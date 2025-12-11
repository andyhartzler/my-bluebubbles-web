import 'package:flutter/material.dart';

import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/app/wrappers/titlebar_wrapper.dart';
import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/features/committees/models/committee.dart';
import 'package:bluebubbles/features/committees/screens/committee_workspace_screen.dart';
import 'package:bluebubbles/features/committees/services/committee_repository.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

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
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return _buildScaffold(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
                const SizedBox(height: 16),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return _buildScaffold(
      child: RefreshIndicator(
        onRefresh: _loadData,
        child: _buildContent(context),
      ),
    );
  }

  Widget _buildScaffold({required Widget child}) {
    if (widget.embed) return child;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Committees'),
      ),
      body: child,
    );
  }

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);
    final sortedCommittees = _sortedCommittees;

    return SelectionArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Committees',
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Select a committee to access its workspace',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh),
                onPressed: _loadData,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Overall stat cards
          _buildStatCardsRow(context),
          const SizedBox(height: 32),

          // Committee list (full-width horizontal tiles)
          ...sortedCommittees.map((committee) {
            final stats = _stats[committee.id];
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildCommitteeTile(context, committee, stats),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStatCardsRow(BuildContext context) {
    final theme = Theme.of(context);

    // Calculate totals
    int totalMembers = 0;
    for (final stats in _stats.values) {
      totalMembers += stats.memberCount;
    }

    final slackMessages = _overallStats['slackMessages'] ?? 0;
    final messagesSent = _overallStats['messagesSent'] ?? 0;
    final countiesRepresented = _overallStats['countiesRepresented'] ?? 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;

        final cards = [
          _StatCard(
            icon: Icons.chat_bubble_outline,
            iconColor: Colors.purple,
            label: 'Slack Messages',
            value: _formatNumber(slackMessages),
          ),
          _StatCard(
            icon: Icons.people_outline,
            iconColor: Colors.blue,
            label: 'Active Members',
            value: _formatNumber(totalMembers),
          ),
          _StatCard(
            icon: Icons.message_outlined,
            iconColor: Colors.green,
            label: 'Messages Sent',
            value: _formatNumber(messagesSent),
          ),
          _StatCard(
            icon: Icons.location_on_outlined,
            iconColor: Colors.orange,
            label: 'Counties',
            value: _formatNumber(countiesRepresented),
          ),
        ];

        if (isNarrow) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildStatCard(cards[0], theme)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildStatCard(cards[1], theme)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildStatCard(cards[2], theme)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildStatCard(cards[3], theme)),
                ],
              ),
            ],
          );
        }

        return Row(
          children: cards.map((card) => Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: _buildStatCard(card, theme),
            ),
          )).toList(),
        );
      },
    );
  }

  Widget _buildStatCard(_StatCard card, ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: card.iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(card.icon, color: card.iconColor, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              card.value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              card.label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommitteeTile(BuildContext context, Committee committee, CommitteeStats? stats) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _openCommitteeWorkspace(committee),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [committee.primaryColor, committee.secondaryColor],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Committee icon
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white.withOpacity(0.2),
                child: Icon(committee.icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 20),

              // Committee name and description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      committee.displayName,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      committee.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withOpacity(0.8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Leadership bubbles (side by side)
              if (stats != null && stats.allLeaders.isNotEmpty) ...[
                _buildLeadershipBubbles(stats),
                const SizedBox(width: 16),
              ],

              // Member count badge
              if (stats != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.people, size: 18, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        '${stats.memberCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: 12),

              // Arrow indicator
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeadershipBubbles(CommitteeStats stats) {
    final leaders = stats.allLeaders;
    if (leaders.isEmpty) return const SizedBox.shrink();

    // Show up to 2 leaders side by side
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: leaders.take(2).map((leader) {
        return Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Tooltip(
            message: '${leader.name}\n${leader.title ?? "Leader"}',
            child: CircleAvatar(
              radius: 20,
              backgroundImage: leader.photoUrl != null ? NetworkImage(leader.photoUrl!) : null,
              backgroundColor: Colors.white.withOpacity(0.3),
              child: leader.photoUrl == null
                  ? Text(
                      leader.name.isNotEmpty ? leader.name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
          ),
        );
      }).toList(),
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

class _StatCard {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });
}
