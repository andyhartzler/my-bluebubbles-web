import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/app/wrappers/titlebar_wrapper.dart';
import 'package:bluebubbles/features/committees/widgets/cors_aware_avatar.dart';
import 'package:bluebubbles/features/slack/screens/slack_management_screen.dart';
import 'package:bluebubbles/features/slack/services/slack_management_repository.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/models/crm/slack_activity.dart';
import 'package:bluebubbles/screens/crm/member_detail/slack_user_search_screen.dart';
import 'package:bluebubbles/screens/crm/member_detail_screen.dart';
import 'package:bluebubbles/services/crm/slack_activity_service.dart';
import 'package:bluebubbles/utils/slack_message_formatter.dart';

class SlackActivityTab extends StatefulWidget {
  const SlackActivityTab({
    super.key,
    required this.member,
    this.onLinked,
  });

  final Member member;
  final Future<void> Function()? onLinked;

  @override
  State<SlackActivityTab> createState() => _SlackActivityTabState();
}

class _SlackActivityTabState extends State<SlackActivityTab> {
  final SlackActivityService _slackService = SlackActivityService.instance;
  final SlackManagementRepository _slackRepo = SlackManagementRepository();
  final List<SlackMessage> _messages = [];
  final DateFormat _timestampFormat = DateFormat('MMM d, y • h:mm a');

  SlackActivityStatistics? _statistics;
  SlackProfile? _profile;
  Map<String, Map<String, String>> _userMappings = {};
  Map<String, Member> _memberCache = {};
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  int _offset = 0;
  static const int _pageSize = 50;
  bool _hasMore = false;
  bool _linkingSlackAccount = false;

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
      final profileFuture = _slackService.fetchSlackProfile(widget.member.id);
      final userMappingsFuture = _slackRepo.getSlackUserMappings();
      final activity = await _slackService.fetchMemberMessages(
        memberId: widget.member.id,
        limit: _pageSize,
        offset: 0,
      );
      final profile = await profileFuture;
      final userMappings = await userMappingsFuture;

      if (!mounted) return;

      setState(() {
        _profile = profile;
        _statistics = activity.statistics;
        _userMappings = userMappings;
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
        memberId: widget.member.id,
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
    final shouldShowLinkButton = widget.member.slackUserId == null;

    // Prioritize member's main profile photo, fall back to Slack avatar
    final avatarUrl = widget.member.primaryProfilePhotoUrl ?? profile?.avatarUrl;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CorsAwareAvatar(
              imageUrl: avatarUrl,
              radius: 28,
              fallbackText: widget.member.name,
              fallbackIcon: Icons.chat_bubble_outline,
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
                  if (shouldShowLinkButton)
                    Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: _linkingSlackAccount ? null : _openSlackLinker,
                          icon: _linkingSlackAccount
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.link),
                          label: Text(
                            _linkingSlackAccount ? 'Opening…' : 'Link Slack Account',
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSlackLinker() async {
    setState(() => _linkingSlackAccount = true);
    try {
      final linked = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (context) => SlackUserSearchScreen(member: widget.member),
        ),
      );

      if (linked == true) {
        final callback = widget.onLinked;
        if (callback != null) {
          await callback();
        }
        await _loadInitial();
      }
    } finally {
      if (mounted) {
        setState(() => _linkingSlackAccount = false);
      }
    }
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
    final theme = Theme.of(context);
    final channelLabel = message.channelInfo?.committeeName?.isNotEmpty == true
        ? message.channelInfo!.committeeName!
        : message.channelInfo?.channelName ?? 'Unknown channel';
    final hasChannelId = message.slackChannelId != null && message.slackChannelId!.isNotEmpty;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: hasChannelId
            ? () => _navigateToChannel(message.slackChannelId!)
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFormattedMessageText(context, message.text, theme),
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
                      Text(
                        channelLabel,
                        style: hasChannelId
                            ? TextStyle(
                                color: theme.colorScheme.primary,
                                decoration: TextDecoration.underline,
                              )
                            : null,
                      ),
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
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.reply, size: 16),
                        SizedBox(width: 4),
                        Text('Thread reply'),
                      ],
                    ),
                  if (message.hasFiles)
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.attach_file, size: 16),
                        SizedBox(width: 4),
                        Text('Includes files'),
                      ],
                    ),
                  if (hasChannelId)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.open_in_new, size: 14, color: theme.colorScheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          'View in channel',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              if (message.reactions.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildReactions(context, message.reactions),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToChannel(String channelId) {
    Navigator.of(context).push(
      ThemeSwitcher.buildPageRoute(
        builder: (context) => TitleBarWrapper(
          child: SlackManagementScreen(initialChannelId: channelId),
        ),
      ),
    );
  }

  Widget _buildFormattedMessageText(BuildContext context, String? text, ThemeData theme) {
    if (text == null || text.trim().isEmpty) {
      return Text(
        'No message text provided',
        style: theme.textTheme.bodyLarge?.copyWith(
          fontStyle: FontStyle.italic,
          color: theme.textTheme.bodyLarge?.color?.withOpacity(0.6),
        ),
      );
    }

    // Use SlackMessageFormatter to parse the message
    final spans = SlackMessageFormatter.parse(
      text,
      baseStyle: theme.textTheme.bodyLarge ?? const TextStyle(),
      linkColor: theme.colorScheme.primary,
      mentionColor: theme.colorScheme.primary,
      userMappings: _userMappings,
      onMentionTap: (userId, memberId) {
        if (memberId != null && memberId.isNotEmpty) {
          _navigateToMember(memberId);
        }
      },
    );

    if (spans.isEmpty) {
      return Text(text, style: theme.textTheme.bodyLarge);
    }

    return RichText(text: TextSpan(children: spans));
  }

  Widget _buildReactions(BuildContext context, List<SlackReaction> reactions) {
    final theme = Theme.of(context);

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: reactions.map((reaction) {
        // Convert emoji shortcode to Unicode
        final emojiOrName = _getEmojiDisplay(reaction.name);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                emojiOrName,
                style: const TextStyle(fontSize: 14),
              ),
              if (reaction.count > 1) ...[
                const SizedBox(width: 4),
                Text(
                  '${reaction.count}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  String _getEmojiDisplay(String name) {
    // Common emoji mappings
    const emojiMap = {
      'thumbsup': '\u{1F44D}',
      '+1': '\u{1F44D}',
      'thumbsdown': '\u{1F44E}',
      '-1': '\u{1F44E}',
      'heart': '\u{2764}\u{FE0F}',
      'tada': '\u{1F389}',
      'fire': '\u{1F525}',
      'rocket': '\u{1F680}',
      'eyes': '\u{1F440}',
      '100': '\u{1F4AF}',
      'clap': '\u{1F44F}',
      'pray': '\u{1F64F}',
      'wave': '\u{1F44B}',
      'smile': '\u{1F604}',
      'joy': '\u{1F602}',
      'sob': '\u{1F62D}',
      'thinking_face': '\u{1F914}',
      'raised_hands': '\u{1F64C}',
      'ok_hand': '\u{1F44C}',
      'muscle': '\u{1F4AA}',
      'sparkles': '\u{2728}',
      'star': '\u{2B50}',
      'white_check_mark': '\u{2705}',
      'heavy_check_mark': '\u{2714}\u{FE0F}',
      'x': '\u{274C}',
      'bangbang': '\u{203C}\u{FE0F}',
      'warning': '\u{26A0}\u{FE0F}',
      'question': '\u{2753}',
      'exclamation': '\u{2757}',
      'bulb': '\u{1F4A1}',
      'memo': '\u{1F4DD}',
      'point_up': '\u{261D}\u{FE0F}',
      'point_down': '\u{1F447}',
      'point_right': '\u{1F449}',
      'point_left': '\u{1F448}',
      'sunglasses': '\u{1F60E}',
      'party_popper': '\u{1F389}',
      'confetti_ball': '\u{1F38A}',
      'balloon': '\u{1F388}',
    };

    return emojiMap[name] ?? ':$name:';
  }

  Future<void> _navigateToMember(String memberId) async {
    final member = await _slackRepo.getMemberById(memberId);
    if (member != null && mounted) {
      Navigator.of(context).push(
        ThemeSwitcher.buildPageRoute(
          builder: (context) => TitleBarWrapper(
            child: MemberDetailScreen(member: member),
          ),
        ),
      );
    }
  }

  String _formatTimestamp(DateTime dateTime) {
    return _timestampFormat.format(dateTime.toLocal());
  }
}
