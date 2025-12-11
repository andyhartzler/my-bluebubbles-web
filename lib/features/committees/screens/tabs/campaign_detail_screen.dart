import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/models/crm/subscriber.dart';
import 'package:bluebubbles/screens/crm/member_detail_screen.dart';

/// Model for a campaign with its associated data
class CampaignData {
  final String id;
  final String name;
  final String description;
  final DateTime? startDate;
  final int totalGenerated;
  final int totalSent;
  final int uniqueParticipants;
  final Map<String, int> sendMethodBreakdown;
  final Map<String, int> participantsByZip;
  final Map<String, int> participantsByCounty;
  final List<CampaignParticipant> participants;

  const CampaignData({
    required this.id,
    required this.name,
    required this.description,
    this.startDate,
    this.totalGenerated = 0,
    this.totalSent = 0,
    this.uniqueParticipants = 0,
    this.sendMethodBreakdown = const {},
    this.participantsByZip = const {},
    this.participantsByCounty = const {},
    this.participants = const [],
  });

  double get sendRate => totalGenerated > 0 ? (totalSent / totalGenerated * 100) : 0.0;
}

/// Model for a campaign participant with optional member/subscriber link
class CampaignParticipant {
  final String name;
  final String email;
  final String? zipCode;
  final String? county;
  final DateTime? sentAt;
  final String? sendMethod;
  final DateTime createdAt;
  final String? profilePhotoUrl;
  final Member? linkedMember;
  final Subscriber? linkedSubscriber;

  const CampaignParticipant({
    required this.name,
    required this.email,
    this.zipCode,
    this.county,
    this.sentAt,
    this.sendMethod,
    required this.createdAt,
    this.profilePhotoUrl,
    this.linkedMember,
    this.linkedSubscriber,
  });

  bool get isSent => sentAt != null;
  bool get isMember => linkedMember != null;
  bool get isSubscriber => linkedSubscriber != null;
  bool get hasProfile => isMember || isSubscriber;
}

/// Detailed campaign view with charts and full participant list
class CampaignDetailScreen extends StatefulWidget {
  final CampaignData campaign;

  const CampaignDetailScreen({
    super.key,
    required this.campaign,
  });

  @override
  State<CampaignDetailScreen> createState() => _CampaignDetailScreenState();
}

class _CampaignDetailScreenState extends State<CampaignDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();

  static const List<Color> _chartColors = [
    Color(0xFF6366F1), // Indigo
    Color(0xFF8B5CF6), // Violet
    Color(0xFF10B981), // Emerald
    Color(0xFFF59E0B), // Amber
    Color(0xFFEC4899), // Pink
    Color(0xFF3B82F6), // Blue
    Color(0xFFEF4444), // Red
    Color(0xFF14B8A6), // Teal
    Color(0xFFF97316), // Orange
    Color(0xFF84CC16), // Lime
  ];

  static const _methodColors = {
    'mail_app': Colors.blue,
    'gmail': Colors.red,
    'outlook': Colors.indigo,
    'copy_paste': Colors.orange,
    'auto_shortcut': Colors.green,
    'unknown': Colors.grey,
  };

  static const _methodLabels = {
    'mail_app': 'Mail App',
    'gmail': 'Gmail',
    'outlook': 'Outlook',
    'copy_paste': 'Copy & Paste',
    'auto_shortcut': 'Auto Shortcut',
    'unknown': 'Unknown',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.campaign.name),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
            Tab(text: 'Geography', icon: Icon(Icons.map)),
            Tab(text: 'Participants', icon: Icon(Icons.people)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(theme, colorScheme),
          _buildGeographyTab(theme, colorScheme),
          _buildParticipantsTab(theme, colorScheme),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(ThemeData theme, ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Campaign description
          if (widget.campaign.description.isNotEmpty) ...[
            Text(
              widget.campaign.description,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Key metrics row
          _buildMetricsRow(theme, colorScheme),
          const SizedBox(height: 32),

          // Send method analysis with pie chart
          _buildSendMethodChart(theme, colorScheme),
          const SizedBox(height: 32),

          // Participation timeline (bar chart)
          _buildParticipationTimeline(theme, colorScheme),
        ],
      ),
    );
  }

  Widget _buildMetricsRow(ThemeData theme, ColorScheme colorScheme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        // Per user request: sent should equal generated
        final displaySent = widget.campaign.totalGenerated;
        final displayRate = widget.campaign.totalGenerated > 0 ? 100.0 : 0.0;

        final cards = [
          _buildMetricCard(
            icon: Icons.edit_note,
            label: 'Emails Generated',
            value: '${widget.campaign.totalGenerated}',
            color: Colors.blue,
          ),
          _buildMetricCard(
            icon: Icons.send,
            label: 'Emails Sent',
            value: '$displaySent',
            color: Colors.green,
          ),
          _buildMetricCard(
            icon: Icons.people,
            label: 'Unique Participants',
            value: '${widget.campaign.uniqueParticipants}',
            color: Colors.purple,
          ),
          _buildMetricCard(
            icon: Icons.percent,
            label: 'Send Rate',
            value: '${displayRate.toStringAsFixed(1)}%',
            color: Colors.orange,
          ),
        ];

        if (isWide) {
          return Row(
            children: cards.map((card) => Expanded(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: card,
            ))).toList(),
          );
        }

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards.map((card) => SizedBox(
            width: (constraints.maxWidth - 12) / 2,
            child: card,
          )).toList(),
        );
      },
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
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

  Widget _buildSendMethodChart(ThemeData theme, ColorScheme colorScheme) {
    final breakdown = widget.campaign.sendMethodBreakdown;
    if (breakdown.isEmpty) return const SizedBox.shrink();

    final total = breakdown.values.fold(0, (sum, count) => sum + count);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.pie_chart, color: Colors.teal),
                const SizedBox(width: 8),
                Text(
                  'Send Method Analysis',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 250,
              child: Row(
                children: [
                  // Pie chart
                  Expanded(
                    flex: 2,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 50,
                        sections: breakdown.entries.toList().asMap().entries.map((entry) {
                          final method = entry.value.key;
                          final count = entry.value.value;
                          final percentage = total > 0 ? (count / total * 100) : 0.0;
                          final color = _methodColors[method] ?? _chartColors[entry.key % _chartColors.length];

                          return PieChartSectionData(
                            value: count.toDouble(),
                            title: '${percentage.toStringAsFixed(0)}%',
                            color: color,
                            radius: 80,
                            titleStyle: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  // Legend
                  Expanded(
                    flex: 1,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: breakdown.entries.map((entry) {
                        final method = entry.key;
                        final count = entry.value;
                        final color = _methodColors[method] ?? Colors.grey;
                        final label = _methodLabels[method] ?? method;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  label,
                                  style: theme.textTheme.bodySmall,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '$count',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipationTimeline(ThemeData theme, ColorScheme colorScheme) {
    // Group participants by date
    final participantsByDate = <String, int>{};
    final dateFormat = DateFormat('MMM d');

    for (final participant in widget.campaign.participants) {
      final date = dateFormat.format(participant.createdAt);
      participantsByDate[date] = (participantsByDate[date] ?? 0) + 1;
    }

    if (participantsByDate.isEmpty) return const SizedBox.shrink();

    // Sort by date and take last 14 days
    final sortedEntries = participantsByDate.entries.toList();
    final displayEntries = sortedEntries.take(14).toList();
    final maxValue = displayEntries.map((e) => e.value).fold(0, (a, b) => a > b ? a : b);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.timeline, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Participation Over Time',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxValue.toDouble() * 1.2,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          '${displayEntries[groupIndex].key}\n${rod.toY.toInt()} participants',
                          const TextStyle(color: Colors.white),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= displayEntries.length) return const Text('');
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              displayEntries[value.toInt()].key,
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxValue > 0 ? maxValue / 5 : 1,
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: displayEntries.asMap().entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value.value.toDouble(),
                          color: Colors.purple,
                          width: 16,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeographyTab(ThemeData theme, ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // County distribution pie chart
          _buildCountyDistributionChart(theme, colorScheme),
          const SizedBox(height: 32),

          // ZIP code distribution bar chart
          _buildZipCodeChart(theme, colorScheme),
          const SizedBox(height: 32),

          // Full geographic breakdown
          _buildGeographicBreakdown(theme, colorScheme),
        ],
      ),
    );
  }

  Widget _buildCountyDistributionChart(ThemeData theme, ColorScheme colorScheme) {
    final byCounty = widget.campaign.participantsByCounty;
    if (byCounty.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.map_outlined, size: 48, color: colorScheme.onSurfaceVariant.withOpacity(0.5)),
              const SizedBox(height: 16),
              Text(
                'No county data available',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final sortedEntries = byCounty.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topCounties = sortedEntries.take(8).toList();
    final total = byCounty.values.fold(0, (sum, count) => sum + count);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_city, color: Colors.indigo),
                const SizedBox(width: 8),
                Text(
                  'County Distribution',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${byCounty.length} counties',
                    style: TextStyle(
                      color: Colors.indigo,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 280,
              child: Row(
                children: [
                  // Pie chart
                  Expanded(
                    flex: 2,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        sections: topCounties.asMap().entries.map((entry) {
                          final county = entry.value.key;
                          final count = entry.value.value;
                          final percentage = total > 0 ? (count / total * 100) : 0.0;
                          final color = _chartColors[entry.key % _chartColors.length];

                          return PieChartSectionData(
                            value: count.toDouble(),
                            title: percentage >= 5 ? '${percentage.toStringAsFixed(0)}%' : '',
                            color: color,
                            radius: 70,
                            titleStyle: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  // Legend
                  Expanded(
                    flex: 1,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: topCounties.asMap().entries.map((entry) {
                          final county = entry.value.key;
                          final count = entry.value.value;
                          final color = _chartColors[entry.key % _chartColors.length];

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    county,
                                    style: theme.textTheme.bodySmall,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '$count',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZipCodeChart(ThemeData theme, ColorScheme colorScheme) {
    final byZip = widget.campaign.participantsByZip;
    if (byZip.isEmpty) return const SizedBox.shrink();

    final sortedEntries = byZip.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topZips = sortedEntries.take(10).toList();
    final maxValue = topZips.isNotEmpty ? topZips.first.value : 0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.pin_drop, color: Colors.red),
                const SizedBox(width: 8),
                Text(
                  'Top ZIP Codes',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${byZip.length} ZIP codes',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 300,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxValue.toDouble() * 1.2,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          'ZIP ${topZips[groupIndex].key}\n${rod.toY.toInt()} participants',
                          const TextStyle(color: Colors.white),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= topZips.length) return const Text('');
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Transform.rotate(
                              angle: -0.5,
                              child: Text(
                                topZips[value.toInt()].key,
                                style: const TextStyle(fontSize: 10),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: topZips.asMap().entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value.value.toDouble(),
                          gradient: LinearGradient(
                            colors: [Colors.red.shade400, Colors.red.shade700],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          width: 24,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeographicBreakdown(ThemeData theme, ColorScheme colorScheme) {
    final byZip = widget.campaign.participantsByZip;
    if (byZip.isEmpty) return const SizedBox.shrink();

    final sortedEntries = byZip.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.list_alt, color: Colors.teal),
                const SizedBox(width: 8),
                Text(
                  'All ZIP Codes',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: sortedEntries.map((entry) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.teal.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        entry.key,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.teal,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${entry.value}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantsTab(ThemeData theme, ColorScheme colorScheme) {
    final participants = widget.campaign.participants;
    final dateFormat = DateFormat('MMM d, y h:mm a');

    if (participants.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: colorScheme.onSurfaceVariant.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              'No participants yet',
              style: theme.textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    // Summary stats
    final membersCount = participants.where((p) => p.isMember).length;
    final subscribersCount = participants.where((p) => p.isSubscriber && !p.isMember).length;
    // Show generated count as sent (since they should be equal per user request)
    final displaySentCount = widget.campaign.totalGenerated;

    return Column(
      children: [
        // Summary bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            border: Border(
              bottom: BorderSide(color: colorScheme.outlineVariant),
            ),
          ),
          child: Row(
            children: [
              _buildParticipantStat(
                icon: Icons.people,
                label: 'Total',
                value: '${participants.length}',
                color: Colors.purple,
              ),
              const SizedBox(width: 24),
              _buildParticipantStat(
                icon: Icons.card_membership,
                label: 'Members',
                value: '$membersCount',
                color: Colors.blue,
              ),
              const SizedBox(width: 24),
              _buildParticipantStat(
                icon: Icons.mail,
                label: 'Subscribers',
                value: '$subscribersCount',
                color: Colors.orange,
              ),
              const SizedBox(width: 24),
              _buildParticipantStat(
                icon: Icons.check_circle,
                label: 'Generated',
                value: '$displaySentCount',
                color: Colors.green,
              ),
            ],
          ),
        ),
        // Participants list
        Expanded(
          child: ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: participants.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final participant = participants[index];
              return _buildParticipantCard(theme, colorScheme, participant, dateFormat);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildParticipantStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildParticipantCard(
    ThemeData theme,
    ColorScheme colorScheme,
    CampaignParticipant participant,
    DateFormat dateFormat,
  ) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: participant.hasProfile
            ? () => _openParticipantProfile(participant)
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Profile picture
              _buildParticipantAvatar(participant),
              const SizedBox(width: 16),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            participant.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (participant.isMember)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Member',
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        else if (participant.isSubscriber)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Subscriber',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      participant.email,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (participant.zipCode?.isNotEmpty == true)
                          _buildInfoChip(
                            icon: Icons.location_on,
                            label: participant.zipCode!,
                            color: Colors.red,
                          ),
                        if (participant.sendMethod?.isNotEmpty == true)
                          _buildInfoChip(
                            icon: Icons.send,
                            label: _methodLabels[participant.sendMethod] ?? participant.sendMethod!,
                            color: _methodColors[participant.sendMethod] ?? Colors.grey,
                          ),
                        _buildInfoChip(
                          icon: Icons.schedule,
                          label: dateFormat.format(participant.createdAt),
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (participant.hasProfile) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildParticipantAvatar(CampaignParticipant participant) {
    final photoUrl = participant.profilePhotoUrl ??
        participant.linkedMember?.primaryProfilePhotoUrl;

    if (photoUrl != null && photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 28,
        backgroundImage: NetworkImage(photoUrl),
        onBackgroundImageError: (_, __) {},
        child: null,
      );
    }

    // Fallback to initials
    final initials = participant.name.isNotEmpty
        ? participant.name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
        : '?';

    return CircleAvatar(
      radius: 28,
      backgroundColor: Colors.purple.withOpacity(0.2),
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.purple,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: color),
          ),
        ],
      ),
    );
  }

  void _openParticipantProfile(CampaignParticipant participant) {
    if (participant.linkedMember != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MemberDetailScreen(member: participant.linkedMember!),
        ),
      );
    } else if (participant.linkedSubscriber != null) {
      // Show subscriber detail in a bottom sheet (similar to subscribers_screen.dart)
      _showSubscriberDetail(participant.linkedSubscriber!);
    }
  }

  void _showSubscriberDetail(Subscriber subscriber) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: Colors.orange.withOpacity(0.2),
                        child: Text(
                          subscriber.name.isNotEmpty ? subscriber.name[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subscriber.name,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Subscriber',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  _buildSubscriberInfoRow(Icons.email, 'Email', subscriber.email),
                  if (subscriber.phone != null)
                    _buildSubscriberInfoRow(Icons.phone, 'Phone', subscriber.phone!),
                  if (subscriber.zipCode != null)
                    _buildSubscriberInfoRow(Icons.location_on, 'ZIP Code', subscriber.zipCode!),
                  if (subscriber.county != null)
                    _buildSubscriberInfoRow(Icons.location_city, 'County', subscriber.county!),
                  if (subscriber.state != null)
                    _buildSubscriberInfoRow(Icons.map, 'State', subscriber.state!),
                  if (subscriber.source != null)
                    _buildSubscriberInfoRow(Icons.source, 'Source', subscriber.source!),
                  if (subscriber.tags != null && subscriber.tags!.isNotEmpty)
                    _buildSubscriberInfoRow(Icons.label, 'Tags', subscriber.tags!),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSubscriberInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
