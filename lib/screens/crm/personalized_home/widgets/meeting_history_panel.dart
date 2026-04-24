import 'package:flutter/material.dart';

import 'package:bluebubbles/services/crm/home_meeting_history_service.dart';

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
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.calendar_today),
                ),
                const SizedBox(width: 4),
                Text(
                  'Meetings',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _load,
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const SizedBox(height: 8),
            TabBar(
              controller: _tabs,
              isScrollable: true,
              tabs: [
                Tab(text: 'Upcoming (${_upcoming.length})'),
                Tab(text: 'Recent (${_attended.length})'),
                Tab(text: 'Hosted (${_hosted.length})'),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 240,
              child: TabBarView(
                controller: _tabs,
                children: [
                  _list(_upcoming, _loading, isUpcoming: true),
                  _list(_attended, _loading, isUpcoming: false),
                  _list(_hosted, _loading, isUpcoming: false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(List<Map<String, dynamic>> items, bool loading, {required bool isUpcoming}) {
    if (loading && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (items.isEmpty) {
      return Center(
        child: Text(
          isUpcoming ? 'No upcoming meetings' : 'No meetings yet',
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final m = items[i];
        final title = (m['meeting_title'] as String?) ?? 'Meeting';
        final date = m['meeting_date']?.toString() ?? '';
        final start = m['start_time']?.toString();
        final committee = m['committee']?.toString() ?? m['committee_id']?.toString();
        return ListTile(
          dense: true,
          leading: Icon(
            isUpcoming ? Icons.event_available : Icons.event_note,
            size: 20,
          ),
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            [
              if (date.isNotEmpty) date,
              if (start != null && start.isNotEmpty) start,
              if (committee != null && committee.isNotEmpty) committee,
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      },
    );
  }
}
