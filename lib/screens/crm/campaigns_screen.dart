import 'package:flutter/material.dart';

import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/app/wrappers/titlebar_wrapper.dart';
import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/models/crm/campaign.dart';
import 'package:bluebubbles/screens/crm/campaign_analytics_screen.dart';
import 'package:bluebubbles/screens/crm/campaign_detail_screen.dart';
import 'package:bluebubbles/services/crm/campaign_service.dart';

class CampaignsScreen extends StatefulWidget {
  const CampaignsScreen({super.key});

  @override
  State<CampaignsScreen> createState() => _CampaignsScreenState();
}

class _CampaignsScreenState extends State<CampaignsScreen> {
  final CampaignService _service = CampaignService();
  bool _loading = true;
  String? _error;
  List<Campaign> _campaigns = const <Campaign>[];

  @override
  void initState() {
    super.initState();
    _loadCampaigns();
  }

  Future<void> _loadCampaigns() async {
    if (!CRMConfig.crmEnabled) {
      setState(() {
        _loading = false;
        _campaigns = const <Campaign>[];
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final List<Campaign> campaigns = await _service.fetchCampaigns();
      if (!mounted) return;
      setState(() {
        _campaigns = campaigns;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  void _openAnalytics(Campaign campaign) {
    Navigator.of(context).push(
      ThemeSwitcher.buildPageRoute(
        builder: (_) => TitleBarWrapper(
          child: CampaignAnalyticsScreen(campaign: campaign),
        ),
      ),
    );
  }

  void _openDetail(Campaign campaign) {
    Navigator.of(context).push(
      ThemeSwitcher.buildPageRoute(
        builder: (_) => TitleBarWrapper(
          child: CampaignDetailScreen(campaign: campaign),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TitleBarWrapper(
      child: ThemeSwitcher(
        iOSSkin: (_) => const SizedBox.shrink(),
        materialSkin: Scaffold(
          appBar: AppBar(
            title: const Text('Campaigns'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadCampaigns,
              ),
            ],
          ),
          body: _buildBody(),
        ),
        samsungSkin: const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildBody() {
    if (!CRMConfig.crmEnabled) {
      return _buildMessage(
        'CRM Disabled',
        'Provide Supabase credentials to fetch campaigns.',
      );
    }

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildMessage('Unable to load campaigns', _error!, action: _loadCampaigns);
    }

    if (_campaigns.isEmpty) {
      return _buildMessage('No campaigns yet', 'Create or import campaigns to view them here.');
    }

    return RefreshIndicator(
      onRefresh: _loadCampaigns,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _campaigns.length,
        itemBuilder: (context, index) {
          final Campaign campaign = _campaigns[index];
          return Card(
            child: ListTile(
              title: Text(campaign.name),
              subtitle: Text(campaign.subject ?? 'No subject'),
              trailing: Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: () => _openAnalytics(campaign),
                    icon: const Icon(Icons.insights_outlined),
                    label: const Text('Analytics'),
                  ),
                  IconButton(
                    onPressed: () => _openDetail(campaign),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              onTap: () => _openDetail(campaign),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessage(String title, String subtitle, {VoidCallback? action}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.email_outlined, size: 52, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center),
            if (action != null) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: action,
                icon: const Icon(Icons.refresh),
                label: const Text('Reload'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
