import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../models/campaign.dart';
import '../services/campaign_service.dart';
import '../widgets/campaign_summary_card.dart';

class CampaignsScreen extends StatelessWidget {
  const CampaignsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final campaignService = Provider.of<CampaignService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Campaigns'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => Get.forceAppUpdate(),
          ),
        ],
      ),
      body: campaignService.isReady
          ? FutureBuilder<List<Campaign>>(
              future: campaignService.fetchCampaigns(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Failed to load campaigns: ${snapshot.error}'),
                  );
                }
                final campaigns = snapshot.data ?? const [];
                if (campaigns.isEmpty) {
                  return const Center(
                    child: Text('No campaigns found.'),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: campaigns.length,
                  itemBuilder: (context, index) {
                    final campaign = campaigns[index];
                    return CampaignSummaryCard(
                      campaign: campaign,
                      onTap: () {
                        Get.toNamed('/crm/campaigns/${campaign.id}');
                      },
                    );
                  },
                );
              },
            )
          : const Center(
              child: Text('Campaigns are unavailable until Supabase is configured.'),
            ),
    );
  }
}
