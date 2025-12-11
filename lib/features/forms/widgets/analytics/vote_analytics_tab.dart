import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/vote_analytics.dart';
import '../../services/votes_service.dart';
import 'engagement_funnel_widget.dart';
import 'analytics_stat_card.dart';

/// Analytics tab content for vote detail screen
class VoteAnalyticsTab extends StatefulWidget {
  final String formId;

  const VoteAnalyticsTab({Key? key, required this.formId}) : super(key: key);

  @override
  State<VoteAnalyticsTab> createState() => _VoteAnalyticsTabState();
}

class _VoteAnalyticsTabState extends State<VoteAnalyticsTab> {
  final _votesService = VotesService();
  VoteAnalytics? _analytics;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final analytics = await _votesService.getVoteAnalytics(widget.formId);
      setState(() {
        _analytics = analytics;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: colorScheme.error),
            const SizedBox(height: 16),
            Text('Error loading analytics', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadAnalytics,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final analytics = _analytics!;

    return RefreshIndicator(
      onRefresh: _loadAnalytics,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Engagement Funnel
            EngagementFunnelWidget(analytics: analytics),
            const SizedBox(height: 24),

            // Key Metrics
            Text(
              'Key Metrics',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildMetricsGrid(theme, colorScheme, analytics),
            const SizedBox(height: 24),

            // Daily Activity Chart
            if (analytics.dailyActivity.isNotEmpty) ...[
              Text(
                'Daily Activity',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _buildActivityChart(theme, colorScheme, analytics),
              const SizedBox(height: 24),
            ],

            // Question Engagement
            if (analytics.fieldAnalytics.isNotEmpty) ...[
              Text(
                'Question Engagement',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _buildFieldEngagementList(theme, colorScheme, analytics),
            ],

            // Empty state if no activity data
            if (analytics.dailyActivity.isEmpty &&
                analytics.fieldAnalytics.isEmpty &&
                analytics.totalSubmissions == 0) ...[
              const SizedBox(height: 24),
              _buildEmptyState(theme, colorScheme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsGrid(
    ThemeData theme,
    ColorScheme colorScheme,
    VoteAnalytics analytics,
  ) {
    return AnalyticsStatsGrid(
      cards: [
        AnalyticsStatCard(
          title: 'View to Start',
          value: '${analytics.viewToStartRate.toStringAsFixed(1)}%',
          icon: Icons.play_arrow,
          color: Colors.blue,
          subtitle: '${analytics.totalStarts} started',
        ),
        AnalyticsStatCard(
          title: 'Start to Submit',
          value: '${analytics.startToSubmitRate.toStringAsFixed(1)}%',
          icon: Icons.check_circle,
          color: Colors.green,
          subtitle: '${analytics.totalSubmissions} completed',
        ),
        AnalyticsStatCard(
          title: 'Overall Conversion',
          value: '${analytics.overallConversionRate.toStringAsFixed(1)}%',
          icon: Icons.trending_up,
          color: Colors.purple,
          subtitle: 'View to submit',
        ),
        AnalyticsStatCard(
          title: 'Abandons',
          value: analytics.totalAbandons.toString(),
          icon: Icons.exit_to_app,
          color: Colors.orange,
          subtitle: analytics.totalStarts > 0
              ? '${(analytics.totalAbandons / analytics.totalStarts * 100).toStringAsFixed(1)}% abandon rate'
              : 'No abandons',
        ),
      ],
    );
  }

  Widget _buildActivityChart(
    ThemeData theme,
    ColorScheme colorScheme,
    VoteAnalytics analytics,
  ) {
    final dailyData = analytics.dailyActivity;
    if (dailyData.isEmpty) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        child: const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: Text('No activity data yet')),
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LegendItem(color: Colors.blue, label: 'Daily Votes'),
                const SizedBox(width: 24),
                _LegendItem(color: Colors.green, label: 'Cumulative'),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: _calculateInterval(dailyData),
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: colorScheme.outlineVariant,
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= dailyData.length) {
                            return const SizedBox();
                          }
                          // Show every nth label based on data length
                          final interval = (dailyData.length / 5).ceil();
                          if (index % interval != 0 && index != dailyData.length - 1) {
                            return const SizedBox();
                          }
                          final date = dailyData[index].date;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '${date.month}/${date.day}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
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
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border(
                      bottom: BorderSide(color: colorScheme.outlineVariant),
                      left: BorderSide(color: colorScheme.outlineVariant),
                    ),
                  ),
                  lineBarsData: [
                    // Daily submissions (bar effect with dots)
                    LineChartBarData(
                      spots: dailyData.asMap().entries.map((e) {
                        return FlSpot(e.key.toDouble(), e.value.submissions.toDouble());
                      }).toList(),
                      isCurved: false,
                      color: Colors.blue,
                      barWidth: 2,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.blue.withOpacity(0.1),
                      ),
                    ),
                    // Cumulative votes line
                    LineChartBarData(
                      spots: dailyData.asMap().entries.map((e) {
                        return FlSpot(e.key.toDouble(), e.value.cumulativeVotes.toDouble());
                      }).toList(),
                      isCurved: true,
                      color: Colors.green,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, bar, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: Colors.green,
                            strokeWidth: 0,
                          );
                        },
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final index = spot.x.toInt();
                          if (index < 0 || index >= dailyData.length) {
                            return null;
                          }
                          final data = dailyData[index];
                          final isDaily = spot.barIndex == 0;
                          return LineTooltipItem(
                            isDaily
                                ? '${data.submissions} votes'
                                : '${data.cumulativeVotes} total',
                            TextStyle(
                              color: isDaily ? Colors.blue : Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
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

  double _calculateInterval(List<DailyActivityData> data) {
    if (data.isEmpty) return 1;
    final maxValue = data.map((d) => d.cumulativeVotes).reduce((a, b) => a > b ? a : b);
    if (maxValue <= 5) return 1;
    if (maxValue <= 20) return 5;
    if (maxValue <= 50) return 10;
    return (maxValue / 5).ceilToDouble();
  }

  Widget _buildFieldEngagementList(
    ThemeData theme,
    ColorScheme colorScheme,
    VoteAnalytics analytics,
  ) {
    final fields = analytics.fieldAnalytics;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: fields.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final field = fields[index];
          final completionRate = field.completionRate;

          return ListTile(
            leading: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              field.fieldLabel ?? 'Question ${index + 1}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              '${field.interactions} interactions',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${completionRate.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: completionRate >= 80
                        ? Colors.green
                        : completionRate >= 50
                            ? Colors.orange
                            : Colors.red,
                  ),
                ),
                Text(
                  'completion',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 64,
              color: colorScheme.onSurfaceVariant.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No Analytics Data Yet',
              style: theme.textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Analytics will appear here once voters start engaging with this vote.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
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
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}
