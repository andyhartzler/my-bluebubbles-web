import 'package:bluebubbles/features/campaigns/widgets/campaign_brand.dart';
import 'package:bluebubbles/models/crm/campaign.dart';
import 'package:bluebubbles/models/crm/message_filter.dart';
import 'package:bluebubbles/services/crm/campaign_service.dart';
import 'package:flutter/material.dart';

class CampaignRecipientsScreen extends StatefulWidget {
  final MessageFilter filter;
  final String? campaignId;

  const CampaignRecipientsScreen({super.key, required this.filter, this.campaignId});

  @override
  State<CampaignRecipientsScreen> createState() => _CampaignRecipientsScreenState();
}

class _CampaignRecipientsScreenState extends State<CampaignRecipientsScreen> {
  final CampaignService _campaignService = CampaignService();
  List<CampaignRecipient> _recipients = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRecipients();
  }

  Future<void> _loadRecipients() async {
    setState(() => _loading = true);
    final recipients = await _campaignService.previewRecipients(widget.filter);
    if (!mounted) return;
    setState(() {
      _recipients = recipients;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: CampaignBrand.unityBlue,
        title: const Text('Recipients preview'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              itemCount: _recipients.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final recipient = _recipients[index];
                return ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(recipient.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (recipient.email != null) Text(recipient.email!),
                      if (recipient.phoneE164 != null) Text(recipient.phoneE164!),
                      if (recipient.county != null) Text(recipient.county!),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
