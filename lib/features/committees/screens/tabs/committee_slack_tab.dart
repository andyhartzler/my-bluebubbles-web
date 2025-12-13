import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/app/wrappers/titlebar_wrapper.dart';
import 'package:bluebubbles/features/committees/models/committee.dart';
import 'package:bluebubbles/features/committees/services/committee_repository.dart';
import 'package:bluebubbles/features/slack/widgets/slack_file_attachment.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/screens/crm/member_detail_screen.dart';
import 'package:bluebubbles/services/crm/member_repository.dart';
import 'package:bluebubbles/utils/slack_message_formatter.dart';

/// MOHSDA Executive Board channel ID
const String _mohsdaChannelId = 'C0993N7R2BZ';

class CommitteeSlackTab extends StatefulWidget {
  final Committee committee;

  const CommitteeSlackTab({super.key, required this.committee});

  @override
  State<CommitteeSlackTab> createState() => _CommitteeSlackTabState();
}

class _CommitteeSlackTabState extends State<CommitteeSlackTab>
    with SingleTickerProviderStateMixin {
  final CommitteeRepository _repository = CommitteeRepository();
  final MemberRepository _memberRepository = MemberRepository();
  final DateFormat _timestampFormat = DateFormat('MMM d, y • h:mm a');

  // Main channel state
  List<Map<String, dynamic>> _messages = [];
  String? _channelId;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _offset = 0;
  bool _hasMore = true;

  // MOHSDA channel state (for High School Democrats)
  List<Map<String, dynamic>> _mohsdaMessages = [];
  bool _mohsdaLoading = true;
  bool _mohsdaLoadingMore = false;
  String? _mohsdaError;
  int _mohsdaOffset = 0;
  bool _mohsdaHasMore = true;

  // Shared state
  Map<String, Map<String, String>> _slackUserMappings = {};
  Map<String, Member> _memberCache = {};

  // Tab controller for committees with multiple channels
  TabController? _tabController;

  static const int _pageSize = 50;

  Committee get committee => widget.committee;

  /// Check if this committee has the MOHSDA sub-tab
  bool get _hasMohsdaTab => committee.id == 'High School Democrats';

  @override
  void initState() {
    super.initState();
    if (_hasMohsdaTab) {
      _tabController = TabController(length: 2, vsync: this);
    }
    _loadInitial();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = null;
      _offset = 0;
      _hasMore = true;
      if (_hasMohsdaTab) {
        _mohsdaLoading = true;
        _mohsdaError = null;
        _mohsdaOffset = 0;
        _mohsdaHasMore = true;
      }
    });

    try {
      // Load channel ID, messages, and user mappings in parallel
      final futures = <Future>[
        _repository.getSlackChannelId(committee.name),
        _repository.getSlackMessages(
          committee.name,
          limit: _pageSize,
          offset: 0,
        ),
        _repository.getSlackUserMappings(),
      ];

      // Add MOHSDA messages fetch if applicable
      if (_hasMohsdaTab) {
        futures.add(_repository.getSlackMessagesByChannelId(
          _mohsdaChannelId,
          limit: _pageSize,
          offset: 0,
        ));
      }

      final results = await Future.wait(futures);

      final channelId = results[0] as String?;
      final messages = results[1] as List<Map<String, dynamic>>;
      final userMappings = results[2] as Map<String, Map<String, String>>;

      List<Map<String, dynamic>>? mohsdaMessages;
      if (_hasMohsdaTab) {
        mohsdaMessages = results[3] as List<Map<String, dynamic>>;
      }

      // Fetch member data for users with linked member_id
      await _loadMemberData(userMappings);

      if (!mounted) return;

      setState(() {
        _channelId = channelId;
        _messages = messages;
        _slackUserMappings = userMappings;
        _offset = messages.length;
        _hasMore = messages.length >= _pageSize;
        _loading = false;

        if (_hasMohsdaTab && mohsdaMessages != null) {
          _mohsdaMessages = mohsdaMessages;
          _mohsdaOffset = mohsdaMessages.length;
          _mohsdaHasMore = mohsdaMessages.length >= _pageSize;
          _mohsdaLoading = false;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load Slack messages: $e';
        _loading = false;
        if (_hasMohsdaTab) {
          _mohsdaError = 'Failed to load MOHSDA messages: $e';
          _mohsdaLoading = false;
        }
      });
    }
  }

  /// Load member data for users who have linked member IDs
  Future<void> _loadMemberData(
      Map<String, Map<String, String>> userMappings) async {
    final memberIds = <String>{};
    for (final mapping in userMappings.values) {
      final memberId = mapping['member_id'];
      if (memberId != null && memberId.isNotEmpty) {
        memberIds.add(memberId);
      }
    }

    if (memberIds.isEmpty) return;

    try {
      // Fetch all members in parallel
      final futures =
          memberIds.map((id) => _memberRepository.getMemberById(id));
      final members = await Future.wait(futures);

      for (final member in members) {
        if (member != null) {
          _memberCache[member.id] = member;
        }
      }
    } catch (e) {
      debugPrint('Error loading member data: $e');
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

  Future<void> _loadMoreMohsda() async {
    if (_mohsdaLoadingMore || !_mohsdaHasMore) return;

    setState(() => _mohsdaLoadingMore = true);

    try {
      final messages = await _repository.getSlackMessagesByChannelId(
        _mohsdaChannelId,
        limit: _pageSize,
        offset: _mohsdaOffset,
      );

      if (!mounted) return;

      setState(() {
        _mohsdaMessages.addAll(messages);
        _mohsdaOffset += messages.length;
        _mohsdaHasMore = messages.length >= _pageSize;
        _mohsdaLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _mohsdaLoadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load more messages: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // For High School Democrats, show a TabBar with sub-tabs
    if (_hasMohsdaTab) {
      return _buildTabbedView();
    }

    // For other committees, show the normal view
    return _buildMainChannelView();
  }

  Widget _buildTabbedView() {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Sub-tab bar
        Container(
          color: theme.colorScheme.surface,
          child: TabBar(
            controller: _tabController,
            labelColor: committee.primaryColor,
            unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
            indicatorColor: committee.primaryColor,
            tabs: const [
              Tab(text: 'All High School Democrats'),
              Tab(text: 'MOHSDA Executive Board'),
            ],
          ),
        ),
        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildMainChannelView(),
              _buildMohsdaChannelView(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMainChannelView() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildErrorView(_error!, _loadInitial);
    }

    if (_channelId == null) {
      return _buildNoChannelView();
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
                  return _buildLoadMoreButton(_loadMore, _loadingMore);
                }
                return _buildMessageCard(_messages[index]);
              },
            ),
    );
  }

  Widget _buildMohsdaChannelView() {
    if (_mohsdaLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_mohsdaError != null) {
      return _buildErrorView(_mohsdaError!, _loadInitial);
    }

    return RefreshIndicator(
      onRefresh: _loadInitial,
      child: _mohsdaMessages.isEmpty
          ? _buildEmptyState(channelName: 'MOHSDA Executive Board')
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _mohsdaMessages.length + (_mohsdaHasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _mohsdaMessages.length) {
                  return _buildLoadMoreButton(
                      _loadMoreMohsda, _mohsdaLoadingMore);
                }
                return _buildMessageCard(_mohsdaMessages[index]);
              },
            ),
    );
  }

  Widget _buildErrorView(String error, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoChannelView() {
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
                    color: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.color
                        ?.withOpacity(0.7),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({String? channelName}) {
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
                channelName != null
                    ? 'Messages from the $channelName channel will appear here once archived.'
                    : 'Messages from the Slack channel will appear here once archived.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.color
                          ?.withOpacity(0.7),
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoadMoreButton(VoidCallback onPressed, bool loading) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: OutlinedButton.icon(
          onPressed: loading ? null : onPressed,
          icon: loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.expand_more),
          label: Text(loading ? 'Loading...' : 'Load more'),
        ),
      ),
    );
  }

  Widget _buildMessageCard(Map<String, dynamic> message) {
    final theme = Theme.of(context);
    final messageText = message['message_text']?.toString() ?? '';
    final postedAtStr = message['posted_at']?.toString();
    final postedAt =
        postedAtStr != null ? DateTime.tryParse(postedAtStr) : null;
    final isThreadReply = message['thread_ts'] != null;
    final slackUserId = message['slack_user_id']?.toString();

    // Get user info from our mappings using slack_user_id
    final userMapping =
        slackUserId != null ? _slackUserMappings[slackUserId] : null;
    String? userName;
    String? avatarUrl;
    String? memberId = userMapping?['member_id'];
    Member? linkedMember;

    if (userMapping != null) {
      userName = userMapping['real_name']?.isNotEmpty == true
          ? userMapping['real_name']
          : userMapping['display_name'];
      avatarUrl = userMapping['avatar_url'];

      // If there's a linked member, use their profile photo instead
      if (memberId != null && memberId.isNotEmpty) {
        linkedMember = _memberCache[memberId];
        if (linkedMember != null) {
          final memberPhotoUrl = linkedMember.primaryProfilePhotoUrl;
          if (memberPhotoUrl != null && memberPhotoUrl.isNotEmpty) {
            avatarUrl = memberPhotoUrl;
          }
          userName = linkedMember.name;
        }
      }
    }

    final canNavigate = linkedMember != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: canNavigate ? () => _navigateToMemberProfile(linkedMember!) : null,
        borderRadius: BorderRadius.circular(12),
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
                    backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                        ? NetworkImage(avatarUrl)
                        : null,
                    backgroundColor: committee.primaryColor.withOpacity(0.2),
                    child: avatarUrl == null || avatarUrl.isEmpty
                        ? Icon(Icons.person,
                            size: 20, color: committee.primaryColor)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                userName ?? 'Unknown User',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  decoration: canNavigate
                                      ? TextDecoration.underline
                                      : null,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (canNavigate) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.open_in_new,
                                size: 14,
                                color: theme.colorScheme.primary,
                              ),
                            ],
                          ],
                        ),
                        if (postedAt != null)
                          Text(
                            _timestampFormat.format(postedAt.toLocal()),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.textTheme.bodySmall?.color
                                  ?.withOpacity(0.6),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (isThreadReply)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: committee.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.reply,
                              size: 14, color: committee.primaryColor),
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

              // Message text with parsed formatting
              _buildMessageText(messageText, theme),

              // File attachments
              _buildFileAttachments(message),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileAttachments(Map<String, dynamic> message) {
    final hasFiles = message['has_files'] == true;
    if (!hasFiles) return const SizedBox.shrink();

    // Try to use files_archived (has Supabase URLs)
    final filesArchived = message['files_archived'];
    final archivedFiles = parseArchivedFiles(filesArchived);

    if (archivedFiles.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: SlackFileAttachments(files: archivedFiles),
      );
    }

    // Fallback to showing a simple indicator if only files is available
    final theme = Theme.of(context);
    final files = message['files'] as List<dynamic>?;
    final fileCount = files?.length ?? 1;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.attach_file,
                size: 14, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              '$fileCount file${fileCount > 1 ? 's' : ''} attached',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build message text with parsed Slack formatting (links, bold, mentions, emojis)
  Widget _buildMessageText(String messageText, ThemeData theme) {
    if (messageText.isEmpty) {
      return Text(
        '[No text content]',
        style: theme.textTheme.bodyMedium?.copyWith(
          fontStyle: FontStyle.italic,
          color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
        ),
      );
    }

    // Use SlackMessageFormatter to parse the message
    final spans = SlackMessageFormatter.parse(
      messageText,
      baseStyle: theme.textTheme.bodyMedium ?? const TextStyle(),
      linkColor: theme.colorScheme.primary,
      mentionColor: committee.primaryColor,
      userMappings: _slackUserMappings,
      onMentionTap: (userId, memberId) {
        if (memberId != null && memberId.isNotEmpty) {
          _navigateToMemberProfileById(memberId);
        }
      },
    );

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

  /// Navigate to member profile screen from a Member object
  void _navigateToMemberProfile(Member member) {
    Navigator.of(context).push(
      ThemeSwitcher.buildPageRoute(
        builder: (context) => TitleBarWrapper(
          child: MemberDetailScreen(member: member),
        ),
      ),
    );
  }

  /// Navigate to member profile screen by member ID
  Future<void> _navigateToMemberProfileById(String memberId) async {
    // Check cache first
    Member? member = _memberCache[memberId];

    if (member == null) {
      try {
        member = await _memberRepository.getMemberById(memberId);
        if (member != null) {
          _memberCache[memberId] = member;
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading member: $e')),
          );
        }
        return;
      }
    }

    if (member != null && mounted) {
      Navigator.of(context).push(
        ThemeSwitcher.buildPageRoute(
          builder: (context) => TitleBarWrapper(
            child: MemberDetailScreen(member: member!),
          ),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Member not found')),
      );
    }
  }
}
