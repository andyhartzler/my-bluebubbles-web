import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:universal_html/html.dart' as html;

import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/models/crm/outreach_activity.dart';
import 'package:bluebubbles/screens/crm/candidate_detail_screen.dart';
import 'package:bluebubbles/screens/crm/member_detail_screen.dart';
import 'package:bluebubbles/services/crm/member_repository.dart';
import 'package:bluebubbles/services/crm/outreach_repository.dart';

import 'outreach_log_sheet.dart';
import 'outreach_region_section.dart';
import 'volunteers_map_models.dart';

/// Which slice of the detail panel to render.
///
/// [statewide] is the overview rail shown when nothing is selected. In the
/// desktop three-pane region view [candidates] renders the left ballot pane and
/// [members] the right selection pane; [combined] is the mobile draggable sheet
/// which stacks candidates over members in one scroll. Only the [members] /
/// [combined] panes own member-selection state.
enum VolunteersPane { statewide, candidates, members, combined }

/// Members-pane "Last contacted" filter (§5). [any] is the default no-op.
enum _LastContactedFilter { any, never, notIn30 }

/// Members-pane sort order (§5). [nameAsc] is the default.
enum _MemberSort { nameAsc, recentlyContacted, leastRecentlyContacted }

// ═══════════════════════════════════════════════════════════════
//  DETAIL PANEL — the right-hand rail (desktop) / draggable sheet body
//  (mobile). Renders a Statewide Overview when nothing is selected, or a
//  region detail (November candidates + resident members with real
//  multi-select and a pinned bulk-action bar) when a region is.
//
//  ONE widget, both surfaces: the mounting decides the box (desktop rail
//  360–440px; mobile DraggableScrollableSheet snapped 0.35 / 0.7 / 0.95).
//  The panel is size-agnostic and drives the sheet through [scrollController]
//  so drag-to-expand works; the pinned action bar sits below the scroll view
//  so it stays visible at every snap.
// ═══════════════════════════════════════════════════════════════

/// One row in the Statewide Overview "hot districts" list.
class HotRegion {
  const HotRegion({
    required this.mode,
    required this.id,
    required this.memberCount,
    required this.status,
  });

  final MapMode mode;
  final String id;
  final int memberCount;
  final RegionStatus status;
}

/// Everything the panel needs to render the selected region.
///
/// [candidateGroups] carries the office-grouped candidate rows (district modes
/// yield one group; county mode yields the crosswalk-overlap groups). Agent A
/// builds these; the panel only renders them.
class RegionDetail {
  const RegionDetail({
    required this.mode,
    required this.id,
    required this.status,
    required this.memberCount,
    required this.members,
    required this.candidateGroups,
    required this.loadingCandidates,
    required this.loadingMembers,
  });

  final MapMode mode;
  final String id;
  final RegionStatus status;
  final int memberCount;
  final List<Member> members;
  final List<CandidateDisplayGroup> candidateGroups;
  final bool loadingCandidates;
  final bool loadingMembers;
}

// ── theme palette resolved per build from the active brightness ───────────
class _Palette {
  _Palette(this.isDark)
      : surface = isDark ? const Color(0xFF1B2337) : Colors.white,
        inset = isDark ? const Color(0xFF212B44) : const Color(0xFFF4F6FA),
        text = isDark ? const Color(0xFFF4F6FA) : const Color(0xFF1E2637),
        secondary =
            isDark ? Colors.white.withValues(alpha: 0.72) : const Color(0xFF5A6478),
        divider = isDark ? const Color(0xFF2E3A57) : const Color(0xFFE5E9F0),
        track = isDark ? const Color(0xFF313D5E) : const Color(0xFFDFE4EC),
        // Blue actions/links must clear 4.5:1 on the panel surface in both
        // themes: raw unityBlue (#0B4DB8) is ~2:1 on the dark surface, so it
        // lightens on dark. Used for text-link actions ("Show all", "Clear",
        // skip "Details", "Log outreach").
        action = isDark ? const Color(0xFF6AA0F0) : MoydMapTheme.unityBlue;

  final bool isDark;
  final Color surface;
  final Color inset;
  final Color text;
  final Color secondary;
  final Color divider;
  final Color track;
  final Color action;

  factory _Palette.of(BuildContext c) =>
      _Palette(Theme.of(c).brightness == Brightness.dark);
}

class VolunteersDetailPanel extends StatelessWidget {
  const VolunteersDetailPanel({
    super.key,
    this.detail,
    this.pane = VolunteersPane.combined,
    required this.statewideMembers,
    required this.statewideYoungDems,
    required this.hotRegions,
    required this.onClose,
    required this.onSelectHot,
    required this.onTextMembers,
    required this.onEmailMembers,
    this.onLogOutreach,
    this.scrollController,
    this.showCloseButton = true,
  });

  /// When null, the panel renders the Statewide Overview.
  final RegionDetail? detail;

  /// Which slice of the region detail to render. Ignored when [detail] is null
  /// (that always renders the statewide overview).
  final VolunteersPane pane;

  final int statewideMembers;
  final int statewideYoungDems;
  final List<HotRegion> hotRegions;

  final VoidCallback onClose;
  final void Function(MapMode mode, String id) onSelectHot;

  /// Existing bulk-send callbacks — signatures unchanged. The action bar
  /// filters the current selection to valid members and calls these.
  final void Function(List<Member> members) onTextMembers;
  final void Function(List<Member> members) onEmailMembers;

  /// Layer 2 outreach logging. Receives the currently selected members so the
  /// map can seed the outreach sheet's participant roster. Null-safe: the "Log
  /// outreach" button is hidden entirely while this is null.
  final void Function(List<Member> members)? onLogOutreach;

  /// Supplied on the mobile draggable sheet so the single scroll view drives
  /// drag-to-expand. Null on desktop (the rail owns its own controller).
  final ScrollController? scrollController;
  final bool showCloseButton;

  @override
  Widget build(BuildContext context) {
    final p = _Palette.of(context);
    return Material(
      color: p.surface,
      child: detail == null
          ? _statewide(context, p)
          : _RegionDetailView(
              key: ValueKey('${detail!.mode}:${detail!.id}:${pane.name}'),
              detail: detail!,
              pane:
                  pane == VolunteersPane.statewide ? VolunteersPane.combined : pane,
              onClose: onClose,
              onTextMembers: onTextMembers,
              onEmailMembers: onEmailMembers,
              onLogOutreach: onLogOutreach,
              scrollController: scrollController,
              showCloseButton: showCloseButton,
            ),
    );
  }

  // ── STATEWIDE OVERVIEW ─────────────────────────────────────────
  Widget _statewide(BuildContext context, _Palette p) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        Text('MISSOURI',
            style: TextStyle(
                color: p.secondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4)),
        const SizedBox(height: 4),
        Text('Statewide overview',
            style: TextStyle(
                color: p.text,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                height: 1.1,
                letterSpacing: -0.3)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _overviewChip(p, '👥', '$statewideMembers members', accent: false),
            _overviewChip(p, '★', '$statewideYoungDems young dems running',
                accent: true),
          ],
        ),
        const SizedBox(height: 24),
        _sectionHeader(p, 'HOT DISTRICTS'),
        const SizedBox(height: 10),
        if (hotRegions.isEmpty)
          Text('Loading district signal…',
              style: TextStyle(color: p.secondary, fontSize: 13))
        else
          ...hotRegions.map((h) => _hotRow(context, p, h)),
      ],
    );
  }

  Widget _overviewChip(_Palette p, String glyph, String label,
      {required bool accent}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: accent ? MoydMapTheme.gold.withValues(alpha: 0.16) : p.inset,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
            color: accent ? MoydMapTheme.gold.withValues(alpha: 0.5) : p.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(glyph, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  // gold-flavored text on a light surface must use goldText
                  // (4.5:1), never raw gold.
                  color: accent ? MoydMapTheme.goldText : p.text,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _hotRow(BuildContext context, _Palette p, HotRegion h) {
    final gold = h.status == RegionStatus.youngDem;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onSelectHot(h.mode, h.id),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: p.inset,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: gold
                      ? MoydMapTheme.gold.withValues(alpha: 0.55)
                      : p.divider),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color:
                        MapPalette.statusSwatch(h.status).withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(gold ? Icons.star_rounded : Icons.place_outlined,
                      size: 18,
                      color: gold ? MoydMapTheme.goldText : p.secondary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(h.mode.regionTitle(h.id),
                          style: TextStyle(
                              color: p.text,
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                          '${h.memberCount} member${h.memberCount == 1 ? '' : 's'}'
                          '${gold ? ' · young dem running' : ''}',
                          style: TextStyle(color: p.secondary, fontSize: 12)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: p.secondary.withValues(alpha: 0.6), size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  REGION DETAIL — stateful so the pinned action bar and the member list
//  share one selection set. Fresh state per region (ValueKey on mode:id).
// ═══════════════════════════════════════════════════════════════
class _RegionDetailView extends StatefulWidget {
  const _RegionDetailView({
    super.key,
    required this.detail,
    required this.pane,
    required this.onClose,
    required this.onTextMembers,
    required this.onEmailMembers,
    required this.onLogOutreach,
    required this.scrollController,
    required this.showCloseButton,
  });

  final RegionDetail detail;
  final VolunteersPane pane;
  final VoidCallback onClose;
  final void Function(List<Member> members) onTextMembers;
  final void Function(List<Member> members) onEmailMembers;
  final void Function(List<Member> members)? onLogOutreach;
  final ScrollController? scrollController;
  final bool showCloseButton;

  @override
  State<_RegionDetailView> createState() => _RegionDetailViewState();
}

class _RegionDetailViewState extends State<_RegionDetailView> {
  static const _initialCap = 30;

  final MemberRepository _repo = MemberRepository();

  final Set<String> _selectedIds = <String>{};
  bool _seeded = false;
  bool _expanded = false;
  bool _canTextFilter = false;
  bool _canEmailFilter = false;

  // Committee multi-select — values loaded once from the repo and cached.
  final Set<String> _committeeFilter = <String>{};
  List<String> _committees = const [];
  bool _loadingCommittees = false;

  _LastContactedFilter _lastContacted = _LastContactedFilter.any;
  _MemberSort _sort = _MemberSort.nameAsc;

  // Session-only overrides applied by the action bar so the list and the
  // last-contacted filter reflect a mark/note write without a full reload.
  // The notes override also seeds the next append so repeated notes never
  // clobber existing notes.
  final Map<String, DateTime> _lastContactedOverride = <String, DateTime>{};
  final Map<String, String> _notesOverride = <String, String>{};

  RegionDetail get _d => widget.detail;

  @override
  void initState() {
    super.initState();
    _loadCommittees();
  }

  Future<void> _loadCommittees() async {
    if (_loadingCommittees) return;
    setState(() => _loadingCommittees = true);
    try {
      final committees = await _repo.getUniqueCommittees();
      if (!mounted) return;
      setState(() {
        _committees = committees;
        _loadingCommittees = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingCommittees = false);
    }
  }

  bool _isSelectable(Member m) =>
      m.canContact || (m.preferredEmail ?? '').isNotEmpty;

  DateTime? _effectiveLastContacted(Member m) =>
      _lastContactedOverride[m.id] ?? m.lastContacted;

  String? _effectiveNotes(Member m) => _notesOverride[m.id] ?? m.notes;

  bool get _anyFilterActive =>
      _canTextFilter ||
      _canEmailFilter ||
      _committeeFilter.isNotEmpty ||
      _lastContacted != _LastContactedFilter.any;

  /// Seed the selection to ALL selectable members the first time they exist.
  /// Guarded so an async member load seeds once and later user changes stick.
  void _seedIfNeeded() {
    if (_seeded) return;
    final selectable = _d.members.where(_isSelectable).toList();
    if (selectable.isEmpty && _d.loadingMembers) return;
    _selectedIds
      ..clear()
      ..addAll(selectable.map((m) => m.id));
    _seeded = true;
  }

  /// Members shown in the list: the textable/emailable toggles compose as an
  /// OR group (unchanged from Phase 1), then AND with the committee and
  /// last-contacted filters, then the chosen sort is applied.
  List<Member> get _displayed {
    Iterable<Member> out = _d.members;

    if (_canTextFilter || _canEmailFilter) {
      out = out.where((m) =>
          (_canTextFilter && m.canContact) ||
          (_canEmailFilter && (m.preferredEmail ?? '').isNotEmpty));
    }

    if (_committeeFilter.isNotEmpty) {
      out = out.where((m) {
        final committees = m.committee;
        if (committees == null || committees.isEmpty) return false;
        return committees.any(_committeeFilter.contains);
      });
    }

    switch (_lastContacted) {
      case _LastContactedFilter.any:
        break;
      case _LastContactedFilter.never:
        out = out.where((m) => _effectiveLastContacted(m) == null);
        break;
      case _LastContactedFilter.notIn30:
        final cutoff = DateTime.now().subtract(const Duration(days: 30));
        out = out.where((m) {
          final lc = _effectiveLastContacted(m);
          return lc == null || lc.isBefore(cutoff);
        });
        break;
    }

    final list = out.toList();
    _sortMembers(list);
    return list;
  }

  void _sortMembers(List<Member> list) {
    int byName(Member a, Member b) =>
        a.name.toLowerCase().compareTo(b.name.toLowerCase());
    switch (_sort) {
      case _MemberSort.nameAsc:
        list.sort(byName);
        break;
      case _MemberSort.recentlyContacted:
        list.sort((a, b) {
          final la = _effectiveLastContacted(a);
          final lb = _effectiveLastContacted(b);
          if (la == null && lb == null) return byName(a, b);
          if (la == null) return 1; // never-contacted sink to the bottom
          if (lb == null) return -1;
          return lb.compareTo(la); // most recent first
        });
        break;
      case _MemberSort.leastRecentlyContacted:
        list.sort((a, b) {
          final la = _effectiveLastContacted(a);
          final lb = _effectiveLastContacted(b);
          if (la == null && lb == null) return byName(a, b);
          if (la == null) return -1; // never-contacted are the most overdue
          if (lb == null) return 1;
          return la.compareTo(lb); // oldest first
        });
        break;
    }
  }

  List<Member> get _selectedTextable => _d.members
      .where((m) => _selectedIds.contains(m.id) && m.canContact)
      .toList();

  List<Member> get _selectedEmailable => _d.members
      .where((m) =>
          _selectedIds.contains(m.id) && (m.preferredEmail ?? '').isNotEmpty)
      .toList();

  /// Every selected member, regardless of contact capability — seeds the
  /// outreach sheet's participant roster.
  List<Member> get _selectedMembers =>
      _d.members.where((m) => _selectedIds.contains(m.id)).toList();

  @override
  Widget build(BuildContext context) {
    final p = _Palette.of(context);
    switch (widget.pane) {
      case VolunteersPane.candidates:
        return _buildCandidatesPane(context, p);
      case VolunteersPane.members:
        return _buildMembersPane(context, p);
      case VolunteersPane.statewide:
      case VolunteersPane.combined:
        return _buildCombined(context, p);
    }
  }

  /// Mobile draggable sheet: candidates then members in one scroll, action bar
  /// pinned below.
  Widget _buildCombined(BuildContext context, _Palette p) {
    _seedIfNeeded();
    final textCount = _selectedTextable.length;
    final emailCount = _selectedEmailable.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(p),
        Expanded(
          child: ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            children: [
              _sectionHeader(p, 'ON THE NOVEMBER BALLOT'),
              const SizedBox(height: 12),
              _candidateSection(context, p),
              const SizedBox(height: 24),
              RegionOutreachSection(mode: _d.mode, regionId: _d.id),
              const SizedBox(height: 24),
              _membersSection(context, p),
            ],
          ),
        ),
        _actionBar(context, p, textCount: textCount, emailCount: emailCount),
      ],
    );
  }

  /// Desktop left pane: November nominee cards only. No member selection here.
  Widget _buildCandidatesPane(BuildContext context, _Palette p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _candidatesHeader(p),
        Expanded(
          child: ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            children: [
              _candidateSection(context, p),
            ],
          ),
        ),
      ],
    );
  }

  /// Desktop right pane: members list, outreach and the pinned action bar. This
  /// pane owns the member-selection state.
  Widget _buildMembersPane(BuildContext context, _Palette p) {
    _seedIfNeeded();
    final textCount = _selectedTextable.length;
    final emailCount = _selectedEmailable.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(p),
        Expanded(
          child: ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            children: [
              RegionOutreachSection(mode: _d.mode, regionId: _d.id),
              const SizedBox(height: 24),
              _membersSection(context, p),
            ],
          ),
        ),
        _actionBar(context, p, textCount: textCount, emailCount: emailCount),
      ],
    );
  }

  // ── header ──────────────────────────────────────────────────────
  Widget _header(_Palette p) {
    final texting = _d.members.where((m) => m.canContact).length;
    final emailing =
        _d.members.where((m) => (m.preferredEmail ?? '').isNotEmpty).length;

    return Container(
      constraints: const BoxConstraints(minHeight: 116),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      color: MoydMapTheme.navy,
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
                    Text(_d.mode.overline,
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4)),
                    const SizedBox(height: 3),
                    Text(_d.mode.regionTitle(_d.id),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            height: 1.1)),
                    const SizedBox(height: 8),
                    // gold underline
                    Container(
                      width: 44,
                      height: 3,
                      decoration: BoxDecoration(
                        color: MoydMapTheme.gold,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.showCloseButton)
                Semantics(
                  button: true,
                  label: 'Close detail panel',
                  child: InkWell(
                    onTap: widget.onClose,
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _headerStat('👥', '${_d.memberCount} member'
                  '${_d.memberCount == 1 ? '' : 's'}'),
              _headerStat('💬', '$texting can text'),
              _headerStat('✉', '$emailing can email'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerStat(String glyph, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
        ),
        child: Text('$glyph  $label',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700)),
      );

  // ── candidates-pane header (desktop left) ───────────────────────
  Widget _candidatesHeader(_Palette p) {
    return Container(
      constraints: const BoxConstraints(minHeight: 116),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      color: MoydMapTheme.navy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('ON THE NOVEMBER BALLOT',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4)),
          const SizedBox(height: 3),
          Text(_d.mode.regionTitle(_d.id),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1.1)),
          const SizedBox(height: 8),
          Container(
            width: 44,
            height: 3,
            decoration: BoxDecoration(
              color: MoydMapTheme.gold,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  // ── candidate section ───────────────────────────────────────────
  Widget _candidateSection(BuildContext context, _Palette p) {
    if (_d.loadingCandidates) {
      return _panelSpinner(p, 'Loading November candidates…');
    }
    final groups =
        _d.candidateGroups.where((g) => g.rows.isNotEmpty).toList();
    if (groups.isEmpty) {
      final noDem = _d.status == RegionStatus.noDem;
      return _emptyBox(
        p,
        circle: (noDem ? MapPalette.statusNoDem : MoydMapTheme.unityBlue)
            .withValues(alpha: 0.14),
        icon: noDem ? Icons.person_off_outlined : Icons.how_to_vote_outlined,
        iconColor: MoydMapTheme.unityBlue,
        title: noDem
            ? 'No Democrat filed here'
            : _d.status == RegionStatus.notOnBallot
                ? 'This seat is not on the 2026 ballot'
                : 'No candidates on record for this race',
        body: noDem
            ? 'No Democrat advanced from the August 4 primary in this district.'
            : 'The August 4 primary results list no candidates for this area.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < groups.length; i++) ...[
          if (i > 0) const SizedBox(height: 18),
          _candidateGroup(context, p, groups[i], showHeader: groups.length > 1),
        ],
      ],
    );
  }

  Widget _candidateGroup(
    BuildContext context,
    _Palette p,
    CandidateDisplayGroup group, {
    required bool showHeader,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader) ...[
          Row(
            children: [
              Flexible(
                child: Text(group.officeTypeLabel.toUpperCase(),
                    style: TextStyle(
                        color: p.secondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0)),
              ),
              const SizedBox(width: 8),
              ...group.districtChips.map((c) => Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: _districtChip(p, c),
                  )),
            ],
          ),
          const SizedBox(height: 10),
        ],
        for (final row in group.rows) _candidateCard(context, p, row),
      ],
    );
  }

  Widget _districtChip(_Palette p, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: MoydMapTheme.unityBlue.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label,
            style: const TextStyle(
                color: MoydMapTheme.unityBlue,
                fontSize: 10.5,
                fontWeight: FontWeight.w800)),
      );

  Widget _candidateCard(BuildContext context, _Palette p, CandidateDisplayRow row) {
    final name = row.candidate?.name ??
        row.result?.candidateName ??
        'Unknown candidate';
    final office = row.candidate?.officeDisplay ?? row.result?.officeRaw ?? '';
    final party =
        row.candidate?.partyShort ?? row.result?.partyShort ?? '?';
    final photo = row.candidate?.effectivePhotoUrl;

    void open() {
      if (!row.tappable) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CandidateDetailScreen(candidate: row.candidate!),
      ));
    }

    final card = Container(
      decoration: BoxDecoration(
        color: p.inset,
        borderRadius: BorderRadius.circular(14),
        border: row.isNominee
            ? Border.all(color: MoydMapTheme.gold, width: 1.4)
            : Border.all(color: p.divider),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _candidateAvatar(name, photo),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        _partyChip(party),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: p.text,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700)),
                        ),
                        if (row.isNominee) ...[
                          const SizedBox(width: 8),
                          _nomineeBadge(party),
                        ],
                      ],
                    ),
                    if (office.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(office,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: p.secondary, fontSize: 12.5)),
                    ],
                  ],
                ),
              ),
              if (row.tappable)
                Icon(Icons.chevron_right,
                    color: p.secondary.withValues(alpha: 0.6), size: 18),
            ],
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: row.tappable
          ? Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: open,
                borderRadius: BorderRadius.circular(14),
                child: card,
              ),
            )
          : card,
    );
  }

  Widget _candidateAvatar(String name, String? url) {
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: 28,
        backgroundColor: MapPalette.avatarColorFor(name),
        backgroundImage: NetworkImage(url),
        onBackgroundImageError: (_, __) {},
        child: null,
      );
    }
    return CircleAvatar(
      radius: 28,
      backgroundColor: MapPalette.avatarColorFor(name),
      child: Text(_initials(name),
          style: const TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
    );
  }

  Widget _partyChip(String letter) => Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: MapPalette.partyChipColor(letter),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(letter,
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
      );

  /// Party-coded NOMINEE pill, mirroring the shipped candidates list: white
  /// caps on the party chip colour. [partyShort] is the candidate's or result's
  /// one-letter party ('D'/'R'/'L'/…), '?' when unknown.
  Widget _nomineeBadge(String partyShort) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: MapPalette.partyChipColor(partyShort),
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Text('NOMINEE',
            style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4)),
      );

  // ── members section (real multi-select) ─────────────────────────
  Widget _membersSection(BuildContext context, _Palette p) {
    if (_d.loadingMembers) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(p, 'MOYD MEMBERS'),
          const SizedBox(height: 12),
          _panelSpinner(p, 'Finding members…'),
        ],
      );
    }

    if (_d.members.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(p, 'MOYD MEMBERS (0)'),
          const SizedBox(height: 12),
          _emptyBox(
            p,
            circle: MoydMapTheme.unityBlue.withValues(alpha: 0.12),
            icon: Icons.group_add_outlined,
            iconColor: MoydMapTheme.unityBlue,
            title: 'No members here yet',
            body: 'No MOYD members live in this area on record.',
          ),
        ],
      );
    }

    final displayed = _displayed;
    final total = _d.members.length;
    final filteredCount = displayed.length;
    final displayedSelectable = displayed.where(_isSelectable).toList();
    final selectedInDisplay = displayedSelectable
        .where((m) => _selectedIds.contains(m.id))
        .length;
    final bool? headerTri = displayedSelectable.isEmpty
        ? false
        : selectedInDisplay == 0
            ? false
            : selectedInDisplay == displayedSelectable.length
                ? true
                : null;

    final filteredTextable = displayed.where((m) => m.canContact).length;
    final filteredEmailable =
        displayed.where((m) => (m.preferredEmail ?? '').isNotEmpty).length;

    // Header count and summary reflect the currently filtered set, showing the
    // total too when it differs (e.g. "MOYD MEMBERS (12 of 41)").
    final headerCount = _anyFilterActive && filteredCount != total
        ? '$filteredCount of $total'
        : '$total';

    final selectAllLabel = _anyFilterActive
        ? 'Select all $filteredCount filtered'
        : 'Select all';

    final visible = _expanded ? displayed : displayed.take(_initialCap).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(p, 'MOYD MEMBERS ($headerCount)'),
        const SizedBox(height: 6),
        Text('$filteredTextable textable · $filteredEmailable emailable',
            style: TextStyle(color: p.secondary, fontSize: 12)),
        const SizedBox(height: 10),
        // Select-all-filtered + live selection count
        Row(
          children: [
            SizedBox(
              width: 34,
              child: Checkbox(
                value: headerTri,
                tristate: true,
                activeColor: MoydMapTheme.unityBlue,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: displayedSelectable.isEmpty
                    ? null
                    : (_) => _toggleAllDisplayed(displayedSelectable),
              ),
            ),
            Flexible(
              child: Text(selectAllLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: p.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ),
            const Spacer(),
            if (_selectedIds.isNotEmpty)
              Text('${_selectedIds.length} selected',
                  style: TextStyle(
                      color: p.action,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 8),
        // Filter + sort chips (§5)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _filterChip(p, 'Textable', _canTextFilter,
                () => setState(() => _canTextFilter = !_canTextFilter)),
            _filterChip(p, 'Emailable', _canEmailFilter,
                () => setState(() => _canEmailFilter = !_canEmailFilter)),
            _menuChip(p, _committeeChipLabel(), _committeeFilter.isNotEmpty,
                _openCommitteeFilter),
            _menuChip(p, _lastContactedChipLabel(),
                _lastContacted != _LastContactedFilter.any,
                _openLastContactedFilter),
            _menuChip(p, _sortChipLabel(), false, _openSortMenu),
          ],
        ),
        const SizedBox(height: 12),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('No members match these filters.',
                style: TextStyle(color: p.secondary, fontSize: 12.5)),
          )
        else
          ...visible.map((m) => _memberRow(context, p, m)),
        if (displayed.length > _initialCap && !_expanded)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: TextButton(
              onPressed: () => setState(() => _expanded = true),
              child: Text('Show all ${displayed.length}',
                  style: TextStyle(
                      color: p.action,
                      fontWeight: FontWeight.w700)),
            ),
          ),
      ],
    );
  }

  String _committeeChipLabel() {
    final n = _committeeFilter.length;
    if (n == 0) return 'Committee';
    return n == 1 ? '1 committee' : '$n committees';
  }

  String _lastContactedChipLabel() {
    switch (_lastContacted) {
      case _LastContactedFilter.any:
        return 'Last contacted';
      case _LastContactedFilter.never:
        return 'Never contacted';
      case _LastContactedFilter.notIn30:
        return 'Not in 30 days';
    }
  }

  String _sortChipLabel() {
    switch (_sort) {
      case _MemberSort.nameAsc:
        return 'Sort: Name';
      case _MemberSort.recentlyContacted:
        return 'Sort: Recent';
      case _MemberSort.leastRecentlyContacted:
        return 'Sort: Least recent';
    }
  }

  // ── filter/sort menus ───────────────────────────────────────────
  Future<void> _openCommitteeFilter() async {
    if (_committees.isEmpty && !_loadingCommittees) {
      await _loadCommittees();
    }
    if (!mounted) return;
    final temp = Set<String>.from(_committeeFilter);
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Filter by committee'),
        content: SizedBox(
          width: double.maxFinite,
          child: _committees.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('No committees on file.'))
              : StatefulBuilder(
                  builder: (context, setDialogState) => ListView(
                    shrinkWrap: true,
                    children: _committees
                        .map((c) => CheckboxListTile(
                              dense: true,
                              value: temp.contains(c),
                              title: Text(c),
                              onChanged: (v) => setDialogState(() {
                                if (v == true) {
                                  temp.add(c);
                                } else {
                                  temp.remove(c);
                                }
                              }),
                            ))
                        .toList(),
                  ),
                ),
        ),
        actions: [
          if (_committeeFilter.isNotEmpty || temp.isNotEmpty)
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, <String>{}),
                child: const Text('Clear')),
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, temp),
              child: const Text('Apply')),
        ],
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _committeeFilter
          ..clear()
          ..addAll(result);
      });
    }
  }

  Future<void> _openLastContactedFilter() async {
    final result = await showDialog<_LastContactedFilter>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Last contacted'),
        children: [
          _radioOption(dialogContext, _LastContactedFilter.any, _lastContacted,
              'Any'),
          _radioOption(dialogContext, _LastContactedFilter.never,
              _lastContacted, 'Never contacted'),
          _radioOption(dialogContext, _LastContactedFilter.notIn30,
              _lastContacted, 'Not contacted in 30 days'),
        ],
      ),
    );
    if (result != null && mounted) {
      setState(() => _lastContacted = result);
    }
  }

  Future<void> _openSortMenu() async {
    final result = await showDialog<_MemberSort>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Sort members'),
        children: [
          _radioOption(dialogContext, _MemberSort.nameAsc, _sort, 'Name (A–Z)'),
          _radioOption(dialogContext, _MemberSort.recentlyContacted, _sort,
              'Recently contacted'),
          _radioOption(dialogContext, _MemberSort.leastRecentlyContacted, _sort,
              'Least recently contacted'),
        ],
      ),
    );
    if (result != null && mounted) {
      setState(() => _sort = result);
    }
  }

  Widget _radioOption<T>(
      BuildContext ctx, T value, T groupValue, String label) {
    final selected = value == groupValue;
    return ListTile(
      dense: true,
      title: Text(label),
      trailing: selected
          ? const Icon(Icons.check, color: MoydMapTheme.unityBlue)
          : null,
      onTap: () => Navigator.pop(ctx, value),
    );
  }

  void _toggleAllDisplayed(List<Member> displayedSelectable) {
    final anySelected =
        displayedSelectable.any((m) => _selectedIds.contains(m.id));
    setState(() {
      if (anySelected) {
        for (final m in displayedSelectable) {
          _selectedIds.remove(m.id);
        }
      } else {
        for (final m in displayedSelectable) {
          _selectedIds.add(m.id);
        }
      }
    });
  }

  Widget _filterChip(_Palette p, String label, bool active, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: active ? MoydMapTheme.unityBlue : p.inset,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
                color: active ? MoydMapTheme.unityBlue : p.divider),
          ),
          child: Text(label,
              style: TextStyle(
                  color: active ? Colors.white : p.text,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  /// Like [_filterChip] but carries a dropdown affordance, for chips that open
  /// a menu (Committee / Last contacted / Sort) rather than toggling.
  Widget _menuChip(_Palette p, String label, bool active, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
          decoration: BoxDecoration(
            color: active ? MoydMapTheme.unityBlue : p.inset,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
                color: active ? MoydMapTheme.unityBlue : p.divider),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: TextStyle(
                      color: active ? Colors.white : p.text,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700)),
              const SizedBox(width: 2),
              Icon(Icons.arrow_drop_down,
                  size: 18, color: active ? Colors.white : p.secondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _memberRow(BuildContext context, _Palette p, Member m) {
    final selectable = _isSelectable(m);
    final selected = _selectedIds.contains(m.id);
    final canText = m.canContact;
    final canEmail = (m.preferredEmail ?? '').isNotEmpty;
    final sub = _memberSubline(m);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Checkbox(
              value: selected,
              activeColor: MoydMapTheme.unityBlue,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: selectable
                  ? (v) => setState(() {
                        if (v == true) {
                          _selectedIds.add(m.id);
                        } else {
                          _selectedIds.remove(m.id);
                        }
                      })
                  : null,
            ),
          ),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => MemberDetailScreen(member: m),
                )),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  child: Row(
                    children: [
                      _memberAvatar(m),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(m.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: p.text,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w600)),
                            if (sub.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(sub,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: p.secondary, fontSize: 12)),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (canText)
                        Icon(Icons.sms_outlined,
                            size: 16,
                            color: p.secondary.withValues(alpha: 0.85)),
                      if (canEmail) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.email_outlined,
                            size: 16,
                            color: p.secondary.withValues(alpha: 0.85)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _memberSubline(Member m) {
    final district = _memberDistrictLabel(m);
    return [
      if ((m.county ?? '').isNotEmpty) '${m.county} County',
      if (district != null) district,
    ].join(' · ');
  }

  String? _memberDistrictLabel(Member m) {
    switch (_d.mode) {
      case MapMode.county:
      case MapMode.congressional:
        final cd = m.congressionalDistrict;
        return (cd ?? '').isNotEmpty ? cd : null;
      case MapMode.house:
        final hd = m.houseDistrict;
        return (hd ?? '').isNotEmpty ? 'HD $hd' : null;
      case MapMode.senate:
        final sd = m.senateDistrict;
        return (sd ?? '').isNotEmpty ? 'SD $sd' : null;
    }
  }

  Widget _memberAvatar(Member m) {
    final url = m.effectiveAvatarUrl;
    if (url != null && url.isNotEmpty) {
      return ClipOval(
        child: Image.network(url,
            width: 36,
            height: 36,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _memberInitials(m)),
      );
    }
    return _memberInitials(m);
  }

  Widget _memberInitials(Member m) => Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: MapPalette.avatarColorFor(m.id),
          shape: BoxShape.circle,
        ),
        child: Text(_initials(m.name),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
      );

  // ── pinned action bar ───────────────────────────────────────────
  Widget _actionBar(BuildContext context, _Palette p,
      {required int textCount, required int emailCount}) {
    final selected = _selectedMembers;
    final selCount = selected.length;
    // Skip counts operate on the whole selection, independent of the filter.
    final cantText = selected.where((m) => !m.canContact).length;
    final cantEmail =
        selected.where((m) => (m.preferredEmail ?? '').isEmpty).length;

    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.divider)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selCount > 0) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$selCount selected · $textCount textable · $emailCount emailable',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: p.text,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => setState(() => _selectedIds.clear()),
                  child: Text('Clear',
                      style: TextStyle(
                          color: p.action,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          // Skip-reason surfacing (§5.3): the Text/Email buttons still send
          // only to the eligible subset; these lines explain who is excluded.
          if (selCount > 0 && cantText > 0)
            _skipLine(
                p,
                "$cantText of $selCount can't be texted: no phone or opted out",
                () => _showSkipDetails(context, isText: true)),
          if (selCount > 0 && cantEmail > 0)
            _skipLine(
                p,
                "$cantEmail of $selCount can't be emailed: no email on file",
                () => _showSkipDetails(context, isText: false)),
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  icon: Icons.sms_outlined,
                  label: 'Text ($textCount)',
                  enabled: textCount > 0,
                  onTap: () => widget.onTextMembers(_selectedTextable),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _actionButton(
                  icon: Icons.email_outlined,
                  label: 'Email ($emailCount)',
                  enabled: emailCount > 0,
                  onTap: () => widget.onEmailMembers(_selectedEmailable),
                ),
              ),
              if (selCount > 0) ...[
                const SizedBox(width: 10),
                _moreMenu(context, p),
              ],
            ],
          ),
          if (widget.onLogOutreach != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () => widget.onLogOutreach!(_selectedMembers),
                icon: const Icon(Icons.edit_note_outlined, size: 18),
                label: const Text('Log outreach'),
                style: TextButton.styleFrom(
                  foregroundColor: p.action,
                  textStyle: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13.5),
                  minimumSize: const Size(0, 40),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _skipLine(_Palette p, String text, VoidCallback onDetails) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 14, color: p.secondary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                style: TextStyle(color: p.secondary, fontSize: 11.5)),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: onDetails,
            child: Text('Details',
                style: TextStyle(
                    color: p.action,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _moreMenu(BuildContext context, _Palette p) {
    return Material(
      color: p.inset,
      borderRadius: BorderRadius.circular(12),
      child: PopupMenuButton<String>(
        tooltip: 'More actions',
        position: PopupMenuPosition.under,
        onSelected: (value) {
          switch (value) {
            case 'activity':
              _openAddToActivity(context);
              break;
            case 'mark':
              _markContactedToday(context);
              break;
            case 'note':
              _recordContactNote(context);
              break;
            case 'copy':
              _copyNames(context);
              break;
            case 'csv':
              _exportCsv(context);
              break;
          }
        },
        itemBuilder: (context) => [
          _moreItem('activity', Icons.playlist_add_outlined, 'Add to activity'),
          _moreItem('mark', Icons.event_available_outlined,
              'Mark contacted today'),
          _moreItem('note', Icons.note_add_outlined, 'Record contact note'),
          _moreItem('copy', Icons.copy_all_outlined, 'Copy names'),
          _moreItem('csv', Icons.download_outlined, 'Export CSV'),
        ],
        child: Container(
          height: 46,
          width: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: p.divider),
          ),
          child: Icon(Icons.more_vert, size: 20, color: p.text),
        ),
      ),
    );
  }

  PopupMenuItem<String> _moreItem(String value, IconData icon, String label) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 10),
          Text(label),
        ],
      ),
    );
  }

  // ── add-to-activity (§5.3) ──────────────────────────────────────
  // Adds the current selection to an existing planned/in-progress activity in
  // this region, or seeds the create sheet pre-filled with the selection and
  // the region's geography. The picker sheet returns the user's choice; this
  // method is the only place that touches the map's region context, so the
  // sheet stays region-agnostic.
  Future<void> _openAddToActivity(BuildContext context) async {
    final members = _selectedMembers;
    if (members.isEmpty) return;

    final choice = await showModalBottomSheet<_AddToActivityChoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddToActivitySheet(
        mode: _d.mode,
        regionId: _d.id,
        members: members,
      ),
    );
    if (!mounted || choice == null) return;

    switch (choice.kind) {
      case _AddToActivityKind.added:
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(choice.addedCount > 0
              ? 'Added ${choice.addedCount} to ${choice.title}'
              : 'All selected members were already on ${choice.title}'),
        ));
        break;
      case _AddToActivityKind.newActivity:
        // Seed the create sheet with the selection and the region's single geo
        // key; the other three geo lists stay empty. Candidates are Phase 4.
        await OutreachLogSheet.show(
          context,
          participants: members,
          counties: _d.mode == MapMode.county ? [_d.id] : const <String>[],
          congressionalDistricts:
              _d.mode == MapMode.congressional ? [_d.id] : const <String>[],
          houseDistricts:
              _d.mode == MapMode.house ? [_d.id] : const <String>[],
          senateDistricts:
              _d.mode == MapMode.senate ? [_d.id] : const <String>[],
          titleSuggestion:
              '${OutreachDisplay.kinds.values.first.label}: ${_d.mode.regionTitle(_d.id)}',
        );
        break;
    }
  }

  String _textSkipReason(Member m) {
    if (m.optOut) return 'opted out';
    if ((m.phoneE164 ?? '').isEmpty) return 'no phone';
    if (m.membershipEligible != true) return 'not eligible';
    return 'cannot be texted';
  }

  Future<void> _showSkipDetails(BuildContext context,
      {required bool isText}) async {
    final skipped = isText
        ? _selectedMembers.where((m) => !m.canContact).toList()
        : _selectedMembers
            .where((m) => (m.preferredEmail ?? '').isEmpty)
            .toList();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isText ? "Can't be texted" : "Can't be emailed"),
        content: SizedBox(
          width: double.maxFinite,
          child: skipped.isEmpty
              ? const Text('No skipped members.')
              : ListView(
                  shrinkWrap: true,
                  children: skipped
                      .map((m) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(m.name),
                            subtitle: Text(
                                isText ? _textSkipReason(m) : 'no email on file'),
                          ))
                      .toList(),
                ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close')),
        ],
      ),
    );
  }

  String _todayStamp() {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)}';
  }

  Future<void> _markContactedToday(BuildContext context) async {
    final members = _selectedMembers;
    if (members.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final now = DateTime.now();
    var ok = 0;
    var failed = 0;
    for (final m in members) {
      try {
        await _repo.updateLastContacted(m.id);
        _lastContactedOverride[m.id] = now;
        ok++;
      } catch (_) {
        failed++;
      }
    }
    if (!mounted) return;
    setState(() {});
    messenger.showSnackBar(SnackBar(
      content: Text(failed == 0
          ? 'Marked $ok as contacted today'
          : 'Marked $ok as contacted, $failed failed'),
    ));
  }

  Future<void> _recordContactNote(BuildContext context) async {
    final members = _selectedMembers;
    if (members.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final controller = TextEditingController();
    var alsoContacted = true;

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
              'Record note · ${members.length} member${members.length == 1 ? '' : 's'}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  hintText: 'Note (appended to each member\'s existing notes)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: alsoContacted,
                title: const Text('Also mark as contacted today'),
                onChanged: (v) =>
                    setDialogState(() => alsoContacted = v ?? false),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Save')),
          ],
        ),
      ),
    );

    final entry = controller.text.trim();
    controller.dispose();
    if (save != true || entry.isEmpty || !mounted) return;

    final today = _todayStamp();
    final now = DateTime.now();
    var ok = 0;
    var failed = 0;
    for (final m in members) {
      try {
        // NEVER replace notes: append to the member's existing notes. Read the
        // current notes (override wins so repeated appends chain), then append.
        final base = (_effectiveNotes(m) ?? '').trim();
        final appended = '$base\n[$today] $entry'.trim();
        await _repo.updateNotes(m.id, appended);
        _notesOverride[m.id] = appended;
        if (alsoContacted) {
          await _repo.updateLastContacted(m.id);
          _lastContactedOverride[m.id] = now;
        }
        ok++;
      } catch (_) {
        failed++;
      }
    }
    if (!mounted) return;
    setState(() {});
    messenger.showSnackBar(SnackBar(
      content: Text(failed == 0
          ? 'Saved note for $ok member${ok == 1 ? '' : 's'}'
          : 'Saved note for $ok, $failed failed'),
    ));
  }

  Future<void> _copyNames(BuildContext context) async {
    final members = _selectedMembers;
    if (members.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(
        ClipboardData(text: members.map((m) => m.name).join('\n')));
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(
      content: Text(
          'Copied ${members.length} name${members.length == 1 ? '' : 's'}'),
    ));
  }

  Future<void> _exportCsv(BuildContext context) async {
    final members = _selectedMembers;
    if (members.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    var includePii = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Export CSV'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'Export ${members.length} selected member${members.length == 1 ? '' : 's'}.'),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: includePii,
                title: const Text('Include phone and email'),
                subtitle:
                    const Text('Personal contact data will leave the system.'),
                onChanged: (v) => setDialogState(() => includePii = v ?? false),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Export')),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    final headers = <String>[
      'name',
      'county',
      'congressional_district',
      'house_district',
      'senate_district',
      'textable',
      'emailable',
    ];
    if (includePii) {
      headers
        ..add('phone_e164')
        ..add('preferred_email');
    }

    final buffer = StringBuffer();
    buffer.writeln(headers.map(_csvEscape).join(','));
    for (final m in members) {
      final row = <String>[
        m.name,
        m.county ?? '',
        m.congressionalDistrict ?? '',
        m.houseDistrict ?? '',
        m.senateDistrict ?? '',
        m.canContact ? 'yes' : 'no',
        (m.preferredEmail ?? '').isNotEmpty ? 'yes' : 'no',
      ];
      if (includePii) {
        row
          ..add(m.phoneE164 ?? '')
          ..add(m.preferredEmail ?? '');
      }
      buffer.writeln(row.map(_csvEscape).join(','));
    }

    if (!kIsWeb) {
      messenger.showSnackBar(const SnackBar(
          content: Text('CSV export is only available on the web app.')));
      return;
    }

    try {
      final blob = html.Blob([buffer.toString()], 'text/csv;charset=utf-8');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', 'members-${_todayStamp()}.csv')
        ..style.display = 'none';
      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();
      html.Url.revokeObjectUrl(url);
      messenger.showSnackBar(SnackBar(
        content: Text(
            'Exported ${members.length} member${members.length == 1 ? '' : 's'}'),
      ));
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('CSV export failed: $e')));
    }
  }

  /// Minimal RFC-4180-ish CSV field escape: quote fields containing a comma,
  /// quote, or newline and double embedded quotes.
  String _csvEscape(String value) {
    if (value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: MoydMapTheme.unityBlue,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 46,
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 17, color: Colors.white),
                const SizedBox(width: 7),
                Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── shared building blocks ─────────────────────────────────────────
Widget _sectionHeader(_Palette p, String label) => Row(
      children: [
        Container(
          width: 20,
          height: 3,
          decoration: BoxDecoration(
            color: MoydMapTheme.gold,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(label,
              style: TextStyle(
                  color: p.secondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1)),
        ),
      ],
    );

Widget _panelSpinner(_Palette p, String label) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 26),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: MoydMapTheme.unityBlue),
            ),
            const SizedBox(height: 12),
            Text(label, style: TextStyle(color: p.secondary, fontSize: 12.5)),
          ],
        ),
      ),
    );

Widget _emptyBox(
  _Palette p, {
  required Color circle,
  required IconData icon,
  required Color iconColor,
  required String title,
  required String body,
  Widget? action,
}) {
  return Container(
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: p.inset,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: p.divider),
    ),
    child: Column(
      children: [
        Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: circle, shape: BoxShape.circle),
          child: Icon(icon, color: iconColor, size: 28),
        ),
        const SizedBox(height: 14),
        Text(title,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: p.text, fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(body,
            textAlign: TextAlign.center,
            style: TextStyle(color: p.secondary, fontSize: 12.5)),
        if (action != null) ...[
          const SizedBox(height: 16),
          action,
        ],
      ],
    ),
  );
}

String _initials(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  final first = parts.first[0];
  final last = parts.length > 1 ? parts.last[0] : '';
  return (first + last).toUpperCase();
}

// ═══════════════════════════════════════════════════════════════
//  ADD-TO-ACTIVITY PICKER — the modal that lets the members action bar drop
//  the current selection onto an existing region activity, or open the create
//  sheet pre-seeded. Returns a [_AddToActivityChoice]; the panel does the
//  region-aware follow-up (snackbar or create sheet). Null on dismiss.
// ═══════════════════════════════════════════════════════════════

enum _AddToActivityKind { added, newActivity }

class _AddToActivityChoice {
  const _AddToActivityChoice.added(this.addedCount, this.title)
      : kind = _AddToActivityKind.added;
  const _AddToActivityChoice.newActivity()
      : kind = _AddToActivityKind.newActivity,
        addedCount = 0,
        title = '';

  final _AddToActivityKind kind;

  /// New participant rows the repository actually inserted (0 when every
  /// selected member was already on the activity).
  final int addedCount;
  final String title;
}

class _AddToActivitySheet extends StatefulWidget {
  const _AddToActivitySheet({
    required this.mode,
    required this.regionId,
    required this.members,
  });

  final MapMode mode;
  final String regionId;
  final List<Member> members;

  @override
  State<_AddToActivitySheet> createState() => _AddToActivitySheetState();
}

class _AddToActivitySheetState extends State<_AddToActivitySheet> {
  final OutreachRepository _repo = OutreachRepository();

  List<OutreachActivity> _activities = const [];
  bool _loading = true;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await _repo.activitiesForRegion(widget.mode, widget.regionId);
      if (!mounted) return;
      // Only the actionable activities: planned or in progress. Filtered
      // client-side so the repository stays a plain region query.
      setState(() {
        _activities = rows
            .where((a) => a.status == 'planned' || a.status == 'in_progress')
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _activities = const [];
        _loading = false;
      });
    }
  }

  Future<void> _addTo(OutreachActivity activity) async {
    if (_adding) return;
    setState(() => _adding = true);
    final inputs = widget.members
        .map((m) => OutreachParticipantInput(memberId: m.id))
        .toList();
    int added;
    try {
      // PINNED: addParticipants dedupes on (activity_id, member_id) and returns
      // the count of newly inserted rows.
      added = await _repo.addParticipants(activity.id, inputs);
    } catch (_) {
      added = 0;
    }
    if (!mounted) return;
    Navigator.of(context)
        .pop(_AddToActivityChoice.added(added, activity.title));
  }

  @override
  Widget build(BuildContext context) {
    final p = _Palette.of(context);
    final media = MediaQuery.of(context);
    final maxHeight = media.size.height * 0.8;
    final n = widget.members.length;

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Container(
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _header(n),
              Flexible(
                child: _loading
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: MoydMapTheme.unityBlue),
                          ),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                        children: [
                          _newActivityTile(p),
                          const SizedBox(height: 12),
                          if (_activities.isEmpty)
                            _emptyNote(p)
                          else
                            ...[for (final a in _activities) _activityRow(p, a)],
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(int n) => Container(
        color: MoydMapTheme.navy,
        padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.playlist_add, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Add $n member${n == 1 ? '' : 's'} to an activity',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 5),
                  Container(
                    width: 40,
                    height: 3,
                    decoration: BoxDecoration(
                      color: MoydMapTheme.gold,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
            InkWell(
              onTap: () => Navigator.of(context).pop(),
              borderRadius: BorderRadius.circular(18),
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
      );

  Widget _newActivityTile(_Palette p) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _adding
              ? null
              : () => Navigator.of(context)
                  .pop(const _AddToActivityChoice.newActivity()),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: MoydMapTheme.unityBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: MoydMapTheme.unityBlue.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Icon(Icons.add_circle_outline, size: 20, color: p.action),
                const SizedBox(width: 12),
                Text('New activity',
                    style: TextStyle(
                        color: p.action,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ),
      );

  Widget _emptyNote(_Palette p) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: p.inset,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: p.divider),
        ),
        child: Text('No planned activities in this region yet.',
            style: TextStyle(color: p.secondary, fontSize: 12.5)),
      );

  Widget _activityRow(_Palette p, OutreachActivity a) {
    final kind = OutreachDisplay.kinds[a.kind];
    final status = OutreachDisplay.statuses[a.status];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _adding ? null : () => _addTo(a),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: p.inset,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: p.divider),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: MoydMapTheme.unityBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(kind?.icon ?? a.kindIcon,
                      size: 18, color: MoydMapTheme.unityBlue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(a.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: p.text,
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                      if (a.scheduledOn != null) ...[
                        const SizedBox(height: 2),
                        Text(_fmtDate(a.scheduledOn!),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                TextStyle(color: p.secondary, fontSize: 12)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: status?.color ?? a.statusColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(status?.label ?? a.statusLabel,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _fmtDate(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';
}
