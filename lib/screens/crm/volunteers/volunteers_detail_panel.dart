import 'package:flutter/material.dart';

import 'package:bluebubbles/models/crm/candidate.dart' show Candidate;
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/services/crm/election_results_repository.dart';

import 'volunteers_map_models.dart';

// ═══════════════════════════════════════════════════════════════
//  DETAIL PANEL — the right-hand rail (desktop) / draggable sheet body
//  (mobile). Renders a Statewide Overview when nothing is selected, or a
//  region detail (November candidates + resident members) when a region is.
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
class RegionDetail {
  const RegionDetail({
    required this.mode,
    required this.id,
    required this.status,
    required this.memberCount,
    required this.candidates,
    required this.members,
    required this.loadingCandidates,
    required this.loadingMembers,
    required this.youngDemNames,
  });

  final MapMode mode;
  final String id;
  final RegionStatus status;
  final int memberCount;
  final List<ElectionResult> candidates;
  final List<Member> members;
  final bool loadingCandidates;
  final bool loadingMembers;

  /// Normalised names of Democratic nominees flagged as young dems.
  final Set<String> youngDemNames;
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
    required this.onOpenCandidate,
    required this.onTextMembers,
    required this.onEmailMembers,
    required this.resolveCandidate,
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
  final void Function(Candidate candidate) onOpenCandidate;
  final void Function(List<Member> members) onTextMembers;
  final void Function(List<Member> members) onEmailMembers;

  /// Resolves a candidate name to a full [Candidate] for detail navigation,
  /// or null when no record matches (in which case the name is not tappable).
  final Candidate? Function(String name) resolveCandidate;

  /// When supplied (mobile draggable sheet) the panel's single scroll view uses
  /// it so drag-to-expand works. Null on desktop (own controller).
  final ScrollController? scrollController;
  final bool showCloseButton;

  // ── theme tokens ───────────────────────────────────────────────
  bool _isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;
  Color _surface(BuildContext c) =>
      _isDark(c) ? const Color(0xFF1B2337) : Colors.white;
  Color _inset(BuildContext c) =>
      _isDark(c) ? const Color(0xFF212B44) : const Color(0xFFF4F6FA);
  Color _text(BuildContext c) =>
      _isDark(c) ? const Color(0xFFF4F6FA) : const Color(0xFF1E2637);
  Color _secondary(BuildContext c) =>
      _isDark(c) ? Colors.white.withValues(alpha: 0.72) : const Color(0xFF5A6478);
  Color _divider(BuildContext c) =>
      _isDark(c) ? const Color(0xFF2E3A57) : const Color(0xFFE5E9F0);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _surface(context),
      child: detail == null
          ? _statewide(context)
          : _regionDetail(context, detail!),
    );
  }

  // ── STATEWIDE OVERVIEW ─────────────────────────────────────────
  Widget _statewide(BuildContext context) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        Text('MISSOURI',
            style: TextStyle(
                color: _secondary(context),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4)),
        const SizedBox(height: 4),
        Text('Statewide overview',
            style: TextStyle(
                color: _text(context),
                fontSize: 22,
                fontWeight: FontWeight.w800,
                height: 1.1,
                letterSpacing: -0.3)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _overviewChip(context, '👥', '$statewideMembers members',
                accent: false),
            _overviewChip(context, '★', '$statewideYoungDems young dems running',
                accent: true),
          ],
        ),
        const SizedBox(height: 24),
        _sectionHeader(context, 'HOT DISTRICTS'),
        const SizedBox(height: 10),
        if (hotRegions.isEmpty)
          Text('Loading district signal…',
              style: TextStyle(color: _secondary(context), fontSize: 13))
        else
          ...hotRegions.map((h) => _hotRow(context, h)),
      ],
    );
  }

  Widget _overviewChip(BuildContext context, String glyph, String label,
      {required bool accent}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: accent
            ? MapPalette.sunriseGold.withValues(alpha: 0.16)
            : _inset(context),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
            color: accent
                ? MapPalette.sunriseGold.withValues(alpha: 0.5)
                : _divider(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(glyph, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: accent
                      ? const Color(0xFFB07A00)
                      : _text(context),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _hotRow(BuildContext context, HotRegion h) {
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
              color: _inset(context),
              borderRadius: BorderRadius.circular(12),
              border: gold
                  ? Border.all(color: MapPalette.sunriseGold.withValues(alpha: 0.55))
                  : Border.all(color: _divider(context)),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: MapPalette.statusSwatch(h.status).withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(gold ? Icons.star_rounded : Icons.place_outlined,
                      size: 18,
                      color: gold
                          ? const Color(0xFFB07A00)
                          : _secondary(context)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(h.mode.regionTitle(h.id),
                          style: TextStyle(
                              color: _text(context),
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                          '${h.memberCount} member${h.memberCount == 1 ? '' : 's'}'
                          '${gold ? ' · young dem running' : ''}',
                          style: TextStyle(
                              color: _secondary(context), fontSize: 12)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: _secondary(context).withValues(alpha: 0.6), size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── REGION DETAIL ──────────────────────────────────────────────
  Widget _regionDetail(BuildContext context, RegionDetail d) {
    return ListView(
      controller: scrollController,
      padding: EdgeInsets.zero,
      children: [
        _header(context, d),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (d.mode.isDistrict) ...[
                _sectionHeader(context, 'CANDIDATES — NOVEMBER GENERAL'),
                const SizedBox(height: 12),
                _candidateSection(context, d),
                const SizedBox(height: 24),
              ],
              _MembersSection(
                members: d.members,
                loading: d.loadingMembers,
                surface: _surface(context),
                inset: _inset(context),
                text: _text(context),
                secondary: _secondary(context),
                divider: _divider(context),
                onText: onTextMembers,
                onEmail: onEmailMembers,
                headerBuilder: (n) =>
                    _sectionHeader(context, 'MOYD MEMBERS ($n)'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _header(BuildContext context, RegionDetail d) {
    return Container(
      constraints: const BoxConstraints(minHeight: 116),
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [MapPalette.unityBlue, MapPalette.momentumBlue],
        ),
      ),
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
                    Text(d.mode.overline,
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4)),
                    const SizedBox(height: 3),
                    Text(d.mode.regionTitle(d.id),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            height: 1.1)),
                    const SizedBox(height: 3),
                    Text(
                        d.mode.isDistrict
                            ? 'Missouri · 2026 general election'
                            : 'Missouri',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.78),
                            fontSize: 12.5)),
                  ],
                ),
              ),
              if (showCloseButton)
                Semantics(
                  button: true,
                  label: 'Close detail panel',
                  child: InkWell(
                    onTap: onClose,
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
              _memberChip(d.memberCount),
              if (d.mode.isDistrict) _raceChip(d.status),
            ],
          ),
        ],
      ),
    );
  }

  Widget _memberChip(int count) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
        ),
        child: Text('👥  $count member${count == 1 ? '' : 's'}',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700)),
      );

  Widget _raceChip(RegionStatus status) {
    switch (status) {
      case RegionStatus.youngDem:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: MapPalette.sunriseGold,
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Text('★ YOUNG DEM RUNNING',
              style: TextStyle(
                  color: MapPalette.unityBlue,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3)),
        );
      case RegionStatus.demContested:
      case RegionStatus.demUnopposed:
        return _dotChip(const Color(0xFF7FC4EA), 'Dem on ballot');
      case RegionStatus.noDem:
        return _dotChip(MapPalette.statusNoDem, 'No Dem filed');
      case RegionStatus.notOnBallot:
        return _dotChip(Colors.white70, 'Not on the 2026 ballot');
    }
  }

  Widget _dotChip(Color dot, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );

  // ── candidate section ──────────────────────────────────────────
  Widget _candidateSection(BuildContext context, RegionDetail d) {
    if (d.loadingCandidates) {
      return _panelSpinner(context, 'Loading November candidates…');
    }
    if (d.candidates.isEmpty) {
      if (d.status == RegionStatus.noDem) {
        return _noDemEmpty(context);
      }
      return _neutralEmpty(
        context,
        icon: Icons.how_to_vote_outlined,
        title: d.status == RegionStatus.notOnBallot
            ? 'This seat is not on the 2026 ballot'
            : 'No candidates on record for this race',
        body:
            'The August 4 primary results do not list candidates for this district.',
      );
    }

    final sorted = [...d.candidates]..sort((a, b) {
        if (a.isDemocrat != b.isDemocrat) return a.isDemocrat ? -1 : 1;
        if (a.advanced != b.advanced) return a.advanced ? -1 : 1;
        return b.votes.compareTo(a.votes);
      });

    return Column(
      children: [
        for (final r in sorted) _candidateRow(context, r),
      ],
    );
  }

  Widget _candidateRow(BuildContext context, ElectionResult r) {
    final ourNominee = r.isDemocrat && r.advanced;
    final youngDem = ourNominee && youngDemNamesFor(r);
    final barColor = r.isDemocrat ? null : const Color(0xFF9AA5B8);
    final pct = (r.pct ?? 0).clamp(0, 100).toDouble();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: _inset(context),
          borderRadius: BorderRadius.circular(12),
          border: youngDem
              ? Border.all(color: MapPalette.sunriseGold, width: 1)
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (ourNominee)
                Container(width: 3, color: MapPalette.sunriseGold),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _partyChip(r.partyShort),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _CandidateName(
                              name: r.candidateName,
                              color: _text(context),
                              onTap: () => _openCandidate(r.candidateName),
                            ),
                          ),
                          if (ourNominee) ...[
                            const SizedBox(width: 8),
                            _nomineePill(youngDem),
                          ],
                        ],
                      ),
                      const SizedBox(height: 10),
                      _voteBar(context, pct, barColor),
                      const SizedBox(height: 6),
                      Text(
                        '${_thousands(r.votes)}  ·  ${pct.toStringAsFixed(1)}%',
                        style: TextStyle(
                            color: _secondary(context),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            fontFeatures: const [FontFeature.tabularFigures()]),
                      ),
                      const SizedBox(height: 2),
                      Text(_caption(r),
                          style: TextStyle(
                              color: _secondary(context).withValues(alpha: 0.85),
                              fontSize: 11.5)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool youngDemNamesFor(ElectionResult r) =>
      (detail?.youngDemNames ?? const <String>{})
          .contains(normalizeName(r.candidateName));

  void _openCandidate(String name) {
    final resolved = resolveCandidate(name);
    if (resolved != null) onOpenCandidate(resolved);
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

  Widget _nomineePill(bool youngDem) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: MapPalette.sunriseGold,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(youngDem ? 'YOUNG DEM ★' : 'OUR NOMINEE ★',
            style: const TextStyle(
                color: MapPalette.unityBlue,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4)),
      );

  Widget _voteBar(BuildContext context, double pct, Color? solidColor) {
    final track =
        _isDark(context) ? const Color(0xFF313D5E) : const Color(0xFFDFE4EC);
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Container(
        height: 6,
        color: track,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: (pct / 100).clamp(0.0, 1.0)),
          duration: const Duration(milliseconds: 550),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: value,
              child: Container(
                decoration: BoxDecoration(
                  color: solidColor,
                  gradient: solidColor == null
                      ? const LinearGradient(colors: [
                          MapPalette.momentumBlue,
                          MapPalette.unityBlue
                        ])
                      : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _caption(ElectionResult r) {
    if (!r.advanced) return 'Aug 4 primary';
    return 'Aug 4 primary · advanced to November';
  }

  Widget _noDemEmpty(BuildContext context) {
    return _emptyBox(
      context,
      circle: MapPalette.statusNoDem.withValues(alpha: 0.15),
      icon: Icons.person_off_outlined,
      iconColor: MapPalette.unityBlue,
      title: 'No Democrat filed in this district',
      body:
          'No Democrat advanced from the August 4 primary here — this seat has '
          'no Democrat on the November ballot.',
      action: _suggestButton(context),
    );
  }

  Widget _neutralEmpty(BuildContext context,
      {required IconData icon,
      required String title,
      required String body}) {
    return _emptyBox(
      context,
      circle: MapPalette.momentumBlue.withValues(alpha: 0.12),
      icon: icon,
      iconColor: MapPalette.unityBlue,
      title: title,
      body: body,
    );
  }

  Widget _suggestButton(BuildContext context) => FilledButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Recruitment tracking is coming soon.')));
        },
        style: FilledButton.styleFrom(
          backgroundColor: MapPalette.sunriseGold,
          foregroundColor: MapPalette.unityBlue,
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: const Text('Suggest a recruit'),
      );

  Widget _emptyBox(BuildContext context,
      {required Color circle,
      required IconData icon,
      required Color iconColor,
      required String title,
      required String body,
      Widget? action}) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _inset(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _divider(context)),
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
                  color: _text(context),
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(body,
              textAlign: TextAlign.center,
              style: TextStyle(color: _secondary(context), fontSize: 12.5)),
          if (action != null) ...[
            const SizedBox(height: 16),
            action,
          ],
        ],
      ),
    );
  }

  Widget _panelSpinner(BuildContext context, String label) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: MapPalette.momentumBlue),
              ),
              const SizedBox(height: 12),
              Text(label,
                  style:
                      TextStyle(color: _secondary(context), fontSize: 12.5)),
            ],
          ),
        ),
      );

  Widget _sectionHeader(BuildContext context, String label) => Row(
        children: [
          Container(
            width: 20,
            height: 3,
            decoration: BoxDecoration(
              color: MapPalette.sunriseGold,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  color: _secondary(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2)),
        ],
      );

  static String _thousands(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

// A tappable candidate name that underlines on hover.
class _CandidateName extends StatelessWidget {
  const _CandidateName(
      {required this.name, required this.color, required this.onTap});
  final String name;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Text(name,
          style: TextStyle(
              color: color, fontSize: 15, fontWeight: FontWeight.w700)),
    );
  }
}

// ── members section with a "show all" expander ────────────────────
class _MembersSection extends StatefulWidget {
  const _MembersSection({
    required this.members,
    required this.loading,
    required this.surface,
    required this.inset,
    required this.text,
    required this.secondary,
    required this.divider,
    required this.onText,
    required this.onEmail,
    required this.headerBuilder,
  });

  final List<Member> members;
  final bool loading;
  final Color surface;
  final Color inset;
  final Color text;
  final Color secondary;
  final Color divider;
  final void Function(List<Member> members) onText;
  final void Function(List<Member> members) onEmail;
  final Widget Function(int count) headerBuilder;

  @override
  State<_MembersSection> createState() => _MembersSectionState();
}

class _MembersSectionState extends State<_MembersSection> {
  static const _initialCap = 30;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final members = widget.members;
    final emailable =
        members.where((m) => (m.preferredEmail ?? '').isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: widget.headerBuilder(members.length)),
            if (emailable.length >= 5)
              _EmailAllButton(
                count: emailable.length,
                onTap: () => widget.onEmail(emailable),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (widget.loading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: MapPalette.momentumBlue),
                  ),
                  const SizedBox(height: 12),
                  Text('Finding members…',
                      style:
                          TextStyle(color: widget.secondary, fontSize: 12.5)),
                ],
              ),
            ),
          )
        else if (members.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: widget.inset,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: widget.divider),
            ),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: MapPalette.momentumBlue.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.group_add_outlined,
                      color: MapPalette.unityBlue, size: 28),
                ),
                const SizedBox(height: 14),
                Text('No members here yet',
                    style: TextStyle(
                        color: widget.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('No MOYD members live in this area on record.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: widget.secondary, fontSize: 12.5)),
              ],
            ),
          )
        else ...[
          ...(_expanded ? members : members.take(_initialCap))
              .map((m) => _memberRow(m)),
          if (members.length > _initialCap && !_expanded)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: TextButton(
                onPressed: () => setState(() => _expanded = true),
                child: Text('Show all ${members.length}',
                    style: const TextStyle(
                        color: MapPalette.momentumBlue,
                        fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      ],
    );
  }

  Widget _memberRow(Member m) {
    final canText = m.canContact;
    final canEmail = (m.preferredEmail ?? '').isNotEmpty;
    final sub = [
      if ((m.city ?? '').isNotEmpty) m.city!,
      if (m.dateJoined != null) 'joined ${m.dateJoined!.year}',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            _avatar(m),
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
                          color: widget.text,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600)),
                  if (sub.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            TextStyle(color: widget.secondary, fontSize: 12)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            _compactButton(
              icon: Icons.sms_outlined,
              label: 'Text',
              enabled: canText,
              onTap: () => widget.onText([m]),
            ),
            const SizedBox(width: 6),
            _compactButton(
              icon: Icons.email_outlined,
              label: 'Email',
              enabled: canEmail,
              onTap: () => widget.onEmail([m]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatar(Member m) {
    final url = m.effectiveAvatarUrl;
    if (url != null && url.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          url,
          width: 36,
          height: 36,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _initialsAvatar(m),
        ),
      );
    }
    return _initialsAvatar(m);
  }

  Widget _initialsAvatar(Member m) => Container(
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

  static String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }

  Widget _compactButton({
    required IconData icon,
    required String label,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    final color = enabled ? MapPalette.momentumBlue : widget.secondary;
    return Semantics(
      button: true,
      enabled: enabled,
      label: '$label member',
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 44,
              constraints: const BoxConstraints(minWidth: 44),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.6), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 14, color: color),
                    const SizedBox(width: 5),
                    Text(label,
                        style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmailAllButton extends StatelessWidget {
  const _EmailAllButton({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.email_outlined, size: 15),
      label: const Text('Email all'),
      style: TextButton.styleFrom(
        foregroundColor: MapPalette.momentumBlue,
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }
}
