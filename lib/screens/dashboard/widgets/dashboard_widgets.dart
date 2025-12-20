import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../../../models/crm/dashboard_metrics.dart';
import '../../../models/crm/member.dart';
import '../models/dashboard_widget_config.dart';

// Brand colors
const _unityBlue = Color(0xFF273351);
const _momentumBlue = Color(0xFF32A6DE);
const _sunriseGold = Color(0xFFFDB813);
const _actionRed = Color(0xFFE63946);
const _justicePurple = Color(0xFF6A1B9A);
const _grassrootsGreen = Color(0xFF43A047);

/// Default gradient sets for widgets
class WidgetGradients {
  static const List<List<Color>> all = [
    [_unityBlue, _momentumBlue],
    [_momentumBlue, _justicePurple],
    [_grassrootsGreen, _momentumBlue],
    [_sunriseGold, _actionRed],
    [_justicePurple, _actionRed],
    [_actionRed, _sunriseGold],
    [_grassrootsGreen, _sunriseGold],
    [_unityBlue, _grassrootsGreen],
  ];

  static List<Color> get random => all[math.Random().nextInt(all.length)];
}

/// Renders a stat card widget
class StatCardWidget extends StatelessWidget {
  final DashboardWidgetConfig config;
  final dynamic value;
  final String? trend;
  final VoidCallback? onTap;

  const StatCardWidget({
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
        : WidgetGradients.all[0];

    final displayValue = _formatValue(value);

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
          padding: const EdgeInsets.all(20),
          child: Column(
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
          ),
        ),
      ),
    );
  }

  String _formatValue(dynamic val) {
    if (val is num) {
      if (val >= 1000000) {
        return '${(val / 1000000).toStringAsFixed(1)}M';
      } else if (val >= 1000) {
        return '${(val / 1000).toStringAsFixed(1)}K';
      }
      if (val is double) {
        if (config.dataSourceKey.contains('Amount') || config.dataSourceKey.contains('Donation')) {
          return '\$${val.toStringAsFixed(0)}';
        }
        return val.toStringAsFixed(1);
      }
      return val.toString();
    }
    return val?.toString() ?? '0';
  }
}

/// Renders a bar chart widget
class BarChartWidget extends StatelessWidget {
  final DashboardWidgetConfig config;
  final List<NameCount> data;
  final int maxItems;

  const BarChartWidget({
    super.key,
    required this.config,
    required this.data,
    this.maxItems = 8,
  });

  @override
  Widget build(BuildContext context) {
    final sortedData = List<NameCount>.from(data)
      ..sort((a, b) => b.count.compareTo(a.count));
    final displayData = sortedData.take(maxItems).toList();

    if (displayData.isEmpty) {
      return _buildEmptyState();
    }

    final maxValue = displayData.fold<int>(0, (prev, e) => e.count > prev ? e.count : prev);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            Expanded(
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: (maxValue * 1.2).clamp(1, double.infinity).toDouble(),
                  barGroups: List.generate(displayData.length, (index) {
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: displayData[index].count.toDouble(),
                          width: config.size == DashboardWidgetSize.small ? 12 : 20,
                          borderRadius: BorderRadius.circular(6),
                          gradient: LinearGradient(
                            colors: config.gradientColors.isNotEmpty
                                ? config.gradientColors
                                : [_momentumBlue, _justicePurple],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                        ),
                      ],
                    );
                  }),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= displayData.length) {
                            return const SizedBox.shrink();
                          }
                          final label = displayData[index].name;
                          final displayLabel = label.length > 10
                              ? '${label.substring(0, 9)}…'
                              : label;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: RotatedBox(
                              quarterTurns: -1,
                              child: Text(
                                displayLabel,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: _unityBlue,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 35,
                        getTitlesWidget: (value, meta) => Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 10, color: _unityBlue),
                        ),
                      ),
                    ),
                  ),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      tooltipBgColor: _unityBlue.withOpacity(0.9),
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final entry = displayData[groupIndex];
                        return BarTooltipItem(
                          '${entry.name}\n',
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          children: [
                            TextSpan(
                              text: '${entry.count}',
                              style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 11),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
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
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _momentumBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(config.icon ?? Icons.bar_chart, color: _momentumBlue, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            config.title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: _unityBlue,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bar_chart, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 8),
              Text(
                'No data available',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Renders a pie/donut chart widget
class PieChartWidget extends StatefulWidget {
  final DashboardWidgetConfig config;
  final List<NameCount> data;
  final bool isDonut;
  final int maxItems;

  const PieChartWidget({
    super.key,
    required this.config,
    required this.data,
    this.isDonut = false,
    this.maxItems = 6,
  });

  @override
  State<PieChartWidget> createState() => _PieChartWidgetState();
}

class _PieChartWidgetState extends State<PieChartWidget> {
  int _touchedIndex = -1;

  static const List<Color> _pieColors = [
    _momentumBlue,
    _grassrootsGreen,
    _sunriseGold,
    _justicePurple,
    _actionRed,
    Color(0xFF00BCD4),
    Color(0xFFFF9800),
    Color(0xFF9C27B0),
  ];

  @override
  Widget build(BuildContext context) {
    final sortedData = List<NameCount>.from(widget.data)
      ..sort((a, b) => b.count.compareTo(a.count));
    final displayData = sortedData.take(widget.maxItems).toList();

    // Add "Other" category if there are more items
    if (sortedData.length > widget.maxItems) {
      final otherCount = sortedData.skip(widget.maxItems).fold<int>(0, (sum, e) => sum + e.count);
      if (otherCount > 0) {
        displayData.add(NameCount(name: 'Other', count: otherCount));
      }
    }

    if (displayData.isEmpty) {
      return _buildEmptyState();
    }

    final total = displayData.fold<int>(0, (sum, e) => sum + e.count);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: PieChart(
                      PieChartData(
                        pieTouchData: PieTouchData(
                          touchCallback: (event, response) {
                            setState(() {
                              if (!event.isInterestedForInteractions ||
                                  response == null ||
                                  response.touchedSection == null) {
                                _touchedIndex = -1;
                                return;
                              }
                              _touchedIndex = response.touchedSection!.touchedSectionIndex;
                            });
                          },
                        ),
                        borderData: FlBorderData(show: false),
                        sectionsSpace: 2,
                        centerSpaceRadius: widget.isDonut ? 40 : 0,
                        sections: List.generate(displayData.length, (index) {
                          final isTouched = index == _touchedIndex;
                          final entry = displayData[index];
                          final percentage = total > 0 ? (entry.count / total * 100) : 0.0;
                          return PieChartSectionData(
                            color: _pieColors[index % _pieColors.length],
                            value: entry.count.toDouble(),
                            title: isTouched ? '${percentage.toStringAsFixed(1)}%' : '',
                            radius: isTouched ? 60 : 50,
                            titleStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(displayData.length, (index) {
                          final entry = displayData[index];
                          final percentage = total > 0 ? (entry.count / total * 100) : 0.0;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: _pieColors[index % _pieColors.length],
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    entry.name.length > 12
                                        ? '${entry.name.substring(0, 11)}…'
                                        : entry.name,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: _touchedIndex == index ? _unityBlue : Colors.grey[700],
                                      fontWeight: _touchedIndex == index ? FontWeight.bold : FontWeight.normal,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '${percentage.toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
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

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _momentumBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(widget.config.icon ?? Icons.pie_chart, color: _momentumBlue, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            widget.config.title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: _unityBlue,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.pie_chart, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 8),
              Text(
                'No data available',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Renders a line chart widget
class LineChartWidget extends StatelessWidget {
  final DashboardWidgetConfig config;
  final List<MonthlyCount> data;

  const LineChartWidget({
    super.key,
    required this.config,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return _buildEmptyState();
    }

    final sortedData = List<MonthlyCount>.from(data)
      ..sort((a, b) => a.month.compareTo(b.month));

    final maxValue = sortedData.fold<int>(0, (prev, e) => e.count > prev ? e.count : prev);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            Expanded(
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: (maxValue * 1.2).clamp(1, double.infinity).toDouble(),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxValue > 0 ? maxValue / 4 : 1,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey[300]!,
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= sortedData.length) {
                            return const SizedBox.shrink();
                          }
                          final month = sortedData[index].month;
                          // Format: 2025-10 -> Oct
                          final parts = month.split('-');
                          if (parts.length < 2) return const SizedBox.shrink();
                          final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                          final monthNum = int.tryParse(parts[1]) ?? 1;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              monthNames[monthNum - 1],
                              style: const TextStyle(fontSize: 10, color: _unityBlue),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 35,
                        getTitlesWidget: (value, meta) => Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 10, color: _unityBlue),
                        ),
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: List.generate(sortedData.length, (index) {
                        return FlSpot(index.toDouble(), sortedData[index].count.toDouble());
                      }),
                      isCurved: true,
                      color: _momentumBlue,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, bar, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: Colors.white,
                            strokeWidth: 2,
                            strokeColor: _momentumBlue,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            _momentumBlue.withOpacity(0.3),
                            _momentumBlue.withOpacity(0.05),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      tooltipBgColor: _unityBlue.withOpacity(0.9),
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final entry = sortedData[spot.x.toInt()];
                          return LineTooltipItem(
                            '${entry.month}\n${entry.count} new members',
                            const TextStyle(color: Colors.white, fontSize: 12),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
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
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _momentumBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(config.icon ?? Icons.show_chart, color: _momentumBlue, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            config.title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: _unityBlue,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.show_chart, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 8),
              Text(
                'No data available',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Renders a leaderboard widget
class LeaderboardWidget extends StatelessWidget {
  final DashboardWidgetConfig config;
  final List<dynamic> data; // Can be TopDonor or TopSlackMember
  final bool isDonors;
  final int maxItems;

  const LeaderboardWidget({
    super.key,
    required this.config,
    required this.data,
    this.isDonors = false,
    this.maxItems = 5,
  });

  @override
  Widget build(BuildContext context) {
    final displayData = data.take(maxItems).toList();

    if (displayData.isEmpty) {
      return _buildEmptyState();
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: displayData.length,
                itemBuilder: (context, index) {
                  final item = displayData[index];
                  final name = isDonors
                      ? (item as TopDonor).name
                      : (item as TopSlackMember).name;
                  final value = isDonors
                      ? '\$${(item as TopDonor).totalDonated.toStringAsFixed(0)}'
                      : '${(item as TopSlackMember).messageCount} msgs';

                  return _buildLeaderboardItem(
                    rank: index + 1,
                    name: name,
                    value: value,
                  );
                },
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
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _sunriseGold.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(config.icon ?? Icons.emoji_events, color: _sunriseGold, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            config.title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: _unityBlue,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderboardItem({
    required int rank,
    required String name,
    required String value,
  }) {
    final rankColors = [_sunriseGold, Colors.grey[400]!, Color(0xFFCD7F32)];
    final rankColor = rank <= 3 ? rankColors[rank - 1] : Colors.grey[300]!;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: rankColor.withOpacity(0.2),
              shape: BoxShape.circle,
              border: rank <= 3 ? Border.all(color: rankColor, width: 2) : null,
            ),
            child: Center(
              child: rank <= 3
                  ? Icon(Icons.emoji_events, size: 14, color: rankColor)
                  : Text(
                      '$rank',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: rank <= 3 ? FontWeight.w600 : FontWeight.normal,
                color: _unityBlue,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _grassrootsGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _grassrootsGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.leaderboard, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 8),
              Text(
                'No data available',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Progress ring widget for showing percentage/goal progress
class ProgressRingWidget extends StatelessWidget {
  final DashboardWidgetConfig config;
  final int current;
  final int total;
  final String? suffix;

  const ProgressRingWidget({
    super.key,
    required this.config,
    required this.current,
    required this.total,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = total > 0 ? (current / total).clamp(0.0, 1.0) : 0.0;
    final colors = config.gradientColors.isNotEmpty
        ? config.gradientColors
        : [_momentumBlue, _justicePurple];

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SizedBox(
                  width: 120,
                  height: 120,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: percentage,
                        strokeWidth: 10,
                        backgroundColor: colors.first.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(colors.first),
                      ),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              current.toString(),
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: colors.first,
                              ),
                            ),
                            Text(
                              suffix ?? '/ $total',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              config.title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: _unityBlue,
              ),
              textAlign: TextAlign.center,
            ),
            if (config.subtitle != null)
              Text(
                config.subtitle!,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}

/// Renders a member list widget with profile photos
class MemberListWidget extends StatelessWidget {
  final DashboardWidgetConfig config;
  final List<Member> members;
  final void Function(Member member)? onMemberTap;
  final int maxItems;

  const MemberListWidget({
    super.key,
    required this.config,
    required this.members,
    this.onMemberTap,
    this.maxItems = 5,
  });

  @override
  Widget build(BuildContext context) {
    final displayMembers = members.take(maxItems).toList();

    if (displayMembers.isEmpty) {
      return _buildEmptyState();
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: displayMembers.length,
                itemBuilder: (context, index) {
                  final member = displayMembers[index];
                  return _buildMemberItem(context, member, index);
                },
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
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _grassrootsGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(config.icon ?? Icons.person_add, color: _grassrootsGreen, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            config.title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: _unityBlue,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMemberItem(BuildContext context, Member member, int index) {
    // Calculate how many days ago they joined
    String joinedText = '';
    if (member.createdAt != null) {
      final daysAgo = DateTime.now().difference(member.createdAt!).inDays;
      if (daysAgo == 0) {
        joinedText = 'Today';
      } else if (daysAgo == 1) {
        joinedText = 'Yesterday';
      } else if (daysAgo < 7) {
        joinedText = '$daysAgo days ago';
      } else if (daysAgo < 30) {
        final weeks = (daysAgo / 7).floor();
        joinedText = weeks == 1 ? '1 week ago' : '$weeks weeks ago';
      } else {
        final months = (daysAgo / 30).floor();
        joinedText = months == 1 ? '1 month ago' : '$months months ago';
      }
    }

    return InkWell(
      onTap: onMemberTap != null ? () => onMemberTap!(member) : null,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            // Profile photo or avatar
            _buildMemberAvatar(member),
            const SizedBox(width: 12),
            // Member info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _unityBlue,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (member.chapterName != null || member.county != null)
                    Text(
                      member.chapterName ?? member.county ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            // Joined date badge
            if (joinedText.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _momentumBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  joinedText,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: _momentumBlue,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberAvatar(Member member) {
    final photoUrl = member.primaryProfilePhotoUrl;
    final size = 44.0;

    // Generate initials for fallback
    final initials = _getInitials(member.name);

    // Generate a consistent color based on the member's name
    final colorIndex = member.name.hashCode.abs() % WidgetGradients.all.length;
    final gradientColors = WidgetGradients.all[colorIndex];

    Widget fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );

    if (photoUrl != null && photoUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          photoUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[200],
              ),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    return fallback;
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '?';
    }
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  Widget _buildEmptyState() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.people_outline, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 8),
              Text(
                'No recent members',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
