/// Pure-Dart district resolution for the decisions board (no Flutter imports
/// so it stays unit-testable).
///
/// Endorsement submissions carry office + district as loose strings ("MO
/// House 119", "MO HD 3", office "State Representative" + district "119"...).
/// [parseDistrictRef] normalizes them into the exact (office, districtNum)
/// pair `MissouriMapController.zoomToDistrict` routes on: its office match is
/// substring-based ('congress' / 'state senate' / 'house', congressional
/// checked before house), and its GeoJSON district keys have leading zeros
/// stripped, so [mapOffice] / [districtNum] below hit exactly one layer and
/// one polygon.
class DistrictRef {
  /// Fed to `MissouriMapController.zoomToDistrict(office:)`.
  final String mapOffice;

  /// Canonical digits, no leading zeros (matches the parsed GeoJSON keys).
  final String districtNum;

  /// Compact chip label: 'HD 119' | 'SD 3' | 'CD 2'.
  final String shortLabel;

  const DistrictRef(this.mapOffice, this.districtNum, this.shortLabel);
}

/// Parse a chamber + district number out of the raw office/district strings.
///
/// Returns null for statewide / local / judicial offices (no district
/// polygon exists, and guessing the map's house fallback would zoom to a
/// wrong district): callers render plain office text instead of a chip.
DistrictRef? parseDistrictRef({String? office, String? district}) {
  final blob = '${office ?? ''} ${district ?? ''}'.toLowerCase();
  // Number: LAST run of digits, district string first, then the blob
  // (strings like 'mo house 119' put the district last).
  final m = RegExp(r'(\d{1,3})(?!.*\d)').firstMatch(district ?? '') ??
      RegExp(r'(\d{1,3})(?!.*\d)').firstMatch(blob);
  if (m == null) return null;
  final n = int.parse(m.group(1)!).toString(); // strips leading zeros
  bool has(String p) => RegExp(p).hasMatch(blob);
  // Congressional FIRST so 'u.s. house' never falls through to state house.
  if (has(r'\bcd\b') || has(r'congress') || has(r'u\.?s\.?\s*(house|rep)')) {
    return DistrictRef('US Congress', n, 'CD $n');
  }
  if (has(r'\bsd\b') || has(r'senat')) {
    // senate / senator / state senate
    return DistrictRef('State Senate', n, 'SD $n');
  }
  if (has(r'\bhd\b') ||
      has(r'\bhouse\b') ||
      has(r'state rep') ||
      has(r'representative')) {
    return DistrictRef('State House', n, 'HD $n');
  }
  return null; // statewide / local / judicial: no chip, no sheet
}
