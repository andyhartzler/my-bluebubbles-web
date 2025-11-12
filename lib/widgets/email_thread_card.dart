import 'package:bluebubbles/models/crm/email_thread.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EmailThreadCard extends StatelessWidget {
  const EmailThreadCard({
    super.key,
    required this.thread,
    this.onTap,
    this.onLongPress,
  });

  final EmailThread thread;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  static final DateFormat _timestampFormat =
      DateFormat.yMMMd().add_jm();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final unread = thread.unreadCount > 0;
    final updatedLabel =
        _timestampFormat.format(thread.updatedAt.toLocal());
    final participantsLabel =
        formatParticipants(thread.uniqueParticipants);

    final backgroundColor = unread
        ? Color.alphaBlend(
            colorScheme.primary.withOpacity(0.08),
            colorScheme.surface,
          )
        : colorScheme.surface;

    return Card(
      elevation: unread ? 2 : 0,
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: unread
              ? colorScheme.primary.withOpacity(0.3)
              : colorScheme.outlineVariant,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      thread.subject.isEmpty
                          ? '(No subject)'
                          : thread.subject,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight:
                            unread ? FontWeight.w700 : FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Icon(
                        unread
                            ? Icons.mark_email_unread_outlined
                            : Icons.mail_outline,
                        size: 20,
                        color: unread
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        updatedLabel,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (participantsLabel.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  participantsLabel,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if ((thread.snippet ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  thread.snippet!.trim(),
                  style: textTheme.bodyMedium,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Chip(
                    label: Text(
                      '${thread.messages.length} message${thread.messages.length == 1 ? '' : 's'}',
                      style: textTheme.labelMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    backgroundColor: colorScheme.primaryContainer,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  const SizedBox(width: 8),
                  if (thread.unreadCount > 0)
                    Chip(
                      label: Text(
                        '${thread.unreadCount} unread',
                        style: textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSecondaryContainer,
                        ),
                      ),
                      backgroundColor: colorScheme.secondaryContainer,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  const Spacer(),
                  if (thread.isArchived)
                    Tooltip(
                      message: 'Archived thread',
                      child: Icon(
                        Icons.archive_outlined,
                        size: 18,
                        color: colorScheme.onSurfaceVariant,
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
