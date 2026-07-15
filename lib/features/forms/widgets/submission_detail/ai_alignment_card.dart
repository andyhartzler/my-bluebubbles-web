import 'package:flutter/material.dart';

import '../../models/submission_review_model.dart';
import '../review/stance_visuals.dart';

/// Detail-screen card that surfaces the Gemini-judged alignment: the overall
/// score, Gemini's overall rationale, and an expandable per-issue breakdown.
///
/// This is the authoritative alignment read (Gemini reads each candidate's full
/// answers, including written caveats, against the MOYD platform). The old
/// rule-based score, when present, is shown small and clearly labeled so the
/// committee can see both.
class AiAlignmentCard extends StatelessWidget {
  final AiAlignmentScore ai;

  /// Optional rule-based score, shown as a small labeled comparison chip.
  final double? rulePct;

  const AiAlignmentCard({super.key, required this.ai, this.rulePct});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final pct = ai.pct;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header band.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF263351), Color(0xFF2B4B8C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Gemini alignment',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        'AI-judged against the MOYD platform, reading full answers',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.82),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                AlignmentBadge(pct: pct, showWord: true),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (ai.rationale.trim().isNotEmpty)
                  Text(
                    ai.rationale.trim(),
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                  ),
                if (rulePct != null) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _MiniStat(
                        label: 'Old rule-based score',
                        value: '${rulePct!.round()}%',
                        color: cs.onSurfaceVariant,
                      ),
                      if (ai.model != null && ai.model!.isNotEmpty)
                        _MiniStat(
                          label: 'Model',
                          value: ai.model!,
                          color: cs.onSurfaceVariant,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          if (ai.perIssue.isNotEmpty)
            Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                title: Text(
                  'Per-issue breakdown (${ai.perIssue.length})',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                children: [
                  for (final issue in ai.perIssue) _IssueRow(issue: issue),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _IssueRow extends StatelessWidget {
  final AiIssueScore issue;
  const _IssueRow({required this.issue});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final fg = AlignmentVisuals.fg(issue.score.toDouble());
    final bg = AlignmentVisuals.bg(issue.score.toDouble());
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            padding: const EdgeInsets.symmetric(vertical: 3),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              '${issue.score}',
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  issue.label.isNotEmpty ? issue.label : issue.id,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (issue.rationale.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      issue.rationale.trim(),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant, height: 1.35),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(
            text: '$label: ',
            style: TextStyle(color: color, fontSize: 11.5),
          ),
          TextSpan(
            text: value,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ]),
      ),
    );
  }
}
