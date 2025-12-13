import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:bluebubbles/features/committees/services/pending_share_content.dart';
import 'package:bluebubbles/features/meetings/models/scheduled_meeting.dart';
import 'package:bluebubbles/models/crm/member.dart';

/// Result from the notification options dialog
class NotificationResult {
  final bool navigatedToEmail;
  final bool navigatedToMessages;
  final bool skipped;

  const NotificationResult({
    this.navigatedToEmail = false,
    this.navigatedToMessages = false,
    this.skipped = false,
  });
}

/// Dialog for selecting notification options after creating a meeting
class NotificationOptionsDialog extends StatelessWidget {
  final ScheduledMeeting meeting;
  final List<Member> members;
  final VoidCallback? onNavigateToEmail;
  final VoidCallback? onNavigateToMessages;

  const NotificationOptionsDialog({
    super.key,
    required this.meeting,
    required this.members,
    this.onNavigateToEmail,
    this.onNavigateToMessages,
  });

  /// Shows the dialog and returns the notification result
  static Future<NotificationResult?> show(
    BuildContext context, {
    required ScheduledMeeting meeting,
    required List<Member> members,
    VoidCallback? onNavigateToEmail,
    VoidCallback? onNavigateToMessages,
  }) {
    return showDialog<NotificationResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => NotificationOptionsDialog(
        meeting: meeting,
        members: members,
        onNavigateToEmail: onNavigateToEmail,
        onNavigateToMessages: onNavigateToMessages,
      ),
    );
  }

  int get _membersWithEmail =>
      members.where((m) => m.preferredEmail != null && m.preferredEmail!.isNotEmpty).length;

  int get _membersWithPhone =>
      members.where((m) => m.primaryPhone != null && m.primaryPhone!.isNotEmpty).length;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_circle,
                      color: Colors.green.shade700,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Meeting Created!',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    meeting.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.green.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Meeting summary
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          _buildInfoRow(
                            Icons.calendar_today,
                            meeting.formattedDate,
                          ),
                          const SizedBox(height: 8),
                          _buildInfoRow(
                            Icons.access_time,
                            '${meeting.formattedTime} (${meeting.formattedDuration})',
                          ),
                        ],
                      ),
                    ),

                    // Zoom link section
                    if (meeting.zoomJoinUrl != null) ...[
                      const SizedBox(height: 16),
                      _buildZoomLinkSection(context),
                    ],

                    const SizedBox(height: 24),

                    // Share options title
                    Text(
                      'Share with committee members',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Choose how to invite members to this meeting.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Email option button
                    _buildShareOptionCard(
                      context,
                      icon: Icons.email_outlined,
                      iconColor: Colors.blue,
                      title: 'Send via Email',
                      subtitle: '$_membersWithEmail members with email addresses',
                      onTap: _membersWithEmail > 0 && onNavigateToEmail != null
                          ? () => _sendViaEmail(context)
                          : null,
                    ),

                    const SizedBox(height: 12),

                    // SMS option button
                    _buildShareOptionCard(
                      context,
                      icon: Icons.sms_outlined,
                      iconColor: Colors.green,
                      title: 'Send via SMS/Text',
                      subtitle: '$_membersWithPhone members with phone numbers',
                      onTap: _membersWithPhone > 0 && onNavigateToMessages != null
                          ? () => _sendViaMessage(context)
                          : null,
                    ),

                    // No members warning
                    if (members.isEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'No committee members to notify.',
                                style: TextStyle(color: Colors.orange.shade800),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: theme.dividerColor)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(
                      const NotificationResult(skipped: true),
                    ),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, {Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: color),
          ),
        ),
      ],
    );
  }

  Widget _buildZoomLinkSection(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.videocam, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Zoom Meeting Link',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    meeting.zoomJoinUrl!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.blue.shade800,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.copy, size: 18, color: Colors.blue.shade600),
                  onPressed: () => _copyZoomLink(context),
                  tooltip: 'Copy link',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          if (meeting.zoomPassword != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.lock_outline, size: 14, color: Colors.blue.shade600),
                const SizedBox(width: 4),
                Text(
                  'Password: ${meeting.zoomPassword}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.blue.shade600,
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _copyPassword(context),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Icon(Icons.copy, size: 14, color: Colors.blue.shade600),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildShareOptionCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final isEnabled = onTap != null;

    return Material(
      color: isEnabled ? iconColor.withOpacity(0.05) : Colors.grey.shade100,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isEnabled ? iconColor.withOpacity(0.3) : Colors.grey.shade300,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isEnabled ? iconColor.withOpacity(0.1) : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: isEnabled ? iconColor : Colors.grey,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isEnabled ? null : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isEnabled
                            ? theme.textTheme.bodySmall?.color?.withOpacity(0.7)
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              if (isEnabled)
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: iconColor,
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _copyZoomLink(BuildContext context) {
    if (meeting.zoomJoinUrl == null) return;

    Clipboard.setData(ClipboardData(text: meeting.zoomJoinUrl!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Zoom link copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _copyPassword(BuildContext context) {
    if (meeting.zoomPassword == null) return;

    Clipboard.setData(ClipboardData(text: meeting.zoomPassword!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Password copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _sendViaEmail(BuildContext context) {
    // Set pending email content
    PendingShareContent().setMeetingEmailContent(
      meetingTitle: meeting.title,
      meetingDate: meeting.formattedDate,
      meetingTime: meeting.formattedTime,
      meetingDuration: meeting.formattedDuration,
      zoomJoinUrl: meeting.zoomJoinUrl!,
      zoomPassword: meeting.zoomPassword,
      description: meeting.description,
    );

    // Close dialog and navigate to email tab
    Navigator.of(context).pop(const NotificationResult(navigatedToEmail: true));
    onNavigateToEmail?.call();
  }

  void _sendViaMessage(BuildContext context) {
    // Set pending message content
    PendingShareContent().setMeetingMessageContent(
      meetingTitle: meeting.title,
      meetingDate: meeting.formattedDate,
      meetingTime: meeting.formattedTime,
      zoomJoinUrl: meeting.zoomJoinUrl!,
      zoomPassword: meeting.zoomPassword,
    );

    // Close dialog and navigate to messages tab
    Navigator.of(context).pop(const NotificationResult(navigatedToMessages: true));
    onNavigateToMessages?.call();
  }
}
