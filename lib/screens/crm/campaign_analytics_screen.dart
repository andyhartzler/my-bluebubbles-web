import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/app/wrappers/titlebar_wrapper.dart';
import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/models/crm/campaign.dart';
import 'package:bluebubbles/models/crm/campaign_analytics.dart';
import 'package:bluebubbles/providers/campaign_analytics_provider.dart';

class CampaignAnalyticsScreen extends StatefulWidget {
  const CampaignAnalyticsScreen({super.key, this.campaign, this.campaignId});

  final Campaign? campaign;
  final String? campaignId;

  @override
  State<CampaignAnalyticsScreen> createState() => _CampaignAnalyticsScreenState();
}

class _CampaignAnalyticsScreenState extends State<CampaignAnalyticsScreen> {
  late final CampaignAnalyticsProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = CampaignAnalyticsProvider();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _provider.loadAnalytics(
        campaignId: widget.campaignId ?? widget.campaign?.id,
        campaign: widget.campaign,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return TitleBarWrapper(
      child: ThemeSwitcher(
        iOSSkin: (_) => const SizedBox.shrink(),
        materialSkin: ChangeNotifierProvider<CampaignAnalyticsProvider>.value(
          value: _provider,
          child: Scaffold(
            appBar: AppBar(
              title: Consumer<CampaignAnalyticsProvider>(
                builder: (context, provider, _) {
                  final String title = provider.campaign?.name ?? 'Campaign Analytics';
                  return Text(title);
                },
              ),
            ),
            body: Consumer<CampaignAnalyticsProvider>(
              builder: (context, provider, _) {
                if (!CRMConfig.crmEnabled) {
                  return _buildEmptyState(
                    context,
                    title: 'CRM Disabled',
                    description:
                        'Provide SUPABASE_URL and SUPABASE_ANON_KEY in your .env file to enable campaign analytics.',
                  );
                }

                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.error != null) {
                  return _buildEmptyState(
                    context,
                    title: 'Unable to load analytics',
                    description: provider.error!,
                    actionLabel: 'Retry',
                    onAction: () => provider.loadAnalytics(
                      campaignId: widget.campaignId ?? widget.campaign?.id,
                      campaign: widget.campaign,
                    ),
                  );
                }

                final CampaignAnalytics analytics = provider.analytics;
                if (analytics.totalRecipients == 0 &&
                    analytics.topLinks.isEmpty &&
                    analytics.clickTimeline.isEmpty) {
                  return _buildEmptyState(
                    context,
                    title: 'No analytics found',
                    description:
                        'Campaign activity will appear here after your next send.',
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => provider.loadAnalytics(
                    campaignId: widget.campaignId ?? widget.campaign?.id,
                    campaign: widget.campaign,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildOverview(context, analytics),
                              const SizedBox(height: 16),
                              _buildFunnelChart(context, analytics),
                              const SizedBox(height: 16),
                              _buildTimelineCard(context, analytics),
                              const SizedBox(height: 16),
                              _buildTopLinks(context, analytics),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ),
        samsungSkin: const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildOverview(BuildContext context, CampaignAnalytics analytics) {
    final List<_StatCardData> cards = <_StatCardData>[
      _StatCardData('Recipients', analytics.totalRecipients, Icons.group_outlined,
          subtitle: 'Total audience'),
      _StatCardData('Delivered', analytics.delivered, Icons.mark_email_read_outlined,
          subtitle: _toPercent(analytics.deliveryRate)),
      _StatCardData('Opened', analytics.opened, Icons.drafts_outlined,
          subtitle: _toPercent(analytics.openRate)),
      _StatCardData('Clicked', analytics.clicked, Icons.link_outlined,
          subtitle: _toPercent(analytics.clickRate)),
      _StatCardData('Unique clickers', analytics.uniqueClickers, Icons.person_pin_circle_outlined,
          subtitle: _toPercent(analytics.uniqueClickRate)),
      _StatCardData('Bounced', analytics.bounced, Icons.error_outline, subtitle: 'Failures'),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: cards.map((data) => _StatCard(data: data)).toList(),
    );
  }

  Widget _buildFunnelChart(BuildContext context, CampaignAnalytics analytics) {
    final List<_FunnelStep> steps = <_FunnelStep>[
      _FunnelStep('Sent', analytics.totalRecipients, Colors.blueGrey.shade300),
      _FunnelStep('Delivered', analytics.delivered, Colors.green.shade400),
      _FunnelStep('Opened', analytics.opened, Colors.amber.shade600),
      _FunnelStep('Clicked', analytics.clicked, Colors.blue.shade500),
    ];

    final double maxY = (steps.map((step) => step.value).maxOrNull ?? 1).toDouble().clamp(1, double.infinity);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Engagement funnel', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(
              height: 240,
              child: BarChart(
                BarChartData(
                  gridData: FlGridData(show: true, drawVerticalLine: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          final int index = value.toInt();
                          if (index < 0 || index >= steps.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              steps[index].label,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  maxY: maxY,
                  barGroups: [
                    for (int i = 0; i < steps.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: steps[i].value.toDouble(),
                            borderRadius: BorderRadius.circular(6),
                            width: 18,
                            color: steps[i].color,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineCard(BuildContext context, CampaignAnalytics analytics) {
    final List<TimeSeriesPoint> points = analytics.clickTimeline.isNotEmpty
        ? analytics.clickTimeline
        : (analytics.openTimeline.isNotEmpty ? analytics.openTimeline : analytics.sendTimeline);

    if (points.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Engagement over time', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              const Text('No time-series data available yet.'),
            ],
          ),
        ),
      );
    }

    final double maxY =
        (points.map((point) => point.count).maxOrNull ?? 1).toDouble().clamp(1, double.infinity);
    final DateFormat dateFormat = DateFormat.MMMd();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Engagement over time', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(
              height: 240,
              child: BarChart(
                BarChartData(
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          final int index = value.toInt();
                          if (index < 0 || index >= points.length) {
                            return const SizedBox.shrink();
                          }
                          final DateTime date = points[index].timestamp;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              dateFormat.format(date),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  maxY: maxY,
                  barGroups: [
                    for (int i = 0; i < points.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: points[i].count.toDouble(),
                            borderRadius: BorderRadius.circular(6),
                            color: Theme.of(context).colorScheme.primary,
                            width: 14,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopLinks(BuildContext context, CampaignAnalytics analytics) {
    final List<CampaignLinkAnalytics> links = analytics.topLinks;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Top links', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (links.isEmpty)
              const Text('No link activity yet.')
            else
              ...links.map(
                (link) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.link_outlined),
                  title: Text(link.label?.isNotEmpty == true ? link.label! : link.url),
                  subtitle: Text(link.url),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${link.clicks} clicks'),
                      Text('${link.uniqueClicks} unique'),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context, {
    required String title,
    required String description,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insights_outlined, size: 56, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(onPressed: onAction, child: Text(actionLabel)),
            ],
          ],
        ),
      ),
    );
  }

  String _toPercent(double value) => '${(value * 100).toStringAsFixed(1)}%';
}

class _StatCardData {
  const _StatCardData(this.label, this.value, this.icon, {this.subtitle});

  final String label;
  final int value;
  final IconData icon;
  final String? subtitle;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.data});

  final _StatCardData data;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(data.icon, size: 28, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 8),
              Text(data.label, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              Text(
                data.value.toString(),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (data.subtitle != null)
                Text(
                  data.subtitle!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FunnelStep {
  const _FunnelStep(this.label, this.value, this.color);

  final String label;
  final int value;
  final Color color;
}
