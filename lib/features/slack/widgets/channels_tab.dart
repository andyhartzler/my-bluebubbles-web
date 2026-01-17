import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/app/wrappers/titlebar_wrapper.dart';
import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
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

  /// Custom channel sort order - these channels appear first in this order
  static const List<String> _priorityChannelOrder = [
    'general',
    'speak-your-mind',
    'speak_your_mind',
    'speakyourmind',
    'news-channel',
    'news_channel',
    'newschannel',
    'questions-help',
    'questions_help',
    'questionshelp',
    'executive-committee',
    'executive_committee',
    'executivecommittee',
    'mohsda-executive-board',
    'mohsda_executive_board',
    'mohsdaexecutiveboard',
  ];

  /// Sort channels with priority order first, then alphabetically
  List<SlackChannel> _sortChannels(List<SlackChannel> channels) {
    return channels..sort((a, b) {
      final aName = a.slackChannelName.toLowerCase();
      final bName = b.slackChannelName.toLowerCase();

      // Check priority for each channel
      int aPriority = -1;
      int bPriority = -1;

      for (int i = 0; i < _priorityChannelOrder.length; i++) {
        final priority = _priorityChannelOrder[i];
        if (aName == priority ||
            aName.replaceAll('-', '').replaceAll('_', '') ==
                priority.replaceAll('-', '').replaceAll('_', '')) {
          aPriority = i;
          break;
        }
      }

      for (int i = 0; i < _priorityChannelOrder.length; i++) {
        final priority = _priorityChannelOrder[i];
        if (bName == priority ||
            bName.replaceAll('-', '').replaceAll('_', '') ==
                priority.replaceAll('-', '').replaceAll('_', '')) {
          bPriority = i;
          break;
        }
      }

      // If both have priority, sort by priority index
      if (aPriority >= 0 && bPriority >= 0) {
        return aPriority.compareTo(bPriority);
      }

      // If only a has priority, a comes first
      if (aPriority >= 0) return -1;

      // If only b has priority, b comes first
      if (bPriority >= 0) return 1;

      // Neither has priority, sort alphabetically
      return aName.compareTo(bName);
    });
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

      final channels = _sortChannels(results[0] as List<SlackChannel>);
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
            (c) => c.slackChannelId == widget.initialChannelId,
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
    Map<String, Map<String, String>> userMappings,
  ) async {
    final memberIds = <String>{};
    for (final mapping in userMappings.values) {
      final memberId = mapping['member_id'];
      if (memberId != null && memberId.isNotEmpty) {
        memberIds.add(memberId);
      }
    }

    if (memberIds.isEmpty) return;

    try {
      final futures = memberIds.map(
        (id) => _memberRepository.getMemberById(id),
      );
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
        _repository.getChannelMessages(
          channel.slackChannelId,
          limit: _pageSize,
          offset: 0,
        ),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load more: $e')));
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
      final success = await _repository.triggerArchiveSync(
        _selectedChannel!.slackChannelId,
      );

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
        builder: (context) =>
            TitleBarWrapper(child: MemberDetailScreen(member: member)),
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
        // Channel sidebar with brand styling
        Container(
          width: 280,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: BrandColors.tileGradient,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            children: [
              _buildSidebarHeader(),
              Expanded(
                child: _BrandedChannelSidebar(
                  channels: _channels,
                  selectedChannelId: _selectedChannel?.slackChannelId,
                  onChannelSelected: _selectChannel,
                ),
              ),
            ],
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

  Widget _buildMobileLayout() {
    return Column(
      children: [
        // Channel dropdown with brand styling
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: BrandColors.tileGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: _BrandedChannelDropdown(
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.tag, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          const Text(
            'Channels',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_channels.length}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
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
          Icon(Icons.chat_bubble_outline, size: 64, color: theme.disabledColor),
          const SizedBox(height: 16),
          Text('Select a channel', style: theme.textTheme.titleMedium),
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
    final archiveDateFormat = DateFormat('MMM d, y • h:mm a');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: BrandColors.tileGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.tag, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '#${_selectedChannel!.slackChannelName}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      _selectedChannel!.committeeName,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    if (_archiveStatus != null) ...[
                      const SizedBox(width: 8),
                      const Text('•', style: TextStyle(color: Colors.white54)),
                      const SizedBox(width: 8),
                      Text(
                        '${_archiveStatus!.totalMessagesArchived} messages',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (_archiveStatus?.lastArchiveDate != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.archive, size: 14, color: Colors.white70),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat(
                      'MMM d',
                    ).format(_archiveStatus!.lastArchiveDate!.toLocal()),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _syncing ? null : _triggerSync,
            style: ElevatedButton.styleFrom(
              backgroundColor: BrandColors.sunriseGold,
              foregroundColor: BrandColors.unityBlue,
            ),
            icon: _syncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: BrandColors.unityBlue,
                    ),
                  )
                : const Icon(Icons.sync, size: 18),
            label: Text(_syncing ? 'Syncing...' : 'Sync'),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search messages...',
          hintStyle: TextStyle(color: BrandColors.unityBlue.withOpacity(0.5)),
          prefixIcon: Icon(Icons.search, color: BrandColors.momentumBlue),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: BrandColors.unityBlue),
                  onPressed: () {
                    _searchController.clear();
                    _search('');
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: BrandColors.momentumBlue.withOpacity(0.3),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: BrandColors.momentumBlue.withOpacity(0.3),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
              color: BrandColors.momentumBlue,
              width: 2,
            ),
          ),
          filled: true,
          fillColor: BrandColors.momentumBlue.withOpacity(0.05),
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
          Icon(Icons.inbox_outlined, size: 64, color: theme.disabledColor),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'No matching messages'
                : 'No messages yet',
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
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
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

/// Branded channel sidebar with white text on gradient background
class _BrandedChannelSidebar extends StatelessWidget {
  const _BrandedChannelSidebar({
    required this.channels,
    required this.selectedChannelId,
    required this.onChannelSelected,
  });

  final List<SlackChannel> channels;
  final String? selectedChannelId;
  final void Function(SlackChannel channel) onChannelSelected;

  @override
  Widget build(BuildContext context) {
    if (channels.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.tag, size: 48, color: Colors.white.withOpacity(0.5)),
              const SizedBox(height: 12),
              Text(
                'No channels found',
                style: TextStyle(color: Colors.white.withOpacity(0.7)),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: channels.length,
      itemBuilder: (context, index) {
        final channel = channels[index];
        final isSelected = channel.slackChannelId == selectedChannelId;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.white.withOpacity(0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListTile(
            dense: true,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            leading: Icon(
              Icons.tag,
              size: 18,
              color: isSelected ? Colors.white : Colors.white70,
            ),
            title: Text(
              channel.slackChannelName,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : Colors.white.withOpacity(0.9),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              channel.committeeName,
              style: TextStyle(
                color: isSelected
                    ? Colors.white.withOpacity(0.7)
                    : Colors.white.withOpacity(0.5),
                fontSize: 11,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => onChannelSelected(channel),
          ),
        );
      },
    );
  }
}

/// Branded channel dropdown for mobile
class _BrandedChannelDropdown extends StatelessWidget {
  const _BrandedChannelDropdown({
    required this.channels,
    required this.selectedChannel,
    required this.onChannelSelected,
  });

  final List<SlackChannel> channels;
  final SlackChannel? selectedChannel;
  final void Function(SlackChannel channel) onChannelSelected;

  @override
  Widget build(BuildContext context) {
    if (channels.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber, color: BrandColors.sunriseGold, size: 20),
            const SizedBox(width: 12),
            const Text(
              'No channels available',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedChannel?.slackChannelId,
          isExpanded: true,
          dropdownColor: BrandColors.unityBlue,
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
          items: channels.map((channel) {
            return DropdownMenuItem<String>(
              value: channel.slackChannelId,
              child: Row(
                children: [
                  const Icon(Icons.tag, size: 18, color: Colors.white70),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          channel.slackChannelName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          channel.committeeName,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          selectedItemBuilder: (context) {
            return channels.map((channel) {
              return Row(
                children: [
                  const Icon(Icons.tag, size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '#${channel.slackChannelName}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              );
            }).toList();
          },
          onChanged: (channelId) {
            if (channelId != null) {
              final channel = channels.firstWhere(
                (c) => c.slackChannelId == channelId,
              );
              onChannelSelected(channel);
            }
          },
        ),
      ),
    );
  }
}
