import 'package:bluebubbles/features/campaigns/widgets/analytics_chart.dart';
import 'package:bluebubbles/features/campaigns/widgets/campaign_brand.dart';
import 'package:bluebubbles/features/campaigns/widgets/campaign_stats_widget.dart';
import 'package:bluebubbles/models/crm/campaign.dart';
import 'package:bluebubbles/services/crm/campaign_service.dart';
import 'package:flutter/material.dart';

class CampaignAnalyticsScreen extends StatefulWidget {
  final Campaign campaign;

  const CampaignAnalyticsScreen({super.key, required this.campaign});

  @override
  State<CampaignAnalyticsScreen> createState() => _CampaignAnalyticsScreenState();
}

class _CampaignAnalyticsScreenState extends State<CampaignAnalyticsScreen> {
  final CampaignService _campaignService = CampaignService();
  CampaignAnalytics _analytics = const CampaignAnalytics();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _loading = true);
    final analytics = await _campaignService.fetchAnalytics(widget.campaign.id ?? '');
    if (!mounted) return;
    setState(() {
      _analytics = analytics;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Campaign analytics'),
        backgroundColor: CampaignBrand.unityBlue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.campaign.name, style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  CampaignStatsWidget(
                    sent: _analytics.delivered,
                    expected: _analytics.totalRecipients,
                    opened: _analytics.opened,
                    clicked: _analytics.clicked,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Chip(
                        backgroundColor: CampaignBrand.sunriseGold,
                        label: Text('Open rate ${(100 * _analytics.openRate).toStringAsFixed(1)}%'),
                      ),
                      const SizedBox(width: 8),
                      Chip(
                        backgroundColor: CampaignBrand.grassrootsGreen,
                        label: Text('Click rate ${(100 * _analytics.clickRate).toStringAsFixed(1)}%'),
                      ),
                      const SizedBox(width: 8),
                      Chip(
                        backgroundColor: CampaignBrand.justicePurple,
                        label: Text('Reply rate ${(100 * _analytics.replyRate).toStringAsFixed(1)}%'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: AnalyticsChart(analytics: _analytics),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
