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
//  House / Senate / Congressional district polygons from
//  Census TIGER/Line, color-coded by candidate status.
//  Supports toggle between district types, tap, zoom, pan.
// ═══════════════════════════════════════════════════════════════

/// Which set of district boundaries to display.
enum DistrictType { house, senate, congressional }

/// Public controller for [MissouriMapWidget] — lets the containing page
/// drive the map imperatively (zoom-to-district on candidate selection,
/// programmatic highlight, etc).
class MissouriMapController {
  _MissouriMapWidgetState? _state;

  void _attach(_MissouriMapWidgetState state) {
    _state = state;
  }

  void _detach(_MissouriMapWidgetState state) {
    if (identical(_state, state)) _state = null;
  }

  /// Animate the map to the centroid of the given district and paint a gold
  /// selection ring on its polygon. [office] picks which GeoJSON layer
  /// ("State Representative" → house, "State Senator" → senate, etc).
  /// Pass null [districtNum] to clear the selection.
  Future<void> zoomToDistrict({
    required String office,
    required String? districtNum,
  }) async {
    await _state?._zoomToDistrictFromOffice(office: office, district: districtNum);
  }

  /// Clear the gold selection ring without moving the map.
  void clearHighlight() {
    _state?._clearHighlight();
  }
}

class MissouriMapWidget extends StatefulWidget {
  final Map<String, List<Candidate>> houseDistrictMap;
  final Map<String, List<Candidate>> senateDistrictMap;
  final Map<String, List<Candidate>> congressionalDistrictMap;
  /// Called when a district polygon is tapped.
  /// Passes (districtNumber, activeDistrictType) so the caller can scope the lookup.
  final void Function(String district, DistrictType type)? onDistrictTap;
  final String? selectedDistrict;
  final String? highlightedDistrict;
  final MissouriMapController? controller;
  final double height;
  final bool showLabels;
  final bool showLegend;
  final bool interactive;
  final bool compactMode;

  MissouriMapWidget({
    super.key,
    @Deprecated('Use houseDistrictMap instead')
    Map<String, List<Candidate>>? districtMap,
    Map<String, List<Candidate>>? houseDistrictMap,
    Map<String, List<Candidate>>? senateDistrictMap,
    Map<String, List<Candidate>>? congressionalDistrictMap,
    this.onDistrictTap,
    this.selectedDistrict,
    this.highlightedDistrict,
    this.controller,
    this.height = 320,
    this.showLabels = true,
    this.showLegend = true,
    this.interactive = true,
    this.compactMode = false,
  }) : houseDistrictMap = houseDistrictMap ?? districtMap ?? {},
       senateDistrictMap = senateDistrictMap ?? {},
       congressionalDistrictMap = congressionalDistrictMap ?? {};

  @override
  State<MissouriMapWidget> createState() => _MissouriMapWidgetState();
}

class _MissouriMapWidgetState extends State<MissouriMapWidget>
    with TickerProviderStateMixin {
  late final MapController _mapController;
  late AnimationController _entranceController;
  late Animation<double> _entranceAnimation;

  // Current district type selection
  DistrictType _activeType = DistrictType.house;

  // Parsed GeoJSON polygons per type
  final Map<DistrictType, List<_DistrictPolygon>> _polygonsByType = {};
  final Set<DistrictType> _loadedTypes = {};
  bool _geoJsonLoaded = false; // true once the initial (house) load finishes
  String? _hoveredDistrict;
  String? _goldRingDistrict;

  // Missouri bounds
  static final _moCenter = LatLng(38.35, -92.45);
  static const _initialZoom = 6.5;

  // ── Asset paths ──────────────────────────────────────────
  static final _geoJsonPaths = {
    DistrictType.house: 'assets/geojson/mo_house_districts.geojson',
    DistrictType.senate: 'assets/geojson/mo_senate_districts.geojson',
    DistrictType.congressional:
        'assets/geojson/mo_congressional_districts.geojson',
  };

  static final _typeLabels = {
    DistrictType.house: 'House',
    DistrictType.senate: 'Senate',
    DistrictType.congressional: 'Congressional',
  };

  // ── Lifecycle ────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    widget.controller?._attach(this);

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _entranceAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );

    _loadGeoJson(_activeType);
  }

  @override
  void didUpdateWidget(MissouriMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
    if (oldWidget.houseDistrictMap != widget.houseDistrictMap ||
        oldWidget.senateDistrictMap != widget.senateDistrictMap ||
        oldWidget.congressionalDistrictMap !=
            widget.congressionalDistrictMap) {
      _rebuildPolygonColors();
      setState(() {}); // trigger rebuild after color mutation
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _entranceController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  // ── Programmatic controller actions ──────────────────────

  void _clearHighlight() {
    if (!mounted) return;
    setState(() {
      _goldRingDistrict = null;
    });
  }

  Future<void> _zoomToDistrictFromOffice({
    required String office,
    required String? district,
  }) async {
    if (!mounted) return;
    if (district == null || district.isEmpty) {
      _clearHighlight();
      return;
    }

    final o = office.toLowerCase();
    DistrictType type;
    if (o.contains('congress') || o.contains('u.s. rep') || o.contains('us rep')) {
      type = DistrictType.congressional;
    } else if (o.contains('state senate') || o.contains('state senator')) {
      type = DistrictType.senate;
    } else if (o.contains('state rep') || o.contains('representative') || o.contains('house')) {
      type = DistrictType.house;
    } else {
      type = DistrictType.house;
    }

    // Switch layer if needed (will lazy-load the GeoJSON the first time).
    if (_activeType != type) {
      setState(() => _activeType = type);
      await _loadGeoJson(type);
    }

    final polygons = _activePolygons;
    _DistrictPolygon? match;
    for (final p in polygons) {
      if (p.district == district) {
        match = p;
        break;
      }
    }
    if (match == null) {
      _clearHighlight();
      return;
    }

    if (!mounted) return;
    setState(() {
      _goldRingDistrict = district;
    });

    // Congressional districts are much larger — zoom out a bit so the whole
    // district is visible. State house/senate get a tighter zoom.
    final zoomLevel = type == DistrictType.congressional ? 7.5 : 9.0;
    _mapController.move(match.centroid, zoomLevel);
  }

  // ── District map for active type ─────────────────────────

  Map<String, List<Candidate>> get _activeDistrictMap {
    switch (_activeType) {
      case DistrictType.house:
        return widget.houseDistrictMap;
      case DistrictType.senate:
        return widget.senateDistrictMap;
      case DistrictType.congressional:
        return widget.congressionalDistrictMap;
    }
  }

  List<_DistrictPolygon> get _activePolygons =>
      _polygonsByType[_activeType] ?? [];

  // ── Load & parse GeoJSON ──────────────────────────────────

  Future<void> _loadGeoJson(DistrictType type) async {
    if (_loadedTypes.contains(type)) {
      // Already loaded — just re-color and return.
      _rebuildPolygonColors();
      if (mounted) setState(() {});
      return;
    }

    try {
      final path = _geoJsonPaths[type]!;
      final jsonStr = await rootBundle.loadString(path);
      final geoJson = json.decode(jsonStr) as Map<String, dynamic>;
      final features = geoJson['features'] as List<dynamic>;

      final polygons = <_DistrictPolygon>[];

      for (final feature in features) {
        final props = feature['properties'] as Map<String, dynamic>;
        // Strip leading zeros so GeoJSON '041' matches candidate district '41'
        final rawDistrict = props['district']?.toString() ?? '';
        final districtNum = rawDistrict.replaceFirst(RegExp(r'^0+'), '');
        if (districtNum.isEmpty) continue;

        final geometry = feature['geometry'] as Map<String, dynamic>;
        final geoType = geometry['type'] as String;
        final coordinates = geometry['coordinates'];

        List<List<LatLng>> rings = [];

        if (geoType == 'Polygon') {
          for (final ring in coordinates as List) {
            rings.add(_parseRing(ring as List));
          }
        } else if (geoType == 'MultiPolygon') {
          for (final polygon in coordinates as List) {
            for (final ring in polygon as List) {
              rings.add(_parseRing(ring as List));
            }
          }
        }

        if (rings.isNotEmpty) {
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
        _polygonsByType[type] = polygons;
        _loadedTypes.add(type);
        _geoJsonLoaded = true;
        _rebuildPolygonColors();
      });

      if (!_entranceController.isCompleted) {
        _entranceController.forward();
      }
    } catch (e) {
      debugPrint('Failed to load GeoJSON for $type: $e');
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
    final districtMap = _activeDistrictMap;
    final polygons = _activePolygons;

    for (final dp in polygons) {
      final candidates = districtMap[dp.district];
      if (candidates == null || candidates.isEmpty) {
        // Gray with solid 0.30 opacity — visible, not invisible
        dp.fillColor = Colors.grey.withOpacity(0.30);
        dp.borderColor = Colors.grey.withOpacity(0.50);
        dp.status = _DistrictStatus.noData;
      } else {
        final hasYd = candidates.any((c) => c.isYoungDem);
        final hasDem = candidates.any((c) => c.isDemocrat);
        final hasRep = candidates.any((c) => c.isRepublican);

        if (hasYd) {
          dp.fillColor = const Color(0xFF0b4db8).withOpacity(0.55);
          dp.borderColor = const Color(0xFF0b4db8).withOpacity(0.85);
          dp.status = _DistrictStatus.youngDem;
        } else if (hasDem && hasRep) {
          dp.fillColor = const Color(0xFF8b5cf6).withOpacity(0.40);
          dp.borderColor = const Color(0xFF8b5cf6).withOpacity(0.65);
          dp.status = _DistrictStatus.contested;
        } else if (hasDem) {
          dp.fillColor = const Color(0xFF3b82f6).withOpacity(0.45);
          dp.borderColor = const Color(0xFF3b82f6).withOpacity(0.70);
          dp.status = _DistrictStatus.dem;
        } else {
          dp.fillColor = const Color(0xFFef4444).withOpacity(0.40);
          dp.borderColor = const Color(0xFFef4444).withOpacity(0.65);
          dp.status = _DistrictStatus.republican;
        }
      }
    }
  }

  // ── Toggle handler ───────────────────────────────────────

  void _onTypeChanged(DistrictType type) {
    if (type == _activeType) return;
    setState(() {
      _activeType = type;
      _hoveredDistrict = null;
    });
    _loadGeoJson(type);
  }

  // ── Tap handler ──────────────────────────────────────────

  void _onDistrictTap(_DistrictPolygon dp) {
    setState(() {
      _hoveredDistrict = dp.district;
    });
    widget.onDistrictTap?.call(dp.district, _activeType);
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _entranceAnimation,
      child: Container(
        margin: widget.compactMode ? EdgeInsets.zero : const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(widget.compactMode ? 12 : 20),
          boxShadow: widget.compactMode
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
          border: Border.all(
            color: Colors.grey.withOpacity(0.15),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!widget.compactMode) _buildTitle(),
            if (!widget.compactMode) _buildDistrictTypeToggle(),
            _buildMap(),
            if (widget.showLegend && !widget.compactMode) _buildLegendBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle() {
    final label = _typeLabels[_activeType] ?? 'House';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Icon(Icons.map_outlined,
              color: const Color(0xFF0b4db8), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Missouri 2026 — $label Districts',
              style: const TextStyle(
                color: Color(0xFF1a1a2e),
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
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.center_focus_strong,
                      color: Colors.grey.shade500, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'Reset',
                    style:
                        TextStyle(color: Colors.grey.shade500, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── District type toggle ──────────────────────────────────

  Widget _buildDistrictTypeToggle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: LayoutBuilder(builder: (context, constraints) {
        final narrow = constraints.maxWidth < 340;
        return SegmentedButton<DistrictType>(
        segments: [
          ButtonSegment(
            value: DistrictType.house,
            label: const Text('House'),
            icon: narrow ? null : const Icon(Icons.house_outlined, size: 16),
          ),
          ButtonSegment(
            value: DistrictType.senate,
            label: const Text('Senate'),
            icon: narrow ? null : const Icon(Icons.account_balance_outlined, size: 16),
          ),
          ButtonSegment(
            value: DistrictType.congressional,
            label: Text(narrow ? 'Cong.' : 'Congress'),
            icon: narrow ? null : const Icon(Icons.flag_outlined, size: 16),
          ),
        ],
        selected: {_activeType},
        onSelectionChanged: (selected) {
          _onTypeChanged(selected.first);
        },
        showSelectedIcon: false,
        style: ButtonStyle(
          textStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xFF0b4db8).withOpacity(0.12);
            }
            return Colors.transparent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xFF0b4db8);
            }
            return Colors.grey.shade600;
          }),
          side: WidgetStateProperty.all(
            BorderSide(color: Colors.grey.withOpacity(0.25)),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      );
      }),
    );
  }

  // ── Map ───────────────────────────────────────────────────

  Widget _buildMap() {
    // Show spinner when the active district type hasn't loaded yet
    final isLoading = !_loadedTypes.contains(_activeType);

    if (isLoading) {
      return SizedBox(
        height: widget.height,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                color: Color(0xFF0b4db8),
                strokeWidth: 2,
              ),
              const SizedBox(height: 12),
              Text(
                'Loading district boundaries...',
                style:
                    TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    final selectedDist = widget.selectedDistrict ?? _hoveredDistrict;
    final polygons = _activePolygons;
    final districtMap = _activeDistrictMap;

    // Build flutter_map polygon list
    final mapPolygons = <Polygon>[];
    for (final dp in polygons) {
      final isSelected = dp.district == selectedDist;
      final outerRing = dp.rings.first;

      mapPolygons.add(Polygon(
        points: outerRing,
        holePointsList: dp.rings.length > 1 ? dp.rings.sublist(1) : null,
        color: isSelected
            ? const Color(0xFF0b4db8).withOpacity(0.40)
            : dp.fillColor,
        borderColor: isSelected
            ? const Color(0xFF0b4db8)
            : dp.borderColor,
        borderStrokeWidth: isSelected ? 2.5 : 0.8,
        isFilled: true,
      ));
    }

    // Gold-ring overlay for the candidate-driven selection from the list panel.
    // External widget.highlightedDistrict prop wins; internal tap-driven
    // _goldRingDistrict is the fallback. Drawn LAST so it sits on top of the
    // base polygon fill/border.
    final goldRing = widget.highlightedDistrict ?? _goldRingDistrict;
    if (goldRing != null) {
      for (final dp in polygons) {
        if (dp.district != goldRing) continue;
        mapPolygons.add(Polygon(
          points: dp.rings.first,
          holePointsList: dp.rings.length > 1 ? dp.rings.sublist(1) : null,
          color: Colors.transparent,
          borderColor: BrandColors.sunriseGold,
          borderStrokeWidth: 3.5,
          isFilled: false,
        ));
        break;
      }
    }

    // Build markers — show labels on districts with candidates
    final markers = <Marker>[];
    for (final dp in polygons) {
      final hasCandidates =
          districtMap.containsKey(dp.district) &&
          districtMap[dp.district]!.isNotEmpty;

      if (dp.status == _DistrictStatus.youngDem) {
        // Young Dem districts get a prominent blue circle marker
        markers.add(Marker(
          point: dp.centroid,
          width: 28,
          height: 28,
          child: GestureDetector(
            onTap: () => _onDistrictTap(dp),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0b4db8),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  dp.district,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
        ));
      } else if (widget.showLabels && hasCandidates) {
        // Other districts with candidates get a subtle label
        markers.add(Marker(
          point: dp.centroid,
          width: 32,
          height: 18,
          child: GestureDetector(
            onTap: () => _onDistrictTap(dp),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.85),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: dp.borderColor.withOpacity(0.5),
                  width: 0.5,
                ),
              ),
              child: Center(
                child: Text(
                  dp.district,
                  style: TextStyle(
                    color: Colors.grey.shade800,
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    height: 1,
                  ),
                ),
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
              backgroundColor: const Color(0xFFf0f0f0),
            ),
            children: [
              // Light tile layer (CartoDB Positron)
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'org.moyoungdemocrats.crm',
                maxZoom: 18,
              ),
              // District polygons
              PolygonLayer(
                polygons: mapPolygons,
                polygonCulling: true,
              ),
              // Markers / labels
              MarkerLayer(
                markers: markers,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleMapTapGesture(TapUpDetails details) {
    if (!widget.interactive) return;
    final polygons = _activePolygons;
    if (polygons.isEmpty) return;

    final tapLatLng = _mapController.camera.pointToLatLng(
        math.Point(details.localPosition.dx, details.localPosition.dy));

    for (final dp in polygons) {
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

  // ── Legend ─────────────────────────────────────────────────

  Widget _buildLegendBar() {
    int ydDistricts = 0;
    int demDistricts = 0;
    int repDistricts = 0;
    int contested = 0;
    int noData = 0;

    for (final dp in _activePolygons) {
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
          noData++;
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
              const Color(0xFF3b82f6), 'Democrat', demDistricts),
          _legendChip(const Color(0xFF8b5cf6), 'Contested', contested),
          _legendChip(
              const Color(0xFFef4444), 'Republican', repDistricts),
          _legendChip(Colors.grey, 'No Cand.', noData),
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
                    TextStyle(color: Colors.grey.shade500, fontSize: 9),
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
