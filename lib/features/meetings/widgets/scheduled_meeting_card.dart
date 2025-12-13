import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:bluebubbles/features/meetings/models/scheduled_meeting.dart';

/// Card widget for displaying a scheduled meeting
class ScheduledMeetingCard extends StatelessWidget {
  final ScheduledMeeting meeting;
  final VoidCallback? onEdit;
  final VoidCallback? onCancel;
  final VoidCallback? onSendInvites;
  final bool showActions;
  final Color? accentColor;

  const ScheduledMeetingCard({
    super.key,
    required this.meeting,
    this.onEdit,
    this.onCancel,
    this.onSendInvites,
    this.showActions = true,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = accentColor ?? theme.colorScheme.primary;
    final isCancelled = meeting.status == MeetingStatus.cancelled;

    return Card(
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      child: Opacity(
        opacity: isCancelled ? 0.6 : 1.0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Color accent bar
            Container(
              height: 4,
              color: isCancelled ? Colors.grey : color,
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and status
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          meeting.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            decoration: isCancelled
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                      if (isCancelled)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Cancelled',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (meeting.isToday && !isCancelled)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Today',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Date and time
                  _buildInfoRow(
                    context,
                    Icons.calendar_today,
                    meeting.formattedDate,
                  ),
                  const SizedBox(height: 6),
                  _buildInfoRow(
                    context,
                    Icons.access_time,
                    '${meeting.formattedTime} (${meeting.formattedDuration})',
                  ),

                  // Host info
                  if (meeting.hostName != null || meeting.hostEmail.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _buildInfoRow(
                      context,
                      Icons.person,
                      meeting.hostName ?? meeting.hostEmail,
                    ),
                  ],

                  // Zoom link
                  if (meeting.zoomJoinUrl != null && !isCancelled) ...[
                    const SizedBox(height: 12),
                    _buildZoomLink(context),
                  ],

                  // Description
                  if (meeting.description != null &&
                      meeting.description!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      meeting.description!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withOpacity(0.8),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  // Notification status
                  if (!isCancelled && (meeting.emailSent || meeting.smsSent)) ...[
                    const SizedBox(height: 12),
                    _buildNotificationStatus(context),
                  ],

                  // Actions
                  if (showActions && !isCancelled) ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    _buildActions(context),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String text) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  Widget _buildZoomLink(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => _openZoomLink(context),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.videocam, color: Colors.blue.shade700, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Join Zoom Meeting',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (meeting.zoomPassword != null)
                    Text(
                      'Password: ${meeting.zoomPassword}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.blue.shade600,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.copy, color: Colors.blue.shade600, size: 18),
              onPressed: () => _copyZoomLink(context),
              tooltip: 'Copy link',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationStatus(BuildContext context) {
    final theme = Theme.of(context);
    final items = <Widget>[];

    if (meeting.emailSent) {
      items.add(
        Chip(
          avatar: Icon(Icons.email, size: 14, color: Colors.green.shade700),
          label: Text(
            'Email sent',
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.green.shade700,
            ),
          ),
          backgroundColor: Colors.green.shade50,
          side: BorderSide.none,
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
      );
    }

    if (meeting.smsSent) {
      items.add(
        Chip(
          avatar: Icon(Icons.sms, size: 14, color: Colors.green.shade700),
          label: Text(
            'SMS sent',
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.green.shade700,
            ),
          ),
          backgroundColor: Colors.green.shade50,
          side: BorderSide.none,
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: items,
    );
  }

  Widget _buildActions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (onSendInvites != null)
          TextButton.icon(
            onPressed: onSendInvites,
            icon: const Icon(Icons.send, size: 18),
            label: Text(meeting.emailSent || meeting.smsSent
                ? 'Resend Invites'
                : 'Send Invites'),
          ),
        if (onEdit != null)
          TextButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit, size: 18),
            label: const Text('Edit'),
          ),
        if (onCancel != null)
          TextButton.icon(
            onPressed: onCancel,
            icon: Icon(Icons.cancel, size: 18, color: Colors.red.shade400),
            label: Text(
              'Cancel',
              style: TextStyle(color: Colors.red.shade400),
            ),
          ),
      ],
    );
  }

  Future<void> _openZoomLink(BuildContext context) async {
    if (meeting.zoomJoinUrl == null) return;

    final uri = Uri.parse(meeting.zoomJoinUrl!);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open Zoom link: $e')),
        );
      }
    }
  }

  void _copyZoomLink(BuildContext context) {
    if (meeting.zoomJoinUrl == null) return;

    var text = meeting.zoomJoinUrl!;
    if (meeting.zoomPassword != null) {
      text += '\nPassword: ${meeting.zoomPassword}';
    }

    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Zoom link copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
