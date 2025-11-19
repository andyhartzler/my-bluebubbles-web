import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:bluebubbles/models/crm/slack_activity.dart';
import 'package:bluebubbles/services/crm/slack_activity_service.dart';

class SlackActivityTab extends StatefulWidget {
  const SlackActivityTab({super.key, required this.memberId});

  final String memberId;

  @override
  State<SlackActivityTab> createState() => _SlackActivityTabState();
}

class _SlackActivityTabState extends State<SlackActivityTab> {
  final SlackActivityService _slackService = SlackActivityService.instance;
  final List<SlackMessage> _messages = [];
  final DateFormat _timestampFormat = DateFormat('MMM d, y • h:mm a');

  SlackActivityStatistics? _statistics;
  SlackProfile? _profile;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  int _offset = 0;
  static const int _pageSize = 50;
  bool _hasMore = false;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final profileFuture = _slackService.fetchSlackProfile(widget.memberId);
      final activity = await _slackService.fetchMemberMessages(
        memberId: widget.memberId,
        limit: _pageSize,
        offset: 0,
      );
      final profile = await profileFuture;

      if (!mounted) return;

      setState(() {
        _profile = profile;
        _statistics = activity.statistics;
        _messages
          ..clear()
          ..addAll(activity.messages);
        _offset = _messages.length;
        _hasMore = activity.totalMessages > _messages.length;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _refresh() async {
    await _loadInitial();
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() {
      _isLoadingMore = true;
    });

    try {
      final activity = await _slackService.fetchMemberMessages(
        memberId: widget.memberId,
        limit: _pageSize,
        offset: _offset,
      );

      if (!mounted) return;

      setState(() {
        _messages.addAll(activity.messages);
        _statistics = activity.statistics ?? _statistics;
        _offset = _messages.length;
        _hasMore = activity.totalMessages > _messages.length;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading more Slack messages: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
              const SizedBox(height: 16),
              const Text('Unable to load Slack activity'),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadInitial,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _buildProfileCard(context),
          const SizedBox(height: 16),
          _buildStatisticsCard(context),
          const SizedBox(height: 16),
          Text(
            'Recent Slack Messages',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (_messages.isEmpty)
            _buildEmptyState(context)
          else
            ...[
              for (final message in _messages) ...[
                _buildMessageCard(context, message),
                const SizedBox(height: 8),
              ],
            ],
          if (_hasMore)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Align(
                alignment: Alignment.center,
                child: OutlinedButton.icon(
                  onPressed: _isLoadingMore ? null : _loadMore,
                  icon: _isLoadingMore
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.expand_more),
                  label: Text(_isLoadingMore ? 'Loading…' : 'Load more'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context) {
    final profile = _profile;
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundImage:
                  profile?.avatarUrl != null ? NetworkImage(profile!.avatarUrl!) : null,
              child: profile?.avatarUrl == null
                  ? const Icon(Icons.chat_bubble_outline)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile?.realName ?? profile?.displayName ?? 'Slack not linked',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  if (profile?.displayName != null)
                    Text('@${profile!.displayName}', style: theme.textTheme.bodyMedium),
                  if (profile?.email != null)
                    Text(profile!.email!, style: theme.textTheme.bodySmall),
                  if (profile == null || !(profile.isLinked))
                    Text(
                      'No Slack profile is linked to this member yet.',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsCard(BuildContext context) {
    final stats = _statistics;

    if (stats == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'No Slack activity has been archived for this member yet.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Slack Activity Summary',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatisticTile(
                  context,
                  icon: Icons.message_outlined,
                  label: 'Messages',
                  value: stats.totalMessages.toString(),
                ),
                _buildStatisticTile(
                  context,
                  icon: Icons.forum_outlined,
                  label: 'Channels',
                  value: stats.channelsActiveIn.toString(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (stats.latestMessage != null)
              Text('Last activity: ${_formatTimestamp(stats.latestMessage!)}'),
            if (stats.earliestMessage != null)
              Text('First archived message: ${_formatTimestamp(stats.earliestMessage!)}'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleLarge),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: Theme.of(context).hintColor),
            const SizedBox(height: 12),
            const Text('No Slack messages have been archived for this member.'),
            const SizedBox(height: 8),
            Text(
              'Once the Slack archiver captures their activity, it will appear here automatically.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageCard(BuildContext context, SlackMessage message) {
    final channelLabel = message.channelInfo?.committeeName?.isNotEmpty == true
        ? message.channelInfo!.committeeName!
        : message.channelInfo?.channelName ?? 'Unknown channel';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text?.trim().isNotEmpty == true
                  ? message.text!
                  : (message.hasFiles
                      ? 'Shared files in Slack'
                      : 'No message text provided'),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.forum_outlined, size: 16),
                    const SizedBox(width: 4),
                    Text(channelLabel),
                  ],
                ),
                if (message.postedAt != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.schedule, size: 16),
                      const SizedBox(width: 4),
                      Text(_formatTimestamp(message.postedAt!)),
                    ],
                  ),
                if (message.isThreadReply)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.reply, size: 16),
                      SizedBox(width: 4),
                      Text('Thread reply'),
                    ],
                  ),
                if (message.hasFiles)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.attach_file, size: 16),
                      SizedBox(width: 4),
                      Text('Includes files'),
                    ],
                  ),
              ],
            ),
            if (message.reactions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final reaction in message.reactions)
                    Chip(
                      label: Text(':${reaction.name}: ${reaction.count}'),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dateTime) {
    return _timestampFormat.format(dateTime.toLocal());
  }
}
