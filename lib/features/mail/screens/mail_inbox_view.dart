import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/features/mail/models/mail_message.dart';
import 'package:bluebubbles/features/mail/providers/mail_inbox_provider.dart';
import 'package:bluebubbles/features/mail/screens/mail_thread_view.dart';

class MailInboxView extends StatefulWidget {
  const MailInboxView({super.key});

  @override
  State<MailInboxView> createState() => _MailInboxViewState();
}

class _MailInboxViewState extends State<MailInboxView> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    final inbox = context.read<MailInboxProvider>();
    if (!_scroll.hasClients) return;
    final distFromBottom =
        _scroll.position.maxScrollExtent - _scroll.position.pixels;
    if (distFromBottom < 240 && inbox.hasMore && !inbox.loadingMore) {
      inbox.loadMore();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inbox = context.watch<MailInboxProvider>();
    if (inbox.loading && inbox.messages.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(Colors.white),
        ),
      );
    }
    if (inbox.error != null && inbox.messages.isEmpty) {
      return _ErrorState(error: inbox.error!, onRetry: inbox.refresh);
    }
    if (inbox.messages.isEmpty) {
      return const _EmptyState();
    }
    return RefreshIndicator(
      color: Colors.white,
      backgroundColor: BrandColors.unityBlue,
      onRefresh: inbox.refresh,
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: inbox.messages.length + (inbox.hasMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i >= inbox.messages.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
              ),
            );
          }
          final msg = inbox.messages[i];
          return _InboxRow(
            message: msg,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MailThreadView(
                  threadId: msg.threadId,
                  initialSubject: msg.subject,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _InboxRow extends StatelessWidget {
  const _InboxRow({required this.message, required this.onTap});

  final MailMessage message;
  final VoidCallback onTap;

  String _initials() {
    final disp = message.fromDisplay;
    if (disp.isEmpty) {
      final addr = message.fromAddress;
      return addr.isEmpty ? '?' : addr[0].toUpperCase();
    }
    final parts = disp.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return disp[0].toUpperCase();
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final isToday =
        now.year == d.year && now.month == d.month && now.day == d.day;
    if (isToday) {
      final h = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
      final m = d.minute.toString().padLeft(2, '0');
      final ap = d.hour >= 12 ? 'pm' : 'am';
      return '$h:$m$ap';
    }
    final yest = now.subtract(const Duration(days: 1));
    if (yest.year == d.year && yest.month == d.month && yest.day == d.day) {
      return 'Yesterday';
    }
    if (now.difference(d).inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[d.weekday - 1];
    }
    return '${d.month}/${d.day}/${d.year.toString().substring(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final unread = message.isUnread;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(unread ? 0.12 : 0.08),
            borderRadius: BorderRadius.circular(12),
            border: unread
                ? Border.all(
                    color: BrandColors.sunriseGold.withOpacity(0.55),
                    width: 1,
                  )
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: BrandColors.unityBlue,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  _initials(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            message.fromDisplay.isNotEmpty
                                ? message.fromDisplay
                                : message.fromAddress,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight:
                                  unread ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDate(message.internalDate),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.78),
                            fontSize: 12,
                            fontWeight: unread
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message.subject.isEmpty
                          ? '(no subject)'
                          : message.subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.92),
                        fontSize: 13,
                        fontWeight:
                            unread ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    if (message.snippet.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        message.snippet,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.70),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (unread)
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: BrandColors.sunriseGold,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 56,
            color: Colors.white.withOpacity(0.6),
          ),
          const SizedBox(height: 12),
          const Text(
            'Inbox is empty',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Mail to your alias will appear here',
            style: TextStyle(
              color: Colors.white.withOpacity(0.75),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Colors.white.withOpacity(0.85),
          ),
          const SizedBox(height: 12),
          const Text(
            'Could not load mail',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.78),
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, color: Colors.white),
            label: const Text(
              'Retry',
              style: TextStyle(color: Colors.white),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.white.withOpacity(0.7)),
            ),
          ),
        ],
      ),
    );
  }
}
