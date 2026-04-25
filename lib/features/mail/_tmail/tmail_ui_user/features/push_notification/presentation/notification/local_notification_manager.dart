// Stub: bluebubbles ships its own notification system; tmail's
// LocalNotificationManager isn't used. Provides a no-op shim with all
// the method/property surface tmail's call sites use.

class LocalNotificationManager {
  static final LocalNotificationManager instance = LocalNotificationManager._();
  LocalNotificationManager._();

  Future<bool?> initialize() async => true;
  Future<bool?> setUp({String? groupId}) async => true;
  Future<bool> requestPermission() async => true;
  Future<void> show(int id, String? title, String? body, {dynamic payload}) async {}
  // Accept any args via dynamic — tmail call sites mix int/String for `id`.
  Future<void> showPushNotification({
    dynamic id,
    String? title,
    String? message,
    dynamic emailAddress,
    String? groupId,
    bool? silent,
    dynamic payload,
  }) async {}
  Future<void> cancel(int id) async {}
  Future<void> cancelAll() async {}
  Future<void> closeStream() async {}
  Future<void> setListenerWhenLaunchApp() async {}
  Future<int> getCountActiveNotificationByGroupOnAndroid({String? groupId}) async => 0;
  Future<void> groupPushNotificationOnAndroid({String? groupId, int? countNotifications}) async {}
  // tmail passes either int id or String tag — accept dynamic
  Future<void> removeNotification(dynamic id) async {}
  Future<void> removeGroupPushNotification(String groupId) async {}
  Future<dynamic> getCurrentNotificationResponse() async => null;
  Stream<dynamic> recreateStreamController() => const Stream.empty();

  Stream<dynamic> get onLaunchAppFromNotificationStream => const Stream.empty();
  Stream<dynamic> get localNotificationStream => const Stream.empty();
  bool isNotificationClickedOnTerminate = false;
  set activatedNotificationClickedOnTerminate(bool _) {}
}
