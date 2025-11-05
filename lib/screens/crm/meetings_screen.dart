import 'dart:math';
import 'dart:ui' as ui;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:universal_html/html.dart' as html;
import 'package:url_launcher/url_launcher.dart';

import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/app/wrappers/titlebar_wrapper.dart';
import 'package:bluebubbles/models/crm/meeting.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/screens/crm/editors/meeting_attendance_edit_sheet.dart';
import 'package:bluebubbles/screens/crm/editors/meeting_edit_sheet.dart';
import 'package:bluebubbles/screens/crm/editors/non_member_attendee_edit_sheet.dart';
import 'package:bluebubbles/screens/crm/member_detail_screen.dart';
import 'package:bluebubbles/services/crm/meeting_repository.dart';
import 'package:bluebubbles/services/crm/member_lookup_service.dart';

class MeetingsScreen extends StatefulWidget {
  final String? initialMeetingId;
  final String? highlightMemberId;

  const MeetingsScreen({
    Key? key,
    this.initialMeetingId,
    this.highlightMemberId,
  }) : super(key: key);

  @override
  State<MeetingsScreen> createState() => _MeetingsScreenState();
}

class _MeetingsScreenState extends State<MeetingsScreen> {
  final MeetingRepository _meetingRepository = MeetingRepository();
  final CRMMemberLookupService _memberLookup = CRMMemberLookupService();
  final ScrollController _meetingListController = ScrollController();

  List<Meeting> _meetings = [];
  Meeting? _selectedMeeting;
  bool _loading = true;
  String? _error;

  bool get _isCrmReady => _memberLookup.isReady;

  @override
  void initState() {
    super.initState();
    _loadMeetings();
  }

  @override
  void dispose() {
    _meetingListController.dispose();
    super.dispose();
  }

  Future<void> _loadMeetings() async {
    if (!_isCrmReady) {
      setState(() {
        _loading = false;
        _error = 'CRM Supabase is not configured.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final meetings = await _meetingRepository.getMeetings(includeAttendance: true);
      for (final meeting in meetings) {
        for (final attendance in meeting.attendance) {
          final member = attendance.member;
          if (member != null) {
            _memberLookup.cacheMember(member);
          }
        }
        final host = meeting.host;
        if (host != null) {
          _memberLookup.cacheMember(host);
        }
      }

      Meeting? selected = meetings.firstWhereOrNull((m) => m.id == widget.initialMeetingId);
      selected ??= meetings.firstOrNull;

      if (!mounted) return;
      setState(() {
        _meetings = meetings;
        _selectedMeeting = selected;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final friendly = e is FormatException
          ? 'The meeting data from Supabase could not be parsed: ${e.message}. Please verify the stored timestamps and IDs.'
          : 'Failed to load meetings: $e';
      setState(() {
        _error = friendly;
        _loading = false;
      });
    }
  }

  Future<void> _editMeeting(Meeting meeting) async {
    if (!_isCrmReady) return;

    final updated = await showModalBottomSheet<Meeting?>(
      context: context,
      isScrollControlled: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.9,
        child: MeetingEditSheet(meeting: meeting),
      ),
    );

    if (!mounted || updated == null) return;
    _applyUpdatedMeeting(updated);
  }

  Future<void> _editAttendance(MeetingAttendance attendance) async {
    if (!_isCrmReady) return;

    final updated = await showModalBottomSheet<MeetingAttendance?>(
      context: context,
      isScrollControlled: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.85,
        child: MeetingAttendanceEditSheet(attendance: attendance),
      ),
    );

    if (!mounted || updated == null) return;
    _applyUpdatedAttendance(updated);
  }

  Future<void> _editNonMember(Meeting meeting, NonMemberAttendee attendee) async {
    if (!_isCrmReady) return;

    final result = await showModalBottomSheet<NonMemberEditResult?>(
      context: context,
      isScrollControlled: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.85,
        child: NonMemberAttendeeEditSheet(meeting: meeting, attendee: attendee),
      ),
    );

    if (!mounted || result == null) return;
    _applyNonMemberResult(meeting, attendee.id, result);
  }

  void _applyUpdatedMeeting(Meeting meeting) {
    final meetings = List<Meeting>.from(_meetings);
    final index = meetings.indexWhere((element) => element.id == meeting.id);
    if (index != -1) {
      meetings[index] = meeting;
    } else {
      meetings.add(meeting);
    }
    meetings.sort((a, b) => b.meetingDate.compareTo(a.meetingDate));

    for (final attendance in meeting.attendance) {
      final member = attendance.member;
      if (member != null) {
        _memberLookup.cacheMember(member);
      }
    }
    final host = meeting.host;
    if (host != null) {
      _memberLookup.cacheMember(host);
    }

    setState(() {
      _meetings = meetings;
      _selectedMeeting = meeting;
    });
  }

  void _applyUpdatedAttendance(MeetingAttendance attendance) {
    final meetingId = attendance.meetingId ?? attendance.meeting?.id;
    if (meetingId == null) return;

    final meetings = List<Meeting>.from(_meetings);
    final meetingIndex = meetings.indexWhere((element) => element.id == meetingId);
    if (meetingIndex == -1) return;

    final meeting = meetings[meetingIndex];
    final updatedAttendance = meeting.attendance.toList();
    final attendanceIndex = updatedAttendance.indexWhere((element) => element.id == attendance.id);
    if (attendanceIndex != -1) {
      updatedAttendance[attendanceIndex] = attendance;
    } else {
      updatedAttendance.add(attendance);
    }

    final updatedMeeting = meeting.copyWith(attendance: updatedAttendance);
    meetings[meetingIndex] = updatedMeeting;

    if (attendance.member != null) {
      _memberLookup.cacheMember(attendance.member!);
    }

    setState(() {
      _meetings = meetings;
      if (_selectedMeeting?.id == updatedMeeting.id) {
        _selectedMeeting = updatedMeeting;
      }
    });
  }

  void _applyNonMemberResult(Meeting meeting, String attendeeId, NonMemberEditResult result) {
    final meetings = List<Meeting>.from(_meetings);
    final index = meetings.indexWhere((element) => element.id == meeting.id);
    if (index == -1) return;

    var target = meetings[index];
    final guests = target.nonMemberAttendees.toList();

    if (result.removed || result.convertedAttendance != null) {
      guests.removeWhere((guest) => guest.id == attendeeId);
    }
    if (result.attendee != null) {
      final guestIndex = guests.indexWhere((guest) => guest.id == attendeeId);
      if (guestIndex != -1) {
        guests[guestIndex] = result.attendee!;
      } else {
        guests.add(result.attendee!);
      }
    }

    target = target.copyWith(nonMemberAttendees: guests);

    if (result.convertedAttendance != null) {
      final converted = result.convertedAttendance!;
      if (converted.member != null) {
        _memberLookup.cacheMember(converted.member!);
      }
      final attendance = target.attendance.toList();
      final existing = attendance.indexWhere((item) => item.id == converted.id);
      if (existing != -1) {
        attendance[existing] = converted;
      } else {
        attendance.add(converted);
      }
      target = target.copyWith(attendance: attendance);
    }

    meetings[index] = target;

    setState(() {
      _meetings = meetings;
      if (_selectedMeeting?.id == target.id) {
        _selectedMeeting = target;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCrmReady) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text('CRM Supabase is not configured. Configure access to view meetings.'),
        ),
      );
    }

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                onPressed: _loadMeetings,
              ),
            ],
          ),
        ),
      );
    }

    if (_meetings.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text('No meetings have been recorded yet.'),
        ),
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/images/Blue-Gradient-Background.png',
                  fit: BoxFit.cover,
                  color: Colors.white.withOpacity(0.4),
                  colorBlendMode: BlendMode.srcATop,
                ),
              ),
              Positioned.fill(
                child: Container(color: Colors.white.withOpacity(0.82)),
              ),
            ],
          ),
        ),
        Positioned.fill(child: _buildContent()),
      ],
    );
  }

  Widget _buildContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWide = constraints.maxWidth >= 1080;
        final meetingList = _buildMeetingList();
        final detail = _selectedMeeting != null
            ? _buildMeetingDetail(_selectedMeeting!, constraints)
            : const Center(child: Text('Select a meeting to view details'));

        if (isWide) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: min(420, max(320.0, constraints.maxWidth * 0.32)),
                  child: meetingList,
                ),
                const SizedBox(width: 24),
                Expanded(child: detail),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          child: Column(
            children: [
              SizedBox(height: min(360, constraints.maxHeight * 0.45), child: meetingList),
              const SizedBox(height: 16),
              Expanded(child: detail),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMeetingList() {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              children: [
                const Icon(Icons.video_camera_front_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Meetings',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadMeetings,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              controller: _meetingListController,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              itemCount: _meetings.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final meeting = _meetings[index];
                final selected = meeting.id == _selectedMeeting?.id;
                return _buildMeetingCard(meeting, selected);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeetingCard(Meeting meeting, bool selected) {
    final theme = Theme.of(context);
    final gradient = selected
        ? const LinearGradient(colors: [Color(0xFF0052D4), Color(0xFF65C7F7)])
        : LinearGradient(colors: [theme.colorScheme.surface, theme.colorScheme.surface]);
    final status = meeting.processingStatus ?? 'unknown';
    final statusLabel = status.toUpperCase();
    final statusColor = switch (status) {
      'completed' => Colors.greenAccent.shade100,
      'processing' => Colors.orangeAccent.shade100,
      _ => Colors.blueGrey.shade100,
    };

    final thumbnail = meeting.resolvedRecordingThumbnailUrl;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          if (selected)
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => setState(() => _selectedMeeting = meeting),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 72,
                  width: 72,
                  child: thumbnail != null
                      ? FadeInImage.assetNetwork(
                          placeholder: 'assets/images/no-video-preview.png',
                          image: thumbnail,
                          fit: BoxFit.cover,
                          imageErrorBuilder: (_, __, ___) => _buildThumbnailFallback(),
                        )
                      : _buildThumbnailFallback(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meeting.meetingTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: selected ? Colors.white : theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${meeting.formattedDate} • ${meeting.formattedTime} CST',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: selected ? Colors.white70 : theme.hintColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(selected ? 0.9 : 0.7),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            statusLabel,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: selected ? Colors.black : theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                        if (meeting.host?.name != null)
                          _buildMiniChip(
                            icon: Icons.person_outline,
                            label: meeting.host!.name,
                            dark: selected,
                          ),
                        if (meeting.attendance.isNotEmpty)
                          _buildMiniChip(
                            icon: Icons.groups_outlined,
                            label: '${meeting.attendance.length + meeting.nonMemberAttendees.length} attendees',
                            dark: selected,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnailFallback() {
    return Container(
      color: Colors.white.withOpacity(0.12),
      child: const Icon(Icons.video_library_outlined, size: 36, color: Colors.white70),
    );
  }

  Widget _buildMiniChip({required IconData icon, required String label, bool dark = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: dark ? Colors.white.withOpacity(0.25) : Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: dark ? Colors.white : Colors.black54),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: dark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeetingDetail(Meeting meeting, BoxConstraints constraints) {
    final theme = Theme.of(context);
    final List<Widget> content = [];

    content
      ..add(_buildHeroCard(meeting))
      ..add(const SizedBox(height: 16))
      ..add(_buildMeetingStats(meeting))
      ..add(const SizedBox(height: 16));

    if (meeting.resolvedRecordingEmbedUrl != null || meeting.recordingUrl != null) {
      content.add(
        Builder(
          builder: (context) => _buildVideoEmbed(meeting),
        ),
      );
    }

    if (meeting.transcriptFilePath != null && meeting.transcriptFilePath!.isNotEmpty) {
      content.add(
        _buildLinkTile(
          icon: Icons.description_outlined,
          label: 'Transcript',
          value: meeting.transcriptFilePath!,
          onTap: () => _launchUrl(Uri.parse(meeting.transcriptFilePath!)),
        ),
      );
    }

    content.addAll(_buildTextSections(meeting));
    content.add(_buildParticipantsPreview(meeting));

    if (meeting.nonMemberAttendees.isNotEmpty) {
      content.add(_buildNonMemberPreview(meeting));
    }

    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          itemCount: content.length,
          itemBuilder: (context, index) => Padding(
            padding: const EdgeInsets.only(bottom: 20.0),
            child: content[index],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard(Meeting meeting) {
    final theme = Theme.of(context);
    final hostName = meeting.host?.name;
    final totalGuests = meeting.attendance.length + meeting.nonMemberAttendees.length;
    final thumbnail = meeting.resolvedRecordingThumbnailUrl;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(colors: [Color(0xFF0052D4), Color(0xFF65C7F7)]),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 24,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (thumbnail != null)
            Positioned.fill(
              child: FadeInImage.assetNetwork(
                placeholder: 'assets/images/no-video-preview.png',
                image: thumbnail,
                fit: BoxFit.cover,
                imageErrorBuilder: (_, __, ___) => Container(color: Colors.black12),
              ),
            ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black.withOpacity(0.55), Colors.black.withOpacity(0.3)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        meeting.meetingTitle,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (_isCrmReady)
                      ElevatedButton.icon(
                        onPressed: () => _editMeeting(meeting),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.18),
                          foregroundColor: Colors.white,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${meeting.formattedDate} • ${meeting.formattedTime} CST',
                  style: theme.textTheme.titleMedium?.copyWith(color: Colors.white.withOpacity(0.85)),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildHeroChip(Icons.groups, '$totalGuests participants'),
                    if (hostName != null) _buildHeroChip(Icons.person, 'Host: $hostName'),
                    if (meeting.zoomMeetingId != null && meeting.zoomMeetingId!.isNotEmpty)
                      _buildHeroChip(Icons.videocam, 'Zoom ${meeting.zoomMeetingId}'),
                    if (meeting.durationMinutes != null)
                      _buildHeroChip(Icons.timer, '${meeting.durationMinutes} minutes'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildMeetingStats(Meeting meeting) {
    final tiles = <Widget>[
      _buildStatTile(
        icon: Icons.play_circle_outline,
        label: meeting.recordingUrl != null ? 'Recording Ready' : 'No Recording',
        description: meeting.recordingUrl ?? 'Upload a recording to share it with the team.',
        onTap: meeting.recordingUrl != null
            ? () => launchUrl(Uri.parse(meeting.recordingUrl!), mode: LaunchMode.externalApplication)
            : null,
      ),
      _buildStatTile(
        icon: Icons.event_available,
        label: 'Agenda & Outcomes',
        description: 'Review agenda status, discussion highlights, decisions, and risks.',
        onTap: () => _scrollToTextSection(),
      ),
      _buildStatTile(
        icon: Icons.groups_outlined,
        label: '${meeting.attendance.length} Members',
        description: 'Tap to view the full roster of member attendees.',
        onTap: () => _showMemberParticipants(meeting),
      ),
      _buildStatTile(
        icon: Icons.person_add_alt,
        label: '${meeting.nonMemberAttendees.length} Guests',
        description: 'Identify guests and link them to CRM profiles.',
        onTap: meeting.nonMemberAttendees.isEmpty ? null : () => _showGuestParticipants(meeting),
      ),
    ];

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: tiles,
    );
  }

  Widget _buildStatTile({
    required IconData icon,
    required String label,
    required String description,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: onTap != null ? theme.colorScheme.primary.withOpacity(0.08) : theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.colorScheme.primary.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              label,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  void _scrollToTextSection() {
    // Placeholder for potential future scroll behavior.
  }

  Iterable<Widget> _buildTextSections(Meeting meeting) sync* {
    final sections = {
      'Executive Recap': meeting.executiveRecap,
      'Agenda Reviewed': meeting.agendaReviewed,
      'Discussion Highlights': meeting.discussionHighlights,
      'Decisions & Rationales': meeting.decisionsRationales,
      'Risks & Open Questions': meeting.risksOpenQuestions,
      'Action Items': meeting.actionItems,
    };

    for (final entry in sections.entries) {
      final value = entry.value;
      if (value == null || value.trim().isEmpty) continue;
      yield Card(
        elevation: 0,
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.35),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.key, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              MarkdownBody(
                data: value.trim(),
                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(p: Theme.of(context).textTheme.bodyMedium),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildParticipantsPreview(Meeting meeting) {
    final participants = meeting.attendance;
    final theme = Theme.of(context);

    if (participants.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: const [
              Icon(Icons.groups_outlined),
              SizedBox(width: 12),
              Expanded(child: Text('No attendance has been recorded for this meeting.')),
            ],
          ),
        ),
      );
    }

    final preview = participants.take(4).toList();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Member Participants', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _showMemberParticipants(meeting),
                  icon: const Icon(Icons.open_in_new),
                  label: Text('View all (${participants.length})'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...preview.map((participant) => _buildParticipantTile(meeting, participant)).toList(),
            if (participants.length > preview.length)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text('Plus ${participants.length - preview.length} more...', style: theme.textTheme.bodySmall),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantTile(Meeting meeting, MeetingAttendance attendance) {
    final highlight = widget.highlightMemberId != null && widget.highlightMemberId == attendance.memberId;
    final theme = Theme.of(context);
    final subtitleParts = <String>[];
    subtitleParts.add(attendance.durationSummary);
    final joinWindow = attendance.joinWindow;
    if (joinWindow != null) subtitleParts.add(joinWindow);
    if (attendance.zoomEmail != null && attendance.zoomEmail!.isNotEmpty) {
      subtitleParts.add(attendance.zoomEmail!);
    }

    return Card(
      color: highlight ? theme.colorScheme.primary.withOpacity(0.12) : null,
      elevation: highlight ? 2 : 0,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: highlight ? theme.colorScheme.primary : theme.colorScheme.primary.withOpacity(0.2),
          foregroundColor: highlight ? theme.colorScheme.onPrimary : theme.colorScheme.primary,
          child: Text(attendance.participantName.isNotEmpty
              ? attendance.participantName.substring(0, 1).toUpperCase()
              : '?'),
        ),
        title: Text(attendance.participantName),
        subtitle: Text(subtitleParts.join(' • ')),
        onTap: attendance.member != null ? () => _openMemberProfile(attendance.member!) : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (attendance.member != null)
              IconButton(
                tooltip: 'View member profile',
                icon: const Icon(Icons.person_search_outlined),
                onPressed: () => _openMemberProfile(attendance.member!),
              ),
            if (_isCrmReady)
              IconButton(
                tooltip: 'Edit attendance',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _editAttendance(attendance),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNonMemberPreview(Meeting meeting) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.secondary.withOpacity(0.15),
          foregroundColor: theme.colorScheme.secondary,
          child: Text('${meeting.nonMemberAttendees.length}'),
        ),
        title: const Text('Guest Participants'),
        subtitle: const Text('Tap to review non-member attendees and link them to profiles.'),
        trailing: const Icon(Icons.open_in_new),
        onTap: () => _showGuestParticipants(meeting),
      ),
    );
  }

  Widget _buildVideoEmbed(Meeting meeting) {
    final resolvedUrl = meeting.resolvedRecordingEmbedUrl ?? meeting.recordingUrl;
    if (resolvedUrl == null) {
      return const SizedBox.shrink();
    }

    final uri = Uri.tryParse(resolvedUrl);
    if (uri == null) {
      return const SizedBox.shrink();
    }

    if (!kIsWeb) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Recording', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('Open Recording'),
                onPressed: () => launchUrl(uri, mode: LaunchMode.externalApplication),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            color: Theme.of(context).colorScheme.surfaceVariant,
            padding: const EdgeInsets.all(12.0),
            child: Text('Recording', style: Theme.of(context).textTheme.titleMedium),
          ),
          SizedBox(
            height: 360,
            child: MeetingRecordingEmbed(uri: uri),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkTile({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        subtitle: Text(value),
        trailing: const Icon(Icons.open_in_new),
        onTap: onTap,
      ),
    );
  }

  Future<void> _showMemberParticipants(Meeting meeting) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.9,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                child: Row(
                  children: [
                    const Icon(Icons.groups_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Member Participants (${meeting.attendance.length})',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  itemCount: meeting.attendance.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final attendance = meeting.attendance[index];
                    return _buildParticipantTile(meeting, attendance);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showGuestParticipants(Meeting meeting) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.85,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                child: Row(
                  children: [
                    const Icon(Icons.person_add_alt),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Guest Participants (${meeting.nonMemberAttendees.length})',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  itemCount: meeting.nonMemberAttendees.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final attendee = meeting.nonMemberAttendees[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(child: Text(attendee.initials)),
                        title: Text(attendee.displayName),
                        subtitle: Text(
                          [
                            if (attendee.totalDurationMinutes != null)
                              '${attendee.totalDurationMinutes} min',
                            if (attendee.formattedJoinWindow != null)
                              attendee.formattedJoinWindow!,
                            if (attendee.email != null && attendee.email!.isNotEmpty)
                              attendee.email!,
                          ].join(' • '),
                        ),
                        trailing: const Icon(Icons.edit_outlined),
                        onTap: () {
                          Navigator.of(context).pop();
                          _editNonMember(meeting, attendee);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openMemberProfile(Member member) {
    _memberLookup.cacheMember(member);
    Navigator.of(context, rootNavigator: true).push(
      ThemeSwitcher.buildPageRoute(
        builder: (context) => TitleBarWrapper(child: MemberDetailScreen(member: member)),
      ),
    );
  }

  void _launchUrl(Uri uri) {
    launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class MeetingRecordingEmbed extends StatefulWidget {
  final Uri uri;

  const MeetingRecordingEmbed({
    super.key,
    required this.uri,
  });

  @override
  State<MeetingRecordingEmbed> createState() => _MeetingRecordingEmbedState();
}

class _MeetingRecordingEmbedState extends State<MeetingRecordingEmbed> {
  static const String _viewType = 'meetings-recording-view';
  static bool _registered = false;
  static final Map<int, html.IFrameElement> _iframes =
      <int, html.IFrameElement>{};

  int? _viewId;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _ensureRegistered();
    }
  }

  @override
  void didUpdateWidget(MeetingRecordingEmbed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.uri != oldWidget.uri) {
      _setSource();
    }
  }

  @override
  void dispose() {
    if (_viewId != null) {
      _iframes.remove(_viewId!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return const SizedBox.shrink();
    }

    return HtmlElementView(
      viewType: _viewType,
      onPlatformViewCreated: (int viewId) {
        _viewId = viewId;
        _setSource();
      },
    );
  }

  void _ensureRegistered() {
    if (_registered) return;

    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) {
        final element = html.IFrameElement()
          ..style.border = '0'
          ..allowFullscreen = true
          ..allow =
              'autoplay; encrypted-media; picture-in-picture; fullscreen';
        _iframes[viewId] = element;
        return element;
      },
    );

    _registered = true;
  }

  void _setSource() {
    if (!kIsWeb || _viewId == null) return;

    final element = _iframes[_viewId!];
    if (element != null) {
      element.src = widget.uri.toString();
    }
  }
}
