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
        query = query.eq('moyd_endorsed', true);
      }
      if (isContacted == true) {
        query = query.eq('moyd_contacted', true);
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

          .from('candidates')
          .select('party, is_young_dem, estimated_age, district, office_level, moyd_endorsed, moyd_contacted, campaign_website, mec_committee_ids, fec_candidate_id');

      final rows = (all as List<dynamic>).cast<Map<String, dynamic>>();

      int total = rows.length;
      int democrats = 0;
      int republicans = 0;
      int youngDems = 0;
      int endorsed = 0;
      int contacted = 0;
      int withWebsite = 0;
      int withMecCommittee = 0;
      int withFecCandidate = 0;
      int withAnyFinance = 0;
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
        final isEnd = r['moyd_endorsed'] as bool? ?? false;
        final isCon = r['moyd_contacted'] as bool? ?? false;
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

        final mecArr = r['mec_committee_ids'];
        final fecId = r['fec_candidate_id'] as String?;
        final hasMec = mecArr is List && mecArr.isNotEmpty;
        final hasFec = fecId != null && fecId.isNotEmpty;
        if (hasMec) withMecCommittee++;
        if (hasFec) withFecCandidate++;
        if (hasMec || hasFec) withAnyFinance++;

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
        withMecCommittee: withMecCommittee,
        withFecCandidate: withFecCandidate,
        withAnyFinance: withAnyFinance,
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
      'moyd_endorsed': endorsed,
      'endorsement_status': endorsed ? 'endorsed' : 'not_endorsed',
    });
  }

  // ─── Mark as contacted ─────────────────────────────────────────

  Future<void> markContacted(String id, String method) async {
    await updateCandidate(id, {
      'moyd_contacted': true,
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
          .from('election_history')
          .select()
          .eq('district', district)
          .order('election_year', ascending: false);

      // The election_history table stores one row per candidate per race.
      // We need to aggregate into ElectionResult (Dem vs Rep per year).
      final rows = (response as List<dynamic>).cast<Map<String, dynamic>>();

      // Group by (election_year, election_type)
      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final row in rows) {
        final year = row['election_year']?.toString() ?? '';
        final type = row['election_type'] as String? ?? 'general';
        final key = '$year-$type';
        grouped.putIfAbsent(key, () => []).add(row);
      }

      final results = <ElectionResult>[];
      for (final entry in grouped.entries) {
        final candidates = entry.value;
        final year = (candidates.first['election_year'] as num?)?.toInt() ?? 0;
        final type = candidates.first['election_type'] as String? ?? 'general';

        String? demCandidate, repCandidate;
        int? demVotes, repVotes;
        double? demPercent, repPercent;
        String? winner;
        int totalVotes = 0;

        for (final c in candidates) {
          final party = (c['party'] as String? ?? '').toLowerCase();
          final name = c['candidate_name'] as String?;
          final votes = (c['votes'] as num?)?.toInt();
          final pct = (c['vote_percentage'] as num?)?.toDouble();
          final isWinner = c['winner'] as bool? ?? false;

          if (votes != null) totalVotes += votes;

          if (party.contains('democrat')) {
            demCandidate = name;
            demVotes = votes;
            demPercent = pct;
            if (isWinner) winner = 'Democratic';
          } else if (party.contains('republican')) {
            repCandidate = name;
            repVotes = votes;
            repPercent = pct;
            if (isWinner) winner = 'Republican';
          }
        }

        results.add(ElectionResult(
          id: '${district}_${year}_$type',
          district: district,
          year: year,
          demCandidate: demCandidate,
          repCandidate: repCandidate,
          demVotes: demVotes,
          repVotes: repVotes,
          totalVotes: totalVotes > 0 ? totalVotes : null,
          winner: winner,
          demPercent: demPercent,
          repPercent: repPercent,
        ));
      }

      // Sort descending by year
      results.sort((a, b) => b.year.compareTo(a.year));
      return results;
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

  // ═══════════════════════════════════════════════════════════════
  //  MEC CAMPAIGN FINANCE — Missouri Ethics Commission data
  // ═══════════════════════════════════════════════════════════════

  /// Fetch MEC committee info using the candidate's linked committee IDs
  Future<List<Map<String, dynamic>>> getMECCommittees(List<String> mecIds) async {
    if (!isReady || mecIds.isEmpty) return [];
    try {
      final response = await _client
          .from('mec_committees')
          .select()
          .inFilter('mec_id', mecIds);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ CandidateRepository.getMECCommittees error: $e');
      return [];
    }
  }

  /// Fetch MEC contributions for a given mec_id (committee)
  Future<List<MECContribution>> getMECContributions(String mecId, {int limit = 500}) async {
    if (!isReady) return [];

    try {
      final response = await _client
          .from('mec_contributions')
          .select()
          .eq('mec_id', mecId)
          .order('contribution_date', ascending: false)
          .limit(limit);

      return (response as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(MECContribution.fromJson)
          .toList();
    } catch (e) {
      debugPrint('❌ CandidateRepository.getMECContributions error: $e');
      return [];
    }
  }

  /// Fetch top donors for a committee (via Postgres function)
  Future<List<Map<String, dynamic>>> getMECTopDonors(String mecId, {int limit = 10}) async {
    if (!isReady) return [];

    try {
      final response = await _client.rpc('get_mec_top_donors', params: {
        'p_mec_id': mecId,
        'p_limit': limit,
      });

      if (response is List) {
        return response.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('❌ CandidateRepository.getMECTopDonors error: $e');
      return [];
    }
  }

  /// Fetch monthly contribution timeline for a committee (via Postgres function)
  Future<List<Map<String, dynamic>>> getMECContributionTimeline(String mecId) async {
    if (!isReady) return [];

    try {
      final response = await _client.rpc('get_mec_contribution_timeline', params: {
        'p_mec_id': mecId,
      });

      if (response is List) {
        return response.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('❌ CandidateRepository.getMECContributionTimeline error: $e');
      return [];
    }
  }

  /// Fetch MEC finance summary for a committee (via Postgres function)
  Future<Map<String, dynamic>> getMECFinanceSummary(String mecId) async {
    if (!isReady) return {};

    try {
      final response = await _client.rpc('get_mec_finance_summary', params: {
        'p_mec_id': mecId,
      });

      if (response is Map<String, dynamic>) {
        return response;
      }
      return {};
    } catch (e) {
      debugPrint('❌ CandidateRepository.getMECFinanceSummary error: $e');
      return {};
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  MEC EXPENDITURES — Spending data
  // ═══════════════════════════════════════════════════════════════

  /// Fetch expenditure summary with breakdowns (via Postgres function)
  Future<Map<String, dynamic>> getMECExpenditureSummary(String mecId) async {
    if (!isReady) return {};

    try {
      final response = await _client.rpc('get_mec_expenditure_summary', params: {
        'p_mec_id': mecId,
      });

      if (response is Map<String, dynamic>) {
        return response;
      }
      return {};
    } catch (e) {
      debugPrint('❌ CandidateRepository.getMECExpenditureSummary error: $e');
      return {};
    }
  }

  /// Fetch top expenditure payees (via Postgres function)
  Future<List<Map<String, dynamic>>> getMECTopPayees(String mecId, {int limit = 10}) async {
    if (!isReady) return [];

    try {
      final response = await _client.rpc('get_mec_top_payees', params: {
        'p_mec_id': mecId,
        'p_limit': limit,
      });

      if (response is List) {
        return response.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('❌ CandidateRepository.getMECTopPayees error: $e');
      return [];
    }
  }

  /// Fetch recent expenditures for a committee
  Future<List<Map<String, dynamic>>> getMECRecentExpenditures(String mecId, {int limit = 20}) async {
    if (!isReady) return [];

    try {
      final response = await _client
          .from('mec_expenditures')
          .select()
          .eq('mec_id', mecId)
          .order('expenditure_date', ascending: false)
          .limit(limit);

      return (response as List<dynamic>).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('❌ CandidateRepository.getMECRecentExpenditures error: $e');
      return [];
    }
  }

  /// Fetch race-wide finance comparison (via Postgres function)
  Future<List<Map<String, dynamic>>> getRaceFinanceComparison(String office, String district) async {
    if (!isReady) return [];

    try {
      final response = await _client.rpc('get_race_finance_comparison', params: {
        'p_office': office,
        'p_district': district,
      });

      if (response is List) {
        return response.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('❌ CandidateRepository.getRaceFinanceComparison error: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  FEC FINANCE — federal candidate contributions
  // ═══════════════════════════════════════════════════════════════

  /// Fetch FEC finance summary for a federal candidate
  Future<Map<String, dynamic>> getFECFinanceSummary(String fecCandId) async {
    if (!isReady) return {};
    try {
      final response = await _client.rpc('get_fec_finance_summary', params: {
        'p_fec_cand_id': fecCandId,
      });
      if (response is Map<String, dynamic>) return response;
      return {};
    } catch (e) {
      debugPrint('❌ CandidateRepository.getFECFinanceSummary error: $e');
      return {};
    }
  }

  /// Fetch top FEC donors for a federal candidate
  Future<List<Map<String, dynamic>>> getFECTopDonors(String fecCandId, {int limit = 10}) async {
    if (!isReady) return [];
    try {
      final response = await _client.rpc('get_fec_top_donors', params: {
        'p_fec_cand_id': fecCandId,
        'p_limit': limit,
      });
      if (response is List) return response.cast<Map<String, dynamic>>();
      return [];
    } catch (e) {
      debugPrint('❌ CandidateRepository.getFECTopDonors error: $e');
      return [];
    }
  }

  /// Fetch FEC contribution timeline (monthly) for a federal candidate
  Future<List<Map<String, dynamic>>> getFECContributionTimeline(String fecCandId) async {
    if (!isReady) return [];
    try {
      final response = await _client.rpc('get_fec_contribution_timeline', params: {
        'p_fec_cand_id': fecCandId,
      });
      if (response is List) return response.cast<Map<String, dynamic>>();
      return [];
    } catch (e) {
      debugPrint('❌ CandidateRepository.getFECContributionTimeline error: $e');
      return [];
    }
  }

  /// Fetch recent FEC contributions for a federal candidate
  Future<List<Map<String, dynamic>>> getFECRecentContributions(String fecCandId, {int limit = 50}) async {
    if (!isReady) return [];
    try {
      final response = await _client.rpc('get_fec_recent_contributions', params: {
        'p_fec_cand_id': fecCandId,
        'p_limit': limit,
      });
      if (response is List) return response.cast<Map<String, dynamic>>();
      return [];
    } catch (e) {
      debugPrint('❌ CandidateRepository.getFECRecentContributions error: $e');
      return [];
    }
  }

  /// Fetch committees linked to a federal candidate
  Future<List<Map<String, dynamic>>> getFECCommittees(String fecCandId) async {
    if (!isReady) return [];
    try {
      final response = await _client.rpc('get_fec_committees_for_candidate', params: {
        'p_fec_cand_id': fecCandId,
      });
      if (response is List) return response.cast<Map<String, dynamic>>();
      return [];
    } catch (e) {
      debugPrint('❌ CandidateRepository.getFECCommittees error: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  DISTRICT CANDIDATES — same race lookup
  // ═══════════════════════════════════════════════════════════════

  /// Get all candidates running for the same office in the same district
  Future<List<Candidate>> getDistrictCandidates(String office, String district) async {
    if (!isReady) return [];

    try {
      final response = await _client
          
          .from('candidates')
          .select()
          .eq('office', office)
          .eq('district', district)
          .order('party');

      return (response as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(Candidate.fromJson)
          .toList();
    } catch (e) {
      debugPrint('❌ CandidateRepository.getDistrictCandidates error: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  CONTACT LOG — full CRUD
  // ═══════════════════════════════════════════════════════════════

  /// Add a contact log entry with all fields
  Future<CandidateContact?> addContactLog(
    String candidateId,
    String contactType,
    String? notes,
    String? outcome, {
    String? subject,
    String? contactedBy,
    String? followUpDate,
  }) async {
    return addContact({
      'candidate_id': candidateId,
      'contact_type': contactType,
      'notes': notes,
      'outcome': outcome,
      'subject': subject,
      'contacted_by': contactedBy,
      'contact_date': DateTime.now().toIso8601String(),
      'follow_up_date': followUpDate,
    });
  }

  /// Delete a contact log entry
  Future<void> deleteContactLog(String contactId) async {
    if (!isReady) return;

    try {
      await _client
          
          .from('candidate_contacts')
          .delete()
          .eq('id', contactId);
    } catch (e) {
      debugPrint('❌ CandidateRepository.deleteContactLog error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  ENDORSEMENTS — dedicated table operations
  // ═══════════════════════════════════════════════════════════════

  /// Fetch endorsements from the dedicated table
  Future<List<Map<String, dynamic>>> fetchCandidateEndorsements(String candidateId) async {
    if (!isReady) return [];

    try {
      final response = await _client
          
          .from('candidate_endorsements')
          .select()
          .eq('candidate_id', candidateId)
          .order('created_at', ascending: false);

      return (response as List<dynamic>).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('❌ CandidateRepository.fetchCandidateEndorsements error: $e');
      return [];
    }
  }

  /// Add an endorsement for a candidate
  Future<Map<String, dynamic>?> addEndorsement(
    String candidateId,
    String endorser,
    String type, {
    String? notes,
    String? endorserUrl,
  }) async {
    if (!isReady) return null;

    try {
      final response = await _client
          
          .from('candidate_endorsements')
          .insert({
            'candidate_id': candidateId,
            'endorser_name': endorser,
            'endorsement_type': type,
            'notes': notes,
            'endorser_url': endorserUrl,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      return response;
    } catch (e) {
      debugPrint('❌ CandidateRepository.addEndorsement error: $e');
      return null;
    }
  }

  /// Remove an endorsement
  Future<void> removeEndorsement(String endorsementId) async {
    if (!isReady) return;

    try {
      await _client
          
          .from('candidate_endorsements')
          .delete()
          .eq('id', endorsementId);
    } catch (e) {
      debugPrint('❌ CandidateRepository.removeEndorsement error: $e');
    }
  }

  /// Toggle the MOYD endorsed flag on the candidate record
  Future<void> toggleMOYDEndorsed(String candidateId) async {
    if (!isReady) return;

    try {
      final current = await fetchCandidate(candidateId);
      if (current == null) return;
      await updateCandidate(candidateId, {
        'moyd_endorsed': !current.isEndorsed,
        'endorsement_status': !current.isEndorsed ? 'endorsed' : 'not_endorsed',
      });
    } catch (e) {
      debugPrint('❌ CandidateRepository.toggleMOYDEndorsed error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  ADJACENT DISTRICTS — for District Intel tab
  // ═══════════════════════════════════════════════════════════════

  /// Get candidates in adjacent districts (±3 from current)
  Future<Map<String, List<Candidate>>> getAdjacentDistrictCandidates(String district) async {
    if (!isReady) return {};

    final distNum = int.tryParse(district);
    if (distNum == null) return {};

    try {
      final result = <String, List<Candidate>>{};
      for (int i = distNum - 3; i <= distNum + 3; i++) {
        if (i < 1 || i > 163 || i == distNum) continue;
        final candidates = await fetchCandidatesByDistrict(i.toString());
        if (candidates.isNotEmpty) {
          result[i.toString()] = candidates;
        }
      }
      return result;
    } catch (e) {
      debugPrint('❌ CandidateRepository.getAdjacentDistrictCandidates error: $e');
      return {};
    }
  }

  /// Get candidates with upcoming follow-ups
  Future<List<Candidate>> fetchUpcomingFollowUps() async {
    if (!isReady) return [];

    try {
      final response = await _client
          
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
  final int withMecCommittee;
  final int withFecCandidate;
  final int withAnyFinance;
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
    this.withMecCommittee = 0,
    this.withFecCandidate = 0,
    this.withAnyFinance = 0,
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

  double get mecFiledPercent =>
      totalCandidates > 0 ? withMecCommittee / totalCandidates * 100 : 0;

  double get fecFiledPercent =>
      totalCandidates > 0 ? withFecCandidate / totalCandidates * 100 : 0;

  double get anyFinancePercent =>
      totalCandidates > 0 ? withAnyFinance / totalCandidates * 100 : 0;
}
