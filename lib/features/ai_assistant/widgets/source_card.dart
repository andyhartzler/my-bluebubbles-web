import 'package:flutter/material.dart';
import '../models/source_document.dart';

// Brand colors matching dashboard theme
const _unityBlue = Color(0xFF273351);
const _momentumBlue = Color(0xFF32A6DE);
const _sunriseGold = Color(0xFFFDB813);
const _actionRed = Color(0xFFE63946);
const _justicePurple = Color(0xFF6A1B9A);
const _grassrootsGreen = Color(0xFF43A047);

class SourceCard extends StatelessWidget {
  final SourceDocument source;

  const SourceCard({super.key, required this.source});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final (icon, color) = _getSourceIcon(source.sourceType, source.sourceTable);

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    source.title ?? 'Untitled',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _Chip(
                        label: source.sourceTable ?? source.sourceType,
                        color: color,
                      ),
                      if (source.similarity != null) ...[
                        const SizedBox(width: 8),
                        _Chip(
                          label: '${(source.similarity! * 100).toInt()}% match',
                          color: colorScheme.tertiary,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  (IconData, Color) _getSourceIcon(String type, String? table) {
    // First check table name for more specific icons
    switch (table) {
      case 'members':
        return (Icons.person, _momentumBlue);
      case 'chapters':
        return (Icons.groups, _grassrootsGreen);
      case 'subscribers':
        return (Icons.email, _sunriseGold);
      case 'donors':
        return (Icons.volunteer_activism, _actionRed);
      case 'donations':
        return (Icons.payments, _grassrootsGreen);
      case 'campaigns':
        return (Icons.campaign, _justicePurple);
      case 'events':
        return (Icons.event, _momentumBlue);
      case 'jobs':
        return (Icons.work, _unityBlue);
      case 'meetings':
        return (Icons.meeting_room, _momentumBlue);
      case 'legislation_tracked_bills':
        return (Icons.gavel, _unityBlue);
      case 'form_schemas':
        return (Icons.description, _sunriseGold);
      case 'slack_messages':
        return (Icons.chat, _justicePurple);
      case 'calendar_events':
        return (Icons.calendar_today, _actionRed);
    }

    // Fall back to type
    switch (type) {
      case 'database':
        return (Icons.storage, _momentumBlue);
      case 'storage_file':
        return (Icons.insert_drive_file, _sunriseGold);
      default:
        return (Icons.article, _unityBlue);
    }
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
