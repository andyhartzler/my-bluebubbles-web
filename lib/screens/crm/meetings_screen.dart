import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:url_launcher/url_launcher.dart';
import 'package:bluebubbles/helpers/mobile_selection_area.dart';

import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/app/wrappers/titlebar_wrapper.dart';
import 'package:bluebubbles/features/calendar/models/calendar_event.dart';
import 'package:bluebubbles/helpers/tz_location.dart';
import 'package:bluebubbles/models/crm/meeting.dart';
import 'package:bluebubbles/models/crm/meeting_agenda.dart';
import 'package:bluebubbles/screens/crm/meeting_detail_screen.dart';
import 'package:bluebubbles/services/crm/meeting_agenda_matcher.dart';
import 'package:bluebubbles/services/crm/meeting_agenda_repository.dart';
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

const _unityBlue = Color(0xFF273351);
const _momentumBlue = Color(0xFF32A6DE);

/// Meetings are held in Missouri, and agenda titles carry the Missouri date.
tz.TZDateTime _inCentral(DateTime time) => tz.TZDateTime.from(time, tzLocation('America/Chicago'));

DateTime _centralDay(DateTime time) {
  final central = _inCentral(time);
  return DateTime(central.year, central.month, central.day);
}

String _centralLabel(DateTime time) {
  final central = _inCentral(time);
  return '${DateFormat('EEE, MMM d, y • h:mm a').format(central)} ${central.timeZoneName}';
}

String _meetingKey(Meeting meeting) => 'meeting:${meeting.id}';
String _eventKey(CalendarEvent event) => 'event:${event.id}';

enum _DateRangeFilter { all, last30, last90 }

/// A load that may fail without taking the rest of the page down with it.
Future<(T?, Object?)> _settle<T>(Future<T> future) async {
  try {
    return (await future, null);
  } catch (error) {
    return (null, error);
  }
}

class _MeetingsScreenState extends State<MeetingsScreen> {
  final MeetingRepository _meetingRepository = MeetingRepository();
  final MeetingAgendaRepository _agendaRepository = MeetingAgendaRepository();
  final CRMMemberLookupService _memberLookup = CRMMemberLookupService();

  List<Meeting> _meetings = [];
  List<CalendarEvent> _upcoming = [];
  Map<String, MeetingAgenda> _agendaByKey = {};
  int _agendaCount = 0;
  bool _loading = true;
  String? _error;
  String? _upcomingError;
  String? _agendaError;

  _DateRangeFilter _dateRangeFilter = _DateRangeFilter.all;
  String? _selectedHostFilter;
  String? _selectedChapterFilter;

  bool get _isCrmReady => _memberLookup.isReady;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
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

    // Upcoming events and agendas load beside the recorded meetings. If either
    // fails, the page still shows the meetings and says what is missing.
    final upcomingFuture = _settle(_meetingRepository.getUpcomingCalendarMeetings());
    final agendasFuture = _settle(_agendaRepository.listAgendas());

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

      final (upcoming, upcomingError) = await upcomingFuture;
      final (agendas, agendaError) = await agendasFuture;

      final events = upcoming ?? const <CalendarEvent>[];
      final agendaList = agendas ?? const <MeetingAgenda>[];
      final targets = <AgendaMatchTarget>[
        for (final event in events)
          AgendaMatchTarget(key: _eventKey(event), title: event.title, centralDay: _centralDay(event.startTime)),
        for (final meeting in meetings)
          AgendaMatchTarget(
            key: _meetingKey(meeting),
            title: meeting.meetingTitle,
            centralDay: _centralDay(meeting.meetingDate),
          ),
      ];

      if (!mounted) return;
      setState(() {
        _meetings = meetings;
        _upcoming = events;
        _agendaByKey = matchAgendas(targets, agendaList);
        _agendaCount = agendaList.length;
        _upcomingError = upcomingError == null ? null : 'Upcoming meetings could not be loaded: $upcomingError';
        _agendaError = agendaError == null ? null : 'Agendas could not be loaded from Google Drive: $agendaError';
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

  void _openMeetingDetail(Meeting meeting) {
    Navigator.of(context).push(
      ThemeSwitcher.buildPageRoute(
        builder: (context) => TitleBarWrapper(
          child: MeetingDetailScreen(
            initialMeeting: meeting,
            highlightMemberId: widget.highlightMemberId,
          ),
        ),
      ),
    );
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That link could not be opened.')),
      );
    }
  }

  /// Recorded meetings that have already happened, newest first.
  List<Meeting> _filterMeetings(List<Meeting> source) {
    final now = DateTime.now();
    final filtered = source.where((meeting) {
      if (meeting.meetingDate.isAfter(now)) {
        return false;
      }
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

  String _formatDateRangeLabel(_DateRangeFilter filter) {
    switch (filter) {
      case _DateRangeFilter.all:
        return 'Any time';
      case _DateRangeFilter.last30:
        return 'Last 30 days';
      case _DateRangeFilter.last90:
        return 'Last 90 days';
    }
  }

  void _setDateRangeFilter(_DateRangeFilter value) {
    if (_dateRangeFilter == value) return;
    setState(() {
      _dateRangeFilter = value;
    });
  }

  void _setHostFilter(String? value) {
    if (_selectedHostFilter == value) return;
    setState(() {
      _selectedHostFilter = value;
    });
  }

  void _setChapterFilter(String? value) {
    if (_selectedChapterFilter == value) return;
    setState(() {
      _selectedChapterFilter = value;
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
                onPressed: _load,
              ),
            ],
          ),
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
        final pastMeetings = _filterMeetings(_meetings);
        final isCompact = constraints.maxWidth < 720;
        final sideBySide = constraints.maxWidth >= 960;
        final horizontalPadding = isCompact ? 12.0 : 32.0;
        final bottomPadding = isCompact ? 16.0 : 32.0;

        return MobileAwareSelectionArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(horizontalPadding, 24, horizontalPadding, 0),
                sliver: SliverToBoxAdapter(child: _buildHeader()),
              ),
              if (_agendaError != null)
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(horizontalPadding, 16, horizontalPadding, 0),
                  sliver: SliverToBoxAdapter(child: _buildNotice(_agendaError!)),
                ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(horizontalPadding, 24, horizontalPadding, 0),
                sliver: SliverToBoxAdapter(
                  child: _buildSectionTitle('Upcoming', Icons.event_outlined),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(horizontalPadding, 12, horizontalPadding, 0),
                sliver: _buildUpcomingSliver(sideBySide),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(horizontalPadding, 32, horizontalPadding, 0),
                sliver: SliverToBoxAdapter(
                  child: _buildSectionTitle('Past meetings', Icons.history),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(horizontalPadding, 12, horizontalPadding, 0),
                sliver: SliverToBoxAdapter(child: _buildFilterControls(isCompact)),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(horizontalPadding, 16, horizontalPadding, bottomPadding),
                sliver: _buildPastSliver(pastMeetings, sideBySide),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);
    final pastCount = _meetings.where((m) => !m.meetingDate.isAfter(DateTime.now())).length;
    final summary = [
      '${_upcoming.length} upcoming',
      '$pastCount recorded',
      if (_agendaError == null) '$_agendaCount agenda${_agendaCount == 1 ? '' : 's'} in Drive',
    ].join(' • ');

    return Row(
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
                summary,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh),
          onPressed: _load,
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _buildNotice(String message) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: theme.colorScheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(String message) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text(message, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
    );
  }

  Widget _buildRowList<T>(List<T> items, Widget Function(T item) buildRow) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index.isOdd) return const SizedBox(height: 16);
          return buildRow(items[index ~/ 2]);
        },
        childCount: items.isEmpty ? 0 : items.length * 2 - 1,
      ),
    );
  }

  Widget _buildUpcomingSliver(bool sideBySide) {
    if (_upcomingError != null) {
      return SliverToBoxAdapter(child: _buildNotice(_upcomingError!));
    }
    if (_upcoming.isEmpty) {
      return SliverToBoxAdapter(child: _buildEmpty('Nothing is on the calendar yet.'));
    }
    return _buildRowList<CalendarEvent>(
      _upcoming,
      (event) => _MeetingRow(
        sideBySide: sideBySide,
        meeting: _buildUpcomingPill(event),
        agenda: _AgendaPanel(
          key: ValueKey('agenda-${_eventKey(event)}'),
          agenda: _agendaByKey[_eventKey(event)],
          agendasUnavailable: _agendaError != null,
          repository: _agendaRepository,
          onOpen: _openLink,
        ),
      ),
    );
  }

  Widget _buildPastSliver(List<Meeting> meetings, bool sideBySide) {
    if (meetings.isEmpty) {
      return SliverToBoxAdapter(
        child: _buildEmpty(
          _meetings.isEmpty
              ? 'No meetings have been recorded yet.'
              : 'Adjust your filters or refresh to see more meetings.',
        ),
      );
    }
    return _buildRowList<Meeting>(
      meetings,
      (meeting) => _MeetingRow(
        sideBySide: sideBySide,
        meeting: _buildMeetingPill(meeting),
        agenda: _AgendaPanel(
          key: ValueKey('agenda-${_meetingKey(meeting)}'),
          agenda: _agendaByKey[_meetingKey(meeting)],
          agendasUnavailable: _agendaError != null,
          repository: _agendaRepository,
          onOpen: _openLink,
        ),
      ),
    );
  }

  String _countdownLabel(CalendarEvent event) {
    final now = DateTime.now();
    if (!now.isBefore(event.startTime)) return 'Happening now';
    final days = _centralDay(event.startTime).difference(_centralDay(now)).inDays;
    if (days <= 0) return 'Today';
    if (days == 1) return 'Tomorrow';
    return 'In $days days';
  }

  Widget _buildUpcomingPill(CalendarEvent event) {
    final theme = Theme.of(context);
    final when = event.isAllDay
        ? DateFormat('EEE, MMM d, y').format(_inCentral(event.startTime))
        : _centralLabel(event.startTime);
    final link = event.meetingLink;

    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      color: _momentumBlue,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              event.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              when,
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white.withOpacity(0.9)),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildInfoChip(Icons.schedule, _countdownLabel(event)),
                if (link != null && link.isNotEmpty)
                  InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => _openLink(link),
                    child: _buildInfoChip(Icons.videocam_outlined, 'Join link'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeetingPill(Meeting meeting) {
    final theme = Theme.of(context);
    final attendeeCount = meeting.attendance.length + meeting.nonMemberAttendees.length;
    final hostName = meeting.host?.name ?? 'Host TBD';
    final durationLabel = meeting.durationMinutes != null ? '${meeting.durationMinutes} min' : 'Duration TBD';

    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      color: _unityBlue,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _openMeetingDetail(meeting),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meeting.meetingTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _centralLabel(meeting.meetingDate),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _buildInfoChip(Icons.schedule, durationLabel),
                        _buildInfoChip(Icons.person_outline, hostName),
                        _buildInfoChip(Icons.groups_outlined, '$attendeeCount'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
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
}

/// A meeting card with its agenda beside it on wide screens, or under it on
/// narrow ones.
class _MeetingRow extends StatelessWidget {
  final bool sideBySide;
  final Widget meeting;
  final Widget agenda;

  const _MeetingRow({
    required this.sideBySide,
    required this.meeting,
    required this.agenda,
  });

  @override
  Widget build(BuildContext context) {
    if (!sideBySide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          meeting,
          const SizedBox(height: 8),
          agenda,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 5, child: meeting),
        const SizedBox(width: 16),
        Expanded(flex: 4, child: agenda),
      ],
    );
  }
}

/// The agenda for one meeting. Its text is fetched from Drive only when
/// someone opens it.
class _AgendaPanel extends StatefulWidget {
  final MeetingAgenda? agenda;
  final bool agendasUnavailable;
  final MeetingAgendaRepository repository;
  final Future<void> Function(String url) onOpen;

  const _AgendaPanel({
    super.key,
    required this.agenda,
    required this.agendasUnavailable,
    required this.repository,
    required this.onOpen,
  });

  @override
  State<_AgendaPanel> createState() => _AgendaPanelState();
}

class _AgendaPanelState extends State<_AgendaPanel> {
  bool _expanded = false;
  Future<String>? _text;

  void _toggle() {
    final agenda = widget.agenda;
    if (agenda == null) return;
    setState(() {
      _expanded = !_expanded;
      if (_expanded) {
        _text ??= widget.repository.agendaText(agenda.fileId);
      }
    });
  }

  void _retry() {
    final agenda = widget.agenda;
    if (agenda == null) return;
    setState(() {
      _text = widget.repository.agendaText(agenda.fileId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final agenda = widget.agenda;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: agenda == null ? _buildMissing(theme) : _buildAgenda(theme, agenda),
    );
  }

  Widget _buildMissing(ThemeData theme) {
    return Row(
      children: [
        Icon(Icons.description_outlined, size: 20, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            widget.agendasUnavailable ? 'Agenda unavailable right now.' : 'No agenda in Drive for this date (yet).',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  Widget _buildAgenda(ThemeData theme, MeetingAgenda agenda) {
    final modified = agenda.modifiedTime;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.description, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    agenda.title,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (modified != null)
                    Text(
                      'Updated ${DateFormat('MMM d, y').format(modified)}',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: _toggle,
              icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
              label: Text(_expanded ? 'Hide agenda' : 'Read agenda'),
            ),
            OutlinedButton.icon(
              onPressed: () => widget.onOpen(agenda.url.toString()),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Open in Google Docs'),
            ),
          ],
        ),
        if (_expanded) ...[
          const SizedBox(height: 12),
          FutureBuilder<String>(
            future: _text,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Row(
                  children: [
                    Expanded(
                      child: Text(
                        'The agenda could not be loaded: ${snapshot.error}',
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
                      ),
                    ),
                    TextButton(onPressed: _retry, child: const Text('Retry')),
                  ],
                );
              }
              final text = (snapshot.data ?? '').trim();
              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: SingleChildScrollView(
                  child: Text(
                    text.isEmpty ? 'This agenda is empty.' : text,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}
