import 'package:bluebubbles/features/campaigns/screens/campaign_analytics_screen.dart';
import 'package:bluebubbles/features/campaigns/screens/campaign_create_screen.dart';
import 'package:bluebubbles/features/campaigns/screens/campaign_editor_screen.dart';
import 'package:bluebubbles/features/campaigns/screens/campaign_preview_screen.dart';
import 'package:bluebubbles/features/campaigns/widgets/campaign_brand.dart';
import 'package:bluebubbles/features/campaigns/widgets/campaign_card.dart';
import 'package:bluebubbles/models/crm/campaign.dart';
import 'package:bluebubbles/services/crm/campaign_service.dart';
import 'package:flutter/material.dart';

class CampaignsListScreen extends StatefulWidget {
  const CampaignsListScreen({super.key});

  @override
  State<CampaignsListScreen> createState() => _CampaignsListScreenState();
}

class _CampaignsListScreenState extends State<CampaignsListScreen> {
  final CampaignService _campaignService = CampaignService();
  final TextEditingController _searchController = TextEditingController();
  List<Campaign> _campaigns = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCampaigns();
  }

  Future<void> _loadCampaigns() async {
    setState(() => _loading = true);
    final campaigns = await _campaignService.fetchCampaigns(
      searchQuery: _searchController.text.trim(),
    );
    setState(() {
      _campaigns = campaigns;
      _loading = false;
    });
  }

  Future<void> _openCreateCampaign() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CampaignCreateScreen()),
    );
    if (created == true) {
      await _loadCampaigns();
    }
  }

  Future<void> _openCampaign(Campaign campaign) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CampaignEditorScreen(campaignId: campaign.id, initialCampaign: campaign),
      ),
    );
    if (updated == true) {
      await _loadCampaigns();
    }
  }

  void _openPreview(Campaign campaign) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CampaignPreviewScreen(campaign: campaign),
      ),
    );
  }

  void _openAnalytics(Campaign campaign) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CampaignAnalyticsScreen(campaign: campaign),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateCampaign,
        icon: const Icon(Icons.campaign_outlined),
        label: const Text('New campaign'),
        backgroundColor: CampaignBrand.unityBlue,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.campaign, color: CampaignBrand.unityBlue),
                  const SizedBox(width: 8),
                  Text(
                    'Campaigns',
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 260,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: 'Search campaigns',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.refresh_outlined),
                          onPressed: _loadCampaigns,
                        ),
                      ),
                      onSubmitted: (_) => _loadCampaigns(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _campaigns.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.mail_outline, size: 48, color: theme.colorScheme.outline),
                                const SizedBox(height: 8),
                                const Text('No campaigns yet. Start by creating one!'),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadCampaigns,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final crossAxisCount = constraints.maxWidth < 800 ? 1 : 2;
                                return GridView.builder(
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: crossAxisCount,
                                    childAspectRatio: 1.35,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                  ),
                                  itemCount: _campaigns.length,
                                  itemBuilder: (context, index) {
                                    final campaign = _campaigns[index];
                                    return CampaignCard(
                                      campaign: campaign,
                                      onOpen: () => _openCampaign(campaign),
                                      onPreview: () => _openPreview(campaign),
                                      onAnalytics: () => _openAnalytics(campaign),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
