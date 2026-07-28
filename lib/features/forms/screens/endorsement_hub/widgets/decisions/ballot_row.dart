import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../theme/moyd_brand.dart';
import '../../../../widgets/review/stance_visuals.dart';
import '../../models/candidate_entry.dart';
import '../headshot_avatar.dart';
import 'decision_chip.dart';
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

  /// Fired after a ballot write on this row COMMITS: true when a vote was
  /// recorded, false when it was withdrawn or the write failed. The board
  /// uses it to pin the row in place under the "needs my vote" filter so it
  /// does not vanish from under the exec's finger.
  final void Function(bool voted)? onVoted;

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
    this.onVoted,
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

  /// The committee's RECORDED decision on this candidate, or undecided while
  /// the decisions load is anything but ready.
  ///
  /// Gated exactly like the browse gallery's chip builder: `stateFor`
  /// defaults a missing entry to undecided, so reading it before a successful
  /// load would label every settled candidate as unsettled. Until this
  /// existed, DecisionChip was built in ONE place in the whole app (the
  /// browse gallery), and the ballot the committee actually votes on showed
  /// no decision state at all: the 23 candidates gavelled on July 14 rendered
  /// as ordinary open rows.
  DecisionState get _decision =>
      widget.repository.loadState == DecisionLoadState.ready
          ? widget.repository.stateFor(entry.id)
          : DecisionState.undecided;

  bool get _settled => _decision != DecisionState.undecided;

  /// Only decided rows get a chip. An "Undecided" pill on the other 50 rows
  /// is noise: on the ballot, no chip already means no decision recorded.
  Widget? _decisionChip() =>
      _settled ? DecisionChip(state: _decision, compact: true) : null;

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

  /// One line: identity, recorded decision, qualifiers, room state, my
  /// action, chevron.
  Widget _wideHeader(ThemeData theme) {
    final cs = theme.colorScheme;
    final chip = _decisionChip();
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
        if (chip != null) ...[
          chip,
          const SizedBox(width: 8),
        ],
        if (widget.conflictLabel != null) ...[
          // Bounded: the pill's inner Flexible needs finite width inside
          // this unbounded header Row. The cap tightens when a decision chip
          // is also on this line so the two together cannot squeeze the name
          // out at the 720px breakpoint (no candidate is both settled and
          // office-conflicted today; this is the guard for when one is).
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: chip == null ? 240 : 150),
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
            child: _TinyTally(
                tally: votes.tallyFor(entry.id), settled: _settled),
          ),
        ),
        const SizedBox(width: 10),
        // onVoted must be passed HERE too, not just in the narrow header.
        // Without it the sticky-row behaviour only worked on phones, and every
        // exec voting from a laptop still had the row pop out from under the
        // cursor and the list re-sort on the first tap.
        _VoteSegmentedControl(
            entry: entry,
            votes: votes,
            displayName: _name,
            onVoted: widget.onVoted),
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
    final chip = _decisionChip();
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
        // The decision chip and the conflict pill share their own chip line
        // on narrow rather than competing with the name row or squeezing the
        // fixed-size vote control below: "Filed: Senate 34 · Said: House 34"
        // plus the segmented control cannot share 360px without an overflow.
        // A Wrap, so the two together fall to a second line instead of
        // overflowing on the narrowest phones.
        if (chip != null || widget.conflictLabel != null) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (chip != null) chip,
                if (widget.conflictLabel != null)
                  _ConflictPill(label: widget.conflictLabel!),
              ],
            ),
          ),
        ],
        const SizedBox(height: 4),
        Row(
          children: [
            _VoteSegmentedControl(
                entry: entry,
                votes: votes,
                displayName: _name,
                onVoted: widget.onVoted),
            const SizedBox(width: 8),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: _TinyTally(
                    tally: votes.tallyFor(entry.id), settled: _settled),
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

  /// True on a candidate the committee has already recorded a decision for:
  /// the "N waiting" suffix is dropped, because nobody is waited on.
  final bool settled;

  const _TinyTally({required this.tally, this.settled = false});

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
          '${tally.undecided} undecided'
          '${settled ? '' : ', ${tally.pending} waiting'}',
      child: ExcludeSemantics(
        child: Text.rich(
          TextSpan(children: [
            seg(tally.yes, 'Y', MoydBrand.supportFg),
            sep,
            seg(tally.no, 'N', MoydBrand.opposeFg),
            sep,
            seg(tally.undecided, 'U', MoydBrand.neutralFg),
            if (tally.pending > 0 && !settled)
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

  /// Name as actually rendered (see [BallotRow.displayName]); used to say
  /// WHICH candidate failed to save, since the failure snackbar can surface
  /// after the exec has scrolled that row off screen.
  final String displayName;

  /// See [BallotRow.onVoted].
  final void Function(bool voted)? onVoted;

  const _VoteSegmentedControl({
    required this.entry,
    required this.votes,
    required this.displayName,
    this.onVoted,
  });

  @override
  State<_VoteSegmentedControl> createState() => _VoteSegmentedControlState();
}

class _VoteSegmentedControlState extends State<_VoteSegmentedControl> {
  /// True while a ballot write for THIS candidate is in flight.
  ///
  /// Without it, two taps produce two concurrent unordered writes against the
  /// same primary key (candidate_id, voter_id), and the recorded vote is
  /// decided by chance rather than by the last tap:
  ///
  ///  - Double tap on the same segment: tap 1 optimistically sets the vote and
  ///    issues an UPSERT; tap 2 arrives before that await returns, sees the
  ///    OPTIMISTIC value, and takes castVote's withdraw branch, issuing a
  ///    DELETE. If the DELETE is processed first it matches nothing, the
  ///    UPSERT then commits, and the exec who believes they withdrew is still
  ///    counted. The realtime echo then re-adds it locally, so the board and
  ///    the database agree on the wrong answer and nothing looks broken.
  ///  - Rapid correction (No then Yes): two UPSERTs race, and whichever
  ///    commits last wins, which may be the FIRST tap.
  ///
  /// Nothing in the client, PostgREST or the table enforces last-tap-wins, so
  /// the only fix is to not issue the second write until the first has
  /// committed. This is the single caller of castVote (verified), so the guard
  /// here is sufficient.
  bool _busy = false;

  Future<void> _handleVote(
    String choice, {
    ScaffoldMessengerState? messenger,
  }) async {
    if (_busy) return;
    // Resolved BEFORE the await: rows live in a lazily built SliverList, so a
    // row scrolled past the cache extent is unmounted by the time the write
    // returns. The old `if (!mounted) return` swallowed the failure snackbar
    // in exactly the normal meeting-night rhythm (tap, then flick down two
    // screens), which is the silent failure this path exists to prevent. The
    // messenger lives above the list and outlives the row.
    final m = messenger ?? ScaffoldMessenger.of(context);
    final wasMine = widget.votes.myVote(widget.entry.id);
    // Tapping the choice already selected withdraws it (castVote's own
    // branch), which is the one case where the row should NOT be pinned.
    final withdrawing = wasMine == choice;
    // Pinned BEFORE the write, not after it: castVote updates the local map
    // and notifies optimistically, so the board rebuilds while the upsert is
    // still in flight. Announcing the vote only after the await would leave
    // one frame in which the "needs my vote" filter has already dropped this
    // row, which is exactly the row-vanishing-under-your-finger behaviour
    // this callback exists to stop.
    if (!withdrawing) widget.onVoted?.call(true);
    // The Retry action can fire after this row has scrolled away and been
    // unmounted, so every _busy transition goes through this guard rather
    // than a bare setState, which would throw on a defunct State.
    void setBusy(bool v) {
      if (mounted) {
        setState(() => _busy = v);
      } else {
        _busy = v;
      }
    }

    setBusy(true);
    bool ok = false;
    try {
      ok = await widget.votes.castVote(widget.entry.id, choice);
    } finally {
      setBusy(false);
    }
    if (!ok) {
      // The write rolled back, so the row is genuinely unvoted again: unpin
      // it rather than leaving a failed vote parked in the list looking done.
      if (!withdrawing) widget.onVoted?.call(false);
      // A denial and a dropped packet are indistinguishable from `false`, and
      // they need OPPOSITE instructions. Telling an exec whose account is not
      // recognised as an executive to "check connection" and handing them a
      // Retry button sends them into a loop that can never succeed, on a
      // board that otherwise looks completely normal. Nothing about an RLS
      // rejection gets better by trying again.
      final denied =
          widget.votes.lastFailure == VoteWriteFailure.permissionDenied;
      m.showSnackBar(SnackBar(
        content: Text(denied
            ? '${widget.displayName}: the server rejected your vote because '
                'your account is not recognized as an executive. Message '
                'Andrew. Retrying will not help.'
            : "${widget.displayName}: vote didn't save. Check connection."),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: denied ? 12 : 4),
        action: denied
            ? null
            : SnackBarAction(
                label: 'Retry',
                onPressed: () => _handleVote(choice, messenger: m)),
      ));
      return;
    }
    final withdrew = withdrawing;
    if (withdrew) widget.onVoted?.call(false);
    // UNDECIDED ONLY. A No is a clear position and the exec has said what they
    // think; stopping them for a reason on every No is friction on the most
    // common non-yes answer and slows a 73 candidate ballot to a crawl.
    // Undecided is the one answer that tells the committee nothing on its own,
    // so it is the one worth asking about.
    if (!withdrew && choice == 'undecided') {
      // Non-blocking: the ballot is already recorded; the sheet only offers
      // the optional why. Needs a live context, so it is the one part that
      // still requires the row to be on screen.
      if (!mounted) return;
      showVoteReasonSheet(context,
          entry: widget.entry, vote: choice, votes: widget.votes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final mine = widget.votes.myVote(widget.entry.id);

    // EVERY segment carries a written label.
    //
    // The third one used to be a bare question-mark icon whose only
    // explanation was a Tooltip, and the phones the committee votes on have
    // no hover at all: on a phone the ballot offered Yes, No, and an
    // unexplained glyph, 73 times. It is also the one choice that opens the
    // reason sheet, so it is the last one to leave a guess.
    Widget seg({
      required String code,
      required IconData icon,
      required Color fill,
      required String label,
    }) {
      final selected = mine == code;
      return Semantics(
        button: true,
        selected: selected,
        label: selected
            ? 'Your vote: $label. Tap to withdraw.'
            : 'Vote $label',
        child: InkWell(
          // Null while a write is in flight: InkWell then renders and reports
          // itself as disabled, so the second tap of a double tap is never
          // delivered and the UPSERT/DELETE race cannot be started.
          onTap: _busy ? null : () => _handleVote(code),
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            // 44, the platform minimum touch target, not 36. These are the
            // meeting-night tap targets and a mis-tap on this control saves a
            // real wrong vote.
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 10),
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
                const SizedBox(width: 5),
                Text(label,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color:
                            selected ? Colors.white : cs.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      );
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
    // "Not sure" rather than "Undecided": shorter on a 360px phone, and it
    // does not collide with the committee's RECORDED "Undecided" decision
    // state, which is a different thing on the same row.
    final undecided = seg(
        code: 'undecided',
        icon: Icons.help_outline,
        fill: MoydBrand.neutralFg,
        label: 'Not sure');

    return AnimatedOpacity(
      // Brief dim while the write is in flight. The optimistic update has
      // already painted the exec's choice, so this reads as "saving" rather
      // than as a dead control, and it explains why a second tap does
      // nothing. Opacity only, so it is legible in both themes by
      // construction.
      duration: const Duration(milliseconds: 120),
      opacity: _busy ? 0.55 : 1.0,
      child: Container(
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
      ),
    );
  }
}
