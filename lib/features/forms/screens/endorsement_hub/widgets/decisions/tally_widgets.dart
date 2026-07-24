import 'package:flutter/material.dart';

import '../../../../theme/moyd_brand.dart';
import 'endorsement_vote_repository.dart';

/// The live tally: "5 Yes · 2 No · 1 Undecided · 8 open" with a
/// green/red/slate proportion bar. The bar is decorative reinforcement; the
/// counts are always spelled out beside it. Shared by the row expansion and
/// the chair's final-call panel.
class TallyBar extends StatelessWidget {
  final VoteTally tally;
  const TallyBar({super.key, required this.tally});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final label = StringBuffer(
        '${tally.yes} Yes · ${tally.no} No · ${tally.undecided} Undecided');
    if (tally.pending > 0) {
      label.write(' · ${tally.pending} open');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          tally.hasVotes ? label.toString() : 'No ballots yet',
          style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: tally.hasVotes ? cs.onSurface : cs.onSurfaceVariant),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: SizedBox(
            height: 8,
            child: Row(
              children: [
                if (tally.yes > 0) ...[
                  Expanded(
                    flex: tally.yes,
                    child: const ColoredBox(color: MoydBrand.supportFg),
                  ),
                ],
                if (tally.yes > 0 && (tally.no > 0 || tally.undecided > 0))
                  const SizedBox(width: 2),
                if (tally.no > 0)
                  Expanded(
                    flex: tally.no,
                    child: const ColoredBox(color: MoydBrand.opposeFg),
                  ),
                if (tally.no > 0 && tally.undecided > 0)
                  const SizedBox(width: 2),
                if (tally.undecided > 0)
                  Expanded(
                    flex: tally.undecided,
                    child: const ColoredBox(color: MoydBrand.neutralFg),
                  ),
                if (!tally.hasVotes)
                  Expanded(
                    child: ColoredBox(
                        color: cs.surfaceContainerHighest.withOpacity(0.8)),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Compact roster of who voted what: one pill per known committee voter with
/// a check (yes) / x (no) / question mark (undecided) / hourglass (not yet)
/// marker plus their name, so the ballot never reads by color alone.
class VoterRoster extends StatelessWidget {
  final EndorsementVoteRepository votes;
  final String candidateId;
  const VoterRoster(
      {super.key, required this.votes, required this.candidateId});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ballots = votes.votesFor(candidateId);
    final known = votes.knownVoters;
    if (known.isEmpty) {
      return Text('Ballots will list every exec by name.',
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: cs.onSurfaceVariant));
    }

    // Yes, then no, then undecided, then whoever has not voted yet; "You"
    // leads each group so members can always find themselves at a glance.
    final me = votes.currentUserId;
    final ids = known.keys.toList()
      ..sort((a, b) {
        int rank(String uid) => switch (ballots[uid]?.vote) {
              'yes' => 0,
              'no' => 1,
              'undecided' => 2,
              _ => 3,
            };
        final r = rank(a).compareTo(rank(b));
        if (r != 0) return r;
        if (a == me) return -1;
        if (b == me) return 1;
        return (known[a] ?? '').toLowerCase().compareTo(
            (known[b] ?? '').toLowerCase());
      });

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final uid in ids)
          _voterPill(
            context,
            name: uid == me ? 'You' : (known[uid] ?? 'An exec'),
            vote: ballots[uid]?.vote,
          ),
      ],
    );
  }

  Widget _voterPill(BuildContext context, {required String name, String? vote}) {
    late final Color fg;
    late final Color bg;
    late final IconData icon;
    switch (vote) {
      case 'yes':
        fg = MoydBrand.supportFg;
        bg = MoydBrand.supportBg;
        icon = Icons.check_circle;
      case 'no':
        fg = MoydBrand.opposeFg;
        bg = MoydBrand.opposeBg;
        icon = Icons.cancel;
      case 'undecided':
        fg = MoydBrand.neutralFg;
        bg = MoydBrand.neutralBg;
        icon = Icons.help_outline;
      default:
        fg = MoydBrand.neutralFg;
        bg = MoydBrand.neutralBg;
        icon = Icons.hourglass_empty;
    }
    return Tooltip(
      message: switch (vote) {
        'yes' => '$name voted Yes',
        'no' => '$name voted No',
        'undecided' => '$name voted Undecided',
        _ => '$name has not voted yet',
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: fg.withOpacity(0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
            Text(name,
                style: TextStyle(
                    color: fg, fontSize: 11.5, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
