import 'package:flutter/material.dart';

import '../models/campaign.dart';

class CampaignSummaryCard extends StatelessWidget {
  const CampaignSummaryCard({super.key, required this.campaign, this.onTap});

  final Campaign campaign;
  final VoidCallback? onTap;

  Color _statusColor(BuildContext context) {
    switch (campaign.status) {
      case CampaignStatus.completed:
        return Colors.green.shade700;
      case CampaignStatus.failed:
        return Theme.of(context).colorScheme.error;
      case CampaignStatus.sending:
      case CampaignStatus.processing:
        return Colors.blue.shade700;
      case CampaignStatus.scheduled:
        return Colors.orange.shade700;
      case CampaignStatus.draft:
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final analytics = campaign.analytics;
    final subtitle = analytics != null
        ? 'Recipients: ${analytics.totalRecipients} · Sent: ${analytics.sentCount} · Delivered: ${analytics.deliveredCount}'
        : 'Recipients pending';

    return Card(
      child: ListTile(
        onTap: onTap,
        title: Text(campaign.name),
        subtitle: Text(subtitle),
        trailing: Chip(
          label: Text(campaign.status.name),
          backgroundColor: _statusColor(context).withOpacity(0.15),
          labelStyle: TextStyle(color: _statusColor(context)),
        ),
      ),
    );
  }
}
