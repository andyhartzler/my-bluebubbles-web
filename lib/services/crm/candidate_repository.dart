import 'dart:io' as io;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/models/crm/candidate.dart';
import 'package:bluebubbles/models/crm/voter_file_record.dart';

import 'supabase_service.dart';
import 'voter_file_service.dart';

// ═══════════════════════════════════════════════════════════════
//  CANDIDATE REPOSITORY
//  Full CRUD + analytics for the `public.candidates` table,
//  plus contact logs, news mentions, election history, and
//  district demographics from related tables.
// ═══════════════════════════════════════════════════════════════

class CandidateRepository {
  final CRMSupabaseService _supabase = CRMSupabaseService();

  bool get isReady => CRMConfig.crmEnabled && _supabase.isInitialized;

  SupabaseClient get _client => _supabase.client;

  // ── Finance data cache (1hr TTL) ──────────────────────────────
  // Avoids re-firing 11 RPCs every time the Money tab is opened.
  static final Map<String, _CachedFinance> _financeCache = {};

  Map<String, dynamic>? getCachedFinanceSummary(String mecId) {
    final c = _financeCache[mecId];
    if (c == null) return null;
    if (DateTime.now().difference(c.fetchedAt).inMinutes > 60) {
      _financeCache.remove(mecId);
      return null;
    }
    return c.summary;
  }

  void cacheFinanceSummary(String mecId, Map<String, dynamic> summary) {
    _financeCache[mecId] = _CachedFinance(summary: summary, fetchedAt: DateTime.now());
  }

  /// Static cache-clear for use from UserSessionProvider.clearSession().
  /// Prevents cross-user leakage of finance data when one user logs out
  /// and another logs in (Wave 2 audit §A.5 / §B.3).
  static void clearFinanceCache() {
    _financeCache.clear();
  }

  // ── Endorsement-survey headshot lookup (candidate_id → public URL) ─────
  //
  // Candidates upload a headshot when they submit the public endorsement
  // survey. When present, that headshot is the canonical face for the
  // candidate everywhere in the CRM (see Candidate.avatarUrl). We resolve the
  // whole map in one query and cache it (1hr TTL) so list pages don't fan out
  // per-row lookups.
  static const String endorsementFormId =
      '945738f0-ff66-420f-8707-afb4a23ca58b';
  static Map<String, String>? _headshotCache;
  static DateTime? _headshotFetchedAt;

  /// Clear the endorsement-headshot cache (session teardown + manual refresh).
  static void clearHeadshotCache() {
    _headshotCache = null;
    _headshotFetchedAt = null;
  }

  /// Map of candidateId → latest submitted endorsement-survey headshot URL.
  /// Only rows with a non-null `candidate_id` and a usable headshot are
  /// included; ordering by `created_at desc` + first-wins keeps the newest
  /// submission per candidate. Cached for an hour.
  Future<Map<String, String>> fetchEndorsementHeadshots(
      {bool forceRefresh = false}) async {
    if (!isReady) return const {};
    final cached = _headshotCache;
    if (!forceRefresh &&
        cached != null &&
        _headshotFetchedAt != null &&
        DateTime.now().difference(_headshotFetchedAt!).inMinutes < 60) {
      return cached;
    }
    try {
      final response = await _client
          .from('form_submissions')
          .select('candidate_id, data, created_at')
          .eq('form_id', endorsementFormId)
          .eq('status', 'submitted')
          .not('candidate_id', 'is', null)
          .order('created_at', ascending: false);

      final map = <String, String>{};
      for (final row in (response as List<dynamic>)) {
        if (row is! Map) continue;
        final cid = row['candidate_id'] as String?;
        if (cid == null || map.containsKey(cid)) continue; // first row = latest
        final url = _headshotUrlFromData(row['data']);
        if (url != null && url.isNotEmpty) map[cid] = url;
      }
      _headshotCache = map;
      _headshotFetchedAt = DateTime.now();
      return map;
    } catch (e) {
      debugPrint('❌ CandidateRepository.fetchEndorsementHeadshots error: $e');
      return _headshotCache ?? const {};
    }
  }

  /// Pull the first headshot URL out of a form_submissions `data` blob.
  /// Shape: data['headshot'] = [{url, name, storage_path, …}]. The
  /// form-uploads bucket is public so the url resolves directly.
  static String? _headshotUrlFromData(dynamic data) {
    if (data is! Map) return null;
    final hs = data['headshot'];
    if (hs is List && hs.isNotEmpty && hs.first is Map) {
      final url = (hs.first as Map)['url'];
      if (url is String && url.isNotEmpty) return url;
    }
    return null;
  }

  /// Merge the cached endorsement headshots onto a batch of candidates. Only
  /// candidates whose id is in [headshots] are copied; the rest are returned
  /// untouched so existing avatar behavior is preserved.
  List<Candidate> _applyHeadshots(
      List<Candidate> candidates, Map<String, String> headshots) {
    if (headshots.isEmpty) return candidates;
    return candidates.map((c) {
      final url = headshots[c.id];
      if (url == null || url.isEmpty) return c;
      return c.copyWith(endorsementHeadshotUrl: url);
    }).toList();
  }

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
        query = query.eq('moyd_assigned_to', assignedTo);
      }
      // District range — use the `district_num` generated column (integer) so
      // the DB does the filtering with an index instead of parsing text client-side.
      if (minDistrict != null) {
        query = query.gte('district_num', minDistrict);
      }
      if (maxDistrict != null) {
        query = query.lte('district_num', maxDistrict);
      }

      final response = await query
          .order(sortBy, ascending: ascending)
          .range(offset, offset + limit - 1);

      final results = (response as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(Candidate.fromJson)
          .toList();

      return _applyHeadshots(results, await fetchEndorsementHeadshots());
    } catch (e) {
      debugPrint('❌ CandidateRepository.fetchCandidates error: $e');
      return [];
    }
  }

  // ─── Fetch single candidate ────────────────────────────────────

  /// Embedded select string used by [fetchCandidate] to bring along the
  /// joined legislator headshot, the team member assigned to this candidate,
  /// and the candidate's linked MOYD member. PostgREST resolves the FK
  /// embeds via the FK names — for the two members joins we have to
  /// disambiguate because both go to the same target table.
  static const _candidateDetailSelect =
      '*,'
      'legislator:legislation_legislators!candidates_legislator_id_fkey('
      '  id,name,first_name,last_name,photo_url,chamber,district,party'
      '),'
      'assigned_member:members!candidates_moyd_assigned_to_fkey('
      '  id,name,email,profile_pictures,executive_committee,'
      '  executive_title,executive_role,date_joined'
      '),'
      'linked_member:members!candidates_member_id_fkey('
      '  id,name,email,profile_pictures,executive_committee,'
      '  executive_title,executive_role,date_joined'
      ')';

  Future<Candidate?> fetchCandidate(String id) async {
    if (!isReady) return null;

    try {
      final response = await _client
          .from('candidates')
          .select(_candidateDetailSelect)
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      return _withHeadshot(Candidate.fromJson(response));
    } catch (e) {
      debugPrint('❌ CandidateRepository.fetchCandidate error: $e');
      // If the embedded select hits a missing FK relationship name on a
      // staging DB, fall back to the bare select so the screen still loads.
      try {
        final fallback = await _client
            .from('candidates')
            .select()
            .eq('id', id)
            .maybeSingle();
        if (fallback == null) return null;
        return _withHeadshot(Candidate.fromJson(fallback));
      } catch (_) {
        return null;
      }
    }
  }

  /// Merge the endorsement headshot onto a single candidate (detail header).
  Future<Candidate> _withHeadshot(Candidate candidate) async {
    final headshots = await fetchEndorsementHeadshots();
    final merged = _applyHeadshots([candidate], headshots);
    return merged.first;
  }

  // ─── Fetch the MO voter-file record for this candidate ─────────
  //
  // Delegates to VoterFileService — the single shared PK lookup against
  // public.mo_voter_file (4.34M rows).
  Future<VoterFileRecord?> fetchVoterRecord(String? voterId) =>
      VoterFileService.fetchRecord(voterId);

  // ─── Lightweight fetch for analytics (fewer columns → smaller payload) ──

  static const _analyticsColumns =
      'id,name,party,district,office,office_level,is_young_dem,estimated_age,'
      'campaign_website,social_twitter,social_facebook,social_instagram,'
      'moyd_endorsed,moyd_contacted,young_dem_score,photo_url,'
      'mec_committee_ids,fec_candidate_id,member_id,date_of_birth';

  Future<List<Candidate>> fetchCandidatesForAnalytics() async {
    if (!isReady) return [];
    try {
      // PostgREST caps a single request at 1000 rows. The candidates table is
      // ~2869 rows and growing, so paginate to exhaustion instead of silently
      // truncating analytics to the first page.
      final all = <Candidate>[];
      const pageSize = 1000;
      var offset = 0;
      while (true) {
        final response = await _client
            .from('candidates')
            .select(_analyticsColumns)
            .order('name')
            .range(offset, offset + pageSize - 1);
        final rows = (response as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .map(Candidate.fromJson)
            .toList();
        all.addAll(rows);
        if (rows.length < pageSize) break;
        offset += pageSize;
      }
      return all;
    } catch (e) {
      debugPrint('❌ CandidateRepository.fetchCandidatesForAnalytics error: $e');
      return [];
    }
  }

  /// Fetch every candidate matching the given filters by paginating past the
  /// PostgREST 1000-row cap. Used by the full candidates list pages, which
  /// previously requested a fixed cap (600/500) that silently dropped rows.
  Future<List<Candidate>> fetchAllCandidates({
    String? searchQuery,
    String? party,
    String? officeLevel,
    String? district,
    bool? isYoungDem,
    bool? isEndorsed,
    bool? isContacted,
    bool? hasCampaignSite,
    String sortBy = 'name',
    bool ascending = true,
  }) async {
    if (!isReady) return [];
    final all = <Candidate>[];
    const pageSize = 1000;
    var offset = 0;
    while (true) {
      final page = await fetchCandidates(
        searchQuery: searchQuery,
        party: party,
        officeLevel: officeLevel,
        district: district,
        isYoungDem: isYoungDem,
        isEndorsed: isEndorsed,
        isContacted: isContacted,
        hasCampaignSite: hasCampaignSite,
        sortBy: sortBy,
        ascending: ascending,
        limit: pageSize,
        offset: offset,
      );
      all.addAll(page);
      if (page.length < pageSize) break;
      offset += pageSize;
    }
    return all;
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

      final results = (response as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(Candidate.fromJson)
          .toList();
      return _applyHeadshots(results, await fetchEndorsementHeadshots());
    } catch (e) {
      debugPrint('❌ CandidateRepository.fetchYoungDemocrats error: $e');
      return [];
    }
  }

  // ─── YD primarying-incumbent-Democrat detection ────────────────

  /// Fetch every (Young Dem challenger, incumbent Dem) pair running in
  /// the same seat via the `get_yd_primary_challengers()` RPC. Authoritative
  /// source for the Candidates-page primary-challenger view.
  Future<List<Map<String, dynamic>>> fetchPrimaryChallengePairs() async {
    if (!isReady) return const [];
    try {
      final data = await _client.rpc('get_yd_primary_challengers');
      return (data as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('❌ CandidateRepository.fetchPrimaryChallengePairs error: $e');
      return const [];
    }
  }

  /// Fetch every candidate running for a specific (office, district). Used by
  /// the district-sidebar panel on the split-screen candidates page so the
  /// right-side widget can list the seat's field without re-slicing the
  /// main results list.
  Future<List<Candidate>> fetchCandidatesForDistrict({
    required String office,
    required String district,
  }) async {
    if (!isReady) return const [];
    try {
      final data = await _client
          .from('candidates')
          .select()
          .eq('office', office)
          .eq('district', district)
          .order('incumbent', ascending: false)
          .order('name');
      return (data as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>()
          .map(Candidate.fromJson)
          .toList();
    } catch (e) {
      debugPrint('❌ CandidateRepository.fetchCandidatesForDistrict error: $e');
      return const [];
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
      'moyd_endorsement_status': endorsed ? 'endorsed' : 'not_endorsed',
    });
  }

  // ─── Mark as contacted ─────────────────────────────────────────

  Future<void> markContacted(String id, String method) async {
    await updateCandidate(id, {
      'moyd_contacted': true,
      'moyd_contact_date': DateTime.now().toIso8601String(),
      'moyd_contact_method': method,
    });
  }

  // ─── Assign team member ────────────────────────────────────────
  //
  // candidates.moyd_assigned_to is uuid REFERENCES members(id). The historical
  // `assignTeamMember(id, memberName)` signature was a footgun — name strings
  // never passed type validation and silently failed. The current contract
  // takes a member UUID (or null to unassign).

  Future<void> assignTeamMember(String candidateId, String? memberId) async {
    await updateCandidate(candidateId, {'moyd_assigned_to': memberId});
  }

  // ─── Exec committee roster (for the Assigned-To picker) ────────
  //
  // Returns the executive_committee=true subset of public.members ordered
  // by name. The Intel tab caches this once per detail screen so the
  // bottom-sheet picker opens instantly.

  /// Find likely MOYD member matches for an unlinked candidate.
  ///
  /// Strategy: prefer email-exact, fall back to name-exact (first+last).
  /// Returns at most 5 candidates so the picker stays compact. Used by
  /// the Intel tab's "Possible matches" panel.
  Future<List<Map<String, dynamic>>> findPossibleMemberMatches({
    String? firstName,
    String? lastName,
    String? email,
  }) async {
    if (!isReady) return [];
    final results = <Map<String, dynamic>>[];
    try {
      if (email != null && email.isNotEmpty) {
        final byEmail = await _client
            .from('members')
            .select('id,name,email,profile_pictures,executive_title,date_joined')
            .ilike('email', email)
            .limit(5);
        results.addAll(
          (byEmail as List).whereType<Map>().map(
                (m) => m.map((k, v) => MapEntry(k.toString(), v)),
              ),
        );
      }
      if (results.length < 5 &&
          firstName != null && firstName.isNotEmpty &&
          lastName != null && lastName.isNotEmpty) {
        final byName = await _client
            .from('members')
            .select('id,name,email,profile_pictures,executive_title,date_joined')
            .ilike('first_name', firstName)
            .ilike('last_name', lastName)
            .limit(5);
        for (final m in (byName as List).whereType<Map>()) {
          final mapped = m.map((k, v) => MapEntry(k.toString(), v));
          if (!results.any((e) => e['id'] == mapped['id'])) {
            results.add(mapped);
          }
        }
      }
      return results.take(5).toList();
    } catch (e) {
      debugPrint('❌ CandidateRepository.findPossibleMemberMatches error: $e');
      return [];
    }
  }

  /// Link a candidate row to a MOYD member uuid (sets candidates.member_id).
  /// Used by the Intel tab "Link" CTA on possible-match tiles.
  Future<void> linkCandidateToMember(String candidateId, String memberId) async {
    await updateCandidate(candidateId, {'member_id': memberId});
  }

  /// Fetch a single member row by id. Used by the Intel tab MOYD Member
  /// Status tile when the candidate's linked_member embed didn't populate
  /// (PostgREST's FK embed occasionally falls back to the bare select).
  Future<Map<String, dynamic>?> fetchMemberById(String memberId) async {
    if (!isReady) return null;
    try {
      final row = await _client
          .from('members')
          .select(
            'id,name,email,profile_pictures,executive_committee,'
            'executive_title,executive_role,date_joined',
          )
          .eq('id', memberId)
          .maybeSingle();
      if (row == null) return null;
      if (row is Map<String, dynamic>) return row;
      final asMap = row as Map;
      return asMap.map((k, v) => MapEntry(k.toString(), v));
    } catch (e) {
      debugPrint('❌ CandidateRepository.fetchMemberById error: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getExecCommitteeMembers() async {
    if (!isReady) return [];
    try {
      final rows = await _client
          .from('members')
          .select('id,name,email,profile_pictures,executive_title,'
              'executive_role,date_joined')
          .eq('executive_committee', true)
          .order('name', ascending: true);
      return (rows as List)
          .whereType<Map>()
          .map((m) => m.map((k, v) => MapEntry(k.toString(), v)))
          .toList();
    } catch (e) {
      debugPrint('❌ CandidateRepository.getExecCommitteeMembers error: $e');
      return [];
    }
  }

  // ─── Find a likely member match for an unlinked candidate ──────
  //
  // Used by the Intel tab → MOYD Member Status card. Tries email first
  // (cheapest, highest confidence), then a (first_name, last_name) match.
  // Returns null if nothing plausible came back.

  Future<Map<String, dynamic>?> findMemberByEmailOrName({
    String? email,
    String? firstName,
    String? lastName,
  }) async {
    if (!isReady) return null;
    final cleanedEmail = email?.trim().toLowerCase();
    try {
      if (cleanedEmail != null && cleanedEmail.isNotEmpty) {
        // Try primary email then school_email as a fallback. We avoid `or()`
        // because email values can legitimately contain `+`/`,` which the
        // PostgREST or-filter doesn't escape cleanly.
        final byPrimary = await _client
            .from('members')
            .select('id,name,email,profile_pictures,executive_title,'
                'executive_role,date_joined')
            .eq('email', cleanedEmail)
            .limit(1)
            .maybeSingle();
        if (byPrimary != null) {
          return (byPrimary).map((k, v) => MapEntry(k.toString(), v));
        }
        final bySchool = await _client
            .from('members')
            .select('id,name,email,profile_pictures,executive_title,'
                'executive_role,date_joined')
            .eq('school_email', cleanedEmail)
            .limit(1)
            .maybeSingle();
        if (bySchool != null) {
          return (bySchool).map((k, v) => MapEntry(k.toString(), v));
        }
      }
      final fn = firstName?.trim();
      final ln = lastName?.trim();
      if (fn == null || ln == null || fn.isEmpty || ln.isEmpty) return null;
      // ILIKE name pattern — keeps it simple and avoids tsvector tokenizer
      // surprises on hyphenated names.
      final byName = await _client
          .from('members')
          .select('id,name,email,profile_pictures,executive_title,'
              'executive_role,date_joined')
          .ilike('name', '$fn $ln')
          .limit(1)
          .maybeSingle();
      if (byName == null) return null;
      return (byName).map((k, v) => MapEntry(k.toString(), v));
    } catch (e) {
      debugPrint('❌ CandidateRepository.findMemberByEmailOrName error: $e');
      return null;
    }
  }

  // ─── Latest membership card for a member (status + expiration) ──

  Future<Map<String, dynamic>?> fetchLatestMembershipCard(String memberId) async {
    if (!isReady) return null;
    try {
      final row = await _client
          .from('membership_cards')
          .select('card_status,activation_date,expiration_date,updated_at')
          .eq('member_id', memberId)
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row == null) return null;
      return (row as Map).map((k, v) => MapEntry(k.toString(), v));
    } catch (e) {
      debugPrint('❌ CandidateRepository.fetchLatestMembershipCard error: $e');
      return null;
    }
  }

  // ─── Link this candidate to a MOYD member ──────────────────────
  Future<void> linkToMember(String candidateId, String? memberId) async {
    await updateCandidate(candidateId, {'member_id': memberId});
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

  // ─── Upload candidate photo ────────────────────────────────────

  /// Upload a candidate profile photo to the `candidate-photos` bucket and
  /// persist the resulting public URL as `candidates.photo_url`.
  /// Returns the new photo URL (or null on failure).
  Future<String?> uploadCandidatePhoto({
    required String candidateId,
    required PlatformFile file,
  }) async {
    if (!isReady) return null;

    try {
      final bytes = await _resolveFileBytes(file);
      final now = DateTime.now().millisecondsSinceEpoch;
      final sanitized = _sanitizeFileName(file.name);
      final path = '$candidateId/$now-$sanitized';
      final contentType = lookupMimeType(file.name) ?? 'application/octet-stream';

      await _client.storage.from('candidate-photos').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: true),
          );

      final publicUrl = _client.storage.from('candidate-photos').getPublicUrl(path);
      await updateCandidate(candidateId, {'photo_url': publicUrl});
      return publicUrl;
    } catch (e) {
      debugPrint('❌ CandidateRepository.uploadCandidatePhoto error: $e');
      return null;
    }
  }

  Future<Uint8List> _resolveFileBytes(PlatformFile file) async {
    if (file.bytes != null) return file.bytes!;
    if (file.path != null && !kIsWeb) {
      return await io.File(file.path!).readAsBytes();
    }
    throw StateError('Selected file has no readable bytes.');
  }

  String _sanitizeFileName(String name) {
    final trimmed = name.trim().isEmpty ? 'candidate-photo' : name.trim();
    final safe = trimmed.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return safe.replaceAll(RegExp(r'_+'), '_');
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

      final results = (response as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(Candidate.fromJson)
          .toList();
      return _applyHeadshots(results, await fetchEndorsementHeadshots());
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

  Future<void> updateContactOutcome(String contactId, String outcome) async {
    if (!isReady) return;
    try {
      await _client
          .from('candidate_contacts')
          .update({'outcome': outcome})
          .eq('id', contactId);
    } catch (e) {
      debugPrint('❌ CandidateRepository.updateContactOutcome error: $e');
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
      // Use the DB-side pivot RPC for efficiency — aggregates per-candidate
      // rows into per-race (Dem vs Rep) results in SQL instead of Dart.
      final response = await _client.rpc('get_election_history_pivoted', params: {
        'p_district': district,
      });

      if (response == null) return [];

      final rows = (response is List)
          ? response.cast<Map<String, dynamic>>()
          : (response as List<dynamic>).cast<Map<String, dynamic>>();

      return rows.map(ElectionResult.fromJson).toList();
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
      // Single query with inFilter instead of N+1 individual fetches
      try {
        final response = await _client
            .from('candidates')
            .select()
            .inFilter('id', candidateIds);
        candidates = (response as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .map(Candidate.fromJson)
            .toList();
      } catch (e) {
        debugPrint('❌ CSV export fetch error: $e');
        candidates = [];
      }
    } else {
      candidates = await fetchCandidates(
        party: party,
        isYoungDem: isYoungDem,
        limit: 2000,
      );
    }

    String esc(String? s) => '"${(s ?? '').replaceAll('"', '""')}"';

    final buffer = StringBuffer();
    buffer.writeln(
        'Name,Party,Office,District,Age,Young Dem,Score,Email,Phone,Campaign Website,Endorsed,Contacted,Assigned To');
    for (final c in candidates) {
      buffer.writeln(
        '${esc(c.name)},${esc(c.party)},${esc(c.office)},${esc(c.district)},${c.estimatedAge ?? ''},${c.isYoungDem},${c.youngDemScore},${esc(c.email)},${esc(c.phone)},${esc(c.campaignWebsite)},${c.isEndorsed},${c.isContacted},${esc(c.assignedTo)}',
      );
    }
    return buffer.toString();
  }

  /// Bulk assign candidates to a team member (single query)
  Future<void> bulkAssign(List<String> candidateIds, String assignee) async {
    if (!isReady || candidateIds.isEmpty) return;
    try {
      await _client
          .from('candidates')
          .update({'moyd_assigned_to': assignee, 'updated_at': DateTime.now().toIso8601String()})
          .inFilter('id', candidateIds);
    } catch (e) {
      debugPrint('❌ bulkAssign error: $e');
    }
  }

  /// Bulk mark as contacted (single query)
  Future<void> bulkMarkContacted(
      List<String> candidateIds, String method) async {
    if (!isReady || candidateIds.isEmpty) return;
    try {
      await _client
          .from('candidates')
          .update({
            'moyd_contacted': true,
            'moyd_contact_date': DateTime.now().toIso8601String(),
            'moyd_contact_method': method,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .inFilter('id', candidateIds);
    } catch (e) {
      debugPrint('❌ bulkMarkContacted error: $e');
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
  Future<List<MECContribution>> getMECContributions(String mecId, {int limit = 5000}) async {
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

  /// Fetch contributions across multiple committees (aggregated view).
  /// Used when the candidate has >1 linked MEC committee and the user picks
  /// "All committees" in the switcher.
  Future<List<MECContribution>> getMECContributionsMulti(List<String> mecIds, {int limit = 5000}) async {
    if (!isReady || mecIds.isEmpty) return [];
    try {
      final response = await _client
          .from('mec_contributions')
          .select()
          .inFilter('mec_id', mecIds)
          .order('contribution_date', ascending: false)
          .limit(limit);
      return (response as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(MECContribution.fromJson)
          .toList();
    } catch (e) {
      debugPrint('❌ CandidateRepository.getMECContributionsMulti error: $e');
      return [];
    }
  }

  /// Fetch top donors for a committee (via Postgres function)
  Future<List<Map<String, dynamic>>> getMECTopDonors(String mecId, {int limit = 50}) async {
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

  /// Aggregated finance summary across multiple MEC committees.
  Future<Map<String, dynamic>> getMECFinanceSummaryMulti(List<String> mecIds) async {
    if (!isReady || mecIds.isEmpty) return {};
    try {
      final response = await _client.rpc('get_mec_finance_summary_multi', params: {
        'p_mec_ids': mecIds,
      });
      if (response is Map<String, dynamic>) return response;
      return {};
    } catch (e) {
      debugPrint('❌ CandidateRepository.getMECFinanceSummaryMulti error: $e');
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> getMECTopDonorsMulti(List<String> mecIds, {int limit = 50}) async {
    if (!isReady || mecIds.isEmpty) return [];
    try {
      final response = await _client.rpc('get_mec_top_donors_multi', params: {
        'p_mec_ids': mecIds,
        'p_limit': limit,
      });
      if (response is List) return response.cast<Map<String, dynamic>>();
      return [];
    } catch (e) {
      debugPrint('❌ CandidateRepository.getMECTopDonorsMulti error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getMECContributionTimelineMulti(List<String> mecIds) async {
    if (!isReady || mecIds.isEmpty) return [];
    try {
      final response = await _client.rpc('get_mec_contribution_timeline_multi', params: {
        'p_mec_ids': mecIds,
      });
      if (response is List) return response.cast<Map<String, dynamic>>();
      return [];
    } catch (e) {
      debugPrint('❌ CandidateRepository.getMECContributionTimelineMulti error: $e');
      return [];
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

  Future<Map<String, dynamic>> getMECExpenditureSummaryMulti(List<String> mecIds) async {
    if (!isReady || mecIds.isEmpty) return {};
    try {
      final response = await _client.rpc('get_mec_expenditure_summary_multi', params: {
        'p_mec_ids': mecIds,
      });
      if (response is Map<String, dynamic>) return response;
      return {};
    } catch (e) {
      debugPrint('❌ CandidateRepository.getMECExpenditureSummaryMulti error: $e');
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> getMECTopPayeesMulti(List<String> mecIds, {int limit = 50}) async {
    if (!isReady || mecIds.isEmpty) return [];
    try {
      final response = await _client.rpc('get_mec_top_payees_multi', params: {
        'p_mec_ids': mecIds,
        'p_limit': limit,
      });
      if (response is List) return response.cast<Map<String, dynamic>>();
      return [];
    } catch (e) {
      debugPrint('❌ CandidateRepository.getMECTopPayeesMulti error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getMECRecentExpendituresMulti(List<String> mecIds, {int limit = 20}) async {
    if (!isReady || mecIds.isEmpty) return [];
    try {
      final response = await _client
          .from('mec_expenditures')
          .select()
          .inFilter('mec_id', mecIds)
          .order('expenditure_date', ascending: false)
          .limit(limit);
      return (response as List<dynamic>).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('❌ CandidateRepository.getMECRecentExpendituresMulti error: $e');
      return [];
    }
  }

  /// Fetch top expenditure payees (via Postgres function)
  Future<List<Map<String, dynamic>>> getMECTopPayees(String mecId, {int limit = 50}) async {
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
  Future<List<Map<String, dynamic>>> getFECTopDonors(String fecCandId, {int limit = 50}) async {
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

      final results = (response as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(Candidate.fromJson)
          .toList();
      return _applyHeadshots(results, await fetchEndorsementHeadshots());
    } catch (e) {
      debugPrint('❌ CandidateRepository.getDistrictCandidates error: $e');
      return [];
    }
  }

  /// Fetch a historical candidate's full profile by their stable id.
  ///
  /// Migration 20260427_02 introduced
  /// `get_historical_candidate_profile_by_id(p_id uuid)` — name-keyed
  /// lookup is unsafe because scraper-bleed left rows whose `name` was
  /// just "Libertarian"/"Republican"/etc, and clicking those collapsed
  /// every party-named row across the state. We now key on the row's
  /// uuid, which is unique and survives any future merge.
  Future<Map<String, dynamic>?> getHistoricalCandidateProfile(String id) async {
    if (!isReady) return null;
    try {
      final response = await _client.rpc(
        'get_historical_candidate_profile_by_id',
        params: {'p_id': id},
      );
      return response is Map<String, dynamic> ? response : null;
    } catch (e) {
      debugPrint('❌ CandidateRepository.getHistoricalCandidateProfile error: $e');
      return null;
    }
  }

  /// Past candidates for a (district, office) pair. Office is required
  /// — the prior single-arg signature collided "District 81 State Rep"
  /// with "District 81 State Senator" and dumped both into the same
  /// panel.
  Future<List<Map<String, dynamic>>> getDistrictHistoricalCandidates(
    String district,
    String office,
  ) async {
    if (!isReady) return [];
    try {
      final response = await _client.rpc('get_district_historical_candidates', params: {
        'p_district': district,
        'p_office': office,
      });
      if (response == null) return [];
      return (response as List<dynamic>).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('❌ CandidateRepository.getDistrictHistoricalCandidates error: $e');
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
            'endorser': endorser,
            'endorser_type': type,
            'source_url': endorserUrl,
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
        'moyd_endorsement_status': !current.isEndorsed ? 'endorsed' : 'not_endorsed',
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

/// Cached finance summary with expiry.
class _CachedFinance {
  final Map<String, dynamic> summary;
  final DateTime fetchedAt;
  const _CachedFinance({required this.summary, required this.fetchedAt});
}
