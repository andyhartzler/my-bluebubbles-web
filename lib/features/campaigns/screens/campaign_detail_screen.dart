import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../models/campaign.dart';
import '../models/campaign_recipient.dart';
import '../services/campaign_service.dart';

class CampaignDetailScreen extends StatelessWidget {
  const CampaignDetailScreen({super.key, this.campaignId});

  final String? campaignId;

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<CampaignService>(context, listen: false);
    final id = campaignId ?? Get.parameters['campaignId'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Campaign Details'),
      ),
      body: id == null
          ? const Center(child: Text('Campaign id was not provided.'))
          : FutureBuilder<({Campaign? campaign, List<CampaignRecipient> recipients})>(
              future: _loadCampaign(service, id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Failed to load campaign: ${snapshot.error}'),
                  );
                }
                final data = snapshot.data;
                final campaign = data?.campaign;
                final recipients = data?.recipients ?? const [];
                if (campaign == null) {
                  return const Center(child: Text('Campaign not found.'));
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      campaign.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    if (campaign.description?.isNotEmpty == true)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(campaign.description!),
                      ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(label: Text('Status: ${campaign.status.name}')),
                        if (campaign.scheduledFor != null)
                          Chip(
                            label: Text(
                              'Scheduled: ${campaign.scheduledFor}',
                            ),
                          ),
                        Chip(
                          label: Text(
                            'Recipients: ${campaign.analytics?.totalRecipients ?? recipients.length}',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Recipients',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (recipients.isEmpty)
                      const Text('No recipients have been queued yet.')
                    else
                      ...recipients.map(
                        (recipient) => ListTile(
                          leading: const Icon(Icons.person_outline),
                          title: Text(recipient.name ?? recipient.address),
                          subtitle: Text('${recipient.channel.name} · ${recipient.status.name}'),
                          trailing: recipient.errorMessage != null
                              ? Tooltip(
                                  message: recipient.errorMessage,
                                  child: const Icon(Icons.error_outline),
                                )
                              : null,
                        ),
                      ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => service.processCampaignSegment(
                        campaignId: campaign.id,
                        segment: {'campaign_id': campaign.id},
                      ),
                      icon: const Icon(Icons.segment),
                      label: const Text('Process Segment'),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: () => service.sendCampaign(campaign.id),
                      icon: const Icon(Icons.send),
                      label: const Text('Send Campaign'),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Future<({Campaign? campaign, List<CampaignRecipient> recipients})> _loadCampaign(
    CampaignService service,
    String id,
  ) async {
    final campaign = await service.fetchCampaignById(id);
    final recipients = await service.fetchRecipients(id);
    return (campaign: campaign, recipients: recipients);
  }
}
