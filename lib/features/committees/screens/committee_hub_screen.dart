import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bluebubbles/features/committees/models/committee.dart';
import 'package:bluebubbles/features/committees/screens/committee_member_workspace_screen.dart';
import 'package:bluebubbles/features/committees/services/committee_repository.dart';
import 'package:bluebubbles/providers/user_session_provider.dart';

// Brand colors matching the meetings page
const _unityBlue = Color(0xFF273351);
const _momentumBlue = Color(0xFF32A6DE);
const _backgroundAsset = 'assets/images/Blue-Gradient-Background.png';
const _overlayOpacity = 0.18;

/// Committee Hub screen for non-executive committee members
///
/// This is the main view shown to committee members after login.
/// It displays their committee(s) as beautiful cards and allows
/// navigation to each committee's workspace.
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

      for (final committee in session.userCommittees) {
        final count = await _repository.getMemberCountForCommittee(committee.name);
        counts[committee.name] = count;
      }

      if (!mounted) return;
      setState(() {
        _committeeMemberCounts = counts;
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
    // Find matching committee definition
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
            child: Container(
              color: Colors.white.withOpacity(_overlayOpacity),
            ),
          ),
          // Content
          Positioned.fill(
            child: _buildContent(),
          ),
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

    final committees = session.userCommittees;
    if (committees.isEmpty) {
      return _buildNoCommitteesView();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 720;
        final horizontalPadding = isCompact ? 16.0 : 32.0;

        return RefreshIndicator(
          onRefresh: () async {
            await session.refreshSession();
            await _loadData();
          },
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(horizontalPadding, 24, horizontalPadding, 0),
                sliver: SliverToBoxAdapter(
                  child: _buildHeader(session, committees.length),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 32),
                sliver: _buildCommitteeList(committees),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(UserSessionProvider session, int committeeCount) {
    final theme = Theme.of(context);
    final greeting = _getGreeting();

    return Row(
      children: [
        Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: _momentumBlue,
          ),
          padding: const EdgeInsets.all(12),
          child: const Icon(Icons.groups_outlined, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting, ${session.displayName.split(' ').first}',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: _unityBlue,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                committeeCount == 1
                    ? 'Your Committee'
                    : 'Your $committeeCount Committees',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _unityBlue.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
        // Logout button
        IconButton(
          onPressed: _handleLogout,
          icon: const Icon(Icons.logout, color: _unityBlue),
          tooltip: 'Sign out',
        ),
      ],
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Widget _buildCommitteeList(List<UserCommitteeInfo> committees) {
    if (committees.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final itemCount = committees.length * 2 - 1;
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index.isOdd) {
            return const SizedBox(height: 16);
          }
          final itemIndex = index ~/ 2;
          return _buildCommitteeCard(committees[itemIndex]);
        },
        childCount: itemCount > 0 ? itemCount : 0,
      ),
    );
  }

  Widget _buildCommitteeCard(UserCommitteeInfo committeeInfo) {
    final theme = Theme.of(context);
    final memberCount = _committeeMemberCounts[committeeInfo.name] ?? 0;
    final toolCount = committeeInfo.tools.length;

    // Get committee definition for icon and colors
    final committee = CommitteeDefinitions.findByName(committeeInfo.name);
    final icon = committee?.icon ?? Icons.groups_outlined;
    final primaryColor = committee?.primaryColor ?? _momentumBlue;

    return Card(
      elevation: 4,
      color: _unityBlue,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _navigateToCommittee(committeeInfo),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Row(
            children: [
              // Committee icon
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryColor.withOpacity(0.3),
                ),
                padding: const EdgeInsets.all(14),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 20),
              // Committee info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      committeeInfo.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (committeeInfo.description != null && committeeInfo.description!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          committeeInfo.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ),
                    // Stats chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _buildInfoChip(Icons.people_outline, '$memberCount members'),
                        _buildInfoChip(Icons.build_outlined, '$toolCount tools'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoCommitteesView() {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _unityBlue.withOpacity(0.1),
              ),
              padding: const EdgeInsets.all(24),
              child: const Icon(
                Icons.groups_outlined,
                size: 64,
                color: _unityBlue,
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
              "You don't appear to be assigned to any committees yet. Please contact your committee chair or reach out to info@moyoungdemocrats.org for assistance.",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: _unityBlue.withOpacity(0.7),
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}
