import 'package:flutter/material.dart';

import 'package:bluebubbles/models/crm/email_campaign.dart';

const _momentumBlue = Color(0xFF32A6DE);
const _actionRed = Color(0xFFE63946);
const _grassrootsGreen = Color(0xFF43A047);

class CampaignStatsGrid extends StatelessWidget {
  final EmailCampaign campaign;
  final Map<RecipientFilter, int> recipientCounts;
  final ValueChanged<RecipientFilter>? onStatTap;

  const CampaignStatsGrid({
    super.key,
    required this.campaign,
    required this.recipientCounts,
    this.onStatTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 700;
        final crossAxisCount = isCompact ? 2 : 4;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: isCompact ? 1.5 : 1.8,
          children: [
            _ClickableStatTile(
              label: 'Recipients',
              value: campaign.totalRecipients,
              icon: Icons.people_outline,
              color: Colors.blueGrey,
              onTap: onStatTap != null ? () => onStatTap!(RecipientFilter.all) : null,
            ),
            _ClickableStatTile(
              label: 'Delivered',
              value: campaign.totalDelivered,
              rate: campaign.totalRecipients > 0
                  ? (campaign.totalDelivered / campaign.totalRecipients) * 100
                  : null,
              icon: Icons.check_circle_outline,
              color: Colors.blue,
              onTap: onStatTap != null ? () => onStatTap!(RecipientFilter.delivered) : null,
            ),
            _ClickableStatTile(
              label: 'Opened',
              value: campaign.uniqueOpens,
              rate: campaign.displayOpenRate,
              icon: Icons.mark_email_read_outlined,
              color: _grassrootsGreen,
              onTap: onStatTap != null ? () => onStatTap!(RecipientFilter.opened) : null,
            ),
            _ClickableStatTile(
              label: 'Clicked',
              value: campaign.uniqueClicks,
              rate: campaign.displayClickRate,
              icon: Icons.touch_app_outlined,
              color: _momentumBlue,
              onTap: onStatTap != null ? () => onStatTap!(RecipientFilter.clicked) : null,
            ),
            _ClickableStatTile(
              label: 'Bounced',
              value: campaign.totalBounces,
              rate: campaign.totalRecipients > 0
                  ? (campaign.totalBounces / campaign.totalRecipients) * 100
                  : null,
              icon: Icons.error_outline,
              color: _actionRed,
              onTap: onStatTap != null ? () => onStatTap!(RecipientFilter.bounced) : null,
            ),
            _ClickableStatTile(
              label: 'Unsubscribed',
              value: campaign.totalUnsubscribes,
              icon: Icons.unsubscribe_outlined,
              color: Colors.orange,
              onTap: onStatTap != null ? () => onStatTap!(RecipientFilter.unsubscribed) : null,
            ),
            _ClickableStatTile(
              label: 'Complaints',
              value: campaign.totalComplaints,
              icon: Icons.report_outlined,
              color: Colors.deepOrange,
              onTap: onStatTap != null ? () => onStatTap!(RecipientFilter.complained) : null,
            ),
            _ClickableStatTile(
              label: 'Failed',
              value: campaign.totalFailed,
              icon: Icons.cancel_outlined,
              color: Colors.grey,
              onTap: onStatTap != null ? () => onStatTap!(RecipientFilter.failed) : null,
            ),
          ],
        );
      },
    );
  }
}

class _ClickableStatTile extends StatelessWidget {
  final String label;
  final int value;
  final double? rate;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _ClickableStatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.rate,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withOpacity(0.12),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  if (onTap != null) ...[
                    const Spacer(),
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$value',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (rate != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      '(${rate!.toStringAsFixed(1)}%)',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
