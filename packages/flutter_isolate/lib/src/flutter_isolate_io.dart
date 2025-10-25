import 'dart:async';
import 'dart:isolate';

/// A lightweight stand-in for the original flutter_isolate plugin.
///
/// The real plugin spins up a secondary Flutter engine so plugins can be used
/// inside the spawned isolate. The BlueBubbles app only needs to run the
/// incremental sync logic on another isolate for mobile platforms, so this
/// implementation simply proxies to [Isolate.spawn].
class FlutterIsolate {
  FlutterIsolate._(this._isolate);

  final Isolate _isolate;

  /// Spawns a new [Isolate] that executes [entryPoint] with [message].
  static Future<FlutterIsolate> spawn<T>(
    FutureOr<void> Function(T message) entryPoint,
    T message, {
    bool? paused,
    bool errorsAreFatal = true,
    SendPort? onExit,
    SendPort? onError,
    String? debugName,
  }) async {
    final isolate = await Isolate.spawn<T>(
      entryPoint,
      message,
      paused: paused ?? false,
      errorsAreFatal: errorsAreFatal,
      onExit: onExit,
      onError: onError,
      debugName: debugName,
    );

    return FlutterIsolate._(isolate);
  }

  /// Terminates the underlying [Isolate].
  void kill({int priority = Isolate.immediate}) {
    _isolate.kill(priority: priority);
  }

  /// Exposes the wrapped [Isolate] for direct access when needed.
  Isolate get isolate => _isolate;
}
