import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../models/email/email_message.dart';
import '../models/email/email_thread.dart';
import '../services/email/email_service.dart';

/// Coordinates email history retrieval and manipulation while exposing
/// observable state for UI widgets.
class EmailHistoryProvider extends ChangeNotifier {
  EmailHistoryProvider({required EmailService emailService})
      : _emailService = emailService;

  final EmailService _emailService;

  final Map<String, EmailThread> _threadLookup = <String, EmailThread>{};
  List<EmailThread> _threads = const <EmailThread>[];

  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _isSendingReply = false;
  String? _errorMessage;

  final Set<String> _refreshingThreads = <String>{};
  final Set<String> _markingThreads = <String>{};

  /// A sorted view of available threads, ordered by newest activity.
  UnmodifiableListView<EmailThread> get threads =>
      UnmodifiableListView<EmailThread>(_threads);

  /// Convenience view mapping a thread id to the messages it contains.
  UnmodifiableMapView<String, List<EmailMessage>> get groupedThreads =>
      UnmodifiableMapView<String, List<EmailMessage>>({
        for (final EmailThread thread in _threads) thread.id: thread.messages,
      });

  EmailThread? threadForId(String threadId) => _threadLookup[threadId];

  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  bool get isSendingReply => _isSendingReply;
  bool get hasError => _errorMessage != null;
  String? get errorMessage => _errorMessage;

  bool isRefreshingThread(String threadId) =>
      _refreshingThreads.contains(threadId);

  bool isMarkingThreadRead(String threadId) =>
      _markingThreads.contains(threadId);

  bool get isMarkingAnyThreadRead => _markingThreads.isNotEmpty;

  /// Loads the set of email threads from the backing [EmailService].
  Future<void> fetchHistory({bool forceRefresh = false}) async {
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final List<EmailThread> threads =
          await _emailService.fetchThreads(forceRefresh: forceRefresh);
      _replaceThreads(threads);
    } catch (error) {
      _registerError(error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Reloads all threads, typically in response to a user refresh action.
  Future<void> refreshHistory() async {
    _isRefreshing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final List<EmailThread> threads =
          await _emailService.fetchThreads(forceRefresh: true);
      _replaceThreads(threads);
    } catch (error) {
      _registerError(error);
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  /// Refreshes a single thread identified by [threadId].
  Future<void> refreshThread(String threadId) async {
    if (_refreshingThreads.contains(threadId)) {
      return;
    }

    _refreshingThreads.add(threadId);
    _errorMessage = null;
    notifyListeners();

    try {
      final EmailThread thread = await _emailService.fetchThread(threadId);
      _upsertThread(thread);
    } catch (error) {
      _registerError(error);
    } finally {
      _refreshingThreads.remove(threadId);
      notifyListeners();
    }
  }

  /// Sends a reply for the given [threadId] using [draft]. When the
  /// underlying service succeeds the new message is appended to the local
  /// thread state and returned.
  Future<EmailMessage?> sendReply({
    required String threadId,
    required EmailReplyDraft draft,
  }) async {
    _isSendingReply = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final EmailMessage message =
          await _emailService.sendReply(threadId: threadId, draft: draft);
      _addMessageToThread(message);
      return message;
    } catch (error) {
      _registerError(error);
      return null;
    } finally {
      _isSendingReply = false;
      notifyListeners();
    }
  }

  /// Marks a thread as read via the [EmailService] and updates local state.
  Future<void> markThreadAsRead(String threadId) async {
    if (_markingThreads.contains(threadId)) return;

    _markingThreads.add(threadId);
    _errorMessage = null;
    notifyListeners();

    try {
      final EmailThread updatedThread =
          await _emailService.markThreadAsRead(threadId);
      _upsertThread(updatedThread);
    } catch (error) {
      _registerError(error);
    } finally {
      _markingThreads.remove(threadId);
      notifyListeners();
    }
  }

  /// Clears the last captured error message and notifies listeners.
  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  void _replaceThreads(List<EmailThread> threads) {
    _threadLookup
      ..clear()
      ..addEntries(
        threads.map(
          (EmailThread thread) => MapEntry<String, EmailThread>(thread.id, thread),
        ),
      );
    _threads = _sortedThreads(_threadLookup.values);
  }

  void _upsertThread(EmailThread thread) {
    _threadLookup[thread.id] = thread;
    _threads = _sortedThreads(_threadLookup.values);
  }

  void _addMessageToThread(EmailMessage message) {
    final EmailThread? existing = _threadLookup[message.threadId];
    if (existing == null) {
      _upsertThread(EmailThread(id: message.threadId, messages: <EmailMessage>[message]));
      return;
    }

    final List<EmailMessage> messages = <EmailMessage>[message];
    for (final EmailMessage existingMessage in existing.messages) {
      if (existingMessage.id == message.id) {
        continue;
      }
      messages.add(existingMessage);
    }

    _upsertThread(existing.copyWith(messages: messages));
  }

  List<EmailThread> _sortedThreads(Iterable<EmailThread> threads) {
    final List<EmailThread> sorted = List<EmailThread>.from(threads);
    sorted.sort((EmailThread a, EmailThread b) {
      final DateTime? aTime = a.latestMessageAt;
      final DateTime? bTime = b.latestMessageAt;
      if (aTime == null && bTime == null) {
        return a.id.compareTo(b.id);
      }
      if (aTime == null) {
        return 1;
      }
      if (bTime == null) {
        return -1;
      }
      return bTime.compareTo(aTime);
    });
    return List.unmodifiable(sorted);
  }

  void _registerError(Object error) {
    _errorMessage = error.toString();
  }
}
