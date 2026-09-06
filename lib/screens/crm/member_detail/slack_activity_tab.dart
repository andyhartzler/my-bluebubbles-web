import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/app/wrappers/titlebar_wrapper.dart';
import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/features/committees/widgets/cors_aware_avatar.dart';
import 'package:bluebubbles/features/slack/screens/slack_management_screen.dart';
import 'package:bluebubbles/features/slack/services/slack_management_repository.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/models/crm/slack_activity.dart';
import 'package:bluebubbles/screens/crm/member_detail/slack_user_search_screen.dart';
import 'package:bluebubbles/screens/crm/member_detail_screen.dart';
import 'package:bluebubbles/screens/crm/widgets/member_profile_sections.dart';
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
      // White spinner on the gradient card: 12.51:1 at the dark end and
      // 4.59:1 at the light end, so it clears 3:1 wherever it sits.
      return const _SlackActivityPage(
        child: ProfileSectionCard(
          title: 'Slack Activity',
          icon: Icons.chat_bubble_outline,
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

    if (_error != null) {
      return _SlackActivityPage(
        child: ProfileSectionCard(
          title: 'Slack Activity',
          icon: Icons.chat_bubble_outline,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              profileErrorBanner(
                title: 'Unable to load Slack activity',
                message: _error!,
              ),
              const SizedBox(height: 16),
              ProfileActionPill(
                icon: Icons.refresh,
                label: 'Retry',
                onPressed: _loadInitial,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      color: BrandColors.unityBlue,
      backgroundColor: Colors.white,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: _pagePadding(constraints),
            children: [
              _sheetWidth(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildProfileCard(context),
                    const SizedBox(height: ProfileTokens.cardGap),
                    _buildStatisticsCard(context),
                    const SizedBox(height: ProfileTokens.cardGap),
                    _buildMessagesCard(context),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// The Slack profile as its own section card. Every line is full white; the
  /// link control is the emphasis pill, unityBlue on sunriseGold (7.17:1).
  Widget _buildProfileCard(BuildContext context) {
    final profile = _profile;
    final shouldShowLinkButton = widget.member.slackUserId == null;

    // Prioritize member's main profile photo, fall back to Slack avatar
    final avatarUrl = widget.member.effectiveAvatarUrl ?? profile?.avatarUrl;

    return ProfileSectionCard(
      title: 'Slack Profile',
      icon: Icons.chat_bubble_outline,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 3 px sunriseGold ring, a mark rather than text; the initials
          // fallback is white on solid unityBlue, 12.51:1.
          Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: BrandColors.sunriseGold,
            ),
            child: CorsAwareAvatar(
              imageUrl: avatarUrl,
              radius: 28,
              backgroundColor: ProfileTokens.fill,
              fallbackText: widget.member.name,
              fallbackIcon: Icons.chat_bubble_outline,
              fallbackTextColor: Colors.white,
              fallbackIconColor: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile?.realName ?? profile?.displayName ?? 'Slack not linked',
                  style: ProfileText.value,
                ),
                const SizedBox(height: 4),
                if (profile?.displayName != null)
                  Text('@${profile!.displayName}', style: ProfileText.caption),
                if (profile?.email != null)
                  Text(profile!.email!, style: ProfileText.caption),
                if (profile == null || !(profile.isLinked))
                  const Text(
                    'No Slack profile is linked to this member yet.',
                    style: ProfileText.caption,
                  ),
                if (shouldShowLinkButton)
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: ProfileActionPill(
                        icon: Icons.link,
                        label: _linkingSlackAccount ? 'Opening…' : 'Link Slack Account',
                        onPressed: _linkingSlackAccount ? null : _openSlackLinker,
                        busy: _linkingSlackAccount,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
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

  /// The activity summary as a section card: two stat tiles and the first and
  /// last archived dates as label over value facts, all full white.
  Widget _buildStatisticsCard(BuildContext context) {
    final stats = _statistics;

    if (stats == null) {
      return const ProfileSectionCard(
        title: 'Slack Activity Summary',
        icon: Icons.insights_outlined,
        child: Text(
          'No Slack activity has been archived for this member yet.',
          style: ProfileText.caption,
        ),
      );
    }

    return ProfileSectionCard(
      title: 'Slack Activity Summary',
      icon: Icons.insights_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          if (stats.latestMessage != null || stats.earliestMessage != null) ...[
            const SizedBox(height: 20),
            Wrap(
              spacing: 32,
              runSpacing: 16,
              children: [
                if (stats.latestMessage != null)
                  profileFact('Last activity', _formatTimestamp(stats.latestMessage!)),
                if (stats.earliestMessage != null)
                  profileFact('First archived message', _formatTimestamp(stats.earliestMessage!)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// One stat: the icon on a solid unityBlue tile (white glyph, 12.51:1), the
  /// big white number, and the 11 w700 white label.
  Widget _buildStatisticTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        profileIconTile(icon, size: 48, iconSize: 26),
        const SizedBox(height: 10),
        Text(value, style: ProfileText.statValue),
        const SizedBox(height: 2),
        Text(label.toUpperCase(), style: ProfileText.label),
      ],
    );
  }

  /// The message feed as one section card: each message is a solid unityBlue
  /// row block with a white outline, and the empty state and the load more
  /// control sit inside the same card.
  Widget _buildMessagesCard(BuildContext context) {
    return ProfileSectionCard(
      title: 'Recent Slack Messages',
      icon: Icons.forum_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_messages.isEmpty)
            _buildEmptyState(context)
          else
            ...[
              for (var i = 0; i < _messages.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                _buildMessageCard(context, _messages[i]),
              ],
            ],
          if (_hasMore)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Align(
                alignment: Alignment.center,
                child: _buildLoadMoreControl(),
              ),
            ),
        ],
      ),
    );
  }

  /// White outline button while idle; a white spinner and caption while the
  /// next page loads (white on the card, 12.51:1 to 4.59:1).
  Widget _buildLoadMoreControl() {
    if (_isLoadingMore) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          SizedBox(width: 10),
          Text('Loading…', style: ProfileText.caption),
        ],
      );
    }
    return profileOutlineButton(
      label: 'Load more',
      icon: Icons.expand_more,
      onPressed: _isLoadingMore ? null : _loadMore,
    );
  }

  /// Empty state inside the card: a solid unityBlue icon tile over the 17 and
  /// 15 white lines, centred.
  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          profileIconTile(Icons.inbox_outlined, size: 64, iconSize: 32),
          const SizedBox(height: 16),
          const Text(
            'No Slack messages have been archived for this member.',
            style: ProfileText.value,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Once the Slack archiver captures their activity, it will appear here automatically.',
            style: ProfileText.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// One message as a tappable row block: solid unityBlue with a white outline
  /// (white on it 12.51:1; the outline keeps the block's edge at the card's
  /// dark corner). Text is 15 white, meta lines 15 white, links white and
  /// underlined, reactions solid outlined chips.
  Widget _buildMessageCard(BuildContext context, SlackMessage message) {
    final channelLabel = message.channelInfo?.committeeName?.isNotEmpty == true
        ? message.channelInfo!.committeeName!
        : message.channelInfo?.channelName ?? 'Unknown channel';
    final hasChannelId = message.slackChannelId != null && message.slackChannelId!.isNotEmpty;

    return Material(
      color: ProfileTokens.fill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ProfileTokens.blockRadius),
        side: const BorderSide(color: ProfileTokens.border),
      ),
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
              _buildFormattedMessageText(context, message.text),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.forum_outlined, size: 16, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        channelLabel,
                        style: hasChannelId ? ProfileText.link : ProfileText.caption,
                      ),
                    ],
                  ),
                  if (message.postedAt != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.schedule, size: 16, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(_formatTimestamp(message.postedAt!), style: ProfileText.caption),
                      ],
                    ),
                  if (message.isThreadReply)
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.reply, size: 16, color: Colors.white),
                        SizedBox(width: 4),
                        Text('Thread reply', style: ProfileText.caption),
                      ],
                    ),
                  if (message.hasFiles)
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.attach_file, size: 16, color: Colors.white),
                        SizedBox(width: 4),
                        Text('Includes files', style: ProfileText.caption),
                      ],
                    ),
                  if (hasChannelId)
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.open_in_new, size: 14, color: Colors.white),
                        SizedBox(width: 4),
                        Text('View in channel', style: ProfileText.link),
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

  Widget _buildFormattedMessageText(BuildContext context, String? text) {
    if (text == null || text.trim().isEmpty) {
      return Text(
        'No message text provided',
        style: ProfileText.longText.copyWith(fontStyle: FontStyle.italic),
      );
    }

    // Use SlackMessageFormatter to parse the message. Links and mentions are
    // white on the solid unityBlue row (12.51:1); the formatter's mention
    // highlight is white 0.10 over that fill, still 9.23:1 under white.
    final spans = SlackMessageFormatter.parse(
      text,
      baseStyle: ProfileText.longText,
      linkColor: Colors.white,
      mentionColor: Colors.white,
      userMappings: _userMappings,
      onMentionTap: (userId, memberId) {
        if (memberId != null && memberId.isNotEmpty) {
          _navigateToMember(memberId);
        }
      },
    );

    if (spans.isEmpty) {
      return Text(text, style: ProfileText.longText);
    }

    return RichText(text: TextSpan(children: spans));
  }

  Widget _buildReactions(BuildContext context, List<SlackReaction> reactions) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: reactions.map((reaction) {
        // Convert emoji shortcode to Unicode
        final emojiOrName = _getEmojiDisplay(reaction.name);
        return profileChip(
          reaction.count > 1 ? '$emojiOrName ${reaction.count}' : emojiOrName,
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

/// The tab's list padding, matching the Meetings tab: 16 under 768 and 32 by
/// 24 above it.
EdgeInsets _pagePadding(BoxConstraints constraints) {
  final wide = constraints.maxWidth >= 768;
  return wide
      ? const EdgeInsets.symmetric(horizontal: 32, vertical: 24)
      : const EdgeInsets.all(16);
}

/// Centres the tab's content at the profile's 1200 sheet width.
Widget _sheetWidth(Widget child) {
  return Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: ProfileTokens.maxSheetWidth),
      child: child,
    ),
  );
}

/// The tab's scroll frame for a single card: always scrollable so the frame
/// matches the loaded page even when the card is short.
class _SlackActivityPage extends StatelessWidget {
  const _SlackActivityPage({required this.child});

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
