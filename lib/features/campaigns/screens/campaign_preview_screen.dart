import 'package:bluebubbles/features/campaigns/widgets/campaign_brand.dart';
import 'package:bluebubbles/models/crm/campaign.dart';
import 'package:flutter/material.dart';

class CampaignPreviewScreen extends StatelessWidget {
  final Campaign campaign;
  final String? htmlOverride;

  const CampaignPreviewScreen({super.key, required this.campaign, this.htmlOverride});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = htmlOverride?.trim().isNotEmpty == true
        ? htmlOverride!
        : campaign.htmlContent ?? 'No content provided yet.';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Campaign preview'),
        backgroundColor: CampaignBrand.unityBlue,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                campaign.name,
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(campaign.subject, style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              Expanded(
                child: Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        content,
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    ),
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
