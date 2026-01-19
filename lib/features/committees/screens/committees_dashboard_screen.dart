import 'package:flutter/material.dart';

import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/app/wrappers/titlebar_wrapper.dart';
import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/features/committees/models/committee.dart';
import 'package:bluebubbles/features/committees/screens/committee_workspace_screen.dart';
import 'package:bluebubbles/features/committees/services/committee_repository.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

// Brand colors matching Member Portal design
const _unityBlue = Color(0xFF273351);
const _momentumBlue = Color(0xFF32A6DE);
const _darkBgStart = Color(0xFF1B2336);
const _darkBgEnd = Color(0xFF0F1624);

class CommitteesDashboardScreen extends StatefulWidget {
  final bool embed;

  const CommitteesDashboardScreen({super.key, this.embed = false});

  @override
  State<CommitteesDashboardScreen> createState() => _CommitteesDashboardScreenState();
}

class _CommitteesDashboardScreenState extends State<CommitteesDashboardScreen> {
  final CommitteeRepository _repository = CommitteeRepository();
  final Map<String, CommitteeStats> _stats = {};
  Map<String, int> _overallStats = {};
  bool _loading = true;
  String? _error;

  bool get _crmReady => CRMConfig.crmEnabled && CRMSupabaseService().isInitialized;

  /// Returns committees sorted: College Democrats first, High School Democrats second, then alphabetically
  List<Committee> get _sortedCommittees {
    final committees = List<Committee>.from(CommitteeDefinitions.all);
    committees.sort((a, b) {
      // College Democrats always first
      if (a.id == 'College Democrats') return -1;
      if (b.id == 'College Democrats') return 1;
      // High School Democrats second
      if (a.id == 'High School Democrats') return -1;
      if (b.id == 'High School Democrats') return 1;
      // Rest alphabetically
      return a.displayName.compareTo(b.displayName);
    });
    return committees;
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!_crmReady) {
      setState(() {
        _loading = false;
        _error = 'CRM Supabase is not configured.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Load committee stats and overall stats in parallel
      final results = await Future.wait([
        _loadCommitteeStats(),
        _repository.getOverallStats(),
      ]);

      if (!mounted) return;

      setState(() {
        _overallStats = results[1] as Map<String, int>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load committee data: $e';
        _loading = false;
      });
    }
  }

  Future<void> _loadCommitteeStats() async {
    final futures = CommitteeDefinitions.all.map((committee) async {
      final stats = await _repository.getCommitteeStats(committee);
      return MapEntry(committee.id, stats);
    });

    final results = await Future.wait(futures);

    if (!mounted) return;

    setState(() {
      _stats.clear();
      for (final entry in results) {
        _stats[entry.key] = entry.value;
      }
    });
  }

  void _openCommitteeWorkspace(Committee committee) {
    Navigator.of(context).push(
      ThemeSwitcher.buildPageRoute(
        builder: (context) => TitleBarWrapper(
          child: CommitteeWorkspaceScreen(committee: committee),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_crmReady) {
      return _buildScaffold(
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'CRM Supabase is not configured. Add Supabase credentials to enable Committees.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (_loading) {
      return _buildScaffold(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_darkBgStart, _darkBgEnd],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Center(
            child: CircularProgressIndicator(color: _momentumBlue),
          ),
        ),
      );
    }

    if (_error != null) {
      return _buildScaffold(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_darkBgStart, _darkBgEnd],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.white70),
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
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
          ),
        ),
      );
    }

    return _buildScaffold(
      child: RefreshIndicator(
        onRefresh: _loadData,
        color: _momentumBlue,
        backgroundColor: _unityBlue,
        child: _buildContent(context),
      ),
    );
  }

  Widget _buildScaffold({required Widget child}) {
    if (widget.embed) return child;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Committees'),
        backgroundColor: _unityBlue,
        foregroundColor: Colors.white,
      ),
      body: child,
    );
  }

  Widget _buildContent(BuildContext context) {
    final sortedCommittees = _sortedCommittees;

    return Stack(
      children: [
        // Dark gradient background
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_darkBgStart, _darkBgEnd],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        // Content
        Positioned.fill(
          child: SelectionArea(
            child: ListView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              padding: const EdgeInsets.all(24),
              children: [
                // Header Card with gradient
                _buildHeaderCard(),
                const SizedBox(height: 32),

                // Section title for committees
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select a Committee',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${sortedCommittees.length} committees',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Committee list
                ...sortedCommittees.map((committee) {
                  final stats = _stats[committee.id];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildCommitteeTile(context, committee, stats),
                  );
                }),

                const SizedBox(height: 16),
                // Footer note
                Text(
                  'Each committee workspace includes member management, Slack analytics, and collaborative tools.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderCard() {
    // Calculate totals
    int totalMembers = 0;
    for (final stats in _stats.values) {
      totalMembers += stats.memberCount;
    }

    final slackMessages = _overallStats['slackMessages'] ?? 0;
    final totalImpressions = _overallStats['totalImpressions'] ?? 0;
    final countiesRepresented = _overallStats['countiesRepresented'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_unityBlue, _momentumBlue],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.groups_3_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Committees Dashboard',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Manage and monitor committee activities',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                tooltip: 'Refresh data',
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Stats grid
          _buildStatsGrid(
            slackMessages: slackMessages,
            totalMembers: totalMembers,
            totalImpressions: totalImpressions,
            countiesRepresented: countiesRepresented,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid({
    required int slackMessages,
    required int totalMembers,
    required int totalImpressions,
    required int countiesRepresented,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        int columns = 1;

        if (maxWidth >= 800) {
          columns = 4;
        } else if (maxWidth >= 500) {
          columns = 2;
        }

        const spacing = 12.0;
        final cardWidth = columns > 1
            ? (maxWidth - spacing * (columns - 1)) / columns
            : maxWidth;

        final cards = [
          _buildStatCard(
            title: 'Slack Messages',
            value: _formatNumber(slackMessages),
            icon: Icons.chat_bubble_outline_rounded,
            width: cardWidth,
          ),
          _buildStatCard(
            title: 'Active Members',
            value: _formatNumber(totalMembers),
            icon: Icons.people_outline_rounded,
            width: cardWidth,
          ),
          _buildStatCard(
            title: 'Impressions',
            value: _formatNumber(totalImpressions),
            icon: Icons.visibility_outlined,
            width: cardWidth,
          ),
          _buildStatCard(
            title: 'Counties',
            value: _formatNumber(countiesRepresented),
            icon: Icons.location_on_outlined,
            width: cardWidth,
          ),
        ];

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards,
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required double width,
  }) {
    return SizedBox(
      width: width,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(8),
              child: Icon(icon, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.7),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommitteeTile(BuildContext context, Committee committee, CommitteeStats? stats) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openCommitteeWorkspace(committee),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                committee.primaryColor,
                committee.secondaryColor,
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: committee.primaryColor.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              // Committee icon
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(12),
                child: Icon(
                  committee.icon,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),

              // Committee name and description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      committee.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (committee.description != null && committee.description!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          committee.description!,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Member count badge
              if (stats != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.people, size: 16, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        '${stats.memberCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: 12),

              // Arrow indicator
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}
