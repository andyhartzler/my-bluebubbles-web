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
import 'package:bluebubbles/features/committees/screens/tabs/committee_votes_tab.dart';
import 'package:bluebubbles/features/committees/services/committee_repository.dart';
import 'package:bluebubbles/features/canvas_board/screens/committee_canvas_tab.dart';
import 'package:bluebubbles/screens/crm/member_detail_screen.dart';

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
  late ScrollController _scrollController;
  List<CommitteeLeader> _leaders = [];
  bool _loadingLeaders = true;
  String? _schoolFilter;
  bool _isCanvasFullscreen = false;
  int _currentTabIndex = 0;

  // Mobile header visibility state
  bool _isHeaderVisible = true;
  double _lastScrollPosition = 0;
  static const double _scrollThreshold = 10.0;

  Committee get committee => widget.committee;

  // Board tab is at index 6 (after Overview, Members, Slack, Email, Messages, Meetings)
  bool get _isOnBoardTab => _currentTabIndex == 6;

  void _setCanvasFullscreen(bool fullscreen) {
    setState(() {
      _isCanvasFullscreen = fullscreen;
    });
  }

  void _navigateToTab(int index) {
    if (index >= 0 && index < _tabs.length) {
      _tabController.animateTo(index);
    }
  }

  void _filterMembersBySchool(String schoolName) {
    setState(() {
      _schoolFilter = schoolName;
    });
    // Navigate to members tab (index 1)
    _tabController.animateTo(1);
  }

  List<_TabDefinition> get _tabs {
    final tabs = <_TabDefinition>[
      _TabDefinition(
        label: 'Overview',
        icon: Icons.dashboard_outlined,
        builder: () => CommitteeOverviewTab(
          committee: committee,
          onNavigateToTab: _navigateToTab,
          onFilterMembersBySchool: _filterMembersBySchool,
        ),
      ),
      _TabDefinition(
        label: 'Members',
        icon: Icons.people_outline,
        builder: () => CommitteeMembersTab(
          committee: committee,
          initialSchoolFilter: _schoolFilter,
          onSchoolFilterCleared: () {
            setState(() => _schoolFilter = null);
          },
        ),
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
        builder: () => CommitteeCanvasTab(
          committee: committee,
          isFullscreen: _isCanvasFullscreen,
          onFullscreenChanged: _setCanvasFullscreen,
        ),
      ),
      _TabDefinition(
        label: 'Votes',
        icon: Icons.how_to_vote_outlined,
        builder: () => CommitteeVotesTab(
          committee: committee,
          onNavigateToEmail: () => _navigateToTab(3),  // Email tab is at index 3
          onNavigateToMessages: () => _navigateToTab(4),  // Messages tab is at index 4
        ),
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
    _tabController.addListener(_onTabChanged);
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _loadLeaders();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    setState(() {
      _currentTabIndex = _tabController.index;
      // Reset header visibility when changing tabs
      _isHeaderVisible = true;
      _lastScrollPosition = 0;
    });
  }

  void _onScroll() {
    final currentPosition = _scrollController.position.pixels;
    final delta = currentPosition - _lastScrollPosition;

    // Only update if scroll delta exceeds threshold (prevents jitter)
    if (delta.abs() > _scrollThreshold) {
      final scrollingDown = delta > 0;
      final atTop = currentPosition <= 0;

      if (atTop) {
        // Always show header when at top
        if (!_isHeaderVisible) {
          setState(() => _isHeaderVisible = true);
        }
      } else if (scrollingDown && _isHeaderVisible) {
        // Hide header when scrolling down
        setState(() => _isHeaderVisible = false);
      } else if (!scrollingDown && !_isHeaderVisible) {
        // Show header when scrolling up
        setState(() => _isHeaderVisible = true);
      }

      _lastScrollPosition = currentPosition;
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
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
    // When canvas is fullscreen, only show the canvas tab
    if (_isCanvasFullscreen) {
      return Scaffold(
        body: CommitteeCanvasTab(
          committee: committee,
          isFullscreen: true,
          onFullscreenChanged: _setCanvasFullscreen,
        ),
      );
    }

    // When on Board tab, use a non-scrollable layout to keep the header fixed
    if (_isOnBoardTab) {
      return Scaffold(
        body: Column(
          children: [
            // Fixed header with tabs
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [committee.primaryColor, committee.secondaryColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Compact header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.white.withOpacity(0.2),
                            child: Icon(committee.icon, color: Colors.white, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              committee.displayName,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Tab bar
                    TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      tabs: _tabs.map((tab) => Tab(
                        icon: tab.iconWidget ?? Icon(tab.icon),
                        text: tab.label,
                      )).toList(),
                    ),
                  ],
                ),
              ),
            ),
            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: _tabs.map((tab) => tab.builder()).toList(),
              ),
            ),
          ],
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isVerySmall = screenWidth < 400;

    // Mobile: use scroll-aware collapsing header
    if (isMobile) {
      return _buildMobileLayout(context, isVerySmall);
    }

    // Desktop: use standard NestedScrollView
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
                labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                tabs: _tabs.map((tab) => Tab(
                  icon: tab.iconWidget ?? Icon(tab.icon, size: 24),
                  text: tab.label,
                  iconMargin: const EdgeInsets.only(bottom: 4),
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

  Widget _buildMobileLayout(BuildContext context, bool isVerySmall) {
    final theme = Theme.of(context);
    final topPadding = MediaQuery.of(context).padding.top;

    // Calculate header height - includes SafeArea top padding when visible
    final headerContentHeight = 56.0; // Compact header row
    final tabBarHeight = 48.0;
    final totalHeaderHeight = topPadding + headerContentHeight + tabBarHeight;

    return Scaffold(
      body: Stack(
        children: [
          // Main content - takes full screen
          Positioned.fill(
            child: Column(
              children: [
                // Spacer that animates with header
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  height: _isHeaderVisible ? totalHeaderHeight : 0,
                ),
                // Tab content
                Expanded(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification is ScrollUpdateNotification) {
                        final currentPosition = notification.metrics.pixels;
                        final delta = currentPosition - _lastScrollPosition;

                        if (delta.abs() > _scrollThreshold) {
                          final scrollingDown = delta > 0;
                          final atTop = currentPosition <= 0;

                          if (atTop && !_isHeaderVisible) {
                            setState(() => _isHeaderVisible = true);
                          } else if (scrollingDown && _isHeaderVisible && currentPosition > 50) {
                            setState(() => _isHeaderVisible = false);
                          } else if (!scrollingDown && !_isHeaderVisible) {
                            setState(() => _isHeaderVisible = true);
                          }

                          _lastScrollPosition = currentPosition;
                        }
                      }
                      return false;
                    },
                    child: TabBarView(
                      controller: _tabController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: _tabs.map((tab) => tab.builder()).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Animated header overlay
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            top: _isHeaderVisible ? 0 : -totalHeaderHeight,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [committee.primaryColor, committee.secondaryColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Compact header row
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => Navigator.of(context).pop(),
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 8),
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.white.withOpacity(0.2),
                            child: Icon(committee.icon, color: Colors.white, size: 16),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              committee.displayName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Tab bar
                    TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      labelPadding: EdgeInsets.symmetric(horizontal: isVerySmall ? 6 : 10),
                      indicatorWeight: 3,
                      tabs: _tabs.map((tab) => Tab(
                        icon: tab.iconWidget ?? Icon(tab.icon, size: 18),
                        text: isVerySmall ? null : tab.label,
                        iconMargin: EdgeInsets.only(bottom: isVerySmall ? 0 : 2),
                      )).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isVerySmall = screenWidth < 400;

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
          padding: EdgeInsets.fromLTRB(
            isMobile ? 56 : 72,
            isMobile ? 8 : 16,
            isMobile ? 16 : 24,
            isMobile ? 40 : 60,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left side: Committee icon and name
              Expanded(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: isMobile ? 20 : 28,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      child: Icon(
                        committee.icon,
                        color: Colors.white,
                        size: isMobile ? 20 : 28,
                      ),
                    ),
                    SizedBox(width: isMobile ? 12 : 16),
                    Expanded(
                      child: Text(
                        committee.displayName,
                        style: (isMobile ? theme.textTheme.titleMedium : theme.textTheme.headlineSmall)?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isMobile) const SizedBox(width: 16),

              // Right side: Leadership section
              _buildLeadershipSection(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeadershipSection(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    // Hide leadership section on mobile - shown elsewhere
    if (isMobile) {
      return const SizedBox.shrink();
    }

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

    // Sort leaders: Chairs first, then Co-Chairs, alphabetical within each group
    final sortedLeaders = List<CommitteeLeader>.from(_leaders)
      ..sort((a, b) {
        final aTitle = a.title?.toLowerCase() ?? '';
        final bTitle = b.title?.toLowerCase() ?? '';

        // Determine if each is a chair or co-chair
        final aIsCoChair = aTitle.contains('co-chair') || aTitle.contains('vice');
        final bIsCoChair = bTitle.contains('co-chair') || bTitle.contains('vice');

        // Chairs come before Co-Chairs
        if (aIsCoChair != bIsCoChair) {
          return aIsCoChair ? 1 : -1; // Co-chairs come after chairs
        }

        // Same role - sort alphabetically by name
        return a.name.compareTo(b.name);
      });

    // Display leaders side by side in a horizontal row (Chair first, then Co-Chair)
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: sortedLeaders.map((leader) => Padding(
        padding: const EdgeInsets.only(left: 8),
        child: _buildLeaderChip(leader),
      )).toList(),
    );
  }

  Widget _buildLeaderChip(CommitteeLeader leader) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _navigateToMemberProfile(leader.memberId),
        borderRadius: BorderRadius.circular(999),
        child: Container(
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
        ),
      ),
    );
  }

  Future<void> _navigateToMemberProfile(String memberId) async {
    final member = await _repository.getMemberById(memberId);
    if (member != null && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MemberDetailScreen(member: member),
        ),
      );
    }
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
