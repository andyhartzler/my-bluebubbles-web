import 'package:flutter/material.dart';

import '../../../../theme/moyd_brand.dart';
import '../../models/slate_stats.dart';

/// A solid-navy scoreboard of headline slate metrics (white numerals, gold
/// labels). Navy island so it reads identically in light and dark themes.
class SlateScoreboard extends StatelessWidget {
  final SlateStats stats;
  const SlateScoreboard({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final s = stats;
    String pct(double? v) => v == null ? '—' : '${v.round()}%';
    String rate(double? v) => v == null ? '—' : '${(v * 100).round()}%';
    String num(double? v) => v == null ? '—' : v.round().toString();

    final tiles = <(_ScoreKind, String, String)>[
      (_ScoreKind.gold, '${s.total}', 'Applicants'),
      (_ScoreKind.plain, '${s.scoredCount}', 'Scored'),
      (_ScoreKind.plain, pct(s.meanAlignment), 'Mean alignment'),
      (_ScoreKind.plain, pct(s.medianAlignment), 'Median alignment'),
      (_ScoreKind.plain, num(s.iqrAlignment), 'IQR spread'),
      (_ScoreKind.plain, rate(s.certificationRate), 'Certified'),
      (_ScoreKind.plain, rate(s.docsCompleteRate), 'Docs complete'),
      (_ScoreKind.plain, '${s.unscoredCount}', 'Unscored'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: MoydBrand.navy,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.leaderboard, color: MoydBrand.gold, size: 20),
              const SizedBox(width: 8),
              Text('Slate scoreboard',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, constraints) {
            final cols = constraints.maxWidth > 560
                ? 4
                : constraints.maxWidth > 360
                    ? 3
                    : 2;
            return Wrap(
              spacing: 12,
              runSpacing: 16,
              children: [
                for (final t in tiles)
                  SizedBox(
                    width: (constraints.maxWidth - (cols - 1) * 12) / cols,
                    child: _Tile(kind: t.$1, value: t.$2, label: t.$3),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

enum _ScoreKind { plain, gold }

class _Tile extends StatelessWidget {
  final _ScoreKind kind;
  final String value;
  final String label;
  const _Tile({required this.kind, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = kind == _ScoreKind.gold ? MoydBrand.gold : Colors.white;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                height: 1.0)),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 11.5,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}
