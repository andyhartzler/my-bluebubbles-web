import 'package:flutter/material.dart';

import '../../../../models/submission_review_model.dart';
import '../../../../theme/moyd_brand.dart';
import '../../../../widgets/review/stance_visuals.dart';
import '../../models/candidate_entry.dart';
import '../../theme/hub_theme.dart';
import '../headshot_avatar.dart';

/// Builds the "other Democrats in this race" toggle for one candidate.
/// [compact] asks for the one-line, opens-a-sheet variant that the fixed-extent
/// grid tile needs; false asks for the inline expanding band the natural-height
/// phone card can carry. See RaceFieldDisclosure / RaceFieldStyle.
typedef RaceDisclosureBuilder = Widget Function(CandidateEntry entry,
    {required bool compact});

/// A single candidate tile in the roster gallery: face on top (with a subtle
/// navy scrim at the base so the frosted badges always read), an info block on
/// the opaque card surface below, a 3-segment stance strip, and flag chips.
///
/// The face never carries body text; every label sits on the solid card
/// surface so it stays legible in both themes. Hovering lifts the card and
/// reveals the compare affordance; selection wraps the card in gold.
class RosterCard extends StatefulWidget {
  final CandidateEntry entry;
  final bool selected;
  final VoidCallback onOpen;
  final VoidCallback onToggleSelect;

  /// Optional decision chip (built by the Decisions layer when present).
  final Widget? decisionChip;

  /// Phone layout: face on the left, details on the right, natural height,
  /// and an always-visible Compare button (touch has no hover state).
  final bool horizontal;

  /// Display name override (SlateController.displayNameFor): covers the one
  /// submission with no name in its data, where the linked candidates.name
  /// is the only name held. Null falls back to entry.name unchanged.
  final String? displayName;

  /// Resolved race label from v_endorsement_applicant_race
  /// ("Missouri House, District 39"), rendered under the office line. Null
  /// (view not applied / fetch failed / row not covered) renders nothing:
  /// the card stays exactly as before.
  final String? raceLine;

  /// Our applicants in this race; >= 2 shows the "N applied" pill at the end
  /// of the race line. Not contested = nothing extra.
  final int raceApplicantCount;

  /// The chair's per-candidate "other Democrats in this race" toggle. Browse
  /// had no such surface at all before this, which is where the research
  /// question ("who else is in this race?") is actually asked. Null renders
  /// the card exactly as before, so a host without race data pays nothing.
  final RaceDisclosureBuilder? raceDisclosureBuilder;

  /// The exec committee's ballot tally for this candidate, built by the
  /// Decisions layer (which owns EndorsementVoteRepository) and injected the
  /// same way [decisionChip] is.
  ///
  /// This card used to show the candidate's own policy answers here, which
  /// reads like a vote count and is not one. It was also nearly useless: 14 of
  /// the 77 applicants gave byte identical answers to every policy question and
  /// another 11 shared a second identical set, so the strip rendered the same
  /// bar on most cards. The committee's actual yes/no ballots do differ per
  /// candidate, and they are what somebody browsing this page is looking for.
  final Widget? voteStrip;

  const RosterCard({
    super.key,
    required this.entry,
    required this.selected,
    required this.onOpen,
    required this.onToggleSelect,
    this.decisionChip,
    this.horizontal = false,
    this.displayName,
    this.raceLine,
    this.raceApplicantCount = 0,
    this.raceDisclosureBuilder,
    this.voteStrip,
  });

  @override
  State<RosterCard> createState() => _RosterCardState();
}

class _RosterCardState extends State<RosterCard> {
  bool _hover = false;

  String get _name => widget.displayName ?? widget.entry.name;

  bool get _hasRaceLine => widget.raceLine?.isNotEmpty == true;

  /// Race identity line: race label + (contested only) the "N applied" pill.
  /// Only built when [_hasRaceLine], so a card without race data renders
  /// exactly as before.
  Widget _raceLineWidget(ThemeData theme, ColorScheme cs) {
    final line = widget.raceLine!;
    final contested = widget.raceApplicantCount >= 2;
    return Row(
      children: [
        Flexible(
          child: Text(
            line,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
        if (contested) ...[
          const SizedBox(width: 6),
          HubCountPill(text: '${widget.raceApplicantCount} applied'),
        ],
      ],
    );
  }

  /// The chair's per-candidate race toggle, or null when the host supplied no
  /// builder.
  ///
  /// The GRID gets [compact] (one text-height line that opens a modal sheet),
  /// because grid tiles are laid out at a FIXED extent
  /// (SliverGridDelegateWithMaxCrossAxisExtent + childAspectRatio) under
  /// `clipBehavior: Clip.antiAlias`: a child that grew on tap would be
  /// silently clipped, and the tile's Column would overflow. The phone list
  /// card has natural height inside a ListView, so it carries the real inline
  /// toggle.
  Widget? _raceDisclosure({required bool compact}) =>
      widget.raceDisclosureBuilder?.call(widget.entry, compact: compact);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final entry = widget.entry;
    final model = entry.model;
    final showControls = _hover || widget.selected;

    if (widget.horizontal) {
      return _horizontalCard(theme, cs, dark, entry, model);
    }
    final raceCompact = _raceDisclosure(compact: true);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onOpen,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _hover ? -3 : 0, 0),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: widget.selected
                  ? HubTheme.gold
                  : (_hover ? HubTheme.royal.withOpacity(0.55) : cs.outlineVariant),
              width: widget.selected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _hover
                    ? HubTheme.royal.withOpacity(dark ? 0.45 : 0.22)
                    : Colors.black.withOpacity(dark ? 0.25 : 0.05),
                blurRadius: _hover ? 16 : 8,
                offset: Offset(0, _hover ? 8 : 3),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---- face ----
              AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    HeadshotAvatar(
                      file: entry.headshot,
                      name: _name,
                      circle: false,
                      radius: 0,
                      size: 220,
                    ),
                    // Subtle navy scrim at the base of the photo (decorative;
                    // no text renders on the image itself).
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.center,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              HubTheme.navy.withOpacity(0.32),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // status chip (top-left)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: _StatusChip(status: entry.submission.status),
                    ),
                    // alignment badge (top-right); disqualified candidates
                    // get the stamp instead of a bare number.
                    if (model.aiAlignment?.disqualified == true)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: _Frosted(child: _DisqualifiedBadge()),
                      )
                    else if (model.alignmentPct != null)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: _Frosted(
                          child: AlignmentBadge(
                              pct: model.alignmentPct!, dense: true),
                        ),
                      ),
                    // hover controls
                    if (showControls)
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: _SelectButton(
                          selected: widget.selected,
                          onTap: widget.onToggleSelect,
                        ),
                      ),
                  ],
                ),
              ),
              // ---- info block ----
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
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
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      _name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  if (entry.isYoungDem) ...[
                                    const SizedBox(width: 5),
                                    const Tooltip(
                                      message: 'Young Dem',
                                      child: Icon(Icons.workspace_premium,
                                          size: 15, color: HubTheme.gold),
                                    ),
                                  ],
                                ],
                              ),
                              if (entry.officeLine.isNotEmpty)
                                Text(
                                  entry.officeLine,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              if (_hasRaceLine) _raceLineWidget(theme, cs),
                              // BOUNDED: the compact variant is a
                              // MainAxisSize.min Row whose only flex child is
                              // a Flexible on the bounded WIDTH axis. It adds
                              // one text-height line and never grows on tap
                              // (it opens a sheet), so the fixed grid extent
                              // is safe. roster_gallery's childAspectRatio was
                              // eased from 0.62 to 0.58 to absorb that line on
                              // the busiest tiles.
                              if (raceCompact != null) raceCompact,
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    widget.voteStrip ?? _StanceStrip(entry: entry),
                    if (entry.flags.any) ...[
                      const SizedBox(height: 10),
                      _FlagChips(flags: entry.flags),
                    ],
                    if (widget.decisionChip != null) ...[
                      const SizedBox(height: 10),
                      widget.decisionChip!,
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension on _RosterCardState {
  /// Phone-width layout: 96px face thumb + always-visible Compare button on
  /// the left, all text on the opaque card surface to the right. Natural
  /// height, so long flag rows and the decision chip never clip; every label
  /// keeps its theme-surface contrast in both light and dark themes.
  Widget _horizontalCard(ThemeData theme, ColorScheme cs, bool dark,
      CandidateEntry entry, SubmissionReviewModel model) {
    // The real inline toggle: this card lives in a ListView.separated with
    // natural height, so an expanding child costs nothing but a taller card.
    //
    // BOUNDED: RaceFieldDisclosure(style: inline) is a MainAxisSize.min Column
    // of a 44px header plus an AnimatedSize that adopts its child's size. It
    // sits inside this card's Expanded Column, whose cross axis (width) is
    // bounded by the card and whose main axis grows with the ListView's
    // natural extent. No vertical flex, no nested scrollable.
    final raceInline = _raceDisclosure(compact: false);
    return GestureDetector(
      onTap: widget.onOpen,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.selected ? HubTheme.gold : cs.outlineVariant,
            width: widget.selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(dark ? 0.25 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 96,
                    height: 96,
                    child: HeadshotAvatar(
                      file: entry.headshot,
                      name: widget.displayName ?? entry.name,
                      circle: false,
                      radius: 0,
                      size: 96,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _SelectButton(
                  selected: widget.selected,
                  onTap: widget.onToggleSelect,
                  large: true,
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.displayName ?? entry.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (entry.isYoungDem) ...[
                        const SizedBox(width: 5),
                        const Tooltip(
                          message: 'Young Dem',
                          child: Icon(Icons.workspace_premium,
                              size: 15, color: HubTheme.gold),
                        ),
                      ],
                    ],
                  ),
                  if (entry.officeLine.isNotEmpty)
                    Text(
                      entry.officeLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  if (_hasRaceLine) _raceLineWidget(theme, cs),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _StatusChip(status: entry.submission.status),
                      if (model.aiAlignment?.disqualified == true)
                        _DisqualifiedBadge()
                      else if (model.alignmentPct != null)
                        AlignmentBadge(pct: model.alignmentPct!, dense: true),
                    ],
                  ),
                  const SizedBox(height: 10),
                  widget.voteStrip ?? _StanceStrip(entry: entry),
                  if (entry.flags.any) ...[
                    const SizedBox(height: 8),
                    _FlagChips(flags: entry.flags),
                  ],
                  if (widget.decisionChip != null) ...[
                    const SizedBox(height: 8),
                    widget.decisionChip!,
                  ],
                  if (raceInline != null) raceInline,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The three-segment support / qualified / oppose strip.
/// Crimson DISQUALIFIED stamp for candidates the Gemini judge flagged for a
/// core-value break. Self-contained colors: legible on the photo overlay in
/// both themes.
class _DisqualifiedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFB91C1C),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.gavel_rounded, size: 12, color: Colors.white),
          SizedBox(width: 4),
          Text(
            'DQ',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _StanceStrip extends StatelessWidget {
  final CandidateEntry entry;
  const _StanceStrip({required this.entry});

  @override
  Widget build(BuildContext context) {
    final t = entry.stanceTally;
    final total = t.support + t.qualified + t.oppose + t.other;
    if (total == 0) {
      return Text(
        'No policy answers',
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      );
    }
    final segs = <(Color, int)>[
      (MoydBrand.supportFg, t.support),
      (MoydBrand.qualifiedFg, t.qualified),
      (MoydBrand.opposeFg, t.oppose),
      (MoydBrand.neutralFg, t.other),
    ].where((e) => e.$2 > 0).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 8,
            child: Row(
              children: [
                for (var i = 0; i < segs.length; i++)
                  Expanded(
                    flex: segs[i].$2,
                    child: Container(
                      margin:
                          EdgeInsets.only(right: i == segs.length - 1 ? 0 : 1),
                      color: segs[i].$1,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${t.support} support · ${t.qualified} qualified · ${t.oppose} oppose',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _FlagChips extends StatelessWidget {
  final CandidateFlags flags;
  const _FlagChips({required this.flags});

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    if (flags.nonDemHistory) {
      chips.add(_chip(Icons.swap_horiz, 'Non-Dem history'));
    }
    if (flags.selfFundedMajority) {
      chips.add(_chip(Icons.savings_outlined, 'Self-funded >50%'));
    }
    if (flags.missingDocs) {
      chips.add(_chip(Icons.folder_off_outlined, 'Missing docs'));
    }
    if (flags.uncertified) {
      chips.add(_chip(Icons.history_edu_outlined, 'Not certified'));
    }
    return Wrap(spacing: 6, runSpacing: 6, children: chips);
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: MoydBrand.amberBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: MoydBrand.amber),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: MoydBrand.amber,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      'reviewed' => 'Reviewed',
      'processed' => 'Processed',
      _ => 'Submitted',
    };
    return _Frosted(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

/// A dark translucent pill so a badge stays legible over any photo without
/// putting readable text directly on the image itself.
class _Frosted extends StatelessWidget {
  final Widget child;
  const _Frosted({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: HubTheme.navy.withOpacity(0.85),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}

class _SelectButton extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;

  /// Touch-friendly sizing for the phone list layout (bigger padding +
  /// glyphs, so the tap target reaches finger size).
  final bool large;

  const _SelectButton(
      {required this.selected, required this.onTap, this.large = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: EdgeInsets.symmetric(
              horizontal: large ? 12 : 9, vertical: large ? 10 : 5),
          decoration: BoxDecoration(
            color: selected ? HubTheme.gold : HubTheme.navy.withOpacity(0.92),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? HubTheme.gold : Colors.white24,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? Icons.check_circle : Icons.add_circle_outline,
                size: large ? 17 : 15,
                color: selected ? HubTheme.navy : Colors.white,
              ),
              const SizedBox(width: 4),
              Text(
                selected ? 'Added' : 'Compare',
                style: TextStyle(
                  color: selected ? HubTheme.navy : Colors.white,
                  fontSize: large ? 12 : 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
