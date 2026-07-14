import 'package:flutter/material.dart';

import '../../../../models/submission_review_model.dart';
import '../../../../theme/moyd_brand.dart';
import '../../../../widgets/review/stance_visuals.dart';
import '../../models/candidate_entry.dart';
import '../../models/slate_stats.dart';
import '../headshot_avatar.dart';

/// The most contested policy questions, ranked by disagreement index, each with
/// the minority-holding candidates surfaced as tappable avatar chips.
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

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_fire_department_outlined,
                  color: MoydBrand.navy, size: 20),
              const SizedBox(width: 8),
              Text('Battleground questions',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 4),
          Text('Where the field is most divided.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant)),
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
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: MoydBrand.navy,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('$splitPct% split',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _stanceCount(Stance.support, q.counts[Stance.support] ?? 0),
            _stanceCount(Stance.qualified, q.counts[Stance.qualified] ?? 0),
            _stanceCount(Stance.oppose, q.counts[Stance.oppose] ?? 0),
          ],
        ),
        if (minority.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Minority view',
              style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
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

  Widget _stanceCount(Stance s, int count) {
    if (count == 0) {
      return StanceVisuals.pill(s, text: '0', dense: true);
    }
    return StanceVisuals.pill(s, text: '$count', dense: true);
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
            HeadshotAvatar(file: entry.model.headshot, name: entry.name, size: 26),
            const SizedBox(width: 6),
            Text(entry.name,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600)),
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
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.name,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(pos.question,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: cs.onSurfaceVariant)),
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
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(pos.explanation!.trim(),
                    style: theme.textTheme.bodyMedium),
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
