import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart' show PointerHoverEvent;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, LogicalKeyboardKey;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:bluebubbles/models/crm/candidate.dart' show Candidate;
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/models/crm/outreach_activity.dart';
import 'package:bluebubbles/services/crm/candidate_repository.dart';
import 'package:bluebubbles/services/crm/outreach_repository.dart';
import 'package:bluebubbles/services/crm/crosswalk_repository.dart';
import 'package:bluebubbles/services/crm/election_results_repository.dart';
import 'package:bluebubbles/services/crm/ge_nominee_repository.dart';
import 'package:bluebubbles/services/crm/member_repository.dart';
import 'package:bluebubbles/screens/crm/bulk_message_screen.dart';
import 'package:bluebubbles/screens/crm/bulk_email_screen.dart';

import 'organizing_toolkit_sheet.dart';
import 'volunteers_map_models.dart';
import 'volunteers_detail_panel.dart';
import 'volunteers_theme.dart';

// ═══════════════════════════════════════════════════════════════
//  CANDIDATE VOLUNTEERS — "The Field Map"
//  A Missouri-only interactive map: four geographies, a member-density
//  choropleth, tap-a-region → candidates + resident members, desktop
//  right rail / mobile draggable sheet. Missouri is masked so the camera
//  never wanders into Kansas or Illinois and out-of-state tiles are hidden.
//
//  Public entry: CandidateVolunteersMap
// ═══════════════════════════════════════════════════════════════

const double _kDesktopBreakpoint = 1200;
const double _kPanelWidth = 400; // 360–440 rail per spec

class CandidateVolunteersMap extends StatefulWidget {
  const CandidateVolunteersMap({super.key, this.height, this.onOpenActivities});

  /// Optional fixed height. When null (the default) the widget fills the
  /// available vertical space via an Expanded/SizedBox.expand parent.
  final double? height;

  /// Fired by the statewide rail's "All activities" link and "This week"
  /// footer. The workspace shell flips its IndexedStack to the Activities tab.
  /// Null when mounted outside the shell — the link is then hidden.
  final VoidCallback? onOpenActivities;

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

  // ── Mode ──
  MapMode _mode = MapMode.county;

  // ── Loaded geometry + reference data ──
  final Map<MapMode, List<RegionData>> _regions = {};
  final Map<MapMode, Map<String, RegionData>> _index = {};
  final Map<MapMode, Map<String, int>> _memberCounts = {};
  final Map<MapMode, List<int>> _choroplethCuts = {}; // 4 quantile cut points
  final Map<MapMode, List<int>> _memberRange = {}; // [min, max]
  Map<String, List<ElectionResult>> _electionByDistrict = const {};
  Map<String, GeNominee> _geLookup = const {};
  final Set<String> _youngDemNames = {};
  // 'officeType:bareDigits(district)' -> candidates classified into that race.
  final Map<String, List<Candidate>> _candidatesByDistrict = {};
  int _statewideMembers = 0;
  int _statewideYoungDems = 0;
  bool _loadingBase = true;

  // ── Selection ──
  String? _selectedId;
  List<Member> _selectedMembers = const [];
  List<CandidateDisplayGroup> _selectedGroups = const [];
  bool _loadingMembers = false;
  bool _loadingCandidates = false;
  int _selectionSeq = 0; // guards out-of-order async loads

  // ── Interaction ──
  String? _hoveredId;

  // ── Outreach activity presence (planned/in_progress) ──
  // One live query, cached in state, then bucketed client-side per MapMode.
  final _outreach = OutreachRepository();
  List<OutreachActivity> _activities = const [];
  final Map<MapMode, Set<String>> _regionsWithActivity = {
    for (final m in MapMode.values) m: <String>{},
  };

  final _members = MemberRepository();
  final _elections = ElectionResultsRepository();
  final _nominees = GeNomineeRepository();
  final _candidates = CandidateRepository();
  final _crosswalk = CrosswalkRepository();

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
    _bootstrap();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _cameraController.dispose();
    _mapController.dispose();
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
        // Shared classifier on the repository (also used by the candidate
        // profile's District tab), so the two never drift.
        final ot = ElectionResultsRepository.officeTypeFor(c.office);
        final d = c.district == null ? null : bareDigits(c.district!);
        if (ot != null && d != null && d.isNotEmpty) {
          (_candidatesByDistrict['$ot:$d'] ??= <Candidate>[]).add(c);
        }
        if (c.isYoungDem && c.isDemocrat) {
          _youngDemNames.add(normalizeName(c.name));
        }
      }

      _statewideYoungDems = _geLookup.values
          .where((n) => _youngDemNames.contains(normalizeName(n.nominee)))
          .length;

      for (final mode in MapMode.values) {
        final counts = _memberCounts[mode] ?? const {};
        final regions = _regions[mode] ?? const <RegionData>[];
        final index = <String, RegionData>{};
        for (final r in regions) {
          r.memberCount = counts[r.id] ?? 0;
          r.status = _computeStatus(mode, r.id);
          index[r.id] = r;
        }
        _index[mode] = index;
        final vals = regions.map((r) => r.memberCount).toList();
        _choroplethCuts[mode] = _computeQuantileCuts(vals);
        if (vals.isEmpty) {
          _memberRange[mode] = const [0, 0];
        } else {
          _memberRange[mode] = [vals.reduce(math.min), vals.reduce(math.max)];
        }
      }

      if (mounted) setState(() => _loadingBase = false);

      // Activity presence rides on top of the finished base map, so the
      // choropleth shows immediately and the activity dots resolve a moment
      // later.
      await _loadActivityCoverage();
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
      String id = mode == MapMode.county
          ? (Member.normalizeCountyLabel(rawId) ?? rawId.trim())
          : bareDigits(rawId);
      if (id.isEmpty) continue;
      // St. Louis is TWO features sharing the county name "St. Louis": the
      // county (geoid 29189) and the independent city (geoid 29510). Keying
      // both on "St. Louis" collided them into one region with a doubled
      // member count. Give the city its own id so the two rank and select
      // independently. regionTitle keeps "St. Louis City" intact.
      if (mode == MapMode.county &&
          props['geoid']?.toString() == '29510') {
        id = 'St. Louis City';
      }

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

  String _officeTypeLabel(String ot) {
    switch (ot) {
      case 'congressional':
        return 'Congressional';
      case 'senate':
        return 'Senate';
      case 'house':
        return 'House';
      default:
        return ot;
    }
  }

  String _districtChipLabel(String ot, String d) {
    switch (ot) {
      case 'congressional':
        return 'CD $d';
      case 'senate':
        return 'SD $d';
      case 'house':
        return 'HD $d';
      default:
        return d;
    }
  }

  /// Best-effort name match: casefold + strip punctuation via [normalizeName].
  Candidate? _matchResultToCandidate(
      String officeType, String district, ElectionResult r) {
    final list = _candidatesByDistrict['$officeType:$district'];
    if (list == null) return null;
    final target = normalizeName(r.candidateName);
    for (final c in list) {
      if (normalizeName(c.name) == target) return c;
    }
    return null;
  }

  List<CandidateDisplayRow> _rowsForDistrict(String officeType, String district) {
    final rows = <CandidateDisplayRow>[];
    final results = _electionByDistrict['$officeType:$district'] ?? const [];
    for (final r in results) {
      // Candidate Volunteers shows ONLY the November general-election ballot,
      // Democrats only. `advanced` marks the nominee who reached the November
      // ballot; primary losers and every non-Democrat party are excluded here,
      // at the single funnel both the county and district grouping paths run
      // through, so nothing non-Dem or non-November can leak into any pane.
      if (!(r.advanced && r.isDemocrat)) continue;
      final cand = _matchResultToCandidate(officeType, district, r);
      rows.add(CandidateDisplayRow(
        result: r,
        candidate: cand,
        isNominee: r.advanced,
      ));
    }
    return rows;
  }

  /// District modes yield a single office-typed group for the selected seat.
  List<CandidateDisplayGroup> _districtGroups(MapMode mode, String id) {
    final ot = mode.officeType;
    if (ot == null) return const [];
    final rows = _rowsForDistrict(ot, id);
    if (rows.isEmpty) return const [];
    return [
      CandidateDisplayGroup(
        officeTypeLabel: _officeTypeLabel(ot),
        districtChips: [_districtChipLabel(ot, id)],
        rows: rows,
      ),
    ];
  }

  /// County mode: borrow the candidate rows of the districts that overlap the
  /// county, grouped by office type (Congressional, Senate, House).
  Future<List<CandidateDisplayGroup>> _countyGroups(String countyId) async {
    final norm = Member.normalizeCountyLabel(countyId) ?? countyId;
    final cw = (await _crosswalk.getCountyCrosswalk())[norm];
    if (cw == null) return const [];
    const order = <List<String>>[
      ['congressional', 'Congressional'],
      ['senate', 'Senate'],
      ['house', 'House'],
    ];
    final groups = <CandidateDisplayGroup>[];
    for (final entry in order) {
      final ot = entry[0];
      final label = entry[1];
      final districts = cw[ot] ?? const [];
      if (districts.isEmpty) continue;
      final chips = <String>[];
      final rows = <CandidateDisplayRow>[];
      for (final d in districts) {
        chips.add(_districtChipLabel(ot, d));
        rows.addAll(_rowsForDistrict(ot, d));
      }
      groups.add(CandidateDisplayGroup(
        officeTypeLabel: label,
        districtChips: chips,
        rows: rows,
      ));
    }
    return groups;
  }

  // ── Selection ──────────────────────────────────────────────────
  void _selectRegion(MapMode mode, String id) {
    final seq = ++_selectionSeq;
    final region = _index[mode]?[id];
    setState(() {
      _mode = mode;
      _selectedId = id;
      _hoveredId = null;
      _selectedGroups = mode.isDistrict ? _districtGroups(mode, id) : const [];
      _loadingCandidates = !mode.isDistrict; // county resolves async
      _selectedMembers = const [];
      _loadingMembers = true;
    });
    if (region != null) {
      final fit = _fittedCamera(region);
      _flyTo(fit.center, fit.zoom);
    }
    _loadMembers(mode, id, seq);
    if (!mode.isDistrict) _loadCountyGroups(id, seq);
  }

  /// Frame the selected region's polygon in the current viewport: build a
  /// [LatLngBounds] over all of its ring points, fit it with 48px padding via
  /// flutter_map's [CameraFit], and clamp the derived zoom to the map's
  /// 6.0–12.0 range. The camera then flies to that center+zoom with the same
  /// smooth tween used everywhere else.
  ({LatLng center, double zoom}) _fittedCamera(RegionData region) {
    var minLat = double.infinity, maxLat = -double.infinity;
    var minLng = double.infinity, maxLng = -double.infinity;
    for (final ring in region.rings) {
      for (final p in ring) {
        if (p.latitude < minLat) minLat = p.latitude;
        if (p.latitude > maxLat) maxLat = p.latitude;
        if (p.longitude < minLng) minLng = p.longitude;
        if (p.longitude > maxLng) maxLng = p.longitude;
      }
    }
    if (minLat > maxLat) {
      // No ring points (should not happen); fall back to the centroid.
      return (center: region.centroid, zoom: _mapController.camera.zoom);
    }
    final bounds = LatLngBounds(
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
    );
    final fitted = CameraFit.bounds(
      bounds: bounds,
      padding: const EdgeInsets.all(48),
    ).fit(_mapController.camera);
    return (center: fitted.center, zoom: fitted.zoom.clamp(6.0, 12.0));
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

  Future<void> _loadCountyGroups(String id, int seq) async {
    try {
      final groups = await _countyGroups(id);
      if (!mounted || seq != _selectionSeq) return;
      setState(() {
        _selectedGroups = groups;
        _loadingCandidates = false;
      });
    } catch (e) {
      debugPrint('CandidateVolunteersMap county candidates load failed: $e');
      if (!mounted || seq != _selectionSeq) return;
      setState(() => _loadingCandidates = false);
    }
  }

  void _clearSelection() {
    setState(() {
      _selectedId = null;
      _selectedMembers = const [];
      _selectedGroups = const [];
      _loadingMembers = false;
      _loadingCandidates = false;
    });
  }

  void _changeMode(MapMode mode) {
    if (mode == _mode) return;
    setState(() {
      _mode = mode;
      _selectedId = null;
      _hoveredId = null;
      _selectedMembers = const [];
      _selectedGroups = const [];
      _loadingMembers = false;
      _loadingCandidates = false;
    });
    _flyTo(_moCenter, _initialZoom);
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
    final z = (camera.zoom + delta).clamp(6.0, 12.0);
    _mapController.move(camera.center, z);
  }

  void _recenter() {
    _clearSelection();
    // Snap Missouri back to filling the frame, the same fit the map opens with.
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: moBounds,
        padding: const EdgeInsets.all(16),
      ),
    );
  }

  // ── Hit testing ────────────────────────────────────────────────
  RegionData? _regionAt(Offset localPosition) {
    if (_activeRegions.isEmpty) return null;
    final ll = _mapController.camera.pointToLatLng(
        math.Point(localPosition.dx, localPosition.dy));
    for (final r in _activeRegions) {
      if (!pointInPolygon(ll, r.outerRing)) continue;
      // Reject taps that fall inside a hole ring.
      final holes = r.holes;
      if (holes != null && holes.any((h) => pointInPolygon(ll, h))) continue;
      return r;
    }
    return null;
  }

  /// Region selection driven by flutter_map's native [MapOptions.onTap], which
  /// hands us the exact tapped [LatLng]. This replaces the old GestureDetector +
  /// pointToLatLng path, which competed with the map's own gesture arena and
  /// left clicks dead.
  void _onMapTapLatLng(LatLng ll) {
    final r = _regionAtLatLng(ll);
    if (r == null) {
      _clearSelection();
      return;
    }
    _selectRegion(_mode, r.id);
  }

  /// Hit-test a tapped [LatLng] straight against the active regions, skipping
  /// pixel coordinates entirely. Rejects taps that land inside a hole ring.
  RegionData? _regionAtLatLng(LatLng ll) {
    for (final r in _activeRegions) {
      if (!pointInPolygon(ll, r.outerRing)) continue;
      final holes = r.holes;
      if (holes != null && holes.any((h) => pointInPolygon(ll, h))) continue;
      return r;
    }
    return null;
  }

  void _onHover(PointerHoverEvent e) {
    final r = _regionAt(e.localPosition);
    final id = r?.id;
    if (id != _hoveredId) setState(() => _hoveredId = id);
  }

  // ── Member actions ─────────────────────────────────────────────
  Future<void> _textMembers(List<Member> people) async {
    final valid = people.where((m) => m.canContact).toList();
    if (valid.isEmpty) {
      _snack('None of those members can be texted.');
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BulkMessageScreen(initialManualMembers: valid),
    ));
    if (!mounted) return;
    _offerLogIt(valid, kind: 'text_bank', channel: 'sms');
    _refreshMembersAfterContact();
  }

  Future<void> _emailMembers(List<Member> people) async {
    final valid =
        people.where((m) => (m.preferredEmail ?? '').isNotEmpty).toList();
    if (valid.isEmpty) {
      _snack('None of those members have an email on file.');
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BulkEmailScreen(initialManualMembers: valid),
    ));
    if (!mounted) return;
    _offerLogIt(valid, kind: 'email_blast', channel: 'email');
    _refreshMembersAfterContact();
  }

  /// The bulk text/email screens stamp `last_contacted`. Reload the selected
  /// region's members so the "never/not contacted" filters, recently-contacted
  /// sort, and header counts reflect it instead of going stale until reselect.
  void _refreshMembersAfterContact() {
    final id = _selectedId;
    if (id == null) return;
    _loadMembers(_mode, id, _selectionSeq);
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Outreach logging ───────────────────────────────────────────
  /// The four district lists for the current selection, one populated by the
  /// selected region's id (county mode → counties, etc.), the rest empty.
  ({List<String> counties, List<String> cds, List<String> sds, List<String> hds})
      _selectedGeo() {
    final id = _selectedId;
    if (id == null) {
      return (counties: const [], cds: const [], sds: const [], hds: const []);
    }
    switch (_mode) {
      case MapMode.county:
        return (counties: [id], cds: const [], sds: const [], hds: const []);
      case MapMode.congressional:
        return (counties: const [], cds: [id], sds: const [], hds: const []);
      case MapMode.senate:
        return (counties: const [], cds: const [], sds: [id], hds: const []);
      case MapMode.house:
        return (counties: const [], cds: const [], sds: const [], hds: [id]);
    }
  }

  /// Every real candidate profile tied to the currently selected region.
  List<Candidate> _selectedCandidates() => _selectedGroups
      .expand((g) => g.rows)
      .map((r) => r.candidate)
      .whereType<Candidate>()
      .toList();

  Future<void> _openOutreachSheet(
    List<Member> participants, {
    String? kind,
    String? channel,
    String? status,
    String? titleSuggestion,
  }) async {
    final geo = _selectedGeo();
    final saved = await OrganizingToolkitSheet.show(
      context,
      counties: geo.counties,
      congressionalDistricts: geo.cds,
      senateDistricts: geo.sds,
      houseDistricts: geo.hds,
      candidates: _selectedCandidates(),
      participants: participants,
      kind: kind,
      channel: channel,
      status: status,
      titleSuggestion: titleSuggestion,
    );
    // A save landed → new dots and counts must appear. Re-run the one query.
    if (saved == true) await _loadActivityCoverage();
  }

  /// Post-send prompt: offer to record the just-completed bulk send as a
  /// completed activity, prefilled with its channel and recipients.
  void _offerLogIt(List<Member> participants,
      {required String kind, required String channel}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Save this as a completed activity?'),
      action: SnackBarAction(
        label: 'Save it',
        onPressed: () => _openOutreachSheet(
          participants,
          kind: kind,
          channel: channel,
          status: 'completed',
        ),
      ),
    ));
  }

  // ── Search hits ────────────────────────────────────────────────
  List<RegionSearchHit> _allSearchHits() {
    final out = <RegionSearchHit>[];
    for (final r in _regions[MapMode.county] ?? const <RegionData>[]) {
      out.add(RegionSearchHit(
          mode: MapMode.county, id: r.id, label: '${r.id} County'));
    }
    for (final r in _regions[MapMode.congressional] ?? const <RegionData>[]) {
      out.add(RegionSearchHit(
          mode: MapMode.congressional, id: r.id, label: 'CD ${r.id}'));
    }
    for (final r in _regions[MapMode.senate] ?? const <RegionData>[]) {
      out.add(
          RegionSearchHit(mode: MapMode.senate, id: r.id, label: 'SD ${r.id}'));
    }
    for (final r in _regions[MapMode.house] ?? const <RegionData>[]) {
      out.add(
          RegionSearchHit(mode: MapMode.house, id: r.id, label: 'HD ${r.id}'));
    }
    return out;
  }

  void _onSearchPick(RegionSearchHit hit) {
    _selectRegion(hit.mode, hit.id);
  }

  // ── Choropleth binning ─────────────────────────────────────────
  List<int> _computeQuantileCuts(List<int> counts) {
    final sorted = [...counts]..sort();
    if (sorted.isEmpty) return const [1, 2, 3, 4];
    int q(double p) {
      final idx = ((sorted.length - 1) * p).round().clamp(0, sorted.length - 1);
      return sorted[idx];
    }
    return [q(0.2), q(0.4), q(0.6), q(0.8)];
  }

  int _choroplethBin(MapMode mode, int count) {
    final cuts = _choroplethCuts[mode] ?? const [1, 2, 3, 4];
    var bin = 0;
    for (final c in cuts) {
      if (count > c) bin++;
    }
    return bin.clamp(0, 4);
  }

  // ── Activity presence ──────────────────────────────────────────
  /// ONE query for planned/in_progress activities, bucketed client-side into a
  /// per-mode set of region ids: each activity's geo array is added to the set
  /// for that mode (county→counties, congressional→congressional_districts,
  /// house→house_districts, senate→senate_districts). The raw list is cached so
  /// the selected-region count is computed without re-querying. Handles the
  /// repo not being ready / an empty result as empty sets, never a crash.
  Future<void> _loadActivityCoverage() async {
    List<OutreachActivity> activities;
    try {
      activities = await _outreach.listActivities(
        statuses: const ['planned', 'in_progress'],
      );
    } catch (e) {
      debugPrint('CandidateVolunteersMap activity coverage load failed: $e');
      activities = const [];
    }

    final buckets = <MapMode, Set<String>>{
      for (final m in MapMode.values) m: <String>{},
    };
    for (final a in activities) {
      buckets[MapMode.county]!.addAll(a.counties);
      buckets[MapMode.congressional]!.addAll(a.congressionalDistricts);
      buckets[MapMode.house]!.addAll(a.houseDistricts);
      buckets[MapMode.senate]!.addAll(a.senateDistricts);
    }

    if (!mounted) return;
    setState(() {
      _activities = activities;
      for (final m in MapMode.values) {
        _regionsWithActivity[m] = buckets[m]!;
      }
    });
  }

  /// Highlight centroid dots for regions in the CURRENT mode that carry at least one
  /// planned/in_progress activity. Non-interactive: wrapped in [IgnorePointer]
  /// so a tap on a dot still falls through to region selection. Recomputed on
  /// build, so a mode change re-derives the visible set from `_mode`.
  List<Marker> _activityMarkers() {
    final ids = _regionsWithActivity[_mode] ?? const <String>{};
    if (ids.isEmpty) return const [];
    final index = _index[_mode] ?? const <String, RegionData>{};
    final markers = <Marker>[];
    for (final id in ids) {
      final region = index[id];
      if (region == null) continue;
      markers.add(Marker(
        point: region.centroid,
        width: 16,
        height: 16,
        child: const IgnorePointer(child: _ActivityDot()),
      ));
    }
    return markers;
  }

  /// Count of loaded planned/in_progress activities whose geo array for the
  /// current mode contains [_selectedId]. Read from the cached list, no query.
  int _activityCountForSelected() {
    final id = _selectedId;
    if (id == null) return 0;
    var n = 0;
    for (final a in _activities) {
      final List<String> geo;
      switch (_mode) {
        case MapMode.county:
          geo = a.counties;
          break;
        case MapMode.congressional:
          geo = a.congressionalDistricts;
          break;
        case MapMode.house:
          geo = a.houseDistricts;
          break;
        case MapMode.senate:
          geo = a.senateDistricts;
          break;
      }
      if (geo.contains(id)) n++;
    }
    return n;
  }

  // ── Build ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final layout = LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= _kDesktopBreakpoint;
        if (isDesktop) return _desktopLayout(context);
        return _mobileLayout(context);
      },
    );

    // Esc returns to the statewide view when a region is selected.
    final content = CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_selectedId != null) _clearSelection();
        },
      },
      child: Focus(autofocus: true, child: layout),
    );

    if (widget.height != null && widget.height!.isFinite) {
      return SizedBox(height: widget.height, child: content);
    }
    return content;
  }

  Widget _desktopLayout(BuildContext context) {
    // Statewide landing: full-width map + overview rail.
    if (_selectedId == null) {
      return Row(
        children: [
          Expanded(child: _mapStack(context)),
          _paneDivider(),
          SizedBox(
            width: _kPanelWidth,
            child: _buildPanel(context,
                pane: VolunteersPane.statewide, showClose: false),
          ),
        ],
      );
    }

    // Region war room: Candidates | Map | Members.
    return LayoutBuilder(builder: (context, constraints) {
      // Candidates pane was pinned to 320px, which clipped every real full
      // name even on wide desktops. Make it responsive like the members pane
      // (a touch narrower so the map keeps room) with a 360px floor.
      final candidatesWidth = (constraints.maxWidth * 0.22).clamp(360.0, 420.0);
      final membersWidth = (constraints.maxWidth * 0.24).clamp(360.0, 440.0);
      return Row(
        children: [
          SizedBox(
            width: candidatesWidth,
            child: _buildPanel(context,
                pane: VolunteersPane.candidates, showClose: false),
          ),
          _paneDivider(),
          Expanded(child: _mapStack(context)),
          _paneDivider(),
          SizedBox(
            width: membersWidth,
            child: _buildPanel(context,
                pane: VolunteersPane.members, showClose: false),
          ),
        ],
      );
    });
  }

  Widget _paneDivider() => Container(width: 1, color: _vt.divider);

  Widget _mobileLayout(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: _mapStack(context)),
        if (_selectedId != null)
          DraggableScrollableSheet(
            initialChildSize: 0.35,
            minChildSize: 0.2,
            maxChildSize: 0.95,
            snap: true,
            snapSizes: const [0.35, 0.7, 0.95],
            builder: (context, scrollController) {
              return _MobileSheet(
                child: _buildPanel(
                  context,
                  pane: VolunteersPane.combined,
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
    required VolunteersPane pane,
    bool showClose = false,
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
        members: _selectedMembers,
        candidateGroups: _selectedGroups,
        loadingCandidates: _loadingCandidates,
        loadingMembers: _loadingMembers,
      );
    }
    return VolunteersDetailPanel(
      detail: detail,
      pane: pane,
      statewideMembers: _statewideMembers,
      statewideYoungDems: _statewideYoungDems,
      statewideNominees: _geLookup.length,
      hotRegions: _hotRegions(),
      upcomingActivities: _upcomingActivities(),
      organizingPlays: _organizingPlays(),
      onOpenActivities: widget.onOpenActivities,
      onHighlightYoungDems: _highlightYoungDems,
      onClose: _clearSelection,
      onSelectHot: _selectRegion,
      onTextMembers: _textMembers,
      onEmailMembers: _emailMembers,
      onLogOutreach:
          _selectedId == null ? null : (members) => _openOutreachSheet(members),
      scrollController: scrollController,
      showCloseButton: showClose,
    );
  }

  /// The next up-to-3 planned activities across every geography, soonest first.
  /// Drawn from the already-loaded `_activities` (planned + in_progress); we
  /// keep only `planned` with a real date so the rail shows what is coming up.
  List<OutreachActivity> _upcomingActivities() {
    final planned = _activities
        .where((a) => a.status == 'planned' && a.scheduledOn != null)
        .toList()
      ..sort((a, b) => a.scheduledOn!.compareTo(b.scheduledOn!));
    return planned.take(3).toList();
  }

  /// Switch to the district geography that carries the most young-dem regions
  /// and let the pulse rings draw attention to their pins. Called by the rail's
  /// "young dems on the November ballot" tile.
  void _highlightYoungDems() {
    MapMode? best;
    var bestCount = 0;
    for (final mode in [
      MapMode.congressional,
      MapMode.senate,
      MapMode.house,
    ]) {
      final n = (_regions[mode] ?? const <RegionData>[])
          .where((r) => r.status == RegionStatus.youngDem)
          .length;
      if (n > bestCount) {
        bestCount = n;
        best = mode;
      }
    }
    if (best != null) _changeMode(best);
  }

  /// Real Candidate profiles tied to a district (for seeding a play's sheet).
  List<Candidate> _nomineeCandidates(String officeType, String id) =>
      _rowsForDistrict(officeType, id)
          .map((r) => r.candidate)
          .whereType<Candidate>()
          .toList();

  /// Open the toolkit sheet pre-seeded for a single region + nominee, from an
  /// Organizing Play card. Reloads activity coverage on save so the new dots
  /// and "this week" rows appear.
  Future<void> _startPlay({
    required MapMode mode,
    required String id,
    required String kind,
    required String title,
    List<Candidate> candidates = const [],
  }) async {
    final saved = await OrganizingToolkitSheet.show(
      context,
      counties: mode == MapMode.county ? [id] : const [],
      congressionalDistricts: mode == MapMode.congressional ? [id] : const [],
      senateDistricts: mode == MapMode.senate ? [id] : const [],
      houseDistricts: mode == MapMode.house ? [id] : const [],
      candidates: candidates,
      participants: const [],
      kind: kind,
      titleSuggestion: title,
    );
    if (saved == true) await _loadActivityCoverage();
  }

  /// Three deterministic organizing ideas computed from data already in memory.
  /// Each is a concrete next action seeded into the toolkit sheet, so the front
  /// door always offers something to plan even with zero activities logged.
  List<OrganizingPlay> _organizingPlays() {
    final plays = <OrganizingPlay>[];

    // 1) Rally for a young dem — top young-dem district by member count.
    RegionData? topYoungDem;
    MapMode? topYoungDemMode;
    for (final mode in [
      MapMode.congressional,
      MapMode.senate,
      MapMode.house,
    ]) {
      for (final r in _regions[mode] ?? const <RegionData>[]) {
        if (r.status != RegionStatus.youngDem) continue;
        if (topYoungDem == null || r.memberCount > topYoungDem.memberCount) {
          topYoungDem = r;
          topYoungDemMode = mode;
        }
      }
    }
    if (topYoungDem != null && topYoungDemMode != null) {
      final region = topYoungDemMode.regionTitle(topYoungDem.id);
      final ot = topYoungDemMode.officeType!;
      plays.add(OrganizingPlay(
        icon: OutreachDisplay.kindIcon('day_of_action'),
        title: 'Rally for a young dem',
        rationale:
            'A young Democrat is on the ballot in $region, home to ${topYoungDem.memberCount} members.',
        onStart: () => _startPlay(
          mode: topYoungDemMode!,
          id: topYoungDem!.id,
          kind: 'day_of_action',
          title: 'Day of action in $region',
          candidates: _nomineeCandidates(ot, topYoungDem.id),
        ),
      ));
    }

    // 2) Wake a quiet region — highest-member county with nothing planned.
    final withActivity = _regionsWithActivity[MapMode.county] ?? const <String>{};
    RegionData? quiet;
    for (final r in _regions[MapMode.county] ?? const <RegionData>[]) {
      if (withActivity.contains(r.id)) continue;
      if (quiet == null || r.memberCount > quiet.memberCount) quiet = r;
    }
    if (quiet != null && quiet.memberCount > 0) {
      final region = MapMode.county.regionTitle(quiet.id);
      plays.add(OrganizingPlay(
        icon: OutreachDisplay.kindIcon('volunteer_day'),
        title: 'Wake a quiet region',
        rationale:
            '${quiet.memberCount} members live in $region and nothing is planned yet.',
        onStart: () => _startPlay(
          mode: MapMode.county,
          id: quiet!.id,
          kind: 'volunteer_day',
          title: 'Meet-up in $region',
        ),
      ));
    }

    // 3) Text bank for the ticket — a contested Dem race with 5+ members.
    RegionData? contested;
    MapMode? contestedMode;
    for (final mode in [
      MapMode.congressional,
      MapMode.senate,
      MapMode.house,
    ]) {
      for (final r in _regions[mode] ?? const <RegionData>[]) {
        final ok = (r.status == RegionStatus.demContested ||
                r.status == RegionStatus.youngDem) &&
            r.memberCount >= 5;
        if (!ok) continue;
        if (contested == null || r.memberCount > contested.memberCount) {
          contested = r;
          contestedMode = mode;
        }
      }
    }
    if (contested != null && contestedMode != null) {
      final region = contestedMode.regionTitle(contested.id);
      final ot = contestedMode.officeType!;
      final nominees = _nomineeCandidates(ot, contested.id);
      final who = nominees.isNotEmpty ? nominees.first.name : region;
      plays.add(OrganizingPlay(
        icon: OutreachDisplay.kindIcon('text_bank'),
        title: 'Text bank for the ticket',
        rationale:
            '$region has a contested Democratic race and ${contested.memberCount} members ready to help.',
        onStart: () => _startPlay(
          mode: contestedMode!,
          id: contested!.id,
          kind: 'text_bank',
          title: 'Text bank for $who',
          candidates: nominees,
        ),
      ));
    }

    return plays;
  }

  List<HotRegion> _hotRegions() {
    final regions = [..._activeRegions];
    regions.sort((a, b) {
      final ay = a.status == RegionStatus.youngDem ? 1 : 0;
      final by = b.status == RegionStatus.youngDem ? 1 : 0;
      if (ay != by) return by - ay;
      return b.memberCount.compareTo(a.memberCount);
    });
    // Defensive de-dup: even with the St. Louis City geoid split, never let two
    // rows share an id (a re-parse or a future collision would otherwise show a
    // region twice with the same count).
    final seen = <String>{};
    final out = <HotRegion>[];
    for (final r in regions) {
      if (!seen.add(r.id)) continue;
      out.add(HotRegion(
          mode: _mode, id: r.id, memberCount: r.memberCount, status: r.status));
      if (out.length == 5) break;
    }
    return out;
  }

  // ── Map + floating chrome ──────────────────────────────────────
  Widget _mapStack(BuildContext context) {
    final dark = _isDark;
    final vt = _vt;
    if (_loadingBase && _activeRegions.isEmpty) {
      return Container(
        color: vt.mask,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: vt.accent, strokeWidth: 2.5),
              const SizedBox(height: 14),
              Text('Loading the field map…',
                  style: TextStyle(color: vt.secondary, fontSize: 13)),
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
              child: _buildFlutterMap(reduceMotion, dark),
            ),
          ),

          // top-left: back-to-statewide pill (only while a region is selected)
          if (_selectedId != null)
            Positioned(
              left: 16,
              top: 16,
              child: _backToStatewidePill(),
            ),

          // top-left: mode switch (shifts below the back pill when selecting)
          Positioned(
            left: 16,
            top: _selectedId != null ? 64 : 16,
            child: _modeSwitcher(),
          ),

          // top-right: search
          Positioned(
            right: 16,
            top: 16,
            width: 300,
            child: _RegionSearchField(
              hits: _allSearchHits(),
              onPick: _onSearchPick,
            ),
          ),

          // top-center: region title lockup + "n activities here" chip
          if (_selectedId != null)
            Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Center(child: _regionTitleLockup(dark)),
            ),

          // bottom-left: member-density legend
          Positioned(
            left: 16,
            bottom: 16,
            child: _glass(
              radius: 12,
              child: ChoroplethLegend(
                minCount: (_memberRange[_mode] ?? const [0, 0])[0],
                maxCount: (_memberRange[_mode] ?? const [0, 0])[1],
              ),
            ),
          ),

          // bottom-right: zoom
          Positioned(right: 16, bottom: 16, child: _zoomCluster()),

          // hover tooltip
          if (_hoveredId != null) _hoverTooltip(),
        ],
      ),
    );
  }

  Widget _buildFlutterMap(bool reduceMotion, bool dark) {
    final vt = _vt;
    final maskColor = vt.mask;
    final polygons = <Polygon>[];

    // The state silhouette is formed by the region polygons themselves — there
    // is no separate outline or out-of-state mask polygon. The old coarse
    // 60-point outline asset cut gold chords across the fills and the donut
    // mask painted maskColor over maskColor, so both are gone. A slightly
    // firmer region border gives the state edge its definition instead.

    // 1) Region choropleth fills.
    final selecting = _selectedId != null;
    final borderBase = vt.divider;
    for (final r in _activeRegions) {
      final hovered = _hoveredId == r.id && _selectedId != r.id;
      polygons.add(Polygon(
        points: r.outerRing,
        holePointsList: r.holes,
        color: _fillFor(r, vt, selecting),
        borderColor: hovered ? vt.accent : borderBase,
        borderStrokeWidth: hovered ? 1.5 : 0.8,
      ));
    }

    // 2) Selection: onSurface halo under a 3px accent ring.
    final sel = _selectedId == null ? null : _index[_mode]?[_selectedId];
    if (sel != null) {
      polygons.add(Polygon(
        points: sel.outerRing,
        holePointsList: sel.holes,
        color: Colors.transparent,
        borderColor: vt.text.withValues(alpha: 0.4),
        borderStrokeWidth: 5,
      ));
      polygons.add(Polygon(
        points: sel.outerRing,
        holePointsList: sel.holes,
        color: Colors.transparent,
        borderColor: vt.accent,
        borderStrokeWidth: 3,
      ));
    }

    return FlutterMap(
      mapController: _mapController,
      options: moMapOptions(
        center: _moCenter,
        zoom: _initialZoom,
        backgroundColor: maskColor,
        onTap: (_, latLng) => _onMapTapLatLng(latLng),
      ),
      children: [
        // No tile basemap: Missouri renders as a branded infographic on the
        // solid canvas (backgroundColor), so no out-of-state tiles can ever
        // bleed through around the state.
        PolygonLayer(polygons: polygons, polygonCulling: true),
        MarkerLayer(markers: _youngDemMarkers(reduceMotion)),
        // Activity presence: highlight dots on regions with a planned/
        // in_progress activity in the current mode, statewide and in-region.
        MarkerLayer(markers: _activityMarkers()),
      ],
    );
  }

  Color _fillFor(RegionData r, VolunteersTheme vt, bool selecting) {
    final bin = _choroplethBin(_mode, r.memberCount);
    Color base = vt.choropleth(bin);
    if (selecting && _selectedId != r.id) {
      base = base.withValues(alpha: base.a * 0.6);
    }
    return base;
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
                              color: _vt.highlight
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

  Widget _staticPin(String id) {
    final vt = _vt;
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: vt.highlightSoft,
        border: Border.all(color: vt.surface, width: 2),
        boxShadow: [
          BoxShadow(
              color: vt.highlight.withValues(alpha: 0.5),
              blurRadius: 8,
              spreadRadius: 1),
        ],
      ),
      child: Icon(Icons.star_rounded, color: vt.onHighlightSoft, size: 16),
    );
  }

  // ── Back-to-statewide pill (accent fill, onAccent content, both themes) ─
  Widget _backToStatewidePill() {
    final vt = _vt;
    return Semantics(
      button: true,
      label: 'Back to Missouri statewide',
      excludeSemantics: true,
      child: Material(
        color: vt.accent,
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: _clearSelection,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                  color: vt.onAccent.withValues(alpha: 0.18), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back_rounded, size: 16, color: vt.onAccent),
                const SizedBox(width: 6),
                Text('Missouri',
                    style: TextStyle(
                        color: vt.onAccent,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Mode switcher (segmented pill, unityBlue active) ────────────
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
                    color: _vt.accent,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                          color: _vt.accent.withValues(alpha: 0.30),
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
    final vt = _vt;
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
                    color: selected ? vt.onAccent : vt.secondary,
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
                            ? vt.onAccent.withValues(alpha: 0.85)
                            : vt.accent,
                      )),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

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
            child: Icon(icon, size: 20, color: _vt.text),
          ),
        ),
      ),
    );
  }

  // ── Hover tooltip ──────────────────────────────────────────────
  Widget _hoverTooltip() {
    final vt = _vt;
    final r = _index[_mode]?[_hoveredId];
    if (r == null) return const SizedBox.shrink();
    final line =
        '${r.memberCount} member${r.memberCount == 1 ? '' : 's'}';
    final youngDem = r.status == RegionStatus.youngDem;
    return Positioned(
      left: 16,
      top: _selectedId != null ? 116 : 68,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: vt.inverseSurface.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(10),
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
                  style: TextStyle(
                      color: vt.onInverseSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (youngDem) ...[
                    // Paint on the inverseSurface tooltip: use the guaranteed
                    // contrasting onInverseSurface role, not scheme.tertiary
                    // (vt.highlight), which washes out on a light dark-mode
                    // inverseSurface.
                    Icon(Icons.star_rounded,
                        size: 12, color: vt.onInverseSurface),
                    const SizedBox(width: 4),
                  ],
                  Text(line,
                      style: TextStyle(
                          color: vt.onInverseSurface.withValues(alpha: 0.82),
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Region title lockup (top-center, selected) ─────────────────
  /// Translucent lockup over the map: overline + region title, plus a
  /// highlight-tinted "n activities here" chip when n > 0. Wrapped in
  /// [IgnorePointer] so it never swallows a map tap. Both themes clear 4.5:1
  /// (onSurface title on the glass surface; onTertiaryContainer chip text on
  /// the tertiaryContainer chip).
  Widget _regionTitleLockup(bool dark) {
    final vt = _vt;
    final id = _selectedId;
    if (id == null) return const SizedBox.shrink();
    final n = _activityCountForSelected();
    return IgnorePointer(
      child: _glass(
        radius: 12,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_mode.overline,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: vt.secondary,
                  )),
              const SizedBox(height: 2),
              Text(_mode.regionTitle(id),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: vt.text,
                  )),
              if (n > 0) ...[
                const SizedBox(height: 6),
                _activityChip(n, vt),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _activityChip(int n, VolunteersTheme vt) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: vt.highlightSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
                shape: BoxShape.circle, color: vt.onHighlightSoft),
          ),
          const SizedBox(width: 6),
          Text('$n ${n == 1 ? 'activity' : 'activities'} here',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: vt.onHighlightSoft,
              )),
        ],
      ),
    );
  }

  // ── Glass chrome helper ────────────────────────────────────────
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  VolunteersTheme get _vt => VolunteersTheme.of(context);

  Widget _glass({required double radius, required Widget child}) {
    final vt = _vt;
    final bg = vt.surface.withValues(alpha: 0.90);
    final border = vt.divider;
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

// ═══════════════════════════════════════════════════════════════
//  CHOROPLETH LEGEND — bottom-left member-density scale.
//  Five swatches from the active theme ramp + "Members" label + min/max.
// ═══════════════════════════════════════════════════════════════
class ChoroplethLegend extends StatelessWidget {
  const ChoroplethLegend({
    super.key,
    required this.minCount,
    required this.maxCount,
  });

  final int minCount;
  final int maxCount;

  @override
  Widget build(BuildContext context) {
    final vt = VolunteersTheme.of(context);
    final title = vt.secondary;
    final micro = vt.secondary.withValues(alpha: 0.75);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('MEMBERS',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: title,
              )),
          const SizedBox(height: 8),
          SizedBox(
            width: 160,
            height: 10,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Row(
                children: [
                  for (var bin = 0; bin < 5; bin++)
                    Expanded(
                      child: Container(color: vt.choropleth(bin)),
                    ),
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
                Text('$minCount',
                    style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w600, color: micro)),
                Text('$maxCount',
                    style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w600, color: micro)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  REGION SEARCH — Autocomplete over the loaded regions, all four modes.
//  County names + synthetic "CD 3"/"HD 42"/"SD 15" labels. No network.
// ═══════════════════════════════════════════════════════════════
class _RegionSearchField extends StatelessWidget {
  const _RegionSearchField({
    required this.hits,
    required this.onPick,
  });

  final List<RegionSearchHit> hits;
  final void Function(RegionSearchHit) onPick;

  @override
  Widget build(BuildContext context) {
    final vt = VolunteersTheme.of(context);
    final fieldText = vt.text;
    final hintColor = vt.secondary;
    final panelBg = vt.surface;

    return Autocomplete<RegionSearchHit>(
      displayStringForOption: (h) => h.label,
      optionsBuilder: (TextEditingValue value) {
        final q = value.text.trim().toLowerCase();
        if (q.isEmpty) return const Iterable<RegionSearchHit>.empty();
        final matches =
            hits.where((h) => h.label.toLowerCase().contains(q)).toList();
        matches.sort((a, b) {
          final ap = a.label.toLowerCase().startsWith(q) ? 0 : 1;
          final bp = b.label.toLowerCase().startsWith(q) ? 0 : 1;
          if (ap != bp) return ap - bp;
          if (a.mode.index != b.mode.index) {
            return a.mode.index.compareTo(b.mode.index);
          }
          return a.label.compareTo(b.label);
        });
        return matches.take(8);
      },
      onSelected: onPick,
      fieldViewBuilder: (context, controller, focusNode, onSubmit) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: vt.surface.withValues(alpha: 0.90),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: vt.divider, width: 1),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(Icons.search, size: 18, color: vt.secondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      onSubmitted: (_) => onSubmit(),
                      style: TextStyle(fontSize: 13.5, color: fieldText),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: 'Jump to a district or county…',
                        hintStyle:
                            TextStyle(fontSize: 13, color: hintColor),
                      ),
                    ),
                  ),
                  if (controller.text.isNotEmpty)
                    GestureDetector(
                      onTap: () => controller.clear(),
                      child: Icon(Icons.close,
                          size: 16,
                          color: vt.secondary.withValues(alpha: 0.75)),
                    ),
                ],
              ),
            ),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final list = options.toList();
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 300,
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                color: panelBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: vt.divider, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final o = list[i];
                  final showGroup = i == 0 || list[i - 1].group != o.group;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (showGroup)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                          child: Text(o.group,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                color: vt.secondary.withValues(alpha: 0.85),
                              )),
                        ),
                      InkWell(
                        onTap: () => onSelected(o),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 9),
                          child: Text(o.label,
                              style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: fieldText)),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
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
    final vt = VolunteersTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: vt.surface,
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
              color: vt.divider,
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

/// Activity-presence dot dropped on a region centroid. Filled with the
/// highlight role, a thin surface ring and a soft shadow so it reads over any
/// choropleth fill in both themes. Purely decorative — the map's tap handling
/// sits above it.
class _ActivityDot extends StatelessWidget {
  const _ActivityDot();

  @override
  Widget build(BuildContext context) {
    final vt = VolunteersTheme.of(context);
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: vt.highlight,
        border: Border.all(color: vt.surface, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 3,
          ),
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
