import 'package:flutter/material.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/models/crm/outreach_activity.dart';
import 'package:bluebubbles/services/crm/outreach_repository.dart';
import 'package:bluebubbles/screens/crm/volunteers/activity_detail_screen.dart';
import 'package:bluebubbles/screens/crm/volunteers/organizing_toolkit_sheet.dart';

// ═══════════════════════════════════════════════════════════════
//  ACTIVITIES HUB (Tab 2 of the War Room workspace)
//
//  Org-wide list of organizing activities over OutreachRepository, with a
//  status/kind/date filter bar and a "Plan activity" button that reuses the
//  shipped OrganizingToolkitSheet create flow. Row tap pushes
//  ActivityDetailScreen. Per-row roster/nominee/attended counts are loaded
//  lazily and cached so the list never fires hundreds of queries up front.
//
//  Painted in the Slack management language: BrandedBackground page, one
//  gradient header band carrying the title and every filter, and a gradient
//  feed panel of white-pill rows underneath.
// ═══════════════════════════════════════════════════════════════

/// Quick date lens applied in-memory over the fetched list.
enum _DateLens { all, upcoming, overdue }

/// List vs. Board (Kanban) presentation of the same filtered activity set.
enum _HubView { list, board }

/// Below this width four side-by-side status columns don't fit, so the Board
/// toggle is hidden and the hub is forced to the List view.
const double _kBoardMinWidth = 840;

/// Below this width the header's create button drops its label, so the title
/// keeps a readable share of the row on a phone.
const double _kCompactHeaderWidth = 560;

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
    if (!mounted) return;
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
      // Fetch roster and nominee count concurrently instead of sequentially
      // (this runs per visible row).
      final results = await Future.wait([
        _repo.getRoster(activityId),
        _repo.activityCandidateCount(activityId),
      ]);
      final roster = results[0] as List<ActivityRosterEntry>;
      final nominees = results[1] as int;
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

  bool get _filtersActive =>
      _statuses.isNotEmpty || _kind != null || _dateLens != _DateLens.all;

  Future<void> _newActivity() async {
    final saved = await OrganizingToolkitSheet.show(context);
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return BrandedBackground(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Board is desktop/tablet only. Below the threshold we hide the
          // toggle and force List, so a resize down never leaves four columns
          // crammed.
          final boardAllowed = constraints.maxWidth >= _kBoardMinWidth;
          final showBoard = boardAllowed && _view == _HubView.board;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _headerBand(
                boardAllowed,
                narrow: constraints.maxWidth < _kCompactHeaderWidth,
              ),
              Expanded(child: showBoard ? _board() : _body()),
            ],
          );
        },
      ),
    );
  }

  // ── Header band ────────────────────────────────────────────────
  // Title, view toggle, the create button and every filter live on ONE
  // gradient band, so the light page below carries nothing but content.
  Widget _headerBand(bool boardAllowed, {required bool narrow}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(gradient: BrandColors.getTileGradient()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.campaign_outlined,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Organizing activities',
                        style: BrandTextStyles.title),
                    const SizedBox(height: 2),
                    Text(_subtitle(), style: BrandTextStyles.caption),
                  ],
                ),
              ),
              if (boardAllowed) ...[
                _viewToggle(),
                const SizedBox(width: 10),
              ],
              IconButton(
                onPressed: _loading ? null : _load,
                tooltip: 'Refresh',
                icon: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.refresh, color: Colors.white),
              ),
              const SizedBox(width: 4),
              _planButton(narrow: narrow),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final entry in OutreachDisplay.statuses.entries)
                _statusChip(entry.key, entry.value.label),
              _kindMenu(),
            ],
          ),
          const SizedBox(height: 10),
          _dateToggle(),
        ],
      ),
    );
  }

  // Gold with navy ink is the emphasis pair: it is the only button fill that
  // holds 4.5:1 over both ends of the header gradient. Below the compact
  // breakpoint the label would squeeze the title out, so it drops to the icon.
  Widget _planButton({required bool narrow}) {
    final style = ElevatedButton.styleFrom(
      backgroundColor: BrandColors.sunriseGold,
      foregroundColor: BrandColors.unityBlue,
      padding: EdgeInsets.symmetric(horizontal: narrow ? 12 : 14, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
    if (narrow) {
      return Tooltip(
        message: 'Plan activity',
        child: ElevatedButton(
          onPressed: _newActivity,
          style: style,
          child: const Icon(Icons.add, size: 18),
        ),
      );
    }
    return ElevatedButton.icon(
      onPressed: _newActivity,
      style: style,
      icon: const Icon(Icons.add, size: 18),
      label: const Text('Plan activity',
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
    );
  }

  String _subtitle() {
    if (_loading) return 'Loading activities';
    if (_errored) return 'Could not load activities';
    final shown = _visible.length;
    if (_filtersActive) {
      return '$shown of ${_activities.length} shown';
    }
    return shown == 1 ? '1 activity' : '$shown activities';
  }

  Widget _statusChip(String key, String label) {
    final selected = _statuses.contains(key);
    final style = outreachStatusStyle(key);
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? style.fill : Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(label,
              style: TextStyle(
                  color: selected ? style.fg : Colors.white,
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
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _kind,
          isDense: true,
          icon: const Icon(Icons.expand_more, color: Colors.white70, size: 18),
          dropdownColor: BrandColors.unityBlue,
          borderRadius: BorderRadius.circular(12),
          style: const TextStyle(
              color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('All kinds'),
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

  // Selected segments fill with unityBlue rather than a translucent white:
  // white-on-white-over-gradient drops under 4:1 at the momentumBlue end,
  // where navy holds 15:1 anywhere on the band.
  Widget _segment({
    required String label,
    IconData? icon,
    required bool selected,
    required VoidCallback onTap,
    bool expand = true,
  }) {
    final seg = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 34,
          padding: EdgeInsets.symmetric(horizontal: expand ? 8 : 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? BrandColors.unityBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon,
                    size: 16,
                    color: selected ? Colors.white : Colors.white70),
                const SizedBox(width: 6),
              ],
              Text(label,
                  style: TextStyle(
                      color: selected ? Colors.white : Colors.white70,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
    return expand ? Expanded(child: seg) : seg;
  }

  Widget _dateToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          for (final lens in _DateLens.values)
            _segment(
              label: _lensLabel(lens),
              selected: _dateLens == lens,
              onTap: () => setState(() => _dateLens = lens),
            ),
        ],
      ),
    );
  }

  String _lensLabel(_DateLens lens) {
    switch (lens) {
      case _DateLens.all:
        return 'All';
      case _DateLens.upcoming:
        return 'Upcoming';
      case _DateLens.overdue:
        return 'Overdue';
    }
  }

  // ── List / Board toggle (desktop/tablet only) ──────────────────
  Widget _viewToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment(
            label: 'List',
            icon: Icons.view_agenda_outlined,
            selected: _view == _HubView.list,
            expand: false,
            onTap: () => setState(() => _view = _HubView.list),
          ),
          const SizedBox(width: 4),
          _segment(
            label: 'Board',
            icon: Icons.view_column_outlined,
            selected: _view == _HubView.board,
            expand: false,
            onTap: () => setState(() => _view = _HubView.board),
          ),
        ],
      ),
    );
  }

  // ── Body ───────────────────────────────────────────────────────
  Widget _body() {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(
              strokeWidth: 2.6, color: BrandColors.unityBlue),
        ),
      );
    }
    if (_errored) return _errorState();

    final visible = _visible;
    if (visible.isEmpty) return _emptyState();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BrandCardDecoration.brandedCard(),
          child: RefreshIndicator(
            onRefresh: _load,
            color: BrandColors.unityBlue,
            backgroundColor: Colors.white,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: visible.length,
              itemBuilder: (_, i) => _activityRow(visible[i]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _activityRow(OutreachActivity a) {
    final geo = _geoLabels(a);
    final overdue = _overdueDays(a);
    final style = outreachStatusStyle(a.status);

    final head = <String>[
      a.kindLabel,
      a.scheduledOn == null ? 'No date' : _fmtDate(a.scheduledOn!),
      if (geo.isNotEmpty) geo.join(', '),
    ].join('  ·  ');

    return FutureBuilder<_RowCounts>(
      future: _countsFor(a.id),
      builder: (context, snap) {
        final counts = snap.data;
        return BrandedActivityFeedItem(
          primaryText: a.title,
          secondaryText: head,
          tertiaryText: counts == null
              ? null
              : '${counts.nominees == 1 ? '1 nominee' : '${counts.nominees} nominees'}'
                  '  ·  ${counts.rostered == 1 ? '1 on roster' : '${counts.rostered} on roster'}'
                  '  ·  ${counts.attended} attended',
          leadingIcon: a.kindIcon,
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => ActivityDetailScreen(activity: a)),
            );
            // Status/attendance may have changed on the detail screen.
            _load();
          },
          trailingChips: overdue == null
              ? null
              : [_overdueChip(overdue)],
          // The feed item's own action pill is always white-on-fill, which the
          // light state colors cannot carry; this owns the right edge instead.
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _statusPill(a.statusLabel, style),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: Colors.white54, size: 18),
            ],
          ),
        );
      },
    );
  }

  Widget _statusPill(String label, ({Color fill, Color fg}) style) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: style.fill,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label.toUpperCase(),
          style: TextStyle(
              color: style.fg, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _overdueChip(int days) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: BrandColors.unityBlue,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule, size: 12, color: outreachDangerInk),
          const SizedBox(width: 4),
          Text(days == 1 ? '1 day overdue' : '$days days overdue',
              style: TextStyle(
                  color: outreachDangerInk,
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ── Empty / error states ───────────────────────────────────────
  // Both sit on the light BrandedBackground, so every word here is unityBlue
  // and never white. The empty state is what everyone sees first while the
  // table is still empty, so it carries the create action rather than a note.
  Widget _emptyState() {
    final filtered = _filtersActive;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: BrandColors.momentumBlue.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                filtered ? Icons.filter_alt_off_outlined : Icons.event_available,
                size: 56,
                color: BrandColors.unityBlue,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              filtered
                  ? 'No activities match these filters'
                  : 'No organizing planned yet',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: BrandColors.unityBlue,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              filtered
                  ? 'Clear a status, kind or date filter to widen the search.'
                  : 'Canvasses, phone banks and days of action live here. Plan '
                      'the first one and the roster, attendance and nominee '
                      'coverage follow.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: BrandColors.unityBlue.withValues(alpha: 0.7),
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            if (filtered)
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _statuses.clear();
                    _kind = null;
                    _dateLens = _DateLens.all;
                  });
                  _load();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: BrandColors.unityBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.filter_alt_off_outlined),
                label: const Text('Clear filters'),
              )
            else
              ElevatedButton.icon(
                onPressed: _newActivity,
                style: ElevatedButton.styleFrom(
                  backgroundColor: BrandColors.sunriseGold,
                  foregroundColor: BrandColors.unityBlue,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Plan the first activity',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: BrandColors.error.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline,
                  size: 56, color: BrandColors.error),
            ),
            const SizedBox(height: 20),
            const Text(
              'Could not load activities',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: BrandColors.unityBlue,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The activity list could not be read. Check the connection and '
              'try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: BrandColors.unityBlue.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _load,
              style: ElevatedButton.styleFrom(
                backgroundColor: BrandColors.unityBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
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
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(
              strokeWidth: 2.6, color: BrandColors.unityBlue),
        ),
      );
    }
    if (_errored) return _errorState();

    final visible = _visible;
    final keys = OutreachDisplay.statuses.keys.toList(); // planned→cancelled
    final byStatus = <String, List<OutreachActivity>>{
      for (final k in keys) k: <OutreachActivity>[],
    };
    for (final a in visible) {
      (byStatus[a.status] ??= <OutreachActivity>[]).add(a);
    }

    return Padding(
      padding: const EdgeInsets.all(16),
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
    final style = outreachStatusStyle(key);
    return DragTarget<OutreachActivity>(
      onWillAcceptWithDetails: (d) => d.data.status != key,
      onAcceptWithDetails: (d) => _moveTo(d.data, key),
      builder: (context, candidate, rejected) {
        final hovering = candidate.isNotEmpty;
        return Container(
          // Clipped so a scrolled card never paints over the rounded corners.
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: BrandColors.getTileGradient(),
            borderRadius: BorderRadius.circular(16),
            // Gold is the highlight ring everywhere else in the kit, and it is
            // the only accent that stays visible over both ends of the tile
            // gradient.
            border: hovering
                ? Border.all(color: BrandColors.sunriseGold, width: 2)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom:
                        BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: style.fill,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(meta.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('${items.length}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Nothing here',
                              style: BrandTextStyles.caption),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 2),
                        itemCount: items.length,
                        itemBuilder: (_, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _boardCard(items[i]),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
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
    final overdue = _overdueDays(a);
    return Material(
      // In-column cards are the kit's white-10% inset on the column gradient.
      // The drag proxy leaves that gradient behind, so it carries its own.
      color: dragging ? Colors.transparent : Colors.white.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      elevation: dragging ? 6 : 0,
      shadowColor: Colors.black.withValues(alpha: 0.35),
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
          padding: const EdgeInsets.all(12),
          decoration: dragging
              ? BrandCardDecoration.brandedCard(borderRadius: 12)
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(a.kindIcon, size: 16, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(a.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            height: 1.25)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                a.scheduledOn == null ? 'No date' : _fmtDate(a.scheduledOn!),
                style: BrandTextStyles.caption,
              ),
              if (geo.isNotEmpty || overdue != null) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    if (overdue != null) _overdueChip(overdue),
                    if (geo.isNotEmpty) _regionChip(geo.first),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _regionChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
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
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: BrandColors.unityBlue,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ));
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
