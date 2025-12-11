import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
  bool _loading = true;
  String? _error;

  bool get _crmReady => CRMConfig.crmEnabled && CRMSupabaseService().isInitialized;

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

          // Committee grid
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 900;
              final isMedium = constraints.maxWidth > 600;
              final crossAxisCount = isWide ? 3 : (isMedium ? 2 : 1);
              final childAspectRatio = isWide ? 1.3 : (isMedium ? 1.4 : 2.0);

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: childAspectRatio,
                ),
                itemCount: CommitteeDefinitions.all.length,
                itemBuilder: (context, index) {
                  final committee = CommitteeDefinitions.all[index];
                  final stats = _stats[committee.id];
                  return _buildCommitteeCard(context, committee, stats);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCommitteeCard(BuildContext context, Committee committee, CommitteeStats? stats) {
    final theme = Theme.of(context);

    return Card(
      elevation: 3,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: () => _openCommitteeWorkspace(committee),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [committee.primaryColor, committee.secondaryColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon and member count row
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white.withOpacity(0.2),
                    child: Icon(committee.icon, color: Colors.white),
                  ),
                  const Spacer(),
                  if (stats != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.people, size: 16, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            '${stats.memberCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Committee name
              Text(
                committee.displayName,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),

              // Leadership
              if (stats?.chairName != null || stats?.coChairName != null) ...[
                _buildLeadershipRow(stats),
                const SizedBox(height: 8),
              ],

              // Committee-specific stats
              Expanded(
                child: _buildCommitteeSpecificStats(committee, stats),
              ),

              // Arrow indicator
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeadershipRow(CommitteeStats? stats) {
    final leaders = <Widget>[];

    if (stats?.chairName != null) {
      leaders.add(_buildLeaderChip(stats!.chairName!, stats.chairPhotoUrl, 'Chair'));
    }
    if (stats?.coChairName != null) {
      leaders.add(_buildLeaderChip(stats!.coChairName!, stats.coChairPhotoUrl, 'Co-Chair'));
    }

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: leaders,
    );
  }

  Widget _buildLeaderChip(String name, String? photoUrl, String role) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 10,
            backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
            backgroundColor: Colors.white.withOpacity(0.3),
            child: photoUrl == null
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 10, color: Colors.white),
                  )
                : null,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommitteeSpecificStats(Committee committee, CommitteeStats? stats) {
    if (stats == null) return const SizedBox.shrink();

    final specific = stats.specificStats;
    final currency = NumberFormat.compactSimpleCurrency();

    switch (committee.id) {
      case 'Communications':
        return _buildStatsList([
          _StatItem(Icons.send, '${specific['totalCampaignsSent'] ?? 0} campaigns sent'),
          _StatItem(Icons.email, '${specific['totalEmailsDelivered'] ?? 0} emails delivered'),
        ]);

      case 'Political Affairs':
        return _buildStatsList([
          _StatItem(Icons.event, '${specific['totalEvents'] ?? 0} total events'),
          _StatItem(Icons.upcoming, '${specific['upcomingEvents'] ?? 0} upcoming'),
        ]);

      case 'Policy & Advocacy':
        return _buildStatsList([
          _StatItem(Icons.edit_note, '${specific['totalAdvocacyEmailsGenerated'] ?? 0} emails generated'),
          _StatItem(Icons.send, '${specific['totalAdvocacyEmailsSent'] ?? 0} sent'),
        ]);

      case 'Membership & Outreach':
        return _buildStatsList([
          _StatItem(Icons.people, '${specific['totalMembers'] ?? 0} total members'),
          _StatItem(Icons.verified_user, '${specific['activeMembers'] ?? 0} active'),
        ]);

      case 'Fundraising':
        final totalRaised = specific['totalRaised'] as double? ?? 0.0;
        return _buildStatsList([
          _StatItem(Icons.people, '${specific['totalDonors'] ?? 0} donors'),
          _StatItem(Icons.attach_money, currency.format(totalRaised)),
        ]);

      case 'College Democrats':
        return _buildStatsList([
          _StatItem(Icons.school, '${specific['totalCollegeChapters'] ?? 0} chapters'),
          _StatItem(Icons.verified, '${specific['charteredCollegeChapters'] ?? 0} chartered'),
          _StatItem(Icons.account_balance, '${specific['uniqueColleges'] ?? 0} colleges'),
        ]);

      case 'High School Democrats':
        return _buildStatsList([
          _StatItem(Icons.school, '${specific['totalHSChapters'] ?? 0} chapters'),
          _StatItem(Icons.verified, '${specific['charteredHSChapters'] ?? 0} chartered'),
          _StatItem(Icons.domain, '${specific['uniqueHighSchools'] ?? 0} schools'),
        ]);

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStatsList(List<_StatItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.icon, size: 14, color: Colors.white.withOpacity(0.8)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  item.label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _StatItem {
  final IconData icon;
  final String label;

  const _StatItem(this.icon, this.label);
}
