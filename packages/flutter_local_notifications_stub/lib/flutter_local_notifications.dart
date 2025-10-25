library flutter_local_notifications;

class AndroidInitializationSettings {
  final String icon;
  const AndroidInitializationSettings(this.icon);
}

class InitializationSettings {
  final AndroidInitializationSettings? android;
  const InitializationSettings({this.android});
}

class NotificationResponse {
  final String? payload;
  NotificationResponse({this.payload});
}

class NotificationAppLaunchDetails {
  final bool didNotificationLaunchApp;
  final NotificationResponse? notificationResponse;

  NotificationAppLaunchDetails({this.didNotificationLaunchApp = false, this.notificationResponse});
}

enum AndroidScheduleMode { exactAllowWhileIdle }

enum UILocalNotificationDateInterpretation { absoluteTime }

enum Importance { max }

enum Priority { max }

class BigTextStyleInformation {
  const BigTextStyleInformation(String _);
}

class PendingNotificationRequest {
  final int id;
  final String? title;
  final String? body;
  final String? payload;

  const PendingNotificationRequest(this.id, this.title, this.body, this.payload);
}

class ActiveNotification {
  final int? id;
  final String? title;
  final String? body;

  const ActiveNotification({this.id, this.title, this.body});
}

class AndroidNotificationDetails {
  final String channelId;
  final String channelName;
  final String? channelDescription;
  final Priority? priority;
  final Importance? importance;
  final Object? color;
  final bool? ongoing;
  final bool? onlyAlertOnce;
  final BigTextStyleInformation? styleInformation;

  AndroidNotificationDetails(
    this.channelId,
    this.channelName, {
    this.channelDescription,
    this.priority,
    this.importance,
    this.color,
    this.ongoing,
    this.onlyAlertOnce,
    this.styleInformation,
  });
}

class NotificationDetails {
  final AndroidNotificationDetails? android;
  const NotificationDetails({this.android});
}

class FlutterLocalNotificationsPlugin {
  Future<void> initialize(
    InitializationSettings settings, {
    Future<void> Function(NotificationResponse?)? onDidReceiveNotificationResponse,
  }) async {}

  Future<NotificationAppLaunchDetails?> getNotificationAppLaunchDetails() async => null;

  Future<void> zonedSchedule(
    int id,
    String? title,
    String? body,
    DateTime scheduledDate,
    NotificationDetails notificationDetails, {
    String? payload,
    AndroidScheduleMode androidScheduleMode = AndroidScheduleMode.exactAllowWhileIdle,
    UILocalNotificationDateInterpretation uiLocalNotificationDateInterpretation = UILocalNotificationDateInterpretation.absoluteTime,
  }) async {}

  Future<void> show(
    int id,
    String? title,
    String? body,
    NotificationDetails? notificationDetails, {
    String? payload,
  }) async {}

  Future<void> cancel(int id) async {}

  Future<List<PendingNotificationRequest>> pendingNotificationRequests() async =>
      const <PendingNotificationRequest>[];

  Future<List<ActiveNotification>> getActiveNotifications() async => const <ActiveNotification>[];
}
