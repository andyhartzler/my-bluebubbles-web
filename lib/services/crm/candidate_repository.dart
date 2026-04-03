import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/models/crm/candidate.dart';

import 'supabase_service.dart';

// ═══════════════════════════════════════════════════════════════
//  CANDIDATE REPOSITORY
//  Full CRUD + analytics for the `listmonk.candidates` table,
//  plus contact logs, news mentions, election history, and
//  district demographics from related tables.
// ═══════════════════════════════════════════════════════════════

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
    bool? isEndorsed,
    bool? isContacted,
    bool? hasCampaignSite,
    int? minAge,
    int? maxAge,
    int? minDistrict,
    int? maxDistrict,
    String? assignedTo,
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
      if (isEndorsed == true) {
        query = query.eq('is_endorsed', true);
      }
      if (isContacted == true) {
        query = query.eq('is_contacted', true);
      }
      if (hasCampaignSite == true) {
        query = query.not('campaign_website', 'is', null);
      }
      if (minAge != null) {
        query = query.gte('estimated_age', minAge);
      }
      if (maxAge != null) {
        query = query.lte('estimated_age', maxAge);
      }
      if (assignedTo != null) {
        query = query.eq('assigned_to', assignedTo);
      }

      final response = await query
          .order(sortBy, ascending: ascending)
          .range(offset, offset + limit - 1);

      var results = (response as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(Candidate.fromJson)
          .toList();

      // Post-filter for district range (needs int parsing)
      if (minDistrict != null || maxDistrict != null) {
        results = results.where((c) {
          final d = int.tryParse(c.district ?? '');
          if (d == null) return false;
          if (minDistrict != null && d < minDistrict) return false;
          if (maxDistrict != null && d > maxDistrict) return false;
          return true;
        }).toList();
      }

      return results;
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

  // ─── Paginated fetch for infinite scroll ──────────────────────

  Future<List<Candidate>> fetchPage({
    required int page,
    int pageSize = 50,
    String? searchQuery,
    String? party,
    String? officeLevel,
    bool? isYoungDem,
    String sortBy = 'name',
    bool ascending = true,
  }) async {
    return fetchCandidates(
      searchQuery: searchQuery,
      party: party,
      officeLevel: officeLevel,
      isYoungDem: isYoungDem,
      sortBy: sortBy,
      ascending: ascending,
      limit: pageSize,
      offset: page * pageSize,
    );
  }

  // ─── Aggregate stats ──────────────────────────────────────────

  Future<CandidateStats> fetchStats() async {
    if (!isReady) return const CandidateStats();

    try {
      final all = await _client
          .schema('listmonk')
          .from('candidates')
          .select('party, is_young_dem, estimated_age, district, office_level, is_endorsed, is_contacted, campaign_website');

      final rows = (all as List<dynamic>).cast<Map<String, dynamic>>();

      int total = rows.length;
      int democrats = 0;
      int republicans = 0;
      int youngDems = 0;
      int endorsed = 0;
      int contacted = 0;
      int withWebsite = 0;
      double ydAgeSum = 0;
      int ydAgeCount = 0;
      final demDistricts = <String>{};
      final repDistricts = <String>{};
      final ageDistribution = <String, int>{
        'under25': 0,
        '25-35': 0,
        '36-50': 0,
        '51-65': 0,
        'over65': 0,
        'unknown': 0,
      };

      for (final r in rows) {
        final party = (r['party'] as String? ?? '').toLowerCase();
        final isYd = r['is_young_dem'] as bool? ?? false;
        final age = (r['estimated_age'] as num?)?.toInt();
        final dist = r['district'] as String? ?? '';
        final level = r['office_level'] as String? ?? '';
        final isEnd = r['is_endorsed'] as bool? ?? false;
        final isCon = r['is_contacted'] as bool? ?? false;
        final hasWeb = r['campaign_website'] as String?;

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

        if (isEnd) endorsed++;
        if (isCon) contacted++;
        if (hasWeb != null && hasWeb.isNotEmpty) withWebsite++;

        // Age distribution
        if (age == null) {
          ageDistribution['unknown'] = (ageDistribution['unknown'] ?? 0) + 1;
        } else if (age < 25) {
          ageDistribution['under25'] = (ageDistribution['under25'] ?? 0) + 1;
        } else if (age <= 35) {
          ageDistribution['25-35'] = (ageDistribution['25-35'] ?? 0) + 1;
        } else if (age <= 50) {
          ageDistribution['36-50'] = (ageDistribution['36-50'] ?? 0) + 1;
        } else if (age <= 65) {
          ageDistribution['51-65'] = (ageDistribution['51-65'] ?? 0) + 1;
        } else {
          ageDistribution['over65'] = (ageDistribution['over65'] ?? 0) + 1;
        }
      }

      // Uncontested = Dem districts with no Republican filing
      final uncontestedDem = demDistricts.difference(repDistricts).length;
      final uncontestedRep = repDistricts.difference(demDistricts).length;
      final avgYdAge = ydAgeCount > 0 ? ydAgeSum / ydAgeCount : 0.0;

      return CandidateStats(
        totalCandidates: total,
        democrats: democrats,
        republicans: republicans,
        youngDemocrats: youngDems,
        uncontestedDemSeats: uncontestedDem,
        uncontestedRepSeats: uncontestedRep,
        averageYdAge: avgYdAge,
        endorsed: endorsed,
        contacted: contacted,
        withWebsite: withWebsite,
        ageDistribution: ageDistribution,
      );
    } catch (e) {
      debugPrint('❌ CandidateRepository.fetchStats error: $e');
      return const CandidateStats();
    }
  }

  // ─── Update candidate fields ───────────────────────────────────

  Future<void> updateCandidate(String id, Map<String, dynamic> updates) async {
    if (!isReady) return;

    try {
      updates['updated_at'] = DateTime.now().toIso8601String();
      await _client
          .schema('listmonk')
          .from('candidates')
          .update(updates)
          .eq('id', id);
    } catch (e) {
      debugPrint('❌ CandidateRepository.updateCandidate error: $e');
    }
  }

  // ─── Update candidate notes ────────────────────────────────────

  Future<void> updateNotes(String id, String notes) async {
    await updateCandidate(id, {'notes': notes});
  }

  // ─── Toggle endorsement ────────────────────────────────────────

  Future<void> toggleEndorsement(String id, bool endorsed) async {
    await updateCandidate(id, {
      'is_endorsed': endorsed,
      'endorsement_status': endorsed ? 'endorsed' : 'not_endorsed',
    });
  }

  // ─── Mark as contacted ─────────────────────────────────────────

  Future<void> markContacted(String id, String method) async {
    await updateCandidate(id, {
      'is_contacted': true,
      'last_contact_date': DateTime.now().toIso8601String(),
      'contact_method': method,
    });
  }

  // ─── Assign team member ────────────────────────────────────────

  Future<void> assignTeamMember(String id, String? memberName) async {
    await updateCandidate(id, {'assigned_to': memberName});
  }

  // ─── Create new candidate ──────────────────────────────────────

  Future<Candidate?> createCandidate(Map<String, dynamic> data) async {
    if (!isReady) return null;

    try {
      data['created_at'] = DateTime.now().toIso8601String();
      data['updated_at'] = DateTime.now().toIso8601String();

      final response = await _client
          .schema('listmonk')
          .from('candidates')
          .insert(data)
          .select()
          .single();

      return Candidate.fromJson(response);
    } catch (e) {
      debugPrint('❌ CandidateRepository.createCandidate error: $e');
      return null;
    }
  }

  // ─── Delete candidate ──────────────────────────────────────────

  Future<void> deleteCandidate(String id) async {
    if (!isReady) return;

    try {
      await _client
          .schema('listmonk')
          .from('candidates')
          .delete()
          .eq('id', id);
    } catch (e) {
      debugPrint('❌ CandidateRepository.deleteCandidate error: $e');
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

  // ═══════════════════════════════════════════════════════════════
  //  CONTACT LOG OPERATIONS
  // ═══════════════════════════════════════════════════════════════

  Future<List<CandidateContact>> fetchContacts(String candidateId) async {
    if (!isReady) return [];

    try {
      final response = await _client
          .schema('listmonk')
          .from('candidate_contacts')
          .select()
          .eq('candidate_id', candidateId)
          .order('contact_date', ascending: false);

      return (response as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(CandidateContact.fromJson)
          .toList();
    } catch (e) {
      debugPrint('❌ CandidateRepository.fetchContacts error: $e');
      return [];
    }
  }

  Future<CandidateContact?> addContact(Map<String, dynamic> data) async {
    if (!isReady) return null;

    try {
      final response = await _client
          .schema('listmonk')
          .from('candidate_contacts')
          .insert(data)
          .select()
          .single();

      // Also mark the candidate as contacted
      final candidateId = data['candidate_id'] as String?;
      if (candidateId != null) {
        await markContacted(candidateId, data['contact_type'] as String? ?? 'other');
      }

      return CandidateContact.fromJson(response);
    } catch (e) {
      debugPrint('❌ CandidateRepository.addContact error: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  NEWS MENTIONS
  // ═══════════════════════════════════════════════════════════════

  Future<List<CandidateNews>> fetchNews(String candidateId) async {
    if (!isReady) return [];

    try {
      final response = await _client
          .schema('listmonk')
          .from('candidate_news')
          .select()
          .eq('candidate_id', candidateId)
          .order('published_at', ascending: false);

      return (response as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(CandidateNews.fromJson)
          .toList();
    } catch (e) {
      debugPrint('❌ CandidateRepository.fetchNews error: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  ELECTION HISTORY
  // ═══════════════════════════════════════════════════════════════

  Future<List<ElectionResult>> fetchElectionHistory(String district) async {
    if (!isReady) return [];

    try {
      final response = await _client
          .schema('listmonk')
          .from('election_results')
          .select()
          .eq('district', district)
          .order('year', ascending: false);

      return (response as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(ElectionResult.fromJson)
          .toList();
    } catch (e) {
      debugPrint('❌ CandidateRepository.fetchElectionHistory error: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  DISTRICT DEMOGRAPHICS
  // ═══════════════════════════════════════════════════════════════

  Future<DistrictDemographics?> fetchDistrictDemographics(
      String district) async {
    if (!isReady) return null;

    try {
      final response = await _client
          .schema('listmonk')
          .from('district_demographics')
          .select()
          .eq('district', district)
          .maybeSingle();

      if (response == null) return null;
      return DistrictDemographics.fromJson(response);
    } catch (e) {
      debugPrint('❌ CandidateRepository.fetchDistrictDemographics error: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  BULK OPERATIONS
  // ═══════════════════════════════════════════════════════════════

  /// Export candidates to CSV format
  Future<String> exportCandidatesCsv({
    List<String>? candidateIds,
    String? party,
    bool? isYoungDem,
  }) async {
    List<Candidate> candidates;
    if (candidateIds != null && candidateIds.isNotEmpty) {
      final futures =
          candidateIds.map((id) => fetchCandidate(id)).toList();
      final results = await Future.wait(futures);
      candidates = results.whereType<Candidate>().toList();
    } else {
      candidates = await fetchCandidates(
        party: party,
        isYoungDem: isYoungDem,
        limit: 2000,
      );
    }

    final buffer = StringBuffer();
    buffer.writeln(
        'Name,Party,Office,District,Age,Young Dem,Score,Email,Phone,Campaign Website,Endorsed,Contacted,Assigned To');
    for (final c in candidates) {
      buffer.writeln(
        '"${c.name}","${c.party}","${c.office}","${c.district ?? ''}",${c.estimatedAge ?? ''},${c.isYoungDem},${c.youngDemScore},"${c.email ?? ''}","${c.phone ?? ''}","${c.campaignWebsite ?? ''}",${c.isEndorsed},${c.isContacted},"${c.assignedTo ?? ''}"',
      );
    }
    return buffer.toString();
  }

  /// Bulk assign candidates to a team member
  Future<void> bulkAssign(List<String> candidateIds, String assignee) async {
    for (final id in candidateIds) {
      await assignTeamMember(id, assignee);
    }
  }

  /// Bulk mark as contacted
  Future<void> bulkMarkContacted(
      List<String> candidateIds, String method) async {
    for (final id in candidateIds) {
      await markContacted(id, method);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  ANALYTICS QUERIES
  // ═══════════════════════════════════════════════════════════════

  /// Get party breakdown by office level
  Future<Map<String, Map<String, int>>> fetchPartyBreakdown() async {
    if (!isReady) return {};

    try {
      final response = await _client
          .schema('listmonk')
          .from('candidates')
          .select('party, office_level');

      final rows = (response as List<dynamic>).cast<Map<String, dynamic>>();
      final breakdown = <String, Map<String, int>>{};

      for (final r in rows) {
        final level = r['office_level'] as String? ?? 'other';
        final party = r['party'] as String? ?? 'other';
        breakdown.putIfAbsent(level, () => {});
        breakdown[level]![party] = (breakdown[level]![party] ?? 0) + 1;
      }

      return breakdown;
    } catch (e) {
      debugPrint('❌ CandidateRepository.fetchPartyBreakdown error: $e');
      return {};
    }
  }

  /// Get contested vs uncontested seat breakdown
  Future<Map<String, int>> fetchContestationBreakdown() async {
    if (!isReady) return {};

    try {
      final response = await _client
          .schema('listmonk')
          .from('candidates')
          .select('district, party')
          .eq('office_level', 'state');

      final rows = (response as List<dynamic>).cast<Map<String, dynamic>>();
      final districtParties = <String, Set<String>>{};

      for (final r in rows) {
        final dist = r['district'] as String? ?? '';
        final party = r['party'] as String? ?? '';
        if (dist.isNotEmpty) {
          districtParties.putIfAbsent(dist, () => {}).add(party);
        }
      }

      int contested = 0;
      int uncontestedDem = 0;
      int uncontestedRep = 0;
      int other = 0;

      for (final parties in districtParties.values) {
        final hasDem = parties.contains('Democratic');
        final hasRep = parties.contains('Republican');
        if (hasDem && hasRep) {
          contested++;
        } else if (hasDem) {
          uncontestedDem++;
        } else if (hasRep) {
          uncontestedRep++;
        } else {
          other++;
        }
      }

      return {
        'contested': contested,
        'uncontested_dem': uncontestedDem,
        'uncontested_rep': uncontestedRep,
        'other': other,
        'total_districts': districtParties.length,
      };
    } catch (e) {
      debugPrint(
          '❌ CandidateRepository.fetchContestationBreakdown error: $e');
      return {};
    }
  }

  /// Get candidates with upcoming follow-ups
  Future<List<Candidate>> fetchUpcomingFollowUps() async {
    if (!isReady) return [];

    try {
      final response = await _client
          .schema('listmonk')
          .from('candidate_contacts')
          .select('candidate_id, follow_up_date')
          .not('follow_up_date', 'is', null)
          .gte('follow_up_date', DateTime.now().toIso8601String())
          .lte(
              'follow_up_date',
              DateTime.now()
                  .add(const Duration(days: 7))
                  .toIso8601String())
          .order('follow_up_date');

      final rows = (response as List<dynamic>).cast<Map<String, dynamic>>();
      final candidateIds =
          rows.map((r) => r['candidate_id'] as String).toSet();

      final futures =
          candidateIds.map((id) => fetchCandidate(id)).toList();
      final results = await Future.wait(futures);
      return results.whereType<Candidate>().toList();
    } catch (e) {
      debugPrint('❌ CandidateRepository.fetchUpcomingFollowUps error: $e');
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
  final int uncontestedRepSeats;
  final double averageYdAge;
  final int endorsed;
  final int contacted;
  final int withWebsite;
  final Map<String, int> ageDistribution;

  const CandidateStats({
    this.totalCandidates = 0,
    this.democrats = 0,
    this.republicans = 0,
    this.youngDemocrats = 0,
    this.uncontestedDemSeats = 0,
    this.uncontestedRepSeats = 0,
    this.averageYdAge = 0,
    this.endorsed = 0,
    this.contacted = 0,
    this.withWebsite = 0,
    this.ageDistribution = const {},
  });

  int get totalContested =>
      totalCandidates > 0
          ? (totalCandidates -
              uncontestedDemSeats -
              uncontestedRepSeats)
          : 0;

  double get contactedPercent =>
      totalCandidates > 0 ? contacted / totalCandidates * 100 : 0;
}
