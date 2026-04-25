import 'package:flutter/foundation.dart';

import 'package:bluebubbles/features/mail/services/mail_api_client.dart';

class MailThreadProvider extends ChangeNotifier {
  MailThreadProvider({MailApiClient? client})
    : _client = client ?? MailApiClient();

  final MailApiClient _client;

  List<Map<String, dynamic>> _messages = const [];
  bool _loading = false;
  Object? _error;

  List<Map<String, dynamic>> get messages => _messages;
  bool get loading => _loading;
  Object? get error => _error;

  Future<void> load(String threadId) async {
    _loading = true;
    _error = null;
    _messages = const [];
    notifyListeners();
    try {
      _messages = await _client.getThread(threadId);
    } catch (e) {
      _error = e;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
