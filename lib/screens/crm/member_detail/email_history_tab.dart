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
    this.memberEmail,
    this.loadThreadMessages,
    this.onSendReply,
  });

  final String memberId;
  final String memberName;
  final String? memberEmail;
  final Future<List<EmailMessage>> Function(String memberId, String threadId)?
      loadThreadMessages;
  final Future<void> Function(String threadId, EmailReplyData data)? onSendReply;

  @override
  State<EmailHistoryTab> createState() => _EmailHistoryTabState();
}

class _EmailHistoryTabState extends State<EmailHistoryTab> {
  late final DateFormat _timestampFormat = DateFormat('MMM d, y • h:mm a');
  bool _requestedInitialLoad = false;

  EmailHistoryProvider? _maybeReadProvider(BuildContext context) {
    try {
      return Provider.of<EmailHistoryProvider>(context, listen: false);
    } on ProviderNotFoundException {
      return null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = _maybeReadProvider(context);
    if (provider != null && !_requestedInitialLoad) {
      _requestedInitialLoad = true;
      provider.ensureLoaded(widget.memberId);
    }
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

    final defaultRecipients = _resolveDefaultReplyRecipients(entry);
    final participants = _participantsFromEntry(entry);
    final preview = _sanitizeEmailPreview(entry.previewText);
    final thread = EmailThread(
      id: threadId,
      subject: entry.subject,
      updatedAt: entry.sentAt ?? DateTime.now(),
      snippet: preview,
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
          initialReplyTo: defaultRecipients,
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

  List<String> _resolveDefaultReplyRecipients(EmailHistoryEntry entry) {
    final nonOrg = <String>[];
    final fallback = <String>[];
    final seen = <String>{};

    void collect(List<String> values) {
      for (final value in values) {
        final email = _normalizeEmail(value);
        if (email == null) continue;
        final lower = email.toLowerCase();
        if (!seen.add(lower)) continue;
        if (_isOrgAddress(email)) {
          fallback.add(email);
        } else {
          nonOrg.add(email);
        }
      }
    }

    collect(entry.to);
    collect(entry.cc);
    collect(entry.bcc);

    final result = <String>[];
    final added = <String>{};

    void addToResult(String? email) {
      final normalized = _normalizeEmail(email);
      if (normalized == null) return;
      final lower = normalized.toLowerCase();
      if (added.add(lower)) {
        result.add(normalized);
      }
    }

    for (final email in nonOrg) {
      addToResult(email);
    }

    for (final email in fallback) {
      addToResult(email);
    }

    addToResult(widget.memberEmail);

    return result;
  }

  Future<void> _defaultReplyHandler(String threadId, EmailReplyData data) async {
    final trimmedTo = data.to
        .map(_normalizeEmail)
        .whereType<String>()
        .toList(growable: false);
    final trimmedCc = data.cc
        .map(_normalizeEmail)
        .whereType<String>()
        .toList(growable: false);
    final trimmedBcc = data.bcc
        .map(_normalizeEmail)
        .whereType<String>()
        .toList(growable: false);

    if (trimmedTo.isEmpty) {
      throw CRMEmailException('At least one recipient email is required for the reply.');
    }

    await CRMEmailService().sendEmailReply(
      threadId: threadId,
      to: trimmedTo,
      htmlBody: data.htmlBody,
      textBody: data.plainTextBody,
      subject: data.subject,
      cc: trimmedCc.isEmpty ? null : trimmedCc,
      bcc: trimmedBcc.isEmpty ? null : trimmedBcc,
    );
  }

  String? _normalizeEmail(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final match = RegExp(r'<([^>]+)>').firstMatch(trimmed);
    final extracted = match != null ? match.group(1)! : trimmed;
    var cleaned = extracted.trim();
    while (cleaned.startsWith('"') || cleaned.startsWith("'")) {
      cleaned = cleaned.substring(1).trim();
    }
    while (cleaned.endsWith('"') || cleaned.endsWith("'")) {
      cleaned = cleaned.substring(0, cleaned.length - 1).trim();
    }
    return cleaned.isEmpty ? null : cleaned;
  }

  bool _isOrgAddress(String value) {
    final normalized = _normalizeEmail(value);
    if (normalized == null) return false;
    return normalized.toLowerCase().endsWith('@moyoungdemocrats.org');
  }

  @override
  Widget build(BuildContext context) {
    final provider = _maybeReadProvider(context);
    if (provider == null) {
      return const _MissingProviderView();
    }

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

        final bool showWarning = state.error != null;
        final int itemCount = state.entries.length + (showWarning ? 1 : 0);

        return RefreshIndicator(
          onRefresh: () => provider.refresh(widget.memberId),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: itemCount,
            separatorBuilder: (_, index) {
              if (showWarning && index == 0) {
                return const SizedBox(height: 16);
              }
              return const SizedBox(height: 12);
            },
            itemBuilder: (context, index) {
              if (showWarning) {
                if (index == 0) {
                  return _SyncWarningBanner(message: state.error!);
                }
                final entry = state.entries[index - 1];
                return _EmailHistoryTile(
                  entry: entry,
                  formatTimestamp: _timestampFormat,
                  onTap: () => _openThread(entry),
                );
              }

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
    final preview = _sanitizeEmailPreview(entry.previewText);

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

    if (preview != null && preview.isNotEmpty) {
      subtitle.add(const SizedBox(height: 8));
      subtitle.add(Text(
        preview,
        style: theme.textTheme.bodyMedium,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
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
    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          TextSpan(
            text: '$label: ',
            style: baseStyle?.copyWith(fontWeight: FontWeight.w600),
          ),
          TextSpan(text: recipients.join(', ')),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
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

class _SyncWarningBanner extends StatelessWidget {
  const _SyncWarningBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.tertiary.withOpacity(0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: colorScheme.tertiary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Email sync is experiencing issues',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.tertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MissingProviderView extends StatelessWidget {
  const _MissingProviderView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyMedium?.color?.withOpacity(0.75);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, size: 40, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Email history unavailable',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Email history requires an EmailHistoryProvider above this screen. Please ensure the CRM providers are configured.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
            ),
          ],
        ),
      ),
    );
  }
}

String? _sanitizeEmailPreview(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  final withBreaks = trimmed
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(
        RegExp(
          r'</(div|p|section|article|header|footer|table|tbody|tr)>',
          caseSensitive: false,
        ),
        '\n\n',
      )
      .replaceAll(RegExp(r'</?(ul|ol)>', caseSensitive: false), '\n\n')
      .replaceAll(RegExp(r'</li>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '\n• ');

  final withoutCodeBlocks = withBreaks.replaceAll(
    RegExp(r'<(script|style)[^>]*>.*?</\1>', caseSensitive: false, dotAll: true),
    '',
  );

  final stripped = withoutCodeBlocks.replaceAll(RegExp(r'<[^>]+>'), ' ');
  final decoded = _decodeHtmlEntities(stripped);
  final normalized = _normalizePreviewWhitespace(decoded);
  return normalized.isEmpty ? null : normalized;
}

String _decodeHtmlEntities(String input) {
  return input.replaceAllMapped(
    RegExp(r'&(#x?[0-9a-fA-F]+|[a-zA-Z]+);'),
    (match) {
      final value = match.group(1);
      if (value == null) return match.group(0)!;

      switch (value) {
        case 'nbsp':
          return ' ';
        case 'amp':
          return '&';
        case 'lt':
          return '<';
        case 'gt':
          return '>';
        case 'quot':
          return '"';
        case 'apos':
        case 'lsquo':
        case 'rsquo':
          return "'";
        case 'ldquo':
        case 'rdquo':
          return '"';
        case 'ndash':
          return '–';
        case 'mdash':
          return '—';
      }

      if (value.startsWith('#x') || value.startsWith('#X')) {
        final hex = value.substring(2);
        final codePoint = int.tryParse(hex, radix: 16);
        if (codePoint != null && codePoint >= 0 && codePoint <= 0x10FFFF) {
          try {
            return String.fromCharCode(codePoint);
          } catch (_) {
            return match.group(0)!;
          }
        }
      } else if (value.startsWith('#')) {
        final decimal = value.substring(1);
        final codePoint = int.tryParse(decimal, radix: 10);
        if (codePoint != null && codePoint >= 0 && codePoint <= 0x10FFFF) {
          try {
            return String.fromCharCode(codePoint);
          } catch (_) {
            return match.group(0)!;
          }
        }
      }

      return match.group(0)!;
    },
  );
}

String _normalizePreviewWhitespace(String input) {
  if (input.isEmpty) return '';

  final cleaned = input
      .replaceAll(String.fromCharCode(0x00A0), ' ')
      .replaceAll(RegExp(r'\r\n?'), '\n')
      .replaceAll(RegExp(r'[\t\f\v]+'), ' ');

  final lines = cleaned.split('\n');
  final paragraphs = <String>[];
  final buffer = <String>[];

  void flushBuffer() {
    if (buffer.isEmpty) return;
    paragraphs.add(buffer.join(' ').trim());
    buffer.clear();
  }

  for (final rawLine in lines) {
    final line = rawLine.trim();
    if (line.isEmpty) {
      flushBuffer();
    } else {
      buffer.add(line.replaceAll(RegExp(r' {2,}'), ' '));
    }
  }
  flushBuffer();

  return paragraphs.join('\n\n').trim();
}
