import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bluebubbles/features/committees/models/committee.dart';
import 'package:bluebubbles/features/committees/services/committee_repository.dart';
import 'package:bluebubbles/features/meetings/models/scheduled_meeting.dart';
import 'package:bluebubbles/features/meetings/services/zoom_meeting_service.dart';
import 'package:bluebubbles/features/meetings/widgets/notification_options_dialog.dart';
import 'package:bluebubbles/features/meetings/widgets/schedule_meeting_dialog.dart';
import 'package:bluebubbles/features/meetings/widgets/scheduled_meeting_card.dart';
import 'package:bluebubbles/models/crm/member.dart';

/// Widget that displays upcoming scheduled meetings for a committee
class UpcomingMeetingsWidget extends StatefulWidget {
  final Committee committee;
  final Color? accentColor;
  final VoidCallback? onNavigateToEmail;
  final VoidCallback? onNavigateToMessages;

  const UpcomingMeetingsWidget({
    super.key,
    required this.committee,
    this.accentColor,
    this.onNavigateToEmail,
    this.onNavigateToMessages,
  });

  @override
  State<UpcomingMeetingsWidget> createState() => _UpcomingMeetingsWidgetState();
}

class _UpcomingMeetingsWidgetState extends State<UpcomingMeetingsWidget> {
  final ZoomMeetingService _meetingService = ZoomMeetingService();
  final CommitteeRepository _committeeRepository = CommitteeRepository();

  List<ScheduledMeeting> _meetings = [];
  List<Member> _members = [];
  bool _loading = true;
  String? _error;

  String get _currentUserId =>
      Supabase.instance.client.auth.currentUser?.id ?? 'anonymous';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _meetingService.getUpcomingMeetings(committeeName: widget.committee.name),
        _committeeRepository.getMembersForCommittee(widget.committee.name),
      ]);

      if (!mounted) return;
      setState(() {
        _meetings = results[0] as List<ScheduledMeeting>;
        _members = results[1] as List<Member>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load meetings: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = widget.accentColor ?? widget.committee.primaryColor;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.videocam, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Upcoming Zoom Meetings',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _scheduleMeeting,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Schedule'),
                  style: FilledButton.styleFrom(
                    backgroundColor: color,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Content
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null)
              _buildError()
            else if (_meetings.isEmpty)
              _buildEmptyState()
            else
              _buildMeetingsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red.shade700),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final color = widget.accentColor ?? widget.committee.primaryColor;

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.event_available,
            size: 48,
            color: color.withOpacity(0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'No upcoming meetings scheduled',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Schedule a Zoom meeting for your committee',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeetingsList() {
    return Column(
      children: _meetings.map((meeting) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ScheduledMeetingCard(
            meeting: meeting,
            accentColor: widget.accentColor ?? widget.committee.primaryColor,
            onEdit: () => _editMeeting(meeting),
            onCancel: () => _cancelMeeting(meeting),
            onSendInvites: () => _sendInvites(meeting),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _scheduleMeeting() async {
    final meeting = await ScheduleMeetingDialog.show(
      context,
      // Note: committee.id is a string name, not a UUID, so we only use committeeName
      committeeName: widget.committee.name,
      createdBy: _currentUserId,
    );

    if (meeting != null && mounted) {
      // Show notification options dialog
      await NotificationOptionsDialog.show(
        context,
        meeting: meeting,
        members: _members,
        onNavigateToEmail: widget.onNavigateToEmail,
        onNavigateToMessages: widget.onNavigateToMessages,
      );

      // Reload meetings list
      _loadData();
    }
  }

  Future<void> _editMeeting(ScheduledMeeting meeting) async {
    final updatedMeeting = await ScheduleMeetingDialog.show(
      context,
      // Note: committee.id is a string name, not a UUID, so we only use committeeName
      committeeName: widget.committee.name,
      createdBy: _currentUserId,
      existingMeeting: meeting,
    );

    if (updatedMeeting != null && mounted) {
      // Optionally offer to resend invites
      final shouldResend = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Meeting Updated'),
          content: const Text(
            'Would you like to send updated invites to committee members?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Send Updates'),
            ),
          ],
        ),
      );

      if (shouldResend == true && mounted) {
        await NotificationOptionsDialog.show(
          context,
          meeting: updatedMeeting,
          members: _members,
          onNavigateToEmail: widget.onNavigateToEmail,
          onNavigateToMessages: widget.onNavigateToMessages,
        );
      }

      // Reload meetings list
      _loadData();
    }
  }

  Future<void> _cancelMeeting(ScheduledMeeting meeting) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Meeting'),
        content: Text(
          'Are you sure you want to cancel "${meeting.title}"?\n\n'
          'This will delete the meeting from Zoom.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep Meeting'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Cancel Meeting'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _meetingService.cancelMeeting(meeting);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Meeting cancelled')),
          );
        }

        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to cancel meeting: $e')),
          );
        }
      }
    }
  }

  Future<void> _sendInvites(ScheduledMeeting meeting) async {
    await NotificationOptionsDialog.show(
      context,
      meeting: meeting,
      members: _members,
      onNavigateToEmail: widget.onNavigateToEmail,
      onNavigateToMessages: widget.onNavigateToMessages,
    );

    // Reload to update notification status
    _loadData();
  }
}
