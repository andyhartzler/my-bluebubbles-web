import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/app/wrappers/titlebar_wrapper.dart';
import 'package:bluebubbles/features/committees/models/committee.dart';
import 'package:bluebubbles/features/committees/services/committee_repository.dart';
import 'package:bluebubbles/screens/crm/member_detail_screen.dart';
import 'package:bluebubbles/services/crm/member_repository.dart';

class CommitteeSlackTab extends StatefulWidget {
  final Committee committee;

  const CommitteeSlackTab({super.key, required this.committee});

  @override
  State<CommitteeSlackTab> createState() => _CommitteeSlackTabState();
}

class _CommitteeSlackTabState extends State<CommitteeSlackTab> {
  final CommitteeRepository _repository = CommitteeRepository();
  final MemberRepository _memberRepository = MemberRepository();
  final DateFormat _timestampFormat = DateFormat('MMM d, y • h:mm a');

  List<Map<String, dynamic>> _messages = [];
  Map<String, Map<String, String>> _slackUserMappings = {};
  String? _channelId;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _offset = 0;
  static const int _pageSize = 50;
  bool _hasMore = true;

  // Regex to match Slack user mentions like <@U0A2FQDCGMP>
  static final RegExp _mentionRegex = RegExp(r'<@([A-Z0-9]+)>');

  Committee get committee => widget.committee;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = null;
      _offset = 0;
      _hasMore = true;
    });

    try {
      // Load channel ID, messages, and user mappings in parallel
      final results = await Future.wait([
        _repository.getSlackChannelId(committee.name),
        _repository.getSlackMessages(
          committee.name,
          limit: _pageSize,
          offset: 0,
        ),
        _repository.getSlackUserMappings(),
      ]);

      final channelId = results[0] as String?;
      final messages = results[1] as List<Map<String, dynamic>>;
      final userMappings = results[2] as Map<String, Map<String, String>>;

      if (!mounted) return;

      setState(() {
        _channelId = channelId;
        _messages = messages;
        _slackUserMappings = userMappings;
        _offset = messages.length;
        _hasMore = messages.length >= _pageSize;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load Slack messages: $e';
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;

    setState(() => _loadingMore = true);

    try {
      final messages = await _repository.getSlackMessages(
        committee.name,
        limit: _pageSize,
        offset: _offset,
      );

      if (!mounted) return;

      setState(() {
        _messages.addAll(messages);
        _offset += messages.length;
        _hasMore = messages.length >= _pageSize;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load more messages: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadInitial,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_channelId == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 64,
                color: Theme.of(context).disabledColor,
              ),
              const SizedBox(height: 16),
              Text(
                'No Slack channel linked',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'This committee does not have a Slack channel configured.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInitial,
      child: _messages.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  return _buildLoadMoreButton();
                }
                return _buildMessageCard(_messages[index]);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.inbox_outlined,
                size: 64,
                color: Theme.of(context).disabledColor,
              ),
              const SizedBox(height: 16),
              Text(
                'No messages yet',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Messages from the Slack channel will appear here once archived.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoadMoreButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: OutlinedButton.icon(
          onPressed: _loadingMore ? null : _loadMore,
          icon: _loadingMore
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.expand_more),
          label: Text(_loadingMore ? 'Loading...' : 'Load more'),
        ),
      ),
    );
  }

  Widget _buildMessageCard(Map<String, dynamic> message) {
    final theme = Theme.of(context);
    final messageText = message['message_text']?.toString() ?? '';
    final postedAtStr = message['posted_at']?.toString();
    final postedAt = postedAtStr != null ? DateTime.tryParse(postedAtStr) : null;
    final isThreadReply = message['thread_ts'] != null;

    // Get user info from joined table
    final userMapping = message['slack_user_mapping'];
    String? userName;
    String? avatarUrl;

    if (userMapping is Map) {
      userName = userMapping['real_name']?.toString() ?? userMapping['display_name']?.toString();
      avatarUrl = userMapping['avatar_url']?.toString();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                  backgroundColor: committee.primaryColor.withOpacity(0.2),
                  child: avatarUrl == null
                      ? Icon(Icons.person, size: 20, color: committee.primaryColor)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName ?? 'Unknown User',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (postedAt != null)
                        Text(
                          _timestampFormat.format(postedAt.toLocal()),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                          ),
                        ),
                    ],
                  ),
                ),
                if (isThreadReply)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: committee.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.reply, size: 14, color: committee.primaryColor),
                        const SizedBox(width: 4),
                        Text(
                          'Thread',
                          style: TextStyle(
                            fontSize: 11,
                            color: committee.primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Message text with parsed mentions
            _buildMessageText(messageText, theme),
          ],
        ),
      ),
    );
  }

  /// Build message text with clickable user mentions
  Widget _buildMessageText(String messageText, ThemeData theme) {
    if (messageText.isEmpty) {
      return Text(
        '[No text content]',
        style: theme.textTheme.bodyMedium,
      );
    }

    // Parse mentions and build rich text
    final spans = <InlineSpan>[];
    int lastMatchEnd = 0;

    for (final match in _mentionRegex.allMatches(messageText)) {
      // Add text before this match
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: messageText.substring(lastMatchEnd, match.start),
          style: theme.textTheme.bodyMedium,
        ));
      }

      // Get the Slack user ID from the match
      final slackUserId = match.group(1);
      final userInfo = slackUserId != null ? _slackUserMappings[slackUserId] : null;
      final displayName = userInfo?['real_name']?.isNotEmpty == true
          ? userInfo!['real_name']!
          : (userInfo?['display_name']?.isNotEmpty == true
              ? userInfo!['display_name']!
              : '@$slackUserId');
      final memberId = userInfo?['member_id'];

      // Add clickable mention span
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: _buildMentionChip(displayName, memberId, userInfo?['avatar_url']),
      ));

      lastMatchEnd = match.end;
    }

    // Add any remaining text after the last match
    if (lastMatchEnd < messageText.length) {
      spans.add(TextSpan(
        text: messageText.substring(lastMatchEnd),
        style: theme.textTheme.bodyMedium,
      ));
    }

    // If no mentions found, just return plain text
    if (spans.isEmpty) {
      return Text(
        messageText,
        style: theme.textTheme.bodyMedium,
      );
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }

  /// Build a clickable chip for a user mention
  Widget _buildMentionChip(String displayName, String? memberId, String? avatarUrl) {
    final hasValidMemberId = memberId != null && memberId.isNotEmpty;

    return GestureDetector(
      onTap: hasValidMemberId ? () => _navigateToMemberProfile(memberId) : null,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: committee.primaryColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (avatarUrl != null && avatarUrl.isNotEmpty) ...[
              CircleAvatar(
                radius: 8,
                backgroundImage: NetworkImage(avatarUrl),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              '@$displayName',
              style: TextStyle(
                color: committee.primaryColor,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                decoration: hasValidMemberId ? TextDecoration.underline : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Navigate to member profile screen
  Future<void> _navigateToMemberProfile(String memberId) async {
    try {
      final member = await _memberRepository.getMemberById(memberId);
      if (member != null && mounted) {
        Navigator.of(context).push(
          ThemeSwitcher.buildPageRoute(
            builder: (context) => TitleBarWrapper(
              child: MemberDetailScreen(member: member),
            ),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Member not found')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading member: $e')),
        );
      }
    }
  }
}
