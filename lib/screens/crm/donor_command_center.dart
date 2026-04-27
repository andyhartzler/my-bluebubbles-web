import 'package:flutter/material.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/screens/crm/tabs/call_time_tab.dart';
import 'package:bluebubbles/screens/crm/tabs/committees_tab.dart';
import 'package:bluebubbles/screens/crm/tabs/fundraising_tab.dart';
import 'package:bluebubbles/screens/crm/tabs/mec_research_tab.dart';

/// 4-tab donors-and-fundraising container. The main CRM nav's "Donors" button
/// lands here, so this is the only entry point users have to these
/// sub-features.
///
/// Tabs:
///   0. Fundraising     — donation manager + thank-you tracker (also covers
///                        the MOYD donors list — Andrew collapsed the
///                        previously-separate MOYD Donors tab into this one
///                        on 2026-04-27 since the content was duplicate).
///   1. Donor Research  — MEC + FEC unified-donor research.
///   2. Call Time       — call-time list.
///   3. Committees      — committee directory.
class DonorCommandCenter extends StatefulWidget {
  final bool embed;

  const DonorCommandCenter({super.key, this.embed = false});

  @override
  State<DonorCommandCenter> createState() => _DonorCommandCenterState();
}

class _DonorCommandCenterState extends State<DonorCommandCenter>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  /// Needed so MecResearchTab's "Navigate to committee" callback can switch to
  /// the Committees tab AND open a specific committee by id.
  final GlobalKey<CommitteesTabState> _committeesKey =
      GlobalKey<CommitteesTabState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Switch to the Committees tab, then open the requested committee detail.
  ///
  /// The naive postFrameCallback approach fails on the first navigation
  /// because the CommitteesTab widget isn't materialised until the
  /// TabBarView animates to its index — addPostFrameCallback fires AFTER
  /// the frame that started the animation, but BEFORE tmail's lazy build
  /// of the tab 3 child. _committeesKey.currentState is null on the first
  /// frame, so the open silently no-ops and the user sees only the empty
  /// committees-tab list view.
  ///
  /// We poll the GlobalKey across animation frames (max 30 = ~500ms at
  /// 60fps) and call openCommitteeById as soon as the state attaches.
  void _navigateToCommittee(
    String committeeId,
    String committeeName,
    String source,
  ) {
    _tabController.animateTo(3);
    int attempts = 0;
    void tryOpen() {
      final state = _committeesKey.currentState;
      if (state != null) {
        state.openCommitteeById(committeeId, committeeName, source);
        return;
      }
      attempts++;
      if (attempts < 30 && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) => tryOpen());
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => tryOpen());
  }

  @override
  Widget build(BuildContext context) {
    final tabView = TabBarView(
      controller: _tabController,
      // Andrew's rule: tabs are clickable only — no swipe-to-change.
      physics: const NeverScrollableScrollPhysics(),
      children: [
        const FundraisingTab(),
        MecResearchTab(
          onNavigateToCommittee: _navigateToCommittee,
        ),
        const CallTimeTab(),
        CommitteesTab(key: _committeesKey),
      ],
    );

    if (widget.embed) {
      return Column(
        children: [
          _buildTabBar(),
          Expanded(child: tabView),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Donors'),
        backgroundColor: BrandColors.unityBlue,
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _buildTabBar(),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: BrandColors.tileGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: tabView,
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      // Run the gradient horizontally so the top edge stays uniform and
      // flows cleanly from the AppBar above (a topLeft → bottomRight
      // gradient creates a visible diagonal seam at the AppBar boundary).
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: BrandColors.tileGradient,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: TabBar(
        controller: _tabController,
        // Let the bar scroll horizontally on narrow screens so the tabs
        // don't get crammed.
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicatorColor: BrandColors.sunriseGold,
        indicatorWeight: 3,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        tabs: const [
          Tab(icon: Icon(Icons.savings), text: 'Fundraising'),
          Tab(icon: Icon(Icons.manage_search), text: 'Donor Research'),
          Tab(icon: Icon(Icons.phone_callback), text: 'Call Time'),
          Tab(icon: Icon(Icons.account_balance), text: 'Committees'),
        ],
      ),
    );
  }
}
