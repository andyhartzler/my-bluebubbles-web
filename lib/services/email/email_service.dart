import '../../models/email/email_message.dart';
import '../../models/email/email_thread.dart';

class EmailReplyDraft {
  const EmailReplyDraft({
    required this.body,
    this.subject,
  });

  final String body;
  final String? subject;

  EmailReplyDraft copyWith({
    String? body,
    String? subject,
  }) {
    return EmailReplyDraft(
      body: body ?? this.body,
      subject: subject ?? this.subject,
    );
  }
}

abstract class EmailService {
  const EmailService();

  Future<List<EmailThread>> fetchThreads({bool forceRefresh = false});

  Future<EmailThread> fetchThread(String threadId);

  Future<EmailMessage> sendReply({
    required String threadId,
    required EmailReplyDraft draft,
  });

  Future<EmailThread> markThreadAsRead(String threadId);
}
