import 'package:flutter/material.dart';

import 'package:bluebubbles/features/meetings/models/scheduled_meeting.dart';
import 'package:bluebubbles/features/meetings/services/zoom_meeting_service.dart';
import 'package:bluebubbles/models/crm/member.dart';

/// Result from the notification options dialog
class NotificationResult {
  final bool emailSent;
  final bool smsSent;
  final bool skipped;

  const NotificationResult({
    this.emailSent = false,
    this.smsSent = false,
    this.skipped = false,
  });
}

/// Dialog for selecting notification options after creating a meeting
class NotificationOptionsDialog extends StatefulWidget {
  final ScheduledMeeting meeting;
  final List<Member> members;

  const NotificationOptionsDialog({
    super.key,
    required this.meeting,
    required this.members,
  });

  /// Shows the dialog and returns the notification result
  static Future<NotificationResult?> show(
    BuildContext context, {
    required ScheduledMeeting meeting,
    required List<Member> members,
  }) {
    return showDialog<NotificationResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => NotificationOptionsDialog(
        meeting: meeting,
        members: members,
      ),
    );
  }

  @override
  State<NotificationOptionsDialog> createState() => _NotificationOptionsDialogState();
}

class _NotificationOptionsDialogState extends State<NotificationOptionsDialog> {
  bool _sendEmail = true;
  bool _sendSms = false;
  bool _isLoading = false;
  String? _error;

  int get _membersWithEmail =>
      widget.members.where((m) => m.preferredEmail != null && m.preferredEmail!.isNotEmpty).length;

  int get _membersWithPhone =>
      widget.members.where((m) => m.primaryPhone != null && m.primaryPhone!.isNotEmpty).length;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 450),
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
                    widget.meeting.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.green.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // Content
            Padding(
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
                          widget.meeting.formattedDate,
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          Icons.access_time,
                          '${widget.meeting.formattedTime} (${widget.meeting.formattedDuration})',
                        ),
                        if (widget.meeting.zoomJoinUrl != null) ...[
                          const SizedBox(height: 8),
                          _buildInfoRow(
                            Icons.videocam,
                            'Zoom meeting created',
                            color: Colors.blue,
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Notification options
                  Text(
                    'Send meeting invites to committee members?',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Invites will include the Zoom link and a calendar attachment.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Email checkbox
                  CheckboxListTile(
                    value: _sendEmail,
                    onChanged: _isLoading
                        ? null
                        : (value) => setState(() => _sendEmail = value ?? false),
                    title: const Text('Send via Email'),
                    subtitle: Text(
                      '$_membersWithEmail members with email addresses',
                      style: theme.textTheme.bodySmall,
                    ),
                    secondary: const Icon(Icons.email_outlined),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    enabled: !_isLoading && _membersWithEmail > 0,
                  ),

                  // SMS checkbox
                  CheckboxListTile(
                    value: _sendSms,
                    onChanged: _isLoading
                        ? null
                        : (value) => setState(() => _sendSms = value ?? false),
                    title: const Text('Send via SMS/Text'),
                    subtitle: Text(
                      '$_membersWithPhone members with phone numbers',
                      style: theme.textTheme.bodySmall,
                    ),
                    secondary: const Icon(Icons.sms_outlined),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    enabled: !_isLoading && _membersWithPhone > 0,
                  ),

                  // Summary
                  if (widget.members.isEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 12),
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

                  // Error message
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: theme.colorScheme.onErrorContainer,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: TextStyle(color: theme.colorScheme.onErrorContainer),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: theme.dividerColor)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () => Navigator.of(context).pop(
                              const NotificationResult(skipped: true),
                            ),
                    child: const Text('Skip for Now'),
                  ),
                  FilledButton.icon(
                    onPressed: _isLoading || (!_sendEmail && !_sendSms)
                        ? null
                        : _sendNotifications,
                    icon: _isLoading
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.onPrimary,
                            ),
                          )
                        : const Icon(Icons.send),
                    label: Text(_isLoading ? 'Sending...' : 'Send Invites'),
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

  Future<void> _sendNotifications() async {
    if (!_sendEmail && !_sendSms) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final service = ZoomMeetingService();
      await service.sendMeetingInvites(
        meetingId: widget.meeting.id,
        members: widget.members,
        sendEmail: _sendEmail,
        sendSms: _sendSms,
      );

      if (mounted) {
        Navigator.of(context).pop(NotificationResult(
          emailSent: _sendEmail,
          smsSent: _sendSms,
        ));
      }
    } on ZoomMeetingException catch (e) {
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to send invites: $e';
        _isLoading = false;
      });
    }
  }
}
