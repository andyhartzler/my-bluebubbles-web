import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bluebubbles/features/committees/models/committee.dart';
import 'package:bluebubbles/features/committees/screens/committee_member_workspace_screen.dart';
import 'package:bluebubbles/features/committees/screens/committee_member_settings_screen.dart';
import 'package:bluebubbles/features/committees/services/committee_repository.dart';
import 'package:bluebubbles/features/committees/widgets/cors_aware_avatar.dart';
import 'package:bluebubbles/features/committees/widgets/member_calendar_widget.dart';
import 'package:bluebubbles/providers/user_session_provider.dart';

// Brand colors
const _unityBlue = Color(0xFF273351);
const _momentumBlue = Color(0xFF32A6DE);
const _backgroundAsset = 'assets/images/Blue-Gradient-Background.png';
const _overlayOpacity = 0.12;

/// Committee Hub Dashboard for non-executive committee members
///
/// A modern dashboard showing committee assignments, upcoming meetings,
/// and personalized welcome message.
class CommitteeHubScreen extends StatefulWidget {
  const CommitteeHubScreen({super.key});

  @override
  State<CommitteeHubScreen> createState() => _CommitteeHubScreenState();
}

class _CommitteeHubScreenState extends State<CommitteeHubScreen> {
  final CommitteeRepository _repository = CommitteeRepository();

  bool _isLoading = true;
  String? _error;
  Map<String, int> _committeeMemberCounts = {};
  Map<String, bool> _workspaceEnabledMap = {};

  /// Whether all the user's committees have workspace disabled
  bool _allWorkspacesDisabled = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final session = context.read<UserSessionProvider>();
      final counts = <String, int>{};

      // Build workspace enabled map from already-loaded committee data
      // (RPC already filters by workspace_enabled = true, so all should be enabled)
      final workspaceEnabled = <String, bool>{};
      for (final committee in session.userCommittees) {
        workspaceEnabled[committee.name] = committee.workspaceEnabled;
      }

      for (final committee in session.userCommittees) {
        // Only load data for enabled committees
        if (committee.workspaceEnabled) {
          final count = await _repository.getMemberCountForCommittee(committee.name);
          counts[committee.name] = count;
        }
      }

      // Check if any workspaces are enabled (should be true since RPC filters)
      final anyEnabled = session.userCommittees.any((c) => c.workspaceEnabled);

      if (!mounted) return;
      setState(() {
        _committeeMemberCounts = counts;
        _workspaceEnabledMap = workspaceEnabled;
        _allWorkspacesDisabled = !anyEnabled;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _handleLogout() async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      context.read<UserSessionProvider>().clearSession();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: $e')),
      );
    }
  }

  void _navigateToCommittee(UserCommitteeInfo committeeInfo) {
    final committee = CommitteeDefinitions.findByName(committeeInfo.name);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CommitteeMemberWorkspaceScreen(
          committeeInfo: committeeInfo,
          committee: committee,
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Gradient background
          Positioned.fill(
            child: Image.asset(
              _backgroundAsset,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_unityBlue, _momentumBlue],
                  ),
                ),
              ),
            ),
          ),
          // White overlay
          Positioned.fill(
            child: Container(color: Colors.white.withOpacity(_overlayOpacity)),
          ),
          // Content
          Positioned.fill(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final session = context.watch<UserSessionProvider>();

    if (session.isLoading || _isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(_momentumBlue),
        ),
      );
    }

    if (_error != null) {
      return _buildErrorView();
    }

    // Filter to only show committees with workspace enabled
    final committees = session.userCommittees
        .where((c) => _workspaceEnabledMap[c.name] == true)
        .toList();

    // If no committees at all (not in any committee)
    if (session.userCommittees.isEmpty) {
      return _buildNoCommitteesView();
    }

    // If all workspaces are disabled
    if (_allWorkspacesDisabled || committees.isEmpty) {
      return _buildWorkspaceDisabledView();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;
        final isTablet = constraints.maxWidth >= 600 && constraints.maxWidth < 900;
        final horizontalPadding = isDesktop ? 48.0 : (isTablet ? 32.0 : 20.0);

        return RefreshIndicator(
          onRefresh: () async {
            await session.refreshSession();
            await _loadData();
          },
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              // Welcome header
              SliverToBoxAdapter(
                child: _buildWelcomeHeader(session, horizontalPadding),
              ),

              // Main content - committees section (full width) and calendar
              SliverPadding(
                padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 32),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    children: [
                      _buildCommitteesSection(committees),
                      const SizedBox(height: 24),
                      const MemberCalendarWidget(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _navigateToSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CommitteeMemberSettingsScreen(),
      ),
    );
  }

  Widget _buildWelcomeHeader(UserSessionProvider session, double horizontalPadding) {
    final theme = Theme.of(context);
    final greeting = _getGreeting();
    final firstName = session.displayName.split(' ').first;
    // The one resolver: an uploaded avatar_url first, then the primary
    // profile_pictures entry. Reading profile_pictures alone hides the
    // headshot of anyone who uploaded through the personalized home.
    final photoUrl = session.currentMember?.effectiveAvatarUrl;

    return Container(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 48, horizontalPadding, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar with member's photo
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: _unityBlue.withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: CorsAwareAvatar(
              imageUrl: photoUrl,
              radius: 32,
              // White initials on a solid momentumBlue disc measure 2.75:1,
              // under both the 4.5:1 normal-text and 3:1 large-text floors.
              // momentumBlue is a non-text-use color. An opaque unityBlue
              // disc carries white at 12.51:1 and holds on any surface.
              backgroundColor: _unityBlue,
              fallbackText: session.displayName,
              fallbackIconColor: Colors.white,
              fallbackTextColor: Colors.white,
            ),
          ),
          const SizedBox(width: 20),
          // Greeting
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _unityBlue.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  firstName,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: _unityBlue,
                  ),
                ),
              ],
            ),
          ),
          // Settings button
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: _unityBlue.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              onPressed: _navigateToSettings,
              icon: const Icon(Icons.settings_outlined, color: _unityBlue),
              tooltip: 'Settings',
            ),
          ),
          const SizedBox(width: 8),
          // Logout button
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: _unityBlue.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              onPressed: _handleLogout,
              icon: const Icon(Icons.logout_rounded, color: _unityBlue),
              tooltip: 'Sign out',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommitteesSection(List<UserCommitteeInfo> committees) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _unityBlue.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _momentumBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.dashboard_outlined, color: _momentumBlue, size: 22),
                ),
                const SizedBox(width: 12),
                Text(
                  'Your Committees',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: _unityBlue,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Committee list
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: committees.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 24, endIndent: 24),
            itemBuilder: (context, index) => _buildCommitteeRow(committees[index]),
          ),
        ],
      ),
    );
  }

  Widget _buildCommitteeRow(UserCommitteeInfo committeeInfo) {
    final theme = Theme.of(context);
    final memberCount = _committeeMemberCounts[committeeInfo.name] ?? 0;
    final committee = CommitteeDefinitions.findByName(committeeInfo.name);
    final icon = committee?.icon ?? Icons.groups_outlined;
    final primaryColor = committee?.primaryColor ?? _momentumBlue;

    return InkWell(
      onTap: () => _navigateToCommittee(committeeInfo),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            // Committee icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [primaryColor, primaryColor.withOpacity(0.7)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    committeeInfo.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: _unityBlue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.people_outline, size: 14, color: _unityBlue.withOpacity(0.5)),
                      const SizedBox(width: 4),
                      Text(
                        '$memberCount members',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _unityBlue.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Arrow
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _momentumBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_forward_rounded, size: 18, color: _momentumBlue),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: _unityBlue),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _unityBlue),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _momentumBlue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoCommitteesView() {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: _unityBlue.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _momentumBlue.withOpacity(0.1),
                ),
                padding: const EdgeInsets.all(24),
                child: const Icon(
                  Icons.groups_outlined,
                  size: 56,
                  color: _momentumBlue,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No Committee Access',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: _unityBlue,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "You don't appear to be assigned to any committees yet.\nPlease contact your committee chair for assistance.",
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _unityBlue.withOpacity(0.7),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _handleLogout,
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _unityBlue,
                  side: const BorderSide(color: _unityBlue),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkspaceDisabledView() {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: _unityBlue.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.amber.withOpacity(0.1),
                ),
                padding: const EdgeInsets.all(24),
                child: Icon(
                  Icons.lock_clock_outlined,
                  size: 56,
                  color: Colors.amber.shade700,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Workspace Not Available',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: _unityBlue,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your committee(s) do not have workspace access enabled.\n\nIf you believe this is an error, please ask your committee leaders in Slack.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _unityBlue.withOpacity(0.7),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: _loadData,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _momentumBlue,
                      side: const BorderSide(color: _momentumBlue),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _handleLogout,
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign Out'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _unityBlue,
                      side: const BorderSide(color: _unityBlue),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
}
