import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:bluebubbles/features/calendar/models/calendar_event.dart';

/// Card widget for displaying a calendar event
class CalendarEventCard extends StatelessWidget {
  final CalendarEvent event;
  final Color? accentColor;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onCancel;
  final bool compact;

  const CalendarEventCard({
    super.key,
    required this.event,
    this.accentColor,
    this.onTap,
    this.onEdit,
    this.onCancel,
    this.compact = false,
  });

  Color _getEventTypeColor(EventType type, ThemeData theme) {
    switch (type) {
      case EventType.committee:
        return Colors.blue;
      case EventType.executive:
        return Colors.purple;
      case EventType.social:
        return Colors.orange;
      case EventType.deadline:
        return Colors.red;
      case EventType.general:
        return accentColor ?? theme.colorScheme.primary;
    }
  }

  IconData _getEventTypeIcon(EventType type) {
    switch (type) {
      case EventType.committee:
        return Icons.groups;
      case EventType.executive:
        return Icons.star;
      case EventType.social:
        return Icons.celebration;
      case EventType.deadline:
        return Icons.flag;
      case EventType.general:
        return Icons.event;
    }
  }

  String _formatEventTime() {
    if (event.allDay) {
      return 'All Day';
    }

    final timeFormat = DateFormat('h:mm a');
    final start = timeFormat.format(event.startTime.toLocal());
    final end = timeFormat.format(event.endTime.toLocal());
    return '$start - $end';
  }

  String _formatEventDate() {
    final dateFormat = DateFormat('EEE, MMM d');
    return dateFormat.format(event.startTime.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _getEventTypeColor(event.eventType, theme);
    final icon = _getEventTypeIcon(event.eventType);

    if (compact) {
      return _buildCompactCard(context, theme, color, icon);
    }
    return _buildFullCard(context, theme, color, icon);
  }

  Widget _buildCompactCard(
    BuildContext context,
    ThemeData theme,
    Color color,
    IconData icon,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                event.title,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: color.withOpacity(0.9),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!event.allDay)
              Text(
                DateFormat('h:mm a').format(event.startTime.toLocal()),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color.withOpacity(0.7),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullCard(
    BuildContext context,
    ThemeData theme,
    Color color,
    IconData icon,
  ) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withOpacity(0.3)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Event type indicator
              Container(
                width: 4,
                height: 50,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),

              // Event icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 12),

              // Event details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatEventTime(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatEventDate(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    if (event.location != null && event.location!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              event.location!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (event.committeeName != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          event.committeeName!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Actions
              if (onEdit != null || onCancel != null)
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  onSelected: (value) {
                    if (value == 'edit' && onEdit != null) {
                      onEdit!();
                    } else if (value == 'cancel' && onCancel != null) {
                      onCancel!();
                    }
                  },
                  itemBuilder: (context) => [
                    if (onEdit != null)
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                    if (onCancel != null)
                      PopupMenuItem(
                        value: 'cancel',
                        child: Row(
                          children: [
                            Icon(Icons.cancel, size: 18, color: Colors.red),
                            const SizedBox(width: 8),
                            const Text('Cancel', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
