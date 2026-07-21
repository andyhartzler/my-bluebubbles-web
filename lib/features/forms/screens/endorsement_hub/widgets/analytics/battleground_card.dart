import 'package:flutter/material.dart';

import '../../../../models/submission_review_model.dart';
import '../../../../widgets/review/stance_visuals.dart';
import '../../models/candidate_entry.dart';
import '../../models/slate_stats.dart';
import '../../theme/hub_theme.dart';
import '../headshot_avatar.dart';

/// The most contested policy questions, ranked by disagreement index, each
/// with a split meter and the minority-holding candidates surfaced as
/// tappable avatar chips (tap for their exact answer + explanation).
class BattlegroundCard extends StatelessWidget {
  final SlateStats stats;
  final void Function(CandidateEntry) onOpen;
  const BattlegroundCard({super.key, required this.stats, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final all = stats.battlegroundQuestions();
    final top = all.where((q) => q.disagreementIndex > 0).take(5).toList();

    return HubCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HubCardHeader(
            icon: Icons.local_fire_department,
            title: 'Battleground questions',
            subtitle: 'Where the field is most divided.',
            tileGradient: HubTheme.gradCrimson,
          ),
          const SizedBox(height: 16),
          if (top.isEmpty)
            Text(
              stats.total == 0
                  ? 'No submissions yet.'
                  : 'No divided questions yet — the field agrees so far.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant),
            )
          else
            for (var i = 0; i < top.length; i++) ...[
              if (i > 0) Divider(height: 24, color: cs.outlineVariant),
              _QuestionRow(q: top[i], stats: stats, onOpen: onOpen),
            ],
        ],
      ),
    );
  }
}

class _QuestionRow extends StatelessWidget {
  final BattlegroundQuestion q;
  final SlateStats stats;
  final void Function(CandidateEntry) onOpen;
  const _QuestionRow(
      {required this.q, required this.stats, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final minority = stats.minorityHolders(q);
    final splitPct = (q.disagreementIndex * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(q.question,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700, height: 1.3)),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                gradient: HubTheme.chip,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bolt, size: 12, color: HubTheme.gold),
                  const SizedBox(width: 3),
                  Text('$splitPct% split',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Stance meter: proportional split of decisive answers.
        _StanceMeter(counts: q.counts, answered: q.answered),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            StanceVisuals.pill(Stance.support,
                text: '${q.counts[Stance.support] ?? 0}', dense: true),
            StanceVisuals.pill(Stance.qualified,
                text: '${q.counts[Stance.qualified] ?? 0}', dense: true),
            StanceVisuals.pill(Stance.oppose,
                text: '${q.counts[Stance.oppose] ?? 0}', dense: true),
          ],
        ),
        if (minority.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('MINORITY VIEW',
              style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  letterSpacing: 0.5,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in minority)
                _MinorityChip(
                  entry: e,
                  questionId: q.id,
                  onOpen: () => onOpen(e),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// A slim proportional bar of the decisive stances on one question.
class _StanceMeter extends StatelessWidget {
  final Map<Stance, int> counts;
  final int answered;
  const _StanceMeter({required this.counts, required this.answered});

  @override
  Widget build(BuildContext context) {
    if (answered == 0) return const SizedBox.shrink();
    final segs = <(Stance, int)>[
      (Stance.support, counts[Stance.support] ?? 0),
      (Stance.qualified, counts[Stance.qualified] ?? 0),
      (Stance.oppose, counts[Stance.oppose] ?? 0),
    ].where((s) => s.$2 > 0).toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 8,
        child: Row(
          children: [
            for (var i = 0; i < segs.length; i++)
              Expanded(
                flex: segs[i].$2,
                child: Container(
                  margin: EdgeInsets.only(right: i == segs.length - 1 ? 0 : 1),
                  color: StanceVisuals.fg(segs[i].$1),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MinorityChip extends StatelessWidget {
  final CandidateEntry entry;
  final String questionId;
  final VoidCallback onOpen;
  const _MinorityChip(
      {required this.entry, required this.questionId, required this.onOpen});

  PolicyPosition? get _pos {
    for (final p in entry.model.allPolicyPositions) {
      if (p.id == questionId) return p;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pos = _pos;
    return InkWell(
      onTap: () => _showAnswer(context),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withOpacity(0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HeadshotAvatar(
                file: entry.headshot, name: entry.name, size: 26),
            const SizedBox(width: 6),
            Text(entry.name,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            if (pos != null) ...[
              const SizedBox(width: 6),
              Icon(StanceVisuals.glyph(pos.stance),
                  size: 13, color: StanceVisuals.fg(pos.stance)),
            ],
          ],
        ),
      ),
    );
  }

  void _showAnswer(BuildContext context) {
    final pos = _pos;
    if (pos == null) {
      onOpen();
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final cs = theme.colorScheme;
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              HeadshotAvatar(
                  file: entry.headshot, name: entry.name, size: 38),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.name,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(pos.question,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StanceVisuals.pill(pos.stance, text: pos.answerLabel),
              if (pos.explanation != null &&
                  pos.explanation!.trim().isNotEmpty) ...[
                const SizedBox(height: 14),
                Text('Explanation',
                    style: theme.textTheme.labelMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(pos.explanation!.trim(),
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.4)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                onOpen();
              },
              child: const Text('Open profile'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}
