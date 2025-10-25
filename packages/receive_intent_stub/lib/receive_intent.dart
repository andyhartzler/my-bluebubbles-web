library receive_intent;

class Intent {
  final String? action;
  final Map<String, dynamic>? extra;
  final String? data;

  Intent({this.action, this.extra, this.data});
}

class ReceiveIntent {
  static Future<Intent?> getInitialIntent() async => null;
  static Stream<Intent?> get receivedIntentStream => const Stream<Intent?>.empty();
}
