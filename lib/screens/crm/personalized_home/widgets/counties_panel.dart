import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/models/crm/meeting_commitment.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/screens/crm/members_list_screen.dart';
import 'package:bluebubbles/services/crm/meeting_commitment_repository.dart';
import 'package:bluebubbles/services/crm/member_repository.dart';

import 'branded_panel.dart';

/// The counties you were given, how many people are in them, and how many of
/// those you can actually phone. Plus, for everyone, the counties nobody took.
///
/// WHY THIS EXISTS. At the executive meeting on 2026-08-12 the committee split
/// Missouri by county and made each exec the person who personally calls the
/// members who live there. That split then lived in one meeting's minutes.
/// Roughly seven people are doing the work for four hundred members, and the
/// chair's stated priority was: we have their names, phone numbers and
/// locations, so connect them with a candidate.
///
/// WHY IT IS READ ONLY. `public.assignments` is a complete feature, service,
/// dialog, realtime stream, inference engine, mounted on this same screen, and
/// it has zero rows and has ALWAYS had zero rows. It was reachable and
/// permitted; nobody ever had a reason to type into it. So this panel asks for
/// nothing. Every number on it is a side effect of membership data the CRM
/// already collects. If nobody ever taps anything, it still tells the truth.
///
/// WHAT IT DELIBERATELY DOES NOT DO. No races and no candidates: `candidates`
/// holds zero general-election rows, so "which candidate do I point this person
/// at" is unanswerable today and pretending otherwise would be the fastest way
/// to lose an exec's trust. No contact logging. No claiming or reassigning a
/// county: ownership is what the room agreed, and the person with no county is
/// fixed by a phone call, not a button.
///
/// DESIGN LANGUAGE. This is a field-ops call sheet, so the visual system is
/// built around one question — "who's calling them?" — answered twice: once
/// at the top as a stacked coverage bar over all eligible members, and once
/// per county as a slim phone-coverage ratio bar ("X of Y have phones" is
/// what turns a county into a callable job). Grassroots green = someone can
/// call / covered. Action Red is never text or an icon-only signal (it is
/// ~3:1 on navy); it appears only as a dot or bar fill, always beside a word.
/// Sunrise gold carries warnings (unconfirmed assignments, data anomalies).
class CountiesPanel extends StatefulWidget {
  const CountiesPanel({
    super.key,
    required this.memberId,
    required this.isExecutive,
  });

  /// members.id of the signed-in exec. NOT the auth user id. Ownership lives in
  /// meeting_commitments.owner_member_id, which holds members.id.
  final String memberId;

  final bool isExecutive;

  @override
  State<CountiesPanel> createState() => _CountiesPanelState();
}

/// Exactly one of these renders. [accessAnomaly] is the one that matters: the
/// view ends in `where (select is_staff())`, so an identity mismatch returns
/// zero rows and no error, which is indistinguishable from "no counties" unless
/// it is called out. Sixty-two counties have members, so zero rows is not
/// possible legitimate data.
enum _CountiesState { loading, error, accessAnomaly, ready }

/// Grassroots green: "someone can call this person". Semantic constant local
/// to this panel so the meaning stays in one place.
const Color _kCovered = Color(0xFF43A047);

/// Action Red: "nobody is calling them". NEVER used as text or an icon-only
/// signal — dot/bar fills only, always paired with a word.
const Color _kUncovered = Color(0xFFE63946);

class _CountiesPanelState extends State<CountiesPanel>
    with WidgetsBindingObserver {
  final _commitments = MeetingCommitmentRepository();
  final _members = MemberRepository();

  _CountiesState _state = _CountiesState.loading;
  List<RegionCoverage> _coverage = const [];
  List<Member> _execRoster = const [];
  int _totalEligible = 0;
  bool _expandedGaps = false;
  bool _expandedOwned = false;

  /// How many unowned counties to show before the expander. Bounds the panel
  /// height by row count rather than by a fixed pixel height, which is what
  /// keeps it safe under large Dynamic Type settings.
  static const int _visibleGaps = 4;
  static const int _visibleOwned = 4;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.isExecutive) _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The county map changes once per meeting, so there is no realtime channel
    // here on purpose. Neither meeting_commitments nor assignments is in the
    // supabase_realtime publication, which is why the sibling panel's .stream()
    // never fires. A resume refresh is SILENT: it must not blank content that is
    // already correct back to a spinner every time the exec tabs away and back.
    if (state == AppLifecycleState.resumed && widget.isExecutive) {
      _load(silent: true);
    }
  }

  Future<void> _load({bool silent = false}) async {
    final hadData = _state == _CountiesState.ready;
    if (!silent && mounted) setState(() => _state = _CountiesState.loading);
    try {
      final results = await Future.wait([
        _commitments.getRegionCoverage(),
        _members.countEligibleMembers(),
        _members.getExecutiveRoster(),
      ]);
      if (!mounted) return;
      final coverage = results[0] as List<RegionCoverage>;
      setState(() {
        _coverage = coverage;
        _totalEligible = results[1] as int;
        _execRoster = results[2] as List<Member>;
        _state = coverage.isEmpty
            ? _CountiesState.accessAnomaly
            : _CountiesState.ready;
      });
    } catch (e) {
      debugPrint('CountiesPanel: load failed: $e');
      // A background refresh that fails while good data is on screen keeps the
      // data. Only a failed FIRST load becomes the error card.
      if (mounted && !hadData) setState(() => _state = _CountiesState.error);
    }
  }

  // ---- derived, all client side, no extra query ----

  List<RegionCoverage> get _mine =>
      _coverage.where((c) => c.isOwnedBy(widget.memberId)).toList();

  /// Already sorted by member_count descending by the query.
  List<RegionCoverage> get _unowned =>
      _coverage.where((c) => !c.hasOwner && c.memberCount > 0).toList();

  int get _membersWithCounty =>
      _coverage.fold<int>(0, (a, c) => a + c.memberCount);

  /// Subtraction, not a query: PostgREST cannot express "county IS NULL OR
  /// county = ''" in one filter, and this guarantees the numbers on screen add
  /// up to the headline.
  int get _noCounty => math.max(0, _totalEligible - _membersWithCounty);

  int get _unownedMembers => _unowned.fold<int>(0, (a, c) => a + c.memberCount);

  /// Members living in a county that SOMEBODY owns — the green half of the
  /// hero bar. Pure subtraction over already-loaded data.
  int get _coveredMembers => math.max(0, _membersWithCounty - _unownedMembers);

  /// Counties with an owner, for the header summary chip.
  int get _ownedCountyCount => _coverage.where((c) => c.hasOwner).length;

  List<Member> get _noRegionExecs {
    final owners = _coverage.expand((c) => c.ownerMemberIds).toSet();
    return _execRoster.where((m) => !owners.contains(m.id)).toList();
  }

  // ---- actions ----

  void _openCounty(String county) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MembersListScreen(initialCounty: county),
      ),
    );
  }

  /// Behind a tap, not on the face of the panel. Naming a colleague as having
  /// no county on every exec's home screen is a different and worse thing than
  /// letting someone go looking.
  void _showNoRegionExecs() {
    final execs = _noRegionExecs;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Text(
                'Executives with no county',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                'Assigned at an exec meeting. Not something the app can set.',
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: execs.length,
                itemBuilder: (_, i) => ListTile(
                  dense: true,
                  title: Text(execs[i].name.isEmpty ? 'Unnamed' : execs[i].name),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ---- build ----

  @override
  Widget build(BuildContext context) {
    // Rendering anything for a non-exec would leak the feature's existence for
    // no benefit. No error, no placeholder.
    if (!widget.isExecutive) return const SizedBox.shrink();

    return BrandedPanel(
      title: 'Your Counties',
      icon: Icons.call,
      headerAction: _state == _CountiesState.ready ? _headerChip() : null,
      // No bodyHeight on purpose: a fixed height has no headroom for large
      // Dynamic Type. Height is bounded by row count instead.
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: switch (_state) {
          _CountiesState.loading => _loading(),
          _CountiesState.error => _error(),
          _CountiesState.accessAnomaly => _accessAnomaly(),
          _CountiesState.ready => _ready(),
        },
      ),
    );
  }

  /// Header-strip summary chip: how much of the map is spoken for. Words
  /// carry the meaning; the chip is informational, not tappable.
  Widget _headerChip() {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withOpacity(0.22)),
        ),
        child: Text(
          '$_ownedCountyCount of ${_coverage.length} covered',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  Widget _loading() => const SizedBox(
        height: 160,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Checking the county map…',
                style: TextStyle(color: Colors.white70, fontSize: 12.5),
              ),
            ],
          ),
        ),
      );

  Widget _error() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.wifi_off_rounded,
                      color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    "Couldn't load your counties.",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded,
                  size: 16, color: BrandColors.sunriseGold),
              label: const Text('Retry'),
              style: TextButton.styleFrom(
                foregroundColor: BrandColors.sunriseGold,
                minimumSize: const Size(64, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: BrandColors.sunriseGold.withOpacity(0.5),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
            ),
          ],
        ),
      );

  /// Zero rows while the session says executive. Impossible as data, so it is
  /// reported as what it is rather than as an empty list.
  Widget _accessAnomaly() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: BrandColors.sunriseGold.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: BrandColors.sunriseGold.withOpacity(0.45),
          ),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded,
                color: BrandColors.sunriseGold, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                "County data came back empty, which can't be right: 62 counties "
                'have members in them. This is an access problem, not an empty '
                'list. Tell Andrew.',
                style: TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
              ),
            ),
          ],
        ),
      );

  Widget _ready() {
    final mine = _mine;
    final unowned = _unowned;
    final hasGaps = unowned.isNotEmpty;

    final shownOwned =
        _expandedOwned ? mine : mine.take(_visibleOwned).toList();
    final hiddenOwned = mine.length - shownOwned.length;

    final shownGaps =
        (_expandedGaps ? unowned : unowned.take(_visibleGaps)).toList();
    final hiddenGaps = unowned.length - shownGaps.length;
    final hiddenGapMembers =
        _unownedMembers - shownGaps.fold<int>(0, (a, c) => a + c.memberCount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _hero(),
        const SizedBox(height: 18),

        if (mine.isEmpty) ...[
          // The majority case: ten of fifteen execs. Not an error, and never
          // phrased as completion. It ends in a colon and a list of work, or,
          // when there is no work left, says so plainly rather than trailing a
          // colon into an empty list.
          const Text(
            "You weren't given a county at the August 12 meeting.",
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasGaps
                ? 'These counties have members and nobody calling them:'
                : 'Every county with members already has someone calling it.',
            style: const TextStyle(
                color: Colors.white70, fontSize: 13, height: 1.35),
          ),
          const SizedBox(height: 10),
        ] else ...[
          _sectionHeader('YOURS'),
          const SizedBox(height: 8),
          ...shownOwned.map((c) => _countyRow(c, mine: true)),
          if (hiddenOwned > 0)
            _tappableLine(
              '+ $hiddenOwned more of yours',
              semantics: '$hiddenOwned more of your counties. '
                  'Double tap for the full list.',
              trailing: Icons.expand_more,
              onTap: () => setState(() => _expandedOwned = true),
              dense: true,
            ),
          // Only header the gaps section when there is a gap to head. An empty
          // "NOBODY'S" with a red dot and nothing under it reads as a bug.
          if (hasGaps) ...[
            const SizedBox(height: 16),
            _sectionHeader("NOBODY'S CALLING", dotColor: _kUncovered),
            const SizedBox(height: 8),
          ],
        ],

        ...shownGaps.map((c) => _countyRow(c, mine: false)),

        if (hiddenGaps > 0)
          _tappableLine(
            '+ $hiddenGaps more counties, $hiddenGapMembers people',
            semantics: '$hiddenGaps more counties with no owner, '
                '$hiddenGapMembers members. Double tap for the full list.',
            trailing: Icons.expand_more,
            onTap: () => setState(() => _expandedGaps = true),
          ),

        const SizedBox(height: 14),
        Divider(height: 1, color: Colors.white.withOpacity(0.10)),
        const SizedBox(height: 10),

        Semantics(
          label: '$_noCounty members have no county on file.',
          excludeSemantics: true,
          child: Row(
            children: [
              Icon(Icons.location_off_outlined,
                  size: 14, color: Colors.white.withOpacity(0.45)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$_noCounty members have no county on file.',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        if (_noRegionExecs.isNotEmpty)
          _tappableLine(
            '${_noRegionExecs.length} execs have no county',
            semantics: '${_noRegionExecs.length} executives have no county '
                'assignment. Double tap to see who.',
            trailing: Icons.chevron_right,
            onTap: _showNoRegionExecs,
            dense: true,
          ),
      ],
    );
  }

  // ---- hero ----

  /// The point of the card: the whole eligible membership, split by whether
  /// anyone is responsible for calling them. Words in the legend carry every
  /// meaning the colours do.
  Widget _hero() {
    final covered = _coveredMembers;
    final uncovered = _unownedMembers;
    final unplaced = _noCounty;

    final segments = <(int, Color)>[
      if (covered > 0) (covered, _kCovered),
      if (uncovered > 0) (uncovered, _kUncovered),
      if (unplaced > 0) (unplaced, Colors.white.withOpacity(0.25)),
    ];

    return Semantics(
      label: '$_totalEligible eligible members. '
          '$covered have a caller, $uncovered have nobody calling them, '
          '$unplaced have no county on file.',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$_totalEligible',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                  letterSpacing: -0.5,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text(
                  'members eligible',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            "Who's calling them?",
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (segments.isNotEmpty) ...[
            const SizedBox(height: 12),
            _animatedSweep(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 8,
                  child: Row(
                    children: [
                      for (final (count, color) in segments)
                        Expanded(
                          flex: count,
                          child: ColoredBox(color: color),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                if (covered > 0)
                  _legendEntry(_kCovered, '$covered have a caller'),
                if (uncovered > 0)
                  _legendEntry(_kUncovered, '$uncovered have nobody'),
                if (unplaced > 0)
                  _legendEntry(
                      Colors.white.withOpacity(0.35), '$unplaced no county'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _legendEntry(Color color, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );

  /// Cheap left-to-right reveal for bars. Pure implicit animation — plays
  /// once when the widget enters, does nothing on identical rebuilds, so a
  /// silent background refresh never causes a distracting replay.
  Widget _animatedSweep({required Widget child}) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeOutCubic,
        child: child,
        builder: (context, t, child) => ClipRect(
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: t,
            child: child,
          ),
        ),
      );

  // ---- sections & rows ----

  /// Overline with an optional status dot and a hairline rule that carries the
  /// eye across the card. The dot never stands alone: the word beside it is
  /// the signal.
  Widget _sectionHeader(String text, {Color? dotColor}) => Row(
        children: [
          if (dotColor != null) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            text,
            style: TextStyle(
              color: Colors.white.withOpacity(0.65),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(height: 1, color: Colors.white.withOpacity(0.10)),
          ),
        ],
      );

  Widget _countyRow(RegionCoverage c, {required bool mine}) {
    final zero = c.memberCount == 0;

    final semantics = StringBuffer('${c.county} County')
      ..write(mine ? ', assigned to you' : ', no owner')
      ..write(mine && c.anyUnconfirmed ? ', pending confirmation' : '')
      ..write(zero
          ? ', no members on file'
          : '. ${c.memberCount} members, ${c.phoneCount} with phone numbers')
      ..write('. Double tap to open the member list.');

    // An owned county matching zero members is a mistyped county string in a
    // commitment row. It is shown loudly rather than dropped.
    final Widget detail;
    if (zero) {
      detail = const Row(
        children: [
          Icon(Icons.error_outline_rounded,
              size: 14, color: BrandColors.sunriseGold),
          SizedBox(width: 6),
          Text(
            '0 members on file',
            style: TextStyle(
              color: BrandColors.sunriseGold,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    } else {
      detail = Row(
        children: [
          Expanded(child: _coverageBar(c.phoneCount, c.memberCount)),
          const SizedBox(width: 10),
          Text(
            mine
                ? '${c.phoneCount} of ${c.memberCount} have phones'
                : '${c.phoneCount} of ${c.memberCount} callable',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      );
    }

    // Accent bar: gold flags the data anomaly, red marks an uncovered county.
    // Both are always accompanied by words (the gold line / section header).
    final Color? accent = zero
        ? BrandColors.sunriseGold
        : (mine ? null : _kUncovered);

    return Semantics(
      label: semantics.toString(),
      button: true,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _openCounty(c.county),
            borderRadius: BorderRadius.circular(12),
            splashColor: Colors.white.withOpacity(0.10),
            highlightColor: Colors.white.withOpacity(0.06),
            child: Container(
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  if (accent != null) ...[
                    Container(
                      width: 3,
                      height: 34,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                c.county,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.1,
                                ),
                              ),
                            ),
                            if (mine && c.anyUnconfirmed) ...[
                              const SizedBox(width: 8),
                              _unconfirmedPill(),
                            ],
                          ],
                        ),
                        const SizedBox(height: 7),
                        detail,
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(Icons.chevron_right,
                      size: 18, color: Colors.white.withOpacity(0.55)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Phone coverage as a slim ratio bar: fill = members with a phone number,
  /// track = the rest. The "X of Y" text beside it always carries the number.
  /// The fill eases in once on first build; identical rebuilds (e.g. a silent
  /// background refresh) do not replay it.
  Widget _coverageBar(int phones, int members) {
    final fraction = members > 0 ? (phones / members).clamp(0.0, 1.0) : 0.0;
    return Container(
      height: 6,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(3),
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: fraction),
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: value,
          child: Container(
            decoration: BoxDecoration(
              color: _kCovered,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ),
    );
  }

  /// Four of the six region assignments were never confirmed by the person they
  /// were given to. Asserting an unconfirmed assignment as settled fact is the
  /// worse error, so the pill stays until somebody confirms it out of band.
  Widget _unconfirmedPill() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: BrandColors.sunriseGold.withOpacity(0.12),
          border: Border.all(
            color: BrandColors.sunriseGold.withOpacity(0.55),
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Text(
          'NOT CONFIRMED',
          style: TextStyle(
            color: BrandColors.sunriseGold,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
      );

  Widget _tappableLine(
    String text, {
    required String semantics,
    required IconData trailing,
    required VoidCallback onTap,
    bool dense = false,
  }) =>
      Semantics(
        label: semantics,
        button: true,
        excludeSemantics: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            splashColor: Colors.white.withOpacity(0.10),
            highlightColor: Colors.white.withOpacity(0.06),
            child: Container(
              constraints: BoxConstraints(minHeight: dense ? 44 : 48),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      text,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: dense ? 12 : 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(trailing,
                      size: 18, color: Colors.white.withOpacity(0.55)),
                ],
              ),
            ),
          ),
        ),
      );
}
