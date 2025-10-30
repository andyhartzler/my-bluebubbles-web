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
  String? _lastBaseServer;
  List<String> _socketCandidates = <String>[];
  int _candidateIndex = 0;
  bool _resolvingCandidate = false;
  bool _serverInfoChecked = false;

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
    _ensureSocketCandidates();

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
    final target = _currentSocketTarget();
    if (isNullOrEmpty(target)) {
      return;
    }

    Logger.info('Connecting to socket at $target');
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
        if (_socketCandidates.isNotEmpty) {
          final String activeTarget = _socketOverride ?? serverAddress;
          final int index = _socketCandidates.indexOf(activeTarget);
          _candidateIndex = index >= 0 ? index : 0;
          _socketOverride = _socketCandidates[_candidateIndex] == serverAddress
              ? null
              : _socketCandidates[_candidateIndex];
        } else {
          _candidateIndex = 0;
        }
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
        Logger.info("Socket connect error, evaluating fallbacks...");

        if (data is SocketException) {
          handleSocketException(data);
        }

        _handleSocketError();
        return;
      default:
        return;
    }
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
    _lastBaseServer = null;
    _socketCandidates = <String>[];
    _candidateIndex = 0;
    _serverInfoChecked = false;
  }

  void _handleSocketError() {
    Future<void>(() async {
      final applied = await _applyNextCandidate();
      if (applied) {
        return;
      }

      state.value = SocketState.error;
      _scheduleReconnect(fetchNewUrl: true);
    });
  }

  String? _currentSocketTarget() {
    if (_socketCandidates.isEmpty) {
      return _socketOverride ?? serverAddress;
    }

    if (_candidateIndex < 0 || _candidateIndex >= _socketCandidates.length) {
      _candidateIndex = 0;
    }

    final String candidate = _socketCandidates[_candidateIndex];
    if (candidate == serverAddress) {
      _socketOverride = null;
      return candidate;
    }

    _socketOverride = candidate;
    return candidate;
  }

  void _ensureSocketCandidates() {
    final base = serverAddress;
    if (base.isEmpty) {
      _socketCandidates = <String>[];
      _lastBaseServer = null;
      return;
    }

    if (_lastBaseServer == base && _socketCandidates.isNotEmpty) {
      return;
    }

    final Uri? baseUri = Uri.tryParse(base);
    if (baseUri == null) {
      _socketCandidates = <String>[];
      _lastBaseServer = null;
      return;
    }

    _lastBaseServer = base;
    _candidateIndex = 0;
    _serverInfoChecked = false;
    final List<String> candidates = <String>[];

    void addUri(Uri uri) {
      final candidate = uri.toString();
      if (candidate.isEmpty) {
        return;
      }
      if (!candidates.contains(candidate)) {
        candidates.add(candidate);
      }
    }

    addUri(baseUri);

    if (!baseUri.hasPort || baseUri.port == 0) {
      addUri(baseUri.replace(port: 1234));
    } else if (baseUri.port == 443 && baseUri.scheme == 'https') {
      addUri(baseUri.replace(port: 1234));
    } else if (baseUri.port == 80 && baseUri.scheme == 'http') {
      addUri(baseUri.replace(port: 1234));
    }

    if (kIsWeb) {
      if (baseUri.scheme == 'http') {
        addUri(baseUri.replace(scheme: 'https'));
        if (!baseUri.hasPort || baseUri.port == 80) {
          addUri(baseUri.replace(scheme: 'https', port: 1234));
        }
      }
    } else {
      if (baseUri.scheme == 'https') {
        addUri(baseUri.replace(scheme: 'http'));
        if (!baseUri.hasPort || baseUri.port == 443) {
          addUri(baseUri.replace(scheme: 'http', port: 1234));
        }
      } else if (baseUri.scheme == 'http') {
        addUri(baseUri.replace(scheme: 'https'));
        if (!baseUri.hasPort || baseUri.port == 80) {
          addUri(baseUri.replace(scheme: 'https', port: 1234));
        }
      }
    }

    _socketCandidates = candidates;
  }

  Future<bool> _applyNextCandidate() async {
    if (_resolvingCandidate) {
      return false;
    }

    _resolvingCandidate = true;
    try {
      _ensureSocketCandidates();
      if (_socketCandidates.isEmpty) {
        return false;
      }

      final bool hasNext = _candidateIndex + 1 < _socketCandidates.length;
      if (hasNext) {
        _candidateIndex += 1;
        final String next = _socketCandidates[_candidateIndex];
        _socketOverride = next == serverAddress ? null : next;
        Logger.warn('Socket connection failed, retrying with alternate target: $next');
        restartSocket();
        return true;
      }

      if (!_serverInfoChecked && await _appendServerInfoCandidate()) {
        _candidateIndex = _socketCandidates.length - 1;
        final String next = _socketCandidates[_candidateIndex];
        _socketOverride = next == serverAddress ? null : next;
        Logger.warn('Socket connection failed, retrying with server-provided target: $next');
        restartSocket();
        return true;
      }

      return false;
    } finally {
      _resolvingCandidate = false;
    }
  }

  Future<bool> _appendServerInfoCandidate() async {
    _serverInfoChecked = true;
    try {
      final response = await http.serverInfo();
      final dynamic data = response.data;
      if (data is! Map) {
        return false;
      }

      final Map map = data;
      final String? socketUrl = _stringFromMap(map, const [
        'socket_url',
        'socketUrl',
        'socket_address',
        'socketAddress',
      ]);
      if (socketUrl != null) {
        final String? sanitized = sanitizeServerAddress(address: socketUrl);
        if (sanitized != null && !_socketCandidates.contains(sanitized)) {
          _socketCandidates.add(sanitized);
          return true;
        }
      }

      final int? port = _intFromMap(map, const ['socket_port', 'socketPort']);
      if (port != null) {
        final Uri? baseUri = Uri.tryParse(serverAddress);
        if (baseUri != null) {
          String scheme = baseUri.scheme;
          final String? socketScheme = _stringFromMap(map, const ['socket_scheme', 'socketScheme']);
          if (socketScheme != null && socketScheme.isNotEmpty) {
            final String normalized = socketScheme.toLowerCase();
            if (normalized == 'ws') {
              scheme = 'http';
            } else if (normalized == 'wss') {
              scheme = 'https';
            } else if (normalized == 'http' || normalized == 'https') {
              scheme = normalized;
            }
          }

          final Uri candidateUri = baseUri.replace(scheme: scheme, port: port);
          final String candidate = candidateUri.toString();
          if (!_socketCandidates.contains(candidate)) {
            _socketCandidates.add(candidate);
            return true;
          }
        }
      }
    } catch (e, stack) {
      Logger.warn('Failed to fetch server socket metadata', error: e, trace: stack);
    }

    return false;
  }

  String? _stringFromMap(Map<dynamic, dynamic> map, List<String> keys) {
    for (final String key in keys) {
      final dynamic value = map[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  int? _intFromMap(Map<dynamic, dynamic> map, List<String> keys) {
    for (final String key in keys) {
      final dynamic value = map[key];
      if (value is int) {
        return value;
      }
      if (value is String) {
        final int? parsed = int.tryParse(value);
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }
}
