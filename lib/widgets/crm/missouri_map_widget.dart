import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/models/crm/candidate.dart';
import 'package:bluebubbles/screens/crm/volunteers/volunteers_map_models.dart'
    show moMapOptions, moBounds;

// ═══════════════════════════════════════════════════════════════
//  MISSOURI MAP WIDGET — flutter_map + real GeoJSON districts
//  Interactive tile-based map with OpenStreetMap tiles,
//  House / Senate / Congressional district polygons from
//  Census TIGER/Line, color-coded by candidate status.
//  Supports toggle between district types, tap, zoom, pan.
// ═══════════════════════════════════════════════════════════════

/// Map-surface tokens for THIS tile-based widget only. Moved here from
/// volunteers_map_models.dart when the Candidate Volunteers area switched to
/// the scheme-driven VolunteersTheme; this widget is the sole consumer now.
class MoydMapTheme {
  MoydMapTheme._();

  static const Color navy = Color(0xFF273351);

  /// State-outline stroke in dark mode (strokes/rings only, never body text).
  static const Color gold = Color(0xFFF0B429);

  /// Out-of-state mask fill, matched to the active theme's map surface.
  static const Color maskLight = Color(0xFFEFF2F6);
  static const Color maskDark = Color(0xFF1B2130);
  static Color maskColor(bool dark) => dark ? maskDark : maskLight;

  /// CartoDB basemap URL template for the active theme (light_all / dark_all).
  static String tileTemplate(bool dark) =>
      'https://{s}.basemaps.cartocdn.com/${dark ? 'dark_all' : 'light_all'}/{z}/{x}/{y}{r}.png';
}

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
  late AnimationController _pulseController;
  late AnimationController _cameraController;
  Animation<LatLng>? _cameraCenterAnim;
  Animation<double>? _cameraZoomAnim;

  // Current district type selection
  DistrictType _activeType = DistrictType.house;

  // Parsed GeoJSON polygons per type
  final Map<DistrictType, List<_DistrictPolygon>> _polygonsByType = {};
  final Set<DistrictType> _loadedTypes = {};
  String? _hoveredDistrict;
  Offset? _hoverLocalPosition;
  String? _goldRingDistrict;

  // Missouri bounds
  static final _moCenter = LatLng(38.35, -92.45);
  static const _initialZoom = 6.5;

  // Out-of-state mask: dissolved Missouri outline ring(s) used as the hole,
  // plus a rectangle comfortably larger than the padded MO bounds.
  List<List<LatLng>> _maskRings = const [];
  static final List<LatLng> _outerRect = <LatLng>[
    const LatLng(45, -102),
    const LatLng(45, -84),
    const LatLng(30, -84),
    const LatLng(30, -102),
  ];

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

    // Pulse loop: drives both YD marker glow AND the gold-ring pulse.
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    // Smooth camera flight controller — drives animated move() instead of
    // the hard jump the old MapController.move() did.
    _cameraController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _cameraController.addListener(() {
      if (_cameraCenterAnim != null && _cameraZoomAnim != null) {
        _mapController.move(
          _cameraCenterAnim!.value,
          _cameraZoomAnim!.value,
        );
      }
    });

    _loadGeoJson(_activeType);
    _loadMask();
  }

  /// Parse the dissolved Missouri outline into the ring(s) that form the hole
  /// in the out-of-state mask. Same ring parsing as [_loadGeoJson].
  Future<void> _loadMask() async {
    try {
      final raw = await rootBundle
          .loadString('assets/geojson/mo_state_outline.geojson');
      final geo = json.decode(raw) as Map<String, dynamic>;
      final features = geo['features'] as List<dynamic>;
      final rings = <List<LatLng>>[];
      for (final feature in features) {
        final geometry = feature['geometry'] as Map<String, dynamic>;
        final type = geometry['type'] as String;
        final coords = geometry['coordinates'];
        if (type == 'Polygon') {
          rings.add(_parseRing((coords as List).first as List));
        } else if (type == 'MultiPolygon') {
          for (final poly in coords as List) {
            rings.add(_parseRing((poly as List).first as List));
          }
        }
      }
      if (!mounted) return;
      setState(() => _maskRings = rings);
    } catch (e) {
      debugPrint('MissouriMapWidget mask load failed: $e');
    }
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
    _pulseController.dispose();
    _cameraController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  // Smooth-fly the camera to [target] at [zoom] over ~650ms using an
  // easeInOutCubic curve. Replaces MapController.move() for nicer UX.
  void _flyTo(LatLng target, double zoom) {
    final camera = _mapController.camera;
    final fromCenter = camera.center;
    final fromZoom = camera.zoom;

    _cameraController.stop();
    _cameraCenterAnim = LatLngTween(begin: fromCenter, end: target).animate(
      CurvedAnimation(parent: _cameraController, curve: Curves.easeInOutCubic),
    );
    _cameraZoomAnim = Tween<double>(begin: fromZoom, end: zoom).animate(
      CurvedAnimation(parent: _cameraController, curve: Curves.easeInOutCubic),
    );
    _cameraController.forward(from: 0);
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
    _flyTo(match.centroid, zoomLevel);
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

    // First pass: compute max YD count so we can normalize the heatmap.
    int maxYd = 1;
    for (final dp in polygons) {
      final candidates = districtMap[dp.district];
      if (candidates == null) continue;
      final ydCount = candidates.where((c) => c.isYoungDem).length;
      if (ydCount > maxYd) maxYd = ydCount;
    }

    for (final dp in polygons) {
      final candidates = districtMap[dp.district];
      dp.candidateCount = candidates?.length ?? 0;
      dp.ydCount = candidates?.where((c) => c.isYoungDem).length ?? 0;

      if (candidates == null || candidates.isEmpty) {
        // "No Democrat running" gets a subtle warning red-gray tint so it
        // pops visually as a gap the party should fill.
        dp.fillColor = const Color(0xFF6b7280).withOpacity(0.22);
        dp.borderColor = const Color(0xFF6b7280).withOpacity(0.45);
        dp.status = _DistrictStatus.noData;
      } else {
        final hasYd = dp.ydCount > 0;
        final hasDem = candidates.any((c) => c.isDemocrat);
        final hasRep = candidates.any((c) => c.isRepublican);

        if (hasYd) {
          // Heatmap: districts with more YDs get a brighter gold-saturated
          // glow. Clamp to avoid a pure white burnout on districts with 3+ YDs.
          final intensity = (dp.ydCount / maxYd).clamp(0.4, 1.0);
          dp.fillColor = Color.lerp(
            const Color(0xFF0b4db8).withOpacity(0.40),
            const Color(0xFFFDB813).withOpacity(0.55),
            intensity * 0.65,
          )!;
          dp.borderColor = const Color(0xFFFDB813).withOpacity(0.85);
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
          dp.fillColor = const Color(0xFFef4444).withOpacity(0.38);
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

  void _onDistrictTap(_DistrictPolygon dp, [Offset? localPos]) {
    setState(() {
      _hoveredDistrict = dp.district;
      _hoverLocalPosition = localPos ?? _hoverLocalPosition ?? Offset.zero;
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
          // When the parent gave us a bounded height (e.g. compactMode in
          // the split-screen candidates page passes height: double.infinity
          // inside an Expanded), expand to fill it. Otherwise the map's
          // SizedBox(height: double.infinity) would collapse to zero
          // because the Column wouldn't take the available vertical space.
          mainAxisSize: widget.height.isInfinite
              ? MainAxisSize.max
              : MainAxisSize.min,
          children: [
            if (!widget.compactMode) _buildTitle(),
            if (!widget.compactMode) _buildDistrictTypeToggle(),
            // When height is infinite, let the map flex to fill the column.
            // When height is finite, use the explicit value.
            if (widget.height.isInfinite)
              Expanded(child: _buildMap())
            else
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
              // Fit the state to THIS viewport rather than flying to a fixed
              // zoom. A zoom level is an absolute scale, so the hardcoded
              // constant drew Missouri small and adrift on a large screen and
              // cropped it on a small one. Same defect, and same fix, as
              // _statewideCamera() in candidate_volunteers_map.dart.
              final fit = CameraFit.bounds(
                bounds: moBounds,
                padding: const EdgeInsets.all(16),
              ).fit(_mapController.camera);
              _flyTo(fit.center, fit.zoom);
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Show spinner when the active district type hasn't loaded yet
    final isLoading = !_loadedTypes.contains(_activeType);

    if (isLoading) {
      // When wrapped in Expanded (height==infinity) the parent already
      // bounds us; SizedBox.expand() picks up that bound. When given an
      // explicit finite height, keep the original behaviour.
      return SizedBox(
        height: widget.height.isInfinite ? null : widget.height,
        width: widget.height.isInfinite ? double.infinity : null,
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

    // Build flutter_map polygon list. The out-of-state mask is prepended so
    // it draws under the district polygons and hides Kansas/Illinois tiles.
    final mapPolygons = <Polygon>[];
    if (_maskRings.isNotEmpty) {
      mapPolygons.add(Polygon(
        points: _outerRect,
        holePointsList: _maskRings,
        color: MoydMapTheme.maskColor(dark),
        borderStrokeWidth: 0,
        isFilled: true,
      ));
      final outlineColor =
          dark ? MoydMapTheme.gold.withOpacity(0.6) : MoydMapTheme.navy;
      for (final ring in _maskRings) {
        mapPolygons.add(Polygon(
          points: ring,
          color: Colors.transparent,
          borderColor: outlineColor,
          borderStrokeWidth: 2,
          isFilled: false,
        ));
      }
    }
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
        // Young Dem districts get a pulsing gold ring + bold navy center.
        // The pulse is driven by _pulseController (repeat reverse, 1.8s).
        markers.add(Marker(
          point: dp.centroid,
          width: 40,
          height: 40,
          child: GestureDetector(
            onTap: () => _onDistrictTap(dp),
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) {
                // 0..1 -> 0.85..1.15 ring scale, 0.55..0.15 ring opacity
                final t = _pulseController.value;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer pulsing ring
                    Transform.scale(
                      scale: 0.85 + t * 0.35,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: BrandColors.sunriseGold.withOpacity(0.55 - t * 0.4),
                            width: 2.5,
                          ),
                        ),
                      ),
                    ),
                    // Solid center badge
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [BrandColors.sunriseGold, Color(0xFFE89B00)],
                        ),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.9), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: BrandColors.sunriseGold.withOpacity(0.55),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          dp.district,
                          style: const TextStyle(
                            color: Color(0xFF1a1a2e),
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
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

    // Hover tooltip content — only painted when _hoveredDistrict is set.
    _DistrictPolygon? hoveredDp;
    if (_hoveredDistrict != null) {
      for (final dp in polygons) {
        if (dp.district == _hoveredDistrict) {
          hoveredDp = dp;
          break;
        }
      }
    }

    return SizedBox(
      // Same pattern as the loading branch — when wrapped in Expanded
      // the parent's bound takes effect; when given a finite height
      // use it directly.
      height: widget.height.isInfinite ? null : widget.height,
      width: widget.height.isInfinite ? double.infinity : null,
      child: ClipRRect(
        borderRadius: widget.compactMode
            ? BorderRadius.circular(12)
            : const BorderRadius.vertical(bottom: Radius.circular(12)),
        child: Stack(
          children: [
            GestureDetector(
              onTapUp: (details) => _handleMapTapGesture(details),
              child: FlutterMap(
                mapController: _mapController,
                options: moMapOptions(
                  center: _moCenter,
                  zoom: _initialZoom,
                  backgroundColor: MoydMapTheme.maskColor(dark),
                  interaction: InteractionOptions(
                    flags: widget.interactive
                        ? InteractiveFlag.all
                        : InteractiveFlag.none,
                  ),
                ),
                children: [
                  // Theme-matched CartoDB basemap (light_all / dark_all).
                  TileLayer(
                    urlTemplate: MoydMapTheme.tileTemplate(dark),
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
            // Floating hover/tap tooltip
            if (hoveredDp != null && _hoverLocalPosition != null)
              _buildHoverTooltip(hoveredDp),
          ],
        ),
      ),
    );
  }

  /// Floating dark pill in the top-left of the map showing district name +
  /// candidate count. Appears when a district is tapped; dismisses automatically
  /// on next tap.
  Widget _buildHoverTooltip(_DistrictPolygon dp) {
    final typeLabel = _typeLabels[_activeType] ?? '';
    final titleText = '$typeLabel District ${dp.district}';
    String subtitle;
    if (dp.status == _DistrictStatus.noData) {
      subtitle = 'No candidates filed yet';
    } else if (dp.ydCount > 0) {
      subtitle =
          '${dp.ydCount} Young Dem${dp.ydCount == 1 ? '' : 's'} · ${dp.candidateCount} total';
    } else {
      subtitle =
          '${dp.candidateCount} candidate${dp.candidateCount == 1 ? '' : 's'}';
    }
    return Positioned(
      left: 12,
      top: 12,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: BrandColors.unityBlue.withOpacity(0.94),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: BrandColors.sunriseGold.withOpacity(0.55), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                titleText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: dp.ydCount > 0
                      ? BrandColors.sunriseGold
                      : Colors.white.withOpacity(0.75),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
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
        _onDistrictTap(dp, details.localPosition);
        return;
      }
    }
    // Tap on empty map area — dismiss tooltip.
    setState(() {
      _hoveredDistrict = null;
      _hoverLocalPosition = null;
    });
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
              BrandColors.sunriseGold, 'Young Dem', ydDistricts),
          _legendChip(
              const Color(0xFF3b82f6), 'Democrat', demDistricts),
          _legendChip(const Color(0xFF8b5cf6), 'Contested', contested),
          _legendChip(
              const Color(0xFFef4444), 'Republican', repDistricts),
          _legendChip(const Color(0xFF6b7280), 'No Cand.', noData),
        ],
      ),
    );
  }

  Widget _legendChip(Color color, String label, int count) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withOpacity(0.22),
                color.withOpacity(0.10),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.45), width: 1),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.55),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '$count',
                    style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                ),
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
  Color fillColor = Colors.transparent;
  Color borderColor = Colors.transparent;
  _DistrictStatus status = _DistrictStatus.noData;
  int candidateCount = 0;
  int ydCount = 0;

  _DistrictPolygon({
    required this.district,
    required this.rings,
    required this.centroid,
  });
}

/// Tween that linearly interpolates two LatLng coordinates. Used by the
/// smooth camera flyTo() so we can animate center + zoom over an
/// easeInOutCubic curve instead of the hard jump MapController.move() does.
class LatLngTween extends Tween<LatLng> {
  LatLngTween({required LatLng begin, required LatLng end})
      : super(begin: begin, end: end);

  @override
  LatLng lerp(double t) {
    final b = begin!;
    final e = end!;
    return LatLng(
      b.latitude + (e.latitude - b.latitude) * t,
      b.longitude + (e.longitude - b.longitude) * t,
    );
  }
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
