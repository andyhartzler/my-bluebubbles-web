import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/social_media_stats.dart';
import '../theme/communications_committee_theme.dart';

/// Displays an engagement over time line chart
class EngagementChart extends StatelessWidget {
  final List<SocialMediaStats> historicalStats;
  final Set<String> selectedPlatforms;

  const EngagementChart({
    super.key,
    required this.historicalStats,
    required this.selectedPlatforms,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Group stats by date and platform
    final dataByPlatform = _groupDataByPlatform();

    return Container(
      margin: const EdgeInsets.all(16),
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
            'Engagement Over Time',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _buildLegend(),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: dataByPlatform.isEmpty
                ? Center(
                    child: Text(
                      'No engagement data available',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  )
                : _buildChart(dataByPlatform),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    final platforms = selectedPlatforms.toList()..sort();

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: platforms.asMap().entries.map((entry) {
        final index = entry.key;
        final platform = entry.value;
        final color = CommunicationsCommitteeTheme.getChartColor(index);

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              _capitalize(platform),
              style: const TextStyle(fontSize: 12),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildChart(Map<String, List<_DataPoint>> dataByPlatform) {
    final allDates = dataByPlatform.values
        .expand((points) => points.map((p) => p.date))
        .toSet()
        .toList()
      ..sort();

    if (allDates.isEmpty) {
      return Center(
        child: Text(
          'No data points available',
          style: TextStyle(color: Colors.grey[500]),
        ),
      );
    }

    final lineBarsData = <LineChartBarData>[];
    final platforms = dataByPlatform.keys.toList()..sort();

    for (var i = 0; i < platforms.length; i++) {
      final platform = platforms[i];
      final points = dataByPlatform[platform]!;
      final color = CommunicationsCommitteeTheme.getChartColor(i);

      final spots = <FlSpot>[];
      for (var j = 0; j < allDates.length; j++) {
        final date = allDates[j];
        final point = points.firstWhere(
          (p) => p.date == date,
          orElse: () => _DataPoint(date: date, value: 0),
        );
        spots.add(FlSpot(j.toDouble(), point.value.toDouble()));
      }

      lineBarsData.add(
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: color,
          barWidth: 2,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: color.withOpacity(0.1),
          ),
        ),
      );
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: _calculateInterval(dataByPlatform),
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
              reservedSize: 40,
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
              interval: (allDates.length / 5).ceil().toDouble().clamp(1, double.infinity),
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < allDates.length) {
                  final date = DateTime.parse(allDates[index]);
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
        lineBarsData: lineBarsData,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final platform = platforms[spot.barIndex];
                final color = CommunicationsCommitteeTheme.getChartColor(spot.barIndex);
                return LineTooltipItem(
                  '${_capitalize(platform)}: ${_formatNumber(spot.y.toInt())}',
                  TextStyle(color: color, fontWeight: FontWeight.bold),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  Map<String, List<_DataPoint>> _groupDataByPlatform() {
    final result = <String, List<_DataPoint>>{};

    for (final stats in historicalStats) {
      if (!selectedPlatforms.contains(stats.platform)) continue;

      result.putIfAbsent(stats.platform, () => []);
      result[stats.platform]!.add(_DataPoint(
        date: stats.metricDate,
        value: stats.totalEngagement,
      ));
    }

    // Sort each list by date
    for (final points in result.values) {
      points.sort((a, b) => a.date.compareTo(b.date));
    }

    return result;
  }

  double _calculateInterval(Map<String, List<_DataPoint>> data) {
    final maxValue = data.values
        .expand((points) => points.map((p) => p.value))
        .fold<int>(0, (max, v) => v > max ? v : max);

    if (maxValue <= 100) return 20;
    if (maxValue <= 1000) return 200;
    if (maxValue <= 10000) return 2000;
    return 20000;
  }

  String _formatAxisValue(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(0)}M';
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

  String _capitalize(String s) =>
      s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : s;
}

class _DataPoint {
  final String date;
  final int value;

  _DataPoint({required this.date, required this.value});
}
