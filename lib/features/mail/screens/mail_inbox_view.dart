import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/features/mail/_tmail/model/email/presentation_email.dart';
import 'package:bluebubbles/features/mail/_tmail/model/mailbox/select_mode.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/thread/presentation/widgets/email_tile_builder.dart' as mobile_tile;
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/thread/presentation/widgets/email_tile_web_builder.dart' as web_tile;
import 'package:bluebubbles/features/mail/providers/mail_inbox_provider.dart';
import 'package:bluebubbles/features/mail/screens/mail_thread_view.dart';
import 'package:bluebubbles/features/mail/services/tmail_bridge.dart';

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
    ensureTmailGetXBindings();
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

  void _openThread(BuildContext context, PresentationEmail email) {
    final tid = email.threadId?.id.value;
    if (tid == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MailThreadView(
          threadId: tid,
          initialSubject: email.subject,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inbox = context.watch<MailInboxProvider>();
    final isWide = MediaQuery.of(context).size.width >= 768;
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
      child: Material(
        // tmail's EmailTileBuilder is built around Material ListTiles. Wrap
        // in a white-surface Material so the forked widgets render on the
        // background they expect. The tmail visual chrome is preserved
        // verbatim — only the surrounding shell is ours.
        color: Colors.white,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
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
                        valueColor: AlwaysStoppedAnimation(
                          BrandColors.unityBlue,
                        ),
                      ),
                    ),
                  ),
                );
              }
              final msg = inbox.messages[i];
              final pe = toPresentationEmail(msg);
              if (isWide) {
                return web_tile.EmailTileBuilder(
                  presentationEmail: pe,
                  selectAllMode: SelectMode.INACTIVE,
                  isShowingEmailContent: false,
                  emailActionClick: (action, email) => _openThread(context, email),
                );
              } else {
                return mobile_tile.EmailTileBuilder(
                  presentationEmail: pe,
                  selectAllMode: SelectMode.INACTIVE,
                  isShowingEmailContent: false,
                  emailActionClick: (action, email) => _openThread(context, email),
                );
              }
            },
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
