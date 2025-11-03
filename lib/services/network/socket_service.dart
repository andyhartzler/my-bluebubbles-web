import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:universal_io/io.dart';

import 'package:bluebubbles/helpers/backend/settings_helpers.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/crypto_utils.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:socket_io_client/socket_io_client.dart';

SocketService socket =
    Get.isRegistered<SocketService>() ? Get.find<SocketService>() : Get.put(SocketService());

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
  bool _socketInitialized = false;
  bool _initializingSocket = false;
  String? _socketOverride;
  String? _lastBaseServer;
  List<String> _socketCandidates = <String>[];
  int _candidateIndex = 0;
  bool _resolvingCandidate = false;
  bool _serverInfoChecked = false;

  String get serverAddress => http.origin;
  String get password => ss.settings.guidAuthKey.value;

  bool get _isSecureWebContext => kIsWeb && Uri.base.scheme == 'https';

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
    if (_initializingSocket) {
      Logger.debug('Socket initialization already in progress');
      return;
    }

    if (isNullOrEmpty(serverAddress)) {
      Logger.debug('Socket start skipped, no server address configured');
      return;
    }

    _initializingSocket = true;
    Future<void>(() async {
      try {
        await _prepareSocketCandidates();
        _initializeSocket();
      } catch (e, stack) {
        Logger.error('Failed to start socket', error: e, trace: stack);
      } finally {
        _initializingSocket = false;
      }
    });
  }

  void disconnect() {
    if (!_socketInitialized || isNullOrEmpty(serverAddress)) return;
    socket.disconnect();
    state.value = SocketState.disconnected;
    _healthCheckTimer?.cancel();
  }

  void reconnect() {
    if (!_socketInitialized || state.value == SocketState.connected || isNullOrEmpty(serverAddress)) {
      return;
    }
    state.value = SocketState.connecting;
    socket.connect();
  }

  void closeSocket() {
    if (!_socketInitialized || isNullOrEmpty(serverAddress)) {
      _socketInitialized = false;
      return;
    }
    socket.dispose();
    _socketInitialized = false;
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
    if (!_socketInitialized) {
      return Future.error('Socket not initialized');
    }

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
    _resetErrorTracking();
  }

  void _handleSocketError() {
    Future<void>(() async {
      final bool applied = await _applyNextCandidate();
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

  Iterable<String> _candidateVariantsForUri(Uri uri, {bool fromMetadata = false}) sync* {
    final candidate = uri.toString();
    if (candidate.isEmpty) {
      return;
    }

    final bool isHttp = uri.scheme == 'http';
    final bool nonLocal = !_isLocalHost(uri.host);
    if (_isSecureWebContext && nonLocal && isHttp && !fromMetadata) {
      yield uri.replace(scheme: 'https').toString();
      return;
    }

    yield candidate;

    if (_isSecureWebContext && nonLocal && isHttp) {
      yield uri.replace(scheme: 'https').toString();
    }
  }

  void _ensureSocketCandidates() {
    final String base = serverAddress;
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
    final LinkedHashSet<String> candidates = LinkedHashSet<String>();

    void addUri(Uri uri, {bool fromMetadata = false}) {
      for (final variant in _candidateVariantsForUri(uri, fromMetadata: fromMetadata)) {
        candidates.add(variant);
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

    _socketCandidates = candidates.toList();
  }

  Future<bool> _applyNextCandidate() async {
    if (_resolvingCandidate) {
      return false;
    }

    _resolvingCandidate = true;
    try {
      if (_socketCandidates.isEmpty) {
        return false;
      }

      final bool hasNext = _candidateIndex + 1 < _socketCandidates.length;
      if (hasNext) {
        _candidateIndex += 1;
        final String next = _socketCandidates[_candidateIndex];
        _socketOverride = next == serverAddress ? null : next;
        Logger.warn('Socket connection failed, retrying with alternate target: $next');
        closeSocket();
        _initializeSocket();
        return true;
      }

      if (!_serverInfoChecked) {
        final String? appended = await _appendServerInfoCandidate();
        if (appended != null) {
          _prioritizeCandidates(serverCandidate: appended);
          if (_socketCandidates.isNotEmpty) {
            final String next = _socketCandidates.first;
            _candidateIndex = 0;
            _socketOverride = next == serverAddress ? null : next;
            Logger.warn('Socket connection failed, retrying with server-provided target: $next');
            closeSocket();
            _initializeSocket();
            return true;
          }
        }
      }

      return false;
    } finally {
      _resolvingCandidate = false;
    }
  }

  Future<String?> _appendServerInfoCandidate() async {
    _serverInfoChecked = true;
    try {
      final response = await http.serverInfo();
      final dynamic data = response.data;
      if (data is! Map) {
        return null;
      }

      final Map map = data;
      final String? socketUrl = _stringFromMap(map, const [
        'socket_url',
        'socketUrl',
        'socket_address',
        'socketAddress',
      ]);
      if (socketUrl != null) {
        final String? normalized = _normalizeCandidate(sanitizeServerAddress(address: socketUrl));
        if (normalized != null) {
          final Uri? uri = Uri.tryParse(normalized);
          if (uri != null) {
            final List<String> variants = _candidateVariantsForUri(uri, fromMetadata: true).toList();
            String? first;
            for (final variant in variants) {
              _socketCandidates.remove(variant);
              _socketCandidates.insert(0, variant);
              first = variant;
            }
            if (first != null) {
              return first;
            }
          } else {
            _socketCandidates.remove(normalized);
            _socketCandidates.insert(0, normalized);
            return normalized;
          }
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
          final List<String> variants =
              _candidateVariantsForUri(candidateUri, fromMetadata: true).toList();
          String? first;
          for (final variant in variants) {
            _socketCandidates.remove(variant);
            _socketCandidates.insert(0, variant);
            first = variant;
          }
          if (first != null) {
            return first;
          }
        }
      }
    } catch (e, stack) {
      Logger.warn('Failed to fetch server socket metadata', error: e, trace: stack);
    }

    return null;
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

  Future<void> _prepareSocketCandidates() async {
    _ensureSocketCandidates();
    String? serverCandidate;
    if (!_serverInfoChecked) {
      serverCandidate = await _appendServerInfoCandidate();
    }
    _prioritizeCandidates(serverCandidate: serverCandidate);
    if (_socketCandidates.isNotEmpty) {
      Logger.debug('Socket candidates: ${_socketCandidates.join(', ')}');
    } else {
      Logger.debug('Socket candidates: <none>');
    }
  }

  void _prioritizeCandidates({String? serverCandidate}) {
    if (_socketCandidates.isEmpty) {
      if (serverAddress.isNotEmpty) {
        _socketCandidates = <String>[serverAddress];
      }
      return;
    }

    final LinkedHashSet<String> ordered = LinkedHashSet<String>();

    void push(String? value) {
      if (value == null || value.isEmpty) return;
      ordered.add(value);
    }

    push(serverCandidate);

    final Uri? baseUri = Uri.tryParse(serverAddress);
    if (baseUri != null && ss.settings.enablePrivateAPI.value) {
      push(_buildPrivateApiCandidate(baseUri));
    }

    for (final String candidate in _socketCandidates) {
      push(candidate);
    }

    _socketCandidates = ordered.toList();
    _candidateIndex = 0;
    if (_socketCandidates.isNotEmpty) {
      final String first = _socketCandidates.first;
      _socketOverride = first == serverAddress ? null : first;
    } else {
      _socketOverride = null;
    }
  }

  String? _buildPrivateApiCandidate(Uri baseUri) {
    if (baseUri.host.isEmpty) {
      return null;
    }

    String scheme = baseUri.scheme;
    if (scheme.isEmpty) {
      scheme = 'http';
    } else if (scheme == 'ws') {
      scheme = 'http';
    } else if (scheme == 'wss') {
      scheme = 'https';
    }

    if (_isSecureWebContext && !_isLocalHost(baseUri.host) && scheme == 'http') {
      scheme = 'https';
    }

    final bool isLocal = _isLocalHost(baseUri.host);
    int port = baseUri.port;
    if (port == 0) {
      port = scheme == 'https' ? 443 : 80;
    }

    if (isLocal && ss.settings.localhostPort.value != null) {
      port = int.tryParse(ss.settings.localhostPort.value!) ?? port;
    }

    final Uri candidateUri = baseUri.replace(scheme: scheme, port: port);
    return candidateUri.toString();
  }

  bool _isLocalHost(String host) {
    if (host == 'localhost') {
      return true;
    }

    final InternetAddress? parsed = InternetAddress.tryParse(host);
    if (parsed != null) {
      return parsed.isLoopback || parsed.type == InternetAddressType.unix;
    }

    return host.endsWith('.local');
  }

  String? _normalizeCandidate(String? candidate) {
    if (candidate == null) {
      return null;
    }

    if (candidate.startsWith('ws://') || candidate.startsWith('wss://')) {
      final Uri? uri = Uri.tryParse(candidate);
      if (uri == null) {
        return candidate.startsWith('wss://')
            ? 'https://${candidate.substring(6)}'
            : 'http://${candidate.substring(5)}';
      }

      final bool secure = candidate.startsWith('wss://');
      final bool nonLocal = !_isLocalHost(uri.host);
      final String targetScheme;
      if (_isSecureWebContext && nonLocal) {
        targetScheme = secure ? 'https' : 'https';
      } else {
        targetScheme = secure ? 'https' : 'http';
      }

      return uri.replace(scheme: targetScheme).toString();
    }

    return candidate;
  }

  void _initializeSocket() {
    final String? target = _currentSocketTarget();
    if (isNullOrEmpty(target)) {
      Logger.warn('No socket target available');
      _initializingSocket = false;
      return;
    }

    final Map<String, dynamic> query = <String, dynamic>{};
    if (password.isNotEmpty) {
      query['guid'] = password;
    }

    final OptionBuilder builder = OptionBuilder()
        .setQuery(query)
        .setTransports(<String>['websocket', 'polling'])
        .setPath('/socket.io/')
        .setTimeout(20000)
        .setReconnectionAttempts(999999)
        .setReconnectionDelay(2000)
        .setReconnectionDelayMax(10000)
        .setRandomizationFactor(0.35)
        // Disable so that we can create the listeners first
        .disableAutoConnect()
        .enableReconnection();

    if (!kIsWeb && http.headers.isNotEmpty) {
      builder.setExtraHeaders(http.headers);
    }

    final options = builder.build();

    Logger.info('Connecting to socket at $target');
    socket = io(target, options);
    _socketInitialized = true;

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

    state.value = SocketState.connecting;
    socket.connect();
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (state.value == SocketState.connected || _reconnectTimer != null) {
        return;
      }
      _scheduleReconnect();
    });
    _initializingSocket = false;
  }

  void _resetErrorTracking() {
    lastError.value = "";
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
    _lastState = SocketState.disconnected;
  }
}

