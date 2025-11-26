import 'package:bluebubbles/features/campaigns/widgets/campaign_brand.dart';
import 'package:bluebubbles/models/crm/campaign.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class AnalyticsChart extends StatelessWidget {
  final CampaignAnalytics analytics;

  const AnalyticsChart({super.key, required this.analytics});

  List<BarChartGroupData> _buildBars() {
    final metrics = <String, int>{
      'Delivered': analytics.delivered,
      'Opened': analytics.opened,
      'Clicked': analytics.clicked,
      'Replies': analytics.replies,
      'Unsubscribed': analytics.unsubscribed,
    };

    int index = 0;
    return metrics.entries.map((entry) {
      final group = BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: entry.value.toDouble(),
            borderRadius: BorderRadius.circular(8),
            gradient: CampaignBrand.primaryGradient(),
          ),
        ],
      );
      index++;
      return group;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bars = _buildBars();

    return AspectRatio(
      aspectRatio: 1.6,
      child: BarChart(
        BarChartData(
          gridData: FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: bars,
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                getTitlesWidget: (value, meta) {
                  final labels = ['Delivered', 'Opened', 'Clicked', 'Replies', 'Unsubscribed'];
                  final label = value.toInt() >= 0 && value.toInt() < labels.length
                      ? labels[value.toInt()]
                      : '';
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(label, style: const TextStyle(fontSize: 11)),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  rod.toY.toInt().toString(),
                  const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
