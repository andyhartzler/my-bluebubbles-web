import 'dart:async';

class SendPort {
  const SendPort();

  void send(dynamic message) {}
}

class RawReceivePort {
  RawReceivePort() {
    throw UnsupportedError('RawReceivePort is not supported on the web.');
  }

  void Function(dynamic message)? handler;

  SendPort get sendPort => const SendPort();

  void close() {}
}

class ReceivePort {
  ReceivePort() {
    throw UnsupportedError('ReceivePort is not supported on the web.');
  }

  SendPort get sendPort => const SendPort();

  Future<dynamic> get first => Future.value(null);

  void close() {}
}

class Isolate {
  Isolate._();

  static Future<Isolate> spawn<T>(
    void Function(T message) entryPoint,
    T message, {
    bool paused = false,
    bool errorsAreFatal = true,
    SendPort? onExit,
    SendPort? onError,
    String? debugName,
  }) async {
    throw UnsupportedError('Isolate.spawn is not supported on the web.');
  }

  void kill({int priority = 0}) {}
}

class IsolateNameServer {
  static SendPort? lookupPortByName(String name) => null;

  static bool registerPortWithName(SendPort port, String name) => false;

  static bool removePortNameMapping(String name) => false;
}
