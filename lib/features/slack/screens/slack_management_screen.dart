import 'package:flutter/material.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/features/slack/widgets/channels_tab.dart';
import 'package:bluebubbles/features/slack/widgets/unmatched_users_tab.dart';
import 'package:bluebubbles/features/slack/widgets/ineligible_members_tab.dart';
import 'package:bluebubbles/features/slack/widgets/analytics_tab.dart';

/// Main screen for Slack management with tabbed interface
class SlackManagementScreen extends StatefulWidget {
  const SlackManagementScreen({
    super.key,
    this.embed = false,
    this.initialChannelId,
    this.initialUnmatchedUserId,
    this.initialTabIndex,
  });

  final bool embed;

  /// Optional channel ID to pre-select when opening the Channels tab
  final String? initialChannelId;

  /// Optional Slack user ID to highlight when opening the Unmatched Users tab
  final String? initialUnmatchedUserId;

  /// Optional initial tab index (0=Channels, 1=Unmatched, 2=Ineligible, 3=Analytics)
  final int? initialTabIndex;

  @override
  State<SlackManagementScreen> createState() => _SlackManagementScreenState();
}

class _SlackManagementScreenState extends State<SlackManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // Determine initial tab: if initialUnmatchedUserId is set, go to tab 1 (Unmatched)
    int initialIndex = widget.initialTabIndex ?? 0;
    if (widget.initialUnmatchedUserId != null) {
      initialIndex = 1; // Unmatched Users tab
    }
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: initialIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        // Branded tab bar
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: BrandColors.tileGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(icon: Icon(Icons.tag), text: 'Channels'),
                Tab(icon: Icon(Icons.person_search), text: 'Unmatched'),
                Tab(icon: Icon(Icons.person_off), text: 'Ineligible'),
                Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
              ],
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: BrandColors.sunriseGold,
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ),
        ),
        // Tab content with branded background
        Expanded(
          child: BrandedBackground(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                ChannelsTab(initialChannelId: widget.initialChannelId),
                UnmatchedUsersTab(
                  highlightUserId: widget.initialUnmatchedUserId,
                ),
                const IneligibleMembersTab(),
                AnalyticsTab(
                  onSwitchToUnmatchedTab: () => _tabController.animateTo(1),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    if (widget.embed) {
      return content;
    }

    // Standalone screen with branded app bar
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Slack Management',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: BrandColors.tileGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: content,
    );
  }
}
