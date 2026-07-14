import 'package:flutter/material.dart';
import '../../models/submission_review_model.dart';
import '../../theme/moyd_brand.dart';

/// Renders a section's policy positions: a summary line plus one row each of
/// [position label] + [stance pill] + optional expandable explanation.
class PolicyPositionsGrid extends StatelessWidget {
  final List<PolicyPosition> positions;

  const PolicyPositionsGrid({super.key, required this.positions});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

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
              style: theme.textTheme.labelLarge?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
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
        color: widget.alt
            ? cs.surfaceContainerHighest.withOpacity(0.25)
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
                    Text(
                      p.question,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.3),
                    ),
                    if (p.answerLabel.isNotEmpty &&
                        p.answerLabel.toLowerCase() !=
                            _StancePill.labelFor(p.stance).toLowerCase()) ...[
                      const SizedBox(height: 2),
                      Text(
                        p.answerLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _StancePill(stance: p.stance),
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
                    _expanded ? 'Hide explanation' : 'Explanation',
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
                        style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
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

class _StancePill extends StatelessWidget {
  final Stance stance;
  const _StancePill({required this.stance});

  static String labelFor(Stance s) {
    switch (s) {
      case Stance.support:
        return 'Support';
      case Stance.oppose:
        return 'Oppose';
      case Stance.qualified:
        return 'Qualified';
      case Stance.unsure:
        return 'Unsure';
      case Stance.neutral:
        return 'See note';
    }
  }

  ({Color fg, Color bg}) _colors() {
    switch (stance) {
      case Stance.support:
        return (fg: MoydBrand.supportFg, bg: MoydBrand.supportBg);
      case Stance.oppose:
        return (fg: MoydBrand.opposeFg, bg: MoydBrand.opposeBg);
      case Stance.qualified:
        return (fg: MoydBrand.qualifiedFg, bg: MoydBrand.qualifiedBg);
      case Stance.unsure:
      case Stance.neutral:
        return (fg: MoydBrand.neutralFg, bg: MoydBrand.neutralBg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _colors();
    return Container(
      width: 90,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: Text(
        labelFor(stance),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: c.fg,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
