import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../models/submission_review_model.dart';
import '../../../../theme/moyd_brand.dart';
import '../../race_field_repository.dart';
import '../headshot_avatar.dart';

/// "Other Democrats in this race": the per-candidate toggle.
///
/// THE CHAIR'S ASK, verbatim: "I want to have a drop down for each candidate
/// ... the ones who did not fill out our form will be collapsed by default,
/// but I want the ability to easily tap the toggle and see who the other
/// Democrats are in the race."
///
/// So this is a TOGGLE ON THE ROW, not a thing buried inside the row's
/// expansion. It used to be the last item in [RowExpansion], which meant two
/// taps to reach and zero presence on the collapsed ballot; now [BallotRow]
/// mounts it directly under the header, where it is one tap from the list, and
/// [RosterCard] mounts it in Browse where it never existed at all.
///
/// SIX STATES, and the distinction between them is the whole point. Only ONE
/// of them is a toggle, because a toggle that opens onto nothing is worse than
/// a sentence:
///
///   * field:       1+ other filed Democrats -> the toggle. Collapsed by
///                  default, count in the collapsed label so there is a reason
///                  to tap it.
///   * solo:        race key exists, zero others, this applicant is the only
///                  one -> "Only Democrat filed in this race". Being the sole
///                  filed Democrat is a decision-relevant fact, so it is
///                  stated plainly rather than hidden behind an empty toggle.
///   * no others:   race key exists, zero non-applicants, but 2+ applicants
///                  -> "No Democrat filed beyond our N applicants".
///                  MO_HOUSE-39 and MO_SEN-18 each hold two applicants and no
///                  outsider; the solo line would be a false statement there.
///   * keyless:     county / statewide applicants -> "No filed-candidate list
///                  for this office" (we hold a filing list for legislative
///                  and congressional races and not for these).
///   * unavailable: the race fetch failed -> "Race field unavailable".
///                  NEVER collapsed into solo: rendering nothing on failure
///                  would silently convert every contested race into an
///                  apparent solo race, a false statement the committee could
///                  act on.
///   * not loaded:  fetch in flight -> nothing (transient).
///
/// TWO HARD RULES beyond the visuals: unvetted people are never in any
/// aggregate (SlateStats, scoreboard, copy summary, toolbar counts), and they
/// are never on the ballot. They exist only inside this disclosure.
///
/// THE RACES WITH NO APPLICANT AT ALL live at the bottom of this file
/// ([UnansweredRacesHeader] / [UnansweredRaceDisclosure] over the repository's
/// own [OrphanRace]),
/// because they reuse every honesty primitive here. The chair, after this
/// build started: "yes include the people that didnt fill out a form at all
/// like no one in that MOHD or SD or congressional district but just put them
/// at the bottom or something." Those races have no applicant row to hang a
/// toggle off, so they get their own collapsed row per race, in their own
/// section, BELOW everyone we heard from.
///
/// BOUNDED CONSTRAINTS. This mounts inside a lazily built SliverList, where
/// every child arrives with maxHeight == double.infinity (see the long
/// incident note in roster_board.dart). Every subtree below is finite by
/// construction, and each is annotated where it is built:
///   * no [CrossAxisAlignment.stretch] on any horizontal [Row] anywhere in
///     this file (the only stretch is on a vertical Column, which constrains
///     the bounded WIDTH axis);
///   * every [Column] is [MainAxisSize.min];
///   * no [Expanded] or [Flexible] on a vertical axis (the ones present are in
///     horizontal Rows, where they flex the bounded width);
///   * no scrollable inside the sliver. The person list is a plain `for` loop.
///     Measured 2026-07-28 against the whole 2026 filed-Democrat universe: the
///     most non-respondents in any one race is 4, on both sides of the split
///     (the toggle payload and the bottom section), so there is nothing to
///     virtualize. The only [SingleChildScrollView] in this file lives inside
///     a modal bottom sheet route, under an explicit [ConstrainedBox]
///     maxHeight.
enum RaceFieldStyle {
  /// Full-bleed tinted band with a top hairline: the ballot row, mounted
  /// directly beneath the header so it is visible while the row is collapsed.
  band,

  /// Bare block inside a card body, no band, no hairline: the phone roster
  /// card, which has natural height and its own surface.
  inline,

  /// One text-height line that opens the same content in a modal sheet
  /// instead of expanding in place. For the Browse GRID, whose tiles have a
  /// FIXED extent (SliverGridDelegateWithMaxCrossAxisExtent + childAspectRatio)
  /// and would clip or overflow if a child grew on tap.
  compact,
}

/// Which of the six states this row is in.
enum _RaceState { loading, unavailable, keyless, solo, noOthers, field }

class RaceFieldDisclosure extends StatefulWidget {
  final RaceInfo? raceInfo;

  /// Non-applicant Democrats in this race, already alphabetized upstream.
  /// Empty is the normal case and is handled as its own state, never as a
  /// broken one: the data layer may widen this set later, and an empty list
  /// must degrade to the honest "nobody else filed" sentence.
  final List<RaceFieldCandidate> others;

  /// SlateController's race-load lifecycle, threaded through so this widget
  /// can tell "no opponents" apart from "we could not find out".
  final bool loaded;
  final bool failed;

  /// How many QUESTIONNAIRE APPLICANTS share this race key, this one
  /// included. [others] holds only the filed Democrats who did NOT apply, so
  /// without this the widget could not tell a genuinely solo race from a race
  /// where every filed Democrat happens to have applied.
  final int applicantsInRace;

  final RaceFieldStyle style;

  const RaceFieldDisclosure({
    super.key,
    required this.raceInfo,
    required this.others,
    required this.loaded,
    required this.failed,
    this.applicantsInRace = 1,
    this.style = RaceFieldStyle.band,
  });

  @override
  State<RaceFieldDisclosure> createState() => _RaceFieldDisclosureState();
}

class _RaceFieldDisclosureState extends State<RaceFieldDisclosure> {
  /// COLLAPSED BY DEFAULT, on every row, every time the widget is built.
  bool _open = false;

  _RaceState get _state {
    if (!widget.loaded) return _RaceState.loading;
    // A submission the view does not cover is the same honest statement as a
    // failed fetch: we could not determine this race's field.
    if (widget.failed || widget.raceInfo == null) return _RaceState.unavailable;
    if (widget.raceInfo!.raceKey == null) return _RaceState.keyless;
    if (widget.others.isEmpty) {
      return widget.applicantsInRace >= 2 ? _RaceState.noOthers : _RaceState.solo;
    }
    return _RaceState.field;
  }

  int get _count => widget.others.length;

  /// The collapsed line. Requirement: it must say enough to be worth tapping,
  /// which means the COUNT, not a bare "Other Democrats".
  String get _headline => switch (_state) {
        _RaceState.unavailable => 'Race field unavailable',
        _RaceState.keyless => 'No filed-candidate list for this office',
        _RaceState.solo => 'Only Democrat filed in this race',
        _RaceState.noOthers =>
          'No Democrat filed in this race beyond our ${widget.applicantsInRace} applicants',
        _RaceState.field => _count == 1
            ? '1 other Democrat in this race'
            : '$_count other Democrats in this race',
        _RaceState.loading => '',
      };

  IconData get _icon => switch (_state) {
        _RaceState.unavailable => Icons.cloud_off_outlined,
        _RaceState.keyless => Icons.map_outlined,
        _RaceState.solo => Icons.person_outline,
        _RaceState.noOthers => Icons.groups_outlined,
        _RaceState.field => Icons.groups_outlined,
        _RaceState.loading => Icons.more_horiz,
      };

  /// Short muted qualifier printed after the headline in the FIELD state, so
  /// the collapsed row already says these are not our applicants.
  static const String _suffix = ' · did not apply';

  @override
  Widget build(BuildContext context) {
    final state = _state;
    if (state == _RaceState.loading) return const SizedBox.shrink();
    if (widget.style == RaceFieldStyle.compact) {
      return _compact(context, state);
    }
    return _full(context, state);
  }

  // -------------------------------------------------------------------------
  // band / inline
  // -------------------------------------------------------------------------

  /// BOUNDED: root is a [Container] with a decoration and no size of its own,
  /// so it takes the size of its child; the child is a
  /// `Column(mainAxisSize: min)` whose children are a fixed-height header and
  /// an [AnimatedSize] (RenderAnimatedSize lays the child out and adopts its
  /// size). Height is therefore the sum of finite children, whatever the
  /// incoming maxHeight is.
  Widget _full(BuildContext context, _RaceState state) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final band = widget.style == RaceFieldStyle.band;
    final isToggle = state == _RaceState.field;

    final header = _header(context, state, isToggle);

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _NotVettedBanner(),
        const SizedBox(height: 8),
        Text(
          _provenanceCopy(),
          style: theme.textTheme.labelSmall
              ?.copyWith(color: cs.onSurfaceVariant, height: 1.35),
        ),
        const SizedBox(height: 8),
        // Alphabetical only. This block never sorts, scores or ranks, so the
        // order cannot be read as a judgment.
        //
        // BOUNDED: a plain `for` loop into a min-size Column, NOT a ListView.
        // The largest non-respondent field in any race is 4 people (measured
        // 2026-07-28 over all 184 races), so there is nothing to virtualize
        // and a nested scrollable inside the ballot's sliver would be both
        // unbounded and unusable on a phone.
        for (final c in widget.others)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: UnvettedDemocratRow(candidate: c),
          ),
      ],
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        header,
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _open && isToggle
              ? Padding(
                  padding: EdgeInsets.fromLTRB(band ? 10 : 0, 0, band ? 10 : 0, 10),
                  child: body,
                )
              // Infinite WIDTH resolves against the bounded width axis (1040
              // in the ballot, the card width in Browse); height is zero.
              : const SizedBox(width: double.infinity),
        ),
      ],
    );

    if (!band) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: content,
      );
    }
    return Container(
      decoration: BoxDecoration(
        // Theme-derived on both sides: a tint of the theme's own container
        // color over the row's surface. Never Theme.cardColor, which is a
        // branded surface elsewhere in this app and unreadable in dark mode.
        color: cs.surfaceContainerHighest.withOpacity(
            theme.brightness == Brightness.dark ? 0.30 : 0.45),
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: content,
    );
  }

  /// The tap target. 44 logical pixels minimum, the platform touch minimum,
  /// spanning the full row width: the chair opens this with a thumb on an
  /// iPhone, and a bare 18px chevron is not a target.
  ///
  /// BOUNDED: [ConstrainedBox] with `minHeight` only (never `maxHeight:
  /// infinity` tightened), wrapping a horizontal [Row] with
  /// `crossAxisAlignment: center`. Center, not stretch: stretch on a
  /// horizontal Row under an infinite maxHeight is the exact construct that
  /// truncated the ballot to one row on 2026-07-26. The Row's [Expanded] child
  /// flexes the bounded WIDTH.
  Widget _header(BuildContext context, _RaceState state, bool isToggle) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final band = widget.style == RaceFieldStyle.band;

    final label = Text.rich(
      TextSpan(
        text: _headline,
        style: TextStyle(
          color: isToggle ? cs.onSurface : cs.onSurfaceVariant,
          fontWeight: isToggle ? FontWeight.w700 : FontWeight.w500,
        ),
        children: [
          if (isToggle)
            TextSpan(
              text: _suffix,
              style: TextStyle(
                  color: cs.onSurfaceVariant, fontWeight: FontWeight.w500),
            ),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.labelSmall,
    );

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(_icon,
            size: 15,
            color: isToggle ? cs.onSurface : cs.onSurfaceVariant),
        const SizedBox(width: 7),
        Expanded(child: label),
        if (isToggle) ...[
          const SizedBox(width: 6),
          AnimatedRotation(
            turns: _open ? 0.5 : 0,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: Icon(Icons.expand_more, size: 20, color: cs.onSurface),
          ),
        ],
      ],
    );

    final padded = Padding(
      padding: EdgeInsets.symmetric(horizontal: band ? 10 : 0, vertical: 6),
      child: row,
    );

    if (!isToggle) {
      // Not tappable, and visually inert: no chevron, muted text. A row that
      // looks like a control and does nothing is worse than a sentence.
      //
      // BOUNDED: minHeight only. ConstrainedBox enforces its constraints
      // AGAINST the incoming ones, so an infinite incoming maxHeight stays
      // infinite and is never tightened; the Padding/Row below resolve to
      // max(32, their own content height). Deliberately no Align: with a
      // null heightFactor, Align FILLS a finite maxHeight, which is a
      // different failure mode in a different parent.
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 32),
        child: padded,
      );
    }

    return Semantics(
      button: true,
      label: _open
          ? 'Hide the $_count other Democrats filed in this race'
          : 'Show the $_count other Democrats filed in this race. '
              'None of them applied to MOYD.',
      child: ExcludeSemantics(
        // Material so the ink splash has a surface to paint on inside the
        // Browse cards, whose root is a GestureDetector rather than a
        // Material. Transparency type paints no background of its own, so the
        // band tint above stays exactly as specified.
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: () => setState(() => _open = !_open),
            // 44 logical pixels, the platform touch minimum, spanning the full
            // row width. Same minHeight-only reasoning as above; the Row's
            // crossAxisAlignment.center does the vertical centering inside it,
            // so no Align is needed and none is used.
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: padded,
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // compact (fixed-extent grid tiles)
  // -------------------------------------------------------------------------

  /// One text-height line. In the FIELD state it opens the same content in a
  /// modal sheet; the sheet exists because the Browse grid lays its tiles out
  /// at a FIXED extent, so a child that grows on tap would clip against the
  /// tile's `clipBehavior: Clip.antiAlias` and overflow its RenderFlex.
  ///
  /// BOUNDED: `Row(mainAxisSize: min)` with a [Flexible] text child on the
  /// horizontal (bounded) axis, no vertical flex, and no height of its own
  /// beyond the glyph line.
  Widget _compact(BuildContext context, _RaceState state) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isToggle = state == _RaceState.field;
    final text = isToggle ? '$_headline$_suffix' : _headline;

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(_icon,
            size: 13, color: isToggle ? cs.onSurface : cs.onSurfaceVariant),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: isToggle ? cs.onSurface : cs.onSurfaceVariant,
              fontWeight: isToggle ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        if (isToggle)
          Icon(Icons.chevron_right, size: 15, color: cs.onSurface),
      ],
    );

    if (!isToggle) {
      return Padding(padding: const EdgeInsets.only(top: 2), child: row);
    }
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Semantics(
        button: true,
        label: 'Show the $_count other Democrats filed in this race. '
            'None of them applied to MOYD.',
        child: ExcludeSemantics(
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: () => _openSheet(context),
              borderRadius: BorderRadius.circular(6),
              child: row,
            ),
          ),
        ),
      ),
    );
  }

  void _openSheet(BuildContext context) {
    showRaceFieldSheet(
      context,
      raceLabel: widget.raceInfo?.shortLabel ?? '',
      provenance: _provenanceCopy(),
      others: widget.others,
    );
  }

  /// Provenance clause fulfils RaceInfo.officeSource's contract: when the race
  /// identity came only from the applicant's own questionnaire answer, say so
  /// rather than implying a filing match. Both arms end on the same sentence,
  /// which is the one the committee must not be able to miss.
  String _provenanceCopy() {
    final filed = widget.raceInfo?.officeSource == 'filed';
    return filed
        ? 'These Democrats filed for this race with the Secretary of State '
            'and did not answer our questionnaire. MOYD has not reviewed, '
            'scored or evaluated any of them.'
        : 'These Democrats filed for this race and did not answer our '
            'questionnaire. This race was identified from the applicant\'s '
            'own answers, not from a filing record. MOYD has not reviewed, '
            'scored or evaluated any of them.';
  }
}

/// Modal sheet carrying exactly the same content the inline toggle opens, for
/// the fixed-extent grid tiles.
///
/// BOUNDED: the sheet is its own route, so nothing here is inside the ballot's
/// sliver. Height is explicitly capped at 80% of the viewport by a
/// [ConstrainedBox], and the scrollable underneath it is therefore bounded on
/// both axes. This is the ONLY scrollable in this feature's race surface.
Future<void> showRaceFieldSheet(
  BuildContext context, {
  required String raceLabel,
  required String provenance,
  required List<RaceFieldCandidate> others,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final cs = theme.colorScheme;
      return SafeArea(
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  others.length == 1
                      ? '1 other Democrat in this race'
                      : '${others.length} other Democrats in this race',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                if (raceLabel.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(raceLabel,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: cs.onSurfaceVariant)),
                ],
                const SizedBox(height: 10),
                const _NotVettedBanner(),
                const SizedBox(height: 8),
                Text(provenance,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: cs.onSurfaceVariant, height: 1.35)),
                const SizedBox(height: 10),
                for (final c in others)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: UnvettedDemocratRow(candidate: c),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// The one sentence nobody can miss, above every opened list. Stated about US,
/// not about them: "we did not evaluate these people" is a fact about MOYD's
/// process, where "unqualified" or "not endorsable" would be a judgement we
/// have not made and have no basis to make.
///
/// neutralFg-on-neutralBg is a documented self-contained AA pair on both
/// themes, and reads as distinct from the amber baseline header and the
/// qualified amber conflict pill.
///
/// BOUNDED: Container sized by its child; child is a horizontal Row with a
/// centered cross axis and one [Expanded] on the bounded width axis.
class _NotVettedBanner extends StatelessWidget {
  const _NotVettedBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: MoydBrand.neutralBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.info_outline, size: 14, color: MoydBrand.neutralFg),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              'Never applied to MOYD. Not vetted, not scored, not on the '
              'ballot. Listed for context only.',
              style: TextStyle(
                color: MoydBrand.neutralFg,
                fontSize: 11,
                height: 1.3,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One unvetted Democrat. Visually segregated from every applicant treatment
/// on four independent axes so no single one carries the load: a mandatory
/// "Did not apply" pill, a dashed border no applicant surface uses (with a
/// dashed avatar ring), deliberate inertness (no alignment, no stances, no
/// DecisionChip, no vote controls, no tap-through: none exists), and the
/// verbal disclaimer above the list. The only affordances are external links.
///
/// BOUNDED: [CustomPaint] with no `size` sizes to its child; the child
/// Container has a `minHeight` constraint only; its Row is
/// `crossAxisAlignment: center` (never stretch) with one [Expanded] on the
/// bounded width axis, and the inner Column is [MainAxisSize.min].
class UnvettedDemocratRow extends StatelessWidget {
  final RaceFieldCandidate candidate;
  const UnvettedDemocratRow({super.key, required this.candidate});

  /// [url] is always the output of [socialProfileUrl] / [webLinkUrl]: fully
  /// resolved, network-correct, and junk-filtered upstream. This method never
  /// composes URLs itself; the per-network routing lives beside the
  /// sanitizers in race_field_repository.dart so there is one implementation.
  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final c = candidate;

    final glanceParts = <String>[
      if (c.city != null) c.city!,
      if (c.county != null) c.county!,
      if (c.ageBand != null) c.ageBand!,
      if (c.gatedMoneyLabel != null) c.gatedMoneyLabel!,
    ];

    // Trailing external-link buttons: 20px glyphs padded to a 44px tap
    // target. Ballotpedia and the campaign website are the anchor links.
    // Fields are sanitized at parse time (the columns hold 'No', 'Yes',
    // 'N/A', 'in progress' and bare human names), so a non-null value here is
    // URL-shaped and webLinkUrl always resolves it.
    final trailing = <Widget>[
      if (c.ballotpediaUrl != null)
        _LinkTarget(
          icon: Icons.how_to_vote_outlined,
          tooltip: 'Ballotpedia',
          onTap: () => _open(webLinkUrl(c.ballotpediaUrl!)),
        ),
      if (c.campaignWebsite != null)
        _LinkTarget(
          icon: Icons.language,
          tooltip: 'Campaign website',
          onTap: () => _open(webLinkUrl(c.campaignWebsite!)),
        ),
    ];

    // Each icon resolves through ITS OWN network's base URL: the Instagram
    // icon must never open x.com/<handle>, which can be a different person.
    // A value whose network-specific resolution fails (for example a Bluesky
    // value on a non-Bluesky host) renders no icon at all: a dead or wrong
    // button next to an unvetted candidate's face is worse than no button.
    final socialSpecs = <(SocialNetwork, String?, IconData, String)>[
      (SocialNetwork.facebook, c.socialFacebook, Icons.facebook, 'Facebook'),
      (
        SocialNetwork.twitter,
        c.socialTwitter,
        Icons.alternate_email,
        'Twitter/X'
      ),
      (
        SocialNetwork.instagram,
        c.socialInstagram,
        Icons.camera_alt_outlined,
        'Instagram'
      ),
      (SocialNetwork.tiktok, c.socialTiktok, Icons.music_note, 'TikTok'),
      (
        SocialNetwork.bluesky,
        c.socialBluesky,
        Icons.cloud_outlined,
        'Bluesky'
      ),
    ];
    final socials = <Widget>[];
    for (final (network, value, icon, tooltip) in socialSpecs) {
      if (value == null) continue;
      final url = socialProfileUrl(network, value);
      if (url == null) continue;
      socials.add(_LinkTarget(
          icon: icon, tooltip: tooltip, small: true, onTap: () => _open(url)));
    }

    return CustomPaint(
      painter: _DashedBorderPainter(color: cs.outlineVariant, radius: 12),
      child: Container(
        // Background from ColorScheme so the row reads on both themes; the
        // dashed outline itself is painted, since Flutter borders have no
        // dashed style.
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _DashedRingAvatar(name: c.name, photoUrl: c.photoUrl),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(c.name,
                          style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface)),
                      const _DidNotApplyPill(),
                      if (c.incumbent) const _IncumbentChip(),
                    ],
                  ),
                  if (glanceParts.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(glanceParts.join(' · '),
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                  if (socials.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Wrap(spacing: 2, children: socials),
                  ],
                ],
              ),
            ),
            ...trailing,
          ],
        ),
      ),
    );
  }
}

/// The mandatory pill: on every unvetted row, always, never collapsed away on
/// narrow. neutralFg-on-neutralBg is a documented self-contained AA pair on
/// both themes, and reads as distinct from the amber baseline header and the
/// qualified amber conflict pill, so a draft chip, a conflict chip and an
/// unvetted chip are never confused.
class _DidNotApplyPill extends StatelessWidget {
  const _DidNotApplyPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: MoydBrand.neutralBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text('Did not apply',
          style: TextStyle(
              color: MoydBrand.neutralFg,
              fontSize: 10.5,
              fontWeight: FontWeight.w700)),
    );
  }
}

/// Plain factual chip stating a fact of public record, never a rank and never
/// part of a badge system. It used to be true on exactly one row (Wesley Bell)
/// because the field only reached 32 people; across the whole filed universe
/// it is true on 27 of the 176 non-respondents (26 of them in the bottom
/// section), so it is now a real recurring element rather than a one-off.
class _IncumbentChip extends StatelessWidget {
  const _IncumbentChip();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text('Incumbent',
          style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 10.5,
              fontWeight: FontWeight.w700)),
    );
  }
}

/// External-link button: 20px glyph (16 when [small]) padded to a 44px (36px
/// when [small]) tap target.
class _LinkTarget extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool small;
  const _LinkTarget({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final box = small ? 36.0 : 44.0;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(box / 2),
        child: SizedBox(
          width: box,
          height: box,
          child: Icon(icon, size: small ? 16 : 20, color: cs.onSurfaceVariant),
        ),
      ),
    );
  }
}

/// 28px face inside a dashed ring (applicants get solid rings everywhere on
/// the board). Initials fallback via the shared [HeadshotAvatar].
class _DashedRingAvatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  const _DashedRingAvatar({required this.name, required this.photoUrl});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final file = photoUrl == null
        ? null
        : ReviewFile(url: photoUrl!, name: 'profile.jpg', mimeType: 'image/jpeg');
    return CustomPaint(
      painter: _DashedCirclePainter(color: cs.outline),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: HeadshotAvatar(file: file, name: name, size: 28),
      ),
    );
  }
}

/// Dashed rounded-rect outline (Flutter's BorderStyle has no dashed variant).
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  const _DashedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Offset.zero & size, Radius.circular(radius)));
    canvas.drawPath(_dash(path), paint);
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}

class _DashedCirclePainter extends CustomPainter {
  final Color color;
  const _DashedCirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()..addOval(Offset.zero & size);
    canvas.drawPath(_dash(path, dash: 3, gap: 3), paint);
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter old) =>
      old.color != color;
}

/// Convert a closed path into a dashed copy via its path metrics.
Path _dash(Path source, {double dash = 4, double gap = 3}) {
  final out = Path();
  for (final ui.PathMetric metric in source.computeMetrics()) {
    var distance = 0.0;
    while (distance < metric.length) {
      final end = (distance + dash).clamp(0.0, metric.length);
      out.addPath(metric.extractPath(distance, end), Offset.zero);
      distance = end + gap;
    }
  }
  return out;
}

// ===========================================================================
// THE BOTTOM SECTION: races where NOBODY returned the questionnaire.
//
// Everything above this line hangs off an applicant's row. 125 of the 184
// filed 2026 Democratic legislative races have no applicant at all, so they
// have no row to hang off, and until now they were invisible: the chair could
// not see 146 of the 176 filed Democrats we never heard from.
//
// Measured against production 2026-07-28 (query in the report; the same shape
// as sections 6 and 8 of 182_endorsement_race_field_full_field.sql):
//
//   office     orphan races   filed Democrats in them
//   US_HOUSE              2                         5
//   MO_SEN               11                        18
//   MO_HOUSE            112                       126
//   total               125                       149 raw / 146 after the
//                                                 person merge
//
//   most Democrats in any one orphan race : 4
//   orphan races holding exactly one      : 107 of 125
//
// So the section is 125 one-line rows, each opening to at most 4 people.
//
// THE ORDER IS DELIBERATE AND IS NOT A RANKING. Races sort by office (U.S.
// House, then Missouri Senate, then Missouri House) and then by district
// number, which is the order a filing list is printed in. Inside a race the
// people stay in the alphabetical order the repository already put them in.
// Nothing here sorts on money, incumbency, or anything else that could be
// read as an assessment, because no assessment exists.
// ===========================================================================

/// The section's list, filtered by the board's live search box and re-sorted
/// through the repository's own [OrphanRace.compare].
///
/// THE MODEL IS THE REPOSITORY'S, not a copy. [OrphanRace] already carries the
/// key, the SQL-built `race_label` behind a never-null `displayLabel`, the
/// alphabetized people, and the chamber-then-district ordering. A second
/// definition of any of that in the widget layer would be a second thing to
/// keep true.
///
/// [query] is the ballot toolbar's search text, so searching a name also finds
/// the people we never heard from. A race survives if its label or any of its
/// people match. Filtering, never reordering: search cannot promote anybody up
/// this list, because there is no ranking here to promote them within.
///
/// Empty in, empty out, which is the whole degradation story for this section.
/// The caller passes an empty list whenever the race fetch failed or the view
/// predates 182 (the repository leaves [RaceDataSnapshot.racesWithoutApplicants]
/// empty in exactly those cases), the section then renders nothing at all, and
/// no header is ever printed over an empty or unknown field.
List<OrphanRace> filterUnansweredRaces(
  List<OrphanRace> races, {
  String query = '',
}) {
  final q = query.trim().toLowerCase();
  final out = <OrphanRace>[
    for (final r in races)
      if (r.candidates.isNotEmpty &&
          (q.isEmpty ||
              r.displayLabel.toLowerCase().contains(q) ||
              r.candidates.any((c) => c.name.toLowerCase().contains(q))))
        r
  ];
  // The repository already delivers these ordered; sorting again is cheap at
  // 125 items and makes the section's order a property of THIS list rather
  // than an assumption about how it arrived.
  out.sort(OrphanRace.compare);
  return out;
}

/// The section header, which has one job beyond counting: make it unmistakable
/// that everything below it is a DIFFERENT KIND OF THING from the ballot above
/// it. No gradient tile (gradients belong to the ballot and the hero), no
/// vote controls anywhere beneath it, and the words say plainly that there is
/// nothing to vote on and nobody has been assessed.
///
/// BOUNDED: root [Container] with a decoration and no size, sized by its
/// child; child is `Column(mainAxisSize: min)`; the one [Row] is
/// `crossAxisAlignment: start` with a fixed-size icon tile and one [Expanded]
/// on the bounded WIDTH axis. No vertical flex, no scrollable.
class UnansweredRacesHeader extends StatelessWidget {
  /// Races rendered right now (after search).
  final int raceCount;

  /// Races in the section before search, so a filtered header cannot read as
  /// the whole picture.
  final int totalRaces;

  /// Filed Democrats across [raceCount] races.
  final int peopleCount;

  /// True when the board's search box is narrowing this section.
  final bool filtered;

  const UnansweredRacesHeader({
    super.key,
    required this.raceCount,
    required this.totalRaces,
    required this.peopleCount,
    this.filtered = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final people = peopleCount == 1 ? '1 Democrat' : '$peopleCount Democrats';
    final races = raceCount == 1 ? '1 race' : '$raceCount races';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        // Theme roles on both sides, no branded surface: this block must read
        // as quieter than every ballot card above it, in both themes.
        color: cs.surfaceContainerHighest.withOpacity(
            theme.brightness == Brightness.dark ? 0.30 : 0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Icon(Icons.mark_email_unread_outlined,
                    size: 18, color: cs.onSurfaceVariant),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Races nobody answered',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      filtered
                          ? '$races of $totalRaces shown · search active'
                          : '$races · $people filed · no questionnaires',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Not on the ballot. Nobody in these districts returned our '
            'questionnaire, so there is nothing to vote on here and nobody '
            'here has been reviewed, scored or evaluated by MOYD. Listed so '
            'the whole Democratic field is visible.',
            style: theme.textTheme.labelSmall
                ?.copyWith(color: cs.onSurfaceVariant, height: 1.35),
          ),
        ],
      ),
    );
  }
}

/// One collapsed race in the bottom section. Same interaction as the per-row
/// toggle above (collapsed by default, one 44px tap, count in the collapsed
/// label so there is a reason to tap), and the same opened content, but the
/// headline names the RACE rather than an applicant, because in these races
/// there is no "us" for anyone to be an "other" of.
///
/// Deliberately NOT a [BallotRow]-shaped card: no elevation, no shadow, no
/// consensus accent, no vote control, no chip, no tap-through to a review.
/// Everything that makes a ballot row look actionable is absent, because
/// nothing here is actionable.
///
/// BOUNDED, and the chain is the same one the disclosure above documents,
/// because this mounts in the same lazily built SliverList where every child
/// arrives with `maxHeight == double.infinity`:
///   1. root [Container]: decoration only, no size, so it takes its child's;
///   2. child `Column(mainAxisSize: min, crossAxisAlignment: start)`, so its
///      height is the sum of two finite children and its stretch-free cross
///      axis is the bounded WIDTH;
///   3. the header is a [ConstrainedBox] with `minHeight` ONLY. `enforce`
///      leaves an incoming infinite maxHeight infinite and never tightens it;
///   4. inside it a horizontal [Row] with `crossAxisAlignment: center` (never
///      stretch, which is the 2026-07-26 ballot-truncation construct) and one
///      [Expanded], which flexes the bounded width;
///   5. the open body is an [AnimatedSize] over a `Column(mainAxisSize: min)`
///      built by a plain `for` loop over at most 4 rows. No ListView, no
///      SingleChildScrollView, no Expanded or Flexible on any vertical axis;
///   6. closed, the body is `SizedBox(width: double.infinity)`: infinite WIDTH
///      resolves against the bounded width axis and the height is zero.
class UnansweredRaceDisclosure extends StatefulWidget {
  final OrphanRace race;
  const UnansweredRaceDisclosure({super.key, required this.race});

  @override
  State<UnansweredRaceDisclosure> createState() =>
      _UnansweredRaceDisclosureState();
}

class _UnansweredRaceDisclosureState extends State<UnansweredRaceDisclosure> {
  /// COLLAPSED BY DEFAULT, every race, every build.
  bool _open = false;

  int get _count => widget.race.candidates.length;

  /// The collapsed line has to earn the tap, so it carries the count. "Filed"
  /// is the only verb used: it is what the Secretary of State's list says and
  /// it asserts nothing about the person.
  String get _countLine => _count == 1
      ? '1 Democrat filed · did not apply to MOYD'
      : '$_count Democrats filed · none applied to MOYD';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // The same glyph the per-row toggle uses for "the field in a race",
        // deliberately NOT a ballot glyph: nothing in this section is on the
        // ballot and the icon must not suggest otherwise.
        Icon(Icons.groups_outlined, size: 15, color: cs.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                // displayLabel, never raceLabel: the view has never returned a
                // null label, and if it ever does this falls back to the
                // office + district reconstruction and finally to the raw key
                // rather than printing a chamber we did not resolve.
                widget.race.displayLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w800, color: cs.onSurface),
              ),
              const SizedBox(height: 1),
              Text(
                _countLine,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        AnimatedRotation(
          turns: _open ? 0.5 : 0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: Icon(Icons.expand_more, size: 20, color: cs.onSurface),
        ),
      ],
    );

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _NotVettedBanner(),
        const SizedBox(height: 8),
        Text(
          'Nobody in this race answered our questionnaire. These Democrats '
          'filed for it with the Secretary of State. MOYD has not reviewed, '
          'scored or evaluated any of them, and none of them is on the '
          'ballot.',
          style: theme.textTheme.labelSmall
              ?.copyWith(color: cs.onSurfaceVariant, height: 1.35),
        ),
        const SizedBox(height: 8),
        // Alphabetical only, exactly as the repository delivered them. This
        // block never sorts, scores or ranks, so the order cannot be read as
        // a judgment. See the bounded-constraints note on the class: a plain
        // `for` loop over at most 4 rows, never a nested scrollable.
        for (final c in widget.race.candidates)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: UnvettedDemocratRow(candidate: c),
          ),
      ],
    );

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            label: _open
                ? 'Hide the $_count Democrats filed in '
                    '${widget.race.displayLabel}'
                : 'Show the $_count Democrats filed in '
                    '${widget.race.displayLabel}. '
                    'None of them applied to MOYD.',
            child: ExcludeSemantics(
              // Material so the splash has a surface to paint on; transparency
              // type paints no background, so the card colour above stands.
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: () => setState(() => _open = !_open),
                  borderRadius: BorderRadius.circular(12),
                  // 44 logical pixels, the platform touch minimum, spanning
                  // the whole row. minHeight only: see the class note.
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      child: header,
                    ),
                  ),
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _open
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    child: body,
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
