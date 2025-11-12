import 'package:bluebubbles/models/crm/email_thread.dart';
import 'package:bluebubbles/widgets/email_detail_screen.dart';
import 'package:bluebubbles/widgets/email_thread_card.dart';
import 'package:flutter/material.dart';

class EmailHistoryTab extends StatelessWidget {
  const EmailHistoryTab({
    super.key,
    required this.threads,
    this.isLoading = false,
    this.error,
    this.onRefresh,
    this.onOpenThread,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 24),
  });

  final List<EmailThread> threads;
  final bool isLoading;
  final String? error;
  final Future<void> Function()? onRefresh;
  final ValueChanged<EmailThread>? onOpenThread;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    if (isLoading && threads.isEmpty && error == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final colorScheme = Theme.of(context).colorScheme;
    final onRefresh = this.onRefresh;

    final cards = <Widget>[];

    if (error != null) {
      cards.add(
        Card(
          color: colorScheme.errorContainer,
          child: ListTile(
            leading: Icon(Icons.error_outline, color: colorScheme.error),
            title: const Text('Unable to load email history'),
            subtitle: Text(error!),
            trailing: onRefresh == null
                ? null
                : IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () async {
                      await onRefresh();
                    },
                  ),
          ),
        ),
      );
    }

    if (!isLoading && error == null && threads.isEmpty) {
      cards.add(
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.mark_email_read_outlined,
                  size: 42,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 12),
                Text(
                  'No email history yet',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Sent and received emails will appear here once available.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    cards.addAll(
      threads.map(
        (thread) => EmailThreadCard(
          thread: thread,
          onTap: () => _openThread(context, thread),
        ),
      ),
    );

    final listView = ListView.separated(
      padding: padding,
      physics:
          onRefresh != null ? const AlwaysScrollableScrollPhysics() : null,
      itemBuilder: (context, index) => cards[index],
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemCount: cards.length,
    );

    final scrollable = onRefresh != null
        ? RefreshIndicator(
            onRefresh: onRefresh,
            child: listView,
          )
        : listView;

    if (!isLoading || threads.isEmpty) {
      return scrollable;
    }

    return Stack(
      children: [
        scrollable,
        const Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: LinearProgressIndicator(minHeight: 2),
        ),
      ],
    );
  }

  void _openThread(BuildContext context, EmailThread thread) {
    if (onOpenThread != null) {
      onOpenThread!(thread);
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EmailDetailScreen(thread: thread),
      ),
    );
  }
}
