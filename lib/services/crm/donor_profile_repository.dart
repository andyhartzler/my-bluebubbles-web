import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/models/crm/donor_profile.dart';
import 'supabase_service.dart';

class DonorProfileRepository {
  final CRMSupabaseService _supabase = CRMSupabaseService();

  bool get isReady => CRMConfig.crmEnabled && _supabase.isInitialized;

  SupabaseClient get _readClient =>
      _supabase.hasServiceRole ? _supabase.privilegedClient : _supabase.client;

  SupabaseClient get _writeClient => _supabase.privilegedClient;

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
