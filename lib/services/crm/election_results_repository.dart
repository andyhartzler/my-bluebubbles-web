import 'package:flutter/foundation.dart';

import 'supabase_service.dart';

/// One candidate's line from the official Missouri Primary Election results
/// (August 4 2026), as loaded into `public.election_results_2026` from the SOS
/// "State of Missouri - Election Night Results" PDF. Read-only reference data.
class ElectionResult {
  const ElectionResult({
    required this.officeRaw,
    required this.officeType,
    required this.district,
    required this.candidateName,
    required this.party,
    required this.votes,
    this.pct,
    this.advanced = false,
  });

  /// The office as printed, e.g. 'STATE REPRESENTATIVE - DISTRICT 52',
  /// 'U.S. REPRESENTATIVE - DISTRICT 1', 'State Auditor'.
  final String officeRaw;

  /// 'congressional' | 'house' | 'senate' | 'statewide' | 'other'.
  final String officeType;

  /// Bare district number as a string ('52', '8'); null for statewide races.
  final String? district;

  final String candidateName;

  /// 'Democratic' | 'Republican' | 'Libertarian' | 'Green' | ...
  final String party;

  final int votes;
  final double? pct;

  /// True for the top vote-getter within this office+party, i.e. the candidate
  /// who advances to the November general election as that party's nominee.
  final bool advanced;

  bool get isDemocrat => party.toLowerCase() == 'democratic';
  bool get isRepublican => party.toLowerCase() == 'republican';

  /// Short party tag for chips: D / R / L / G / etc.
  String get partyShort =>
      party.isEmpty ? '?' : party[0].toUpperCase();

  static String keyFor(String officeType, String district) =>
      '$officeType:$district';
  String? get key => district == null ? null : keyFor(officeType, district!);

  factory ElectionResult.fromJson(Map<String, dynamic> j) => ElectionResult(
        officeRaw: (j['office_raw'] ?? '').toString(),
        officeType: (j['office_type'] ?? '').toString(),
        district: j['district']?.toString(),
        candidateName: (j['candidate_name'] ?? '').toString(),
        party: (j['party'] ?? '').toString(),
        votes: (j['votes'] as num?)?.toInt() ?? 0,
        pct: (j['pct'] as num?)?.toDouble(),
        advanced: j['advanced'] == true,
      );
}

/// Loads and indexes the full 2026 primary results. Small (~510 rows) reference
/// data, fetched once and cached, then sliced in memory by district and by
/// general-election status.
class ElectionResultsRepository {
  final CRMSupabaseService _supabase = CRMSupabaseService();

  bool get _isReady => _supabase.isInitialized;

  List<ElectionResult>? _cache;

  static const _columns =
      'office_raw, office_type, district, candidate_name, party, votes, pct, advanced';

  /// All result rows, loaded once and cached.
  Future<List<ElectionResult>> getAll() async {
    if (_cache != null) return _cache!;
    if (!_isReady) return const [];
    try {
      final data = await _supabase.client
          .from('election_results_2026')
          .select(_columns)
          .order('votes', ascending: false);
      final list = (data as List)
          .map((e) => ElectionResult.fromJson(e as Map<String, dynamic>))
          .toList();
      _cache = list;
      return list;
    } catch (e) {
      debugPrint('ElectionResultsRepository.getAll failed: $e');
      return const [];
    }
  }

  /// Every candidate in one race (office type + bare district), highest votes
  /// first. E.g. `forDistrict(officeType: 'house', district: '52')`.
  Future<List<ElectionResult>> forDistrict({
    required String officeType,
    required String district,
  }) async {
    final all = await getAll();
    final out = all
        .where((r) => r.officeType == officeType && r.district == district)
        .toList()
      ..sort((a, b) => b.votes.compareTo(a.votes));
    return out;
  }

  /// A lookup of every race's candidate list, keyed `officeType:district`.
  Future<Map<String, List<ElectionResult>>> byDistrict() async {
    final all = await getAll();
    final out = <String, List<ElectionResult>>{};
    for (final r in all) {
      final k = r.key;
      if (k == null) continue;
      (out[k] ??= <ElectionResult>[]).add(r);
    }
    for (final list in out.values) {
      list.sort((a, b) => b.votes.compareTo(a.votes));
    }
    return out;
  }

  /// The November general-election field: the advancing nominee from each party
  /// in each race. Optionally restrict to one [officeType]
  /// ('congressional' | 'house' | 'senate') and/or one [party].
  Future<List<ElectionResult>> generalCandidates({
    String? officeType,
    String? party,
  }) async {
    final all = await getAll();
    return all.where((r) {
      if (!r.advanced) return false;
      if (officeType != null && r.officeType != officeType) return false;
      if (party != null && r.party.toLowerCase() != party.toLowerCase()) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) {
        final t = a.officeType.compareTo(b.officeType);
        if (t != 0) return t;
        final da = int.tryParse(a.district ?? '') ?? 1 << 30;
        final db = int.tryParse(b.district ?? '') ?? 1 << 30;
        if (da != db) return da.compareTo(db);
        return b.votes.compareTo(a.votes);
      });
  }
}
