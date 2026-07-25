import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../theme/moyd_brand.dart';
import '../../../../widgets/review/stance_visuals.dart';
import '../../models/candidate_entry.dart';
import '../headshot_avatar.dart';
import 'decision_repository.dart';
import 'district_map_sheet.dart';
import 'district_ref.dart';
import 'endorsement_vote_repository.dart';
import 'row_expansion.dart';
import 'vote_reason_sheet.dart';

/// One compact ballot row: identity, district chip, alignment badge, the
/// 3-way vote control and a tiny tally on a single line (two lines on
/// phones: identity + district up top, vote control + tally underneath).
/// Tapping the row expands it in place ([RowExpansion]); tapping a vote
/// segment casts without expanding; tapping the district chip opens the
/// map sheet. On expand the row scrolls itself clear of the pinned toolbar.
class BallotRow extends StatefulWidget {
  final CandidateEntry entry;
  final EndorsementVoteRepository votes;
  final DecisionRepository repository;
  final bool isChair;
  final VoteBucket bucket;
  final String? suggestion; // 'yes' | 'no' when bucket == consensusReady
  final bool expanded;
  final VoidCallback onToggleExpand;
  final VoidCallback onOpen;
  final VoidCallback onFinalCall;
  final DistrictRef? districtRef;
  final bool narrow;

  /// Pinned [BoardToolbarDelegate] extent: the reveal-on-expand scroll treats
  /// everything above it as occluded.
  final double toolbarExtent;

  /// Display name override (SlateController.displayNameFor): covers the one
  /// submission whose data carries no name at all, where the race view's
  /// coalesced candidates.name is the only name we hold. Null falls back to
  /// [entry].name unchanged.
  final String? displayName;

  /// Visible office-conflict pill text ("Filed: Senate 34 · Said: House 34"),
  /// non-null only where the SoS filing contradicts the candidate's own
  /// office answer. A pill, not a tooltip: hover does not exist on the phones
  /// the committee uses mid-meeting, and hiding the conflict would silently
  /// reassign the candidate's race.
  final String? conflictLabel;

  /// "Other Democrats in this race" disclosure, rendered inside the
  /// expansion; null keeps the row exactly as before.
  final Widget? raceDisclosure;

  const BallotRow({
    super.key,
    required this.entry,
    required this.votes,
    required this.repository,
    required this.isChair,
    required this.bucket,
    required this.suggestion,
    required this.expanded,
    required this.onToggleExpand,
    required this.onOpen,
    required this.onFinalCall,
    required this.districtRef,
    required this.narrow,
    required this.toolbarExtent,
    this.displayName,
    this.conflictLabel,
    this.raceDisclosure,
  });

  @override
  State<BallotRow> createState() => _BallotRowState();
}

class _BallotRowState extends State<BallotRow> {
  /// Keyed so the reveal can measure the expansion's full height while the
  /// AnimatedSize is still opening (the child is laid out at its natural
  /// size immediately; only the clip animates).
  final GlobalKey _expansionKey = GlobalKey();

  @override
  void didUpdateWidget(covariant BallotRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expanded && !oldWidget.expanded) {
      // Only on the tap that opened THIS row. A rebuild that arrives with
      // the row already expanded (re-sort, re-filter, realtime) never
      // re-scrolls the list.
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealExpansion());
    }
  }

  /// Scrolls just enough that the row header sits below the pinned toolbar
  /// and as much of the expansion as fits comes on screen. A row that is
  /// already fully visible does not move at all.
  void _revealExpansion() {
    if (!mounted) return;
    final scrollable = Scrollable.maybeOf(context);
    final row = context.findRenderObject();
    final viewportBox = scrollable?.context.findRenderObject();
    if (scrollable == null ||
        row is! RenderBox ||
        !row.attached ||
        viewportBox is! RenderBox ||
        !viewportBox.attached) {
      return;
    }
    final position = scrollable.position;
    // Breathing room between the toolbar hairline and the row's top edge.
    final topLimit = widget.toolbarExtent + 8;
    final rowTop = row.localToGlobal(Offset.zero, ancestor: viewportBox).dy;
    double delta;
    if (rowTop < topLimit) {
      // The header is (partly) under the pinned toolbar: bring it back out.
      delta = rowTop - topLimit;
    } else {
      // Header is clear. Scroll down only if the expansion runs past the
      // fold, and never far enough to push the header under the toolbar.
      final expansion = _expansionKey.currentContext?.findRenderObject();
      final bottomBox =
          expansion is RenderBox && expansion.attached ? expansion : row;
      final bottom = bottomBox
          .localToGlobal(Offset(0, bottomBox.size.height),
              ancestor: viewportBox)
          .dy;
      final overflow = bottom - viewportBox.size.height;
      if (overflow <= 0) return;
      delta = math.min(overflow, rowTop - topLimit);
    }
    final target = (position.pixels + delta)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if (target == position.pixels) return;
    position.animateTo(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  CandidateEntry get entry => widget.entry;
  EndorsementVoteRepository get votes => widget.votes;

  /// Name actually rendered (override wins; see [BallotRow.displayName]).
  String get _name => widget.displayName ?? entry.name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
                theme.brightness == Brightness.dark ? 0.25 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        // Stack (not a stretched Row) so the consensus strip spans header +
        // expansion without an IntrinsicHeight pass per row.
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 3,
              child: _ConsensusAccent(
                  bucket: widget.bucket, suggestion: widget.suggestion),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: widget.onToggleExpand,
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minHeight: widget.narrow ? 76 : 56),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: widget.narrow
                            ? _narrowHeader(theme)
                            : _wideHeader(theme),
                      ),
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: widget.expanded
                        ? RowExpansion(
                            key: _expansionKey,
                            entry: entry,
                            votes: votes,
                            repository: widget.repository,
                            isChair: widget.isChair,
                            bucket: widget.bucket,
                            suggestion: widget.suggestion,
                            onOpen: widget.onOpen,
                            onFinalCall: widget.onFinalCall,
                            raceDisclosure: widget.raceDisclosure,
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// One line: identity, qualifiers, room state, my action, chevron.
  Widget _wideHeader(ThemeData theme) {
    final cs = theme.colorScheme;
    return Row(
      children: [
        HeadshotAvatar(file: entry.headshot, name: _name, size: 36),
        const SizedBox(width: 10),
        Expanded(
          child: Text(_name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 8),
        if (widget.conflictLabel != null) ...[
          // Bounded: the pill's inner Flexible needs finite width inside
          // this unbounded header Row.
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: _ConflictPill(label: widget.conflictLabel!),
          ),
          const SizedBox(width: 8),
        ],
        _districtSlot(theme, maxOfficeWidth: 150),
        const SizedBox(width: 8),
        // Fixed slot so the score column stays vertically aligned while
        // scanning 70 rows.
        SizedBox(
          width: 64,
          child: Align(
            alignment: Alignment.centerRight,
            child: _alignmentSlot(cs),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 110,
          child: Align(
            alignment: Alignment.centerRight,
            child: _TinyTally(tally: votes.tallyFor(entry.id)),
          ),
        ),
        const SizedBox(width: 10),
        _VoteSegmentedControl(entry: entry, votes: votes),
        const SizedBox(width: 6),
        _chevron(cs),
      ],
    );
  }

  /// Two lines: identity + district + badge, then the vote control with the
  /// tally beside it. The control renders at its intrinsic size (its Yes/No
  /// segments never compress on phone widths); only the name and the tally
  /// give way, both behind an ellipsis.
  Widget _narrowHeader(ThemeData theme) {
    final cs = theme.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            HeadshotAvatar(file: entry.headshot, name: _name, size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Text(_name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 6),
            _districtSlot(theme, maxOfficeWidth: 110),
            const SizedBox(width: 6),
            _alignmentSlot(cs),
            const SizedBox(width: 6),
            _chevron(cs),
          ],
        ),
        // The conflict pill gets its own chip line on narrow rather than
        // competing with the name row or squeezing the fixed-size vote
        // control below: "Filed: Senate 34 · Said: House 34" plus the
        // segmented control cannot share 360px without an overflow.
        if (widget.conflictLabel != null) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: _ConflictPill(label: widget.conflictLabel!),
          ),
        ],
        const SizedBox(height: 4),
        Row(
          children: [
            _VoteSegmentedControl(entry: entry, votes: votes),
            const SizedBox(width: 8),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: _TinyTally(tally: votes.tallyFor(entry.id)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// District chip when the office parses to a mapped district; plain muted
  /// office text otherwise (statewide/local candidates have no polygon).
  Widget _districtSlot(ThemeData theme, {required double maxOfficeWidth}) {
    final ref = widget.districtRef;
    if (ref != null) {
      return _DistrictChip(
          entry: entry, refValue: ref, onOpenReview: widget.onOpen);
    }
    if (entry.officeLine.isEmpty) return const SizedBox.shrink();
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxOfficeWidth),
      child: Text(entry.officeLine,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
    );
  }

  Widget _alignmentSlot(ColorScheme cs) {
    final pct = entry.alignmentPct;
    if (pct == null) {
      // Unscored: a quiet dot holds the slot; the expansion spells it out.
      return Container(
        width: 6,
        height: 6,
        decoration:
            BoxDecoration(color: cs.outlineVariant, shape: BoxShape.circle),
      );
    }
    return AlignmentBadge(pct: pct, dense: true);
  }

  Widget _chevron(ColorScheme cs) {
    return AnimatedRotation(
      turns: widget.expanded ? 0.5 : 0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: Icon(Icons.expand_more, size: 20, color: cs.onSurfaceVariant),
    );
  }
}

/// 3px consensus strip on the row's left inner edge. Decorative only: the
/// same state is always spelled out in the consensus banner, split notes and
/// tally text. Still-open rows stay transparent (silence is the signal).
class _ConsensusAccent extends StatelessWidget {
  final VoteBucket bucket;
  final String? suggestion;
  const _ConsensusAccent({required this.bucket, required this.suggestion});

  @override
  Widget build(BuildContext context) {
    final color = switch (bucket) {
      VoteBucket.consensusReady =>
        suggestion == 'yes' ? MoydBrand.supportFg : MoydBrand.opposeFg,
      VoteBucket.split => MoydBrand.qualifiedFg,
      VoteBucket.stillOpen => Colors.transparent,
    };
    return ColoredBox(color: color);
  }
}

/// Quiet neutral district pill (navy stays reserved for the toolbar's active
/// states). neutralFg on neutralBg is a verified self-contained pair, legible
/// on both themes. Its own InkWell wins the gesture arena over the header's,
/// so tapping it opens the map sheet without toggling expansion.
class _DistrictChip extends StatelessWidget {
  final CandidateEntry entry;
  final DistrictRef refValue;
  final VoidCallback onOpenReview;
  const _DistrictChip({
    required this.entry,
    required this.refValue,
    required this.onOpenReview,
  });

  @override
  Widget build(BuildContext context) {
    // Visual height 24 inside a 36px box so the touch target stays generous.
    return SizedBox(
      height: 36,
      child: Center(
        child: Tooltip(
          message: 'Show district ${refValue.districtNum} on the map',
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => showDistrictMapSheet(
              context,
              entry: entry,
              ref: refValue,
              onOpenReview: onOpenReview,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: MoydBrand.neutralBg,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                    color: MoydBrand.neutralFg.withOpacity(0.28)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.map_outlined,
                      size: 13, color: MoydBrand.neutralFg),
                  const SizedBox(width: 4),
                  Text(refValue.shortLabel,
                      style: const TextStyle(
                          color: MoydBrand.neutralFg,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Visible amber office-conflict pill ("Filed: Senate 34 · Said: House 34").
/// qualifiedFg on qualifiedBg is a verified self-contained AA pair on both
/// themes, and reads as distinct from the neutral district chip beside it and
/// the amber baseline header, so a conflict chip is never confused with
/// either. Deliberately not a tooltip: the phones the committee uses during a
/// meeting have no hover, and a hidden conflict is a silent race
/// reassignment.
class _ConflictPill extends StatelessWidget {
  final String label;
  const _ConflictPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: MoydBrand.qualifiedBg,
        borderRadius: BorderRadius.circular(999),
        border:
            Border.all(color: MoydBrand.qualifiedFg.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline,
              size: 12, color: MoydBrand.qualifiedFg),
          const SizedBox(width: 4),
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: MoydBrand.qualifiedFg,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

/// Tiny per-row tally: "● 2Y · ● 0N · ● 1U · 3 waiting". Dots are decorative
/// (the letters carry meaning); counts are onSurface text, never Fg-colored
/// text on the card (supportFg on a dark card is ~2.8:1). Zero-count
/// segments stay rendered but dimmed so the columns are positionally stable.
class _TinyTally extends StatelessWidget {
  final VoteTally tally;
  const _TinyTally({required this.tally});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final base = theme.textTheme.labelSmall
        ?.copyWith(fontWeight: FontWeight.w700, color: cs.onSurface);
    if (!tally.hasVotes) {
      return Text('No ballots yet',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall
              ?.copyWith(color: cs.onSurfaceVariant));
    }

    InlineSpan seg(int count, String letter, Color dot) {
      final active = count > 0;
      return TextSpan(children: [
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.only(right: 3),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: active ? dot : cs.outlineVariant,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        TextSpan(
          text: '$count$letter',
          style: active ? null : TextStyle(color: cs.onSurfaceVariant),
        ),
      ]);
    }

    final sep = TextSpan(
        text: ' · ', style: TextStyle(color: cs.onSurfaceVariant));
    return Semantics(
      label: '${tally.yes} yes, ${tally.no} no, '
          '${tally.undecided} undecided, ${tally.pending} waiting',
      child: ExcludeSemantics(
        child: Text.rich(
          TextSpan(children: [
            seg(tally.yes, 'Y', MoydBrand.supportFg),
            sep,
            seg(tally.no, 'N', MoydBrand.opposeFg),
            sep,
            seg(tally.undecided, 'U', MoydBrand.neutralFg),
            if (tally.pending > 0)
              TextSpan(
                  text: ' · ${tally.pending} waiting',
                  style: TextStyle(color: cs.onSurfaceVariant)),
          ]),
          style: base,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

/// The compact 3-way vote control. All three choices stay one tap from the
/// collapsed row (Undecided plus its reason sheet is a live flow); unselected
/// segments are neutral gray so a scan down the control column shows where I
/// have voted (color) versus not (gray). All three Fg fills carry white at
/// >= 4.5:1 (the guarantee the old full-width buttons documented). Always
/// rendered at intrinsic size: the segments are the meeting-night tap targets
/// and must never be squeezed below their labels.
class _VoteSegmentedControl extends StatefulWidget {
  final CandidateEntry entry;
  final EndorsementVoteRepository votes;

  const _VoteSegmentedControl({
    required this.entry,
    required this.votes,
  });

  @override
  State<_VoteSegmentedControl> createState() => _VoteSegmentedControlState();
}

class _VoteSegmentedControlState extends State<_VoteSegmentedControl> {
  Future<void> _handleVote(String choice) async {
    final wasMine = widget.votes.myVote(widget.entry.id);
    final ok = await widget.votes.castVote(widget.entry.id, choice);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text("Vote didn't save. Check connection."),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
            label: 'Retry', onPressed: () => _handleVote(choice)),
      ));
      return;
    }
    final withdrew = wasMine == choice;
    if (!withdrew && (choice == 'no' || choice == 'undecided')) {
      // Non-blocking: the ballot is already recorded; the sheet only offers
      // the optional why.
      showVoteReasonSheet(context,
          entry: widget.entry, vote: choice, votes: widget.votes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final mine = widget.votes.myVote(widget.entry.id);

    Widget seg({
      required String code,
      required IconData icon,
      required Color fill,
      String? label,
    }) {
      final selected = mine == code;
      final display = label ?? code;
      final segment = Semantics(
        button: true,
        selected: selected,
        label: selected
            ? 'Your vote: $display. Tap to withdraw.'
            : 'Vote $display',
        child: InkWell(
          onTap: () => _handleVote(code),
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 36,
            width: label == null ? 40 : null,
            padding: label == null
                ? null
                : const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: selected ? fill : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 15,
                    color: selected ? Colors.white : cs.onSurfaceVariant),
                if (label != null) ...[
                  const SizedBox(width: 5),
                  Text(label,
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: selected
                              ? Colors.white
                              : cs.onSurfaceVariant)),
                ],
              ],
            ),
          ),
        ),
      );
      if (label == null) {
        return Tooltip(message: 'Undecided', child: segment);
      }
      return segment;
    }

    final yes = seg(
        code: 'yes',
        icon: Icons.check_circle,
        fill: MoydBrand.supportFg,
        label: 'Yes');
    final no = seg(
        code: 'no',
        icon: Icons.cancel,
        fill: MoydBrand.opposeFg,
        label: 'No');
    final undecided = seg(
        code: 'undecided',
        icon: Icons.help_outline,
        fill: MoydBrand.neutralFg);

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          yes,
          const SizedBox(width: 2),
          no,
          const SizedBox(width: 2),
          undecided,
        ],
      ),
    );
  }
}
