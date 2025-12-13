import 'package:flutter/material.dart';

import 'package:bluebubbles/features/slack/widgets/channels_tab.dart';
import 'package:bluebubbles/features/slack/widgets/unmatched_users_tab.dart';
import 'package:bluebubbles/features/slack/widgets/analytics_tab.dart';

/// Main screen for Slack management with tabbed interface
class SlackManagementScreen extends StatefulWidget {
  const SlackManagementScreen({
    super.key,
    this.embed = false,
    this.initialChannelId,
  });

  final bool embed;
  /// Optional channel ID to pre-select when opening the Channels tab
  final String? initialChannelId;

  @override
  State<SlackManagementScreen> createState() => _SlackManagementScreenState();
}

class _SlackManagementScreenState extends State<SlackManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final content = Column(
      children: [
        // Tab bar
        Container(
          color: theme.colorScheme.surface,
          child: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(
                icon: Icon(Icons.tag),
                text: 'Channels',
              ),
              Tab(
                icon: Icon(Icons.person_search),
                text: 'Unmatched Users',
              ),
              Tab(
                icon: Icon(Icons.analytics),
                text: 'Analytics',
              ),
            ],
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
            indicatorColor: theme.colorScheme.primary,
          ),
        ),
        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              ChannelsTab(initialChannelId: widget.initialChannelId),
              const UnmatchedUsersTab(),
              AnalyticsTab(
                onSwitchToUnmatchedTab: () => _tabController.animateTo(1),
              ),
            ],
          ),
        ),
      ],
    );

    if (widget.embed) {
      return content;
    }

    // Standalone screen with app bar
    return Scaffold(
      appBar: AppBar(
        title: const Text('Slack Management'),
        elevation: 0,
      ),
      body: content,
    );
  }
}
