import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/models/crm/candidate.dart';

// ═══════════════════════════════════════════════════════════════
//  MISSOURI MAP WIDGET
//  Interactive CustomPaint-based map of Missouri with 163 state
//  house districts, color-coded by candidate status.
//  Uses accurate GeoJSON-derived state outline (232 points).
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

    // Find the nearest district dot to tap position
    final rng = math.Random(42);
    String? bestDistrict;
    double bestDist = double.infinity;

    for (final entry in widget.districtMap.entries) {
      final districtNum = int.tryParse(entry.key) ?? 0;
      if (districtNum < 1 || districtNum > 163) continue;

      final dPos = _MissouriDistrictPainter.getDistrictPosition(districtNum, rng);
      final dx = dPos.dx * size.width - pos.dx;
      final dy = dPos.dy * size.height - pos.dy;
      final dist = dx * dx + dy * dy;

      // 20px touch target
      if (dist < 400 && dist < bestDist) {
        bestDist = dist;
        bestDistrict = entry.key;
      }
    }

    if (bestDistrict != null) {
      widget.onDistrictTap!(bestDistrict);
    }
  }
}

// ═══════════════════════════════════════════════════════════════
//  MISSOURI DISTRICT PAINTER
//  Renders accurate state outline + district dots with
//  metro clustering for KC, STL, Springfield, Columbia, etc.
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

  // ───────────────────────────────────────────────────────
  //  ACCURATE Missouri outline from US Census GeoJSON
  //  232 points, normalized to 0..1 coordinate space
  // ───────────────────────────────────────────────────────
  static const _moOutline = [
    Offset(0.8988, 0.8921),
    Offset(0.8904, 0.8910),
    Offset(0.8884, 0.8948),
    Offset(0.8941, 0.9017),
    Offset(0.9002, 0.9088),
    Offset(0.8926, 0.9115),
    Offset(0.8774, 0.9097),
    Offset(0.8902, 0.9251),
    Offset(0.8920, 0.9338),
    Offset(0.8878, 0.9375),
    Offset(0.8795, 0.9489),
    Offset(0.8764, 0.9590),
    Offset(0.8541, 0.9592),
    Offset(0.8186, 0.9596),
    Offset(0.7893, 0.9600),
    Offset(0.7852, 0.9600),
    Offset(0.7858, 0.9565),
    Offset(0.7920, 0.9412),
    Offset(0.8057, 0.9224),
    Offset(0.8202, 0.9063),
    Offset(0.8255, 0.9032),
    Offset(0.8272, 0.8988),
    Offset(0.8271, 0.8830),
    Offset(0.8176, 0.8719),
    Offset(0.8145, 0.8620),
    Offset(0.8150, 0.8600),
    Offset(0.7566, 0.8599),
    Offset(0.7036, 0.8599),
    Offset(0.6424, 0.8601),
    Offset(0.5876, 0.8598),
    Offset(0.5438, 0.8598),
    Offset(0.4874, 0.8600),
    Offset(0.4371, 0.8600),
    Offset(0.3817, 0.8599),
    Offset(0.3260, 0.8597),
    Offset(0.2740, 0.8598),
    Offset(0.2130, 0.8597),
    Offset(0.1995, 0.8597),
    Offset(0.1994, 0.8261),
    Offset(0.1994, 0.8064),
    Offset(0.1994, 0.7904),
    Offset(0.1994, 0.7610),
    Offset(0.1994, 0.7427),
    Offset(0.1994, 0.7280),
    Offset(0.1994, 0.7186),
    Offset(0.1995, 0.6955),
    Offset(0.1995, 0.6810),
    Offset(0.1996, 0.6636),
    Offset(0.1995, 0.6385),
    Offset(0.1995, 0.6161),
    Offset(0.1996, 0.5967),
    Offset(0.1998, 0.5803),
    Offset(0.1999, 0.5665),
    Offset(0.2000, 0.5533),
    Offset(0.2000, 0.5309),
    Offset(0.2002, 0.5173),
    Offset(0.2002, 0.5068),
    Offset(0.2002, 0.5004),
    Offset(0.2001, 0.4833),
    Offset(0.2002, 0.4656),
    Offset(0.2003, 0.4458),
    Offset(0.2006, 0.4137),
    Offset(0.2008, 0.3904),
    Offset(0.2008, 0.3741),
    Offset(0.2009, 0.3527),
    Offset(0.2009, 0.3452),
    Offset(0.2009, 0.3389),
    Offset(0.2033, 0.3335),
    Offset(0.2017, 0.3297),
    Offset(0.1872, 0.3269),
    Offset(0.1831, 0.3278),
    Offset(0.1809, 0.3270),
    Offset(0.1752, 0.3214),
    Offset(0.1604, 0.3014),
    Offset(0.1591, 0.2921),
    Offset(0.1541, 0.2818),
    Offset(0.1326, 0.2552),
    Offset(0.1311, 0.2511),
    Offset(0.1372, 0.2389),
    Offset(0.1447, 0.2272),
    Offset(0.1553, 0.2169),
    Offset(0.1612, 0.2094),
    Offset(0.1567, 0.1849),
    Offset(0.1531, 0.1820),
    Offset(0.1445, 0.1824),
    Offset(0.1433, 0.1866),
    Offset(0.1351, 0.1898),
    Offset(0.1218, 0.1822),
    Offset(0.1052, 0.1655),
    Offset(0.1043, 0.1623),
    Offset(0.0748, 0.1126),
    Offset(0.0705, 0.1042),
    Offset(0.0610, 0.0941),
    Offset(0.0521, 0.0696),
    Offset(0.0529, 0.0645),
    Offset(0.0559, 0.0587),
    Offset(0.0508, 0.0536),
    Offset(0.0489, 0.0579),
    Offset(0.0411, 0.0564),
    Offset(0.0400, 0.0480),
    Offset(0.0412, 0.0457),
    Offset(0.0821, 0.0464),
    Offset(0.1358, 0.0473),
    Offset(0.1975, 0.0485),
    Offset(0.2526, 0.0483),
    Offset(0.3048, 0.0474),
    Offset(0.3497, 0.0466),
    Offset(0.4089, 0.0459),
    Offset(0.4618, 0.0448),
    Offset(0.5120, 0.0433),
    Offset(0.5682, 0.0415),
    Offset(0.5977, 0.0400),
    Offset(0.5994, 0.0430),
    Offset(0.6127, 0.0545),
    Offset(0.6124, 0.0598),
    Offset(0.6259, 0.0804),
    Offset(0.6305, 0.0839),
    Offset(0.6404, 0.0869),
    Offset(0.6369, 0.0899),
    Offset(0.6307, 0.1053),
    Offset(0.6278, 0.1222),
    Offset(0.6278, 0.1368),
    Offset(0.6300, 0.1548),
    Offset(0.6347, 0.1662),
    Offset(0.6367, 0.1881),
    Offset(0.6385, 0.1940),
    Offset(0.6478, 0.2066),
    Offset(0.6475, 0.2162),
    Offset(0.6550, 0.2250),
    Offset(0.6666, 0.2378),
    Offset(0.6737, 0.2423),
    Offset(0.6763, 0.2513),
    Offset(0.6924, 0.2714),
    Offset(0.7144, 0.2893),
    Offset(0.7354, 0.3105),
    Offset(0.7369, 0.3167),
    Offset(0.7422, 0.3414),
    Offset(0.7378, 0.3501),
    Offset(0.7379, 0.3522),
    Offset(0.7443, 0.3746),
    Offset(0.7499, 0.3837),
    Offset(0.7556, 0.3876),
    Offset(0.7594, 0.3872),
    Offset(0.7661, 0.3809),
    Offset(0.7689, 0.3762),
    Offset(0.7695, 0.3725),
    Offset(0.7716, 0.3691),
    Offset(0.7739, 0.3679),
    Offset(0.7800, 0.3689),
    Offset(0.7980, 0.3761),
    Offset(0.8204, 0.3915),
    Offset(0.8210, 0.3939),
    Offset(0.8191, 0.4017),
    Offset(0.8124, 0.4080),
    Offset(0.8071, 0.4161),
    Offset(0.8068, 0.4189),
    Offset(0.8082, 0.4226),
    Offset(0.8103, 0.4263),
    Offset(0.8115, 0.4327),
    Offset(0.8115, 0.4344),
    Offset(0.8106, 0.4389),
    Offset(0.8051, 0.4462),
    Offset(0.8002, 0.4554),
    Offset(0.7976, 0.4666),
    Offset(0.7953, 0.4757),
    Offset(0.7891, 0.4836),
    Offset(0.7849, 0.4943),
    Offset(0.7845, 0.5046),
    Offset(0.7859, 0.5136),
    Offset(0.7900, 0.5229),
    Offset(0.8010, 0.5364),
    Offset(0.8079, 0.5430),
    Offset(0.8261, 0.5573),
    Offset(0.8395, 0.5753),
    Offset(0.8429, 0.5843),
    Offset(0.8447, 0.5857),
    Offset(0.8496, 0.5866),
    Offset(0.8524, 0.5847),
    Offset(0.8574, 0.5795),
    Offset(0.8719, 0.5912),
    Offset(0.8809, 0.5999),
    Offset(0.9028, 0.6262),
    Offset(0.9041, 0.6354),
    Offset(0.9020, 0.6446),
    Offset(0.9020, 0.6471),
    Offset(0.9026, 0.6529),
    Offset(0.9083, 0.6660),
    Offset(0.9117, 0.6703),
    Offset(0.9152, 0.6788),
    Offset(0.9158, 0.6827),
    Offset(0.9149, 0.6890),
    Offset(0.9085, 0.6926),
    Offset(0.9033, 0.6980),
    Offset(0.9024, 0.7023),
    Offset(0.9062, 0.7104),
    Offset(0.9168, 0.7350),
    Offset(0.9208, 0.7490),
    Offset(0.9294, 0.7581),
    Offset(0.9379, 0.7634),
    Offset(0.9427, 0.7629),
    Offset(0.9483, 0.7652),
    Offset(0.9556, 0.7635),
    Offset(0.9600, 0.7711),
    Offset(0.9535, 0.7904),
    Offset(0.9492, 0.7972),
    Offset(0.9569, 0.8027),
    Offset(0.9559, 0.8094),
    Offset(0.9485, 0.8090),
    Offset(0.9462, 0.8146),
    Offset(0.9464, 0.8165),
    Offset(0.9502, 0.8252),
    Offset(0.9498, 0.8296),
    Offset(0.9462, 0.8360),
    Offset(0.9426, 0.8457),
    Offset(0.9364, 0.8453),
    Offset(0.9289, 0.8332),
    Offset(0.9265, 0.8335),
    Offset(0.9220, 0.8369),
    Offset(0.9204, 0.8449),
    Offset(0.9121, 0.8666),
    Offset(0.9089, 0.8681),
    Offset(0.9059, 0.8638),
    Offset(0.9088, 0.8568),
    Offset(0.9097, 0.8523),
    Offset(0.9071, 0.8452),
    Offset(0.9012, 0.8434),
    Offset(0.8951, 0.8491),
    Offset(0.8966, 0.8545),
    Offset(0.9023, 0.8644),
    Offset(0.9036, 0.8844),
    Offset(0.9006, 0.8916),
    Offset(0.8988, 0.8921),
  ];

  // City positions (geographic, normalized to same space)
  static const _cities = {
    'Kansas City': Offset(0.2049, 0.3416),
    'St. Louis': Offset(0.8086, 0.4358),
    'Springfield': Offset(0.3822, 0.7183),
    'Columbia': Offset(0.5143, 0.3711),
    'Jeff City': Offset(0.5364, 0.4458),
    'St. Joseph': Offset(0.1679, 0.2083),
    'Cape Girardeau': Offset(0.9025, 0.6990),
    'Joplin': Offset(0.2139, 0.7432),
  };

  @override
  void paint(Canvas canvas, Size size) {
    _drawOutline(canvas, size);
    _drawDistrictDots(canvas, size);
    if (showLabels) _drawCityLabels(canvas, size);
  }

  void _drawOutline(Canvas canvas, Size size) {
    // Fill
    final fillPaint = Paint()
      ..color = Colors.white.withOpacity(0.06 * entranceProgress)
      ..style = PaintingStyle.fill;

    // Border — smooth thick stroke
    final borderPaint = Paint()
      ..color = BrandColors.momentumBlue.withOpacity(0.5 * entranceProgress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    // Subtle inner glow
    final glowPaint = Paint()
      ..color = BrandColors.momentumBlue.withOpacity(0.12 * entranceProgress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
      ..isAntiAlias = true;

    final path = _buildOutlinePath(size);

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, borderPaint);

    // Subtle latitude/longitude grid lines inside the state
    _drawSubtleGrid(canvas, size, path);
  }

  Path _buildOutlinePath(Size size) {
    final path = Path();
    final first = Offset(
        _moOutline[0].dx * size.width, _moOutline[0].dy * size.height);
    path.moveTo(first.dx, first.dy);

    // Use quadratic bezier curves between points for smoothness
    for (int i = 1; i < _moOutline.length; i++) {
      final curr = Offset(
          _moOutline[i].dx * size.width, _moOutline[i].dy * size.height);
      final prev = Offset(
          _moOutline[i - 1].dx * size.width, _moOutline[i - 1].dy * size.height);

      if (i + 1 < _moOutline.length) {
        final next = Offset(
            _moOutline[i + 1].dx * size.width, _moOutline[i + 1].dy * size.height);
        // Smooth with catmull-rom style: use midpoints
        final midX = (prev.dx + curr.dx) / 2;
        final midY = (prev.dy + curr.dy) / 2;
        final midX2 = (curr.dx + next.dx) / 2;
        final midY2 = (curr.dy + next.dy) / 2;
        path.quadraticBezierTo(curr.dx, curr.dy, midX2, midY2);
      } else {
        path.lineTo(curr.dx, curr.dy);
      }
    }
    path.close();
    return path;
  }

  void _drawSubtleGrid(Canvas canvas, Size size, Path statePath) {
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.025 * entranceProgress)
      ..strokeWidth = 0.5
      ..isAntiAlias = true;

    // Clip to state outline for clean grid
    canvas.save();
    canvas.clipPath(statePath);

    // Horizontal lines
    for (double y = 0.1; y < 1.0; y += 0.1) {
      canvas.drawLine(
        Offset(0, y * size.height),
        Offset(size.width, y * size.height),
        gridPaint,
      );
    }
    // Vertical lines
    for (double x = 0.1; x < 1.0; x += 0.1) {
      canvas.drawLine(
        Offset(x * size.width, 0),
        Offset(x * size.width, size.height),
        gridPaint,
      );
    }
    canvas.restore();
  }

  void _drawDistrictDots(Canvas canvas, Size size) {
    final rng = math.Random(42);

    for (final entry in districtMap.entries) {
      final districtNum = int.tryParse(entry.key) ?? 0;
      if (districtNum < 1 || districtNum > 163) continue;

      final candidates = entry.value;
      final pos = getDistrictPosition(districtNum, rng);

      // Determine color
      final hasYd = candidates.any((c) => c.isYoungDem);
      final hasDem = candidates.any((c) => c.isDemocrat);
      final hasRep = candidates.any((c) => c.isRepublican);

      Color dotColor;
      double dotRadius = 3.5;
      if (hasYd) {
        dotColor = BrandColors.momentumBlue;
        dotRadius = 5.0;
      } else if (hasDem && !hasRep) {
        dotColor = Colors.blueGrey.shade300;
        dotRadius = 3.5;
      } else if (hasDem && hasRep) {
        dotColor = Colors.amber.withOpacity(0.8);
        dotRadius = 4.0;
      } else {
        dotColor = BrandColors.republicanRed.withOpacity(0.5);
        dotRadius = 3.0;
      }

      dotRadius *= entranceProgress;

      final isSelected = selectedDistrict == entry.key;
      if (isSelected) {
        dotRadius *= 1.5 * pulseValue;
      }

      final dotPos = Offset(pos.dx * size.width, pos.dy * size.height);

      // Glow for Young Dem or selected
      if (hasYd || isSelected) {
        final glowPaint = Paint()
          ..color = dotColor.withOpacity(0.35 * pulseValue * entranceProgress)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
        canvas.drawCircle(dotPos, dotRadius * 2.0, glowPaint);
      }

      // Outer ring for Young Dem
      if (hasYd) {
        canvas.drawCircle(
          dotPos,
          dotRadius + 1.0,
          Paint()
            ..color = Colors.white.withOpacity(0.3 * entranceProgress)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8,
        );
      }

      // Main dot
      canvas.drawCircle(dotPos, dotRadius, Paint()..color = dotColor);

      // Selected district label
      if (isSelected) {
        _drawDistrictLabel(canvas, entry.key, dotPos, dotRadius);
      }
    }
  }

  void _drawDistrictLabel(Canvas canvas, String label, Offset pos, double radius) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'HD-$label',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(color: Colors.black54, blurRadius: 4),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Background pill
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(pos.dx, pos.dy - radius - 12),
        width: textPainter.width + 10,
        height: 16,
      ),
      const Radius.circular(4),
    );
    canvas.drawRRect(
      bgRect,
      Paint()..color = Colors.black.withOpacity(0.6),
    );

    textPainter.paint(
      canvas,
      Offset(pos.dx - textPainter.width / 2, pos.dy - radius - 20),
    );
  }

  /// Map district numbers to geographic positions using real
  /// Missouri metro areas and geographic knowledge.
  static Offset getDistrictPosition(int districtNum, math.Random rng) {
    double x, y;

    // KC Metro (districts 1-35 roughly)
    if (districtNum <= 20) {
      // KC urban core
      final idx = districtNum - 1;
      x = 0.185 + (idx % 5) * 0.012 + rng.nextDouble() * 0.008;
      y = 0.320 + (idx ~/ 5) * 0.020 + rng.nextDouble() * 0.008;
    } else if (districtNum <= 40) {
      // KC suburbs (Independence, Lee's Summit, Blue Springs, etc.)
      final idx = districtNum - 21;
      x = 0.215 + (idx % 5) * 0.015 + rng.nextDouble() * 0.010;
      y = 0.295 + (idx ~/ 5) * 0.025 + rng.nextDouble() * 0.010;
    } else if (districtNum <= 50) {
      // Northland KC / St. Joseph area
      final idx = districtNum - 41;
      x = 0.170 + (idx % 4) * 0.018 + rng.nextDouble() * 0.012;
      y = 0.240 + (idx ~/ 4) * 0.025 + rng.nextDouble() * 0.012;
    }
    // STL Metro (districts 51-95 roughly)
    else if (districtNum <= 75) {
      // STL urban core
      final idx = districtNum - 51;
      x = 0.790 + (idx % 5) * 0.012 + rng.nextDouble() * 0.008;
      y = 0.400 + (idx ~/ 5) * 0.020 + rng.nextDouble() * 0.008;
    } else if (districtNum <= 95) {
      // STL suburbs (St. Charles, South County, West County)
      final idx = districtNum - 76;
      x = 0.755 + (idx % 5) * 0.014 + rng.nextDouble() * 0.010;
      y = 0.360 + (idx ~/ 5) * 0.025 + rng.nextDouble() * 0.010;
    }
    // Columbia / Jeff City (districts 96-105)
    else if (districtNum <= 105) {
      final idx = districtNum - 96;
      x = 0.485 + (idx % 4) * 0.020 + rng.nextDouble() * 0.015;
      y = 0.380 + (idx ~/ 4) * 0.030 + rng.nextDouble() * 0.015;
    }
    // Springfield (districts 106-118)
    else if (districtNum <= 118) {
      final idx = districtNum - 106;
      x = 0.355 + (idx % 4) * 0.018 + rng.nextDouble() * 0.012;
      y = 0.690 + (idx ~/ 4) * 0.025 + rng.nextDouble() * 0.012;
    }
    // Joplin area (119-124)
    else if (districtNum <= 124) {
      final idx = districtNum - 119;
      x = 0.200 + (idx % 3) * 0.020 + rng.nextDouble() * 0.012;
      y = 0.720 + (idx ~/ 3) * 0.030 + rng.nextDouble() * 0.012;
    }
    // Cape Girardeau / SE Missouri (125-130)
    else if (districtNum <= 130) {
      final idx = districtNum - 125;
      x = 0.870 + (idx % 3) * 0.018 + rng.nextDouble() * 0.010;
      y = 0.670 + (idx ~/ 3) * 0.035 + rng.nextDouble() * 0.010;
    }
    // Rural districts spread across the state (131-163)
    else {
      final idx = districtNum - 131;
      // Distribute across rural Missouri in a more organic pattern
      // Avoid the metro clusters
      final ruralPositions = [
        // NW Missouri
        Offset(0.28, 0.15), Offset(0.33, 0.18), Offset(0.38, 0.14),
        // North Central
        Offset(0.45, 0.12), Offset(0.52, 0.15), Offset(0.58, 0.12),
        // NE Missouri
        Offset(0.65, 0.10), Offset(0.70, 0.14), Offset(0.74, 0.18),
        // West Central
        Offset(0.25, 0.48), Offset(0.30, 0.52), Offset(0.35, 0.48),
        // Central
        Offset(0.45, 0.52), Offset(0.52, 0.55), Offset(0.58, 0.50),
        // East Central
        Offset(0.65, 0.48), Offset(0.70, 0.52), Offset(0.73, 0.55),
        // SW Missouri
        Offset(0.28, 0.62), Offset(0.33, 0.58), Offset(0.25, 0.80),
        // South Central (Ozarks)
        Offset(0.42, 0.65), Offset(0.48, 0.68), Offset(0.55, 0.65),
        Offset(0.60, 0.70), Offset(0.65, 0.65),
        // SE Missouri (Bootheel)
        Offset(0.88, 0.78), Offset(0.90, 0.82), Offset(0.92, 0.86),
        Offset(0.86, 0.84), Offset(0.84, 0.80),
        // Additional rural fill
        Offset(0.40, 0.28), Offset(0.60, 0.30),
      ];

      if (idx < ruralPositions.length) {
        final base = ruralPositions[idx];
        x = base.dx + rng.nextDouble() * 0.03 - 0.015;
        y = base.dy + rng.nextDouble() * 0.03 - 0.015;
      } else {
        // Fallback: scatter remaining across the state
        x = 0.25 + rng.nextDouble() * 0.55;
        y = 0.15 + rng.nextDouble() * 0.65;
      }
    }

    return Offset(x.clamp(0.06, 0.95), y.clamp(0.06, 0.95));
  }

  void _drawCityLabels(Canvas canvas, Size size) {
    for (final entry in _cities.entries) {
      final pos = Offset(
        entry.value.dx * size.width,
        entry.value.dy * size.height,
      );

      // City marker dot
      canvas.drawCircle(
        pos,
        2.0 * entranceProgress,
        Paint()..color = Colors.white.withOpacity(0.25 * entranceProgress),
      );

      // City name
      final textPainter = TextPainter(
        text: TextSpan(
          text: entry.key,
          style: TextStyle(
            color: Colors.white.withOpacity(0.30 * entranceProgress),
            fontSize: 8,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(
          pos.dx - textPainter.width / 2,
          pos.dy + 5,
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
