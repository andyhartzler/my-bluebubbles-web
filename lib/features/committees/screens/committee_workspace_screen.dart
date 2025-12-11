import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:bluebubbles/features/committees/models/committee.dart';
import 'package:bluebubbles/features/committees/screens/tabs/committee_overview_tab.dart';
import 'package:bluebubbles/features/committees/screens/tabs/committee_members_tab.dart';
import 'package:bluebubbles/features/committees/screens/tabs/committee_slack_tab.dart';
import 'package:bluebubbles/features/committees/screens/tabs/committee_email_tab.dart';
import 'package:bluebubbles/features/committees/screens/tabs/committee_messages_tab.dart';
import 'package:bluebubbles/features/committees/screens/tabs/committee_donors_tab.dart';
import 'package:bluebubbles/features/committees/screens/tabs/committee_chapters_tab.dart';
import 'package:bluebubbles/features/committees/screens/tabs/committee_campaigns_tab.dart';
import 'package:bluebubbles/features/committees/screens/tabs/committee_meetings_tab.dart';
import 'package:bluebubbles/features/committees/services/committee_repository.dart';
import 'package:bluebubbles/features/canvas_board/screens/committee_canvas_tab.dart';

class CommitteeWorkspaceScreen extends StatefulWidget {
  final Committee committee;

  const CommitteeWorkspaceScreen({super.key, required this.committee});

  @override
  State<CommitteeWorkspaceScreen> createState() => _CommitteeWorkspaceScreenState();
}

class _CommitteeWorkspaceScreenState extends State<CommitteeWorkspaceScreen>
    with SingleTickerProviderStateMixin {
  final CommitteeRepository _repository = CommitteeRepository();
  late TabController _tabController;
  List<CommitteeLeader> _leaders = [];
  bool _loadingLeaders = true;

  Committee get committee => widget.committee;

  List<_TabDefinition> get _tabs {
    final tabs = <_TabDefinition>[
      _TabDefinition(
        label: 'Overview',
        icon: Icons.dashboard_outlined,
        builder: () => CommitteeOverviewTab(committee: committee),
      ),
      _TabDefinition(
        label: 'Members',
        icon: Icons.people_outline,
        builder: () => CommitteeMembersTab(committee: committee),
      ),
      _TabDefinition(
        label: 'Slack',
        iconWidget: SvgPicture.asset(
          'assets/icon/slack-icon.svg',
          width: 24,
          height: 24,
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        ),
        builder: () => CommitteeSlackTab(committee: committee),
      ),
      _TabDefinition(
        label: 'Email',
        icon: Icons.email_outlined,
        builder: () => CommitteeEmailTab(committee: committee),
      ),
      _TabDefinition(
        label: 'Messages',
        icon: Icons.message_outlined,
        builder: () => CommitteeMessagesTab(committee: committee),
      ),
      _TabDefinition(
        label: 'Meetings',
        icon: Icons.video_camera_front_outlined,
        builder: () => CommitteeMeetingsTab(committee: committee),
      ),
      _TabDefinition(
        label: 'Board',
        icon: Icons.space_dashboard_outlined,
        builder: () => CommitteeCanvasTab(committee: committee),
      ),
    ];

    // Add committee-specific tabs
    if (committee.hasDonorsTab) {
      tabs.add(_TabDefinition(
        label: 'Donors',
        icon: Icons.volunteer_activism_outlined,
        builder: () => const CommitteeDonorsTab(),
      ));
    }

    if (committee.hasChaptersTab) {
      tabs.add(_TabDefinition(
        label: 'Chapters',
        icon: Icons.account_tree_outlined,
        builder: () => CommitteeChaptersTab(
          chapterTypeFilter: committee.chapterTypeFilter,
        ),
      ));
    }

    if (committee.hasCampaignsTab) {
      tabs.add(_TabDefinition(
        label: 'Campaigns',
        icon: Icons.campaign_outlined,
        builder: () => const CommitteeCampaignsTab(),
      ));
    }

    return tabs;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _loadLeaders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLeaders() async {
    setState(() => _loadingLeaders = true);

    try {
      final leaders = await _repository.getCommitteeLeadership(committee.name);
      if (!mounted) return;
      setState(() {
        _leaders = leaders;
        _loadingLeaders = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingLeaders = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 200,
              floating: false,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: _buildHeader(context),
              ),
              bottom: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: _tabs.map((tab) => Tab(
                  icon: tab.iconWidget ?? Icon(tab.icon),
                  text: tab.label,
                )).toList(),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          physics: const NeverScrollableScrollPhysics(),
          children: _tabs.map((tab) => tab.builder()).toList(),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [committee.primaryColor, committee.secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(72, 16, 24, 60),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left side: Committee icon and name
              Expanded(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      child: Icon(
                        committee.icon,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            committee.displayName,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            committee.description,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withOpacity(0.9),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Right side: Leadership section
              _buildLeadershipSection(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeadershipSection(BuildContext context) {
    if (_loadingLeaders) {
      return SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withOpacity(0.7)),
        ),
      );
    }

    if (_leaders.isEmpty) {
      return const SizedBox.shrink();
    }

    // Display leaders side by side in a horizontal row (Chair first, then Co-Chair)
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: _leaders.map((leader) => Padding(
        padding: const EdgeInsets.only(left: 8),
        child: _buildLeaderChip(leader),
      )).toList(),
    );
  }

  Widget _buildLeaderChip(CommitteeLeader leader) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundImage: leader.photoUrl != null ? NetworkImage(leader.photoUrl!) : null,
            backgroundColor: Colors.white.withOpacity(0.3),
            child: leader.photoUrl == null
                ? Text(
                    leader.name.isNotEmpty ? leader.name[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                leader.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              if (leader.title != null)
                Text(
                  leader.title!,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TabDefinition {
  final String label;
  final IconData? icon;
  final Widget? iconWidget;
  final Widget Function() builder;

  const _TabDefinition({
    required this.label,
    this.icon,
    this.iconWidget,
    required this.builder,
  }) : assert(icon != null || iconWidget != null);
}
