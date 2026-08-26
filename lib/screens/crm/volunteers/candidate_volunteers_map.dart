import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart' show PointerHoverEvent;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:bluebubbles/models/crm/candidate.dart' show Candidate;
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/services/crm/candidate_repository.dart';
import 'package:bluebubbles/services/crm/election_results_repository.dart';
import 'package:bluebubbles/services/crm/ge_nominee_repository.dart';
import 'package:bluebubbles/services/crm/member_repository.dart';
import 'package:bluebubbles/screens/crm/candidate_detail_screen.dart';
import 'package:bluebubbles/screens/crm/bulk_message_screen.dart';
import 'package:bluebubbles/screens/crm/bulk_email_screen.dart';

import 'volunteers_map_models.dart';
import 'volunteers_detail_panel.dart';

// ═══════════════════════════════════════════════════════════════
//  CANDIDATE VOLUNTEERS — "The War Room Map"
//  A full-bleed interactive Missouri map: four geographies, two
//  choropleth lenses, tap-a-region → candidates + resident members,
//  desktop split panel / mobile draggable sheet.
//
//  Public entry: CandidateVolunteersMap
// ═══════════════════════════════════════════════════════════════

const double _kDesktopBreakpoint = 1200;
const double _kPanelWidth = 400;

class CandidateVolunteersMap extends StatefulWidget {
  const CandidateVolunteersMap({super.key, this.height});

  /// Optional fixed height. When null (the default) the widget fills the
  /// available vertical space via an Expanded/SizedBox.expand parent.
  final double? height;

  @override
  State<CandidateVolunteersMap> createState() => _CandidateVolunteersMapState();
}

class _CandidateVolunteersMapState extends State<CandidateVolunteersMap>
    with TickerProviderStateMixin {
  late final MapController _mapController;
  late final AnimationController _pulseController;
  late final AnimationController _cameraController;
  Animation<LatLng>? _cameraCenterAnim;
  Animation<double>? _cameraZoomAnim;
  bool _cameraMoving = false;

  // ── Missouri camera framing ──
  static const LatLng _moCenter = LatLng(38.35, -92.45);
  static const double _initialZoom = 6.4;

  // ── Mode + lens ──
  MapMode _mode = MapMode.county;
  MapLens _lens = MapLens.members;

  // ── Loaded geometry + reference data ──
  final Map<MapMode, List<RegionData>> _regions = {};
  final Map<MapMode, Map<String, RegionData>> _index = {};
  final Map<MapMode, Map<String, int>> _memberCounts = {};
  Map<String, List<ElectionResult>> _electionByDistrict = const {};
  Map<String, GeNominee> _geLookup = const {};
  final Set<String> _youngDemNames = {};
  final Map<String, Candidate> _candidateByName = {};
  int _statewideMembers = 0;
  int _statewideYoungDems = 0;
  bool _loadingBase = true;

  // ── Selection ──
  String? _selectedId;
  List<Member> _selectedMembers = const [];
  List<ElectionResult> _selectedCandidates = const [];
  bool _loadingMembers = false;
  int _selectionSeq = 0; // guards out-of-order async member loads

  // ── Interaction ──
  String? _hoveredId;
  RegionStatus? _statusFilter; // Lens B legend filter
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  bool _searchOpen = false;

  final _members = MemberRepository();
  final _elections = ElectionResultsRepository();
  final _nominees = GeNomineeRepository();
  final _candidates = CandidateRepository();

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
    _cameraController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..addListener(() {
        if (_cameraCenterAnim != null && _cameraZoomAnim != null) {
          _mapController.move(_cameraCenterAnim!.value, _cameraZoomAnim!.value);
        }
      })
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed || s == AnimationStatus.dismissed) {
          if (mounted) setState(() => _cameraMoving = false);
        }
      });
    _searchCtrl.addListener(() => setState(() {}));
    _searchFocus.addListener(() {
      setState(() => _searchOpen = _searchFocus.hasFocus);
    });
    _bootstrap();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _cameraController.dispose();
    _mapController.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ── Data load ──────────────────────────────────────────────────
  Future<void> _bootstrap() async {
    try {
      final results = await Future.wait([
        _parseGeoJson(MapMode.county),
        _parseGeoJson(MapMode.congressional),
        _parseGeoJson(MapMode.house),
        _parseGeoJson(MapMode.senate),
        _members.getMemberCountsByField('county'),
        _members.getMemberCountsByField('congressional_district'),
        _members.getMemberCountsByField('house_district'),
        _members.getMemberCountsByField('senate_district'),
        _elections.byDistrict(),
        _nominees.getLookup(),
        _candidates.fetchAllCandidates(),
        _members.countEligibleMembers(),
      ]);

      _regions[MapMode.county] = results[0] as List<RegionData>;
      _regions[MapMode.congressional] = results[1] as List<RegionData>;
      _regions[MapMode.house] = results[2] as List<RegionData>;
      _regions[MapMode.senate] = results[3] as List<RegionData>;
      _memberCounts[MapMode.county] = results[4] as Map<String, int>;
      _memberCounts[MapMode.congressional] = results[5] as Map<String, int>;
      _memberCounts[MapMode.house] = results[6] as Map<String, int>;
      _memberCounts[MapMode.senate] = results[7] as Map<String, int>;
      _electionByDistrict = results[8] as Map<String, List<ElectionResult>>;
      _geLookup = results[9] as Map<String, GeNominee>;
      final candidates = results[10] as List<Candidate>;
      _statewideMembers = results[11] as int;

      for (final c in candidates) {
        if (c.name.isEmpty) continue;
        _candidateByName[normalizeName(c.name)] = c;
        if (c.isYoungDem && c.isDemocrat) {
          _youngDemNames.add(normalizeName(c.name));
        }
      }

      _statewideYoungDems = _geLookup.values
          .where((n) => _youngDemNames.contains(normalizeName(n.nominee)))
          .length;

      for (final mode in MapMode.values) {
        final counts = _memberCounts[mode] ?? const {};
        final regions = _regions[mode] ?? const [];
        final index = <String, RegionData>{};
        for (final r in regions) {
          r.memberCount = counts[r.id] ?? 0;
          r.status = _computeStatus(mode, r.id);
          index[r.id] = r;
        }
        _index[mode] = index;
      }

      if (mounted) setState(() => _loadingBase = false);
    } catch (e) {
      debugPrint('CandidateVolunteersMap bootstrap failed: $e');
      if (mounted) setState(() => _loadingBase = false);
    }
  }

  Future<List<RegionData>> _parseGeoJson(MapMode mode) async {
    final raw = await rootBundle.loadString(mode.geoJsonPath);
    final geo = json.decode(raw) as Map<String, dynamic>;
    final features = geo['features'] as List<dynamic>;
    final out = <RegionData>[];
    for (final feature in features) {
      final props = feature['properties'] as Map<String, dynamic>;
      final rawId = props[mode.idProperty]?.toString() ?? '';
      final id = mode == MapMode.county
          ? (Member.normalizeCountyLabel(rawId) ?? rawId.trim())
          : bareDigits(rawId);
      if (id.isEmpty) continue;

      final geometry = feature['geometry'] as Map<String, dynamic>;
      final geoType = geometry['type'] as String;
      final coords = geometry['coordinates'];
      final rings = <List<LatLng>>[];
      if (geoType == 'Polygon') {
        for (final ring in coords as List) {
          rings.add(_parseRing(ring as List));
        }
      } else if (geoType == 'MultiPolygon') {
        for (final poly in coords as List) {
          for (final ring in poly as List) {
            rings.add(_parseRing(ring as List));
          }
        }
      }
      if (rings.isEmpty) continue;

      final outer = rings.first;
      double cx = 0, cy = 0;
      for (final p in outer) {
        cx += p.latitude;
        cy += p.longitude;
      }
      cx /= outer.length;
      cy /= outer.length;
      out.add(RegionData(id: id, rings: rings, centroid: LatLng(cx, cy)));
    }
    return out;
  }

  List<LatLng> _parseRing(List ring) => ring
      .map<LatLng>((c) => LatLng(
            (c[1] as num).toDouble(),
            (c[0] as num).toDouble(),
          ))
      .toList();

  RegionStatus _computeStatus(MapMode mode, String id) {
    final ot = mode.officeType;
    if (ot == null) return RegionStatus.notOnBallot;
    final key = '$ot:$id';
    final nominee = _geLookup[key];
    final hasRace = _electionByDistrict.containsKey(key);
    if (nominee != null) {
      if (_youngDemNames.contains(normalizeName(nominee.nominee))) {
        return RegionStatus.youngDem;
      }
      return nominee.contestedPrimary
          ? RegionStatus.demContested
          : RegionStatus.demUnopposed;
    }
    return hasRace ? RegionStatus.noDem : RegionStatus.notOnBallot;
  }

  List<RegionData> get _activeRegions => _regions[_mode] ?? const [];

  // ── Selection ──────────────────────────────────────────────────
  void _selectRegion(MapMode mode, String id) {
    final seq = ++_selectionSeq;
    final region = _index[mode]?[id];
    setState(() {
      _mode = mode;
      _selectedId = id;
      _hoveredId = null;
      _selectedCandidates = mode.isDistrict
          ? (_electionByDistrict['${mode.officeType}:$id'] ?? const [])
          : const [];
      _selectedMembers = const [];
      _loadingMembers = true;
      _searchOpen = false;
    });
    _searchFocus.unfocus();
    if (region != null) {
      _flyTo(region.centroid, _selectionZoom(mode));
    }
    _loadMembers(mode, id, seq);
  }

  double _selectionZoom(MapMode mode) {
    switch (mode) {
      case MapMode.county:
        return 8.0;
      case MapMode.congressional:
        return 7.2;
      case MapMode.senate:
        return 8.2;
      case MapMode.house:
        return 9.2;
    }
  }

  Future<void> _loadMembers(MapMode mode, String id, int seq) async {
    try {
      final List<Member> people;
      switch (mode) {
        case MapMode.county:
          people = await _members.getMembersInCounties([id]);
          break;
        case MapMode.house:
          people = await _members.getMembersInHouseDistricts([id]);
          break;
        case MapMode.senate:
          people = await _members.getMembersInSenateDistricts([id]);
          break;
        case MapMode.congressional:
          final res =
              await _members.getAllMembers(congressionalDistrict: 'CD-$id');
          people = res.members;
          break;
      }
      if (!mounted || seq != _selectionSeq) return;
      setState(() {
        _selectedMembers = people;
        _loadingMembers = false;
      });
    } catch (e) {
      debugPrint('CandidateVolunteersMap member load failed: $e');
      if (!mounted || seq != _selectionSeq) return;
      setState(() => _loadingMembers = false);
    }
  }

  void _clearSelection() {
    setState(() {
      _selectedId = null;
      _selectedMembers = const [];
      _selectedCandidates = const [];
      _loadingMembers = false;
    });
  }

  void _changeMode(MapMode mode) {
    if (mode == _mode) return;
    setState(() {
      _mode = mode;
      _selectedId = null;
      _hoveredId = null;
      _selectedMembers = const [];
      _selectedCandidates = const [];
      _loadingMembers = false;
      _statusFilter = null;
    });
    _flyTo(_moCenter, _initialZoom);
  }

  void _changeLens(MapLens lens) {
    if (lens == _lens) return;
    setState(() {
      _lens = lens;
      if (lens == MapLens.members) _statusFilter = null;
    });
  }

  // ── Camera ─────────────────────────────────────────────────────
  void _flyTo(LatLng target, double zoom) {
    final camera = _mapController.camera;
    _cameraController.stop();
    _cameraCenterAnim = _LatLngTween(begin: camera.center, end: target).animate(
      CurvedAnimation(parent: _cameraController, curve: Curves.fastOutSlowIn),
    );
    _cameraZoomAnim = Tween<double>(begin: camera.zoom, end: zoom).animate(
      CurvedAnimation(parent: _cameraController, curve: Curves.fastOutSlowIn),
    );
    setState(() => _cameraMoving = true);
    _cameraController.forward(from: 0);
  }

  void _zoomBy(double delta) {
    final camera = _mapController.camera;
    final z = (camera.zoom + delta).clamp(5.5, 12.0);
    _mapController.move(camera.center, z);
  }

  void _recenter() {
    _clearSelection();
    _flyTo(_moCenter, _initialZoom);
  }

  // ── Hit testing ────────────────────────────────────────────────
  RegionData? _regionAt(Offset localPosition) {
    if (_activeRegions.isEmpty) return null;
    final ll = _mapController.camera.pointToLatLng(
        math.Point(localPosition.dx, localPosition.dy));
    for (final r in _activeRegions) {
      if (pointInPolygon(ll, r.outerRing)) return r;
    }
    return null;
  }

  void _onTapUp(TapUpDetails d) {
    final r = _regionAt(d.localPosition);
    if (r == null) {
      _clearSelection();
      return;
    }
    _selectRegion(_mode, r.id);
  }

  void _onHover(PointerHoverEvent e) {
    final r = _regionAt(e.localPosition);
    final id = r?.id;
    if (id != _hoveredId) setState(() => _hoveredId = id);
  }

  // ── Member actions ─────────────────────────────────────────────
  void _textMembers(List<Member> people) {
    final valid = people.where((m) => m.canContact).toList();
    if (valid.isEmpty) {
      _snack('None of those members can be texted.');
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BulkMessageScreen(initialManualMembers: valid),
    ));
  }

  void _emailMembers(List<Member> people) {
    final valid =
        people.where((m) => (m.preferredEmail ?? '').isNotEmpty).toList();
    if (valid.isEmpty) {
      _snack('None of those members have an email on file.');
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BulkEmailScreen(initialManualMembers: valid),
    ));
  }

  void _openCandidate(Candidate c) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CandidateDetailScreen(candidate: c),
    ));
  }

  Candidate? _resolveCandidate(String name) =>
      _candidateByName[normalizeName(name)];

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Search index ───────────────────────────────────────────────
  List<RegionSearchEntry> _searchResults(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final out = <RegionSearchEntry>[];
    for (final mode in MapMode.values) {
      for (final r in _regions[mode] ?? const <RegionData>[]) {
        final label = mode.regionTitle(r.id);
        if (r.id.toLowerCase().contains(q) ||
            label.toLowerCase().contains(q)) {
          out.add(RegionSearchEntry(mode: mode, id: r.id, label: label));
          if (out.length >= 40) break;
        }
      }
    }
    // Prefer exact-id-prefix and same-mode matches first, then cap to 7.
    out.sort((a, b) {
      final ap = a.id.toLowerCase().startsWith(q) ? 0 : 1;
      final bp = b.id.toLowerCase().startsWith(q) ? 0 : 1;
      if (ap != bp) return ap - bp;
      return a.mode.index.compareTo(b.mode.index);
    });
    return out.take(7).toList();
  }

  // ── Build ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final content = LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= _kDesktopBreakpoint;
        if (isDesktop) return _desktopLayout(context);
        return _mobileLayout(context);
      },
    );

    if (widget.height != null && widget.height!.isFinite) {
      return SizedBox(height: widget.height, child: content);
    }
    return content;
  }

  Widget _desktopLayout(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _mapStack(context)),
        Container(
          width: 1,
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF2E3A57)
                : const Color(0xFFE5E9F0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 16,
                offset: const Offset(-4, 0),
              ),
            ],
          ),
        ),
        SizedBox(
          width: _kPanelWidth,
          child: _buildPanel(context, showClose: _selectedId != null),
        ),
      ],
    );
  }

  Widget _mobileLayout(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: _mapStack(context)),
        if (_selectedId != null)
          DraggableScrollableSheet(
            initialChildSize: 0.45,
            minChildSize: 0.12,
            maxChildSize: 0.92,
            snap: true,
            snapSizes: const [0.12, 0.45, 0.92],
            builder: (context, scrollController) {
              return _MobileSheet(
                child: _buildPanel(
                  context,
                  showClose: true,
                  scrollController: scrollController,
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildPanel(
    BuildContext context, {
    required bool showClose,
    ScrollController? scrollController,
  }) {
    final id = _selectedId;
    RegionDetail? detail;
    if (id != null) {
      final region = _index[_mode]?[id];
      detail = RegionDetail(
        mode: _mode,
        id: id,
        status: region?.status ?? RegionStatus.notOnBallot,
        memberCount: region?.memberCount ?? 0,
        candidates: _selectedCandidates,
        members: _selectedMembers,
        loadingCandidates: false,
        loadingMembers: _loadingMembers,
        youngDemNames: _youngDemNames,
      );
    }
    return VolunteersDetailPanel(
      detail: detail,
      statewideMembers: _statewideMembers,
      statewideYoungDems: _statewideYoungDems,
      hotRegions: _hotRegions(),
      onClose: _clearSelection,
      onSelectHot: _selectRegion,
      onOpenCandidate: _openCandidate,
      onTextMembers: _textMembers,
      onEmailMembers: _emailMembers,
      resolveCandidate: _resolveCandidate,
      scrollController: scrollController,
      showCloseButton: showClose,
    );
  }

  List<HotRegion> _hotRegions() {
    final regions = [..._activeRegions];
    regions.sort((a, b) {
      final ay = a.status == RegionStatus.youngDem ? 1 : 0;
      final by = b.status == RegionStatus.youngDem ? 1 : 0;
      if (ay != by) return by - ay;
      return b.memberCount.compareTo(a.memberCount);
    });
    return regions
        .take(5)
        .map((r) => HotRegion(
            mode: _mode, id: r.id, memberCount: r.memberCount, status: r.status))
        .toList();
  }

  // ── Map + floating chrome ──────────────────────────────────────
  Widget _mapStack(BuildContext context) {
    if (_loadingBase && _activeRegions.isEmpty) {
      return Container(
        color: const Color(0xFFEFF2F6),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                  color: MapPalette.momentumBlue, strokeWidth: 2.5),
              SizedBox(height: 14),
              Text('Loading the war room…',
                  style: TextStyle(color: Color(0xFF5A6478), fontSize: 13)),
            ],
          ),
        ),
      );
    }

    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return ClipRect(
      child: Stack(
        children: [
          Positioned.fill(
            child: MouseRegion(
              onHover: _onHover,
              onExit: (_) {
                if (_hoveredId != null) setState(() => _hoveredId = null);
              },
              child: GestureDetector(
                onTapUp: _onTapUp,
                child: _buildFlutterMap(reduceMotion),
              ),
            ),
          ),

          // top-left: mode + lens
          Positioned(
            left: 16,
            top: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _modeSwitcher(),
                const SizedBox(height: 8),
                _lensToggle(),
              ],
            ),
          ),

          // top-right: search
          Positioned(
            right: 16,
            top: 16,
            width: 300,
            child: _searchPill(),
          ),

          // bottom-left: legend
          Positioned(left: 16, bottom: 16, child: _legend()),

          // bottom-right: zoom
          Positioned(right: 16, bottom: 16, child: _zoomCluster()),

          // hover tooltip
          if (_hoveredId != null) _hoverTooltip(),
        ],
      ),
    );
  }

  Widget _buildFlutterMap(bool reduceMotion) {
    final polygons = <Polygon>[];
    for (final r in _activeRegions) {
      polygons.add(Polygon(
        points: r.outerRing,
        holePointsList: r.holes,
        color: _fillFor(r),
        borderColor: Colors.white,
        borderStrokeWidth: 1.2,
      ));
    }
    // Selected gold ring (white casing under gold), drawn last.
    final sel = _selectedId == null ? null : _index[_mode]?[_selectedId];
    if (sel != null) {
      polygons.add(Polygon(
        points: sel.outerRing,
        holePointsList: sel.holes,
        borderColor: Colors.white,
        borderStrokeWidth: 5.5,
      ));
      polygons.add(Polygon(
        points: sel.outerRing,
        holePointsList: sel.holes,
        borderColor: MapPalette.sunriseGold,
        borderStrokeWidth: 3,
      ));
    }

    return FlutterMap(
      mapController: _mapController,
      options: const MapOptions(
        initialCenter: _moCenter,
        initialZoom: _initialZoom,
        minZoom: 5.5,
        maxZoom: 12.0,
        interactionOptions:
            const InteractionOptions(flags: InteractiveFlag.all),
        backgroundColor: const Color(0xFFEFF2F6),
      ),
      children: [
        TileLayer(
          urlTemplate:
              'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'org.moyoungdemocrats.crm',
          maxZoom: 18,
        ),
        PolygonLayer(polygons: polygons, polygonCulling: true),
        MarkerLayer(markers: _youngDemMarkers(reduceMotion)),
      ],
    );
  }

  Color _fillFor(RegionData r) {
    // base solid + base opacity
    final Color solid;
    final double baseOpacity;
    if (_lens == MapLens.members) {
      solid = MapPalette.densityStops[MapPalette.densityBin(r.memberCount)];
      baseOpacity = r.memberCount <= 0 ? 0.55 : 0.72;
    } else {
      solid = MapPalette.statusSwatch(r.status);
      baseOpacity = r.status == RegionStatus.notOnBallot ? 0.45 : 0.72;
    }

    double op;
    if (_selectedId == r.id) {
      op = 0.92;
    } else if (_selectedId != null) {
      op = 0.55;
    } else if (_lens == MapLens.candidates &&
        _statusFilter != null &&
        r.status != _statusFilter) {
      op = 0.30;
    } else if (_hoveredId == r.id) {
      op = 0.88;
    } else {
      op = baseOpacity;
    }
    return solid.withValues(alpha: op);
  }

  List<Marker> _youngDemMarkers(bool reduceMotion) {
    if (!_mode.isDistrict) return const [];
    final youngDem = _activeRegions
        .where((r) => r.status == RegionStatus.youngDem)
        .take(20)
        .toList();
    return youngDem.map((r) {
      return Marker(
        point: r.centroid,
        width: 44,
        height: 44,
        child: GestureDetector(
          onTap: () => _selectRegion(_mode, r.id),
          child: (reduceMotion || _cameraMoving)
              ? _staticPin(r.id)
              : AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, _) {
                    final t = _pulseController.value;
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        Transform.scale(
                          scale: 1.0 + t * 0.9,
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: MapPalette.sunriseGold
                                  .withValues(alpha: 0.45 * (1 - t)),
                            ),
                          ),
                        ),
                        _staticPin(r.id),
                      ],
                    );
                  },
                ),
        ),
      );
    }).toList();
  }

  Widget _staticPin(String id) => Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: MapPalette.sunriseGold,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
                color: MapPalette.sunriseGold.withValues(alpha: 0.5),
                blurRadius: 8,
                spreadRadius: 1),
          ],
        ),
        child: const Icon(Icons.star_rounded,
            color: MapPalette.unityBlue, size: 16),
      );

  // ── Mode switcher ──────────────────────────────────────────────
  Widget _modeSwitcher() {
    const modes = MapMode.values;
    return _glass(
      radius: 999,
      child: LayoutBuilder(builder: (context, _) {
        const segWidth = 92.0;
        final selectedIndex = modes.indexOf(_mode);
        return SizedBox(
          height: 40,
          width: segWidth * modes.length,
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                left: segWidth * selectedIndex,
                top: 0,
                bottom: 0,
                width: segWidth,
                child: Container(
                  margin: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [MapPalette.unityBlue, MapPalette.momentumBlue],
                    ),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                          color: MapPalette.sunriseGold.withValues(alpha: 0.35),
                          blurRadius: 6,
                          offset: const Offset(0, 2)),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  for (final mode in modes)
                    SizedBox(
                      width: segWidth,
                      height: 40,
                      child: _modeSegment(mode, mode == _mode),
                    ),
                ],
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _modeSegment(MapMode mode, bool selected) {
    final count = _regions[mode]?.length;
    return Semantics(
      button: true,
      selected: selected,
      label: mode.segmentLabel,
      excludeSemantics: true,
      child: InkWell(
        onTap: () => _changeMode(mode),
        borderRadius: BorderRadius.circular(999),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(mode.segmentLabel,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? Colors.white
                        : (_isDark ? const Color(0xFFC9D2E4)
                            : const Color(0xFF3C4763)),
                  )),
              if (count != null) ...[
                const SizedBox(width: 3),
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text('$count',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? Colors.white.withValues(alpha: 0.85)
                            : MapPalette.momentumBlue,
                      )),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Lens toggle ────────────────────────────────────────────────
  Widget _lensToggle() {
    return _glass(
      radius: 999,
      child: SizedBox(
        height: 34,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _lensSegment(MapLens.members, 'Members', MapPalette.momentumBlue),
            _lensSegment(MapLens.candidates, 'Candidates',
                MapPalette.sunriseGold),
          ],
        ),
      ),
    );
  }

  Widget _lensSegment(MapLens lens, String label, Color dot) {
    final selected = _lens == lens;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label lens',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => _changeLens(lens),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          margin: const EdgeInsets.all(3),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? MapPalette.unityBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? Colors.white
                        : (_isDark
                            ? const Color(0xFFC9D2E4)
                            : const Color(0xFF3C4763)),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  // ── Search ─────────────────────────────────────────────────────
  Widget _searchPill() {
    final List<RegionSearchEntry> results =
        _searchOpen ? _searchResults(_searchCtrl.text) : const <RegionSearchEntry>[];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _glass(
          radius: 999,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(Icons.search,
                    size: 18,
                    color: _isDark ? Colors.white70 : const Color(0xFF5A6478)),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    focusNode: _searchFocus,
                    style: TextStyle(
                        fontSize: 13.5,
                        color: _isDark ? Colors.white : const Color(0xFF1E2637)),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'Jump to a district, county, or town…',
                      hintStyle: TextStyle(
                          fontSize: 13,
                          color: (_isDark ? Colors.white : Colors.black)
                              .withValues(alpha: 0.4)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
                if (_searchCtrl.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchCtrl.clear();
                    },
                    child: Icon(Icons.close,
                        size: 16,
                        color:
                            _isDark ? Colors.white54 : const Color(0xFF8A93A6)),
                  ),
              ],
            ),
          ),
        ),
        if (results.isNotEmpty) ...[
          const SizedBox(height: 6),
          _glass(
            radius: 14,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 6),
                children: _groupedResults(results),
              ),
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _groupedResults(List<RegionSearchEntry> results) {
    final widgets = <Widget>[];
    String? lastGroup;
    for (final e in results) {
      if (e.group != lastGroup) {
        lastGroup = e.group;
        widgets.add(Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
          child: Text(e.group,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: _isDark ? Colors.white54 : const Color(0xFF8A93A6),
              )),
        ));
      }
      widgets.add(InkWell(
        onTap: () {
          _searchCtrl.clear();
          _searchFocus.unfocus();
          _selectRegion(e.mode, e.id);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(e.label,
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: _isDark ? Colors.white : const Color(0xFF1E2637))),
        ),
      ));
    }
    return widgets;
  }

  // ── Legend ─────────────────────────────────────────────────────
  Widget _legend() {
    return _glass(
      radius: 12,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: _lens == MapLens.members ? _legendMembers() : _legendCandidates(),
      ),
    );
  }

  Widget _legendMembers() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _legendTitle('MEMBER DENSITY'),
        const SizedBox(height: 8),
        SizedBox(
          width: 160,
          height: 10,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Row(
              children: [
                for (final c in MapPalette.densityStops)
                  Expanded(child: Container(color: c)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 160,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _legendMicro('0'),
              _legendMicro('26+'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _legendCandidates() {
    const order = [
      RegionStatus.youngDem,
      RegionStatus.demContested,
      RegionStatus.demUnopposed,
      RegionStatus.noDem,
      RegionStatus.notOnBallot,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _legendTitle('CANDIDATE STATUS'),
        const SizedBox(height: 8),
        for (final s in order) _legendStatusRow(s),
      ],
    );
  }

  Widget _legendStatusRow(RegionStatus s) {
    final active = _statusFilter == s;
    final dimmed = _statusFilter != null && !active;
    return Semantics(
      button: true,
      selected: active,
      excludeSemantics: true,
      child: InkWell(
        onTap: () =>
            setState(() => _statusFilter = active ? null : s),
        borderRadius: BorderRadius.circular(6),
        child: Opacity(
          opacity: dimmed ? 0.45 : 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: MapPalette.statusSwatch(s),
                    borderRadius: BorderRadius.circular(3),
                    border: active
                        ? Border.all(color: MapPalette.unityBlue, width: 1.5)
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Text(MapPalette.statusLabel(s),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                      color:
                          _isDark ? Colors.white : const Color(0xFF3C4763),
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _legendTitle(String label) => Text(label,
      style: TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        color: _isDark ? Colors.white70 : const Color(0xFF5A6478),
      ));

  Widget _legendMicro(String label) => Text(label,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: _isDark ? Colors.white54 : const Color(0xFF8A93A6),
      ));

  // ── Zoom cluster ───────────────────────────────────────────────
  Widget _zoomCluster() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _zoomButton(Icons.add, 'Zoom in', () => _zoomBy(1)),
        const SizedBox(height: 6),
        _zoomButton(Icons.remove, 'Zoom out', () => _zoomBy(-1)),
        const SizedBox(height: 6),
        _zoomButton(Icons.my_location, 'Recenter on Missouri', _recenter),
      ],
    );
  }

  Widget _zoomButton(IconData icon, String label, VoidCallback onTap) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: _glass(
        radius: 12,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon,
                size: 20,
                color: _isDark ? Colors.white : const Color(0xFF273351)),
          ),
        ),
      ),
    );
  }

  // ── Hover tooltip ──────────────────────────────────────────────
  Widget _hoverTooltip() {
    final r = _index[_mode]?[_hoveredId];
    if (r == null) return const SizedBox.shrink();
    final line = _lens == MapLens.members
        ? '${r.memberCount} member${r.memberCount == 1 ? '' : 's'}'
        : (_mode.isDistrict
            ? MapPalette.statusLabel(r.status)
            : '${r.memberCount} member${r.memberCount == 1 ? '' : 's'}');
    return Positioned(
      left: 16,
      top: 116,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: MapPalette.unityBlue.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: MapPalette.sunriseGold.withValues(alpha: 0.5), width: 1),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 14,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_mode.regionTitle(r.id),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(line,
                  style: TextStyle(
                      color: r.status == RegionStatus.youngDem
                          ? MapPalette.sunriseGold
                          : Colors.white.withValues(alpha: 0.75),
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Glass chrome helper ────────────────────────────────────────
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Widget _glass({required double radius, required Widget child}) {
    final bg = _isDark
        ? const Color(0xFF1B2337).withValues(alpha: 0.90)
        : Colors.white.withValues(alpha: 0.90);
    final border = _isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.06);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: border, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(color: Colors.transparent, child: child),
        ),
      ),
    );
  }
}

/// Rounded, shadowed sheet chrome for the mobile draggable panel. The [child]
/// (the detail panel) owns the sheet's scroll controller so drag-to-expand
/// works; this only adds the top radius + grabber.
class _MobileSheet extends StatelessWidget {
  const _MobileSheet({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B2337) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 24,
              offset: const Offset(0, -6)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFC3CAD6),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Linear interpolation for a LatLng camera fly.
class _LatLngTween extends Tween<LatLng> {
  _LatLngTween({required LatLng begin, required LatLng end})
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
