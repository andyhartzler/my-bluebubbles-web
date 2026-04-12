import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:bluebubbles/models/crm/email_campaign.dart';

const _unityBlue = Color(0xFF273351);
const _momentumBlue = Color(0xFF32A6DE);
const _actionRed = Color(0xFFE63946);
const _grassrootsGreen = Color(0xFF43A047);

class CampaignCard extends StatelessWidget {
  final EmailCampaign campaign;
  final VoidCallback? onTap;

  static final DateFormat _dateFormat = DateFormat('MMM d, y');
  static final DateFormat _timeFormat = DateFormat('h:mm a');

  const CampaignCard({
    super.key,
    required this.campaign,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSent = campaign.isSent;
    final statusLabel = isSent ? 'Sent' : 'Draft';
    final statusColor = isSent ? _grassrootsGreen : Colors.orange;

    return Card(
      elevation: 2,
      color: _unityBlue,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          campaign.subject,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white70,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _StatusPill(label: statusLabel, color: statusColor),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (campaign.sentAt != null)
                    _InfoPill(
                      icon: Icons.schedule_outlined,
                      label: '${_dateFormat.format(campaign.sentAt!)} at ${_timeFormat.format(campaign.sentAt!)}',
                    ),
                  if (campaign.source.isNotEmpty)
                    _InfoPill(
                      icon: Icons.source_outlined,
                      label: _capitalizeFirst(campaign.source),
                    ),
                  if (campaign.audienceName != null)
                    _InfoPill(
                      icon: Icons.group_outlined,
                      label: campaign.audienceName!,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _buildStatsBar(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            label: 'Recipients',
            value: campaign.totalRecipients.toString(),
            icon: Icons.people_outline,
          ),
          _StatItem(
            label: 'Opens',
            value: '${campaign.displayOpenRate.toStringAsFixed(1)}%',
            subValue: '${campaign.uniqueOpens}',
            icon: Icons.mark_email_read_outlined,
            color: _grassrootsGreen,
          ),
          _StatItem(
            label: 'Clicks',
            value: '${campaign.displayClickRate.toStringAsFixed(1)}%',
            subValue: '${campaign.uniqueClicks}',
            icon: Icons.touch_app_outlined,
            color: _momentumBlue,
          ),
          _StatItem(
            label: 'Bounces',
            value: campaign.totalBounces.toString(),
            icon: Icons.error_outline,
            color: campaign.totalBounces > 0 ? _actionRed : null,
          ),
          _StatItem(
            label: 'Unsubs',
            value: campaign.totalUnsubscribes.toString(),
            icon: Icons.unsubscribe_outlined,
            color: campaign.totalUnsubscribes > 0 ? Colors.orange : null,
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final String? subValue;
  final IconData icon;
  final Color? color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    this.subValue,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final displayColor = color ?? Colors.white70;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: displayColor),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        if (subValue != null)
          Text(
            subValue!,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 10,
            ),
          ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

String _capitalizeFirst(String text) {
  if (text.isEmpty) return text;
  return text[0].toUpperCase() + text.substring(1).toLowerCase();
}
