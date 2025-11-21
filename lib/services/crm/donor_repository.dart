import 'package:postgrest/postgrest.dart' show CountOption, PostgrestFilterBuilder, PostgrestResponse;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/models/crm/donor.dart';

import 'supabase_service.dart';

class DonorRepository {
  final CRMSupabaseService _supabase = CRMSupabaseService();

  bool get isReady => CRMConfig.crmEnabled && _supabase.isInitialized;

  SupabaseClient get _readClient =>
      _supabase.hasServiceRole ? _supabase.privilegedClient : _supabase.client;

  Future<DonorFetchResult> fetchDonors({
    String? searchQuery,
    bool? recurring,
    bool? linkedToMember,
    double? minTotal,
    double? maxTotal,
    String sortBy = 'name',
    bool ascending = true,
    int? limit,
    int? offset,
    bool fetchTotalCount = false,
  }) async {
    if (!isReady) {
      return const DonorFetchResult(donors: []);
    }

    final allowedSorts = <String>{'name', 'total_donated', 'created_at', 'phone', 'member_id'};
    final resolvedSort = allowedSorts.contains(sortBy) ? sortBy : 'name';

    var query = _applyFilters(
      _readClient.from('donors').select('*'),
      searchQuery: searchQuery,
      recurring: recurring,
      linkedToMember: linkedToMember,
      minTotal: minTotal,
      maxTotal: maxTotal,
    ).order(resolvedSort, ascending: ascending).order('id', ascending: true);

    if (limit != null && offset != null) {
      query = query.range(offset, offset + limit - 1);
    } else if (limit != null) {
      query = query.limit(limit);
    }

    if (fetchTotalCount) {
      final PostgrestResponse response = await query.count(CountOption.exact);
      final donors = _mapDonors(response.data);
      return DonorFetchResult(donors: donors, totalCount: response.count);
    }

    final data = await query;
    return DonorFetchResult(donors: _mapDonors(data));
  }

  Future<Map<String, dynamic>> getDonorStats() async {
    if (!isReady) {
      return {
        'total': 0,
        'recurring': 0,
        'linked': 0,
        'totalRaised': 0.0,
      };
    }

    try {
      final PostgrestResponse totalResponse =
          await _readClient.from('donors').select('id').count(CountOption.exact);
      final total = totalResponse.count ?? 0;

      final PostgrestResponse recurringResponse = await _readClient
          .from('donors')
          .select('id')
          .eq('is_recurring_donor', true)
          .count(CountOption.exact);
      final recurring = recurringResponse.count ?? 0;

      final PostgrestResponse linkedResponse = await _readClient
          .from('donors')
          .select('id')
          .not('member_id', 'is', null)
          .count(CountOption.exact);
      final linked = linkedResponse.count ?? 0;

      final totalsResponse = await _readClient.from('donors').select('total_donated');
      final donations = (totalsResponse as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((row) => (row['total_donated'] as num?)?.toDouble() ?? 0.0)
          .toList();
      final totalRaised = donations.fold<double>(0, (sum, value) => sum + value);

      return {
        'total': total,
        'recurring': recurring,
        'linked': linked,
        'totalRaised': totalRaised,
      };
    } catch (e) {
      print('❌ Error fetching donor stats: $e');
      return {
        'total': 0,
        'recurring': 0,
        'linked': 0,
        'totalRaised': 0.0,
      };
    }
  }

  PostgrestFilterBuilder<dynamic> _applyFilters(
    PostgrestFilterBuilder<dynamic> query, {
    String? searchQuery,
    bool? recurring,
    bool? linkedToMember,
    double? minTotal,
    double? maxTotal,
  }) {
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final value = searchQuery.trim();
      query = query.or('name.ilike.%$value%,email.ilike.%$value%,phone.ilike.%$value%');
    }

    if (recurring != null) {
      query = query.eq('is_recurring_donor', recurring);
    }

    if (linkedToMember != null) {
      if (linkedToMember) {
        query = query.not('member_id', 'is', null);
      } else {
        query = query.isFilter('member_id', null);
      }
    }

    if (minTotal != null) {
      query = query.gte('total_donated', minTotal);
    }

    if (maxTotal != null) {
      query = query.lte('total_donated', maxTotal);
    }

    return query;
  }

  List<Donor> _mapDonors(dynamic data) {
    final list = (data as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(Donor.fromJson)
        .toList();
    return list;
  }
}
