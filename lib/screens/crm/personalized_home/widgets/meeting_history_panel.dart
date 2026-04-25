import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:bluebubbles/screens/crm/meeting_detail_screen.dart';
import 'package:bluebubbles/screens/crm/meetings_screen.dart';
import 'package:bluebubbles/services/crm/home_meeting_history_service.dart';
import 'package:bluebubbles/services/crm/meeting_repository.dart';

import 'branded_panel.dart';

/// Three-section meeting widget on the Personalized Home Screen:
/// upcoming (invited), recent (attended), and hosted.
class MeetingHistoryPanel extends StatefulWidget {
  final String authUserId;
  final String memberId;

  const MeetingHistoryPanel({
    super.key,
    required this.authUserId,
    required this.memberId,
  });

  @override
  State<MeetingHistoryPanel> createState() => _MeetingHistoryPanelState();
}

class _MeetingHistoryPanelState extends State<MeetingHistoryPanel>
    with SingleTickerProviderStateMixin {
  final _service = HomeMeetingHistoryService();
  late final TabController _tabs;

  List<Map<String, dynamic>> _upcoming = const [];
  List<Map<String, dynamic>> _attended = const [];
  List<Map<String, dynamic>> _hosted = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
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
      _service.fetchUpcomingInvited(widget.memberId),
      _service.fetchPastAttended(widget.memberId),
      _service.fetchHosted(memberId: widget.memberId, authUserId: widget.authUserId),
    ]);
    if (!mounted) return;
    setState(() {
      _upcoming = results[0];
      _attended = results[1];
      _hosted = results[2];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BrandedPanel(
      title: 'Meetings',
      icon: Icons.calendar_today,
      headerAction: IconButton(
        onPressed: _load,
        tooltip: 'Refresh',
        icon: const Icon(Icons.refresh, color: Colors.white),
      ),
      tabBar: BrandedHeaderTabBar(
        controller: _tabs,
        onTap: (i) => _tabs.animateTo(i),
        tabs: [
          Tab(text: 'Upcoming (${_upcoming.length})'),
          Tab(text: 'Recent (${_attended.length})'),
          Tab(text: 'Hosted (${_hosted.length})'),
        ],
      ),
      bodyHeight: 280,
      body: TabBarView(
        controller: _tabs,
        children: [
          _list(_upcoming, _loading, isUpcoming: true, kind: 'scheduled'),
          _list(_attended, _loading, isUpcoming: false, kind: 'past'),
          _list(_hosted, _loading, isUpcoming: false, kind: 'mixed'),
        ],
      ),
    );
  }

  /// Open the right detail surface for a meeting row.
  /// - `past` and the past-hosted half of `mixed` → fetch a `Meeting` by
  ///   id and push `MeetingDetailScreen`.
  /// - `scheduled` (and the upcoming-hosted half of `mixed`) → push the
  ///   global `MeetingsScreen` since there's no scheduled-meeting detail
  ///   view yet. The user lands on the same data source they just clicked
  ///   from, with the broader context available.
  Future<void> _openMeeting(Map<String, dynamic> m, String kind) async {
    final id = m['id']?.toString();
    if (id == null || id.isEmpty) return;

    // Detect mixed-tab source so we route past-hosted to detail and
    // upcoming-hosted to the meetings list.
    final source = m['_source'] as String?;
    final isPastForRouting =
        kind == 'past' || (kind == 'mixed' && source == 'past_hosted');

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    if (isPastForRouting) {
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
      return;
    }

    // Scheduled / upcoming-hosted: route to the all-meetings screen.
    navigator.push(MaterialPageRoute(builder: (_) => const MeetingsScreen()));
  }

  /// Format a meeting's date+time for display, always in America/Chicago
  /// (Central Time, with DST handled — labels as CST or CDT depending on
  /// the date). Inputs may be a full ISO timestamp on `date`, or a
  /// date-only string with a separate `start_time` HH:MM[:SS].
  static String _formatMeetingTime(String? date, String? start) {
    if (date == null || date.isEmpty) return '';
    final chicago = tz.getLocation('America/Chicago');
    DateTime? parsed;

    // Try the full ISO timestamp form first (e.g. "2025-10-31T00:30:00+00:00").
    if (date.contains('T') || date.contains(' ')) {
      parsed = DateTime.tryParse(date);
    } else if (start != null && start.isNotEmpty) {
      // Combine date + start_time. Treat as UTC if no tz info present
      // (matches what Supabase returns for `time without time zone`
      // columns paired with `date`).
      final combined = '${date}T$start${start.contains('+') || start.contains('Z') ? '' : 'Z'}';
      parsed = DateTime.tryParse(combined);
    } else {
      // Date-only — show the date in Chicago timezone with no time.
      final dateOnly = DateTime.tryParse(date);
      if (dateOnly == null) return date;
      final chiDate = tz.TZDateTime.from(dateOnly.toUtc(), chicago);
      return DateFormat('EEE MMM d').format(chiDate);
    }

    if (parsed == null) return date;
    final chi = tz.TZDateTime.from(parsed, chicago);
    final dayLabel = DateFormat('EEE MMM d').format(chi);
    final timeLabel = DateFormat('h:mm a').format(chi);
    final tzAbbrev = chi.timeZoneName; // "CST" or "CDT"
    return '$dayLabel · $timeLabel $tzAbbrev';
  }

  Widget _list(
    List<Map<String, dynamic>> items,
    bool loading, {
    required bool isUpcoming,
    required String kind,
  }) {
    if (loading && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (items.isEmpty) {
      return Center(
        child: Text(
          isUpcoming ? 'No upcoming meetings' : 'No meetings yet',
          style: const TextStyle(color: Color(0xFF6B7280)),
        ),
      );
    }
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final m = items[i];
        final title = (m['meeting_title'] as String?) ?? 'Meeting';
        final committee = m['committee']?.toString() ?? m['committee_id']?.toString();
        final timeLabel = _formatMeetingTime(
          m['meeting_date']?.toString(),
          m['start_time']?.toString(),
        );
        return ListTile(
          dense: true,
          onTap: () => _openMeeting(m, kind),
          leading: Icon(
            isUpcoming ? Icons.event_available : Icons.event_note,
            size: 20,
          ),
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            [
              if (timeLabel.isNotEmpty) timeLabel,
              if (committee != null && committee.isNotEmpty) committee,
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.arrow_forward_ios, size: 14),
        );
      },
    );
  }
}
