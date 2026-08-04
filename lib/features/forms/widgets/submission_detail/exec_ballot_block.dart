import 'package:flutter/material.dart';

import '../../models/submission_review_model.dart';
import '../../screens/endorsement_hub/widgets/decisions/endorsement_vote_repository.dart';
import '../../screens/endorsement_hub/widgets/decisions/tally_widgets.dart';
import '../../screens/endorsement_hub/widgets/decisions/vote_reason_sheet.dart';
import '../../screens/endorsement_hub/widgets/headshot_avatar.dart';
import '../../theme/moyd_brand.dart';
import 'gold_rule_header.dart';
import 'review_text.dart';

/// Who on the executive committee voted on this candidate, how they voted,
/// and why: the first thing on the questionnaire page, above the AI verdict
/// and above the answers.
///
/// THE KEY TRAP, READ THIS BEFORE CHANGING ANY CALL SITE.
/// `endorsement_votes.candidate_id` is a TEXT column holding the
/// `form_submissions.id` of the questionnaire submission. It is NOT
/// `candidates.id`. Every tally and ballot lookup on this page therefore
/// passes the submission id. Handing it a CRM candidate uuid returns an empty
/// ballot with no error, which renders a board where nobody voted, which is
/// the one wrong answer an exec would act on.
///
/// The block never invents participation. The three execs who have genuinely
/// cast nothing render an outlined "Not voted yet" chip, distinct from No by
/// fill, icon and label, and distinct from Undecided by fill and label. A
/// failed ballot fetch renders an honest failure with a retry, never an empty
/// board.
class ExecBallotBlock extends StatelessWidget {
  final EndorsementVoteRepository votes;

  /// The submission id (see the key trap above), NOT the candidate uuid.
  final String submissionId;

  /// True once the committee has recorded a decision here, which suppresses
  /// the "N open" clause: the room is not waiting on those execs any more.
  final bool settled;

  const ExecBallotBlock({
    super.key,
    required this.votes,
    required this.submissionId,
    this.settled = false,
  });

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _shortDate(DateTime d) {
    final l = d.toLocal();
    return '${_months[l.month - 1]} ${l.day}';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: votes,
      builder: (context, _) {
        switch (votes.loadState) {
          case VoteLoadState.loading:
            return _shell(context, trailing: null, child: _loading(context));
          case VoteLoadState.failed:
            return _shell(context, trailing: null, child: _failed(context));
          case VoteLoadState.ready:
            return _loaded(context);
        }
      },
    );
  }

  Widget _shell(BuildContext context,
      {required Widget? trailing, required Widget child}) {
    return ReviewCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GoldRuleHeader(title: 'Executive ballot', trailing: trailing),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  // ── states ────────────────────────────────────────────────────────────────

  Widget _loading(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: _gridDelegate,
      itemCount: 8,
      itemBuilder: (context, _) => const Row(
        children: [
          ReviewSkeletonBar(width: 44, height: 44, circle: true),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ReviewSkeletonBar(height: 11),
                SizedBox(height: 8),
                ReviewSkeletonBar(width: 70, height: 9),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _failed(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.error_outline, size: 18, color: MoydBrand.opposeFg),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Ballots did not load.',
                  style: ReviewText.bodyStrong(context)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'The ballots could not be loaded, so none are shown. This does not '
          'mean nobody has voted.',
          style: ReviewText.secondary(context),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonal(
            onPressed: () => votes.reload(),
            child: const Text('Retry'),
          ),
        ),
        const SizedBox(height: 4),
        // NO tally here, deliberately. `failed` is only reachable when the
        // FIRST load never succeeded: load() early-returns once ready and
        // refresh()'s catch is non-destructive. So there is no stale-but-real
        // number to show; the store is empty and tallyFor would return 0/0/0,
        // which TallyBar renders as the words "No ballots yet".
        //
        // That reads as "the committee has not voted", which is
        // indistinguishable from the truth and is exactly what makes an exec
        // re-vote a candidate they already decided. castVote writes
        // reason_codes: [], so re-voting destroys their captured reasons.
        // Showing nothing is the honest failure.
        Text('Retry re-reads every ballot on the table.',
            style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant)),
      ],
    );
  }

  Widget _loaded(BuildContext context) {
    final ballots = votes.votesFor(submissionId);
    final tally = votes.tallyFor(submissionId);
    final tiles = _sortedVoters(ballots);

    return _shell(
      context,
      trailing: Text(
        '${tally.cast} of ${tiles.length} in',
        style: ReviewText.caption(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TallyBar(tally: tally, settled: settled),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: _gridDelegate,
            itemCount: tiles.length,
            itemBuilder: (context, i) =>
                _tile(context, tiles[i], ballots[tiles[i].userId]),
          ),
        ],
      ),
    );
  }

  /// FIXED mainAxisExtent, never childAspectRatio. A ratio-derived height is
  /// the silent-truncation hazard this codebase has already been bitten by
  /// twice in the roster gallery: the cell height stops depending on the
  /// content, the content overflows, and in a release build the assert that
  /// would have caught it is stripped.
  static const SliverGridDelegateWithMaxCrossAxisExtent _gridDelegate =
      SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: 280,
    mainAxisExtent: 80,
    crossAxisSpacing: 10,
    mainAxisSpacing: 10,
  );

  // ── roster ───────────────────────────────────────────────────────────────

  /// The exec roster (with faces and titles) unioned with anyone who cast a
  /// ballot without being on it, sorted yes, no, undecided, not voted; the
  /// signed-in exec first inside their group, alphabetical after that.
  ///
  /// This is [VoterRoster]'s comparator, which is the shipped ordering the
  /// committee already reads elsewhere.
  List<ExecVoter> _sortedVoters(Map<String, BallotEntry> ballots) {
    final roster = votes.execRoster;
    final known = votes.knownVoters;
    final merged = <String, ExecVoter>{};
    for (final entry in known.entries) {
      merged[entry.key] = roster[entry.key] ??
          ExecVoter(userId: entry.key, name: entry.value);
    }
    for (final entry in roster.entries) {
      merged.putIfAbsent(entry.key, () => entry.value);
    }

    final me = votes.currentUserId;
    final list = merged.values.toList()
      ..sort((a, b) {
        int rank(String uid) => switch (ballots[uid]?.vote) {
              'yes' => 0,
              'no' => 1,
              'undecided' => 2,
              _ => 3,
            };
        final r = rank(a.userId).compareTo(rank(b.userId));
        if (r != 0) return r;
        if (a.userId == me) return -1;
        if (b.userId == me) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return list;
  }

  // ── tile ─────────────────────────────────────────────────────────────────

  Widget _tile(BuildContext context, ExecVoter voter, BallotEntry? ballot) {
    final cs = Theme.of(context).colorScheme;
    final reason = _reasonLine(ballot);
    final voted = ballot?.vote;
    final when = ballot?.updatedAt;

    final tooltip = voted == null
        ? '${voter.name} has not voted yet'
        : '${voter.name} voted ${_voteWord(voted)}'
            '${when == null ? '' : ' · ${_shortDate(when)}'}';

    return Tooltip(
      message: tooltip,
      child: ClipRect(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            HeadshotAvatar(
              file: voter.photoUrl == null
                  ? null
                  : ReviewFile(url: voter.photoUrl!, name: voter.name),
              name: voter.name,
              size: 44,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    voter.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  if (voter.executiveTitle != null)
                    Text(
                      voter.executiveTitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _voteChip(context, voted),
                  ),
                  // 801 of 802 ballots carry no stated reason, so absence is
                  // the default and renders nothing at all. No per-tile
                  // "Reasons" header, no empty-state copy.
                  if (reason != null)
                    Text(
                      reason,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _voteWord(String vote) => switch (vote) {
        'yes' => 'Yes',
        'no' => 'No',
        _ => 'Undecided',
      };

  /// Humanized stated reasons plus any free text.
  ///
  /// [BallotEntry.statedReasonCodes] has already stripped the provenance tags
  /// (`meeting_2026_07_14` and friends). Those are NOT reasons and are never
  /// rendered here: the ballot-attribution UI was built and then deliberately
  /// deleted on 2026-07-27, and this must not rebuild it in chip form.
  String? _reasonLine(BallotEntry? ballot) {
    if (ballot == null) return null;
    final parts = <String>[
      for (final code in ballot.statedReasonCodes) voteReasonLabel(code),
    ];
    final other = ballot.otherText?.trim();
    if (other != null && other.isNotEmpty) parts.add(other);
    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }

  /// Four visually distinct states, none of which reads by color alone: each
  /// carries its own glyph and its own word.
  ///
  /// "Not voted yet" is outlined rather than filled, which is what separates
  /// it from No (solid red family) and from Undecided (solid neutral). The
  /// filled pairs are the shipped self-contained stance palette, AA on both
  /// light and dark cards without branching.
  Widget _voteChip(BuildContext context, String? vote) {
    final cs = Theme.of(context).colorScheme;
    late final Color fg;
    late final Color? bg;
    late final IconData icon;
    late final String label;
    switch (vote) {
      case 'yes':
        fg = MoydBrand.supportFg;
        bg = MoydBrand.supportBg;
        icon = Icons.check_circle;
        label = 'Yes';
      case 'no':
        fg = MoydBrand.opposeFg;
        bg = MoydBrand.opposeBg;
        icon = Icons.cancel;
        label = 'No';
      case 'undecided':
        fg = MoydBrand.neutralFg;
        bg = MoydBrand.neutralBg;
        icon = Icons.help_outline;
        label = 'Undecided';
      default:
        fg = cs.onSurfaceVariant;
        bg = null;
        icon = Icons.hourglass_empty;
        label = 'Not voted yet';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: bg == null ? Border.all(color: cs.outlineVariant) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
