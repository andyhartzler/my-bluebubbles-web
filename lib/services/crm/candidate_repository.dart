import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/models/crm/candidate.dart';

import 'supabase_service.dart';

/// Repository for querying the `listmonk.candidates` table.
///
/// Uses the privileged (service-role) client because the table lives
/// in the `listmonk` schema which is not exposed through the public
/// PostgREST API.
class CandidateRepository {
  final CRMSupabaseService _supabase = CRMSupabaseService();

  bool get isReady => CRMConfig.crmEnabled && _supabase.isInitialized;

  SupabaseClient get _client => _supabase.privilegedClient;

  // ─── Fetch all candidates (with optional filters) ──────────────

  Future<List<Candidate>> fetchCandidates({
    String? searchQuery,
    String? party,
    String? officeLevel,
    String? district,
    bool? isYoungDem,
    int? minAge,
    int? maxAge,
    String sortBy = 'name',
    bool ascending = true,
    int limit = 500,
    int offset = 0,
  }) async {
    if (!isReady) return [];

    try {
      var query = _client
          .schema('listmonk')
          .from('candidates')
          .select();

      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.ilike('name', '%$searchQuery%');
      }
      if (party != null && party.isNotEmpty) {
        query = query.eq('party', party);
      }
      if (officeLevel != null && officeLevel.isNotEmpty) {
        query = query.eq('office_level', officeLevel);
      }
      if (district != null && district.isNotEmpty) {
        query = query.eq('district', district);
      }
      if (isYoungDem == true) {
        query = query.eq('is_young_dem', true);
      }
      if (minAge != null) {
        query = query.gte('estimated_age', minAge);
      }
      if (maxAge != null) {
        query = query.lte('estimated_age', maxAge);
      }

      final response = await query
          .order(sortBy, ascending: ascending)
          .range(offset, offset + limit - 1);

      return (response as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(Candidate.fromJson)
          .toList();
    } catch (e) {
      debugPrint('❌ CandidateRepository.fetchCandidates error: $e');
      return [];
    }
  }

  // ─── Fetch single candidate ────────────────────────────────────

  Future<Candidate?> fetchCandidate(String id) async {
    if (!isReady) return null;

    try {
      final response = await _client
          .schema('listmonk')
          .from('candidates')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      return Candidate.fromJson(response);
    } catch (e) {
      debugPrint('❌ CandidateRepository.fetchCandidate error: $e');
      return null;
    }
  }

  // ─── Fetch only Young Democrats ────────────────────────────────

  Future<List<Candidate>> fetchYoungDemocrats() async {
    if (!isReady) return [];

    try {
      final response = await _client
          .schema('listmonk')
          .from('candidates')
          .select()
          .eq('is_young_dem', true)
          .order('estimated_age', ascending: true);

      return (response as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(Candidate.fromJson)
          .toList();
    } catch (e) {
      debugPrint('❌ CandidateRepository.fetchYoungDemocrats error: $e');
      return [];
    }
  }

  // ─── Aggregate stats ──────────────────────────────────────────

  Future<CandidateStats> fetchStats() async {
    if (!isReady) return const CandidateStats();

    try {
      final all = await _client
          .schema('listmonk')
          .from('candidates')
          .select('party, is_young_dem, estimated_age, district, office_level');

      final rows = (all as List<dynamic>).cast<Map<String, dynamic>>();

      int total = rows.length;
      int democrats = 0;
      int republicans = 0;
      int youngDems = 0;
      double ydAgeSum = 0;
      int ydAgeCount = 0;
      final demDistricts = <String>{};
      final repDistricts = <String>{};

      for (final r in rows) {
        final party = (r['party'] as String? ?? '').toLowerCase();
        final isYd = r['is_young_dem'] as bool? ?? false;
        final age = (r['estimated_age'] as num?)?.toInt();
        final dist = r['district'] as String? ?? '';
        final level = r['office_level'] as String? ?? '';

        if (party == 'democratic') {
          democrats++;
          if (level == 'state' && dist.isNotEmpty) demDistricts.add(dist);
        } else if (party == 'republican') {
          republicans++;
          if (level == 'state' && dist.isNotEmpty) repDistricts.add(dist);
        }

        if (isYd) {
          youngDems++;
          if (age != null) {
            ydAgeSum += age;
            ydAgeCount++;
          }
        }
      }

      // Uncontested = Dem districts with no Republican filing
      final uncontestedDem = demDistricts.difference(repDistricts).length;
      final avgYdAge = ydAgeCount > 0 ? ydAgeSum / ydAgeCount : 0.0;

      return CandidateStats(
        totalCandidates: total,
        democrats: democrats,
        republicans: republicans,
        youngDemocrats: youngDems,
        uncontestedDemSeats: uncontestedDem,
        averageYdAge: avgYdAge,
      );
    } catch (e) {
      debugPrint('❌ CandidateRepository.fetchStats error: $e');
      return const CandidateStats();
    }
  }

  // ─── Update candidate notes ────────────────────────────────────

  Future<void> updateNotes(String id, String notes) async {
    if (!isReady) return;

    try {
      await _client
          .schema('listmonk')
          .from('candidates')
          .update({'notes': notes, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', id);
    } catch (e) {
      debugPrint('❌ CandidateRepository.updateNotes error: $e');
    }
  }

  // ─── Get distinct districts for state house candidates ─────────

  Future<List<String>> fetchStateHouseDistricts() async {
    if (!isReady) return [];

    try {
      final response = await _client
          .schema('listmonk')
          .from('candidates')
          .select('district, party, is_young_dem')
          .eq('office_level', 'state')
          .not('district', 'is', null);

      final rows = (response as List<dynamic>).cast<Map<String, dynamic>>();
      final districts = <String>{};
      for (final r in rows) {
        final d = r['district'] as String? ?? '';
        if (d.isNotEmpty) districts.add(d);
      }
      final sorted = districts.toList()
        ..sort((a, b) {
          final ai = int.tryParse(a) ?? 999;
          final bi = int.tryParse(b) ?? 999;
          return ai.compareTo(bi);
        });
      return sorted;
    } catch (e) {
      debugPrint('❌ CandidateRepository.fetchStateHouseDistricts error: $e');
      return [];
    }
  }

  // ─── Get candidates by district (for map taps) ────────────────

  Future<List<Candidate>> fetchCandidatesByDistrict(String district) async {
    if (!isReady) return [];

    try {
      final response = await _client
          .schema('listmonk')
          .from('candidates')
          .select()
          .eq('district', district)
          .eq('office_level', 'state')
          .order('party');

      return (response as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(Candidate.fromJson)
          .toList();
    } catch (e) {
      debugPrint('❌ CandidateRepository.fetchCandidatesByDistrict error: $e');
      return [];
    }
  }
}

/// Aggregated candidate statistics
class CandidateStats {
  final int totalCandidates;
  final int democrats;
  final int republicans;
  final int youngDemocrats;
  final int uncontestedDemSeats;
  final double averageYdAge;

  const CandidateStats({
    this.totalCandidates = 0,
    this.democrats = 0,
    this.republicans = 0,
    this.youngDemocrats = 0,
    this.uncontestedDemSeats = 0,
    this.averageYdAge = 0,
  });
}
