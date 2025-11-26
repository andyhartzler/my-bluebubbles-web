import 'package:bluebubbles/features/campaigns/widgets/campaign_brand.dart';
import 'package:bluebubbles/features/campaigns/widgets/campaign_stats_widget.dart';
import 'package:bluebubbles/models/crm/campaign.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CampaignCard extends StatelessWidget {
  final Campaign campaign;
  final VoidCallback? onOpen;
  final VoidCallback? onPreview;
  final VoidCallback? onAnalytics;

  const CampaignCard({
    super.key,
    required this.campaign,
    this.onOpen,
    this.onPreview,
    this.onAnalytics,
  });

  Color _statusColor(BuildContext context) {
    switch (campaign.status) {
      case CampaignStatus.scheduled:
        return CampaignBrand.sunriseGold;
      case CampaignStatus.sending:
        return CampaignBrand.momentumBlue;
      case CampaignStatus.sent:
        return CampaignBrand.grassrootsGreen;
      case CampaignStatus.failed:
        return CampaignBrand.actionRed;
      case CampaignStatus.archived:
        return Theme.of(context).colorScheme.outline;
      case CampaignStatus.draft:
      default:
        return CampaignBrand.justicePurple;
    }
  }

  String _scheduledText() {
    if (campaign.scheduledAt == null) return 'No schedule set';
    return 'Scheduled ${DateFormat.yMd().add_jm().format(campaign.scheduledAt!)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _statusColor(context);

    return Container(
      decoration: BoxDecoration(
        gradient: CampaignBrand.primaryGradient(),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              campaign.name,
                              style: theme.textTheme.titleLarge
                                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              campaign.subject,
                              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      Chip(
                        label: Text(
                          campaign.statusLabel,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        backgroundColor: statusColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _scheduledText(),
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  CampaignStatsWidget(
                    sent: campaign.sentCount,
                    expected: campaign.expectedRecipients,
                    opened: campaign.openedCount,
                    clicked: campaign.clickedCount,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      OutlinedButton.icon(
                        onPressed: onPreview,
                        icon: const Icon(Icons.visibility_outlined, color: Colors.white),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                          backgroundColor: Colors.white.withOpacity(0.08),
                        ),
                        label: const Text('Preview'),
                      ),
                      OutlinedButton.icon(
                        onPressed: onAnalytics,
                        icon: const Icon(Icons.analytics_outlined, color: Colors.white),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                          backgroundColor: Colors.white.withOpacity(0.08),
                        ),
                        label: const Text('Analytics'),
                      ),
                      OutlinedButton.icon(
                        onPressed: onOpen,
                        icon: const Icon(Icons.edit_outlined, color: Colors.white),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                          backgroundColor: Colors.white.withOpacity(0.08),
                        ),
                        label: const Text('Edit'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
