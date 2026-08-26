import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/models/crm/candidate.dart' show Candidate;
import 'package:bluebubbles/services/crm/election_results_repository.dart';

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
        // An id that already carries "City" (e.g. St. Louis City, an
        // independent city keyed off geoid 29510) is a full region name on
        // its own — never suffix it into "St. Louis City County".
        return id.endsWith('City') ? id : '$id County';
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

/// Candidate status for a district's November race. `none` covers counties
/// (no ballot) and districts with no 2026 race at all.
enum RegionStatus { youngDem, demContested, demUnopposed, noDem, notOnBallot }

/// Palette pulled straight from the design spec, keyed to [BrandColors].
class MapPalette {
  MapPalette._();

  static const Color unityBlue = BrandColors.unityBlue; // #273351
  static const Color momentumBlue = BrandColors.momentumBlue; // #32A6DE
  static const Color sunriseGold = BrandColors.sunriseGold; // #FDB813

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

  // Deterministic avatar backgrounds (navy family). Every entry keeps white
  // initials at >= 4.5:1 (the old #32A6DE / #4682B4 / #5A7FA3 fell short, so
  // they are darkened to same-hue equivalents).
  static const List<Color> avatarColors = [
    Color(0xFF273351),
    Color(0xFF16708F),
    Color(0xFF1F5FA0),
    Color(0xFF38678F),
    Color(0xFF46647F),
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

  /// NOTE: the detail panel intercepts [RegionStatus.youngDem] and paints it
  /// with the theme highlight (scheme.tertiary) BEFORE consulting this, so the
  /// gold constant below never renders in the volunteers area.
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
        return 'Dem on ballot, contested';
      case RegionStatus.demUnopposed:
        return 'Dem unopposed';
      case RegionStatus.noDem:
        return 'No Dem filed';
      case RegionStatus.notOnBallot:
        return 'Not on the November ballot';
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

/// Padded Missouri bounding box. Used both to constrain the camera
/// ([moMapOptions]) and to size the out-of-state donut mask.
final LatLngBounds moBounds = LatLngBounds(
  const LatLng(35.85, -95.95), // padded SW (MO true SW ≈ 35.9957, -95.7747)
  const LatLng(40.75, -88.95), // padded NE (MO true NE ≈ 40.6136, -89.0988)
);

/// Shared camera helper. Both map widgets pass their own center/zoom and the
/// theme-matched background color; the constraint and min/max zoom are fixed so
/// the map can never wander into Kansas or Illinois.
MapOptions moMapOptions({
  required LatLng center,
  required double zoom,
  required Color backgroundColor,
  void Function(TapPosition, LatLng)? onTap,
  InteractionOptions interaction =
      const InteractionOptions(flags: InteractiveFlag.all),
}) =>
    MapOptions(
      initialCenter: center,
      initialZoom: zoom,
      // Fit Missouri to the viewport on open so the state FILLS the frame
      // instead of floating tiny in a void. containCenter keeps it framed
      // (center can't leave MO) without the constraint fighting the fit the
      // way `contain` does on a wide screen.
      initialCameraFit: CameraFit.bounds(
        bounds: moBounds,
        padding: const EdgeInsets.all(16),
      ),
      minZoom: 5.5,
      maxZoom: 12.0,
      cameraConstraint: CameraConstraint.containCenter(bounds: moBounds),
      interactionOptions: interaction,
      // Native flutter_map tap: hands us the tapped LatLng directly, so region
      // selection never depends on a fragile GestureDetector/pointToLatLng path.
      onTap: onTap,
      backgroundColor: backgroundColor,
    );

/// A single "Jump to" autocomplete hit: a county name or a synthetic district
/// label ("CD 3", "HD 42", "SD 15"). Data comes from the loaded regions, never
/// the network.
class RegionSearchHit {
  const RegionSearchHit({
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

  @override
  String toString() => label;
}

/// One candidate line in a region's detail panel.
///
/// A [result]-backed row that also resolves to a [candidate] renders the
/// candidate photo and taps through to their profile. A result with no matched
/// candidate renders initials-only and is NOT tappable — never fabricate a
/// profile. [isNominee] flags the party-colored NOMINEE badge (derivable from
/// `ElectionResult.advanced`).
class CandidateDisplayRow {
  const CandidateDisplayRow({
    this.result,
    this.candidate,
    this.isNominee = false,
  });

  final ElectionResult? result;
  final Candidate? candidate;
  final bool isNominee;

  /// True when this row resolves to a full candidate profile and can navigate.
  bool get tappable => candidate != null;
}

/// A group of candidate rows sharing an office type, e.g. all Congressional
/// candidates for the districts that overlap a county. [districtChips] carries
/// the "CD 3", "HD 42" labels shown in the group header.
class CandidateDisplayGroup {
  const CandidateDisplayGroup({
    required this.officeTypeLabel,
    this.districtChips = const <String>[],
    this.rows = const <CandidateDisplayRow>[],
  });

  final String officeTypeLabel;
  final List<String> districtChips;
  final List<CandidateDisplayRow> rows;
}
