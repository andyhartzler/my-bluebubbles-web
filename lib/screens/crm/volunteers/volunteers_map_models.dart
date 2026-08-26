import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';

// ═══════════════════════════════════════════════════════════════
//  MODELS + COLOR LOGIC for the Candidate Volunteers "War Room" map.
//  Pure data + palette. No widgets, no I/O.
// ═══════════════════════════════════════════════════════════════

/// The four geographies the map can display.
enum MapMode { county, congressional, house, senate }

extension MapModeInfo on MapMode {
  /// GeoJSON asset for this geography.
  String get geoJsonPath {
    switch (this) {
      case MapMode.county:
        return 'assets/geojson/mo_counties.geojson';
      case MapMode.congressional:
        return 'assets/geojson/mo_congressional_districts.geojson';
      case MapMode.house:
        return 'assets/geojson/mo_house_districts.geojson';
      case MapMode.senate:
        return 'assets/geojson/mo_senate_districts.geojson';
    }
  }

  /// GeoJSON property that carries the region id.
  /// Counties key on `county`; districts on `district`.
  String get idProperty => this == MapMode.county ? 'county' : 'district';

  /// Field for `MemberRepository.getMemberCountsByField`.
  String get memberField {
    switch (this) {
      case MapMode.county:
        return 'county';
      case MapMode.congressional:
        return 'congressional_district';
      case MapMode.house:
        return 'house_district';
      case MapMode.senate:
        return 'senate_district';
    }
  }

  /// `ElectionResult.officeType` / `GeNominee.kind` for this mode, or null for
  /// counties (which are not a ballot unit and carry no candidate).
  String? get officeType {
    switch (this) {
      case MapMode.county:
        return null;
      case MapMode.congressional:
        return 'congressional';
      case MapMode.house:
        return 'house';
      case MapMode.senate:
        return 'senate';
    }
  }

  String get segmentLabel {
    switch (this) {
      case MapMode.county:
        return 'County';
      case MapMode.congressional:
        return 'Congress';
      case MapMode.house:
        return 'MO House';
      case MapMode.senate:
        return 'MO Senate';
    }
  }

  /// Uppercase overline label shown in the detail header.
  String get overline {
    switch (this) {
      case MapMode.county:
        return 'COUNTY';
      case MapMode.congressional:
        return 'CONGRESSIONAL DISTRICT';
      case MapMode.house:
        return 'MO HOUSE DISTRICT';
      case MapMode.senate:
        return 'MO SENATE DISTRICT';
    }
  }

  /// How the region name is presented in a title.
  String regionTitle(String id) {
    switch (this) {
      case MapMode.county:
        return '$id County';
      case MapMode.congressional:
        return 'Congressional District $id';
      case MapMode.house:
        return 'House District $id';
      case MapMode.senate:
        return 'Senate District $id';
    }
  }

  bool get isDistrict => this != MapMode.county;
}

/// The two choropleth lenses.
enum MapLens { members, candidates }

/// Candidate status for a district's November race. `none` covers counties
/// (no ballot) and districts with no 2026 race at all.
enum RegionStatus { youngDem, demContested, demUnopposed, noDem, notOnBallot }

/// Palette pulled straight from the design spec, keyed to [BrandColors].
class MapPalette {
  MapPalette._();

  static const Color unityBlue = BrandColors.unityBlue; // #273351
  static const Color momentumBlue = BrandColors.momentumBlue; // #32A6DE
  static const Color sunriseGold = BrandColors.sunriseGold; // #FDB813

  // Member-density sequential ramp (6 stops).
  static const Color density0 = Color(0xFFEAEEF3);
  static const Color density1 = Color(0xFFBFE0F4);
  static const Color density2 = Color(0xFF7FC4EA);
  static const Color density3 = Color(0xFF32A6DE);
  static const Color density4 = Color(0xFF1F6FA8);
  static const Color density5 = Color(0xFF273351);

  static const List<Color> densityStops = [
    density0,
    density1,
    density2,
    density3,
    density4,
    density5,
  ];

  static const List<String> densityLabels = [
    '0',
    '1-2',
    '3-5',
    '6-10',
    '11-25',
    '26+',
  ];

  // Candidate-status categorical (colourblind-aware, no green).
  static const Color statusYoungDem = sunriseGold;
  static const Color statusDemContested = momentumBlue;
  static const Color statusDemUnopposed = Color(0xFF1F5FA0);
  static const Color statusNoDem = Color(0xFFD98A82);
  static const Color statusNa = Color(0xFFE3E7EE);

  // Party chip letter backgrounds.
  static const Color partyD = Color(0xFF1D4ED8);
  static const Color partyR = Color(0xFFC62828);
  static const Color partyL = Color(0xFFB45309);
  static const Color partyG = Color(0xFF2E7D32);
  static const Color partyOther = Color(0xFF546E7A);

  // Deterministic avatar backgrounds (navy family).
  static const List<Color> avatarColors = [
    Color(0xFF273351),
    Color(0xFF32A6DE),
    Color(0xFF1F5FA0),
    Color(0xFF4682B4),
    Color(0xFF5A7FA3),
  ];

  static Color partyChipColor(String partyShort) {
    switch (partyShort.toUpperCase()) {
      case 'D':
        return partyD;
      case 'R':
        return partyR;
      case 'L':
        return partyL;
      case 'G':
        return partyG;
      default:
        return partyOther;
    }
  }

  /// Member-density fill for a raw member count. The empty bin sits at 55%
  /// opacity; every populated bin renders at 72% over the Positron basemap.
  static Color densityFill(int count) {
    if (count <= 0) return density0.withValues(alpha: 0.55);
    if (count <= 2) return density1.withValues(alpha: 0.72);
    if (count <= 5) return density2.withValues(alpha: 0.72);
    if (count <= 10) return density3.withValues(alpha: 0.72);
    if (count <= 25) return density4.withValues(alpha: 0.72);
    return density5.withValues(alpha: 0.72);
  }

  static int densityBin(int count) {
    if (count <= 0) return 0;
    if (count <= 2) return 1;
    if (count <= 5) return 2;
    if (count <= 10) return 3;
    if (count <= 25) return 4;
    return 5;
  }

  static Color statusFill(RegionStatus status) {
    switch (status) {
      case RegionStatus.youngDem:
        return statusYoungDem.withValues(alpha: 0.72);
      case RegionStatus.demContested:
        return statusDemContested.withValues(alpha: 0.72);
      case RegionStatus.demUnopposed:
        return statusDemUnopposed.withValues(alpha: 0.72);
      case RegionStatus.noDem:
        return statusNoDem.withValues(alpha: 0.72);
      case RegionStatus.notOnBallot:
        return statusNa.withValues(alpha: 0.45);
    }
  }

  static Color statusSwatch(RegionStatus status) {
    switch (status) {
      case RegionStatus.youngDem:
        return statusYoungDem;
      case RegionStatus.demContested:
        return statusDemContested;
      case RegionStatus.demUnopposed:
        return statusDemUnopposed;
      case RegionStatus.noDem:
        return statusNoDem;
      case RegionStatus.notOnBallot:
        return statusNa;
    }
  }

  static String statusLabel(RegionStatus status) {
    switch (status) {
      case RegionStatus.youngDem:
        return 'Young Dem on ballot';
      case RegionStatus.demContested:
        return 'Dem — contested';
      case RegionStatus.demUnopposed:
        return 'Dem — unopposed';
      case RegionStatus.noDem:
        return 'No Dem filed';
      case RegionStatus.notOnBallot:
        return 'Not on ballot / NA';
    }
  }

  static Color avatarColorFor(String seed) {
    var hash = 0;
    for (final unit in seed.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return avatarColors[hash % avatarColors.length];
  }
}

/// One region on the map. Geometry is fixed at parse time; [memberCount] and
/// [status] are (re)computed as member and candidate data arrives.
class RegionData {
  RegionData({
    required this.id,
    required this.rings,
    required this.centroid,
  });

  /// County name, or bare-digit district number.
  final String id;

  /// Outer ring first, then any holes.
  final List<List<LatLng>> rings;
  final LatLng centroid;

  int memberCount = 0;
  RegionStatus status = RegionStatus.notOnBallot;

  List<LatLng> get outerRing => rings.first;
  List<List<LatLng>>? get holes => rings.length > 1 ? rings.sublist(1) : null;
}

/// Bare-digit normalisation shared by GeoJSON ids and member-count keys:
/// strip non-digits, then drop leading zeros while keeping at least one digit.
String bareDigits(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return raw.trim();
  final trimmed = digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
  return trimmed.isEmpty ? '0' : trimmed;
}

/// Normalise a candidate/nominee name for cross-source matching.
String normalizeName(String raw) =>
    raw.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');

/// Ray-casting point-in-polygon hit test (matches the proven missouri_map_widget).
bool pointInPolygon(LatLng point, List<LatLng> polygon) {
  var inside = false;
  var j = polygon.length - 1;
  for (var i = 0; i < polygon.length; i++) {
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

/// A single autocomplete entry in the "Jump to" search.
class RegionSearchEntry {
  const RegionSearchEntry({
    required this.mode,
    required this.id,
    required this.label,
  });

  final MapMode mode;
  final String id;
  final String label;

  String get group {
    switch (mode) {
      case MapMode.county:
        return 'COUNTIES';
      case MapMode.congressional:
        return 'CONGRESSIONAL';
      case MapMode.house:
        return 'MO HOUSE';
      case MapMode.senate:
        return 'MO SENATE';
    }
  }
}
