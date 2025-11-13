import 'package:bluebubbles/models/crm/email_thread.dart';
import 'package:bluebubbles/widgets/email_reply_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart'
    show Html, Style, Margins, HtmlPaddings, FontSize;
import 'package:intl/intl.dart';

class EmailDetailScreen extends StatefulWidget {
  const EmailDetailScreen({
    super.key,
    required this.thread,
    this.loadMessages,
    this.onSendReply,
    this.initiallyLoading = false,
    this.error,
    this.initialReplyTo,
  });

  final EmailThread thread;
  final Future<List<EmailMessage>> Function()? loadMessages;
  final Future<void> Function(EmailReplyData data)? onSendReply;
  final bool initiallyLoading;
  final String? error;
  final List<String>? initialReplyTo;

  @override
  State<EmailDetailScreen> createState() => _EmailDetailScreenState();
}

class _EmailDetailScreenState extends State<EmailDetailScreen> {
  static final DateFormat _headerFormat =
      DateFormat.yMMMMd().add_jm();
  static final DateFormat _messageFormat =
      DateFormat.yMMMd().add_jm();

  late List<EmailMessage> _messages;
  bool _loading = false;
  bool _sendingReply = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _messages = List<EmailMessage>.from(widget.thread.messages);
    _error = widget.error;
    if (widget.initiallyLoading) {
      _loading = true;
    }
    if ((widget.initiallyLoading || _messages.isEmpty) &&
        widget.loadMessages != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refreshMessages();
      });
    }
  }

  Future<void> _refreshMessages() async {
    if (widget.loadMessages == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final loaded = await widget.loadMessages!.call();
      if (!mounted) return;
      setState(() {
        _messages = loaded;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _handleReply() async {
    if (widget.onSendReply == null) return;

    final result = await showDialog<EmailReplyData>(
      context: context,
      builder: (context) => EmailReplyDialog(
        threadSubject: widget.thread.subject,
        initialTo: _resolveInitialRecipients(),
      ),
    );

    if (result == null) return;

    setState(() => _sendingReply = true);
    try {
      await widget.onSendReply!(result);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reply sent successfully.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send reply: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _sendingReply = false);
      }
    }
  }

  List<String> _resolveInitialRecipients() {
    final recipients = <String>[];
    final seen = <String>{};

    void add(String? value) {
      final normalized = _normalizeEmail(value);
      if (normalized == null) return;
      final lower = normalized.toLowerCase();
      if (seen.add(lower)) {
        recipients.add(normalized);
      }
    }

    for (final message in _messages.reversed) {
      if (message.isOutgoing) continue;
      final senderEmail = _normalizeEmail(message.sender.address);
      if (senderEmail != null && !_isOrgAddress(senderEmail)) {
        add(senderEmail);
        break;
      }
    }

    final initial = widget.initialReplyTo;
    if (initial != null) {
      for (final email in initial) {
        add(email);
      }
    }

    EmailMessage? lastOutgoing;
    for (final message in _messages.reversed) {
      if (message.isOutgoing) {
        lastOutgoing = message;
        break;
      }
    }
    if (lastOutgoing != null) {
      for (final participant in lastOutgoing.to) {
        add(participant.address);
      }
    }

    for (final participant in widget.thread.participants) {
      final normalized = _normalizeEmail(participant.address);
      if (normalized == null || _isOrgAddress(normalized)) continue;
      add(normalized);
    }

    if (recipients.isEmpty) {
      for (final participant in widget.thread.participants) {
        add(participant.address);
      }
    }

    return recipients;
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
    final colorScheme = Theme.of(context).colorScheme;
    final subject =
        widget.thread.subject.isEmpty ? '(No subject)' : widget.thread.subject;

    return Scaffold(
      appBar: AppBar(
        title: Text(subject),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: widget.loadMessages == null
                ? null
                : () {
                    _refreshMessages();
                  },
          ),
        ],
      ),
      floatingActionButton: widget.onSendReply == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _sendingReply ? null : _handleReply,
              icon: _sendingReply
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.reply_outlined),
              label: Text(_sendingReply ? 'Sending…' : 'Reply'),
            ),
      body: Column(
        children: [
          _buildThreadSummary(context),
          if (_loading && _messages.isNotEmpty)
            const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: _buildMessageList(context, colorScheme),
          ),
        ],
      ),
    );
  }

  Widget _buildThreadSummary(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final latest = widget.thread.latestMessage;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Material(
        elevation: 1,
        borderRadius: BorderRadius.circular(16),
        color: colorScheme.surfaceVariant,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.thread.subject.isEmpty
                          ? '(No subject)'
                          : widget.thread.subject,
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Updated ${_headerFormat.format(widget.thread.updatedAt.toLocal())}',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (widget.thread.unreadCount > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Chip(
                            label: Text('${widget.thread.unreadCount} unread'),
                            backgroundColor: colorScheme.secondaryContainer,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              if (widget.thread.uniqueParticipants.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Participants',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: widget.thread.uniqueParticipants
                      .map((participant) => Chip(
                            label: Text(participant.label),
                            backgroundColor: colorScheme.surface,
                          ))
                      .toList(),
                ),
              ],
              if ((widget.thread.snippet ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  widget.thread.snippet!.trim(),
                  style: textTheme.bodyMedium,
                ),
              ],
              if (latest != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Latest message from ${latest.sender.label}',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  latest.displayBody.isEmpty
                      ? 'No preview available.'
                      : latest.displayBody,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageList(BuildContext context, ColorScheme colorScheme) {
    if (_loading && _messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final onRefresh = widget.loadMessages == null ? null : _refreshMessages;

    final items = <Widget>[];

    if (_error != null) {
      items.add(
        Card(
          color: colorScheme.errorContainer,
          child: ListTile(
            leading: Icon(Icons.error_outline, color: colorScheme.error),
            title: const Text('Unable to load conversation'),
            subtitle: Text(_error!),
            trailing: onRefresh == null
                ? null
                : IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _refreshMessages,
                  ),
          ),
        ),
      );
    }

    if (_messages.isEmpty && !_loading) {
      items.add(
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.mail_outline,
                    size: 36, color: colorScheme.onSurfaceVariant),
                const SizedBox(height: 12),
                Text(
                  'No messages yet',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Replies and previous emails will show up here.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    items.addAll(_messages.map(_buildMessageCard));

    final listView = ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      physics: onRefresh != null
          ? const AlwaysScrollableScrollPhysics()
          : null,
      itemBuilder: (context, index) => items[index],
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemCount: items.length,
    );

    if (onRefresh != null) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: listView,
      );
    }

    return listView;
  }

  Widget _buildMessageCard(EmailMessage message) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isOutgoing = message.isOutgoing;
    final backgroundColor = isOutgoing
        ? colorScheme.primaryContainer
        : colorScheme.surfaceVariant;
    final borderColor = isOutgoing
        ? colorScheme.primary.withOpacity(0.4)
        : colorScheme.outlineVariant;

    return Card(
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isOutgoing ? Icons.north_east : Icons.south_west,
                  color: isOutgoing
                      ? colorScheme.primary
                      : colorScheme.secondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.sender.label,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _messageFormat.format(message.sentAt.toLocal()),
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (message.to.isNotEmpty)
              _buildAddressRow('To', message.to),
            if (message.cc.isNotEmpty) ...[
              const SizedBox(height: 4),
              _buildAddressRow('CC', message.cc),
            ],
            if (message.subject != null && message.subject!.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  message.subject!,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            if ((message.htmlBody ?? '').trim().isNotEmpty)
              Html(
                data: message.htmlBody!,
                style: {
                  'body': Style(
                    margin: Margins.zero,
                    padding: HtmlPaddings.zero,
                    color: colorScheme.onSurface,
                    fontSize: FontSize(textTheme.bodyMedium?.fontSize ?? 14),
                    fontFamily: textTheme.bodyMedium?.fontFamily,
                  ),
                },
              )
            else if ((message.plainTextBody ?? '').trim().isNotEmpty)
              SelectableText(
                message.plainTextBody!,
                style: textTheme.bodyMedium,
              )
            else
              Text(
                'No content available for this message.',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressRow(String label, List<EmailParticipant> participants) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 32,
          child: Text(
            label,
            style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: participants
                .map((participant) => Chip(
                      label: Text(participant.label),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}
