import 'package:flutter_test/flutter_test.dart';

import 'package:bluebubbles/models/email/email_message.dart';
import 'package:bluebubbles/models/email/email_thread.dart';
import 'package:bluebubbles/providers/email_history_provider.dart';
import 'package:bluebubbles/services/email/email_service.dart';

void main() {
  late FakeEmailService service;
  late EmailHistoryProvider provider;

  setUp(() {
    service = FakeEmailService();
    provider = EmailHistoryProvider(emailService: service);
  });

  test('fetchHistory loads threads and sorts them', () async {
    service.setThreads(<EmailThread>[
      EmailThread(
        id: 'thread-b',
        messages: <EmailMessage>[
          _message(
            id: 'b1',
            threadId: 'thread-b',
            minutes: 5,
          ),
        ],
      ),
      EmailThread(
        id: 'thread-a',
        messages: <EmailMessage>[
          _message(
            id: 'a1',
            threadId: 'thread-a',
            minutes: 1,
          ),
        ],
      ),
    ]);

    final Future<void> future = provider.fetchHistory();
    expect(provider.isLoading, isTrue);
    await future;

    expect(provider.isLoading, isFalse);
    expect(provider.errorMessage, isNull);
    expect(provider.threads, hasLength(2));
    expect(provider.threads.first.id, 'thread-a');
    expect(provider.groupedThreads['thread-a'], hasLength(1));
  });

  test('refreshHistory toggles refreshing state and updates threads', () async {
    service.setThreads(<EmailThread>[
      EmailThread(
        id: 'thread-1',
        messages: <EmailMessage>[
          _message(id: '1', threadId: 'thread-1', minutes: 3),
        ],
      ),
    ]);
    await provider.fetchHistory();

    service.setThreads(<EmailThread>[
      EmailThread(
        id: 'thread-2',
        messages: <EmailMessage>[
          _message(id: '2', threadId: 'thread-2', minutes: 2),
        ],
      ),
    ]);

    final Future<void> future = provider.refreshHistory();
    expect(provider.isRefreshing, isTrue);
    await future;

    expect(provider.isRefreshing, isFalse);
    expect(provider.threads.single.id, 'thread-2');
  });

  test('refreshThread updates a single thread and tracks state', () async {
    final EmailThread thread = EmailThread(
      id: 'thread-1',
      messages: <EmailMessage>[
        _message(id: '1', threadId: 'thread-1', minutes: 10, isRead: false),
      ],
    );
    service.setThreads(<EmailThread>[thread]);
    await provider.fetchHistory();

    final EmailThread refreshed = EmailThread(
      id: 'thread-1',
      messages: <EmailMessage>[
        _message(id: '2', threadId: 'thread-1', minutes: 0),
        _message(id: '1', threadId: 'thread-1', minutes: 10, isRead: true),
      ],
    );
    service.threadOverrides['thread-1'] = refreshed;

    final Future<void> future = provider.refreshThread('thread-1');
    expect(provider.isRefreshingThread('thread-1'), isTrue);
    await future;

    expect(provider.isRefreshingThread('thread-1'), isFalse);
    expect(provider.threadForId('thread-1')?.messages.first.id, '2');
    expect(provider.threadForId('thread-1')?.hasUnread, isFalse);
  });

  test('sendReply adds new message to thread and toggles sending state', () async {
    service.setThreads(<EmailThread>[
      EmailThread(
        id: 'thread-1',
        messages: <EmailMessage>[
          _message(id: '1', threadId: 'thread-1', minutes: 5),
        ],
      ),
    ]);
    await provider.fetchHistory();

    final Future<EmailMessage?> future = provider.sendReply(
      threadId: 'thread-1',
      draft: const EmailReplyDraft(body: 'Reply body'),
    );
    expect(provider.isSendingReply, isTrue);
    final EmailMessage? message = await future;

    expect(provider.isSendingReply, isFalse);
    expect(message, isNotNull);
    expect(provider.threadForId('thread-1')?.messages.first.id, message?.id);
    expect(provider.errorMessage, isNull);
  });

  test('sendReply surfaces errors gracefully', () async {
    service.setThreads(<EmailThread>[
      EmailThread(
        id: 'thread-1',
        messages: <EmailMessage>[
          _message(id: '1', threadId: 'thread-1', minutes: 1),
        ],
      ),
    ]);
    await provider.fetchHistory();
    service.throwOnSend = true;

    final Future<EmailMessage?> future = provider.sendReply(
      threadId: 'thread-1',
      draft: const EmailReplyDraft(body: 'Body'),
    );
    expect(provider.isSendingReply, isTrue);
    final EmailMessage? result = await future;

    expect(provider.isSendingReply, isFalse);
    expect(result, isNull);
    expect(provider.errorMessage, isNotNull);
  });

  test('markThreadAsRead updates thread and clears unread state', () async {
    service.setThreads(<EmailThread>[
      EmailThread(
        id: 'thread-1',
        messages: <EmailMessage>[
          _message(id: '1', threadId: 'thread-1', minutes: 3, isRead: false),
        ],
      ),
    ]);
    await provider.fetchHistory();

    final Future<void> future = provider.markThreadAsRead('thread-1');
    expect(provider.isMarkingThreadRead('thread-1'), isTrue);
    await future;

    expect(provider.isMarkingThreadRead('thread-1'), isFalse);
    expect(provider.threadForId('thread-1')?.hasUnread, isFalse);
  });

  test('fetchHistory handles errors', () async {
    service.throwOnFetch = true;

    await provider.fetchHistory();

    expect(provider.isLoading, isFalse);
    expect(provider.threads, isEmpty);
    expect(provider.errorMessage, isNotNull);
  });
}

EmailMessage _message({
  required String id,
  required String threadId,
  required int minutes,
  bool isRead = true,
}) {
  final DateTime timestamp =
      DateTime.utc(2024, 1, 1, 12).subtract(Duration(minutes: minutes));
  return EmailMessage(
    id: id,
    threadId: threadId,
    sender: 'sender@example.com',
    recipients: const <String>['recipient@example.com'],
    subject: 'Subject $id',
    snippet: 'Snippet $id',
    sentAt: timestamp,
    isRead: isRead,
  );
}

class FakeEmailService extends EmailService {
  FakeEmailService({List<EmailThread> threads = const <EmailThread>[]})
      : _threads = threads;

  List<EmailThread> _threads;
  int _replyCount = 0;

  bool throwOnFetch = false;
  bool throwOnThreadFetch = false;
  bool throwOnSend = false;
  bool throwOnMark = false;

  final Map<String, EmailThread> threadOverrides = <String, EmailThread>{};

  void setThreads(List<EmailThread> threads) {
    _threads = List<EmailThread>.from(threads);
  }

  @override
  Future<List<EmailThread>> fetchThreads({bool forceRefresh = false}) {
    if (throwOnFetch) {
      return Future<List<EmailThread>>.error(Exception('fetch failure'));
    }
    return Future<List<EmailThread>>.delayed(
      const Duration(milliseconds: 1),
      () => List<EmailThread>.from(_threads),
    );
  }

  @override
  Future<EmailThread> fetchThread(String threadId) {
    if (throwOnThreadFetch) {
      return Future<EmailThread>.error(Exception('thread fetch failure'));
    }

    final int index = _threads.indexWhere((EmailThread t) => t.id == threadId);
    if (index == -1) {
      return Future<EmailThread>.error(StateError('Thread $threadId not found'));
    }

    final EmailThread? override = threadOverrides.remove(threadId);
    if (override != null) {
      final List<EmailThread> updated = List<EmailThread>.from(_threads);
      updated[index] = override;
      _threads = updated;
      return Future<EmailThread>.delayed(
        const Duration(milliseconds: 1),
        () => override,
      );
    }

    return Future<EmailThread>.delayed(
      const Duration(milliseconds: 1),
      () => _threads[index],
    );
  }

  @override
  Future<EmailMessage> sendReply({
    required String threadId,
    required EmailReplyDraft draft,
  }) {
    if (throwOnSend) {
      return Future<EmailMessage>.error(Exception('send failure'));
    }

    final EmailMessage message = EmailMessage(
      id: 'reply-${_replyCount++}',
      threadId: threadId,
      sender: 'me@example.com',
      recipients: const <String>['them@example.com'],
      subject: draft.subject,
      snippet: draft.body,
      sentAt: DateTime.utc(2024, 1, 1, 12, _replyCount),
      isRead: true,
      isOutgoing: true,
    );

    final int index = _threads.indexWhere((EmailThread t) => t.id == threadId);
    if (index == -1) {
      _threads = <EmailThread>[..._threads, EmailThread(id: threadId, messages: <EmailMessage>[message])];
    } else {
      final EmailThread thread = _threads[index];
      final EmailThread updated = thread.copyWith(
        messages: <EmailMessage>[message, ...thread.messages],
      );
      final List<EmailThread> mutable = List<EmailThread>.from(_threads);
      mutable[index] = updated;
      _threads = mutable;
    }

    return Future<EmailMessage>.delayed(
      const Duration(milliseconds: 1),
      () => message,
    );
  }

  @override
  Future<EmailThread> markThreadAsRead(String threadId) {
    if (throwOnMark) {
      return Future<EmailThread>.error(Exception('mark failure'));
    }

    final int index = _threads.indexWhere((EmailThread t) => t.id == threadId);
    if (index == -1) {
      return Future<EmailThread>.error(StateError('Thread $threadId not found'));
    }

    final EmailThread thread = _threads[index];
    final EmailThread updated = thread.copyWith(
      messages: thread.messages
          .map((EmailMessage message) => message.copyWith(isRead: true))
          .toList(),
    );

    final List<EmailThread> mutable = List<EmailThread>.from(_threads);
    mutable[index] = updated;
    _threads = mutable;

    return Future<EmailThread>.delayed(
      const Duration(milliseconds: 1),
      () => updated,
    );
  }
}
