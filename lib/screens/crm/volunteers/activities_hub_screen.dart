import 'package:flutter/material.dart';

import 'package:bluebubbles/models/crm/outreach_activity.dart';
import 'package:bluebubbles/services/crm/outreach_repository.dart';
import 'package:bluebubbles/screens/crm/volunteers/activity_detail_screen.dart';
import 'package:bluebubbles/screens/crm/volunteers/outreach_log_sheet.dart';
import 'package:bluebubbles/screens/crm/volunteers/volunteers_map_models.dart';

// ═══════════════════════════════════════════════════════════════
//  ACTIVITIES HUB (Tab 2 of the War Room workspace)
//
//  Org-wide list of volunteer activities over OutreachRepository, with a
//  status/kind/date filter bar and a "+ New Activity" that reuses the
//  shipped OutreachLogSheet create flow. Row tap pushes ActivityDetailScreen.
//  Per-row roster/nominee/attended counts are loaded lazily and cached so the
//  list never fires hundreds of queries up front.
// ═══════════════════════════════════════════════════════════════

/// Quick date lens applied in-memory over the fetched list.
enum _DateLens { all, upcoming, overdue }

/// List vs. Board (Kanban) presentation of the same filtered activity set.
enum _HubView { list, board }

/// Below this width four side-by-side status columns don't fit, so the Board
/// toggle is hidden and the hub is forced to the List view.
const double _kBoardMinWidth = 840;

class ActivitiesHubScreen extends StatefulWidget {
  const ActivitiesHubScreen({super.key});

  @override
  State<ActivitiesHubScreen> createState() => _ActivitiesHubScreenState();
}

class _ActivitiesHubScreenState extends State<ActivitiesHubScreen> {
  final OutreachRepository _repo = OutreachRepository();

  bool _loading = true;
  bool _errored = false;
  List<OutreachActivity> _activities = <OutreachActivity>[];

  // Filters.
  final Set<String> _statuses = <String>{};
  String? _kind; // null = All kinds
  _DateLens _dateLens = _DateLens.all;

  // List (default) vs. Board. Only reachable at desktop/tablet widths; a
  // narrow LayoutBuilder forces List regardless of what this holds.
  _HubView _view = _HubView.list;

  // Lazily-resolved per-row meta, cached so scroll rebuilds don't refetch.
  final Map<String, Future<_RowCounts>> _countsCache =
      <String, Future<_RowCounts>>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errored = false;
    });
    _countsCache.clear();
    try {
      final rows = await _repo.listActivities(
        statuses: _statuses.isEmpty ? null : _statuses.toList(),
        kind: _kind,
      );
      // Server returns newest scheduled_on first; the hub wants ascending
      // (soonest first), with date-less activities sorted to the end.
      rows.sort((a, b) {
        final ax = a.scheduledOn;
        final bx = b.scheduledOn;
        if (ax == null && bx == null) return 0;
        if (ax == null) return 1;
        if (bx == null) return -1;
        return ax.compareTo(bx);
      });
      if (!mounted) return;
      setState(() {
        _activities = rows;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errored = true;
        _loading = false;
      });
    }
  }

  Future<_RowCounts> _countsFor(String activityId) {
    return _countsCache.putIfAbsent(activityId, () async {
      final roster = await _repo.getRoster(activityId);
      final nominees = await _repo.activityCandidateCount(activityId);
      final attended = roster.where((e) => e.attended == true).length;
      return _RowCounts(
        rostered: roster.length,
        attended: attended,
        nominees: nominees,
      );
    });
  }

  List<OutreachActivity> get _visible {
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    return _activities.where((a) {
      switch (_dateLens) {
        case _DateLens.all:
          return true;
        case _DateLens.upcoming:
          final on = a.scheduledOn;
          return on == null || !on.isBefore(startOfToday);
        case _DateLens.overdue:
          final on = a.scheduledOn;
          return on != null && on.isBefore(startOfToday) && a.status == 'planned';
      }
    }).toList();
  }

  Future<void> _newActivity() async {
    final saved = await OutreachLogSheet.show(context);
    if (saved == true) _load();
  }

  // ── Theme tokens ───────────────────────────────────────────────
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bg => _isDark ? const Color(0xFF151B2B) : const Color(0xFFF4F6FA);
  Color get _surface => _isDark ? const Color(0xFF1B2337) : Colors.white;
  Color get _inset => _isDark ? const Color(0xFF212B44) : const Color(0xFFEEF1F6);
  Color get _text => _isDark ? const Color(0xFFF4F6FA) : const Color(0xFF1E2637);
  Color get _secondary =>
      _isDark ? Colors.white.withValues(alpha: 0.72) : const Color(0xFF5A6478);
  Color get _divider =>
      _isDark ? const Color(0xFF2E3A57) : const Color(0xFFE5E9F0);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Board is desktop/tablet only. Below the threshold we hide the toggle
        // and force List, so a resize down never leaves four columns crammed.
        final boardAllowed = constraints.maxWidth >= _kBoardMinWidth;
        final showBoard = boardAllowed && _view == _HubView.board;
        return Container(
          color: _bg,
          child: Column(
            children: [
              _header(boardAllowed),
              _filterBar(),
              Expanded(child: showBoard ? _board() : _body()),
            ],
          ),
        );
      },
    );
  }

  // ── Header ─────────────────────────────────────────────────────
  Widget _header(bool boardAllowed) {
    return Container(
      color: _surface,
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: Text('Volunteer activities',
                style: TextStyle(
                    color: _text, fontSize: 19, fontWeight: FontWeight.w800)),
          ),
          if (boardAllowed) ...[
            _viewToggle(),
            const SizedBox(width: 12),
          ],
          Material(
            color: MoydMapTheme.unityBlue,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: _newActivity,
              borderRadius: BorderRadius.circular(10),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, color: Colors.white, size: 18),
                    SizedBox(width: 6),
                    Text('New Activity',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Filter bar ─────────────────────────────────────────────────
  Widget _filterBar() {
    return Container(
      color: _surface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final entry in OutreachDisplay.statuses.entries)
                _statusChip(entry.key, entry.value.label, entry.value.color),
              _kindMenu(),
            ],
          ),
          const SizedBox(height: 10),
          _dateToggle(),
        ],
      ),
    );
  }

  Widget _statusChip(String key, String label, Color color) {
    final selected = _statuses.contains(key);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            if (selected) {
              _statuses.remove(key);
            } else {
              _statuses.add(key);
            }
          });
          _load();
        },
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? color : _inset,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? color : _divider),
          ),
          child: Text(label,
              style: TextStyle(
                  color: selected ? Colors.white : _text,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  Widget _kindMenu() {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _inset,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _divider),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _kind,
          isDense: true,
          icon: Icon(Icons.expand_more, color: _secondary, size: 18),
          dropdownColor: _surface,
          style: TextStyle(
              color: _text, fontSize: 12.5, fontWeight: FontWeight.w600),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text('All kinds',
                  style: TextStyle(color: _secondary, fontSize: 12.5)),
            ),
            for (final e in OutreachDisplay.kinds.entries)
              DropdownMenuItem<String?>(
                value: e.key,
                child: Text(e.value.label),
              ),
          ],
          onChanged: (v) {
            setState(() => _kind = v);
            _load();
          },
        ),
      ),
    );
  }

  Widget _dateToggle() {
    Widget seg(_DateLens lens, String label) {
      final selected = _dateLens == lens;
      return Expanded(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => _dateLens = lens),
            child: Container(
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? MoydMapTheme.unityBlue.withValues(alpha: _isDark ? 0.28 : 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(label,
                  style: TextStyle(
                      color: selected ? MoydMapTheme.unityBlue : _secondary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _inset,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _divider),
      ),
      child: Row(
        children: [
          seg(_DateLens.all, 'All'),
          seg(_DateLens.upcoming, 'Upcoming'),
          seg(_DateLens.overdue, 'Overdue'),
        ],
      ),
    );
  }

  // ── List / Board toggle (desktop/tablet only) ──────────────────
  Widget _viewToggle() {
    Widget seg(_HubView view, IconData icon, String label) {
      final selected = _view == view;
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _view = view),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? MoydMapTheme.unityBlue : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    size: 16, color: selected ? Colors.white : _secondary),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                        color: selected ? Colors.white : _secondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _inset,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          seg(_HubView.list, Icons.view_agenda_outlined, 'List'),
          const SizedBox(width: 3),
          seg(_HubView.board, Icons.view_column_outlined, 'Board'),
        ],
      ),
    );
  }

  // ── Board (Kanban) ─────────────────────────────────────────────
  //
  // Four status columns over the SAME filtered set the list view uses
  // (_visible). A card is a LongPressDraggable; each column a DragTarget.
  // A legal drop into a different column optimistically moves the card, then
  // persists via updateStatus; a failed write reverts. Filtered-out statuses
  // simply yield an empty column.
  Widget _board() {
    final visible = _visible;
    final keys = OutreachDisplay.statuses.keys.toList(); // planned→cancelled
    final byStatus = <String, List<OutreachActivity>>{
      for (final k in keys) k: <OutreachActivity>[],
    };
    for (final a in visible) {
      (byStatus[a.status] ??= <OutreachActivity>[]).add(a);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < keys.length; i++) ...[
            Expanded(child: _column(keys[i], byStatus[keys[i]]!)),
            if (i < keys.length - 1) const SizedBox(width: 12),
          ],
        ],
      ),
    );
  }

  Widget _column(String key, List<OutreachActivity> items) {
    final meta = OutreachDisplay.statuses[key]!;
    return DragTarget<OutreachActivity>(
      onWillAcceptWithDetails: (d) => d.data.status != key,
      onAcceptWithDetails: (d) => _moveTo(d.data, key),
      builder: (context, candidate, rejected) {
        final hovering = candidate.isNotEmpty;
        return Container(
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: hovering ? meta.color : _divider,
                width: hovering ? 1.6 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thin top accent bar in the status color.
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: meta.color,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(14)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(meta.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: _text,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 8),
                    _countBadge(items.length, meta.color),
                  ],
                ),
              ),
              Divider(height: 1, color: _divider),
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text('Nothing here',
                              style: TextStyle(
                                  color: _secondary,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600)),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(10),
                        itemCount: items.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (_, i) => _boardCard(items[i]),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _countBadge(int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('$count',
          style: const TextStyle(
              color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800)),
    );
  }

  Widget _boardCard(OutreachActivity a) {
    final card = _boardCardBody(a);
    return LongPressDraggable<OutreachActivity>(
      data: a,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.95,
          child: SizedBox(width: 240, child: _boardCardBody(a, dragging: true)),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: card),
      child: card,
    );
  }

  Widget _boardCardBody(OutreachActivity a, {bool dragging = false}) {
    final geo = _geoLabels(a);
    return Material(
      color: dragging ? _surface : _inset,
      borderRadius: BorderRadius.circular(12),
      elevation: dragging ? 6 : 0,
      shadowColor: Colors.black.withValues(alpha: 0.25),
      child: InkWell(
        onTap: dragging
            ? null
            : () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => ActivityDetailScreen(activity: a)),
                );
                _load();
              },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(a.kindIcon, size: 16, color: MoydMapTheme.unityBlue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(a.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: _text,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            height: 1.25)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                      a.scheduledOn == null
                          ? 'No date'
                          : _fmtDate(a.scheduledOn!),
                      style: TextStyle(color: _secondary, fontSize: 11.5)),
                  if (geo.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Flexible(child: _regionChip(geo.first)),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _regionChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: MoydMapTheme.unityBlue.withValues(alpha: _isDark ? 0.24 : 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              color: _isDark ? Colors.white : MoydMapTheme.unityBlue,
              fontSize: 11,
              fontWeight: FontWeight.w700)),
    );
  }

  // Enforced status transitions. Same-column drops are rejected upstream by the
  // DragTarget (no-op). The rest reject with a snackbar rather than writing.
  bool _canTransition(String from, String to) {
    if (from == to) return false;
    switch (from) {
      case 'planned':
        return to == 'in_progress' || to == 'completed' || to == 'cancelled';
      case 'in_progress':
        return to == 'completed' || to == 'cancelled';
      case 'completed':
        return to == 'in_progress'; // reopen only
      case 'cancelled':
        return to == 'planned' || to == 'in_progress'; // reopen only
    }
    return false;
  }

  Future<void> _moveTo(OutreachActivity a, String targetKey) async {
    final label = OutreachDisplay.statuses[targetKey]?.label ?? targetKey;
    if (!_canTransition(a.status, targetKey)) {
      _snack('Cannot move "${a.title}" to $label');
      return;
    }
    final index = _activities.indexWhere((e) => e.id == a.id);
    if (index < 0) return;
    final previous = _activities[index];

    // Optimistic move: the card jumps columns and both count badges update.
    setState(() => _activities[index] = previous.copyWith(status: targetKey));

    try {
      await _repo.updateStatus(a.id, targetKey);
      if (!mounted) return;
      _snack('Moved "${a.title}" to $label');
    } catch (e) {
      if (!mounted) return;
      setState(() => _activities[index] = previous);
      _snack('Could not move "${a.title}". Please try again.');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ));
  }

  // ── Body ───────────────────────────────────────────────────────
  Widget _body() {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(
              strokeWidth: 2.6, color: MoydMapTheme.unityBlue),
        ),
      );
    }
    if (_errored) {
      return _centeredNote(
        Icons.error_outline,
        'Could not load activities.',
        action: ('Retry', _load),
      );
    }

    final visible = _visible;
    if (visible.isEmpty) {
      final filtersActive =
          _statuses.isNotEmpty || _kind != null || _dateLens != _DateLens.all;
      return _centeredNote(
        Icons.event_note_outlined,
        filtersActive
            ? 'No activities match these filters.'
            : 'No activities planned yet.',
        action: filtersActive ? null : ('Plan the first one', _newActivity),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: MoydMapTheme.unityBlue,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        itemCount: visible.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _activityRow(visible[i]),
      ),
    );
  }

  Widget _activityRow(OutreachActivity a) {
    final geo = _geoLabels(a);
    final overdue = _overdueDays(a);

    return Material(
      color: _surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ActivityDetailScreen(activity: a)),
          );
          // Status/attendance may have changed on the detail screen.
          _load();
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _kindSquare(a.kindIcon),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: _text,
                                fontSize: 15,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 3),
                        Text(a.kindLabel,
                            style: TextStyle(
                                color: _secondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _statusPill(a),
                ],
              ),
              const SizedBox(height: 10),
              _metaLine(a, geo),
              if (overdue != null) ...[
                const SizedBox(height: 6),
                Text(
                  overdue == 1 ? '1 day overdue' : '$overdue days overdue',
                  style: TextStyle(
                      color: _isDark
                          ? MoydMapTheme.gold
                          : MoydMapTheme.goldText,
                      fontSize: 12,
                      fontWeight: FontWeight.w800),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _kindSquare(IconData icon) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: MoydMapTheme.unityBlue.withValues(alpha: _isDark ? 0.22 : 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 20, color: MoydMapTheme.unityBlue),
    );
  }

  Widget _statusPill(OutreachActivity a) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: a.statusColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(a.statusLabel,
          style: const TextStyle(
              color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }

  Widget _metaLine(OutreachActivity a, List<String> geo) {
    return FutureBuilder<_RowCounts>(
      future: _countsFor(a.id),
      builder: (context, snap) {
        final parts = <String>[
          a.scheduledOn == null ? 'No date' : _fmtDate(a.scheduledOn!),
          if (geo.isNotEmpty) geo.join(', '),
        ];
        final counts = snap.data;
        if (counts != null) {
          parts.add(counts.nominees == 1
              ? '1 nominee'
              : '${counts.nominees} nominees');
          parts.add(counts.rostered == 1
              ? '1 on roster'
              : '${counts.rostered} on roster');
          parts.add('${counts.attended} attended');
        }
        return Text(
          parts.join('  ·  '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: _secondary, fontSize: 12.5, height: 1.3),
        );
      },
    );
  }

  Widget _centeredNote(IconData icon, String text,
      {(String, VoidCallback)? action}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: _secondary),
          const SizedBox(height: 14),
          Text(text,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: _secondary, fontSize: 14, fontWeight: FontWeight.w600)),
          if (action != null) ...[
            const SizedBox(height: 14),
            TextButton(
              onPressed: action.$2,
              child: Text(action.$1,
                  style: const TextStyle(
                      color: MoydMapTheme.unityBlue,
                      fontWeight: FontWeight.w800)),
            ),
          ],
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────
  List<String> _geoLabels(OutreachActivity a) => [
        for (final c in a.counties) '$c County',
        for (final d in a.congressionalDistricts) 'CD $d',
        for (final d in a.senateDistricts) 'SD $d',
        for (final d in a.houseDistricts) 'HD $d',
      ];

  /// Whole days a planned activity is past due, or null if not overdue.
  int? _overdueDays(OutreachActivity a) {
    if (a.status != 'planned') return null;
    final on = a.scheduledOn;
    if (on == null) return null;
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final onDay = DateTime(on.year, on.month, on.day);
    if (!onDay.isBefore(startOfToday)) return null;
    return startOfToday.difference(onDay).inDays;
  }

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _fmtDate(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';
}

/// Cheap per-row count bundle.
class _RowCounts {
  const _RowCounts({
    required this.rostered,
    required this.attended,
    required this.nominees,
  });

  final int rostered;
  final int attended;
  final int nominees;
}
