import 'package:flutter/foundation.dart';

import 'package:bluebubbles/models/crm/member.dart';
import 'supabase_service.dart';

/// One Democratic nominee for the November 2026 general election, derived from
/// the official August 4 2026 primary results (the top Democrat in each race).
/// Stored in public.ge_2026_dem_nominees. Read-only reference data.
class GeNominee {
  const GeNominee({
    required this.kind,
    required this.district,
    required this.nominee,
    this.primaryVotes,
    this.primaryPct,
    this.contestedPrimary = false,
  });

  /// 'house', 'senate' or 'congressional'.
  final String kind;

  /// Bare district number as a string ('52', '8', ...), matching how members
  /// store house_district / senate_district and the digits of CD-1.
  final String district;

  final String nominee;
  final int? primaryVotes;
  final double? primaryPct;

  /// True when more than one Democrat filed, so this nominee won a contested
  /// primary rather than running unopposed. Display only, never a filter that
  /// hides anyone.
  final bool contestedPrimary;

  static String keyFor(String kind, String district) => '$kind:$district';
  String get key => keyFor(kind, district);

  factory GeNominee.fromJson(Map<String, dynamic> j) => GeNominee(
        kind: (j['kind'] ?? '').toString(),
        district: (j['district'] ?? '').toString(),
        nominee: (j['nominee'] ?? '').toString(),
        primaryVotes: (j['primary_votes'] as num?)?.toInt(),
        primaryPct: (j['primary_pct'] as num?)?.toDouble(),
        contestedPrimary: j['contested_primary'] == true,
      );

  /// The digits of a member's district value. Members store congressional as
  /// 'CD-1' and house/senate as bare numbers, so stripping non-digits gives a
  /// value that matches [district] for all three.
  static String? districtDigits(String? raw) {
    if (raw == null) return null;
    final d = raw.replaceAll(RegExp(r'\D'), '');
    return d.isEmpty ? null : d;
  }
}

/// Which Democratic candidates a member can be connected to this cycle: their
/// congressional-district nominee always (91% of members have a CD on file),
/// and their state house / senate nominee where the member's district is known
/// and that seat is on the 2026 ballot. Never invents a match.
class MemberNominees {
  const MemberNominees({this.congressional, this.house, this.senate});
  final GeNominee? congressional;
  final GeNominee? house;
  final GeNominee? senate;

  bool get hasAny => congressional != null || house != null || senate != null;

  List<GeNominee> get all =>
      [congressional, house, senate].whereType<GeNominee>().toList();
}

class GeNomineeRepository {
  final CRMSupabaseService _supabase = CRMSupabaseService();

  bool get _isReady => _supabase.isInitialized;

  List<GeNominee>? _cache;

  /// All nominees, loaded once and cached. Small (183 rows) reference data.
  Future<List<GeNominee>> getAll() async {
    if (_cache != null) return _cache!;
    if (!_isReady) return const [];
    try {
      final data = await _supabase.client
          .from('ge_2026_dem_nominees')
          .select('kind, district, nominee, primary_votes, primary_pct, '
              'contested_primary');
      final list = (data as List)
          .map((e) => GeNominee.fromJson(e as Map<String, dynamic>))
          .toList();
      _cache = list;
      return list;
    } catch (e) {
      debugPrint('GeNomineeRepository.getAll failed: $e');
      return const [];
    }
  }

  /// A lookup keyed by 'kind:district' for O(1) client-side matching.
  Future<Map<String, GeNominee>> getLookup() async {
    final all = await getAll();
    return {for (final n in all) n.key: n};
  }

  /// Attach the nominees a single member connects to, using a prebuilt lookup
  /// so a member list can be annotated without a query per row.
  static MemberNominees matchFor(Member m, Map<String, GeNominee> lookup) {
    final cd = GeNominee.districtDigits(m.congressionalDistrict);
    final hd = GeNominee.districtDigits(m.houseDistrict);
    final sd = GeNominee.districtDigits(m.senateDistrict);
    return MemberNominees(
      congressional:
          cd == null ? null : lookup[GeNominee.keyFor('congressional', cd)],
      house: hd == null ? null : lookup[GeNominee.keyFor('house', hd)],
      senate: sd == null ? null : lookup[GeNominee.keyFor('senate', sd)],
    );
  }
}
