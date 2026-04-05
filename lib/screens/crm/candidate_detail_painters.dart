import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/models/crm/candidate.dart';

// ═══════════════════════════════════════════════════════════════
//  TAB BAR DELEGATE — Pinned tab bar in NestedScrollView
// ═══════════════════════════════════════════════════════════════

class CandidateTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  const CandidateTabBarDelegate({required this.tabBar});

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0b1e37),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant CandidateTabBarDelegate oldDelegate) => false;
}

// ═══════════════════════════════════════════════════════════════
//  SCORE RADAR PAINTER — 5-axis radar/spider chart
// ═══════════════════════════════════════════════════════════════

class ScoreRadarPainter extends CustomPainter {
  final Map<String, double> scores;
  final double maxValue;
  final Color accentColor;

  ScoreRadarPainter({
    required this.scores,
    required this.maxValue,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 20;
    final axes = scores.keys.toList();
    final n = axes.length;
    if (n == 0) return;

    final angleStep = 2 * math.pi / n;
    final startAngle = -math.pi / 2; // Top

    // Draw grid circles
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int ring = 1; ring <= 4; ring++) {
      final r = radius * ring / 4;
      canvas.drawCircle(center, r, gridPaint);
    }

    // Draw axis lines
    final axisPaint = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..strokeWidth = 1;

    for (int i = 0; i < n; i++) {
      final angle = startAngle + angleStep * i;
      final end = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      canvas.drawLine(center, end, axisPaint);
    }

    // Draw data polygon
    final dataPath = Path();
    final fillPaint = Paint()
      ..color = accentColor.withOpacity(0.2)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (int i = 0; i < n; i++) {
      final value = scores[axes[i]] ?? 0;
      final normalizedValue = (value / maxValue).clamp(0.0, 1.0);
      final angle = startAngle + angleStep * i;
      final point = Offset(
        center.dx + radius * normalizedValue * math.cos(angle),
        center.dy + radius * normalizedValue * math.sin(angle),
      );

      if (i == 0) {
        dataPath.moveTo(point.dx, point.dy);
      } else {
        dataPath.lineTo(point.dx, point.dy);
      }
    }
    dataPath.close();

    canvas.drawPath(dataPath, fillPaint);
    canvas.drawPath(dataPath, strokePaint);

    // Draw data points
    final dotPaint = Paint()..color = accentColor;
    for (int i = 0; i < n; i++) {
      final value = scores[axes[i]] ?? 0;
      final normalizedValue = (value / maxValue).clamp(0.0, 1.0);
      final angle = startAngle + angleStep * i;
      final point = Offset(
        center.dx + radius * normalizedValue * math.cos(angle),
        center.dy + radius * normalizedValue * math.sin(angle),
      );
      canvas.drawCircle(point, 4, dotPaint);
    }

    // Draw labels
    for (int i = 0; i < n; i++) {
      final angle = startAngle + angleStep * i;
      final labelOffset = Offset(
        center.dx + (radius + 16) * math.cos(angle),
        center.dy + (radius + 16) * math.sin(angle),
      );

      final textPainter = TextPainter(
        text: TextSpan(
          text: axes[i],
          style: const TextStyle(color: Colors.white54, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(
          labelOffset.dx - textPainter.width / 2,
          labelOffset.dy - textPainter.height / 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ═══════════════════════════════════════════════════════════════
//  MARGIN TREND PAINTER — Win margin line chart
// ═══════════════════════════════════════════════════════════════

class MarginTrendPainter extends CustomPainter {
  final List<ElectionResult> results;

  MarginTrendPainter({required this.results});

  @override
  void paint(Canvas canvas, Size size) {
    if (results.isEmpty) return;

    final n = results.length;
    final stepX = n > 1 ? size.width / (n - 1) : size.width / 2;
    final midY = size.height / 2;

    // Draw center line (50-50)
    final centerPaint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, midY), Offset(size.width, midY), centerPaint);

    // Draw margin line
    final linePaint = Paint()
      ..color = BrandColors.sunriseGold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [BrandColors.sunriseGold.withOpacity(0.3), Colors.transparent],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final linePath = Path();
    final fillPath = Path();

    for (int i = 0; i < n; i++) {
      final r = results[i];
      final demPct = r.demPercent ?? 50;
      final margin = demPct - 50; // Positive = Dem win, Negative = Rep win
      final x = n > 1 ? stepX * i : size.width / 2;
      final y = midY - (margin / 50) * midY; // Scale margin to chart height

      if (i == 0) {
        linePath.moveTo(x, y);
        fillPath.moveTo(x, midY);
        fillPath.lineTo(x, y);
      } else {
        linePath.lineTo(x, y);
        fillPath.lineTo(x, y);
      }

      // Draw dot
      final dotColor = margin >= 0 ? BrandColors.democratBlue : BrandColors.republicanRed;
      canvas.drawCircle(Offset(x, y), 4, Paint()..color = dotColor);

      // Year label
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${r.year}',
          style: const TextStyle(color: Colors.white38, fontSize: 9),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, size.height - 12));
    }

    // Close fill path
    if (n > 1) {
      fillPath.lineTo(stepX * (n - 1), midY);
    } else {
      fillPath.lineTo(size.width / 2, midY);
    }
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(linePath, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
