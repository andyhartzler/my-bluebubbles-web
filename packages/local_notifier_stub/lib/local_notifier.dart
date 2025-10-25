library local_notifier;

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
  final List<LocalNotificationAction> actions;
  final LocalNotificationDuration duration;
  Future<void> Function(LocalNotificationCloseReason reason)? _onClose;

  LocalNotification({
    required this.title,
    this.body,
    this.actions = const [],
    this.duration = LocalNotificationDuration.short,
    Future<void> Function(LocalNotificationCloseReason reason)? onClose,
  }) : _onClose = onClose;

  Future<void> show() async {}

  Future<void> close({LocalNotificationCloseReason reason = LocalNotificationCloseReason.unknown}) async {
    final handler = _onClose;
    if (handler != null) {
      await handler(reason);
    }
  }

  set onClose(Future<void> Function(LocalNotificationCloseReason reason)? handler) => _onClose = handler;
}

class LocalNotifier {
  Future<void> setup({required String appName}) async {}
}
