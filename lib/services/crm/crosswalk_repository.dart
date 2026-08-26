import 'package:flutter/foundation.dart';

import 'supabase_service.dart';

/// Maps each county to the congressional / house / senate districts that
/// overlap it, precomputed in `public.region_crosswalk` from the statewide
/// voter file. County mode on the volunteers map is not a ballot unit, so it
/// borrows the candidate rows of the districts its voters fall into; this
/// repository is the county -> district lookup that resolution needs, with no
/// runtime GIS and no scan of the 4.34M-row voter file.
///
/// The outer key is the normalized county label the map and members share: the
/// `county` property of assets/geojson/mo_counties.geojson, which is also what
/// `Member.normalizeCountyLabel` produces for a member's county. The inner key
/// is the office type, one of 'congressional' | 'house' | 'senate'. The value
/// is that office's overlapping districts as bare digit strings ('2', '63'),
/// sorted numerically, which is exactly the shape `ElectionResult.district` and
/// the `officeType:district` candidate index use.
///
/// Two county names do not round-trip through the map and are handled in the
/// migration rather than here: "St. Louis City" folds into the "St. Louis" key
/// (the geojson carries two St. Louis polygons under one label), and "Kansas
/// City" is its own key with no polygon, so it is reachable only by search, not
/// by tapping the Jackson/Clay/Platte/Cass polygons it physically spans.
class CrosswalkRepository {
  final CRMSupabaseService _supabase = CRMSupabaseService();

  bool get _isReady => _supabase.isInitialized;

  Map<String, Map<String, List<String>>>? _cache;

  static const _columns = 'county, office_type, district';
  static const _pageSize = 1000;

  /// The full crosswalk, loaded once and cached. Small reference data today
  /// (~500 rows), but a bare Supabase select silently caps at 1000 rows, so
  /// this pages with `.range()` regardless; a larger voter file later will not
  /// silently truncate the map's county coverage.
  Future<Map<String, Map<String, List<String>>>> getCountyCrosswalk() async {
    final cached = _cache;
    if (cached != null) return cached;
    if (!_isReady) return const {};

    try {
      final out = <String, Map<String, List<String>>>{};

      for (var from = 0;; from += _pageSize) {
        final page = await _supabase.client
            .from('region_crosswalk')
            .select(_columns)
            .order('county')
            .order('office_type')
            .range(from, from + _pageSize - 1);

        final rows = (page as List);
        for (final row in rows) {
          final r = row as Map<String, dynamic>;
          final county = (r['county'] ?? '').toString();
          final office = (r['office_type'] ?? '').toString();
          final district = (r['district'] ?? '').toString();
          if (county.isEmpty || office.isEmpty || district.isEmpty) continue;
          ((out[county] ??= <String, List<String>>{})[office] ??= <String>[])
              .add(district);
        }

        if (rows.length < _pageSize) break;
      }

      // Bare-digit strings sorted numerically, so '2' precedes '10'. Districts
      // are unique per (county, office) by the table's primary key, so there is
      // nothing to dedupe.
      for (final byOffice in out.values) {
        for (final districts in byOffice.values) {
          districts.sort((a, b) =>
              (int.tryParse(a) ?? 1 << 30).compareTo(int.tryParse(b) ?? 1 << 30));
        }
      }

      _cache = out;
      return out;
    } catch (e) {
      debugPrint('CrosswalkRepository.getCountyCrosswalk failed: $e');
      return const {};
    }
  }
}
