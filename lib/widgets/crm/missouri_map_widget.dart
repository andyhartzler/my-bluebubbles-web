import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/models/crm/candidate.dart';

// ═══════════════════════════════════════════════════════════════
//  MISSOURI MAP WIDGET
//  Interactive CustomPaint-based map of Missouri with 163 state
//  house districts, color-coded by candidate status.
//  Supports tap, pinch-to-zoom, pan, and animated selection.
// ═══════════════════════════════════════════════════════════════

class MissouriMapWidget extends StatefulWidget {
  final Map<String, List<Candidate>> districtMap;
  final ValueChanged<String>? onDistrictTap;
  final String? selectedDistrict;
  final double height;
  final bool showLabels;
  final bool showLegend;
  final bool interactive;
  final bool compactMode;

  const MissouriMapWidget({
    super.key,
    required this.districtMap,
    this.onDistrictTap,
    this.selectedDistrict,
    this.height = 320,
    this.showLabels = true,
    this.showLegend = true,
    this.interactive = true,
    this.compactMode = false,
  });

  @override
  State<MissouriMapWidget> createState() => _MissouriMapWidgetState();
}

class _MissouriMapWidgetState extends State<MissouriMapWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _entranceController;
  late Animation<double> _entranceAnimation;

  // Transform state for pinch/pan
  final TransformationController _transformController = TransformationController();
  double _currentScale = 1.0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _entranceAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );
    _entranceController.forward();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _entranceController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _entranceAnimation,
      child: Container(
        margin: widget.compactMode
            ? EdgeInsets.zero
            : const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              BrandColors.unityBlue.withOpacity(0.9),
              BrandColors.unityBlue,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(widget.compactMode ? 12 : 20),
          boxShadow: widget.compactMode
              ? null
              : [
                  BoxShadow(
                    color: BrandColors.momentumBlue.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!widget.compactMode) _buildTitle(),
            _buildMap(),
            if (widget.showLegend && !widget.compactMode) _buildLegendBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          const Icon(Icons.map_outlined, color: BrandColors.sunriseGold, size: 22),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Missouri 2026 — State House Districts',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (_currentScale > 1.0)
            GestureDetector(
              onTap: () {
                _transformController.value = Matrix4.identity();
                setState(() => _currentScale = 1.0);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Reset',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    final mapWidget = AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return CustomPaint(
          painter: _MissouriDistrictPainter(
            districtMap: widget.districtMap,
            selectedDistrict: widget.selectedDistrict,
            pulseValue: _pulseAnimation.value,
            showLabels: widget.showLabels,
            entranceProgress: _entranceAnimation.value,
          ),
          size: Size.infinite,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapDown: widget.interactive ? _handleTap : null,
          ),
        );
      },
    );

    if (widget.interactive) {
      return SizedBox(
        height: widget.height,
        child: ClipRRect(
          borderRadius: widget.compactMode
              ? BorderRadius.circular(12)
              : const BorderRadius.vertical(bottom: Radius.circular(12)),
          child: InteractiveViewer(
            transformationController: _transformController,
            minScale: 1.0,
            maxScale: 4.0,
            onInteractionUpdate: (details) {
              setState(() => _currentScale = details.scale);
            },
            child: mapWidget,
          ),
        ),
      );
    }

    return SizedBox(height: widget.height, child: mapWidget);
  }

  Widget _buildLegendBar() {
    final totalDistricts = widget.districtMap.length;
    int ydDistricts = 0;
    int demDistricts = 0;
    int repDistricts = 0;
    int contested = 0;

    for (final entry in widget.districtMap.entries) {
      final candidates = entry.value;
      final hasYd = candidates.any((c) => c.isYoungDem);
      final hasDem = candidates.any((c) => c.isDemocrat);
      final hasRep = candidates.any((c) => c.isRepublican);

      if (hasYd) ydDistricts++;
      if (hasDem && !hasRep) demDistricts++;
      if (hasDem && hasRep) contested++;
      if (!hasDem && hasRep) repDistricts++;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          _legendChip(BrandColors.momentumBlue, 'Young Dem', ydDistricts),
          _legendChip(Colors.blueGrey, 'Dem', demDistricts),
          _legendChip(Colors.amber, 'Contested', contested),
          _legendChip(BrandColors.republicanRed.withOpacity(0.6), 'GOP', repDistricts),
        ],
      ),
    );
  }

  Widget _legendChip(Color color, String label, int count) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$count',
                    style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                label,
                style: const TextStyle(color: Colors.white38, fontSize: 9),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleTap(TapDownDetails details) {
    if (widget.onDistrictTap == null) return;

    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final size = box.size;
    final pos = details.localPosition;

    // Calculate district from position using grid mapping
    final cols = 16;
    final rows = 11;
    final cellW = size.width / cols;
    final cellH = widget.height / rows;
    final col = (pos.dx / cellW).floor().clamp(0, cols - 1);
    final row = (pos.dy / cellH).floor().clamp(0, rows - 1);
    final districtNum = row * cols + col + 1;
    final district = districtNum.toString();

    // Direct hit
    if (widget.districtMap.containsKey(district)) {
      widget.onDistrictTap!(district);
      return;
    }

    // Find nearest district
    String? best;
    int bestDist = 999;
    for (final d in widget.districtMap.keys) {
      final n = int.tryParse(d) ?? 999;
      final dist = (n - districtNum).abs();
      if (dist < bestDist) {
        bestDist = dist;
        best = d;
      }
    }
    if (best != null && bestDist <= 5) {
      widget.onDistrictTap!(best);
    }
  }
}

// ═══════════════════════════════════════════════════════════════
//  MISSOURI DISTRICT PAINTER
//  Renders state outline + district dots with metro clustering
// ═══════════════════════════════════════════════════════════════

class _MissouriDistrictPainter extends CustomPainter {
  final Map<String, List<Candidate>> districtMap;
  final String? selectedDistrict;
  final double pulseValue;
  final bool showLabels;
  final double entranceProgress;

  _MissouriDistrictPainter({
    required this.districtMap,
    this.selectedDistrict,
    this.pulseValue = 1.0,
    this.showLabels = true,
    this.entranceProgress = 1.0,
  });

  // Simplified Missouri outline (normalized 0-1 coordinates)
  static const _outline = [
    Offset(0.05, 0.10),
    Offset(0.40, 0.08),
    Offset(0.55, 0.05),
    Offset(0.70, 0.07),
    Offset(0.88, 0.10),
    Offset(0.90, 0.20),
    Offset(0.92, 0.35),
    Offset(0.95, 0.45),
    Offset(0.92, 0.55),
    Offset(0.88, 0.65),
    Offset(0.90, 0.75),
    Offset(0.92, 0.90),
    Offset(0.80, 0.92),
    Offset(0.75, 0.80),
    Offset(0.70, 0.72),
    Offset(0.55, 0.70),
    Offset(0.40, 0.72),
    Offset(0.25, 0.70),
    Offset(0.10, 0.68),
    Offset(0.05, 0.55),
    Offset(0.03, 0.35),
    Offset(0.05, 0.20),
  ];

  // City positions (normalized)
  static const _cities = {
    'Kansas City': Offset(0.10, 0.22),
    'St. Louis': Offset(0.82, 0.24),
    'Springfield': Offset(0.32, 0.52),
    'Columbia': Offset(0.47, 0.24),
    'Jeff City': Offset(0.45, 0.38),
  };

  @override
  void paint(Canvas canvas, Size size) {
    _drawOutline(canvas, size);
    _drawGrid(canvas, size);
    _drawDistrictDots(canvas, size);
    if (showLabels) _drawCityLabels(canvas, size);
  }

  void _drawOutline(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.08 * entranceProgress)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = BrandColors.momentumBlue.withOpacity(0.4 * entranceProgress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final path = Path();
    final first = Offset(
        _outline[0].dx * size.width, _outline[0].dy * size.height);
    path.moveTo(first.dx, first.dy);
    for (int i = 1; i < _outline.length; i++) {
      final p = Offset(
          _outline[i].dx * size.width, _outline[i].dy * size.height);
      path.lineTo(p.dx, p.dy);
    }
    path.close();

    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);
  }

  void _drawGrid(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.03 * entranceProgress)
      ..strokeWidth = 0.5;

    for (double x = 0.1; x < 1.0; x += 0.05) {
      canvas.drawLine(
        Offset(x * size.width, 0),
        Offset(x * size.width, size.height),
        gridPaint,
      );
    }
    for (double y = 0.1; y < 1.0; y += 0.05) {
      canvas.drawLine(
        Offset(0, y * size.height),
        Offset(size.width, y * size.height),
        gridPaint,
      );
    }
  }

  void _drawDistrictDots(Canvas canvas, Size size) {
    final rng = math.Random(42);

    for (final entry in districtMap.entries) {
      final districtNum = int.tryParse(entry.key) ?? 0;
      if (districtNum < 1 || districtNum > 163) continue;

      final candidates = entry.value;
      final pos = _getDistrictPosition(districtNum, rng);
      final x = pos.dx.clamp(0.06, 0.93);
      final y = pos.dy.clamp(0.08, 0.88);

      // Determine color
      final hasYd = candidates.any((c) => c.isYoungDem);
      final hasDem = candidates.any((c) => c.isDemocrat);
      final hasRep = candidates.any((c) => c.isRepublican);

      Color dotColor;
      double dotRadius = 4.0;
      if (hasYd) {
        dotColor = BrandColors.momentumBlue;
        dotRadius = 5.5;
      } else if (hasDem && !hasRep) {
        dotColor = Colors.blueGrey;
        dotRadius = 4.0;
      } else if (hasDem && hasRep) {
        dotColor = Colors.amber.withOpacity(0.7);
        dotRadius = 4.5;
      } else {
        dotColor = BrandColors.republicanRed.withOpacity(0.6);
        dotRadius = 3.5;
      }

      dotRadius *= entranceProgress;

      final isSelected = selectedDistrict == entry.key;
      if (isSelected) {
        dotRadius *= 1.5 * pulseValue;
      }

      final dotPos = Offset(x * size.width, y * size.height);

      // Glow effect
      if (hasYd || isSelected) {
        final glowPaint = Paint()
          ..color = dotColor.withOpacity(0.3 * pulseValue * entranceProgress)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        canvas.drawCircle(dotPos, dotRadius * 1.8, glowPaint);
      }

      // Dot
      canvas.drawCircle(dotPos, dotRadius, Paint()..color = dotColor);

      // Selected label
      if (isSelected) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: entry.key,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(
          canvas,
          Offset(dotPos.dx - textPainter.width / 2,
              dotPos.dy - dotRadius - 14),
        );
      }
    }
  }

  Offset _getDistrictPosition(int districtNum, math.Random rng) {
    double x, y;
    if (districtNum <= 30) {
      // KC metro
      x = 0.08 + (districtNum % 6) * 0.025 + rng.nextDouble() * 0.01;
      y = 0.25 + (districtNum ~/ 6) * 0.04 + rng.nextDouble() * 0.01;
    } else if (districtNum <= 40) {
      // KC suburbs
      x = 0.12 + ((districtNum - 30) % 5) * 0.03 + rng.nextDouble() * 0.015;
      y = 0.20 + ((districtNum - 30) ~/ 5) * 0.05 + rng.nextDouble() * 0.015;
    } else if (districtNum <= 80) {
      // STL metro
      final idx = districtNum - 41;
      x = 0.78 + (idx % 7) * 0.022 + rng.nextDouble() * 0.01;
      y = 0.28 + (idx ~/ 7) * 0.038 + rng.nextDouble() * 0.01;
    } else if (districtNum <= 95) {
      // STL suburbs
      final idx = districtNum - 81;
      x = 0.72 + (idx % 5) * 0.03 + rng.nextDouble() * 0.015;
      y = 0.25 + (idx ~/ 5) * 0.06 + rng.nextDouble() * 0.015;
    } else if (districtNum <= 105) {
      // Columbia / Jeff City
      final idx = districtNum - 96;
      x = 0.42 + (idx % 4) * 0.035 + rng.nextDouble() * 0.02;
      y = 0.28 + (idx ~/ 4) * 0.05 + rng.nextDouble() * 0.02;
    } else if (districtNum <= 120) {
      // Springfield
      final idx = districtNum - 106;
      x = 0.28 + (idx % 5) * 0.03 + rng.nextDouble() * 0.015;
      y = 0.55 + (idx ~/ 5) * 0.045 + rng.nextDouble() * 0.015;
    } else {
      // Rural / rest of state
      final idx = districtNum - 121;
      x = 0.15 + (idx % 10) * 0.065 + rng.nextDouble() * 0.03;
      y = 0.15 + (idx ~/ 10) * 0.08 + rng.nextDouble() * 0.03;
    }
    return Offset(x, y);
  }

  void _drawCityLabels(Canvas canvas, Size size) {
    for (final entry in _cities.entries) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: entry.key,
          style: TextStyle(
            color: Colors.white.withOpacity(0.35 * entranceProgress),
            fontSize: 9,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(
          entry.value.dx * size.width - textPainter.width / 2,
          entry.value.dy * size.height,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MissouriDistrictPainter old) {
    return selectedDistrict != old.selectedDistrict ||
        pulseValue != old.pulseValue ||
        entranceProgress != old.entranceProgress;
  }
}
