import 'package:flutter/material.dart';
import '../../models/submission_review_model.dart';
import '../../theme/moyd_brand.dart';
import '../review/stance_visuals.dart';
import 'review_text.dart';

/// Renders a section's policy positions: a summary line plus one row each of
/// [position label] + [stance pill] + optional expandable explanation.
///
/// The pill is [StanceVisuals.pill], the same one the compare matrix, the
/// stance bars and the answer rows use. The fixed-width glyphless pill this
/// file used to carry was the only stance chip in the product that read by
/// color and word alone, with no icon, so it was also the only one that
/// failed the "never by color alone" rule the rest of the palette follows.
class PolicyPositionsGrid extends StatelessWidget {
  final List<PolicyPosition> positions;

  const PolicyPositionsGrid({super.key, required this.positions});

  @override
  Widget build(BuildContext context) {
    var support = 0, oppose = 0, qualified = 0;
    for (final p in positions) {
      if (p.stance == Stance.support) support++;
      if (p.stance == Stance.oppose) oppose++;
      if (p.stance == Stance.qualified) qualified++;
    }

    final summaryParts = <String>[
      if (support > 0) '$support support',
      if (oppose > 0) '$oppose oppose',
      if (qualified > 0) '$qualified qualified',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (summaryParts.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              summaryParts.join('  ·  '),
              style: ReviewText.caption(context)
                  .copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        for (int i = 0; i < positions.length; i++)
          _PolicyRow(
            position: positions[i],
            alt: i.isOdd,
          ),
      ],
    );
  }
}

class _PolicyRow extends StatefulWidget {
  final PolicyPosition position;
  final bool alt;
  const _PolicyRow({required this.position, required this.alt});

  @override
  State<_PolicyRow> createState() => _PolicyRowState();
}

class _PolicyRowState extends State<_PolicyRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final p = widget.position;
    final hasExplain = p.explanation != null && p.explanation!.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        // Zebra stripe pre-blended against the card surface rather than left
        // as a translucent fill, so the color under this row's text is a
        // known value in both themes instead of whatever composites behind it.
        color: widget.alt
            ? Color.alphaBlend(
                cs.surfaceContainerHighest.withValues(alpha: 0.35), cs.surface)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                    Text(p.question, style: ReviewText.body(context)),
                    if (p.answerLabel.isNotEmpty &&
                        p.answerLabel.toLowerCase() !=
                            StanceVisuals.label(p.stance).toLowerCase()) ...[
                      const SizedBox(height: 2),
                      Text(
                        p.answerLabel,
                        style: ReviewText.secondary(context)
                            .copyWith(fontStyle: FontStyle.italic),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              StanceVisuals.pill(p.stance,
                  text: StanceVisuals.label(p.stance)),
            ],
          ),
          if (hasExplain) ...[
            const SizedBox(height: 6),
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: cs.primary,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    _expanded
                        ? 'Hide ${p.explanationLabel.toLowerCase()}'
                        : p.explanationLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 160),
              alignment: Alignment.topLeft,
              child: _expanded
                  ? Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 6),
                      padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
                      decoration: const BoxDecoration(
                        border: Border(
                          left: BorderSide(color: MoydBrand.gold, width: 3),
                        ),
                      ),
                      child: Text(
                        p.explanation!.trim(),
                        style: ReviewText.body(context),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ],
      ),
    );
  }
}
