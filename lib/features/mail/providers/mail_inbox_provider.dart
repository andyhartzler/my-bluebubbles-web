import 'package:flutter/foundation.dart';

import 'package:bluebubbles/features/mail/models/mail_message.dart';
import 'package:bluebubbles/features/mail/services/mail_api_client.dart';

class MailInboxProvider extends ChangeNotifier {
  MailInboxProvider({MailApiClient? client})
    : _client = client ?? MailApiClient();

  final MailApiClient _client;

  final List<MailMessage> _messages = [];
  String? _nextPageToken;
  bool _loading = false;
  bool _loadingMore = false;
  Object? _error;

  List<MailMessage> get messages => List.unmodifiable(_messages);
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  bool get hasMore => _nextPageToken != null;
  Object? get error => _error;

  Future<void> refresh() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final page = await _client.listInbox(maxResults: 25);
      _messages
        ..clear()
        ..addAll(page.messages);
      _nextPageToken = page.nextPageToken;
    } catch (e) {
      _error = e;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (_loadingMore || _nextPageToken == null) return;
    _loadingMore = true;
    notifyListeners();
    try {
      final page = await _client.listInbox(
        maxResults: 25,
        pageToken: _nextPageToken,
      );
      _messages.addAll(page.messages);
      _nextPageToken = page.nextPageToken;
    } catch (e) {
      _error = e;
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }
}
