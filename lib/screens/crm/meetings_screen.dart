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
import 'package:bluebubbles/screens/crm/editors/member_search_sheet.dart';
import 'package:bluebubbles/screens/crm/member_detail_screen.dart';
import 'package:bluebubbles/screens/crm/editors/meeting_attendance_edit_sheet.dart';
import 'package:bluebubbles/screens/crm/editors/meeting_edit_sheet.dart';
import 'package:bluebubbles/services/crm/meeting_repository.dart';
import 'package:bluebubbles/services/crm/member_lookup_service.dart';
import 'package:bluebubbles/services/crm/storage_uri_resolver.dart';

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

const _unityBlue = Color(0xFF273351);
const _momentumBlue = Color(0xFF32A6DE);
const _sunriseGold = Color(0xFFFDB813);
const _actionRed = Color(0xFFE63946);
const _justicePurple = Color(0xFF6A1B9A);
const _grassrootsGreen = Color(0xFF43A047);

enum _DateRangeFilter { all, last30, last90, upcoming }

class _MeetingsScreenState extends State<MeetingsScreen> {
  final MeetingRepository _meetingRepository = MeetingRepository();
  final CRMMemberLookupService _memberLookup = CRMMemberLookupService();
  final ScrollController _meetingListController = ScrollController();

  List<Meeting> _meetings = [];
  Meeting? _selectedMeeting;
  bool _loading = true;
  String? _error;

  _DateRangeFilter _dateRangeFilter = _DateRangeFilter.all;
  String? _selectedHostFilter;
  String? _selectedChapterFilter;

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
        final filtered = _filterMeetings(meetings);
        _selectedMeeting = _ensureSelectedMeeting(selected, filtered);
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

  Future<void> _addMemberParticipant(Meeting meeting) async {
    if (!_isCrmReady) return;

    final member = await showMemberSearchSheet(context);
    if (member == null) return;

    try {
      final created = await _meetingRepository.upsertAttendance(
        meetingId: meeting.id,
        memberId: member.id,
        zoomDisplayName: member.name,
      );

      if (!mounted || created == null) return;
      _applyUpdatedAttendance(created);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Linked ${member.name} to ${meeting.meetingTitle}.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add participant: $e')),
      );
    }
  }

  Future<void> _deleteAttendance(MeetingAttendance attendance) async {
    if (!_isCrmReady) return;

    final meetingId = attendance.meetingId ?? attendance.meeting?.id;
    if (meetingId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Participant'),
        content: Text('Remove ${attendance.participantName} from this meeting?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _meetingRepository.deleteAttendance(attendance.id);
      if (!mounted) return;
      _removeAttendanceFromMeeting(meetingId, attendance.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${attendance.participantName} removed from ${attendance.meetingTitle ?? 'meeting'}.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove participant: $e')),
      );
    }
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
      final filtered = _filterMeetings(meetings);
      _selectedMeeting = _ensureSelectedMeeting(meeting, filtered);
    });
  }

  List<Meeting> _filterMeetings(List<Meeting> source) {
    final now = DateTime.now();
    final filtered = source.where((meeting) {
      switch (_dateRangeFilter) {
        case _DateRangeFilter.all:
          break;
        case _DateRangeFilter.last30:
          if (meeting.meetingDate.isBefore(now.subtract(const Duration(days: 30)))) {
            return false;
          }
          break;
        case _DateRangeFilter.last90:
          if (meeting.meetingDate.isBefore(now.subtract(const Duration(days: 90)))) {
            return false;
          }
          break;
        case _DateRangeFilter.upcoming:
          if (meeting.meetingDate.isBefore(now)) {
            return false;
          }
          break;
      }

      if (_selectedHostFilter != null && _selectedHostFilter!.isNotEmpty) {
        final hostName = meeting.host?.name;
        if (hostName == null || hostName != _selectedHostFilter) {
          return false;
        }
      }

      if (_selectedChapterFilter != null && _selectedChapterFilter!.isNotEmpty) {
        final chapterName = meeting.host?.chapterName;
        if (chapterName == null || chapterName != _selectedChapterFilter) {
          return false;
        }
      }

      return true;
    }).toList();

    filtered.sort((a, b) => b.meetingDate.compareTo(a.meetingDate));
    return filtered;
  }

  Meeting? _ensureSelectedMeeting(Meeting? candidate, List<Meeting> available) {
    if (available.isEmpty) return null;
    if (candidate != null) {
      final match = available.firstWhereOrNull((element) => element.id == candidate.id);
      if (match != null) return match;
    }
    return available.firstOrNull;
  }

  String _formatDateRangeLabel(_DateRangeFilter filter) {
    switch (filter) {
      case _DateRangeFilter.all:
        return 'Any time';
      case _DateRangeFilter.last30:
        return 'Last 30 days';
      case _DateRangeFilter.last90:
        return 'Last 90 days';
      case _DateRangeFilter.upcoming:
        return 'Upcoming';
    }
  }

  void _setDateRangeFilter(_DateRangeFilter value) {
    if (_dateRangeFilter == value) return;
    setState(() {
      _dateRangeFilter = value;
      final filtered = _filterMeetings(_meetings);
      _selectedMeeting = _ensureSelectedMeeting(_selectedMeeting, filtered);
    });
  }

  void _setHostFilter(String? value) {
    if (_selectedHostFilter == value) return;
    setState(() {
      _selectedHostFilter = value;
      final filtered = _filterMeetings(_meetings);
      _selectedMeeting = _ensureSelectedMeeting(_selectedMeeting, filtered);
    });
  }

  void _setChapterFilter(String? value) {
    if (_selectedChapterFilter == value) return;
    setState(() {
      _selectedChapterFilter = value;
      final filtered = _filterMeetings(_meetings);
      _selectedMeeting = _ensureSelectedMeeting(_selectedMeeting, filtered);
    });
  }

  void _onSelectMeeting(Meeting meeting) {
    if (_selectedMeeting?.id == meeting.id) return;
    setState(() {
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

    final updatedMeeting = meeting.copyWith(
      attendance: updatedAttendance,
      attendanceCount: updatedAttendance.length + meeting.nonMemberAttendees.length,
    );
    meetings[meetingIndex] = updatedMeeting;

    if (attendance.member != null) {
      _memberLookup.cacheMember(attendance.member!);
    }

    setState(() {
      _meetings = meetings;
      final candidate = _selectedMeeting?.id == updatedMeeting.id ? updatedMeeting : _selectedMeeting;
      final filtered = _filterMeetings(meetings);
      _selectedMeeting = _ensureSelectedMeeting(candidate, filtered);
    });
  }

  void _removeAttendanceFromMeeting(String meetingId, String attendanceId) {
    final meetings = List<Meeting>.from(_meetings);
    final meetingIndex = meetings.indexWhere((element) => element.id == meetingId);
    if (meetingIndex == -1) return;

    final meeting = meetings[meetingIndex];
    final updatedAttendance = meeting.attendance.where((entry) => entry.id != attendanceId).toList();

    final updatedMeeting = meeting.copyWith(
      attendance: updatedAttendance,
      attendanceCount: updatedAttendance.length + meeting.nonMemberAttendees.length,
    );
    meetings[meetingIndex] = updatedMeeting;

    setState(() {
      _meetings = meetings;
      final candidate = _selectedMeeting?.id == updatedMeeting.id ? updatedMeeting : _selectedMeeting;
      final filtered = _filterMeetings(meetings);
      _selectedMeeting = _ensureSelectedMeeting(candidate, filtered);
    });
  }

  void _applyNonMemberResult(Meeting meeting, String attendeeId, NonMemberEditResult result) {
    final meetings = List<Meeting>.from(_meetings);
    final index = meetings.indexWhere((element) => element.id == meeting.id);
    if (index == -1) return;

    var target = meetings[index];
    final guests = target.nonMemberAttendees.toList();
    var attendanceRecords = target.attendance.toList();

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

    if (result.convertedAttendance != null) {
      final converted = result.convertedAttendance!;
      if (converted.member != null) {
        _memberLookup.cacheMember(converted.member!);
      }
      final existing = attendanceRecords.indexWhere((item) => item.id == converted.id);
      if (existing != -1) {
        attendanceRecords[existing] = converted;
      } else {
        attendanceRecords.add(converted);
      }
    }

    target = target.copyWith(
      attendance: attendanceRecords,
      nonMemberAttendees: guests,
      attendanceCount: attendanceRecords.length + guests.length,
    );
    meetings[index] = target;

    setState(() {
      _meetings = meetings;
      final candidate = _selectedMeeting?.id == target.id ? target : _selectedMeeting;
      final filtered = _filterMeetings(meetings);
      _selectedMeeting = _ensureSelectedMeeting(candidate, filtered);
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
          child: Image.asset(
            'assets/images/Blue-Gradient-Background.png',
            fit: BoxFit.cover,
          ),
        ),
        Positioned.fill(
          child: Container(
            color: Colors.white.withOpacity(0.18),
          ),
        ),
        Positioned.fill(child: _buildContent()),
      ],
    );
  }

  Widget _buildContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final filteredMeetings = _filterMeetings(_meetings);
        final isCompact = constraints.maxWidth < 720;
        final padding = EdgeInsets.fromLTRB(
          isCompact ? 12 : 32,
          24,
          isCompact ? 12 : 32,
          isCompact ? 16 : 32,
        );

        final detail = _selectedMeeting != null
            ? _buildMeetingDetail(_selectedMeeting!, constraints)
            : _buildDetailPlaceholder();

        return Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildMeetingList(constraints, filteredMeetings),
              SizedBox(height: isCompact ? 16 : 24),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: detail,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailPlaceholder() {
    final theme = Theme.of(context);
    return Card(
      key: const ValueKey('meeting-detail-empty'),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text(
            'Select a meeting to view the full recap and attendee details.',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
        ),
      ),
    );
  }

  Widget _buildMeetingList(BoxConstraints constraints, List<Meeting> meetings) {
    final theme = Theme.of(context);
    final isCompact = constraints.maxWidth < 720;
    final listHeight = isCompact ? 156.0 : 192.0;
    final pillWidth = isCompact ? 240.0 : 320.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: _momentumBlue,
              ),
              padding: const EdgeInsets.all(10),
              child: const Icon(Icons.video_camera_front_outlined, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Meetings',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    meetings.isEmpty
                        ? 'No meetings match the current filters.'
                        : '${meetings.length} meeting${meetings.length == 1 ? '' : 's'} ready to review',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh),
              onPressed: _loadMeetings,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildFilterControls(isCompact),
        const SizedBox(height: 16),
        if (meetings.isEmpty)
          Container(
            height: listHeight,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: theme.colorScheme.outlineVariant ?? theme.dividerColor),
            ),
            child: Text(
              'Adjust your filters or refresh to see more meetings.',
              style: theme.textTheme.bodyMedium,
            ),
          )
        else
          SizedBox(
            height: listHeight,
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
              child: ListView.separated(
                controller: _meetingListController,
                scrollDirection: Axis.horizontal,
                itemCount: meetings.length,
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  final meeting = meetings[index];
                  final selected = meeting.id == _selectedMeeting?.id;
                  return _buildMeetingPill(meeting, selected, pillWidth, isCompact: isCompact);
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFilterControls(bool isCompact) {
    final hostNames = _meetings.map((m) => m.host?.name).whereType<String>().toSet().toList()..sort();
    final chapterNames = _meetings.map((m) => m.host?.chapterName).whereType<String>().toSet().toList()..sort();

    final filters = <Widget>[
      _buildFilterPill(
        icon: Icons.calendar_month_outlined,
        label: 'Date',
        child: DropdownButtonHideUnderline(
          child: DropdownButton<_DateRangeFilter>(
            value: _dateRangeFilter,
            onChanged: (value) {
              if (value != null) {
                _setDateRangeFilter(value);
              }
            },
            items: _DateRangeFilter.values
                .map(
                  (filter) => DropdownMenuItem(
                    value: filter,
                    child: Text(_formatDateRangeLabel(filter)),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    ];

    if (hostNames.isNotEmpty) {
      filters.add(
        _buildFilterPill(
          icon: Icons.person_outline,
          label: 'Host',
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: _selectedHostFilter,
              onChanged: _setHostFilter,
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('All hosts')),
                ...hostNames.map(
                  (host) => DropdownMenuItem<String?>(value: host, child: Text(host)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (chapterNames.isNotEmpty) {
      filters.add(
        _buildFilterPill(
          icon: Icons.flag_outlined,
          label: 'Chapter',
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: _selectedChapterFilter,
              onChanged: _setChapterFilter,
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('All chapters')),
                ...chapterNames.map(
                  (chapter) => DropdownMenuItem<String?>(value: chapter, child: Text(chapter)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final spacing = isCompact ? 8.0 : 12.0;

    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: filters,
    );
  }

  Widget _buildFilterPill({
    required IconData icon,
    required String label,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.6),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            '$label:',
            style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 120),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildMeetingPill(Meeting meeting, bool selected, double width, {required bool isCompact}) {
    final theme = Theme.of(context);
    final attendeeCount = meeting.attendance.length + meeting.nonMemberAttendees.length;
    final hostName = meeting.host?.name ?? 'Host TBD';
    final durationLabel = meeting.durationMinutes != null ? '${meeting.durationMinutes} min' : 'Duration TBD';

    final metaChips = [
      _buildMeetingMetaChip(Icons.schedule, durationLabel, selected),
      _buildMeetingMetaChip(Icons.person_outline, hostName, selected),
      _buildMeetingMetaChip(Icons.groups_outlined, '$attendeeCount attendees', selected),
    ];

    return SizedBox(
      width: width,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          color: selected ? _unityBlue : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: selected
                ? _momentumBlue
                : (theme.colorScheme.outlineVariant ?? theme.dividerColor),
            width: 1.4,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _unityBlue.withOpacity(0.32),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ]
              : [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(32),
            onTap: () => _onSelectMeeting(meeting),
            child: Padding(
              padding: EdgeInsets.all(isCompact ? 18 : 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    meeting.meetingTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: selected ? Colors.white : _unityBlue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${meeting.formattedDate} • ${meeting.formattedTime} CST',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: selected ? Colors.white70 : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: metaChips,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMeetingMetaChip(IconData icon, String label, bool selected) {
    final color = selected ? Colors.white : _unityBlue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? Colors.white.withOpacity(0.18) : _momentumBlue.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeetingDetail(Meeting meeting, BoxConstraints constraints) {
    final isCompact = constraints.maxWidth < 1000;
    final isMobile = constraints.maxWidth < 720;
    final narrativeSections = _buildTextSections(meeting, useAccordions: isMobile).toList();
    final resources = _buildResourceActions(meeting, isCompact: isCompact);
    final horizontalPadding = (isMobile ? 16.0 : 24.0) * 2;
    final contentWidth = max(240.0, constraints.maxWidth - horizontalPadding);

    final children = <Widget>[
      _buildSummaryHeader(meeting, isMobile: isMobile),
      const SizedBox(height: 24),
      _buildMeetingStats(
        meeting,
        isCompact: isCompact,
        availableWidth: contentWidth,
      ),
    ];

    if (resources != null) {
      children
        ..add(const SizedBox(height: 24))
        ..add(resources);
    }

    if (narrativeSections.isNotEmpty) {
      children
        ..add(const SizedBox(height: 24))
        ..addAll(_intersperseSections(narrativeSections));
    }

    children
      ..add(const SizedBox(height: 24))
      ..add(_buildParticipantsPreview(meeting, isCompact: isCompact))
      ..add(const SizedBox(height: 16))
      ..add(_buildNonMemberPreview(meeting, isCompact: isCompact));

    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          children: [
            _buildHeroCard(meeting),
            const SizedBox(height: 20),
            _buildMeetingStats(meeting),
            const SizedBox(height: 20),
            if (meeting.resolvedRecordingEmbedUrl != null || meeting.recordingUrl != null) ...[
              _buildVideoEmbed(meeting),
              const SizedBox(height: 20),
            ],
            if (meeting.transcriptFilePath != null && meeting.transcriptFilePath!.isNotEmpty) ...[
              _buildLinkTile(
                icon: Icons.description_outlined,
                label: 'Transcript',
                value: meeting.transcriptFilePath!,
                onTap: () {
                  _handleTranscriptTap(meeting.transcriptFilePath!);
                },
              ),
              const SizedBox(height: 20),
            ],
            ..._intersperseSections(narrativeSections),
            if (narrativeSections.isNotEmpty) const SizedBox(height: 20),
            _buildParticipantsPreview(meeting),
            if (meeting.nonMemberAttendees.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildNonMemberPreview(meeting),
            ],
          ],
        ),
      ),
    );
  }

  Iterable<Widget> _intersperseSections(Iterable<Widget> widgets) sync* {
    var first = true;
    for (final widget in widgets) {
      if (!first) {
        yield const SizedBox(height: 20);
      }
      yield widget;
      first = false;
    }
  }

  Widget _buildSummaryHeader(Meeting meeting, {required bool isMobile}) {
    final theme = Theme.of(context);
    final hostName = meeting.host?.name ?? 'Host TBD';
    final totalGuests = meeting.attendance.length + meeting.nonMemberAttendees.length;
    final durationLabel = meeting.durationMinutes != null ? '${meeting.durationMinutes} minutes' : 'Duration TBD';
    final statusLabel = (meeting.processingStatus ?? 'Pending').toUpperCase();

    final chips = [
      _buildSummaryChip(Icons.calendar_month_outlined, '${meeting.formattedDate} • ${meeting.formattedTime} CST'),
      _buildSummaryChip(Icons.timer_outlined, durationLabel),
      _buildSummaryChip(Icons.person_outline, 'Host: $hostName'),
      _buildSummaryChip(Icons.groups_outlined, '$totalGuests attendees'),
      _buildSummaryChip(Icons.auto_awesome, 'Status: $statusLabel'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: _unityBlue,
        borderRadius: BorderRadius.circular(isMobile ? 28 : 32),
      ),
      padding: EdgeInsets.fromLTRB(isMobile ? 20 : 28, 24, isMobile ? 20 : 28, 24),
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
                      meeting.meetingTitle,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      meeting.zoomMeetingId != null ? 'Zoom ID: ${meeting.zoomMeetingId}' : 'Zoom ID not linked',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              if (_isCrmReady)
                FilledButton.icon(
                  onPressed: () => _editMeeting(meeting),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.18),
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: chips,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryChip(IconData icon, String label) {
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
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildResourceActions(Meeting meeting, {required bool isCompact}) {
    final theme = Theme.of(context);
    final actions = <Widget>[];

    if (meeting.recordingUrl != null && meeting.recordingUrl!.isNotEmpty) {
      actions.add(
        _buildResourceButton(
          icon: Icons.play_circle_outline,
          label: 'Open recording',
          onPressed: () => _launchUrl(Uri.parse(meeting.recordingUrl!)),
          primary: true,
        ),
      );
    } else if (meeting.resolvedRecordingEmbedUrl != null) {
      actions.add(
        _buildResourceButton(
          icon: Icons.play_circle_outline,
          label: 'Open recording preview',
          onPressed: () => _launchUrl(Uri.parse(meeting.resolvedRecordingEmbedUrl!)),
          primary: true,
        ),
      );
    }

    if (meeting.transcriptFilePath != null && meeting.transcriptFilePath!.isNotEmpty) {
      actions.add(
        _buildResourceButton(
          icon: Icons.description_outlined,
          label: 'Open transcript',
          onPressed: () => _launchUrl(Uri.parse(meeting.transcriptFilePath!)),
        ),
      );
    }

    final hasEmbed = meeting.resolvedRecordingEmbedUrl != null || meeting.recordingUrl != null;
    final embedWidget = hasEmbed ? _buildVideoEmbed(meeting) : null;

    if (actions.isEmpty && embedWidget == null) {
      return null;
    }

    return Card(
      color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: EdgeInsets.all(isCompact ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resources',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: actions,
              ),
            ],
            if (embedWidget != null) ...[
              const SizedBox(height: 16),
              embedWidget,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResourceButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    bool primary = false,
  }) {
    final theme = Theme.of(context);
    final button = primary
        ? FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
            style: FilledButton.styleFrom(
              backgroundColor: _momentumBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
          )
        : OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.onSurface,
              side: BorderSide(color: theme.colorScheme.outlineVariant ?? theme.dividerColor),
              padding: const EdgeInsets.symmetric(horizontal: 18),
            ),
          );

    return SizedBox(height: 44, child: button);
  }

  Widget _buildMeetingStats(
    Meeting meeting, {
    required bool isCompact,
    required double availableWidth,
  }) {
    final tileWidth = isCompact ? availableWidth : min(260.0, availableWidth / 2);

    final stats = <Widget>[
      _buildStatTile(
        icon: Icons.play_circle_outline,
        label: meeting.recordingUrl != null || meeting.resolvedRecordingEmbedUrl != null
            ? 'Recording ready'
            : 'Add a recording',
        description: meeting.recordingUrl != null || meeting.resolvedRecordingEmbedUrl != null
            ? 'Launch the recording to rewatch highlights.'
            : 'Share the meeting recording so others can catch up.',
        width: tileWidth,
        accent: _momentumBlue,
        onTap: meeting.recordingUrl != null
            ? () => _launchUrl(Uri.parse(meeting.recordingUrl!))
            : (meeting.resolvedRecordingEmbedUrl != null
                ? () => _launchUrl(Uri.parse(meeting.resolvedRecordingEmbedUrl!))
                : null),
      ),
      _buildStatTile(
        icon: Icons.timer_outlined,
        label: meeting.durationMinutes != null
            ? '${meeting.durationMinutes} minute meeting'
            : 'Duration pending',
        description: 'Capture the total run time to benchmark future sessions.',
        width: tileWidth,
        accent: _sunriseGold,
      ),
      _buildStatTile(
        icon: Icons.groups_outlined,
        label: '${meeting.attendance.length} members',
        description: 'Open the roster of member attendees.',
        width: tileWidth,
        accent: _grassrootsGreen,
        onTap: meeting.attendance.isEmpty ? null : () => _showMemberParticipants(meeting),
      ),
      _buildStatTile(
        icon: Icons.person_add_alt,
        label: '${meeting.nonMemberAttendees.length} guests',
        description: 'Track prospective members and follow up quickly.',
        width: tileWidth,
        accent: _actionRed,
        onTap: meeting.nonMemberAttendees.isEmpty ? null : () => _showGuestParticipants(meeting),
      ),
      _buildStatTile(
        icon: Icons.description_outlined,
        label: meeting.transcriptFilePath != null && meeting.transcriptFilePath!.isNotEmpty
            ? 'Transcript available'
            : 'Transcript missing',
        description: meeting.transcriptFilePath != null && meeting.transcriptFilePath!.isNotEmpty
            ? 'Open the transcript to review the conversation.'
            : 'Upload a transcript to keep everyone aligned.',
        width: tileWidth,
        accent: _justicePurple,
        onTap: meeting.transcriptFilePath != null && meeting.transcriptFilePath!.isNotEmpty
            ? () => _launchUrl(Uri.parse(meeting.transcriptFilePath!))
            : null,
      ),
    ];

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: stats,
    );
  }

  Widget _buildStatTile({
    required IconData icon,
    required String label,
    required String description,
    required double width,
    Color? accent,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final accentColor = accent ?? theme.colorScheme.primary;
    final background = onTap != null
        ? accentColor.withOpacity(0.12)
        : theme.colorScheme.surfaceVariant.withOpacity(0.4);
    final borderColor = accentColor.withOpacity(onTap != null ? 0.45 : 0.25);

    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: accentColor),
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
        ),
      ),
    );
  }

  Iterable<Widget> _buildTextSections(Meeting meeting, {required bool useAccordions}) sync* {
    final theme = Theme.of(context);
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
      if (useAccordions) {
        yield Card(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              title: Text(entry.key, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                MarkdownBody(
                  data: value.trim(),
                  styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(p: theme.textTheme.bodyMedium),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      yield Card(
        elevation: 0,
        color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.key, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              MarkdownBody(
                data: value.trim(),
                styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(p: theme.textTheme.bodyMedium),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildParticipantsPreview(Meeting meeting, {required bool isCompact}) {
    final participants = meeting.attendance;
    final theme = Theme.of(context);

    if (participants.isEmpty) {
      return Card(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.25),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
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

    final preview = participants.take(isCompact ? 3 : 5).toList();

    return Card(
      color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Member Participants (${participants.length})',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _showMemberParticipants(meeting),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('View all'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...preview
                .map((participant) => Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: _buildParticipantTile(meeting, participant),
                    ))
                .toList(),
            if (participants.length > preview.length)
              Text(
                'Plus ${participants.length - preview.length} more...',
                style: theme.textTheme.bodySmall,
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
            if (_isCrmReady)
              IconButton(
                tooltip: 'Remove from meeting',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _deleteAttendance(attendance),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNonMemberPreview(Meeting meeting, {required bool isCompact}) {
    final theme = Theme.of(context);
    final guests = meeting.nonMemberAttendees;
    final preview = guests.take(isCompact ? 2 : 3).toList();

    return Card(
      color: theme.colorScheme.surfaceVariant.withOpacity(0.25),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Guest Participants (${guests.length})',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: guests.isEmpty ? null : () => _showGuestParticipants(meeting),
                  icon: const Icon(Icons.open_in_new),
                  label: Text(guests.isEmpty ? 'No guests' : 'View all'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (guests.isEmpty)
              Text(
                'Track visitors and prospective members to follow up later.',
                style: theme.textTheme.bodyMedium,
              )
            else
              ...preview.map((guest) {
                final subtitleParts = <String>[];
                if (guest.totalDurationMinutes != null) {
                  subtitleParts.add('${guest.totalDurationMinutes} min present');
                }
                if (guest.formattedJoinWindow != null) {
                  subtitleParts.add(guest.formattedJoinWindow!);
                }
                if (guest.email != null && guest.email!.isNotEmpty) {
                  subtitleParts.add(guest.email!);
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.secondary.withOpacity(0.2),
                      foregroundColor: theme.colorScheme.secondary,
                      child: Text(guest.initials),
                    ),
                    title: Text(guest.displayName),
                    subtitle: Text(subtitleParts.join(' • ')),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () {
                      _editNonMember(meeting, guest);
                    },
                  ),
                );
              }),
          ],
        ),
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

    return Builder(
      builder: (context) {
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
      },
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
              if (_isCrmReady)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: () => _addMemberParticipant(meeting),
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('Add member participant'),
                    ),
                  ),
                ),
              if (_isCrmReady) const SizedBox(height: 12),
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

  Future<void> _handleTranscriptTap(String rawPath) async {
    final resolved = await _resolveStorageUri(rawPath);
    if (!mounted) return;

    if (resolved == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open transcript link.')),
      );
      return;
    }

    await _launchUrl(resolved);
  }

  Future<Uri?> _resolveStorageUri(String path) {
    return CRMStorageUriResolver.resolve(path);
  }

  Future<void> _launchUrl(Uri? uri) async {
    if (!mounted) return;

    if (uri == null || uri.scheme.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid link.')),
      );
      return;
    }

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
        webOnlyWindowName: kIsWeb ? '_blank' : null,
      );

      if (!launched) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open ${uri.toString()}')),
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to launch link: $error')),
      );
    }
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
