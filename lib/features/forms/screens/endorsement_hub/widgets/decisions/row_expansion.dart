import 'package:flutter/material.dart';

import '../../../../models/submission_review_model.dart';
import '../../../../theme/moyd_brand.dart';
import '../../../../widgets/review/stance_visuals.dart';
import '../../models/candidate_entry.dart';
import '../../theme/hub_theme.dart';
import 'candidate_voice.dart';
import 'decision_activity.dart';
import 'decision_repository.dart';
import 'endorsement_vote_repository.dart';
import 'tally_widgets.dart';
import 'vote_reason_sheet.dart';

/// The in-place detail for one ballot row: full AI rationale, deductions,
/// disqualifiers, tally bar, voter roster, the caster's own reason echo, the
/// chair's split notes, the consensus banner with the chair-only Confirm and
/// the footer actions. Built only while the row is expanded so the 70-row
/// list stays light.
class RowExpansion extends StatefulWidget {
  final CandidateEntry entry;
  final EndorsementVoteRepository votes;
  final DecisionRepository repository;
  final bool isChair;
  final VoteBucket bucket;
  final String? suggestion; // 'yes' | 'no' when bucket == consensusReady
  final VoidCallback onOpen;
  final VoidCallback onFinalCall;

  /// The "other Democrats in this race" disclosure, built by the board (which
  /// owns SlateController's race data) and rendered above the footer row.
  /// Null keeps the expansion exactly as before, so hosts without race data
  /// pay nothing.
  final Widget? raceDisclosure;

  const RowExpansion({
    super.key,
    required this.entry,
    required this.votes,
    required this.repository,
    required this.isChair,
    required this.bucket,
    required this.suggestion,
    required this.onOpen,
    required this.onFinalCall,
    this.raceDisclosure,
  });

  @override
  State<RowExpansion> createState() => _RowExpansionState();
}

class _RowExpansionState extends State<RowExpansion> {
  bool _confirming = false;

  // Reveal-on-expand lives in _BallotRowState (didUpdateWidget): the row owns
  // the header that must stay clear of the pinned toolbar, so a blanket
  // ensureVisible here would scroll it out from under the user.

  Future<void> _confirm() async {
    final s = widget.suggestion == 'yes'
        ? DecisionState.endorse
        : DecisionState.decline;
    setState(() => _confirming = true);
    final ok = await widget.repository.trySetState(widget.entry.id, s);
    if (!mounted) return;
    setState(() => _confirming = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text("Confirm didn't save. Nothing was recorded."),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(label: 'Retry', onPressed: _confirm),
      ));
    }
    // On success realtime moves this row to the locked baseline everywhere.
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final entry = widget.entry;
    final votes = widget.votes;
    final tally = votes.tallyFor(entry.id);
    final myBallot = votes.myBallot(entry.id);
    final ai = entry.aiAlignment;
    final disqualifiers = ai?.disqualifiers ?? const <AiDisqualifier>[];
    final deductions = ai?.deductions ?? const <AiDeduction>[];
    final showDeductions =
        ai != null && ai.overallScore < 100 && deductions.isNotEmpty;

    // 30 of 77 scored questionnaires came back at exactly 100 with zero
    // deductions, so for two fifths of the field the score and the rationale
    // separate nobody from anybody. When the AI produced nothing to weigh a
    // candidate on, what they wrote is the only real evidence in the row, so
    // it LEADS. When there are disqualifiers or itemised deductions, the exec
    // already has plenty and the same block sits below them, one tap away.
    // See CandidateVoiceBlock: this is prominence, not presence.
    final voiceLeads = ai == null || (!showDeductions && disqualifiers.isEmpty);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Divider(height: 1, color: cs.outlineVariant),
          const SizedBox(height: 10),
          if (entry.officeLine.isNotEmpty)
            Text(entry.officeLine,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: cs.onSurfaceVariant)),
          // Criticality first: disqualifiers above the rationale.
          for (final d in disqualifiers) ...[
            const SizedBox(height: 10),
            _DisqualifierCard(disqualifier: d),
          ],
          const SizedBox(height: 10),
          if (voiceLeads) ...[
            CandidateVoiceBlock(
              key: ValueKey('voice-lead-${entry.id}'),
              entry: entry,
              lead: true,
            ),
            const SizedBox(height: 10),
          ],
          if (ai != null)
            _AiRationaleBlock(score: ai)
          else
            Text('Not AI scored yet',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: cs.onSurfaceVariant)),
          if (showDeductions) ...[
            const SizedBox(height: 10),
            _DeductionsList(
              deductions: deductions,
              positions: entry.model.allPolicyPositions,
            ),
          ],
          if (!voiceLeads) ...[
            const SizedBox(height: 4),
            CandidateVoiceBlock(
              key: ValueKey('voice-support-${entry.id}'),
              entry: entry,
              lead: false,
            ),
          ],
          const SizedBox(height: 12),
          TallyBar(tally: tally),
          const SizedBox(height: 4),
          Text('${tally.cast} of ${votes.roomSize} execs in',
              style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          // Collapsed by default: the headline numbers above stay visible
          // without opening the full pill roll.
          VoterRollDisclosure(votes: votes, candidateId: entry.id),
          if (myBallot != null && myBallot.hasReason) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.flag, size: 13, color: cs.onSurfaceVariant),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'Reason: ${_myReasonText(myBallot)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ],
          if (widget.isChair && widget.bucket == VoteBucket.split)
            _splitDetail(context),
          if (widget.bucket == VoteBucket.consensusReady)
            _consensusBanner(context, tally),
          // Last content item before the footer: the race-field disclosure
          // (solo line / opponent list / honest failure line, see
          // RaceFieldDisclosure). Informational, so it sits below every
          // voting-critical block.
          if (widget.raceDisclosure != null) widget.raceDisclosure!,
          const SizedBox(height: 8),
          Row(
            children: [
              if (widget.isChair)
                TextButton.icon(
                  onPressed: widget.onFinalCall,
                  icon:
                      Icon(Icons.gavel, size: 16, color: cs.onSurfaceVariant),
                  label: Text('Final call',
                      style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5)),
                  style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4)),
                ),
              const Spacer(),
              TextButton.icon(
                onPressed: widget.onOpen,
                icon: Icon(Icons.open_in_new,
                    size: 16, color: cs.onSurfaceVariant),
                label: Text('Full review',
                    style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5)),
                style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _myReasonText(BallotEntry ballot) {
    if (ballot.reasonCodes.contains('other') &&
        (ballot.otherText?.isNotEmpty ?? false)) {
      return ballot.otherText!;
    }
    return ballot.reasonCodes.map(voteReasonLabel).join(', ');
  }

  /// Chair-only rollup on split cards: the reasons behind the No/Undecided
  /// ballots plus who the room is still waiting on — what gets read aloud.
  Widget _splitDetail(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ballots = widget.votes.ballotsFor(widget.entry.id);
    final noReasons = <String, int>{};
    final undecidedReasons = <String, int>{};
    var noOther = 0;
    var undecidedOther = 0;
    for (final b in ballots.values) {
      final target = b.vote == 'no'
          ? noReasons
          : (b.vote == 'undecided' ? undecidedReasons : null);
      if (target == null) continue;
      for (final code in b.reasonCodes) {
        if (code == 'other') {
          if (b.vote == 'no') {
            noOther++;
          } else {
            undecidedOther++;
          }
          continue;
        }
        target[code] = (target[code] ?? 0) + 1;
      }
    }
    String rollup(Map<String, int> m, int others) {
      final parts = [
        for (final e in m.entries) '${e.value}× ${voteReasonLabel(e.key)}',
        if (others > 0) '$others× Other',
      ];
      return parts.join(', ');
    }

    final waiting = [
      for (final entry in widget.votes.knownVoters.entries)
        if (!ballots.containsKey(entry.key)) entry.value,
    ]..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final noLine = rollup(noReasons, noOther);
    final undecidedLine = rollup(undecidedReasons, undecidedOther);
    final noCount = ballots.values.where((b) => b.vote == 'no').length;
    final undecidedCount =
        ballots.values.where((b) => b.vote == 'undecided').length;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Split · discussion notes',
                style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant, fontWeight: FontWeight.w800)),
            if (noCount > 0) ...[
              const SizedBox(height: 4),
              Text(
                noLine.isEmpty
                    ? 'No ($noCount): no reasons given'
                    : 'No ($noCount): $noLine',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: cs.onSurface),
              ),
            ],
            if (undecidedCount > 0) ...[
              const SizedBox(height: 4),
              Text(
                undecidedLine.isEmpty
                    ? 'Undecided ($undecidedCount): no reasons given'
                    : 'Undecided ($undecidedCount): $undecidedLine',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: cs.onSurface),
              ),
            ],
            if (waiting.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Waiting on: ${waiting.join(', ')}',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }

  /// Full-width consensus strip. Everyone sees the suggestion; only the chair
  /// gets the Confirm button, and Confirm uses the CHECKED write path — on a
  /// failed write the card stays on the ballot on every device.
  Widget _consensusBanner(BuildContext context, VoteTally tally) {
    final endorse = widget.suggestion == 'yes';
    final fg = endorse ? MoydBrand.supportFg : MoydBrand.opposeFg;
    final bg = endorse ? MoydBrand.supportBg : MoydBrand.opposeBg;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: fg.withOpacity(0.35)),
        ),
        child: Row(
          children: [
            Icon(endorse ? Icons.verified : Icons.block, size: 16, color: fg),
            const SizedBox(width: 7),
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: 'Consensus: ',
                  children: [
                    TextSpan(
                        text: endorse ? 'Endorse' : 'Decline',
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    TextSpan(
                        text: ' (${tally.yes} Yes · ${tally.no} No · '
                            '${tally.undecided} Undecided)'),
                  ],
                ),
                style: TextStyle(
                    color: fg, fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ),
            if (widget.isChair) ...[
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _confirming ? null : _confirm,
                style: FilledButton.styleFrom(
                  backgroundColor: HubTheme.navy,
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                child: _confirming
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Confirm'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The full Gemini rationale in a quiet framed block: badge + scoring
/// recency in the header, then the untruncated narrative. The raw model id
/// chip was retired: it is an internal detail execs kept asking about, and
/// recency is the fact that actually informs trust in the rationale.
class _AiRationaleBlock extends StatelessWidget {
  final AiAlignmentScore score;
  const _AiRationaleBlock({required this.score});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome,
                  size: 14, color: AlignmentVisuals.fg(score.pct)),
              const SizedBox(width: 6),
              Text('AI ALIGNMENT',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: cs.onSurfaceVariant)),
              const Spacer(),
              AlignmentBadge(pct: score.pct, dense: true),
              if (score.scoredAt != null) ...[
                const SizedBox(width: 6),
                Text('Scored ${DecisionActivity.timeAgo(score.scoredAt!)}',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(score.rationale,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurface, height: 1.45)),
        ],
      ),
    );
  }
}

/// "Where the points went": the points lost, the issue, and THE CANDIDATE'S
/// OWN ANSWER. Nothing else.
///
/// This used to lead with the model's prose for every deduction, several lines
/// of "MOYD demands an unapologetic commitment to..." restating the platform
/// back at an exec who already knows it. The chair's note, verbatim: "I don't
/// need all this AI garbage about like MOYD beliefs blah blah, all I need here
/// is the minus the points, the categories, and what the candidate actually
/// put that caused them to lose points."
///
/// The sharper half of that complaint was Medicare for All: minus 5 points and
/// no indication anywhere of what the candidate had answered. That happens on
/// 17 of the 120 deductions on record, because the scorer only emits a `quote`
/// when it chose to pull one. The answer was always in the submission; it just
/// was not being looked up.
///
/// So the deduction is now joined back to the candidate's stance by issue id.
/// Their selected option leads, because that is the thing that actually cost
/// the points, and their own words follow when they wrote any. The model's
/// explanation is not rendered at all.
class _DeductionsList extends StatelessWidget {
  final List<AiDeduction> deductions;

  /// The candidate's stance answers, keyed by the same issue id the deduction
  /// carries. Empty is survivable: the row falls back to the scorer's quote.
  final List<PolicyPosition> positions;

  const _DeductionsList({required this.deductions, required this.positions});

  PolicyPosition? _positionFor(String issueId) {
    if (issueId.isEmpty) return null;
    for (final p in positions) {
      if (p.id == issueId) return p;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('WHERE THE POINTS WENT',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: cs.onSurfaceVariant)),
        for (final d in deductions)
          Builder(builder: (context) {
            final pos = _positionFor(d.issueId);
            // Their written explanation is the best evidence. The scorer's
            // quote is usually the same text, so it is the fallback rather
            // than a second thing to show.
            final written = (pos?.explanation ?? '').trim().isNotEmpty
                ? pos!.explanation!.trim()
                : d.quote.trim();
            final answer = (pos?.answerLabel ?? '').trim();

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    constraints: const BoxConstraints(minWidth: 52),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: MoydBrand.opposeBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('-${d.pointsLost} pts',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: MoydBrand.opposeFg,
                            fontSize: 11,
                            fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(d.label,
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: cs.onSurface)),
                        if (answer.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text.rich(
                              TextSpan(
                                text: 'They answered: ',
                                style: TextStyle(color: cs.onSurfaceVariant),
                                children: [
                                  TextSpan(
                                    text: answer,
                                    style: TextStyle(
                                        color: cs.onSurface,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                              style: const TextStyle(
                                  fontSize: 12, height: 1.35),
                            ),
                          ),
                        if (written.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.only(left: 8),
                            decoration: const BoxDecoration(
                              // Gold is a decorative rule only, never text on
                              // a light surface.
                              border: Border(
                                  left: BorderSide(
                                      color: HubTheme.gold, width: 3)),
                            ),
                            child: Text(written,
                                style: TextStyle(
                                    fontSize: 12,
                                    height: 1.4,
                                    fontStyle: FontStyle.italic,
                                    color: cs.onSurface)),
                          ),
                        // Never a silent gap. If the answer cannot be resolved
                        // and the scorer pulled no quote, say so, because "-5
                        // points and nothing under it" is the exact complaint
                        // this rewrite exists to fix.
                        if (answer.isEmpty && written.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'No answer recorded for this question.',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: cs.onSurfaceVariant),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}

/// One core-value break, full width in the oppose accent. All text is the
/// verified self-contained opposeFg-on-opposeBg pair (~5.6:1, both themes).
class _DisqualifierCard extends StatelessWidget {
  final AiDisqualifier disqualifier;
  const _DisqualifierCard({required this.disqualifier});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = disqualifier;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: MoydBrand.opposeBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: MoydBrand.opposeFg.withOpacity(0.45), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.report, size: 16, color: MoydBrand.opposeFg),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Disqualifier: ${d.position}',
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: MoydBrand.opposeFg)),
                if (d.quote.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.only(left: 8),
                    decoration: const BoxDecoration(
                      border: Border(
                          left: BorderSide(
                              color: MoydBrand.opposeFg, width: 3)),
                    ),
                    child: Text(d.quote,
                        style: const TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: MoydBrand.opposeFg)),
                  ),
                ],
                if (d.whyDisqualifying.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(d.whyDisqualifying,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: MoydBrand.opposeFg)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
