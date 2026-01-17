import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import 'package:bluebubbles/features/committees/models/committee.dart';
import 'package:bluebubbles/features/committees/screens/tabs/committee_slack_tab.dart';
import 'package:bluebubbles/features/committees/screens/tabs/committee_meetings_tab.dart';
import 'package:bluebubbles/features/committees/screens/tabs/committee_votes_tab.dart';
import 'package:bluebubbles/features/committees/screens/tabs/committee_email_tab.dart';
import 'package:bluebubbles/features/committees/screens/tabs/committee_messages_tab.dart';
import 'package:bluebubbles/features/committees/screens/tabs/committee_donors_tab.dart';
import 'package:bluebubbles/features/committees/screens/tabs/committee_chapters_tab.dart';
import 'package:bluebubbles/features/committees/screens/tabs/committee_campaigns_tab.dart';
import 'package:bluebubbles/features/committees/screens/tabs/social_media/social_media_analytics_tab.dart';
import 'package:bluebubbles/features/committees/screens/tabs/member/committee_member_overview_tab.dart';
import 'package:bluebubbles/features/committees/screens/tabs/member/committee_member_members_tab.dart';
import 'package:bluebubbles/features/committees/services/committee_repository.dart';
import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/features/committees/widgets/cors_aware_avatar.dart';
import 'package:bluebubbles/features/canvas_board/screens/committee_canvas_tab.dart';
import 'package:bluebubbles/features/committees/legislation_tracker/screens/legislation_tracker_screen.dart';
import 'package:bluebubbles/features/committees/legislation_tracker/providers/legislation_provider.dart';
import 'package:bluebubbles/features/committees/legislation_tracker/providers/bill_search_provider.dart';
import 'package:bluebubbles/providers/user_session_provider.dart';

/// Workspace screen for committee members (non-executive)
///
/// Shows a filtered set of tabs based on the tools configured
/// by executives for this committee.
class CommitteeMemberWorkspaceScreen extends StatefulWidget {
  final UserCommitteeInfo committeeInfo;
  final Committee? committee;

  const CommitteeMemberWorkspaceScreen({
    super.key,
    required this.committeeInfo,
    this.committee,
  });

  @override
  State<CommitteeMemberWorkspaceScreen> createState() =>
      _CommitteeMemberWorkspaceScreenState();
}

class _CommitteeMemberWorkspaceScreenState
    extends State<CommitteeMemberWorkspaceScreen>
    with SingleTickerProviderStateMixin {
  final CommitteeRepository _repository = CommitteeRepository();

  late TabController _tabController;
  List<CommitteeLeader> _leaders = [];
  bool _loadingLeaders = true;
  int _currentTabIndex = 0;
  bool _isCanvasFullscreen = false;

  UserCommitteeInfo get committeeInfo => widget.committeeInfo;

  // Use the committee definition if available, otherwise create a basic one
  Committee get committee =>
      widget.committee ??
      Committee(
        id: committeeInfo.name,
        name: committeeInfo.name,
        displayName: committeeInfo.name,
        description: committeeInfo.description ?? '',
        icon: Icons.groups_outlined,
        primaryColor: BrandColors.momentumBlue,
        secondaryColor: BrandColors.unityBlue,
      );

  // Get available tabs based on configured tools
  List<_TabDefinition> get _tabs {
    final tools = committeeInfo.tools;
    final tabs = <_TabDefinition>[];

    // Overview - always available if enabled
    if (tools.contains('overview')) {
      tabs.add(
        _TabDefinition(
          label: 'Overview',
          icon: Icons.dashboard_outlined,
          slug: 'overview',
          builder: () => CommitteeMemberOverviewTab(
            committee: committee,
            leaders: _leaders,
            onNavigateToMeetings: tools.contains('meetings')
                ? () => _navigateToTabBySlug('meetings')
                : null,
          ),
        ),
      );
    }

    // Members - read-only version for committee members
    if (tools.contains('members')) {
      tabs.add(
        _TabDefinition(
          label: 'Members',
          icon: Icons.people_outline,
          slug: 'members',
          builder: () => CommitteeMemberMembersTab(committee: committee),
        ),
      );
    }

    // Slack - with member view restrictions
    if (tools.contains('slack')) {
      tabs.add(
        _TabDefinition(
          label: 'Slack',
          iconWidget: SvgPicture.asset(
            'assets/icon/slack-icon.svg',
            width: 20,
            height: 20,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
          slug: 'slack',
          builder: () => CommitteeSlackTab(
            committee: committee,
            isMemberView: true, // Disable profile navigation for members
          ),
        ),
      );
    }

    // Meetings - with member view restrictions (no editing, no profile navigation)
    if (tools.contains('meetings')) {
      tabs.add(
        _TabDefinition(
          label: 'Meetings',
          icon: Icons.video_camera_front_outlined,
          slug: 'meetings',
          builder: () =>
              CommitteeMeetingsTab(committee: committee, isMemberView: true),
        ),
      );
    }

    // Board
    if (tools.contains('board')) {
      tabs.add(
        _TabDefinition(
          label: 'Board',
          icon: Icons.space_dashboard_outlined,
          slug: 'board',
          builder: () => CommitteeCanvasTab(
            committee: committee,
            isFullscreen: _isCanvasFullscreen,
            onFullscreenChanged: _setCanvasFullscreen,
          ),
        ),
      );
    }

    // Votes - member view can only see results, not create/edit/delete
    if (tools.contains('votes')) {
      tabs.add(
        _TabDefinition(
          label: 'Votes',
          icon: Icons.how_to_vote_outlined,
          slug: 'votes',
          builder: () => CommitteeVotesTab(
            committee: committee,
            isMemberView: true,
            onNavigateToEmail: tools.contains('email')
                ? () => _navigateToTabBySlug('email')
                : null,
            onNavigateToMessages: tools.contains('messages')
                ? () => _navigateToTabBySlug('messages')
                : null,
          ),
        ),
      );
    }

    // Email
    if (tools.contains('email')) {
      tabs.add(
        _TabDefinition(
          label: 'Email',
          icon: Icons.email_outlined,
          slug: 'email',
          builder: () => CommitteeEmailTab(committee: committee),
        ),
      );
    }

    // Messages
    if (tools.contains('messages')) {
      tabs.add(
        _TabDefinition(
          label: 'Messages',
          icon: Icons.message_outlined,
          slug: 'messages',
          builder: () => CommitteeMessagesTab(committee: committee),
        ),
      );
    }

    // Donors
    if (tools.contains('donors')) {
      tabs.add(
        _TabDefinition(
          label: 'Donors',
          icon: Icons.volunteer_activism_outlined,
          slug: 'donors',
          builder: () => const CommitteeDonorsTab(),
        ),
      );
    }

    // Chapters
    if (tools.contains('chapters')) {
      tabs.add(
        _TabDefinition(
          label: 'Chapters',
          icon: Icons.account_tree_outlined,
          slug: 'chapters',
          builder: () => CommitteeChaptersTab(
            chapterTypeFilter: committee.chapterTypeFilter,
          ),
        ),
      );
    }

    // Campaigns
    if (tools.contains('campaigns')) {
      tabs.add(
        _TabDefinition(
          label: 'Campaigns',
          icon: Icons.campaign_outlined,
          slug: 'campaigns',
          builder: () => const CommitteeCampaignsTab(),
        ),
      );
    }

    // Legislation
    if (tools.contains('legislation')) {
      tabs.add(
        _TabDefinition(
          label: 'Legislation',
          icon: Icons.gavel_outlined,
          slug: 'legislation',
          builder: () => MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => LegislationProvider()),
              ChangeNotifierProvider(create: (_) => BillSearchProvider()),
            ],
            child: LegislationTrackerScreen(
              committeeId: committee.id,
              isMemberView: true,
            ),
          ),
        ),
      );
    }

    // Social Media
    if (tools.contains('social-media')) {
      tabs.add(
        _TabDefinition(
          label: 'Social Media',
          icon: Icons.analytics_outlined,
          slug: 'social-media',
          builder: () => SocialMediaAnalyticsTab(committee: committee),
        ),
      );
    }

    // If no tabs are configured, show at least overview
    if (tabs.isEmpty) {
      tabs.add(
        _TabDefinition(
          label: 'Overview',
          icon: Icons.dashboard_outlined,
          slug: 'overview',
          builder: () => CommitteeMemberOverviewTab(
            committee: committee,
            leaders: _leaders,
          ),
        ),
      );
    }

    return tabs;
  }

  void _navigateToTabBySlug(String slug) {
    final tabs = _tabs;
    final index = tabs.indexWhere((tab) => tab.slug == slug);
    if (index != -1) {
      _navigateToTab(index);
    }
  }

  bool get _isOnBoardTab {
    final tabs = _tabs;
    if (_currentTabIndex >= tabs.length) return false;
    return tabs[_currentTabIndex].slug == 'board';
  }

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
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
    final tabs = _tabs;

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

    // Use unified layout for all tabs including Legislation
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isVerySmall = screenWidth < 400;

    return Scaffold(
      body: Stack(
        children: [
          // Gradient background
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
              _buildHeader(context, tabs, isMobile, isVerySmall),
              // Tab content - lazy loaded for performance
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: tabs.asMap().entries.map((entry) {
                    final index = entry.key;
                    final tab = entry.value;
                    return _LazyTabContent(
                      key: ValueKey('${tab.slug}_$index'),
                      builder: tab.builder,
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    List<_TabDefinition> tabs,
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
                    _buildLeadershipSection(),
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
              tabs: tabs
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

  Widget _buildLeadershipSection() {
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
    return Container(
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
    );
  }
}

class _TabDefinition {
  final String label;
  final IconData? icon;
  final Widget? iconWidget;
  final String slug;
  final Widget Function() builder;

  const _TabDefinition({
    required this.label,
    this.icon,
    this.iconWidget,
    required this.slug,
    required this.builder,
  }) : assert(icon != null || iconWidget != null);
}

/// Lazy loading wrapper for tab content
/// Only builds the content once it becomes visible for the first time
class _LazyTabContent extends StatefulWidget {
  final Widget Function() builder;

  const _LazyTabContent({super.key, required this.builder});

  @override
  State<_LazyTabContent> createState() => _LazyTabContentState();
}

class _LazyTabContentState extends State<_LazyTabContent>
    with AutomaticKeepAliveClientMixin {
  bool _hasBuilt = false;
  Widget? _child;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Only build the widget once
    if (!_hasBuilt) {
      _hasBuilt = true;
      _child = widget.builder();
    }

    return _child ?? const SizedBox.shrink();
  }
}
