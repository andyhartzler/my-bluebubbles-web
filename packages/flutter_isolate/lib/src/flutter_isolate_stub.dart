import 'dart:async';

/// Web and other non-IO platforms do not support spawning secondary isolates.
/// This shim eagerly runs the provided [entryPoint] on the main isolate so the
/// surrounding code path can still complete and update state as expected.
class FlutterIsolate {
  FlutterIsolate._();

  /// Mimics the API surface of the IO implementation but executes the
  /// [entryPoint] immediately on the current isolate.
  static Future<FlutterIsolate> spawn<T>(
    FutureOr<void> Function(T message) entryPoint,
    T message, {
    bool? paused,
    bool errorsAreFatal = true,
    Object? onExit,
    Object? onError,
    String? debugName,
  }) async {
    await Future.sync(() => entryPoint(message));
    return FlutterIsolate._();
  }

  /// There is no background isolate to terminate on non-IO platforms.
  void kill({int priority = 0}) {}

  /// No backing isolate exists on platforms without isolate support.
  Object? get isolate => null;
}
