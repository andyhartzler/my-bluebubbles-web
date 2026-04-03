import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

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
import 'package:bluebubbles/features/committees/screens/tabs/social_media/social_media_analytics_tab.dart';
import 'package:bluebubbles/features/committees/services/committee_repository.dart';
import 'package:bluebubbles/features/committees/widgets/cors_aware_avatar.dart';
import 'package:bluebubbles/features/canvas_board/screens/committee_canvas_tab.dart';
import 'package:bluebubbles/screens/crm/member_detail_screen.dart';
import 'package:bluebubbles/features/committees/legislation_tracker/screens/legislation_tracker_screen.dart';
import 'package:bluebubbles/features/committees/legislation_tracker/providers/legislation_provider.dart';
import 'package:bluebubbles/features/committees/legislation_tracker/providers/bill_search_provider.dart';
import 'package:bluebubbles/features/committees/screens/tabs/committee_settings_tab.dart';
import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/screens/crm/candidates_page.dart';

class CommitteeWorkspaceScreen extends StatefulWidget {
  final Committee committee;
  final int initialTabIndex;

  const CommitteeWorkspaceScreen({
    super.key,
    required this.committee,
    this.initialTabIndex = 0,
  });

  /// Calculate the index of the Legislation tab for a given committee.
  /// Returns -1 if the committee doesn't have a Legislation tab.
  static int getLegislationTabIndex(Committee committee) {
    if (!committee.hasLegislationTab) return -1;

    // Base tabs: Overview, Members, Slack, Email, Messages, Meetings, Board, Votes
    int index = 8;

    // Add conditional tabs that come before Legislation
    if (committee.hasDonorsTab) index++;
    if (committee.hasChaptersTab) index++;
    if (committee.hasCampaignsTab) index++;

    return index;
  }

  @override
  State<CommitteeWorkspaceScreen> createState() =>
      _CommitteeWorkspaceScreenState();
}

class _CommitteeWorkspaceScreenState extends State<CommitteeWorkspaceScreen>
    with SingleTickerProviderStateMixin {
  final CommitteeRepository _repository = CommitteeRepository();
  late TabController _tabController;
  List<CommitteeLeader> _leaders = [];
  bool _loadingLeaders = true;
  String? _schoolFilter;
  bool _isCanvasFullscreen = false;
  int _currentTabIndex = 0;

  Committee get committee => widget.committee;

  // Board tab detection (dynamic based on tab list)
  bool get _isOnBoardTab =>
      _tabs.length > _currentTabIndex &&
      _tabs[_currentTabIndex].label == 'Board';

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
          width: 20,
          height: 20,
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
          onNavigateToEmail: () => _navigateToTab(3), // Email tab is at index 3
          onNavigateToMessages: () =>
              _navigateToTab(4), // Messages tab is at index 4
        ),
      ),
    ];

    // Add committee-specific tabs
    if (committee.hasDonorsTab) {
      tabs.add(
        _TabDefinition(
          label: 'Donors',
          icon: Icons.volunteer_activism_outlined,
          builder: () => const CommitteeDonorsTab(),
        ),
      );
    }

    if (committee.hasChaptersTab) {
      tabs.add(
        _TabDefinition(
          label: 'Chapters',
          icon: Icons.account_tree_outlined,
          builder: () => CommitteeChaptersTab(
            chapterTypeFilter: committee.chapterTypeFilter,
          ),
        ),
      );
    }

    if (committee.hasCampaignsTab) {
      tabs.add(
        _TabDefinition(
          label: 'Campaigns',
          icon: Icons.campaign_outlined,
          builder: () => const CommitteeCampaignsTab(),
        ),
      );
    }

    if (committee.hasLegislationTab) {
      tabs.add(
        _TabDefinition(
          label: 'Legislation',
          icon: Icons.gavel_outlined,
          builder: () => MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => LegislationProvider()),
              ChangeNotifierProvider(create: (_) => BillSearchProvider()),
            ],
            child: LegislationTrackerScreen(committeeId: committee.id),
          ),
        ),
      );
    }

    if (committee.hasCandidatesTab) {
      tabs.add(
        _TabDefinition(
          label: 'Candidates',
          icon: Icons.how_to_vote,
          builder: () => const CandidatesPage(),
        ),
      );
    }

    // Add Social Media Analytics tab for Communications committee
    if (committee.id == 'Communications') {
      tabs.add(
        _TabDefinition(
          label: 'Social Media',
          icon: Icons.analytics_outlined,
          builder: () => SocialMediaAnalyticsTab(committee: committee),
        ),
      );
    }

    // Settings tab is always last
    tabs.add(
      _TabDefinition(
        label: 'Settings',
        icon: Icons.settings_outlined,
        builder: () => CommitteeSettingsTab(committee: committee),
      ),
    );

    return tabs;
  }

  @override
  void initState() {
    super.initState();
    final initialIndex = widget.initialTabIndex.clamp(0, _tabs.length - 1);
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: initialIndex,
    );
    _currentTabIndex = initialIndex;
    _tabController.addListener(_onTabChanged);
    _loadLeaders();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    setState(() {
      _currentTabIndex = _tabController.index;
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
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
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.white.withOpacity(0.2),
                            child: Icon(
                              committee.icon,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              committee.displayName,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
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
                      tabs: _tabs
                          .map(
                            (tab) => Tab(
                              icon: tab.iconWidget ?? Icon(tab.icon),
                              text: tab.label,
                            ),
                          )
                          .toList(),
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

    // Use unified layout for all tabs including Legislation
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isVerySmall = screenWidth < 400;

    // Use unified layout matching member workspace style
    return Scaffold(
      body: Stack(
        children: [
          // Gradient background (not shown on Board tab)
          if (!_isOnBoardTab)
            Positioned.fill(
              child: Image.asset(
                BrandColors.backgroundAsset,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        committee.primaryColor,
                        committee.secondaryColor,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
            ),
          if (!_isOnBoardTab)
            Positioned.fill(
              child: Container(
                color: Colors.white.withOpacity(
                  BrandColors.backgroundOverlayOpacity,
                ),
              ),
            ),
          // Content
          Column(
            children: [
              // Fixed header with tabs
              _buildFixedHeader(context, isMobile, isVerySmall),
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
        ],
      ),
    );
  }

  /// Fixed header matching the member workspace styling
  Widget _buildFixedHeader(
    BuildContext context,
    bool isMobile,
    bool isVerySmall,
  ) {
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header row with back button, icon, and title
            Padding(
              padding: EdgeInsets.fromLTRB(
                isMobile ? 4 : 16,
                isMobile ? 8 : 16,
                16,
                isMobile ? 4 : 8,
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: isMobile ? 16 : 20,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    child: Icon(
                      committee.icon,
                      color: Colors.white,
                      size: isMobile ? 16 : 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          committee.displayName,
                          style:
                              (isMobile
                                      ? theme.textTheme.titleSmall
                                      : theme.textTheme.titleMedium)
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (!isMobile && _leaders.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Led by ${_leaders.map((l) => l.name.split(' ').first).join(' & ')}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white.withOpacity(0.8),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (!isMobile) ...[
                    const SizedBox(width: 16),
                    _buildLeadershipChips(),
                  ],
                ],
              ),
            ),
            // Tab bar
            TabBar(
              controller: _tabController,
              isScrollable: true,
              labelPadding: EdgeInsets.symmetric(
                horizontal: isVerySmall ? 8 : 12,
              ),
              indicatorWeight: 3,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: _tabs
                  .map(
                    (tab) => Tab(
                      icon:
                          tab.iconWidget ??
                          Icon(tab.icon, size: isMobile ? 18 : 24),
                      text: isVerySmall ? null : tab.label,
                      iconMargin: EdgeInsets.only(bottom: isVerySmall ? 0 : 4),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  /// Leadership chips for desktop view
  Widget _buildLeadershipChips() {
    if (_loadingLeaders) {
      return SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            Colors.white.withOpacity(0.7),
          ),
        ),
      );
    }

    if (_leaders.isEmpty) {
      return const SizedBox.shrink();
    }

    // Sort leaders: Chairs first, then Co-Chairs
    final sortedLeaders = List<CommitteeLeader>.from(_leaders)
      ..sort((a, b) {
        final aTitle = a.title?.toLowerCase() ?? '';
        final bTitle = b.title?.toLowerCase() ?? '';
        final aIsCoChair =
            aTitle.contains('co-chair') || aTitle.contains('vice');
        final bIsCoChair =
            bTitle.contains('co-chair') || bTitle.contains('vice');
        if (aIsCoChair != bIsCoChair) {
          return aIsCoChair ? 1 : -1;
        }
        return a.name.compareTo(b.name);
      });

    // Show up to 2 leaders as chips
    final displayLeaders = sortedLeaders.take(2).toList();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: displayLeaders
          .map(
            (leader) => Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _buildLeaderChip(leader),
            ),
          )
          .toList(),
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
              CorsAwareAvatar(
                imageUrl: leader.photoUrl,
                radius: 14,
                backgroundColor: Colors.white.withOpacity(0.3),
                fallbackText: leader.name,
                fallbackIconColor: Colors.white,
                fallbackTextColor: Colors.white,
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
        MaterialPageRoute(builder: (_) => MemberDetailScreen(member: member)),
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
