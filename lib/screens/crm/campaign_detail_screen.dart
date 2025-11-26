import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/app/wrappers/titlebar_wrapper.dart';
import 'package:bluebubbles/models/crm/campaign.dart';
import 'package:bluebubbles/screens/crm/campaign_analytics_screen.dart';
import 'package:bluebubbles/services/crm/campaign_service.dart';

class CampaignDetailScreen extends StatefulWidget {
  const CampaignDetailScreen({super.key, this.campaign, this.campaignId});

  final Campaign? campaign;
  final String? campaignId;

  @override
  State<CampaignDetailScreen> createState() => _CampaignDetailScreenState();
}

class _CampaignDetailScreenState extends State<CampaignDetailScreen> {
  final CampaignService _service = CampaignService();
  Campaign? _campaign;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _campaign = widget.campaign;
    _load();
  }

  Future<void> _load() async {
    if (widget.campaignId == null && widget.campaign == null) {
      setState(() {
        _loading = false;
        _error = 'No campaign selected';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    if (widget.campaign != null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final Campaign? loaded = await _service.fetchCampaign(widget.campaignId!);
      if (!mounted) return;
      setState(() {
        _campaign = loaded;
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

  void _openAnalytics() {
    if (_campaign == null) return;
    Navigator.of(context).push(
      ThemeSwitcher.buildPageRoute(
        builder: (_) => TitleBarWrapper(
          child: CampaignAnalyticsScreen(
            campaign: _campaign,
            campaignId: _campaign?.id ?? widget.campaignId,
          ),
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
            title: Text(_campaign?.name ?? 'Campaign'),
            actions: [
              IconButton(
                onPressed: _openAnalytics,
                icon: const Icon(Icons.insights_outlined),
              ),
            ],
          ),
          body: _buildBody(context),
        ),
        samsungSkin: const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(child: Text(_error!));
    }

    if (_campaign == null) {
      return const Center(child: Text('Campaign not found'));
    }

    final DateFormat format = DateFormat.yMMMd().add_jm();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _campaign!.name,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          if (_campaign!.subject != null)
            Text(
              _campaign!.subject!,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.secondary),
            ),
          const SizedBox(height: 12),
          if (_campaign!.description?.isNotEmpty == true)
            Text(_campaign!.description!),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildInfoChip('Status', _campaign!.status ?? 'unknown'),
              if (_campaign!.createdAt != null)
                _buildInfoChip('Created', format.format(_campaign!.createdAt!)),
              if (_campaign!.sentAt != null)
                _buildInfoChip('Sent', format.format(_campaign!.sentAt!)),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _openAnalytics,
            icon: const Icon(Icons.insights_outlined),
            label: const Text('View analytics'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, String value) {
    return Chip(
      label: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }
}
