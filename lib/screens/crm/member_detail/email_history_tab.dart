import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/models/crm/email_thread.dart';
import 'package:bluebubbles/screens/crm/member_detail/email_history_provider.dart';
import 'package:bluebubbles/screens/crm/widgets/member_profile_sections.dart';
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
          // White spinner on the gradient card: 12.51:1 at the dark end and
          // 4.59:1 at the light end, so it clears 3:1 wherever it sits.
          return const _EmailHistoryPage(
            child: _EmailHistoryCard(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          );
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
            color: BrandColors.unityBlue,
            backgroundColor: Colors.white,
            child: _EmailHistoryPage(
              child: _EmailHistoryCard(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      profileIconTile(Icons.mark_email_unread_outlined, size: 64, iconSize: 32),
                      const SizedBox(height: 16),
                      const Text(
                        'No emails found',
                        textAlign: TextAlign.center,
                        style: ProfileText.value,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Emails sent to ${widget.memberName} will appear here once delivered through the CRM relay.',
                        textAlign: TextAlign.center,
                        style: ProfileText.caption,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        final bool showWarning = state.error != null;
        final int itemCount = state.entries.length + (showWarning ? 1 : 0);

        return RefreshIndicator(
          onRefresh: () => provider.refresh(widget.memberId),
          color: BrandColors.unityBlue,
          backgroundColor: Colors.white,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return ListView.separated(
                padding: _pagePadding(constraints),
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
                      return _sheetWidth(_SyncWarningBanner(message: state.error!));
                    }
                    final entry = state.entries[index - 1];
                    return _sheetWidth(
                      _EmailHistoryTile(
                        entry: entry,
                        formatTimestamp: _timestampFormat,
                        onTap: () => _openThread(entry),
                      ),
                    );
                  }

                  final entry = state.entries[index];
                  return _sheetWidth(
                    _EmailHistoryTile(
                      entry: entry,
                      formatTimestamp: _timestampFormat,
                      onTap: () => _openThread(entry),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

/// The tab's list padding, matching the Meetings tab: 16 under 768 and 32 by
/// 24 above it.
EdgeInsets _pagePadding(BoxConstraints constraints) {
  final wide = constraints.maxWidth >= 768;
  return wide
      ? const EdgeInsets.symmetric(horizontal: 32, vertical: 24)
      : const EdgeInsets.all(16);
}

/// Centres one list item at the profile's 1200 sheet width.
Widget _sheetWidth(Widget child) {
  return Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: ProfileTokens.maxSheetWidth),
      child: child,
    ),
  );
}

/// The tab's scroll frame for a single card: always scrollable so pull to
/// refresh works even when the card is short.
class _EmailHistoryPage extends StatelessWidget {
  const _EmailHistoryPage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: _pagePadding(constraints),
          children: [_sheetWidth(child)],
        );
      },
    );
  }
}

/// The one gradient card the tab's loading, empty, error and unavailable
/// states sit on, in the section header idiom with the tab's own icon.
class _EmailHistoryCard extends StatelessWidget {
  const _EmailHistoryCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ProfileSectionCard(
      title: 'Email History',
      icon: Icons.email_outlined,
      child: child,
    );
  }
}

/// One email as its own tappable gradient card. Every readable line is full
/// white (12.51:1 to 4.59:1 across the card); the status is a solid pill, the
/// delivery error a solid #B91C1C block under white (6.47:1).
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
    final sentAt = entry.sentAt;
    final subtitle = <Widget>[];
    final preview = _sanitizeEmailPreview(entry.previewText);

    subtitle.add(
      Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _StatusChip(status: entry.status),
          if (sentAt != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.schedule, size: 16, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  formatTimestamp.format(sentAt),
                  style: ProfileText.caption,
                ),
              ],
            ),
        ],
      ),
    );

    final recipients = _buildRecipientLine(context, 'To', entry.to);
    if (recipients != null) {
      subtitle.add(const SizedBox(height: 10));
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
      subtitle.add(const SizedBox(height: 10));
      subtitle.add(Text(
        preview,
        style: ProfileText.caption,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ));
    }

    if (entry.errorMessage != null && entry.errorMessage!.trim().isNotEmpty) {
      subtitle.add(const SizedBox(height: 12));
      subtitle.add(
        Container(
          decoration: BoxDecoration(
            color: ProfileTokens.danger,
            borderRadius: BorderRadius.circular(ProfileTokens.blockRadius),
            border: Border.all(color: ProfileTokens.hairline),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entry.errorMessage!,
                  style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Material(transparent) carrying the elevation, Ink carrying the gradient,
    // so the ripple draws above the card rather than being lost under it.
    return Material(
      color: Colors.transparent,
      elevation: 4,
      borderRadius: BorderRadius.circular(ProfileTokens.sheetRadius),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: profileCardDecoration(),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(ProfileTokens.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.subject, style: ProfileText.fact),
                const SizedBox(height: 12),
                ...subtitle,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget? _buildRecipientLine(BuildContext context, String label, List<String> recipients) {
    if (recipients.isEmpty) return null;
    return Text.rich(
      TextSpan(
        style: ProfileText.caption,
        children: [
          TextSpan(
            text: '$label: ',
            style: ProfileText.caption.copyWith(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: recipients.join(', ')),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Delivery status as a solid pill: failures on #B91C1C under white (6.47:1),
/// queued or pending on sunriseGold under unityBlue (7.17:1), everything else
/// on unityBlue under white with a white outline (12.51:1).
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();

    final ProfilePillStyle style;
    if (normalized.contains('fail') || normalized.contains('error')) {
      style = ProfilePillStyle.danger;
    } else if (normalized.contains('queue') || normalized.contains('pending')) {
      style = ProfilePillStyle.emphasis;
    } else {
      style = ProfilePillStyle.soft;
    }

    return ProfilePill(label: status, style: style);
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
    return _EmailHistoryPage(
      child: _EmailHistoryCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            profileErrorBanner(
              title: 'Unable to load email history',
              message: message,
            ),
            const SizedBox(height: 16),
            ProfileActionPill(
              icon: Icons.refresh,
              label: 'Try Again',
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

/// The partial sync warning above a list that still has entries: a solid
/// sunriseGold block under unityBlue ink (7.17:1) on its own gradient card.
class _SyncWarningBanner extends StatelessWidget {
  const _SyncWarningBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ProfileSheet(
      children: [
        Padding(
          padding: const EdgeInsets.all(ProfileTokens.cardPadding),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ProfileTokens.emphasisFill,
              borderRadius: BorderRadius.circular(ProfileTokens.blockRadius),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 20, color: ProfileTokens.onEmphasis),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Email sync is experiencing issues',
                        style: TextStyle(
                          color: ProfileTokens.onEmphasis,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        message,
                        style: const TextStyle(
                          color: ProfileTokens.onEmphasis,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MissingProviderView extends StatelessWidget {
  const _MissingProviderView();

  @override
  Widget build(BuildContext context) {
    return _EmailHistoryPage(
      child: _EmailHistoryCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              profileIconTile(Icons.info_outline, size: 64, iconSize: 32),
              const SizedBox(height: 16),
              const Text(
                'Email history unavailable',
                textAlign: TextAlign.center,
                style: ProfileText.value,
              ),
              const SizedBox(height: 8),
              const Text(
                'Email history requires an EmailHistoryProvider above this screen. Please ensure the CRM providers are configured.',
                textAlign: TextAlign.center,
                style: ProfileText.caption,
              ),
            ],
          ),
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
          return '\u2013';
        case 'mdash':
          return '\u2014';
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
