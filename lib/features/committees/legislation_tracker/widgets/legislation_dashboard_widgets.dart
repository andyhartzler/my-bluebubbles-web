import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../models/legislation_widget_config.dart';
import '../services/legislation_service.dart';

// Brand colors
const _unityBlue = Color(0xFF273351);
const _momentumBlue = Color(0xFF32A6DE);
const _sunriseGold = Color(0xFFFDB813);
const _actionRed = Color(0xFFE63946);
const _justicePurple = Color(0xFF6A1B9A);
const _grassrootsGreen = Color(0xFF43A047);

// Party colors
const _democratBlue = Color(0xFF3B82F6);
const _republicanRed = Color(0xFFEF4444);

/// Stat Card Widget
class LegislationStatCardWidget extends StatelessWidget {
  final LegislationWidgetConfig config;
  final dynamic value;
  final String? trend;
  final VoidCallback? onTap;

  const LegislationStatCardWidget({
    super.key,
    required this.config,
    required this.value,
    this.trend,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = config.gradientColors.isNotEmpty
        ? config.gradientColors
        : LegislationWidgetGradients.all[0];

    final displayValue = _formatValue(value);
    final isMini = config.size == LegislationWidgetSize.mini;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isMini ? 12 : 16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: EdgeInsets.all(isMini ? 12 : 20),
          child: isMini ? _buildMiniLayout(displayValue) : _buildStandardLayout(displayValue),
        ),
      ),
    );
  }

  Widget _buildMiniLayout(String displayValue) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            config.icon ?? Icons.analytics,
            color: Colors.white,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            config.title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          displayValue,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildStandardLayout(String displayValue) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                config.icon ?? Icons.analytics,
                color: Colors.white,
                size: 24,
              ),
            ),
            if (trend != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  trend!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const Spacer(),
        Text(
          displayValue,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          config.title,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (config.subtitle != null)
          Text(
            config.subtitle!,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
      ],
    );
  }

  String _formatValue(dynamic val) {
    if (val is num) {
      if (val is double) {
        if (val == val.truncateToDouble()) {
          return _formatWithCommas(val.toInt());
        }
        return val.toStringAsFixed(1);
      }
      return _formatWithCommas(val.toInt());
    }
    return val?.toString() ?? '-';
  }

  String _formatWithCommas(int value) {
    final str = value.toString();
    final result = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        result.write(',');
      }
      result.write(str[i]);
    }
    return result.toString();
  }
}

/// Pie Chart Widget
class LegislationPieChartWidget extends StatelessWidget {
  final LegislationWidgetConfig config;
  final List<PieChartItem> data;
  final bool isDonut;

  const LegislationPieChartWidget({
    super.key,
    required this.config,
    required this.data,
    this.isDonut = false,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return _buildEmptyState();
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _unityBlue,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 12),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildChart(),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: _buildLegend(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(config.icon ?? Icons.pie_chart, color: Colors.white, size: 20),
        const SizedBox(width: 8),
        Text(
          config.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildChart() {
    final total = data.fold<int>(0, (sum, item) => sum + item.count);

    return PieChart(
      PieChartData(
        sections: data.map((item) {
          final percentage = total > 0 ? (item.count / total * 100) : 0.0;
          return PieChartSectionData(
            value: item.count.toDouble(),
            title: percentage >= 5 ? '${percentage.toStringAsFixed(0)}%' : '',
            color: item.color,
            radius: isDonut ? 40 : 60,
            titleStyle: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          );
        }).toList(),
        centerSpaceRadius: isDonut ? 40 : 0,
        sectionsSpace: 2,
      ),
    );
  }

  Widget _buildLegend() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: data.map((item) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: item.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${item.count}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _unityBlue,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.pie_chart, color: Colors.white.withOpacity(0.5), size: 48),
              const SizedBox(height: 8),
              Text(
                'No data available',
                style: TextStyle(color: Colors.white.withOpacity(0.7)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Progress Ring Widget
class LegislationProgressRingWidget extends StatelessWidget {
  final LegislationWidgetConfig config;
  final int current;
  final int total;

  const LegislationProgressRingWidget({
    super.key,
    required this.config,
    required this.current,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final colors = config.gradientColors.isNotEmpty
        ? config.gradientColors
        : [_momentumBlue, _justicePurple];

    final percentage = total > 0 ? (current / total * 100) : 0.0;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    config.icon ?? Icons.donut_large,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                Text(
                  '${percentage.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Spacer(),
            SizedBox(
              width: 100,
              height: 100,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: percentage / 100,
                    strokeWidth: 10,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                  Center(
                    child: Text(
                      '$current',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Text(
              config.title,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (config.subtitle != null)
              Text(
                config.subtitle!,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Party Comparison Widget - Side-by-side Democrat vs Republican
/// Fully responsive at all widget sizes
class PartyComparisonWidget extends StatelessWidget {
  final LegislationWidgetConfig config;
  final LegislationStats stats;

  const PartyComparisonWidget({
    super.key,
    required this.config,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    final colors = config.gradientColors.isNotEmpty
        ? config.gradientColors
        : [_unityBlue, _momentumBlue];

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Calculate responsive sizes based on available space
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            final isCompact = height < 200 || width < 300;
            final isVeryCompact = height < 150 || width < 250;
            final padding = isVeryCompact ? 12.0 : (isCompact ? 14.0 : 20.0);

            // Font sizes based on available space
            final titleSize = isVeryCompact ? 12.0 : (isCompact ? 14.0 : 18.0);
            final partyNameSize = isVeryCompact ? 10.0 : (isCompact ? 12.0 : 14.0);
            final countSize = isVeryCompact ? 20.0 : (isCompact ? 24.0 : 32.0);
            final labelSize = isVeryCompact ? 9.0 : (isCompact ? 10.0 : 12.0);
            final barHeight = isVeryCompact ? 10.0 : (isCompact ? 12.0 : 16.0);

            return Padding(
              padding: EdgeInsets.all(padding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Icon(
                        config.icon ?? Icons.compare_arrows,
                        color: Colors.white,
                        size: isVeryCompact ? 16 : (isCompact ? 18 : 20),
                      ),
                      SizedBox(width: isVeryCompact ? 4 : 8),
                      Expanded(
                        child: Text(
                          config.title,
                          style: TextStyle(
                            fontSize: titleSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isVeryCompact ? 8 : (isCompact ? 12 : 16)),

                  // Main content - side by side stats
                  Expanded(
                    child: Row(
                      children: [
                        // Democrat side
                        Expanded(
                          child: _buildPartyStats(
                            party: 'Democrats',
                            color: _democratBlue,
                            primaryCount: stats.democratPrimarySponsorCount,
                            avgPerLegislator: stats.avgBillsPerDemocratLegislator,
                            partyNameSize: partyNameSize,
                            countSize: countSize,
                            labelSize: labelSize,
                            alignment: CrossAxisAlignment.center,
                            isCompact: isCompact,
                            isVeryCompact: isVeryCompact,
                          ),
                        ),

                        // Divider
                        Container(
                          width: 1,
                          margin: EdgeInsets.symmetric(
                            horizontal: isVeryCompact ? 8 : 12,
                            vertical: isVeryCompact ? 4 : 8,
                          ),
                          color: Colors.white24,
                        ),

                        // Republican side
                        Expanded(
                          child: _buildPartyStats(
                            party: 'Republicans',
                            color: _republicanRed,
                            primaryCount: stats.republicanPrimarySponsorCount,
                            avgPerLegislator: stats.avgBillsPerRepublicanLegislator,
                            partyNameSize: partyNameSize,
                            countSize: countSize,
                            labelSize: labelSize,
                            alignment: CrossAxisAlignment.center,
                            isCompact: isCompact,
                            isVeryCompact: isVeryCompact,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Comparison bars (only if enough space)
                  if (!isVeryCompact) ...[
                    SizedBox(height: isCompact ? 8 : 12),
                    _buildComparisonBar(
                      label: 'Primary',
                      demValue: stats.democratPrimarySponsorCount,
                      repValue: stats.republicanPrimarySponsorCount,
                      labelSize: labelSize,
                      barHeight: barHeight,
                    ),
                    SizedBox(height: isCompact ? 6 : 10),
                    _buildComparisonBar(
                      label: 'Co-Sponsors',
                      demValue: stats.democratCosponsorCount,
                      repValue: stats.republicanCosponsorCount,
                      labelSize: labelSize,
                      barHeight: barHeight,
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPartyStats({
    required String party,
    required Color color,
    required int primaryCount,
    required double avgPerLegislator,
    required double partyNameSize,
    required double countSize,
    required double labelSize,
    required CrossAxisAlignment alignment,
    required bool isCompact,
    required bool isVeryCompact,
  }) {
    return Column(
      crossAxisAlignment: alignment,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Party name badge
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: isVeryCompact ? 6 : 10,
            vertical: isVeryCompact ? 2 : 4,
          ),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.5)),
          ),
          child: Text(
            party,
            style: TextStyle(
              color: color,
              fontSize: partyNameSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(height: isVeryCompact ? 6 : 10),
        // Primary count
        Text(
          '$primaryCount',
          style: TextStyle(
            color: Colors.white,
            fontSize: countSize,
            fontWeight: FontWeight.bold,
            height: 1.1,
          ),
        ),
        if (!isVeryCompact) ...[
          Text(
            'Primary Sponsors',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: labelSize,
            ),
          ),
          SizedBox(height: isCompact ? 4 : 8),
          Text(
            '${avgPerLegislator.toStringAsFixed(1)}/legislator',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: labelSize - 1,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildComparisonBar({
    required String label,
    required int demValue,
    required int repValue,
    required double labelSize,
    required double barHeight,
  }) {
    final total = demValue + repValue;
    final demRatio = total > 0 ? demValue / total : 0.5;
    final repRatio = total > 0 ? repValue / total : 0.5;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$demValue',
              style: TextStyle(
                color: _democratBlue,
                fontWeight: FontWeight.bold,
                fontSize: labelSize,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: labelSize - 1,
              ),
            ),
            Text(
              '$repValue',
              style: TextStyle(
                color: _republicanRed,
                fontWeight: FontWeight.bold,
                fontSize: labelSize,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              flex: (demRatio * 100).round().clamp(1, 99),
              child: Container(
                height: barHeight,
                decoration: BoxDecoration(
                  color: _democratBlue,
                  borderRadius: BorderRadius.horizontal(left: Radius.circular(barHeight / 2)),
                ),
              ),
            ),
            const SizedBox(width: 2),
            Expanded(
              flex: (repRatio * 100).round().clamp(1, 99),
              child: Container(
                height: barHeight,
                decoration: BoxDecoration(
                  color: _republicanRed,
                  borderRadius: BorderRadius.horizontal(right: Radius.circular(barHeight / 2)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Legislator Leaderboard Widget with Photos
/// Styled with gradient like other dashboard tiles, shows all entries (scrollable)
class LegislatorLeaderboardWidget extends StatelessWidget {
  final LegislationWidgetConfig config;
  final List<SponsorLeaderboardEntry> entries;
  final Color headerColor;

  const LegislatorLeaderboardWidget({
    super.key,
    required this.config,
    required this.entries,
    required this.headerColor,
  });

  @override
  Widget build(BuildContext context) {
    // Use config gradients if available, otherwise create party-colored gradient
    final colors = config.gradientColors.isNotEmpty
        ? config.gradientColors
        : [headerColor, headerColor.withOpacity(0.7)];

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxHeight < 200;
            final isVeryCompact = constraints.maxHeight < 150;
            final padding = isVeryCompact ? 10.0 : (isCompact ? 12.0 : 16.0);

            return Padding(
              padding: EdgeInsets.all(padding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(isVeryCompact ? 6 : 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          config.icon ?? Icons.emoji_events,
                          color: Colors.white,
                          size: isVeryCompact ? 16 : 20,
                        ),
                      ),
                      SizedBox(width: isVeryCompact ? 8 : 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              config.title,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: isVeryCompact ? 12 : 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (!isVeryCompact)
                              Text(
                                '${entries.length} legislators',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isVeryCompact ? 8 : 12),

                  // Entries list - scrollable, shows all entries
                  Expanded(
                    child: entries.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.person_off_outlined,
                                  color: Colors.white.withOpacity(0.4),
                                  size: 32,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No data available',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            // Show ALL entries, not just top 5
                            itemCount: entries.length,
                            padding: EdgeInsets.zero,
                            itemBuilder: (context, index) {
                              final entry = entries[index];
                              return _buildEntryTile(entry, index, isCompact, isVeryCompact);
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEntryTile(SponsorLeaderboardEntry entry, int index, bool isCompact, bool isVeryCompact) {
    final tileHeight = isVeryCompact ? 36.0 : (isCompact ? 44.0 : 52.0);
    final avatarRadius = isVeryCompact ? 12.0 : (isCompact ? 14.0 : 16.0);
    final rankSize = isVeryCompact ? 10.0 : 12.0;
    final nameSize = isVeryCompact ? 11.0 : 13.0;
    final subtitleSize = isVeryCompact ? 9.0 : 11.0;

    return Container(
      height: tileHeight,
      margin: EdgeInsets.only(bottom: isVeryCompact ? 4 : 6),
      padding: EdgeInsets.symmetric(
        horizontal: isVeryCompact ? 6 : 8,
        vertical: isVeryCompact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          // Rank badge
          Container(
            width: isVeryCompact ? 18 : 22,
            height: isVeryCompact ? 18 : 22,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(index < 3 ? 0.3 : 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: rankSize,
                ),
              ),
            ),
          ),
          SizedBox(width: isVeryCompact ? 6 : 8),
          // Photo
          CircleAvatar(
            radius: avatarRadius,
            backgroundColor: Colors.white.withOpacity(0.2),
            backgroundImage: entry.photoUrl != null && entry.photoUrl!.isNotEmpty
                ? NetworkImage(entry.photoUrl!)
                : null,
            child: entry.photoUrl == null || entry.photoUrl!.isEmpty
                ? Text(
                    entry.name.isNotEmpty ? entry.name.substring(0, 1) : '?',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: avatarRadius * 0.8,
                    ),
                  )
                : null,
          ),
          SizedBox(width: isVeryCompact ? 6 : 10),
          // Name and info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  entry.name,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: nameSize,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                if (!isVeryCompact)
                  Text(
                    '${entry.chamber} ${entry.district}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: subtitleSize,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          // Bill count badge
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isVeryCompact ? 6 : 8,
              vertical: isVeryCompact ? 2 : 4,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${entry.billsCount}',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: rankSize,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bill Leaderboard Widget
class BillLeaderboardWidget extends StatelessWidget {
  final LegislationWidgetConfig config;
  final List<BillLeaderboardEntry> entries;

  const BillLeaderboardWidget({
    super.key,
    required this.config,
    required this.entries,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(color: _momentumBlue),
            child: Row(
              children: [
                Icon(config.icon ?? Icons.star, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    config.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Entries
          Expanded(
            child: Container(
              color: _unityBlue,
              child: entries.isEmpty
                  ? Center(
                      child: Text(
                        'No data available',
                        style: TextStyle(color: Colors.white.withOpacity(0.7)),
                      ),
                    )
                  : ListView.builder(
                      itemCount: entries.take(5).length,
                      padding: EdgeInsets.zero,
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        return _buildEntryTile(entry, index);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryTile(BillLeaderboardEntry entry, int index) {
    return ListTile(
      dense: true,
      leading: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: _momentumBlue.withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            '${index + 1}',
            style: const TextStyle(
              color: _momentumBlue,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
      title: Text(
        entry.billIdentifier,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(
        entry.title,
        style: TextStyle(
          color: Colors.white.withOpacity(0.7),
          fontSize: 11,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _momentumBlue.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '${entry.count}',
          style: const TextStyle(
            color: _momentumBlue,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

/// Bar Chart Widget
class LegislationBarChartWidget extends StatelessWidget {
  final LegislationWidgetConfig config;
  final List<PieChartItem> data;

  const LegislationBarChartWidget({
    super.key,
    required this.config,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return _buildEmptyState();
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _unityBlue,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(config.icon ?? Icons.bar_chart, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  config.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _buildHorizontalBars(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontalBars() {
    final maxValue = data.fold<int>(0, (max, item) => item.count > max ? item.count : max);

    return ListView.builder(
      itemCount: data.length,
      itemBuilder: (context, index) {
        final item = data[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(
                width: 80,
                child: Text(
                  item.label,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: maxValue > 0 ? item.count / maxValue : 0,
                      child: Container(
                        height: 20,
                        decoration: BoxDecoration(
                          color: item.color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 40,
                child: Text(
                  '${item.count}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _unityBlue,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bar_chart, color: Colors.white.withOpacity(0.5), size: 48),
              const SizedBox(height: 8),
              Text(
                'No data available',
                style: TextStyle(color: Colors.white.withOpacity(0.7)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Data class for pie/bar chart items
class PieChartItem {
  final String label;
  final int count;
  final Color color;

  const PieChartItem({
    required this.label,
    required this.count,
    required this.color,
  });
}
