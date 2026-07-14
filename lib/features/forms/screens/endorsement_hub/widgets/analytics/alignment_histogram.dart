import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../theme/moyd_brand.dart';
import '../../../../widgets/review/stance_visuals.dart';
import '../../models/candidate_entry.dart';
import '../../models/slate_stats.dart';
import '../headshot_avatar.dart';

/// A light-panel (in both themes) alignment distribution: fl_chart bars tinted
/// by the alignment ramp, a median reference line, printed values, a tap-to-
/// filter affordance per bar, and face strips of the top / bottom candidates.
class AlignmentHistogram extends StatelessWidget {
  final SlateStats stats;

  /// Fired when a bar is tapped — the host filters the roster to that range.
  final void Function(double lo, double hi) onSelectRange;
  final void Function(CandidateEntry) onOpen;

  const AlignmentHistogram({
    super.key,
    required this.stats,
    required this.onSelectRange,
    required this.onOpen,
  });

  static const Color _panel = Color(0xFFF4F6FA);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bins = stats.alignmentHistogram();
    final maxCount =
        bins.fold<int>(0, (m, b) => b.count > m ? b.count : m).clamp(1, 1 << 30);
    final median = stats.medianAlignment;

    if (stats.scoredCount == 0) {
      return _card(
        context,
        child: _emptyNote(theme,
            'No scored candidates yet. Alignment scores appear once policy answers come in.'),
      );
    }

    // Top 3 and bottom 2 by alignment.
    final scored = stats.entries
        .where((e) => e.alignmentPct != null)
        .toList()
      ..sort((a, b) => b.alignmentPct!.compareTo(a.alignmentPct!));
    final top = scored.take(3).toList();
    final bottom = scored.length > 3
        ? scored.reversed.take(2).toList()
        : <CandidateEntry>[];

    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart, color: MoydBrand.navy, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Alignment distribution',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              if (median != null)
                Text('median ${median.round()}%',
                    style: theme.textTheme.labelMedium?.copyWith(
                        color: MoydBrand.navy, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 4),
          Text('Tap a bar to filter the roster to that range.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.fromLTRB(8, 16, 12, 8),
            decoration: BoxDecoration(
              color: _panel,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxCount.toDouble() + 0.5,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => MoydBrand.navy,
                      getTooltipItem: (group, gi, rod, ri) {
                        final b = bins[group.x];
                        return BarTooltipItem(
                          '${b.label}%\n${b.count} candidate${b.count == 1 ? '' : 's'}',
                          const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12),
                        );
                      },
                    ),
                    touchCallback: (event, resp) {
                      if (event is FlTapUpEvent &&
                          resp?.spot != null) {
                        final b = bins[resp!.spot!.touchedBarGroupIndex];
                        onSelectRange(b.lo.toDouble(), b.hi.toDouble());
                      }
                    },
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 26,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= bins.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text('${bins[i].lo}',
                                style: const TextStyle(
                                    color: MoydBrand.neutralFg,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600)),
                          );
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (v) => FlLine(
                        color: MoydBrand.neutralFg.withOpacity(0.12),
                        strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  extraLinesData: median == null
                      ? const ExtraLinesData()
                      : ExtraLinesData(
                          verticalLines: [
                            VerticalLine(
                              x: (median / 10).clamp(0, 9).toDouble(),
                              color: MoydBrand.gold,
                              strokeWidth: 2,
                              dashArray: [6, 4],
                            ),
                          ],
                        ),
                  barGroups: [
                    for (var i = 0; i < bins.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: bins[i].count.toDouble(),
                            width: 16,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4)),
                            color: bins[i].count == 0
                                ? MoydBrand.neutralBg
                                : AlignmentVisuals.fg(
                                    (bins[i].lo + 5).toDouble()),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Printed values (accessibility / non-chart readout).
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              for (final b in bins.where((b) => b.count > 0))
                Text('${b.label}%: ${b.count}',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
          if (top.isNotEmpty) ...[
            const SizedBox(height: 16),
            _FaceStrip(
                label: 'Top aligned', entries: top, onOpen: onOpen),
          ],
          if (bottom.isNotEmpty) ...[
            const SizedBox(height: 10),
            _FaceStrip(
                label: 'Lowest aligned',
                entries: bottom,
                onOpen: onOpen),
          ],
        ],
      ),
    );
  }

  Widget _card(BuildContext context, {required Widget child}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      padding: const EdgeInsets.all(20),
      child: child,
    );
  }

  Widget _emptyNote(ThemeData theme, String text) => Row(
        children: [
          Icon(Icons.insights, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
        ],
      );
}

class _FaceStrip extends StatelessWidget {
  final String label;
  final List<CandidateEntry> entries;
  final void Function(CandidateEntry) onOpen;
  const _FaceStrip(
      {required this.label, required this.entries, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final e in entries)
              InkWell(
                onTap: () => onOpen(e),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      HeadshotAvatar(
                          file: e.model.headshot, name: e.name, size: 34),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(e.name,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          if (e.alignmentPct != null)
                            Text('${e.alignmentPct!.round()}% aligned',
                                style: theme.textTheme.labelSmall?.copyWith(
                                    color: cs.onSurfaceVariant)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
