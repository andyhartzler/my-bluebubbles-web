import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import 'package:bluebubbles/features/committees/widgets/cors_aware_avatar.dart';
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
  /// If true, hide participants tab (member view)
  final bool isMemberView;

  const CampaignDetailScreen({
    super.key,
    required this.campaign,
    this.isMemberView = false,
  });

  @override
  State<CampaignDetailScreen> createState() => _CampaignDetailScreenState();
}

class _CampaignDetailScreenState extends State<CampaignDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();

  // Brand colors - using Unity Blue consistently
  static const _unityBlue = Color(0xFF273351);
  static const _momentumBlue = Color(0xFF32A6DE);
  static const _grassrootsGreen = Color(0xFF43A047);
  static const _actionRed = Color(0xFFE63946);

  static const List<Color> _chartColors = [
    Color(0xFF2B4B8C), // Royal Blue
    Color(0xFF5A7FA3), // Slate Blue
    Color(0xFF32A6DE), // Momentum Blue
    Color(0xFF273351), // Unity Blue
    Color(0xFF4682B4), // Steel Blue
    Color(0xFF1E3A5F), // Navy Blue
    Color(0xFF10B981), // Emerald
    Color(0xFFF59E0B), // Amber
    Color(0xFF3B82F6), // Blue
    Color(0xFF14B8A6), // Teal
  ];

  static const _methodColors = {
    'mail_app': Color(0xFF2B4B8C),
    'gmail': Color(0xFFEA4335),
    'outlook': Color(0xFF0078D4),
    'copy_paste': Color(0xFF5A7FA3),
    'auto_shortcut': Color(0xFF32A6DE),
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
    // Member view has only 2 tabs (no Participants)
    _tabController = TabController(length: widget.isMemberView ? 2 : 3, vsync: this);
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      body: Stack(
        children: [
          // Gradient background
          Positioned.fill(
            child: Image.asset(
              'assets/images/Blue-Gradient-Background.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.white.withOpacity(0.18)),
          ),
          // Content
          Column(
            children: [
              // Custom AppBar with Unity Blue
              Container(
                decoration: BoxDecoration(
                  color: _unityBlue,
                ),
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header row
                      Padding(
                        padding: EdgeInsets.fromLTRB(isMobile ? 4 : 16, 8, 16, 8),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.white),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.campaign.name,
                                style: theme.textTheme.titleMedium?.copyWith(
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
                        indicatorColor: _momentumBlue,
                        indicatorWeight: 3,
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white60,
                        labelPadding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24),
                        tabs: [
                          Tab(
                            icon: const Icon(Icons.dashboard, size: 20),
                            text: isMobile ? null : 'Overview',
                            iconMargin: EdgeInsets.only(bottom: isMobile ? 0 : 4),
                          ),
                          Tab(
                            icon: const Icon(Icons.map, size: 20),
                            text: isMobile ? null : 'Geography',
                            iconMargin: EdgeInsets.only(bottom: isMobile ? 0 : 4),
                          ),
                          if (!widget.isMemberView)
                            Tab(
                              icon: const Icon(Icons.people, size: 20),
                              text: isMobile ? null : 'Participants',
                              iconMargin: EdgeInsets.only(bottom: isMobile ? 0 : 4),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Tab content - no swiping between tabs
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildOverviewTab(theme, colorScheme),
                    _buildGeographyTab(theme, colorScheme),
                    if (!widget.isMemberView) _buildParticipantsTab(theme, colorScheme),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(ThemeData theme, ColorScheme colorScheme) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final padding = isMobile ? 16.0 : 24.0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Campaign description
          if (widget.campaign.description.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _unityBlue.withOpacity(0.85),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.campaign.description,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(height: isMobile ? 16 : 24),
          ],

          // Key metrics row
          _buildMetricsRow(theme, colorScheme),
          SizedBox(height: isMobile ? 24 : 32),

          // Send method analysis with pie chart
          _buildSendMethodChart(theme, colorScheme),
          SizedBox(height: isMobile ? 24 : 32),

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
        final isVerySmall = constraints.maxWidth < 360;
        // Per user request: sent should equal generated
        final displaySent = widget.campaign.totalGenerated;
        final displayRate = widget.campaign.totalGenerated > 0 ? 100.0 : 0.0;

        final cards = [
          _buildMetricCard(
            icon: Icons.edit_note,
            label: 'Generated',
            value: '${widget.campaign.totalGenerated}',
            color: _momentumBlue,
          ),
          _buildMetricCard(
            icon: Icons.send,
            label: 'Sent',
            value: '$displaySent',
            color: _grassrootsGreen,
          ),
          _buildMetricCard(
            icon: Icons.people,
            label: 'Participants',
            value: '${widget.campaign.uniqueParticipants}',
            color: const Color(0xFF6A1B9A), // justicePurple
          ),
          _buildMetricCard(
            icon: Icons.percent,
            label: 'Send Rate',
            value: displayRate.toStringAsFixed(0),
            color: const Color(0xFFFDB813), // sunriseGold
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

        final spacing = isVerySmall ? 8.0 : 12.0;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards.map((card) => SizedBox(
            width: (constraints.maxWidth - spacing) / 2,
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isVerySmall = screenWidth < 360;

    return Container(
      padding: EdgeInsets.all(isVerySmall ? 10 : (isMobile ? 12 : 16)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _unityBlue,
            _unityBlue.withOpacity(0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: _unityBlue.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: isVerySmall ? 18 : (isMobile ? 20 : 24)),
          SizedBox(height: isVerySmall ? 6 : (isMobile ? 8 : 12)),
          Text(
            value,
            style: TextStyle(
              fontSize: isVerySmall ? 20 : (isMobile ? 22 : 28),
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: isVerySmall ? 10 : 12,
              color: Colors.white.withOpacity(0.9),
            ),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSendMethodChart(ThemeData theme, ColorScheme colorScheme) {
    final breakdown = widget.campaign.sendMethodBreakdown;
    if (breakdown.isEmpty) return const SizedBox.shrink();

    final total = breakdown.values.fold(0, (sum, count) => sum + count);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isVerySmall = screenWidth < 400;

    return Card(
      elevation: 2,
      color: _unityBlue,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pie_chart, color: _momentumBlue, size: isMobile ? 20 : 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Send Method Analysis',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 16 : 24),
            // Stack chart and legend vertically on mobile
            if (isMobile) ...[
              SizedBox(
                height: isVerySmall ? 160 : 200,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: isVerySmall ? 30 : 40,
                    sections: breakdown.entries.toList().asMap().entries.map((entry) {
                      final method = entry.value.key;
                      final count = entry.value.value;
                      final percentage = total > 0 ? (count / total * 100) : 0.0;
                      final color = _methodColors[method] ?? _chartColors[entry.key % _chartColors.length];

                      return PieChartSectionData(
                        value: count.toDouble(),
                        title: '${percentage.toStringAsFixed(0)}%',
                        color: color,
                        radius: isVerySmall ? 50 : 60,
                        titleStyle: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: isVerySmall ? 10 : 11,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Legend as horizontal wrap on mobile
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: breakdown.entries.map((entry) {
                  final method = entry.key;
                  final count = entry.value;
                  final color = _methodColors[method] ?? Colors.grey;
                  final label = _methodLabels[method] ?? method;

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$label ($count)',
                        style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.9)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ] else ...[
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
                                    style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.9)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '$count',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
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
      color: _unityBlue,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timeline, color: _momentumBlue),
                const SizedBox(width: 8),
                const Text(
                  'Participation Over Time',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
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
                      tooltipBgColor: Colors.white,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          '${displayEntries[groupIndex].key}\n${rod.toY.toInt()} participants',
                          TextStyle(color: _unityBlue, fontWeight: FontWeight.w600),
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
                              style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.7)),
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
                            style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.7)),
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
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.white.withOpacity(0.1),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: displayEntries.asMap().entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value.value.toDouble(),
                          gradient: LinearGradient(
                            colors: [_momentumBlue, _momentumBlue.withOpacity(0.6)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
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
        color: _unityBlue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.map_outlined, size: 48, color: Colors.white.withOpacity(0.5)),
              const SizedBox(height: 16),
              Text(
                'No county data available',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.7),
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
      color: _unityBlue,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_city, color: _momentumBlue),
                const SizedBox(width: 8),
                const Text(
                  'County Distribution',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _momentumBlue.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${byCounty.length} counties',
                    style: const TextStyle(
                      color: Colors.white,
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
                                    style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.9)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '$count',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
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
      color: _unityBlue,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pin_drop, color: _actionRed),
                const SizedBox(width: 8),
                const Text(
                  'Top ZIP Codes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _actionRed.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${byZip.length} ZIP codes',
                    style: const TextStyle(
                      color: Colors.white,
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
                      tooltipBgColor: Colors.white,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          'ZIP ${topZips[groupIndex].key}\n${rod.toY.toInt()} participants',
                          TextStyle(color: _unityBlue, fontWeight: FontWeight.w600),
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
                                style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.7)),
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
                            style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.7)),
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
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.white.withOpacity(0.1),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: topZips.asMap().entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value.value.toDouble(),
                          gradient: LinearGradient(
                            colors: [_actionRed, _actionRed.withOpacity(0.6)],
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
      color: _unityBlue,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.list_alt, color: _grassrootsGreen),
                const SizedBox(width: 8),
                const Text(
                  'All ZIP Codes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
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
                    color: _grassrootsGreen.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _grassrootsGreen.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        entry.key,
                        style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _grassrootsGreen,
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
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _unityBlue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.people_outline, size: 48, color: _unityBlue.withOpacity(0.5)),
            ),
            const SizedBox(height: 16),
            Text(
              'No participants yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _unityBlue,
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
          color: _unityBlue,
          child: Row(
            children: [
              _buildParticipantStat(
                icon: Icons.people,
                label: 'Total',
                value: '${participants.length}',
                color: _momentumBlue,
              ),
              const SizedBox(width: 24),
              _buildParticipantStat(
                icon: Icons.card_membership,
                label: 'Members',
                value: '$membersCount',
                color: Colors.lightBlue,
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
                color: _grassrootsGreen,
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
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.7),
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
      color: _unityBlue,
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
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        if (participant.isMember)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _momentumBlue.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Member',
                              style: TextStyle(
                                color: _momentumBlue,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        else if (participant.isSubscriber)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.3),
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
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.7),
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
                  color: Colors.white.withOpacity(0.5),
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

    return CorsAwareAvatar(
      imageUrl: photoUrl,
      radius: 28,
      backgroundColor: _momentumBlue.withOpacity(0.3),
      fallbackText: participant.name,
      fallbackIconColor: _momentumBlue,
      fallbackTextColor: Colors.white,
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
