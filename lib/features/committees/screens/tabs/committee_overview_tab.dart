import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:bluebubbles/features/calendar/widgets/event_create_dialog.dart';
import 'package:bluebubbles/features/calendar/widgets/responsive_calendar_widget.dart';
import 'package:bluebubbles/features/committees/models/committee.dart';
import 'package:bluebubbles/features/committees/services/committee_repository.dart';
import 'package:bluebubbles/features/committees/widgets/cors_aware_avatar.dart';
import 'package:bluebubbles/features/meetings/widgets/upcoming_meetings_widget.dart';
import 'package:bluebubbles/screens/crm/member_detail_screen.dart';

class CommitteeOverviewTab extends StatefulWidget {
  final Committee committee;
  final void Function(int tabIndex)? onNavigateToTab;
  final void Function(String schoolName)? onFilterMembersBySchool;

  const CommitteeOverviewTab({
    super.key,
    required this.committee,
    this.onNavigateToTab,
    this.onFilterMembersBySchool,
  });

  @override
  State<CommitteeOverviewTab> createState() => _CommitteeOverviewTabState();
}

class _CommitteeOverviewTabState extends State<CommitteeOverviewTab> {
  final CommitteeRepository _repository = CommitteeRepository();
  CommitteeStats? _stats;
  Map<String, int> _schoolDistribution = {};
  bool _loading = true;
  String? _error;
  bool _schoolsExpanded = false; // Collapsed by default

  Committee get committee => widget.committee;

  bool get _isSchoolCommittee =>
      committee.id == 'College Democrats' || committee.id == 'High School Democrats';

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final stats = await _repository.getCommitteeStats(committee);

      // Load school distribution for College/HS Democrats (filtered by committee membership)
      Map<String, int> distribution = {};
      if (committee.id == 'College Democrats') {
        distribution = await _repository.getCollegeDistribution(committeeName: committee.name);
      } else if (committee.id == 'High School Democrats') {
        distribution = await _repository.getHighSchoolDistribution(committeeName: committee.name);
      }

      if (!mounted) return;
      setState(() {
        _stats = stats;
        _schoolDistribution = distribution;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load statistics: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
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
                onPressed: _loadStats,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadStats,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildStatsSection(context),
          const SizedBox(height: 24),
          UpcomingMeetingsWidget(
            committee: committee,
            accentColor: committee.primaryColor,
            onNavigateToEmail: widget.onNavigateToTab != null
                ? () => widget.onNavigateToTab!(3) // Email tab index
                : null,
            onNavigateToMessages: widget.onNavigateToTab != null
                ? () => widget.onNavigateToTab!(4) // Messages tab index
                : null,
          ),
          const SizedBox(height: 24),
          ResponsiveCalendarWidget(
            committeeName: committee.name,
            accentColor: committee.primaryColor,
            onAddEvent: () => _showAddEventDialog(context),
          ),
          const SizedBox(height: 24),
          if (_isSchoolCommittee && _schoolDistribution.isNotEmpty) ...[
            _buildSchoolVisualizationSection(context),
            const SizedBox(height: 24),
          ],
          _buildQuickActionsSection(context),
          const SizedBox(height: 24),
          _buildCommitteeInfoSection(context),
        ],
      ),
    );
  }

  Widget _buildStatsSection(BuildContext context) {
    final theme = Theme.of(context);
    final stats = _stats;
    final specific = stats?.specificStats ?? {};
    final currency = NumberFormat.compactSimpleCurrency();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics_outlined, color: committee.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Committee Statistics',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 500;
                final isMobile = constraints.maxWidth < 400;

                if (isWide) {
                  final statCards = _buildStatCards(specific, currency, compact: false);
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: statCards.map((card) => SizedBox(
                      width: (constraints.maxWidth - 32) / 3,
                      child: card,
                    )).toList(),
                  );
                }

                // Mobile: horizontal thin tiles spanning full width
                final statData = _getStatData(specific, currency);
                return Column(
                  children: statData.map((data) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildMobileStatTile(
                      icon: data['icon'] as IconData,
                      label: data['label'] as String,
                      value: data['value'] as String,
                      color: data['color'] as Color,
                    ),
                  )).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getStatData(Map<String, dynamic> specific, NumberFormat currency) {
    final data = <Map<String, dynamic>>[];

    // Member count is common to all
    data.add({
      'icon': Icons.people,
      'label': 'Members',
      'value': '${_stats?.memberCount ?? 0}',
      'color': committee.primaryColor,
    });

    // Committee-specific stats
    switch (committee.id) {
      case 'Communications':
        data.add({
          'icon': Icons.visibility,
          'label': 'Total Impressions',
          'value': _formatNumber(specific['totalImpressions'] ?? 0),
          'color': Colors.blue,
        });
        data.add({
          'icon': Icons.people_alt,
          'label': 'Total Followers',
          'value': _formatNumber(specific['totalFollowers'] ?? 0),
          'color': Colors.green,
        });
        break;

      case 'Political Affairs':
        data.add({
          'icon': Icons.event,
          'label': 'Total Events',
          'value': '${specific['totalEvents'] ?? 0}',
          'color': Colors.blue,
        });
        data.add({
          'icon': Icons.upcoming,
          'label': 'Upcoming Events',
          'value': '${specific['upcomingEvents'] ?? 0}',
          'color': Colors.orange,
        });
        break;

      case 'Policy & Advocacy':
        data.add({
          'icon': Icons.edit_note,
          'label': 'Emails Generated',
          'value': '${specific['totalAdvocacyEmailsGenerated'] ?? 0}',
          'color': Colors.purple,
        });
        data.add({
          'icon': Icons.send,
          'label': 'Emails Sent',
          'value': '${specific['totalAdvocacyEmailsSent'] ?? 0}',
          'color': Colors.green,
        });
        break;

      case 'Membership & Outreach':
        data.add({
          'icon': Icons.group_add,
          'label': 'Total Members',
          'value': '${specific['totalMembers'] ?? 0}',
          'color': Colors.teal,
        });
        data.add({
          'icon': Icons.verified_user,
          'label': 'Active Members',
          'value': '${specific['activeMembers'] ?? 0}',
          'color': Colors.green,
        });
        break;

      case 'Fundraising':
        data.add({
          'icon': Icons.volunteer_activism,
          'label': 'Total Donors',
          'value': '${specific['totalDonors'] ?? 0}',
          'color': Colors.orange,
        });
        data.add({
          'icon': Icons.attach_money,
          'label': 'Total Raised',
          'value': currency.format(specific['totalRaised'] ?? 0.0),
          'color': Colors.green,
        });
        break;

      case 'College Democrats':
        data.add({
          'icon': Icons.school,
          'label': 'Total Chapters',
          'value': '${specific['totalCollegeChapters'] ?? 0}',
          'color': Colors.blue,
        });
        data.add({
          'icon': Icons.account_balance,
          'label': 'Unique Colleges',
          'value': '${specific['uniqueColleges'] ?? 0}',
          'color': Colors.purple,
        });
        break;

      case 'High School Democrats':
        data.add({
          'icon': Icons.school,
          'label': 'Total Chapters',
          'value': '${specific['totalHSChapters'] ?? 0}',
          'color': Colors.green,
        });
        data.add({
          'icon': Icons.domain,
          'label': 'Unique Schools',
          'value': '${specific['uniqueHighSchools'] ?? 0}',
          'color': Colors.teal,
        });
        break;
    }

    return data;
  }

  String _formatNumber(dynamic number) {
    final n = (number is int) ? number : int.tryParse(number.toString()) ?? 0;
    if (n >= 1000000) {
      return '${(n / 1000000).toStringAsFixed(1)}M';
    } else if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(1)}K';
    }
    return n.toString();
  }

  List<Widget> _buildStatCards(Map<String, dynamic> specific, NumberFormat currency, {bool compact = false}) {
    final data = _getStatData(specific, currency);
    return data.map((d) => _buildStatCard(
      icon: d['icon'] as IconData,
      label: d['label'] as String,
      value: d['value'] as String,
      color: d['color'] as Color,
    )).toList();
  }

  Widget _buildMobileStatTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: color.withOpacity(0.8),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSchoolVisualizationSection(BuildContext context) {
    final theme = Theme.of(context);
    final isCollege = committee.id == 'College Democrats';
    final schoolLabel = isCollege ? 'Colleges' : 'High Schools';
    final schoolIcon = isCollege ? Icons.account_balance : Icons.domain;

    // Sort schools by member count (descending)
    final sortedSchools = _schoolDistribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final totalMembers = sortedSchools.fold<int>(0, (sum, e) => sum + e.value);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row - always visible, tappable to expand/collapse
            InkWell(
              onTap: () => setState(() => _schoolsExpanded = !_schoolsExpanded),
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  Icon(schoolIcon, color: committee.primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$schoolLabel Represented',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: committee.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${sortedSchools.length} ${schoolLabel.toLowerCase()}',
                      style: TextStyle(
                        color: committee.primaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _schoolsExpanded ? Icons.expand_less : Icons.expand_more,
                    color: committee.primaryColor,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$totalMembers members across ${sortedSchools.length} ${schoolLabel.toLowerCase()}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
              ),
            ),
            // Expandable content
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: sortedSchools.map((entry) {
                    final school = entry.key;
                    final count = entry.value;
                    final percentage = (count / totalMembers * 100).round();

                    return _buildSchoolChip(
                      school: school,
                      count: count,
                      percentage: percentage,
                      isCollege: isCollege,
                    );
                  }).toList(),
                ),
              ),
              crossFadeState: _schoolsExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSchoolChip({
    required String school,
    required int count,
    required int percentage,
    required bool isCollege,
  }) {
    // Color intensity based on member count relative to the max
    final maxCount = _schoolDistribution.values.reduce((a, b) => a > b ? a : b);
    final intensity = (count / maxCount).clamp(0.3, 1.0);

    final baseColor = isCollege ? Colors.blue : Colors.green;
    final chipColor = baseColor.withOpacity(intensity * 0.15 + 0.05);
    final borderColor = baseColor.withOpacity(intensity * 0.4 + 0.1);
    final textColor = baseColor.shade700;

    return InkWell(
      onTap: () {
        // Navigate to members tab with school filter
        widget.onFilterMembersBySchool?.call(school);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: chipColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isCollege ? Icons.school : Icons.domain,
              size: 16,
              color: textColor,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                school,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: baseColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsSection(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flash_on, color: committee.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Quick Actions',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 400;

                if (isMobile) {
                  // Stack buttons vertically on mobile
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildActionButton(
                        icon: Icons.email_outlined,
                        label: 'Email Committee',
                        onPressed: () => widget.onNavigateToTab?.call(3),
                        fullWidth: true,
                      ),
                      const SizedBox(height: 10),
                      _buildActionButton(
                        icon: Icons.message_outlined,
                        label: 'Message Committee',
                        onPressed: () => widget.onNavigateToTab?.call(4),
                        fullWidth: true,
                      ),
                      const SizedBox(height: 10),
                      _buildActionButton(
                        icon: Icons.people_outline,
                        label: 'View Members',
                        onPressed: () => widget.onNavigateToTab?.call(1),
                        fullWidth: true,
                      ),
                    ],
                  );
                }

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildActionButton(
                      icon: Icons.email_outlined,
                      label: 'Email Committee',
                      onPressed: () => widget.onNavigateToTab?.call(3),
                    ),
                    _buildActionButton(
                      icon: Icons.message_outlined,
                      label: 'Message Committee',
                      onPressed: () => widget.onNavigateToTab?.call(4),
                    ),
                    _buildActionButton(
                      icon: Icons.people_outline,
                      label: 'View Members',
                      onPressed: () => widget.onNavigateToTab?.call(1),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool fullWidth = false,
  }) {
    final button = ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: committee.primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );

    if (fullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }

  Widget _buildCommitteeInfoSection(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: committee.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'About This Committee',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              committee.description,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            if (_stats != null && (_stats!.chairs.isNotEmpty || _stats!.coChairs.isNotEmpty)) ...[
              const Divider(),
              const SizedBox(height: 12),
              Text(
                'Leadership',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              // Show all chairs
              ..._stats!.chairs.map((chair) => _buildLeaderRow(
                _stats!.chairs.length > 1 ? 'Co-Chair' : 'Chair',
                chair,
              )),
              // Show all co-chairs
              ..._stats!.coChairs.map((coChair) => _buildLeaderRow(
                'Co-Chair',
                coChair,
              )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderRow(String role, CommitteeLeader leader) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _navigateToMemberProfile(leader.memberId),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              CorsAwareAvatar(
                imageUrl: leader.photoUrl,
                radius: 20,
                fallbackText: leader.name,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(leader.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(role, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
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

  Future<void> _showAddEventDialog(BuildContext context) async {
    final event = await EventCreateDialog.show(
      context,
      committeeName: committee.name,
    );

    if (event != null && mounted) {
      // Refresh the page to show new event
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Event "${event.title}" created')),
      );
    }
  }
}
