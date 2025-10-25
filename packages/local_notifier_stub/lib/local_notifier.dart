library local_notifier;

import 'dart:async';

enum LocalNotificationDuration { short, long }

enum LocalNotificationCloseReason { action, dismissed, timedOut, unknown }

class LocalNotificationAction {
  final String text;
  final String? key;

  const LocalNotificationAction({required this.text, this.key});
}

class LocalNotification {
  final String title;
  final String? body;
  final String? subtitle;
  final String? imagePath;
  final LocalNotificationDuration duration;
  final List<LocalNotificationAction> actions;

  FutureOr<void> Function()? _onClick;
  FutureOr<void> Function(int index)? _onClickAction;
  FutureOr<void> Function(LocalNotificationCloseReason reason)? _onClose;

  LocalNotification({
    required this.title,
    this.body,
    this.subtitle,
    this.imagePath,
    List<LocalNotificationAction>? actions,
    this.duration = LocalNotificationDuration.short,
    FutureOr<void> Function()? onClick,
    FutureOr<void> Function(int index)? onClickAction,
    FutureOr<void> Function(LocalNotificationCloseReason reason)? onClose,
  })  : actions = List.unmodifiable(actions ?? const []),
        _onClick = onClick,
        _onClickAction = onClickAction,
        _onClose = onClose;

  Future<void> show() async {}

  Future<void> close({LocalNotificationCloseReason reason = LocalNotificationCloseReason.unknown}) async {
    final handler = _onClose;
    if (handler != null) {
      await Future.sync(() => handler(reason));
    }
  }

  FutureOr<void> Function()? get onClick => _onClick;
  set onClick(FutureOr<void> Function()? handler) => _onClick = handler;

  FutureOr<void> Function(int index)? get onClickAction => _onClickAction;
  set onClickAction(FutureOr<void> Function(int index)? handler) => _onClickAction = handler;

  FutureOr<void> Function(LocalNotificationCloseReason reason)? get onClose => _onClose;
  set onClose(FutureOr<void> Function(LocalNotificationCloseReason reason)? handler) => _onClose = handler;
}

class LocalNotifier {
  Future<void> setup({required String appName}) async {}
}
