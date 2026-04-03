import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/models/crm/candidate.dart';

// ═══════════════════════════════════════════════════════════════
//  CANDIDATE SCORE CARD
//  Reusable widget to display Young Dem Score as a radar chart
//  with animated fill and breakdown bars
// ═══════════════════════════════════════════════════════════════

class CandidateScoreCard extends StatefulWidget {
  final Candidate candidate;
  final bool compact;
  final bool showBreakdown;
  final bool animate;

  const CandidateScoreCard({
    super.key,
    required this.candidate,
    this.compact = false,
    this.showBreakdown = true,
    this.animate = true,
  });

  @override
  State<CandidateScoreCard> createState() => _CandidateScoreCardState();
}

class _CandidateScoreCardState extends State<CandidateScoreCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _progress = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
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

  Candidate get c => widget.candidate;

  @override
  Widget build(BuildContext context) {
    if (widget.compact) return _buildCompact();
    return _buildFull();
  }

  // ── Compact version for list views ──
  Widget _buildCompact() {
    final score = c.youngDemScore;
    return AnimatedBuilder(
      animation: _progress,
      builder: (context, _) {
        final val = (score * _progress.value).round();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _scoreColor(score).withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _scoreColor(score).withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star, color: _scoreColor(score), size: 14),
              const SizedBox(width: 4),
              Text(
                '$val',
                style: TextStyle(
                  color: _scoreColor(score),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Full version with radar chart ──
  Widget _buildFull() {
    return Container(
      padding: const EdgeInsets.all(20),
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
          // Header
          Row(
            children: [
              const Icon(Icons.star, color: BrandColors.sunriseGold, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Young Democrat Score',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              AnimatedBuilder(
                animation: _progress,
                builder: (context, _) {
                  final val = (c.youngDemScore * _progress.value).round();
                  return Text(
                    '$val / 100',
                    style: TextStyle(
                      color: _scoreColor(c.youngDemScore),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Radar chart
          Center(
            child: AnimatedBuilder(
              animation: _progress,
              builder: (context, _) {
                return SizedBox(
                  width: 220,
                  height: 220,
                  child: CustomPaint(
                    painter: _RadarChartPainter(
                      values: [
                        c.scoreParty / 100.0,
                        c.scorePrimary / 100.0,
                        c.scoreContributions / 100.0,
                        c.scoreVan / 100.0,
                        c.scoreEndorsements / 100.0,
                      ],
                      labels: ['Party', 'Primary', 'Finance', 'VAN', 'Endorse'],
                      progress: _progress.value,
                      fillColor: _scoreColor(c.youngDemScore),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Score label
          Center(
            child: Text(
              _scoreLabel(c.youngDemScore),
              style: TextStyle(
                color: _scoreColor(c.youngDemScore),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // Breakdown bars
          if (widget.showBreakdown) ...[
            const SizedBox(height: 20),
            _breakdownBar('Party Registration', c.scoreParty, BrandColors.democratBlue),
            _breakdownBar('Primary Engagement', c.scorePrimary, Colors.purpleAccent),
            _breakdownBar('Campaign Finance', c.scoreContributions, BrandColors.sunriseGold),
            _breakdownBar('VAN Score', c.scoreVan, BrandColors.momentumBlue),
            _breakdownBar('Endorsements', c.scoreEndorsements, BrandColors.success),
          ],
        ],
      ),
    );
  }

  Widget _breakdownBar(String label, int score, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedBuilder(
        animation: _progress,
        builder: (context, _) {
          final val = (score * _progress.value).round();
          final progress = (score / 100.0 * _progress.value).clamp(0.0, 1.0);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  Text(
                    '$val',
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: Colors.white.withOpacity(0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static Color _scoreColor(int score) {
    if (score >= 80) return BrandColors.success;
    if (score >= 50) return BrandColors.sunriseGold;
    if (score >= 30) return Colors.orange;
    return Colors.white54;
  }

  static String _scoreLabel(int score) {
    if (score >= 80) return 'Excellent — Core Young Democrat';
    if (score >= 50) return 'Strong — Active Young Democrat';
    if (score >= 30) return 'Promising — Potential Ally';
    return 'Developing — Needs Engagement';
  }
}

// ═══════════════════════════════════════════════════════════════
//  RADAR CHART PAINTER
//  5-axis radar chart for score visualization
// ═══════════════════════════════════════════════════════════════

class _RadarChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final double progress;
  final Color fillColor;

  _RadarChartPainter({
    required this.values,
    required this.labels,
    required this.progress,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 24;
    final sides = values.length;
    final angle = (2 * math.pi) / sides;
    final startAngle = -math.pi / 2; // Start from top

    // Draw grid rings
    for (int ring = 1; ring <= 4; ring++) {
      final ringRadius = radius * ring / 4;
      final gridPaint = Paint()
        ..color = Colors.white.withOpacity(0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8;

      final path = Path();
      for (int i = 0; i <= sides; i++) {
        final a = startAngle + angle * (i % sides);
        final p = Offset(
          center.dx + ringRadius * math.cos(a),
          center.dy + ringRadius * math.sin(a),
        );
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(path, gridPaint);
    }

    // Draw axis lines
    for (int i = 0; i < sides; i++) {
      final a = startAngle + angle * i;
      final lineEnd = Offset(
        center.dx + radius * math.cos(a),
        center.dy + radius * math.sin(a),
      );
      canvas.drawLine(
        center,
        lineEnd,
        Paint()
          ..color = Colors.white.withOpacity(0.12)
          ..strokeWidth = 0.8,
      );
    }

    // Draw filled area
    final fillPath = Path();
    final borderPath = Path();
    for (int i = 0; i <= sides; i++) {
      final idx = i % sides;
      final a = startAngle + angle * idx;
      final val = (values[idx] * progress).clamp(0.0, 1.0);
      final r = radius * math.max(val, 0.05); // Minimum visible radius
      final p = Offset(
        center.dx + r * math.cos(a),
        center.dy + r * math.sin(a),
      );
      if (i == 0) {
        fillPath.moveTo(p.dx, p.dy);
        borderPath.moveTo(p.dx, p.dy);
      } else {
        fillPath.lineTo(p.dx, p.dy);
        borderPath.lineTo(p.dx, p.dy);
      }
    }

    // Fill
    canvas.drawPath(
      fillPath,
      Paint()
        ..color = fillColor.withOpacity(0.25)
        ..style = PaintingStyle.fill,
    );

    // Border
    canvas.drawPath(
      borderPath,
      Paint()
        ..color = fillColor.withOpacity(0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // Draw dots at vertices
    for (int i = 0; i < sides; i++) {
      final a = startAngle + angle * i;
      final val = (values[i] * progress).clamp(0.0, 1.0);
      final r = radius * math.max(val, 0.05);
      final p = Offset(
        center.dx + r * math.cos(a),
        center.dy + r * math.sin(a),
      );

      canvas.drawCircle(
        p,
        4.0,
        Paint()..color = fillColor,
      );
      canvas.drawCircle(
        p,
        2.0,
        Paint()..color = Colors.white,
      );
    }

    // Draw labels
    for (int i = 0; i < sides; i++) {
      final a = startAngle + angle * i;
      final labelRadius = radius + 18;
      final labelPos = Offset(
        center.dx + labelRadius * math.cos(a),
        center.dy + labelRadius * math.sin(a),
      );

      final textPainter = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(
          labelPos.dx - textPainter.width / 2,
          labelPos.dy - textPainter.height / 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RadarChartPainter old) {
    return progress != old.progress || fillColor != old.fillColor;
  }
}

// ═══════════════════════════════════════════════════════════════
//  MINI SCORE BADGE — Tiny inline score display
// ═══════════════════════════════════════════════════════════════

class MiniScoreBadge extends StatelessWidget {
  final int score;
  final double size;

  const MiniScoreBadge({super.key, required this.score, this.size = 24});

  @override
  Widget build(BuildContext context) {
    final color = CandidateScoreCard._scoreColor(score);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(0.5), width: 1.5),
      ),
      child: Center(
        child: Text(
          '$score',
          style: TextStyle(
            color: color,
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
