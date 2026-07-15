import 'package:flutter/material.dart';

import '../../models/form_schema.dart';
import '../../models/form_submission.dart';
import '../../models/submission_review_model.dart';
import '../../theme/moyd_brand.dart';
import 'stance_visuals.dart';

/// Per-policy 100%-stacked stance bars (support / qualified / oppose / other)
/// for the endorsement "Where you stand" questions, computed across every
/// submission via [SubmissionReviewModel].
///
/// Replaces the generic `chartableFields.take(3)` breakdown for the
/// endorsement form, which surfaced arbitrary select fields instead of the
/// decision-useful policy split.
class PolicyStanceBars extends StatelessWidget {
  final FormSchema form;
  final List<FormSubmission> submissions;

  const PolicyStanceBars({
    Key? key,
    required this.form,
    required this.submissions,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Tally stances per policy question across all submissions.
    final order = <String, int>{};
    for (var i = 0; i < form.schema.fields.length; i++) {
      order[form.schema.fields[i].id] = i;
    }
    final labels = <String, String>{};
    final counts = <String, Map<Stance, int>>{};
    for (final s in submissions) {
      final model = SubmissionReviewModel.from(form, s);
      for (final p in model.allPolicyPositions) {
        labels.putIfAbsent(p.id, () => p.question);
        final m = counts.putIfAbsent(p.id, () => <Stance, int>{});
        m[p.stance] = (m[p.stance] ?? 0) + 1;
      }
    }

    if (counts.isEmpty) return const SizedBox.shrink();

    final ids = counts.keys.toList()
      ..sort((a, b) => (order[a] ?? 1 << 30).compareTo(order[b] ?? 1 << 30));

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [MoydBrand.navy, Color(0xFF2B4B8C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.how_to_vote_outlined,
                      color: Colors.white, size: 19),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Where the field stands',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Stance split across ${submissions.length} candidate${submissions.length == 1 ? '' : 's'}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            for (final id in ids)
              _StanceBar(
                label: labels[id]!,
                counts: counts[id]!,
              ),
          ],
        ),
      ),
    );
  }
}

class _StanceBar extends StatelessWidget {
  final String label;
  final Map<Stance, int> counts;

  const _StanceBar({required this.label, required this.counts});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final support = counts[Stance.support] ?? 0;
    final qualified = counts[Stance.qualified] ?? 0;
    final oppose = counts[Stance.oppose] ?? 0;
    final other = (counts[Stance.neutral] ?? 0) + (counts[Stance.unsure] ?? 0);
    final total = support + qualified + oppose + other;
    if (total == 0) return const SizedBox.shrink();

    final segments = <(Stance, int)>[
      (Stance.support, support),
      (Stance.qualified, qualified),
      (Stance.oppose, oppose),
      (Stance.neutral, other),
    ].where((e) => e.$2 > 0).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 26,
              child: Row(
                children: [
                  for (final seg in segments)
                    Expanded(
                      flex: seg.$2,
                      child: Tooltip(
                        message:
                            '${StanceVisuals.label(seg.$1)}: ${seg.$2} (${(seg.$2 / total * 100).round()}%)',
                        child: Container(
                          color: StanceVisuals.fg(seg.$1),
                          alignment: Alignment.center,
                          child: seg.$2 / total > 0.12
                              ? Text(
                                  '${seg.$2}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 2,
            children: [
              if (support > 0) _tag(Stance.support, support, total),
              if (qualified > 0) _tag(Stance.qualified, qualified, total),
              if (oppose > 0) _tag(Stance.oppose, oppose, total),
              if (other > 0) _tag(Stance.neutral, other, total),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tag(Stance s, int count, int total) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: StanceVisuals.fg(s),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '${StanceVisuals.label(s)} $count',
          style: TextStyle(fontSize: 11, color: StanceVisuals.fg(s)),
        ),
      ],
    );
  }
}
