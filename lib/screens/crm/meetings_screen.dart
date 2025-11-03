import 'dart:math';
import 'dart:ui' as ui;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:universal_html/html.dart' as html;
import 'package:url_launcher/url_launcher.dart';

import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/app/wrappers/titlebar_wrapper.dart';
import 'package:bluebubbles/models/crm/meeting.dart';
import 'package:bluebubbles/models/crm/member.dart';
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

  List<Meeting> _meetings = [];
  Meeting? _selectedMeeting;
  bool _loading = true;
  String? _error;

  static final Set<String> _registeredViewTypes = <String>{};

  @override
  void initState() {
    super.initState();
    _loadMeetings();
  }

  bool get _crmReady => _memberLookup.isReady;

  Future<void> _loadMeetings() async {
    if (!_crmReady) {
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

  @override
  Widget build(BuildContext context) {
    if (!_crmReady) {
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWide = constraints.maxWidth >= 960;
        final meetingList = _buildMeetingList(isWide: isWide);
        final detail = _selectedMeeting != null
            ? _buildMeetingDetail(_selectedMeeting!, constraints)
            : const Center(child: Text('Select a meeting to view details'));

        if (isWide) {
          return Row(
            children: [
              SizedBox(
                width: min(360, max(260.0, constraints.maxWidth * 0.32)),
                child: meetingList,
              ),
              const VerticalDivider(width: 1),
              Expanded(child: detail),
            ],
          );
        }

        return Column(
          children: [
            SizedBox(height: min(320, constraints.maxHeight * 0.45), child: meetingList),
            const Divider(height: 1),
            Expanded(child: detail),
          ],
        );
      },
    );
  }

  Widget _buildMeetingList({required bool isWide}) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.35),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        itemCount: _meetings.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final meeting = _meetings[index];
          final bool selected = meeting.id == _selectedMeeting?.id;
          final theme = Theme.of(context);
          final MaterialColor chipBase = meeting.processingStatus == 'completed'
              ? Colors.green
              : meeting.processingStatus == 'processing'
                  ? Colors.orange
                  : Colors.grey;
          final Color chipBackground = chipBase.shade100;
          final Color chipTextColor = chipBase.shade700;

          return Card(
            color: selected
                ? theme.colorScheme.primary.withOpacity(0.12)
                : theme.colorScheme.surface,
            child: ListTile(
              title: Text(meeting.meetingTitle),
              subtitle: Text('${meeting.formattedDate} • ${meeting.formattedTime}'),
              leading: CircleAvatar(
                child: Text('${index + 1}'),
              ),
              trailing: Chip(
                label: Text((meeting.processingStatus ?? 'unknown').toUpperCase()),
                backgroundColor: chipBackground,
                labelStyle: TextStyle(color: chipTextColor, fontWeight: FontWeight.w600),
              ),
              selected: selected,
              onTap: () {
                setState(() => _selectedMeeting = meeting);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildMeetingDetail(Meeting meeting, BoxConstraints constraints) {
    final theme = Theme.of(context);
    final content = <Widget>[
      Card(
        child: ListTile(
          title: Text(meeting.meetingTitle, style: theme.textTheme.titleLarge),
          subtitle: Text('${meeting.formattedDate} • ${meeting.formattedTime}'),
          trailing: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(meeting.processingStatus?.toUpperCase() ?? 'STATUS', style: theme.textTheme.labelSmall),
              if (meeting.attendanceCount != null)
                Text('${meeting.attendanceCount} attendees expected', style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
      if (meeting.recordingEmbedUrl != null || meeting.recordingUrl != null)
        _buildVideoEmbed(meeting),
      _buildMetadataChips(meeting),
      ..._buildTextSections(meeting),
      _buildAttendanceSection(meeting),
    ].whereType<Widget>().toList();

    return Container(
      color: theme.colorScheme.background,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: content.length,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: content[index],
        ),
      ),
    );
  }

  Widget _buildMetadataChips(Meeting meeting) {
    final chips = <Widget>[];
    chips.add(_buildInfoChip(Icons.schedule, '${meeting.formattedTime} CST'));
    if (meeting.durationMinutes != null && meeting.durationMinutes! > 0) {
      chips.add(_buildInfoChip(Icons.timer, '${meeting.durationMinutes} min'));
    }
    if (meeting.host != null) {
      chips.add(_buildInfoChip(Icons.person, 'Hosted by ${meeting.host!.name}'));
      _memberLookup.cacheMember(meeting.host!);
    }
    chips.add(_buildInfoChip(Icons.groups, '${meeting.attendance.length} participants'));
    if (meeting.zoomMeetingId != null && meeting.zoomMeetingId!.isNotEmpty) {
      chips.add(_buildInfoChip(Icons.videocam, 'Zoom ID ${meeting.zoomMeetingId}'));
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips,
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
    );
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
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.key, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SelectableText(value.trim()),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildAttendanceSection(Meeting meeting) {
    final participants = meeting.attendance;
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Participants', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...participants.map((attendance) {
              final highlight = widget.highlightMemberId != null && widget.highlightMemberId == attendance.memberId;
              final subtitleParts = <String>[];
              if (attendance.totalDurationMinutes != null) {
                subtitleParts.add('${attendance.totalDurationMinutes} min');
              }
              if (attendance.numberOfJoins != null && attendance.numberOfJoins! > 1) {
                subtitleParts.add('${attendance.numberOfJoins} joins');
              }
              if (attendance.zoomEmail != null && attendance.zoomEmail!.isNotEmpty) {
                subtitleParts.add(attendance.zoomEmail!);
              }

              final subtitle = subtitleParts.isEmpty ? null : subtitleParts.join(' • ');

              final initials = attendance.participantName.isNotEmpty
                  ? attendance.participantName.substring(0, 1).toUpperCase()
                  : '?';

              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: highlight ? Theme.of(context).colorScheme.primary : null,
                  foregroundColor: highlight ? Theme.of(context).colorScheme.onPrimary : null,
                  child: Text(initials),
                ),
                title: Text(attendance.participantName),
                subtitle: subtitle != null ? Text(subtitle) : null,
                trailing: attendance.member != null
                    ? IconButton(
                        icon: const Icon(Icons.open_in_new),
                        tooltip: 'View member profile',
                        onPressed: () => _openMemberProfile(attendance.member!),
                      )
                    : null,
                onTap: attendance.member != null ? () => _openMemberProfile(attendance.member!) : null,
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoEmbed(Meeting meeting) {
    final resolvedUrl = _resolveEmbedUrl(meeting.recordingEmbedUrl, meeting.recordingUrl);
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

    final viewType = 'meeting-embed-${meeting.id}';
    if (!_registeredViewTypes.contains(viewType)) {
      // ignore: undefined_prefixed_name
      ui.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
        final element = html.IFrameElement()
          ..src = resolvedUrl
          ..style.border = '0'
          ..allowFullscreen = true
          ..allow = 'autoplay; encrypted-media; picture-in-picture; fullscreen';
        return element;
      });
      _registeredViewTypes.add(viewType);
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
            child: HtmlElementView(viewType: viewType),
          ),
        ],
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
}

String? _resolveEmbedUrl(String? embedUrl, String? fallbackUrl) {
  final primary = embedUrl?.trim();
  final fallback = fallbackUrl?.trim();
  final candidate = (primary != null && primary.isNotEmpty) ? primary : fallback;
  if (candidate == null || candidate.isEmpty) {
    return null;
  }

  final uri = Uri.tryParse(candidate);
  if (uri == null) {
    return null;
  }

  if (uri.host.contains('drive.google.com')) {
    final id = _extractDriveId(uri);
    if (id != null) {
      return 'https://drive.google.com/file/d/$id/preview';
    }
  }

  return uri.toString();
}

String? _extractDriveId(Uri uri) {
  final segments = uri.pathSegments.where((segment) => segment.isNotEmpty).toList();
  if (segments.length >= 3 && segments.first == 'file') {
    final dIndex = segments.indexOf('d');
    if (dIndex != -1 && segments.length > dIndex + 1) {
      final id = segments[dIndex + 1];
      if (id.isNotEmpty) {
        return id;
      }
    }
  }

  final queryId = uri.queryParameters['id'] ?? uri.queryParameters['fileId'];
  if (queryId != null && queryId.isNotEmpty) {
    return queryId;
  }

  return null;
}
