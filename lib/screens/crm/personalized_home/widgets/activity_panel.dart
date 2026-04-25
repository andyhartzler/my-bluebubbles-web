import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:bluebubbles/models/crm/event.dart';
import 'package:bluebubbles/screens/crm/event_detail_screen.dart';
import 'package:bluebubbles/screens/crm/meeting_detail_screen.dart';
import 'package:bluebubbles/services/crm/home_meeting_history_service.dart';
import 'package:bluebubbles/services/crm/meeting_repository.dart';

import 'branded_panel.dart';

/// Replaces the old `MeetingHistoryPanel`. Two tabs:
///   - Meetings: past meetings the user attended OR hosted (deduped by id)
///   - Events:   events the user attended (via `event_attendees`)
/// "Hosted but not attended" is treated as "attended" — the host *is* a
/// participant, per Andrew's design call.
class ActivityPanel extends StatefulWidget {
  final String authUserId;
  final String memberId;

  const ActivityPanel({
    super.key,
    required this.authUserId,
    required this.memberId,
  });

  @override
  State<ActivityPanel> createState() => _ActivityPanelState();
}

class _ActivityPanelState extends State<ActivityPanel>
    with SingleTickerProviderStateMixin {
  final _service = HomeMeetingHistoryService();
  late final TabController _tabs;

  List<Map<String, dynamic>> _meetings = const [];
  List<Map<String, dynamic>> _events = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _service.fetchAttendedOrHosted(widget.memberId),
      _service.fetchAttendedEvents(widget.memberId),
    ]);
    if (!mounted) return;
    setState(() {
      _meetings = results[0];
      _events = results[1];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BrandedPanel(
      title: 'Activity',
      icon: Icons.history,
      headerAction: IconButton(
        onPressed: _load,
        tooltip: 'Refresh',
        icon: const Icon(Icons.refresh, color: Colors.white),
      ),
      tabBar: BrandedHeaderTabBar(
        controller: _tabs,
        onTap: (i) => _tabs.animateTo(i),
        tabs: [
          Tab(text: 'Meetings (${_meetings.length})'),
          Tab(text: 'Events (${_events.length})'),
        ],
      ),
      bodyHeight: 280,
      body: TabBarView(
        controller: _tabs,
        children: [
          _meetingList(),
          _eventList(),
        ],
      ),
    );
  }

  Widget _meetingList() {
    if (_loading && _meetings.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    if (_meetings.isEmpty) {
      return Center(
        child: Text(
          'No meetings yet',
          style: TextStyle(color: Colors.white.withOpacity(0.65)),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: _meetings.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, color: Colors.white.withOpacity(0.10)),
      itemBuilder: (context, i) {
        final m = _meetings[i];
        final title = (m['meeting_title'] as String?) ?? 'Meeting';
        final committee = m['committee']?.toString() ?? m['committee_id']?.toString();
        final timeLabel = _formatChicago(
          m['meeting_date']?.toString(),
          m['start_time']?.toString(),
        );
        return ListTile(
          dense: true,
          onTap: () => _openMeeting(m),
          leading: Icon(Icons.event_note,
              size: 20, color: Colors.white.withOpacity(0.85)),
          title: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            [
              if (timeLabel.isNotEmpty) timeLabel,
              if (committee != null && committee.isNotEmpty) committee,
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.white.withOpacity(0.78)),
          ),
          trailing: Icon(
            Icons.arrow_forward_ios,
            size: 14,
            color: Colors.white.withOpacity(0.6),
          ),
        );
      },
    );
  }

  Widget _eventList() {
    if (_loading && _events.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    if (_events.isEmpty) {
      return Center(
        child: Text(
          'No events attended yet',
          style: TextStyle(color: Colors.white.withOpacity(0.65)),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: _events.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, color: Colors.white.withOpacity(0.10)),
      itemBuilder: (context, i) {
        final e = _events[i];
        final name = (e['name'] as String?) ?? 'Event';
        final location = (e['location'] as String?) ??
            (e['address'] as String?) ??
            '';
        final timeLabel = _formatChicago(e['event_date']?.toString(), null);
        return ListTile(
          dense: true,
          onTap: () => _openEvent(e),
          leading: Icon(Icons.celebration_outlined,
              size: 20, color: Colors.white.withOpacity(0.85)),
          title: Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            [
              if (timeLabel.isNotEmpty) timeLabel,
              if (location.isNotEmpty) location,
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.white.withOpacity(0.78)),
          ),
          trailing: Icon(
            Icons.arrow_forward_ios,
            size: 14,
            color: Colors.white.withOpacity(0.6),
          ),
        );
      },
    );
  }

  Future<void> _openMeeting(Map<String, dynamic> m) async {
    final id = m['id']?.toString();
    if (id == null || id.isEmpty) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final meeting = await MeetingRepository().getMeetingById(id);
      if (!mounted) return;
      if (meeting == null) {
        messenger.showSnackBar(const SnackBar(content: Text('Meeting not found')));
        return;
      }
      navigator.push(MaterialPageRoute(
        builder: (_) => MeetingDetailScreen(initialMeeting: meeting),
      ));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Open failed: $e')));
    }
  }

  Future<void> _openEvent(Map<String, dynamic> raw) async {
    try {
      final ev = Event.fromJson(Map<String, dynamic>.from(raw));
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => EventDetailScreen(initialEvent: ev),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Open failed: $e')),
      );
    }
  }

  /// Format a date+time for display, always in America/Chicago.
  /// `date` can be a full ISO timestamp or a YYYY-MM-DD; `start` is an
  /// optional HH:MM[:SS] component when `date` is just a date.
  static String _formatChicago(String? date, String? start) {
    if (date == null || date.isEmpty) return '';
    final chicago = tz.getLocation('America/Chicago');
    DateTime? parsed;

    if (date.contains('T') || date.contains(' ')) {
      parsed = DateTime.tryParse(date);
    } else if (start != null && start.isNotEmpty) {
      final suffix = (start.contains('+') || start.contains('Z')) ? '' : 'Z';
      parsed = DateTime.tryParse('${date}T$start$suffix');
    } else {
      final dateOnly = DateTime.tryParse(date);
      if (dateOnly == null) return date;
      final chiDate = tz.TZDateTime.from(dateOnly.toUtc(), chicago);
      return DateFormat('EEE MMM d').format(chiDate);
    }

    if (parsed == null) return date;
    final chi = tz.TZDateTime.from(parsed, chicago);
    final dayLabel = DateFormat('EEE MMM d').format(chi);
    final timeLabel = DateFormat('h:mm a').format(chi);
    return '$dayLabel · $timeLabel ${chi.timeZoneName}';
  }
}
