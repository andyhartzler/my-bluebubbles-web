import 'package:flutter/material.dart';

import '../../models/slate_stats.dart';
import '../../theme/hub_theme.dart';

/// The headline slate metrics as a responsive grid of vibrant gradient KPI
/// tiles (Slack-analytics style). Every gradient is dark enough for white
/// text at AA in both themes; see [HubTheme] for the verified pairs.
class SlateScoreboard extends StatelessWidget {
  final SlateStats stats;
  const SlateScoreboard({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final s = stats;
    String pct(double? v) => v == null ? '—' : '${v.round()}%';
    String rate(double? v) => v == null ? '—' : '${(v * 100).round()}%';
    String num(double? v) => v == null ? '—' : v.round().toString();

    final certified = s.certificationRate == null
        ? null
        : (s.certificationRate! * s.total).round();
    final docsOk = s.docsCompleteRate == null
        ? null
        : (s.docsCompleteRate! * s.total).round();

    final tiles = <HubStatTile>[
      HubStatTile(
        gradient: HubTheme.gradNavy,
        icon: Icons.groups_2,
        value: '${s.total}',
        label: 'Applicants',
        sub: '${s.youngDemCount} Young Dems',
      ),
      HubStatTile(
        gradient: HubTheme.gradIndigo,
        icon: Icons.workspace_premium,
        value: '${s.scoredCount}',
        label: 'Scored',
        sub: s.unscoredCount == 0
            ? 'everyone scored'
            : '${s.unscoredCount} unscored',
      ),
      HubStatTile(
        gradient: HubTheme.gradEmerald,
        icon: Icons.insights,
        value: pct(s.meanAlignment),
        label: 'Mean alignment',
        sub: 'median ${pct(s.medianAlignment)}',
      ),
      HubStatTile(
        gradient: HubTheme.gradCyan,
        icon: Icons.linear_scale,
        value: num(s.iqrAlignment),
        label: 'IQR spread',
        sub: s.q1Alignment == null || s.q3Alignment == null
            ? null
            : 'Q1 ${s.q1Alignment!.round()} · Q3 ${s.q3Alignment!.round()}',
      ),
      HubStatTile(
        gradient: HubTheme.gradPurple,
        icon: Icons.history_edu,
        value: rate(s.certificationRate),
        label: 'Certified',
        sub: certified == null ? null : '$certified of ${s.total}',
      ),
      HubStatTile(
        gradient: HubTheme.gradAmber,
        icon: Icons.folder_copy_outlined,
        value: rate(s.docsCompleteRate),
        label: 'Docs complete',
        sub: docsOk == null ? null : '$docsOk of ${s.total}',
      ),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final cols = w > 1080
          ? 6
          : w > 720
              ? 3
              : 2;
      const gap = 12.0;
      final tileW = (w - (cols - 1) * gap) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final t in tiles) SizedBox(width: tileW, child: t),
        ],
      );
    });
  }
}
