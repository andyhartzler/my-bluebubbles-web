import 'package:bluebubbles/models/crm/email_thread.dart';
import 'package:bluebubbles/screens/crm/member_detail/email_history_provider.dart';
import 'package:bluebubbles/services/crm/crm_email_service.dart';
import 'package:bluebubbles/widgets/email_detail_screen.dart';
import 'package:bluebubbles/widgets/email_reply_dialog.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class EmailHistoryTab extends StatefulWidget {
  const EmailHistoryTab({
    super.key,
    required this.memberId,
    required this.memberName,
    this.loadThreadMessages,
    this.onSendReply,
  });

  final String memberId;
  final String memberName;
  final Future<List<EmailMessage>> Function(String memberId, String threadId)?
      loadThreadMessages;
  final Future<void> Function(String threadId, EmailReplyData data)? onSendReply;

  @override
  State<EmailHistoryTab> createState() => _EmailHistoryTabState();
}

class _EmailHistoryTabState extends State<EmailHistoryTab> {
  late final DateFormat _timestampFormat = DateFormat('MMM d, y • h:mm a');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<EmailHistoryProvider>().ensureLoaded(widget.memberId);
    });
  }

  Future<void> _openThread(EmailHistoryEntry entry) async {
    final threadId = entry.threadId?.trim();
    if (threadId == null || threadId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This email does not have a conversation thread yet.'),
        ),
      );
      return;
    }

    final loader = widget.loadThreadMessages;
    final loadMessages = loader != null
        ? () => loader(widget.memberId, threadId)
        : () => context
            .read<EmailHistoryProvider>()
            .fetchThreadMessages(memberId: widget.memberId, threadId: threadId);

    final replyHandler = widget.onSendReply;
    Future<void> Function(EmailReplyData data)? onSendReply;
    if (replyHandler != null) {
      onSendReply = (data) => replyHandler(threadId, data);
    } else {
      onSendReply = (data) => _defaultReplyHandler(threadId, data);
    }

    final participants = _participantsFromEntry(entry);
    final thread = EmailThread(
      id: threadId,
      subject: entry.subject,
      updatedAt: entry.sentAt ?? DateTime.now(),
      snippet: entry.previewText,
      messages: const [],
      participants: participants,
    );

    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => EmailDetailScreen(
          thread: thread,
          loadMessages: loadMessages,
          onSendReply: onSendReply,
          initiallyLoading: true,
          error: entry.errorMessage,
        ),
      ),
    );
  }

  List<EmailParticipant> _participantsFromEntry(EmailHistoryEntry entry) {
    final seen = <String>{};
    final participants = <EmailParticipant>[];

    void addAll(List<String> values) {
      for (final value in values) {
        final trimmed = value.trim();
        if (trimmed.isEmpty) continue;
        final lower = trimmed.toLowerCase();
        if (!seen.add(lower)) continue;
        participants.add(EmailParticipant(address: trimmed));
      }
    }

    addAll(entry.to);
    addAll(entry.cc);
    addAll(entry.bcc);

    return participants;
  }

  Future<void> _defaultReplyHandler(String threadId, EmailReplyData data) async {
    final trimmedCc = data.cc
        .map((email) => email.trim())
        .where((email) => email.isNotEmpty)
        .toList(growable: false);
    final trimmedBcc = data.bcc
        .map((email) => email.trim())
        .where((email) => email.isNotEmpty)
        .toList(growable: false);

    await CRMEmailService().sendEmailReply(
      threadId: threadId,
      body: data.body,
      subject: data.subject,
      cc: trimmedCc.isEmpty ? null : trimmedCc,
      bcc: trimmedBcc.isEmpty ? null : trimmedBcc,
      sendAsHtml: data.sendAsHtml,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EmailHistoryProvider>(
      builder: (context, provider, _) {
        final state = provider.stateForMember(widget.memberId);

        if (state.isLoading && !state.hasLoaded) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state.error != null && state.entries.isEmpty) {
          return _ErrorView(
            message: state.error!,
            onRetry: () => provider.refresh(widget.memberId),
          );
        }

        if (state.entries.isEmpty) {
          return RefreshIndicator(
            onRefresh: () => provider.refresh(widget.memberId),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [
                Icon(
                  Icons.mark_email_unread_outlined,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'No emails found',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Emails sent to ${widget.memberName} will appear here once delivered through the CRM relay.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                      ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => provider.refresh(widget.memberId),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: state.entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final entry = state.entries[index];
              return _EmailHistoryTile(
                entry: entry,
                formatTimestamp: _timestampFormat,
                onTap: () => _openThread(entry),
              );
            },
          ),
        );
      },
    );
  }
}

class _EmailHistoryTile extends StatelessWidget {
  const _EmailHistoryTile({
    required this.entry,
    required this.formatTimestamp,
    this.onTap,
  });

  final EmailHistoryEntry entry;
  final DateFormat formatTimestamp;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sentAt = entry.sentAt;
    final subtitle = <Widget>[];

    subtitle.add(
      Row(
        children: [
          _StatusChip(status: entry.status),
          if (sentAt != null) ...[
            const SizedBox(width: 8),
            Icon(Icons.schedule, size: 16, color: theme.textTheme.bodySmall?.color?.withOpacity(0.7)),
            const SizedBox(width: 4),
            Text(
              formatTimestamp.format(sentAt),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );

    final recipients = _buildRecipientLine(context, 'To', entry.to);
    if (recipients != null) {
      subtitle.add(const SizedBox(height: 6));
      subtitle.add(recipients);
    }

    final cc = _buildRecipientLine(context, 'Cc', entry.cc);
    if (cc != null) {
      subtitle.add(const SizedBox(height: 4));
      subtitle.add(cc);
    }

    final bcc = _buildRecipientLine(context, 'Bcc', entry.bcc);
    if (bcc != null) {
      subtitle.add(const SizedBox(height: 4));
      subtitle.add(bcc);
    }

    if (entry.previewText != null && entry.previewText!.trim().isNotEmpty) {
      subtitle.add(const SizedBox(height: 8));
      subtitle.add(Text(
        entry.previewText!.trim(),
        style: theme.textTheme.bodyMedium,
      ));
    }

    if (entry.errorMessage != null && entry.errorMessage!.trim().isNotEmpty) {
      subtitle.add(const SizedBox(height: 8));
      subtitle.add(
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.error.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, size: 18, color: theme.colorScheme.error),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  entry.errorMessage!,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.subject,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              ...subtitle,
            ],
          ),
        ),
      ),
    );
  }

  Widget? _buildRecipientLine(BuildContext context, String label, List<String> recipients) {
    if (recipients.isEmpty) return null;
    final theme = Theme.of(context);
    final baseStyle = theme.textTheme.bodyMedium;
    return RichText(
      text: TextSpan(
        style: baseStyle,
        children: [
          TextSpan(
            text: '$label: ',
            style: baseStyle?.copyWith(fontWeight: FontWeight.w600),
          ),
          TextSpan(text: recipients.join(', ')),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final colorScheme = Theme.of(context).colorScheme;

    Color background;
    Color foreground;
    if (normalized.contains('fail') || normalized.contains('error')) {
      background = colorScheme.error.withOpacity(0.12);
      foreground = colorScheme.error;
    } else if (normalized.contains('queue') || normalized.contains('pending')) {
      background = colorScheme.tertiaryContainer.withOpacity(0.4);
      foreground = colorScheme.tertiary;
    } else {
      background = colorScheme.primary.withOpacity(0.12);
      foreground = colorScheme.primary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 40, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Unable to load email history',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
