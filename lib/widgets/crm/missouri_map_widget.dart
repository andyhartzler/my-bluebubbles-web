import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/models/crm/candidate.dart';

// ═══════════════════════════════════════════════════════════════
//  MISSOURI MAP WIDGET — flutter_map + real GeoJSON districts
//  Interactive tile-based map with OpenStreetMap tiles,
//  163 state house district polygons from Census TIGER/Line,
//  color-coded by candidate status. Supports tap, zoom, pan.
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
  late final MapController _mapController;
  late AnimationController _entranceController;
  late Animation<double> _entranceAnimation;

  // Parsed GeoJSON polygons
  List<_DistrictPolygon> _districtPolygons = [];
  bool _geoJsonLoaded = false;
  String? _hoveredDistrict;

  // Missouri bounds
  static const _moCenter = LatLng(38.35, -92.45);
  static const _initialZoom = 6.5;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _entranceAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );

    _loadGeoJson();
  }

  @override
  void didUpdateWidget(MissouriMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.districtMap != widget.districtMap && _geoJsonLoaded) {
      _rebuildPolygonColors();
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  // ── Load & parse GeoJSON ──────────────────────────────────

  Future<void> _loadGeoJson() async {
    try {
      final jsonStr =
          await rootBundle.loadString('assets/mo_house_districts.json');
      final geoJson = json.decode(jsonStr) as Map<String, dynamic>;
      final features = geoJson['features'] as List<dynamic>;

      final polygons = <_DistrictPolygon>[];

      for (final feature in features) {
        final props = feature['properties'] as Map<String, dynamic>;
        final districtNum = props['district']?.toString() ?? '';
        if (districtNum.isEmpty) continue;

        final geometry = feature['geometry'] as Map<String, dynamic>;
        final type = geometry['type'] as String;
        final coordinates = geometry['coordinates'];

        List<List<LatLng>> rings = [];

        if (type == 'Polygon') {
          for (final ring in coordinates as List) {
            rings.add(_parseRing(ring as List));
          }
        } else if (type == 'MultiPolygon') {
          for (final polygon in coordinates as List) {
            for (final ring in polygon as List) {
              rings.add(_parseRing(ring as List));
            }
          }
        }

        if (rings.isNotEmpty) {
          // Calculate centroid from the outer ring
          final outerRing = rings.first;
          double cx = 0, cy = 0;
          for (final p in outerRing) {
            cx += p.latitude;
            cy += p.longitude;
          }
          cx /= outerRing.length;
          cy /= outerRing.length;

          polygons.add(_DistrictPolygon(
            district: districtNum,
            rings: rings,
            centroid: LatLng(cx, cy),
          ));
        }
      }

      if (!mounted) return;

      setState(() {
        _districtPolygons = polygons;
        _geoJsonLoaded = true;
        _rebuildPolygonColors();
      });

      _entranceController.forward();
    } catch (e) {
      debugPrint('❌ Failed to load GeoJSON: $e');
    }
  }

  List<LatLng> _parseRing(List ring) {
    return ring.map<LatLng>((coord) {
      final c = coord as List;
      return LatLng(
        (c[1] as num).toDouble(),
        (c[0] as num).toDouble(),
      );
    }).toList();
  }

  void _rebuildPolygonColors() {
    for (final dp in _districtPolygons) {
      final candidates = widget.districtMap[dp.district];
      if (candidates == null || candidates.isEmpty) {
        dp.fillColor = Colors.white.withOpacity(0.05);
        dp.borderColor = Colors.white.withOpacity(0.15);
        dp.status = _DistrictStatus.noData;
      } else {
        final hasYd = candidates.any((c) => c.isYoungDem);
        final hasDem = candidates.any((c) => c.isDemocrat);
        final hasRep = candidates.any((c) => c.isRepublican);

        if (hasYd) {
          dp.fillColor = const Color(0xFF0b4db8).withOpacity(0.55);
          dp.borderColor = const Color(0xFF0b4db8).withOpacity(0.9);
          dp.status = _DistrictStatus.youngDem;
        } else if (hasDem && !hasRep) {
          dp.fillColor = const Color(0xFF4682B4).withOpacity(0.30);
          dp.borderColor = const Color(0xFF4682B4).withOpacity(0.6);
          dp.status = _DistrictStatus.dem;
        } else if (hasDem && hasRep) {
          dp.fillColor = Colors.amber.withOpacity(0.25);
          dp.borderColor = Colors.amber.withOpacity(0.6);
          dp.status = _DistrictStatus.contested;
        } else {
          dp.fillColor = const Color(0xFFE53935).withOpacity(0.15);
          dp.borderColor = const Color(0xFFE53935).withOpacity(0.4);
          dp.status = _DistrictStatus.republican;
        }
      }
    }
  }

  // ── Tap handler ──────────────────────────────────────────

  void _onDistrictTap(_DistrictPolygon dp) {
    setState(() {
      _hoveredDistrict = dp.district;
    });
    widget.onDistrictTap?.call(dp.district);
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _entranceAnimation,
      child: Container(
        margin: widget.compactMode ? EdgeInsets.zero : const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              BrandColors.unityBlue.withOpacity(0.95),
              BrandColors.unityBlue,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius:
              BorderRadius.circular(widget.compactMode ? 12 : 20),
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
          const Icon(Icons.map_outlined,
              color: BrandColors.sunriseGold, size: 22),
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
          // Reset zoom button
          GestureDetector(
            onTap: () {
              _mapController.move(_moCenter, _initialZoom);
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.center_focus_strong,
                      color: Colors.white54, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'Reset',
                    style: TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    if (!_geoJsonLoaded) {
      return SizedBox(
        height: widget.height,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: BrandColors.sunriseGold,
                strokeWidth: 2,
              ),
              SizedBox(height: 12),
              Text(
                'Loading district boundaries…',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    final selectedDist =
        widget.selectedDistrict ?? _hoveredDistrict;

    // Build flutter_map polygon list
    final polygons = <Polygon>[];
    for (final dp in _districtPolygons) {
      final isSelected = dp.district == selectedDist;
      final outerRing = dp.rings.first;

      polygons.add(Polygon(
        points: outerRing,
        holePointsList: dp.rings.length > 1 ? dp.rings.sublist(1) : null,
        color: isSelected
            ? BrandColors.sunriseGold.withOpacity(0.45)
            : dp.fillColor,
        borderColor: isSelected
            ? BrandColors.sunriseGold
            : dp.borderColor,
        borderStrokeWidth: isSelected ? 2.5 : 0.8,
        isFilled: true,
      ));
    }

    // Build markers for Young Dem districts
    final markers = <Marker>[];
    for (final dp in _districtPolygons) {
      if (dp.status == _DistrictStatus.youngDem) {
        markers.add(Marker(
          point: dp.centroid,
          width: 22,
          height: 22,
          child: GestureDetector(
            onTap: () => _onDistrictTap(dp),
            child: Container(
              decoration: BoxDecoration(
                color: BrandColors.sunriseGold,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: BrandColors.sunriseGold.withOpacity(0.5),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.star, color: Colors.white, size: 12),
              ),
            ),
          ),
        ));
      }
    }

    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: widget.compactMode
            ? BorderRadius.circular(12)
            : const BorderRadius.vertical(bottom: Radius.circular(12)),
        child: GestureDetector(
          onTapUp: (details) => _handleMapTapGesture(details),
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _moCenter,
              initialZoom: _initialZoom,
              minZoom: 5.5,
              maxZoom: 12.0,
              interactionOptions: InteractionOptions(
                flags: widget.interactive
                    ? InteractiveFlag.all
                    : InteractiveFlag.none,
              ),
              // Dark background behind tiles
              backgroundColor: const Color(0xFF0a1628),
            ),
            children: [
              // Dark-themed tile layer
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'org.moyoungdemocrats.crm',
                maxZoom: 18,
                tileBuilder: _darkTileBuilder,
              ),
              // District polygons
              PolygonLayer(
                polygons: polygons,
                polygonCulling: true,
              ),
              // Young Dem star markers
              MarkerLayer(
                markers: markers,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Darken/tint tiles to match our dark theme
  Widget _darkTileBuilder(
      BuildContext context, Widget tileWidget, TileImage tile) {
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        0.7, 0, 0, 0, 0,    // R
        0, 0.7, 0, 0, 0,    // G
        0, 0, 0.8, 0, 0,    // B
        0, 0, 0, 1, 0,      // A
      ]),
      child: tileWidget,
    );
  }

  void _handleMapTapGesture(TapUpDetails details) {
    if (!widget.interactive || !_geoJsonLoaded) return;

    // Convert screen position to lat/lng
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    // The tap position is relative to the GestureDetector
    final tapLatLng = _mapController.camera
        .pointToLatLng(math.Point(details.localPosition.dx, details.localPosition.dy));

    // Find which district polygon contains this point
    for (final dp in _districtPolygons) {
      if (_isPointInPolygon(tapLatLng, dp.rings.first)) {
        _onDistrictTap(dp);
        return;
      }
    }
  }

  /// Ray-casting point-in-polygon test
  bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
    bool inside = false;
    int j = polygon.length - 1;

    for (int i = 0; i < polygon.length; i++) {
      if ((polygon[i].latitude > point.latitude) !=
              (polygon[j].latitude > point.latitude) &&
          point.longitude <
              (polygon[j].longitude - polygon[i].longitude) *
                      (point.latitude - polygon[i].latitude) /
                      (polygon[j].latitude - polygon[i].latitude) +
                  polygon[i].longitude) {
        inside = !inside;
      }
      j = i;
    }

    return inside;
  }

  Widget _buildLegendBar() {
    int ydDistricts = 0;
    int demDistricts = 0;
    int repDistricts = 0;
    int contested = 0;

    for (final dp in _districtPolygons) {
      switch (dp.status) {
        case _DistrictStatus.youngDem:
          ydDistricts++;
          break;
        case _DistrictStatus.dem:
          demDistricts++;
          break;
        case _DistrictStatus.contested:
          contested++;
          break;
        case _DistrictStatus.republican:
          repDistricts++;
          break;
        case _DistrictStatus.noData:
          break;
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          _legendChip(
              const Color(0xFF0b4db8), 'Young Dem', ydDistricts),
          _legendChip(
              const Color(0xFF4682B4), 'Dem', demDistricts),
          _legendChip(Colors.amber, 'Contested', contested),
          _legendChip(const Color(0xFFE53935).withOpacity(0.7), 'GOP',
              repDistricts),
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
                style:
                    const TextStyle(color: Colors.white38, fontSize: 9),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  INTERNAL MODELS
// ═══════════════════════════════════════════════════════════════

enum _DistrictStatus { youngDem, dem, contested, republican, noData }

class _DistrictPolygon {
  final String district;
  final List<List<LatLng>> rings;
  final LatLng centroid;
  Color fillColor;
  Color borderColor;
  _DistrictStatus status;

  _DistrictPolygon({
    required this.district,
    required this.rings,
    required this.centroid,
    this.fillColor = Colors.transparent,
    this.borderColor = Colors.transparent,
    this.status = _DistrictStatus.noData,
  });
}

// ═══════════════════════════════════════════════════════════════
//  LEGACY COMPATIBILITY — MissouriMapPainter
//  Kept as a no-op stub so existing references in candidates_page
//  don't break at compile time. The real rendering is now done
//  by flutter_map above.
// ═══════════════════════════════════════════════════════════════

class MissouriMapPainter extends CustomPainter {
  final Map<String, List<Candidate>> districtMap;
  final String? selectedDistrict;
  final double pulseValue;

  MissouriMapPainter({
    required this.districtMap,
    this.selectedDistrict,
    this.pulseValue = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // No-op: rendering handled by flutter_map widget
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
