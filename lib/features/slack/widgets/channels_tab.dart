import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/app/wrappers/titlebar_wrapper.dart';
import 'package:bluebubbles/features/slack/models/slack_channel.dart';
import 'package:bluebubbles/features/slack/services/slack_management_repository.dart';
import 'package:bluebubbles/features/slack/widgets/channel_sidebar.dart';
import 'package:bluebubbles/features/slack/widgets/message_bubble.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/screens/crm/member_detail_screen.dart';
import 'package:bluebubbles/services/crm/member_repository.dart';

/// Channels tab displaying Slack messages across all channels
class ChannelsTab extends StatefulWidget {
  const ChannelsTab({super.key, this.initialChannelId});

  /// Optional channel ID to pre-select when opening
  final String? initialChannelId;

  @override
  State<ChannelsTab> createState() => _ChannelsTabState();
}

class _ChannelsTabState extends State<ChannelsTab> {
  final SlackManagementRepository _repository = SlackManagementRepository();
  final MemberRepository _memberRepository = MemberRepository();
  final TextEditingController _searchController = TextEditingController();

  List<SlackChannel> _channels = [];
  SlackChannel? _selectedChannel;
  SlackArchiveStatus? _archiveStatus;
  List<Map<String, dynamic>> _messages = [];
  Map<String, Map<String, String>> _userMappings = {};
  Map<String, Member> _memberCache = {};

  bool _loadingChannels = true;
  bool _loadingMessages = false;
  bool _loadingMore = false;
  bool _syncing = false;
  String? _error;
  int _offset = 0;
  static const int _pageSize = 50;
  bool _hasMore = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadChannels();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadChannels() async {
    setState(() {
      _loadingChannels = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _repository.getChannels(),
        _repository.getSlackUserMappings(),
      ]);

      final channels = results[0] as List<SlackChannel>;
      final userMappings = results[1] as Map<String, Map<String, String>>;

      // Load member data for linked users
      await _loadMemberData(userMappings);

      if (!mounted) return;

      setState(() {
        _channels = channels;
        _userMappings = userMappings;
        _loadingChannels = false;
      });

      // Auto-select channel - prefer initialChannelId if provided
      if (channels.isNotEmpty && _selectedChannel == null) {
        SlackChannel? channelToSelect;
        if (widget.initialChannelId != null) {
          channelToSelect = channels.firstWhere(
            (c) => c.channelId == widget.initialChannelId,
            orElse: () => channels.first,
          );
        } else {
          channelToSelect = channels.first;
        }
        _selectChannel(channelToSelect);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load channels: $e';
        _loadingChannels = false;
      });
    }
  }

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

  Future<void> _selectChannel(SlackChannel channel) async {
    setState(() {
      _selectedChannel = channel;
      _messages = [];
      _offset = 0;
      _hasMore = true;
      _loadingMessages = true;
      _error = null;
      _searchQuery = '';
      _searchController.clear();
    });

    try {
      final results = await Future.wait([
        _repository.getChannelMessages(channel.slackChannelId,
            limit: _pageSize, offset: 0),
        _repository.getArchiveStatus(channel.slackChannelId),
      ]);

      final messages = results[0] as List<Map<String, dynamic>>;
      final archiveStatus = results[1] as SlackArchiveStatus?;

      if (!mounted) return;

      setState(() {
        _messages = messages;
        _archiveStatus = archiveStatus;
        _offset = messages.length;
        _hasMore = messages.length >= _pageSize;
        _loadingMessages = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load messages: $e';
        _loadingMessages = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _selectedChannel == null) return;

    setState(() => _loadingMore = true);

    try {
      final messages = await _repository.getChannelMessages(
        _selectedChannel!.slackChannelId,
        limit: _pageSize,
        offset: _offset,
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
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
        SnackBar(content: Text('Failed to load more: $e')),
      );
    }
  }

  Future<void> _search(String query) async {
    if (_selectedChannel == null) return;

    setState(() {
      _searchQuery = query;
      _messages = [];
      _offset = 0;
      _hasMore = true;
      _loadingMessages = true;
    });

    try {
      final messages = await _repository.getChannelMessages(
        _selectedChannel!.slackChannelId,
        limit: _pageSize,
        offset: 0,
        searchQuery: query.isNotEmpty ? query : null,
      );

      if (!mounted) return;

      setState(() {
        _messages = messages;
        _offset = messages.length;
        _hasMore = messages.length >= _pageSize;
        _loadingMessages = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Search failed: $e';
        _loadingMessages = false;
      });
    }
  }

  Future<void> _triggerSync() async {
    if (_selectedChannel == null || _syncing) return;

    setState(() => _syncing = true);

    try {
      final success =
          await _repository.triggerArchiveSync(_selectedChannel!.slackChannelId);

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Archive sync started. Refresh in a few moments.'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to start archive sync')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _syncing = false);
      }
    }
  }

  void _navigateToMember(Member member) {
    Navigator.of(context).push(
      ThemeSwitcher.buildPageRoute(
        builder: (context) => TitleBarWrapper(
          child: MemberDetailScreen(member: member),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;

    if (_loadingChannels) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _channels.isEmpty) {
      return _buildErrorState();
    }

    if (isMobile) {
      return _buildMobileLayout();
    }

    return _buildDesktopLayout();
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Channel sidebar
        SizedBox(
          width: 280,
          child: Column(
            children: [
              _buildSidebarHeader(),
              Expanded(
                child: ChannelSidebar(
                  channels: _channels,
                  selectedChannelId: _selectedChannel?.slackChannelId,
                  onChannelSelected: _selectChannel,
                ),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        // Message content
        Expanded(
          child: _selectedChannel == null
              ? _buildNoChannelSelected()
              : _buildMessageContent(),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        // Channel dropdown
        Padding(
          padding: const EdgeInsets.all(12),
          child: ChannelDropdown(
            channels: _channels,
            selectedChannel: _selectedChannel,
            onChannelSelected: _selectChannel,
          ),
        ),
        // Message content
        Expanded(
          child: _selectedChannel == null
              ? _buildNoChannelSelected()
              : _buildMessageContent(),
        ),
      ],
    );
  }

  Widget _buildSidebarHeader() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.tag, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            'Channels',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            '${_channels.length}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoChannelSelected() {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: theme.disabledColor,
          ),
          const SizedBox(height: 16),
          Text(
            'Select a channel',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a channel from the list to view messages',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageContent() {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Channel header
        _buildChannelHeader(),
        // Search bar
        _buildSearchBar(),
        // Messages
        Expanded(
          child: _loadingMessages
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _buildErrorState()
                  : _messages.isEmpty
                      ? _buildEmptyMessages()
                      : _buildMessageList(),
        ),
      ],
    );
  }

  Widget _buildChannelHeader() {
    final theme = Theme.of(context);
    final archiveDateFormat = DateFormat('MMM d, y • h:mm a');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.tag, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedChannel!.slackChannelName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      _selectedChannel!.committeeName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (_archiveStatus != null) ...[
                      const SizedBox(width: 8),
                      Text('•', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                      const SizedBox(width: 8),
                      Text(
                        '${_archiveStatus!.totalMessagesArchived} messages archived',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (_archiveStatus?.lastArchiveDate != null)
            Tooltip(
              message:
                  'Last archived: ${archiveDateFormat.format(_archiveStatus!.lastArchiveDate!.toLocal())}',
              child: Chip(
                avatar: const Icon(Icons.archive, size: 16),
                label: Text(
                  archiveDateFormat.format(_archiveStatus!.lastArchiveDate!.toLocal()),
                  style: theme.textTheme.bodySmall,
                ),
                visualDensity: VisualDensity.compact,
              ),
            ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _syncing ? null : _triggerSync,
            icon: _syncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync, size: 18),
            label: Text(_syncing ? 'Syncing...' : 'Sync'),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search messages...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _search('');
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.5),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        onSubmitted: _search,
      ),
    );
  }

  Widget _buildMessageList() {
    return RefreshIndicator(
      onRefresh: () => _selectChannel(_selectedChannel!),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _messages.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _messages.length) {
            return _buildLoadMoreButton();
          }
          return SlackMessageBubble(
            message: _messages[index],
            userMappings: _userMappings,
            memberCache: _memberCache,
            primaryColor: Theme.of(context).colorScheme.primary,
            onMemberTap: _navigateToMember,
          );
        },
      ),
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

  Widget _buildEmptyMessages() {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: theme.disabledColor,
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty ? 'No matching messages' : 'No messages yet',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try a different search term'
                : 'Messages from this channel will appear here once archived.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (_searchQuery.isEmpty) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _syncing ? null : _triggerSync,
              icon: const Icon(Icons.sync),
              label: const Text('Sync Messages'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              _error ?? 'An error occurred',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _selectedChannel != null
                  ? () => _selectChannel(_selectedChannel!)
                  : _loadChannels,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
