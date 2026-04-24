import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/models/crm/donor_enrichment_record.dart';
import 'package:bluebubbles/models/crm/donor_profile.dart';
import 'package:bluebubbles/models/crm/voter_file_record.dart';
import 'supabase_service.dart';
import 'voter_file_service.dart';

class DonorProfileRepository {
  final CRMSupabaseService _supabase = CRMSupabaseService();

  bool get isReady => CRMConfig.crmEnabled && _supabase.isInitialized;

  SupabaseClient get _readClient => _supabase.client;

  SupabaseClient get _writeClient => _supabase.client;

  Future<({List<DonorProfileSearchResult> results, int totalCount})> searchProfiles({
    String? query,
    String? tier,
    String? county,
    String? congressionalDistrict,
    String? partyLean,
    double? minWealthScore,
    double? maxWealthScore,
    double? minPoliticalGiving,
    bool? hasEnrichment,
    bool? hasVan,
    bool? hasPropertyRecords,
    bool? isHomeowner,
    List<String>? tags,
    String sortBy = 'last_name',
    bool ascending = true,
    int page = 0,
    int pageSize = 25,
  }) async {
    if (!isReady) return (results: <DonorProfileSearchResult>[], totalCount: 0);

    try {
      final response = await _readClient.rpc('search_donor_profiles', params: {
        'search_query': query,
        'filter_tier': tier,
        'filter_party': partyLean,
        'filter_county': county,
        'filter_cd': congressionalDistrict,
        'filter_min_donated': minPoliticalGiving,
        'filter_min_wealth': minWealthScore,
        'filter_max_wealth': maxWealthScore,
        'filter_has_enrichment': hasEnrichment,
        'filter_has_van': hasVan,
        'sort_by': sortBy,
        'sort_dir': ascending ? 'asc' : 'desc',
        'page_num': page + 1, // SQL function is 1-based
        'page_size': pageSize,
      });

      final rows = (response as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();

      final totalCount = rows.isNotEmpty
          ? (rows.first['total_count'] as num?)?.toInt() ?? 0
          : 0;

      final results = rows
          .map(DonorProfileSearchResult.fromJson)
          .toList();

      return (results: results, totalCount: totalCount);
    } catch (e) {
      debugPrint('❌ Error searching donor profiles: $e');
      return (results: <DonorProfileSearchResult>[], totalCount: 0);
    }
  }

  Future<DonorProfile?> getFullProfile(String profileId) async {
    if (!isReady) return null;

    try {
      final response = await _readClient.rpc('get_donor_profile_full', params: {
        'p_profile_id': profileId,
      });

      if (response == null) return null;
      return DonorProfile.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('❌ Error fetching full donor profile: $e');
      return null;
    }
  }

  Future<void> updateProfile(String profileId, Map<String, dynamic> fields) async {
    if (!isReady) return;

    try {
      await _writeClient
          .from('donor_profiles')
          .update(fields)
          .eq('id', profileId);
    } catch (e) {
      debugPrint('❌ Error updating donor profile: $e');
    }
  }

  Future<void> addTag(String profileId, String tagName) async {
    if (!isReady) return;

    try {
      await _writeClient.from('donor_tags').insert({
        'profile_id': profileId,
        'tag_name': tagName,
      });
    } catch (e) {
      debugPrint('❌ Error adding tag: $e');
    }
  }

  Future<void> removeTag(String profileId, String tagName) async {
    if (!isReady) return;

    try {
      await _writeClient
          .from('donor_tags')
          .delete()
          .eq('profile_id', profileId)
          .eq('tag_name', tagName);
    } catch (e) {
      debugPrint('❌ Error removing tag: $e');
    }
  }

  Future<void> logActivity(String profileId, String type, String title, String? description) async {
    if (!isReady) return;

    try {
      await _writeClient.from('donor_activity_log').insert({
        'profile_id': profileId,
        'activity_type': type,
        'title': title,
        'description': description,
      });
    } catch (e) {
      debugPrint('❌ Error logging activity: $e');
    }
  }

  Future<void> logCallOutcome(String profileId, String outcome, {double? pledgeAmount, String? notes}) async {
    if (!isReady) return;

    try {
      await _writeClient.from('donor_call_outcomes').insert({
        'profile_id': profileId,
        'outcome': outcome,
        'pledge_amount': pledgeAmount,
        'notes': notes,
        'called_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('❌ Error logging call outcome: $e');
    }
  }

  Future<List<ContributionRecord>> getContributions(String profileId, {String? source, int page = 0, int pageSize = 50}) async {
    if (!isReady) return [];

    try {
      var query = _readClient
          .from('donor_profile_contributions')
          .select()
          .eq('profile_id', profileId);

      if (source != null) {
        query = query.eq('source', source);
      }

      final start = page * pageSize;
      final end = start + pageSize - 1;

      final response = await query
          .order('contribution_date', ascending: false)
          .range(start, end);

      return (response as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ContributionRecord.fromJson)
          .toList();
    } catch (e) {
      debugPrint('❌ Error fetching contributions: $e');
      return [];
    }
  }

  Future<List<String>> getAllTags() async {
    if (!isReady) return [];

    try {
      final response = await _readClient
          .from('donor_tags')
          .select('tag_name')
          .order('tag_name', ascending: true);

      final tags = (response as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((row) => row['tag_name'] as String)
          .toSet()
          .toList();

      return tags;
    } catch (e) {
      debugPrint('❌ Error fetching tags: $e');
      return [];
    }
  }

  /// Resolve a donor profile's `mo_voter_file_id`, then fetch the full
  /// MO voter-file record via [VoterFileService].
  ///
  /// Returns null if the profile has no voter-file linkage, or on any
  /// error (caller should render no card).
  Future<VoterFileRecord?> fetchVoterRecordForProfile(String profileId) async {
    if (!isReady) return null;
    try {
      final row = await _readClient
          .from('donor_profiles')
          .select('mo_voter_file_id')
          .eq('id', profileId)
          .maybeSingle();
      if (row == null) return null;
      final voterId = row['mo_voter_file_id'] as String?;
      if (voterId == null || voterId.isEmpty) return null;
      return VoterFileService.fetchRecord(voterId);
    } catch (e) {
      debugPrint('❌ fetchVoterRecordForProfile: $e');
      return null;
    }
  }

  /// Bulk-fetch the set of donor_profiles (from the given [profileIds])
  /// that have a non-null `mo_voter_file_id` linkage. Used by the donor
  /// command center to show a "registered voter" indicator per row
  /// without refactoring the `search_donor_profiles` RPC.
  ///
  /// Returns an empty set on error or when [profileIds] is empty.
  Future<Set<String>> fetchVoterFileIdsForProfiles(
      List<String> profileIds) async {
    if (!isReady || profileIds.isEmpty) return <String>{};
    try {
      final rows = await _readClient
          .from('donor_profiles')
          .select('id,mo_voter_file_id')
          .inFilter('id', profileIds)
          .not('mo_voter_file_id', 'is', null);

      final list = (rows as List<dynamic>? ?? []).whereType<Map<String, dynamic>>();
      return list
          .map((r) => r['id'] as String?)
          .whereType<String>()
          .toSet();
    } catch (e) {
      debugPrint('❌ fetchVoterFileIdsForProfiles: $e');
      return <String>{};
    }
  }

  /// Fetch the `donor_enrichment` row for a donor profile. Only selects
  /// the columns mapped by [DonorEnrichmentRecord] — skips the ~100
  /// null-only columns in the table.
  ///
  /// Returns null if there is no enrichment row or on error. Callers
  /// should also check [DonorEnrichmentRecord.hasData] before rendering
  /// — an empty record should not produce a card.
  /// Fetch enrichment using a `donor_profiles.id` UUID as the anchor.
  /// Routes: donor_profiles.mec_donor_id → mec_donors.id → donor_enrichment.donor_id.
  /// Used by [DonorProfileScreen], which only has a donor_profiles UUID.
  Future<DonorEnrichmentRecord?> fetchEnrichmentRecordByProfileUuid(
    String profileUuid,
  ) async {
    if (!isReady) return null;
    try {
      final profile = await _readClient
          .from('donor_profiles')
          .select('mec_donor_id')
          .eq('id', profileUuid)
          .maybeSingle();
      final mecDonorId = profile?['mec_donor_id'];
      if (mecDonorId == null) return null;
      return await fetchEnrichmentRecord(mecDonorId.toString());
    } catch (e) {
      debugPrint('❌ fetchEnrichmentRecordByProfileUuid: $e');
      return null;
    }
  }

  /// Fetch a donor_enrichment row keyed by `mec_donors.id` (the canonical donor
  /// identity). [donorId] is the bigint PK from `public.mec_donors`. Call with
  /// a string (e.g. from an RPC payload) — we cast server-side.
  ///
  /// Returns null if there is no enrichment row or on error.
  Future<DonorEnrichmentRecord?> fetchEnrichmentRecord(String donorId) async {
    if (!isReady) return null;
    try {
      final row = await _readClient
          .from('donor_enrichment')
          .select(
            'id,full_name,gender,age_estimate,party_lean,party_lean_confidence,'
            'current_city,current_zip,current_county,congressional_district,'
            'total_political_donations,donation_count,avg_donation,'
            'donation_frequency,is_homeowner,wealth_score,mo_voter_file_id,'
            'generation,ethnicity,current_address_line1,current_address_line2,'
            'current_state,phone_mobile,phone_home,email_personal,'
            'social_profile_count,current_employer,current_job_title,'
            'estimated_income_range,engagement_score,giving_capacity_estimate',
          )
          .eq('donor_id', donorId)
          .maybeSingle();
      if (row == null) return null;
      return DonorEnrichmentRecord.fromJson(row);
    } catch (e) {
      debugPrint('❌ fetchEnrichmentRecord: $e');
      return null;
    }
  }

  Future<DonorProfileStats> getDonorStats() async {
    if (!isReady) return DonorProfileStats.empty();

    try {
      final response = await _readClient.rpc('get_donor_profile_stats');

      if (response == null) return DonorProfileStats.empty();
      return DonorProfileStats.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('❌ Error fetching donor profile stats: $e');
      return DonorProfileStats.empty();
    }
  }
}
