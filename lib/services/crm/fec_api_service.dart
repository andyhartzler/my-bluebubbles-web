import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:bluebubbles/models/crm/candidate.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

// ═══════════════════════════════════════════════════════════════
//  FEC API SERVICE
//  Fetch federal campaign finance data from the Federal Election
//  Commission API. Caches results in Supabase.
//
//  API Docs: https://api.open.fec.gov/developers/
//  Rate limit: 1,000 requests/hour with API key
// ═══════════════════════════════════════════════════════════════

class FecApiService {
  static final FecApiService _instance = FecApiService._();
  factory FecApiService() => _instance;
  FecApiService._();

  static const _baseUrl = 'https://api.open.fec.gov/v1';
  // DEMO_KEY is FEC's official demo key (1000 req/hr). Get a production key at https://api.open.fec.gov/developers/
  static const _apiKey = String.fromEnvironment('FEC_API_KEY', defaultValue: 'DEMO_KEY');
  static const _state = 'MO';

  final CRMSupabaseService _supabase = CRMSupabaseService();
  final Map<String, CandidateFinance> _cache = {};

  // ─── Search FEC candidates by name or state ───────────────────

  Future<List<Map<String, dynamic>>> searchCandidates({
    String? name,
    String state = _state,
    String? office, // H (House), S (Senate), P (President)
    int? electionYear,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final params = <String, String>{
        'api_key': _apiKey,
        'state': state,
        'sort': 'name',
        'sort_hide_null': 'true',
        'per_page': '$perPage',
        'page': '$page',
      };

      if (name != null && name.isNotEmpty) {
        params['q'] = name;
      }
      if (office != null) {
        params['office'] = office;
      }
      if (electionYear != null) {
        params['election_year'] = '$electionYear';
      }

      final uri = Uri.parse('$_baseUrl/candidates/search/').replace(
        queryParameters: params,
      );

      final response = await http.get(uri).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode != 200) {
        debugPrint('❌ FEC API error: ${response.statusCode}');
        return [];
      }

      final data = json.decode(response.body);
      final results = data['results'] as List<dynamic>? ?? [];

      return results.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('❌ FEC searchCandidates error: $e');
      return [];
    }
  }

  // ─── Get candidate financial totals ───────────────────────────

  Future<CandidateFinance?> getCandidateFinance(String fecCandidateId) async {
    // Check memory cache
    if (_cache.containsKey(fecCandidateId)) {
      return _cache[fecCandidateId];
    }

    // Check Supabase cache
    final cached = await _getCachedFinance(fecCandidateId);
    if (cached != null) {
      _cache[fecCandidateId] = cached;
      return cached;
    }

    // Fetch from FEC
    try {
      final params = <String, String>{
        'api_key': _apiKey,
        'sort': '-cycle',
        'per_page': '1',
      };

      final uri = Uri.parse(
          '$_baseUrl/candidate/$fecCandidateId/totals/')
          .replace(queryParameters: params);

      final response = await http.get(uri).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode != 200) {
        debugPrint('❌ FEC totals error: ${response.statusCode}');
        return null;
      }

      final data = json.decode(response.body);
      final results = data['results'] as List<dynamic>? ?? [];
      if (results.isEmpty) return null;

      final r = results.first as Map<String, dynamic>;
      final finance = CandidateFinance(
        candidateId: fecCandidateId,
        fecId: fecCandidateId,
        totalRaised: (r['receipts'] as num?)?.toDouble() ?? 0,
        totalSpent: (r['disbursements'] as num?)?.toDouble() ?? 0,
        cashOnHand: (r['cash_on_hand_end_period'] as num?)?.toDouble() ?? 0,
        totalDebt: (r['debts_owed_by_committee'] as num?)?.toDouble() ?? 0,
        individualContributions:
            (r['individual_contributions'] as num?)?.toDouble() ?? 0,
        pacContributions:
            (r['other_political_committee_contributions'] as num?)?.toDouble() ??
                0,
        contributorCount:
            (r['individual_itemized_contributions'] as num?)?.toInt() ?? 0,
        lastUpdated: r['coverage_end_date'] as String?,
      );

      // Cache in memory
      _cache[fecCandidateId] = finance;

      // Cache in Supabase
      await _cacheFinance(finance);

      return finance;
    } catch (e) {
      debugPrint('❌ FEC getCandidateFinance error: $e');
      return null;
    }
  }

  // ─── Get committee details ────────────────────────────────────

  Future<Map<String, dynamic>?> getCommitteeDetails(
      String fecCandidateId) async {
    try {
      final params = <String, String>{
        'api_key': _apiKey,
        'candidate_id': fecCandidateId,
        'per_page': '5',
      };

      final uri = Uri.parse('$_baseUrl/committees/').replace(
        queryParameters: params,
      );

      final response = await http.get(uri).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode != 200) return null;

      final data = json.decode(response.body);
      final results = data['results'] as List<dynamic>? ?? [];
      return results.isNotEmpty
          ? results.first as Map<String, dynamic>
          : null;
    } catch (e) {
      debugPrint('❌ FEC getCommitteeDetails error: $e');
      return null;
    }
  }

  // ─── Get top contributors ────────────────────────────────────

  Future<List<Map<String, dynamic>>> getTopContributors(
    String committeeId, {
    int limit = 10,
    int? cycle,
  }) async {
    try {
      final params = <String, String>{
        'api_key': _apiKey,
        'sort': '-total',
        'per_page': '$limit',
      };
      if (cycle != null) {
        params['cycle'] = '$cycle';
      }

      final uri = Uri.parse(
              '$_baseUrl/schedules/schedule_a/by_contributor/?committee_id=$committeeId')
          .replace(queryParameters: params);

      final response = await http.get(uri).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode != 200) return [];

      final data = json.decode(response.body);
      return (data['results'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('❌ FEC getTopContributors error: $e');
      return [];
    }
  }

  // ─── Get spending breakdown ──────────────────────────────────

  Future<List<Map<String, dynamic>>> getSpendingBreakdown(
    String committeeId, {
    int? cycle,
  }) async {
    try {
      final params = <String, String>{
        'api_key': _apiKey,
        'sort': '-total',
        'per_page': '20',
      };
      if (cycle != null) {
        params['cycle'] = '$cycle';
      }

      final uri = Uri.parse(
              '$_baseUrl/schedules/schedule_b/by_purpose/?committee_id=$committeeId')
          .replace(queryParameters: params);

      final response = await http.get(uri).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode != 200) return [];

      final data = json.decode(response.body);
      return (data['results'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('❌ FEC getSpendingBreakdown error: $e');
      return [];
    }
  }

  // ─── Map FEC candidate to our candidates table ────────────────

  Future<String?> findFecId(String candidateName, {String? office}) async {
    final results = await searchCandidates(
      name: candidateName,
      office: office,
      electionYear: 2026,
    );

    if (results.isEmpty) return null;

    // Try exact match first
    for (final r in results) {
      final fecName = (r['name'] as String? ?? '').toLowerCase();
      if (fecName.contains(candidateName.toLowerCase())) {
        return r['candidate_id'] as String?;
      }
    }

    // Return first result if no exact match
    return results.first['candidate_id'] as String?;
  }

  // ─── Supabase cache helpers ───────────────────────────────────

  // TODO: fec_finance_cache table doesn't exist in prod — audit 2026-04-24
  // Cache read returns null (table 404s gracefully). Cache write removed during
  // Wave 2 service-role cleanup — no caching until the table is provisioned
  // and RLS is configured.
  Future<CandidateFinance?> _getCachedFinance(String fecId) async {
    return null;
  }

  Future<void> _cacheFinance(CandidateFinance finance) async {
    // no-op: fec_finance_cache table doesn't exist in prod (2026-04-24).
  }

  // ─── Clear cache ──────────────────────────────────────────────

  void clearCache() {
    _cache.clear();
  }
}
