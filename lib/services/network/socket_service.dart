import 'dart:async';
import 'dart:convert';
import 'package:universal_io/io.dart';

import 'package:bluebubbles/helpers/backend/settings_helpers.dart';
import 'package:bluebubbles/utils/crypto_utils.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:socket_io_client/socket_io_client.dart';

SocketService socket = Get.isRegistered<SocketService>() ? Get.find<SocketService>() : Get.put(SocketService());

enum SocketState {
  connected,
  disconnected,
  error,
  connecting,
}

class SocketService extends GetxService {
  final Rx<SocketState> state = SocketState.disconnected.obs;
  SocketState _lastState = SocketState.disconnected;
  RxString lastError = "".obs;
  Timer? _reconnectTimer;
  Timer? _healthCheckTimer;
  late Socket socket;
  String? _socketOverride;
  bool _attemptedDowngrade = false;

  String get serverAddress => http.origin;
  String get password => ss.settings.guidAuthKey.value;

  @override
  void onInit() {
    super.onInit();

    Logger.debug("Initializing socket service...");
    startSocket();
    Connectivity().onConnectivityChanged.listen((event) {
      if (!event.contains(ConnectivityResult.wifi) &&
          !event.contains(ConnectivityResult.ethernet) &&
          http.originOverride != null) {
        Logger.info("Detected switch off wifi, removing localhost address...");
        http.originOverride = null;
      }
    });
    Logger.debug("Initialized socket service");
  }

  @override
  void onClose() {
    closeSocket();
    super.onClose();
  }

  void startSocket() {
    OptionBuilder options = OptionBuilder()
        .setQuery({"guid": password})
        .setTransports(['websocket', 'polling'])
        .setExtraHeaders(http.headers)
        .setPath('/socket.io')
        .setTimeout(20000)
        .setReconnectionAttempts(999999)
        .setReconnectionDelay(2000)
        .setReconnectionDelayMax(10000)
        .setRandomizationFactor(0.35)
        // Disable so that we can create the listeners first
        .disableAutoConnect()
        .enableReconnection();
    final target = _socketOverride ?? serverAddress;
    if (isNullOrEmpty(target)) {
      return;
    }

    socket = io(target, options.build());

    socket.onConnect((data) => handleStatusUpdate(SocketState.connected, data));
    socket.onReconnect((data) => handleStatusUpdate(SocketState.connected, data));

    socket.onReconnectAttempt((data) => handleStatusUpdate(SocketState.connecting, data));
    socket.onReconnecting((data) => handleStatusUpdate(SocketState.connecting, data));
    socket.onConnecting((data) => handleStatusUpdate(SocketState.connecting, data));

    socket.onDisconnect((data) => handleStatusUpdate(SocketState.disconnected, data));

    socket.onConnectError((data) => handleStatusUpdate(SocketState.error, data));
    socket.onReconnectError((data) => handleStatusUpdate(SocketState.error, data));
    socket.onConnectTimeout((data) => handleStatusUpdate(SocketState.error, data));
    socket.onError((data) => handleStatusUpdate(SocketState.error, data));
    socket.onReconnectFailed((_) => _scheduleReconnect(fetchNewUrl: true));

    // custom events
    // only listen to these events from socket on web/desktop (FCM handles on Android)
    if (kIsWeb || kIsDesktop) {
      socket.on("group-name-change", (data) => ah.handleEvent("group-name-change", data, 'DartSocket'));
      socket.on("participant-removed", (data) => ah.handleEvent("participant-removed", data, 'DartSocket'));
      socket.on("participant-added", (data) => ah.handleEvent("participant-added", data, 'DartSocket'));
      socket.on("participant-left", (data) => ah.handleEvent("participant-left", data, 'DartSocket'));
      socket.on("incoming-facetime", (data) => ah.handleEvent("incoming-facetime", jsonDecode(data), 'DartSocket'));
    }

    socket.on("ft-call-status-changed", (data) => ah.handleEvent("ft-call-status-changed", data, 'DartSocket'));
    socket.on("new-message", (data) => ah.handleEvent("new-message", data, 'DartSocket'));
    socket.on("updated-message", (data) => ah.handleEvent("updated-message", data, 'DartSocket'));
    socket.on("typing-indicator", (data) => ah.handleEvent("typing-indicator", data, 'DartSocket'));
    socket.on("chat-read-status-changed", (data) => ah.handleEvent("chat-read-status-changed", data, 'DartSocket'));
    socket.on("imessage-aliases-removed", (data) => ah.handleEvent("imessage-aliases-removed", data, 'DartSocket'));

    socket.connect();
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (state.value == SocketState.connected || _reconnectTimer != null) {
        return;
      }
      _scheduleReconnect();
    });
  }

  void disconnect() {
    if (isNullOrEmpty(serverAddress)) return;
    socket.disconnect();
    state.value = SocketState.disconnected;
    _healthCheckTimer?.cancel();
  }

  void reconnect() {
    if (state.value == SocketState.connected || isNullOrEmpty(serverAddress)) return;
    state.value = SocketState.connecting;
    socket.connect();
  }

  void closeSocket() {
    if (isNullOrEmpty(serverAddress)) return;
    socket.dispose();
    state.value = SocketState.disconnected;
    _healthCheckTimer?.cancel();
  }

  void restartSocket() {
    closeSocket();
    startSocket();
  }

  void forgetConnection() {
    closeSocket();
    clearOverride();
    ss.settings.guidAuthKey.value = "";
    clearServerUrl(saveAdditionalSettings: ["guidAuthKey"]);
  }

  Future<Map<String, dynamic>> sendMessage(String event, Map<String, dynamic> message) {
    Completer<Map<String, dynamic>> completer = Completer();

    socket.emitWithAck(event, message, ack: (response) {
      if (response['encrypted'] == true) {
        response['data'] = jsonDecode(decryptAESCryptoJS(response['data'], password));
      }

      if (!completer.isCompleted) {
        completer.complete(response);
      }
    });

    return completer.future;
  }

  void handleStatusUpdate(SocketState status, dynamic data) {
    if (_lastState == status && status != SocketState.error && status != SocketState.disconnected) {
      return;
    }
    _lastState = status;

    switch (status) {
      case SocketState.connected:
        state.value = SocketState.connected;
        _reconnectTimer?.cancel();
        _reconnectTimer = null;
        NetworkTasks.onConnect();
        notif.clearSocketError();
        _attemptedDowngrade = false;
        return;
      case SocketState.disconnected:
        Logger.info("Disconnected from socket...");
        state.value = SocketState.disconnected;
        _scheduleReconnect();
        return;
      case SocketState.connecting:
        Logger.info("Connecting to socket...");
        state.value = SocketState.connecting;
        return;
      case SocketState.error:
        Logger.info("Socket connect error, fetching new URL...");

        if (data is SocketException) {
          handleSocketException(data);
        }

        if (_maybeDowngradeSocketScheme()) {
          return;
        }

        state.value = SocketState.error;
        _scheduleReconnect(fetchNewUrl: true);
        return;
      default:
        return;
    }
  }

  bool _maybeDowngradeSocketScheme() {
    final origin = serverAddress;
    if (origin.isEmpty) {
      return false;
    }

    if (_socketOverride != null) {
      Logger.warn('Socket fallback also failed. Clearing override and retrying default scheme.');
      _socketOverride = null;
      return false;
    }

    if (_attemptedDowngrade) {
      return false;
    }

    final uri = Uri.tryParse(origin);
    if (uri == null || uri.scheme.toLowerCase() != 'https') {
      return false;
    }

    final downgraded = uri.replace(scheme: 'http');
    if (downgraded.toString() == origin) {
      return false;
    }

    _attemptedDowngrade = true;
    _socketOverride = downgraded.toString();
    Logger.warn('HTTPS socket failed, retrying over HTTP/WebSocket fallback...');
    restartSocket();
    return true;
  }

  void _scheduleReconnect({bool fetchNewUrl = false}) {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () async {
      if (state.value == SocketState.connected) {
        _reconnectTimer = null;
        return;
      }

      if (fetchNewUrl) {
        try {
          await fdb.fetchNewUrl();
        } catch (e, stack) {
          Logger.warn('Failed to refresh server URL before reconnecting', error: e, trace: stack);
        }
      }

      restartSocket();

      if (state.value != SocketState.connected && !ss.settings.keepAppAlive.value) {
        notif.createSocketError();
      }
      _reconnectTimer = null;
    });
  }

  void handleSocketException(SocketException e) {
    String msg = e.message;
    if (msg.contains("Failed host lookup")) {
      lastError.value = "Failed to resolve hostname";
    } else {
      lastError.value = msg;
    }
  }

  void clearOverride() {
    _socketOverride = null;
    _attemptedDowngrade = false;
  }
}
