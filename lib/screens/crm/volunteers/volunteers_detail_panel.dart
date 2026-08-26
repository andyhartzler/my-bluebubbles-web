import 'package:flutter/material.dart';

import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/screens/crm/candidate_detail_screen.dart';
import 'package:bluebubbles/screens/crm/member_detail_screen.dart';

import 'volunteers_map_models.dart';

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
        track = isDark ? const Color(0xFF313D5E) : const Color(0xFFDFE4EC);

  final bool isDark;
  final Color surface;
  final Color inset;
  final Color text;
  final Color secondary;
  final Color divider;
  final Color track;

  factory _Palette.of(BuildContext c) =>
      _Palette(Theme.of(c).brightness == Brightness.dark);
}

class VolunteersDetailPanel extends StatelessWidget {
  const VolunteersDetailPanel({
    super.key,
    this.detail,
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

  final int statewideMembers;
  final int statewideYoungDems;
  final List<HotRegion> hotRegions;

  final VoidCallback onClose;
  final void Function(MapMode mode, String id) onSelectHot;

  /// Existing bulk-send callbacks — signatures unchanged. The action bar
  /// filters the current selection to valid members and calls these.
  final void Function(List<Member> members) onTextMembers;
  final void Function(List<Member> members) onEmailMembers;

  /// Layer 2 outreach logging. Null-safe: the "Log outreach" button is hidden
  /// entirely while this is null.
  final VoidCallback? onLogOutreach;

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
              key: ValueKey('${detail!.mode}:${detail!.id}'),
              detail: detail!,
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
    required this.onClose,
    required this.onTextMembers,
    required this.onEmailMembers,
    required this.onLogOutreach,
    required this.scrollController,
    required this.showCloseButton,
  });

  final RegionDetail detail;
  final VoidCallback onClose;
  final void Function(List<Member> members) onTextMembers;
  final void Function(List<Member> members) onEmailMembers;
  final VoidCallback? onLogOutreach;
  final ScrollController? scrollController;
  final bool showCloseButton;

  @override
  State<_RegionDetailView> createState() => _RegionDetailViewState();
}

class _RegionDetailViewState extends State<_RegionDetailView> {
  static const _initialCap = 30;

  final Set<String> _selectedIds = <String>{};
  bool _seeded = false;
  bool _expanded = false;
  bool _canTextFilter = false;
  bool _canEmailFilter = false;

  RegionDetail get _d => widget.detail;

  bool _isSelectable(Member m) =>
      m.canContact || (m.preferredEmail ?? '').isNotEmpty;

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

  List<Member> get _displayed {
    final all = _d.members;
    if (!_canTextFilter && !_canEmailFilter) return all;
    return all
        .where((m) =>
            (_canTextFilter && m.canContact) ||
            (_canEmailFilter && (m.preferredEmail ?? '').isNotEmpty))
        .toList();
  }

  List<Member> get _selectedTextable => _d.members
      .where((m) => _selectedIds.contains(m.id) && m.canContact)
      .toList();

  List<Member> get _selectedEmailable => _d.members
      .where((m) =>
          _selectedIds.contains(m.id) && (m.preferredEmail ?? '').isNotEmpty)
      .toList();

  @override
  Widget build(BuildContext context) {
    _seedIfNeeded();
    final p = _Palette.of(context);
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
              _sectionHeader(p, 'CANDIDATES — NOVEMBER GENERAL'),
              const SizedBox(height: 12),
              _candidateSection(context, p),
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
    final pct = (row.result?.pct ?? 0).clamp(0, 100).toDouble();
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
                          _nomineeBadge(),
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
          if (row.result != null) ...[
            const SizedBox(height: 10),
            _pctBar(p, pct),
            const SizedBox(height: 5),
            Text('${_thousands(row.result!.votes)}  ·  ${pct.toStringAsFixed(1)}%',
                style: TextStyle(
                    color: p.secondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600)),
          ],
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

  Widget _nomineeBadge() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: MoydMapTheme.gold,
          borderRadius: BorderRadius.circular(999),
        ),
        // navy on gold clears 4.5:1; gold is a fill here, never text.
        child: const Text('NOV NOMINEE ★',
            style: TextStyle(
                color: MoydMapTheme.navy,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3)),
      );

  Widget _pctBar(_Palette p, double pct) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Container(
        height: 6,
        color: p.track,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: (pct / 100).clamp(0.0, 1.0)),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: value,
              child: Container(color: MoydMapTheme.unityBlue),
            ),
          ),
        ),
      ),
    );
  }

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

    final visible = _expanded ? displayed : displayed.take(_initialCap).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(p, 'MOYD MEMBERS (${_d.members.length})'),
        const SizedBox(height: 10),
        // tri-state All + filter chips
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
            Text('All (${displayedSelectable.length})',
                style: TextStyle(
                    color: p.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
            const Spacer(),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _filterChip(p, 'Can text', _canTextFilter,
                () => setState(() => _canTextFilter = !_canTextFilter)),
            _filterChip(p, 'Can email', _canEmailFilter,
                () => setState(() => _canEmailFilter = !_canEmailFilter)),
          ],
        ),
        const SizedBox(height: 12),
        ...visible.map((m) => _memberRow(context, p, m)),
        if (displayed.length > _initialCap && !_expanded)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: TextButton(
              onPressed: () => setState(() => _expanded = true),
              child: Text('Show all ${displayed.length}',
                  style: const TextStyle(
                      color: MoydMapTheme.unityBlue,
                      fontWeight: FontWeight.w700)),
            ),
          ),
      ],
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
            ],
          ),
          if (widget.onLogOutreach != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: widget.onLogOutreach,
                icon: const Icon(Icons.edit_note_outlined, size: 18),
                label: const Text('Log outreach'),
                style: TextButton.styleFrom(
                  foregroundColor: MoydMapTheme.unityBlue,
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

String _thousands(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}
