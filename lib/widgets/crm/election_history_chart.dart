import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/models/crm/candidate.dart';

// ═══════════════════════════════════════════════════════════════
//  ELECTION HISTORY CHART
//  Horizontal bar chart showing D vs R votes per year
//  Color coded (blue/red), winner highlighted, trend arrow
// ═══════════════════════════════════════════════════════════════

class ElectionHistoryChart extends StatefulWidget {
  final List<ElectionResult> results;
  final String? districtLabel;
  final bool showTrend;
  final bool animate;

  const ElectionHistoryChart({
    super.key,
    required this.results,
    this.districtLabel,
    this.showTrend = true,
    this.animate = true,
  });

  @override
  State<ElectionHistoryChart> createState() => _ElectionHistoryChartState();
}

class _ElectionHistoryChartState extends State<ElectionHistoryChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _progress = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    if (widget.animate) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            BrandColors.unityBlue,
            BrandColors.unityBlue.withOpacity(0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          if (widget.results.isEmpty)
            _buildEmpty()
          else ...[
            ..._buildBars(),
            if (widget.showTrend) ...[
              const SizedBox(height: 16),
              _buildTrendIndicator(),
            ],
            const SizedBox(height: 12),
            _buildLegend(),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(Icons.how_to_vote, color: BrandColors.steelBlue, size: 20),
        const SizedBox(width: 8),
        Text(
          widget.districtLabel != null
              ? 'Election History — ${widget.districtLabel}'
              : 'Election History',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.white.withOpacity(0.3), size: 20),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Historical election results will be available once SOS data is integrated.',
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildBars() {
    final sorted = List<ElectionResult>.from(widget.results)
      ..sort((a, b) => b.year.compareTo(a.year)); // Most recent first

    return sorted.map((result) {
      final demPct = result.demPercent ?? 0;
      final repPct = result.repPercent ?? 0;
      final total = demPct + repPct;
      final demWidth = total > 0 ? demPct / total : 0.5;
      final repWidth = total > 0 ? repPct / total : 0.5;

      return AnimatedBuilder(
        animation: _progress,
        builder: (context, _) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Year + winner label
                Row(
                  children: [
                    Text(
                      '${result.year}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (result.demWon)
                      _winnerBadge('D Win', BrandColors.democratBlue)
                    else if (result.repWon)
                      _winnerBadge('R Win', BrandColors.republicanRed),
                    const Spacer(),
                    // Margin display
                    Text(
                      'D ${demPct.toStringAsFixed(1)}% — R ${repPct.toStringAsFixed(1)}%',
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Dual bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 18,
                    child: Row(
                      children: [
                        // Dem bar
                        Expanded(
                          flex: (demWidth * 1000 * _progress.value).round().clamp(1, 999),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  BrandColors.democratBlue.withOpacity(0.8),
                                  BrandColors.democratBlue,
                                ],
                              ),
                            ),
                            alignment: Alignment.center,
                            child: demPct > 15
                                ? Text(
                                    '${demPct.toStringAsFixed(0)}%',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        // Rep bar
                        Expanded(
                          flex: (repWidth * 1000 * _progress.value).round().clamp(1, 999),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  BrandColors.republicanRed,
                                  BrandColors.republicanRed.withOpacity(0.8),
                                ],
                              ),
                            ),
                            alignment: Alignment.center,
                            child: repPct > 15
                                ? Text(
                                    '${repPct.toStringAsFixed(0)}%',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Candidate names
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (result.demCandidate != null)
                        Text(
                          result.demCandidate!,
                          style: TextStyle(
                            color: BrandColors.democratBlue.withOpacity(0.7),
                            fontSize: 10,
                          ),
                        )
                      else
                        const SizedBox(),
                      if (result.repCandidate != null)
                        Text(
                          result.repCandidate!,
                          style: TextStyle(
                            color: BrandColors.republicanRed.withOpacity(0.7),
                            fontSize: 10,
                          ),
                        )
                      else
                        const SizedBox(),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    }).toList();
  }

  Widget _winnerBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTrendIndicator() {
    if (widget.results.length < 2) return const SizedBox.shrink();

    final sorted = List<ElectionResult>.from(widget.results)
      ..sort((a, b) => a.year.compareTo(b.year));

    // Calculate trend: are Dems gaining or losing share?
    double firstDem = sorted.first.demPercent ?? 50;
    double lastDem = sorted.last.demPercent ?? 50;
    double shift = lastDem - firstDem;

    Color trendColor;
    IconData trendIcon;
    String trendLabel;

    if (shift > 2) {
      trendColor = BrandColors.democratBlue;
      trendIcon = Icons.trending_up;
      trendLabel = 'Getting bluer (+${shift.toStringAsFixed(1)}pp)';
    } else if (shift < -2) {
      trendColor = BrandColors.republicanRed;
      trendIcon = Icons.trending_down;
      trendLabel = 'Getting redder (${shift.toStringAsFixed(1)}pp)';
    } else {
      trendColor = Colors.amber;
      trendIcon = Icons.trending_flat;
      trendLabel = 'Stable (${shift > 0 ? '+' : ''}${shift.toStringAsFixed(1)}pp)';
    }

    // Partisan lean index
    final avgDem = sorted.map((r) => r.demPercent ?? 50).reduce((a, b) => a + b) / sorted.length;
    final leanLabel = avgDem > 55
        ? 'Safe D'
        : avgDem > 52
            ? 'Lean D'
            : avgDem > 48
                ? 'Toss-up'
                : avgDem > 45
                    ? 'Lean R'
                    : 'Safe R';
    final leanColor = avgDem > 52
        ? BrandColors.democratBlue
        : avgDem < 48
            ? BrandColors.republicanRed
            : Colors.amber;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Icon(trendIcon, color: trendColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trendLabel,
                  style: TextStyle(
                    color: trendColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${sorted.first.year}–${sorted.last.year} trend',
                  style: const TextStyle(color: Colors.white30, fontSize: 10),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: leanColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: leanColor.withOpacity(0.4)),
            ),
            child: Text(
              leanLabel,
              style: TextStyle(
                color: leanColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendItem('Democrat', BrandColors.democratBlue),
        const SizedBox(width: 20),
        _legendItem('Republican', BrandColors.republicanRed),
      ],
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  MINI ELECTION BAR — compact version for inline use
// ═══════════════════════════════════════════════════════════════

class MiniElectionBar extends StatelessWidget {
  final double demPercent;
  final double repPercent;
  final int year;
  final double height;

  const MiniElectionBar({
    super.key,
    required this.demPercent,
    required this.repPercent,
    required this.year,
    this.height = 14,
  });

  @override
  Widget build(BuildContext context) {
    final total = demPercent + repPercent;
    final dw = total > 0 ? demPercent / total : 0.5;
    final rw = total > 0 ? repPercent / total : 0.5;

    return Row(
      children: [
        Text(
          '$year',
          style: const TextStyle(color: Colors.white38, fontSize: 10),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: height,
              child: Row(
                children: [
                  Expanded(
                    flex: (dw * 100).round().clamp(1, 99),
                    child: Container(color: BrandColors.democratBlue),
                  ),
                  Expanded(
                    flex: (rw * 100).round().clamp(1, 99),
                    child: Container(color: BrandColors.republicanRed),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
