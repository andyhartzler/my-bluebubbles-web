import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/social_media_stats.dart';
import '../theme/communications_committee_theme.dart';

/// Displays a follower growth area chart
class FollowerGrowthChart extends StatelessWidget {
  final List<SocialMediaStats> historicalStats;
  final Set<String> selectedPlatforms;

  const FollowerGrowthChart({
    super.key,
    required this.historicalStats,
    required this.selectedPlatforms,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Group stats by date
    final dataByDate = _groupDataByDate();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Follower Growth',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: dataByDate.isEmpty
                ? Center(
                    child: Text(
                      'No follower data available',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  )
                : _buildChart(dataByDate),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(Map<String, int> dataByDate) {
    final sortedDates = dataByDate.keys.toList()..sort();

    if (sortedDates.isEmpty) {
      return Center(
        child: Text(
          'No data points available',
          style: TextStyle(color: Colors.grey[500]),
        ),
      );
    }

    final spots = <FlSpot>[];
    for (var i = 0; i < sortedDates.length; i++) {
      final date = sortedDates[i];
      final value = dataByDate[date] ?? 0;
      spots.add(FlSpot(i.toDouble(), value.toDouble()));
    }

    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final range = maxY - minY;
    final paddedMin = minY - (range * 0.1);
    final paddedMax = maxY + (range * 0.1);

    return LineChart(
      LineChartData(
        minY: paddedMin > 0 ? paddedMin : 0,
        maxY: paddedMax,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: _calculateInterval(maxY - minY),
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.withOpacity(0.2),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (value, meta) {
                return Text(
                  _formatAxisValue(value),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: (sortedDates.length / 5).ceil().toDouble().clamp(1, double.infinity),
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < sortedDates.length) {
                  final date = DateTime.parse(sortedDates[index]);
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${date.month}/${date.day}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 10,
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: CommunicationsCommitteeTheme.primary,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  CommunicationsCommitteeTheme.primary.withOpacity(0.3),
                  CommunicationsCommitteeTheme.primary.withOpacity(0.0),
                ],
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.x.toInt();
                final date = index >= 0 && index < sortedDates.length
                    ? sortedDates[index]
                    : '';
                return LineTooltipItem(
                  '${_formatDate(date)}\n${_formatNumber(spot.y.toInt())} followers',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  Map<String, int> _groupDataByDate() {
    final result = <String, int>{};

    for (final stats in historicalStats) {
      if (!selectedPlatforms.contains(stats.platform)) continue;

      final date = stats.metricDate;
      final followers = stats.followersCount ?? 0;
      result[date] = (result[date] ?? 0) + followers;
    }

    return result;
  }

  double _calculateInterval(double range) {
    if (range <= 100) return 20;
    if (range <= 1000) return 200;
    if (range <= 10000) return 2000;
    return 20000;
  }

  String _formatAxisValue(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}K';
    }
    return value.toInt().toString();
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.month}/${date.day}/${date.year}';
    } catch (_) {
      return dateStr;
    }
  }
}
