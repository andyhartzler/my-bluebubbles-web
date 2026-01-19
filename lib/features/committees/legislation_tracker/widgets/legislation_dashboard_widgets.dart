import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../models/legislation_widget_config.dart';
import '../models/tracked_bill.dart';
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
    final isSmall = config.size == LegislationWidgetSize.small;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isSmall ? 12 : 16),
      ),
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
          padding: EdgeInsets.all(isSmall ? 12 : (isMini ? 16 : 20)),
          child: isSmall
              ? _buildSmallLayout(displayValue)
              : (isMini
                    ? _buildMiniLayout(displayValue)
                    : _buildStandardLayout(displayValue)),
        ),
      ),
    );
  }

  /// Compact square layout for mini size - number on top, name/icon below
  /// Fully responsive - scales to any screen size
  Widget _buildMiniLayout(String displayValue) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate responsive sizes based on available space
        final availableHeight = constraints.maxHeight;
        final availableWidth = constraints.maxWidth;

        // Number takes up ~60% of height, label takes ~40%
        final numberHeight = availableHeight * 0.55;
        final labelHeight = availableHeight * 0.35;
        final spacing = availableHeight * 0.1;

        // Calculate icon size proportional to available width
        final iconSize = (availableWidth * 0.15).clamp(12.0, 20.0);

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Large number at the top - takes majority of space
            SizedBox(
              height: numberHeight,
              width: availableWidth,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: Text(
                  displayValue,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 72, // Large base size, FittedBox will scale down
                    fontWeight: FontWeight.bold,
                    height: 1.0,
                  ),
                ),
              ),
            ),
            SizedBox(height: spacing),
            // Stat name and icon at the bottom - smaller, compact
            SizedBox(
              height: labelHeight,
              width: availableWidth,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (config.icon != null) ...[
                      Icon(
                        config.icon,
                        color: Colors.white.withOpacity(0.9),
                        size: iconSize,
                      ),
                      SizedBox(width: iconSize * 0.3),
                    ],
                    Text(
                      config.title,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.95),
                        fontSize: 14, // Base size, FittedBox scales
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Compact horizontal layout for small size (half-height row)
  Widget _buildSmallLayout(String displayValue) {
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
  final VoidCallback? onTap;

  const LegislationPieChartWidget({
    super.key,
    required this.config,
    required this.data,
    this.isDonut = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return _buildEmptyState();
    }

    // Use config gradient colors or fall back to brand colors
    final colors = config.gradientColors.isNotEmpty
        ? config.gradientColors
        : [_unityBlue, _momentumBlue];

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxHeight < 180 || constraints.maxWidth < 280;
              final isVeryCompact = constraints.maxHeight < 140 || constraints.maxWidth < 220;
              final spacing = isVeryCompact ? 8.0 : (isCompact ? 12.0 : 16.0);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(isCompact: isCompact),
                  SizedBox(height: isVeryCompact ? 8 : 12),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: _buildChart(
                            isCompact: isCompact,
                            isVeryCompact: isVeryCompact,
                            constraints: constraints,
                          ),
                        ),
                        SizedBox(width: spacing),
                        Expanded(flex: 2, child: _buildLegend(isCompact: isCompact)),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader({bool isCompact = false}) {
    return Row(
      children: [
        Icon(
          config.icon ?? Icons.pie_chart,
          color: Colors.white,
          size: isCompact ? 16 : 20,
        ),
        SizedBox(width: isCompact ? 6 : 8),
        Expanded(
          child: Text(
            config.title,
            style: TextStyle(
              color: Colors.white,
              fontSize: isCompact ? 13 : 16,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildChart({
    bool isCompact = false,
    bool isVeryCompact = false,
    BoxConstraints? constraints,
  }) {
    final total = data.fold<int>(0, (sum, item) => sum + item.count);

    // Calculate responsive radius based on available space
    final availableHeight = constraints?.maxHeight ?? 200;
    final availableWidth = constraints?.maxWidth ?? 200;
    final minDimension = (availableHeight < availableWidth ? availableHeight : availableWidth) * 0.4;

    // Scale radius based on available space
    final baseRadius = isDonut
        ? minDimension.clamp(25.0, 50.0)
        : minDimension.clamp(35.0, 70.0);
    final centerRadius = isDonut ? (baseRadius * 0.7).clamp(20.0, 45.0) : 0.0;
    final titleSize = isVeryCompact ? 9.0 : (isCompact ? 10.0 : 12.0);

    return PieChart(
      PieChartData(
        sections: data.map((item) {
          final percentage = total > 0 ? (item.count / total * 100) : 0.0;
          return PieChartSectionData(
            value: item.count.toDouble(),
            title: percentage >= 5 ? '${percentage.toStringAsFixed(0)}%' : '',
            color: item.color,
            radius: baseRadius,
            titleStyle: TextStyle(
              color: Colors.white,
              fontSize: titleSize,
              fontWeight: FontWeight.bold,
            ),
          );
        }).toList(),
        centerSpaceRadius: centerRadius,
        sectionsSpace: 2,
      ),
    );
  }

  Widget _buildLegend({bool isCompact = false}) {
    final dotSize = isCompact ? 10.0 : 12.0;
    final fontSize = isCompact ? 10.0 : 12.0;
    final spacing = isCompact ? 3.0 : 4.0;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: data.map((item) {
          return Tooltip(
            message: '${item.label}: ${item.count}',
            waitDuration: const Duration(milliseconds: 300),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: spacing),
              child: Row(
                children: [
                  Container(
                    width: dotSize,
                    height: dotSize,
                    decoration: BoxDecoration(
                      color: item.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: isCompact ? 6 : 8),
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(color: Colors.white, fontSize: fontSize),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${item.count}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
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
              Icon(
                Icons.pie_chart,
                color: Colors.white.withOpacity(0.5),
                size: 48,
              ),
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
  final VoidCallback? onTap;

  const LegislationProgressRingWidget({
    super.key,
    required this.config,
    required this.current,
    required this.total,
    this.onTap,
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxHeight < 180 || constraints.maxWidth < 180;
              final isVeryCompact = constraints.maxHeight < 140 || constraints.maxWidth < 140;

              // Responsive sizing
              final padding = isVeryCompact ? 12.0 : (isCompact ? 16.0 : 20.0);
              final iconSize = isVeryCompact ? 18.0 : (isCompact ? 20.0 : 24.0);
              final iconPadding = isVeryCompact ? 6.0 : (isCompact ? 8.0 : 10.0);
              final percentageSize = isVeryCompact ? 16.0 : (isCompact ? 20.0 : 24.0);

              // Calculate ring size based on available space
              final availableForRing = constraints.maxHeight - padding * 2 - 80;
              final ringSize = availableForRing.clamp(60.0, 120.0);
              final strokeWidth = (ringSize * 0.1).clamp(6.0, 12.0);
              final centerTextSize = (ringSize * 0.28).clamp(16.0, 32.0);

              final titleSize = isVeryCompact ? 11.0 : (isCompact ? 12.0 : 14.0);
              final subtitleSize = isVeryCompact ? 9.0 : (isCompact ? 10.0 : 12.0);

              return Padding(
                padding: EdgeInsets.all(padding),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: EdgeInsets.all(iconPadding),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            config.icon ?? Icons.donut_large,
                            color: Colors.white,
                            size: iconSize,
                          ),
                        ),
                        Text(
                          '${percentage.toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: percentageSize,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    SizedBox(
                      width: ringSize,
                      height: ringSize,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CircularProgressIndicator(
                            value: percentage / 100,
                            strokeWidth: strokeWidth,
                            backgroundColor: Colors.white.withOpacity(0.2),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                          Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '$current',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: centerTextSize,
                                  fontWeight: FontWeight.bold,
                                ),
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
                        fontSize: titleSize,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (config.subtitle != null)
                      Text(
                        config.subtitle!,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: subtitleSize,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              );
            },
          ),
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
  final VoidCallback? onTap;

  const PartyComparisonWidget({
    super.key,
    required this.config,
    required this.stats,
    this.onTap,
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Calculate responsive sizes based on available space
              final width = constraints.maxWidth;
              final height = constraints.maxHeight;
              final isCompact = height < 200 || width < 300;
              final isVeryCompact = height < 150 || width < 250;
              final padding = isVeryCompact ? 12.0 : (isCompact ? 14.0 : 20.0);

              // Font sizes based on available space
              final titleSize = isVeryCompact
                  ? 12.0
                  : (isCompact ? 14.0 : 18.0);
              final partyNameSize = isVeryCompact
                  ? 10.0
                  : (isCompact ? 12.0 : 14.0);
              final countSize = isVeryCompact
                  ? 20.0
                  : (isCompact ? 24.0 : 32.0);
              final labelSize = isVeryCompact ? 9.0 : (isCompact ? 10.0 : 12.0);
              final barHeight = isVeryCompact
                  ? 10.0
                  : (isCompact ? 12.0 : 16.0);

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
                              avgPerLegislator:
                                  stats.avgBillsPerDemocratLegislator,
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
                              avgPerLegislator:
                                  stats.avgBillsPerRepublicanLegislator,
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
                  borderRadius: BorderRadius.horizontal(
                    left: Radius.circular(barHeight / 2),
                  ),
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
                  borderRadius: BorderRadius.horizontal(
                    right: Radius.circular(barHeight / 2),
                  ),
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
  final Function(SponsorLeaderboardEntry)? onEntryTap;

  const LegislatorLeaderboardWidget({
    super.key,
    required this.config,
    required this.entries,
    required this.headerColor,
    this.onEntryTap,
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
                              return _buildEntryTile(
                                entry,
                                index,
                                isCompact,
                                isVeryCompact,
                              );
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

  Widget _buildEntryTile(
    SponsorLeaderboardEntry entry,
    int index,
    bool isCompact,
    bool isVeryCompact,
  ) {
    final tileHeight = isVeryCompact ? 36.0 : (isCompact ? 44.0 : 52.0);
    final avatarRadius = isVeryCompact ? 12.0 : (isCompact ? 14.0 : 16.0);
    final rankSize = isVeryCompact ? 10.0 : 12.0;
    final nameSize = isVeryCompact ? 11.0 : 13.0;
    final subtitleSize = isVeryCompact ? 9.0 : 11.0;

    return InkWell(
      onTap: onEntryTap != null ? () => onEntryTap!(entry) : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
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
              backgroundImage:
                  entry.photoUrl != null && entry.photoUrl!.isNotEmpty
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
                      _formatDistrictDisplay(entry.chamber, entry.district),
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
      ),
    );
  }

  /// Format chamber and district for display
  /// Converts "upper" -> "Senate District" and "lower" -> "House District"
  String _formatDistrictDisplay(String chamber, String district) {
    final chamberName = switch (chamber.toLowerCase()) {
      'upper' => 'Senate',
      'lower' => 'House',
      'senate' => 'Senate',
      'house' => 'House',
      _ => chamber,
    };
    return '$chamberName District $district';
  }
}

/// Bill Leaderboard Widget
class BillLeaderboardWidget extends StatelessWidget {
  final LegislationWidgetConfig config;
  final List<BillLeaderboardEntry> entries;
  final Function(BillLeaderboardEntry)? onEntryTap;

  const BillLeaderboardWidget({
    super.key,
    required this.config,
    required this.entries,
    this.onEntryTap,
  });

  @override
  Widget build(BuildContext context) {
    // Use config gradient colors or fall back to brand colors
    final colors = config.gradientColors.isNotEmpty
        ? config.gradientColors
        : [_unityBlue, _momentumBlue];

    // Accent color for badges (use second gradient color or fallback)
    final accentColor = colors.length > 1 ? colors[1] : _momentumBlue;

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
                          config.icon ?? Icons.star,
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
                                '${entries.length} bills',
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

                  // Entries list
                  Expanded(
                    child: entries.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.description_outlined,
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
                            itemCount: entries.length,
                            padding: EdgeInsets.zero,
                            itemBuilder: (context, index) {
                              final entry = entries[index];
                              return _buildEntryTile(
                                entry,
                                index,
                                accentColor,
                                isCompact,
                                isVeryCompact,
                              );
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

  Widget _buildEntryTile(
    BillLeaderboardEntry entry,
    int index,
    Color accentColor,
    bool isCompact,
    bool isVeryCompact,
  ) {
    final tileHeight = isVeryCompact ? 40.0 : (isCompact ? 48.0 : 56.0);
    final rankSize = isVeryCompact ? 10.0 : 12.0;
    final titleSize = isVeryCompact ? 11.0 : 13.0;
    final subtitleSize = isVeryCompact ? 9.0 : 11.0;

    return InkWell(
      onTap: onEntryTap != null ? () => onEntryTap!(entry) : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
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
            SizedBox(width: isVeryCompact ? 6 : 10),
            // Bill info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    entry.billIdentifier,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: titleSize,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  if (!isVeryCompact)
                    Text(
                      entry.title,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: subtitleSize,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            // Count badge
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
                '${entry.count}',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: rankSize,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bar Chart Widget
class LegislationBarChartWidget extends StatelessWidget {
  final LegislationWidgetConfig config;
  final List<PieChartItem> data;
  final Function(PieChartItem)? onItemTap;
  final VoidCallback? onTap;

  const LegislationBarChartWidget({
    super.key,
    required this.config,
    required this.data,
    this.onItemTap,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return _buildEmptyState();
    }

    // Use config gradient colors or fall back to brand colors
    final colors = config.gradientColors.isNotEmpty
        ? config.gradientColors
        : [_unityBlue, _momentumBlue];

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                            config.icon ?? Icons.bar_chart,
                            color: Colors.white,
                            size: isVeryCompact ? 16 : 20,
                          ),
                        ),
                        SizedBox(width: isVeryCompact ? 8 : 12),
                        Expanded(
                          child: Text(
                            config.title,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: isVeryCompact
                                  ? 12
                                  : (isCompact ? 14 : 16),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isVeryCompact ? 8 : 12),
                    Expanded(
                      child: _buildHorizontalBars(isCompact, isVeryCompact),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalBars(bool isCompact, bool isVeryCompact) {
    final maxValue = data.fold<int>(
      0,
      (max, item) => item.count > max ? item.count : max,
    );
    final barHeight = isVeryCompact ? 14.0 : (isCompact ? 16.0 : 20.0);
    final labelWidth = isVeryCompact ? 60.0 : (isCompact ? 70.0 : 80.0);
    final labelSize = isVeryCompact ? 10.0 : 12.0;
    final valueWidth = isVeryCompact ? 30.0 : 40.0;

    return ListView.builder(
      itemCount: data.length,
      padding: EdgeInsets.zero,
      itemBuilder: (context, index) {
        final item = data[index];
        return Tooltip(
          message: '${item.label}: ${item.count}',
          waitDuration: const Duration(milliseconds: 300),
          child: InkWell(
            onTap: onItemTap != null ? () => onItemTap!(item) : null,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: isVeryCompact ? 2 : 4),
              child: Row(
                children: [
                  SizedBox(
                    width: labelWidth,
                    child: Text(
                      item.label,
                      style: TextStyle(color: Colors.white, fontSize: labelSize),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: isVeryCompact ? 4 : 8),
                  Expanded(
                    child: Stack(
                      children: [
                        Container(
                          height: barHeight,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(barHeight / 2),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: maxValue > 0 ? item.count / maxValue : 0,
                          child: Container(
                            height: barHeight,
                            decoration: BoxDecoration(
                              color: item.color,
                              borderRadius: BorderRadius.circular(barHeight / 2),
                              boxShadow: [
                                BoxShadow(
                                  color: item.color.withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: isVeryCompact ? 4 : 8),
                  SizedBox(
                    width: valueWidth,
                    child: Text(
                      '${item.count}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: labelSize,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
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
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.bar_chart,
                color: Colors.white.withOpacity(0.5),
                size: 48,
              ),
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

/// Generic Distribution Leaderboard Widget
/// Displays distribution data (like top subjects, categories) in a ranked list format
class DistributionLeaderboardWidget extends StatelessWidget {
  final LegislationWidgetConfig config;
  final List<PieChartItem> data;
  final VoidCallback? onTap;

  const DistributionLeaderboardWidget({
    super.key,
    required this.config,
    required this.data,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return _buildEmptyState();
    }

    final colors = config.gradientColors.isNotEmpty
        ? config.gradientColors
        : [_unityBlue, _momentumBlue];

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                            config.icon ?? Icons.leaderboard,
                            color: Colors.white,
                            size: isVeryCompact ? 16 : 20,
                          ),
                        ),
                        SizedBox(width: isVeryCompact ? 8 : 12),
                        Expanded(
                          child: Text(
                            config.title,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: isVeryCompact
                                  ? 12
                                  : (isCompact ? 14 : 16),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isVeryCompact ? 8 : 12),
                    Expanded(
                      child: _buildLeaderboardList(isCompact, isVeryCompact),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLeaderboardList(bool isCompact, bool isVeryCompact) {
    final maxValue = data.fold<int>(
      0,
      (max, item) => item.count > max ? item.count : max,
    );
    final itemHeight = isVeryCompact ? 28.0 : (isCompact ? 32.0 : 36.0);
    final fontSize = isVeryCompact ? 11.0 : (isCompact ? 12.0 : 13.0);
    final rankSize = isVeryCompact ? 18.0 : (isCompact ? 22.0 : 26.0);

    return ListView.builder(
      itemCount: data.length,
      padding: EdgeInsets.zero,
      itemBuilder: (context, index) {
        final item = data[index];
        final percentage = maxValue > 0 ? item.count / maxValue : 0.0;

        return Tooltip(
          message: '${item.label}: ${item.count}',
          waitDuration: const Duration(milliseconds: 300),
          child: Container(
            height: itemHeight,
            margin: EdgeInsets.symmetric(vertical: isVeryCompact ? 1 : 2),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                // Rank badge
                Container(
                  width: rankSize,
                  height: rankSize,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: _getRankColor(index),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _getRankColor(index).withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: fontSize - 2,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                // Label - expands to fill space
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: fontSize,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Progress bar (mini)
                SizedBox(
                  width: 50,
                  child: Stack(
                    children: [
                      Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: percentage,
                        child: Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: item.color,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Count
                SizedBox(
                  width: 40,
                  child: Text(
                    '${item.count}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getRankColor(int index) {
    switch (index) {
      case 0:
        return _sunriseGold;
      case 1:
        return Colors.grey[400]!;
      case 2:
        return Colors.brown[400]!;
      default:
        return _momentumBlue.withOpacity(0.7);
    }
  }

  Widget _buildEmptyState() {
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
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.leaderboard,
                color: Colors.white.withOpacity(0.5),
                size: 48,
              ),
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

/// AI Recommendation Bill Leaderboard Widget
/// Shows bills with a specific AI recommendation (position or priority)
/// Displays bill identifier and AI short summary, allows navigation to bill detail
class AiRecommendationBillLeaderboardWidget extends StatelessWidget {
  final LegislationWidgetConfig config;
  final List<TrackedBill> bills;
  final Function(TrackedBill)? onBillTap;
  final Color? accentColor;

  const AiRecommendationBillLeaderboardWidget({
    super.key,
    required this.config,
    required this.bills,
    this.onBillTap,
    this.accentColor,
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
                          config.icon ?? Icons.psychology,
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
                                '${bills.length} bills',
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

                  // Bills list
                  Expanded(
                    child: bills.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.psychology_outlined,
                                  color: Colors.white.withOpacity(0.4),
                                  size: 32,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No AI recommendations',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: bills.length,
                            padding: EdgeInsets.zero,
                            itemBuilder: (context, index) {
                              final bill = bills[index];
                              return _buildBillTile(
                                bill,
                                index,
                                isCompact,
                                isVeryCompact,
                              );
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

  Widget _buildBillTile(
    TrackedBill bill,
    int index,
    bool isCompact,
    bool isVeryCompact,
  ) {
    // Use intrinsic sizing - no fixed height to avoid wasted space
    final hasSummary = bill.aiSummaryShort != null && bill.aiSummaryShort!.isNotEmpty;
    final rankSize = isVeryCompact ? 10.0 : 11.0;
    final titleSize = isVeryCompact ? 11.0 : 12.0;
    final summarySize = isVeryCompact ? 9.0 : 10.0;

    return InkWell(
      onTap: onBillTap != null ? () => onBillTap!(bill) : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: EdgeInsets.only(bottom: isVeryCompact ? 3 : 4),
        padding: EdgeInsets.symmetric(
          horizontal: isVeryCompact ? 6 : 8,
          vertical: isVeryCompact ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Rank badge - smaller
            Container(
              width: isVeryCompact ? 16 : 18,
              height: isVeryCompact ? 16 : 18,
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
            // Bill info - compact layout
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Bill identifier
                  Text(
                    bill.billIdentifier,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: titleSize,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  // AI Summary Short or title (single line only)
                  if (!isVeryCompact)
                    Text(
                      hasSummary ? bill.aiSummaryShort! : bill.title,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: summarySize,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            // Position/Priority indicator
            if (accentColor != null)
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(left: 6),
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
