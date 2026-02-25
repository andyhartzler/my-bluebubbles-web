import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/models/crm/mec_contribution.dart';
import 'package:bluebubbles/models/crm/mec_committee.dart';

import 'supabase_service.dart';

class MecRepository {
  final CRMSupabaseService _supabase = CRMSupabaseService();

  bool get isReady => CRMConfig.crmEnabled && _supabase.isInitialized;

  SupabaseClient get _readClient =>
      _supabase.hasServiceRole ? _supabase.privilegedClient : _supabase.client;

  // ---------------------------------------------------------------------------
  // searchDonors (RPC — aggregated donor search)
  // ---------------------------------------------------------------------------

  /// Smart donor search using the search_donors RPC function.
  ///
  /// Returns aggregated donor rows with total amounts, party affiliations,
  /// and committee counts rather than individual contributions.
  Future<List<Map<String, dynamic>>> searchDonors({
    String? state,
    int? yearFrom,
    int? yearTo,
    double? minTotal,
    double? maxTotal,
    String? party,
    String? nameQuery,
    bool individualsOnly = true,
    int limit = 100,
    int offset = 0,
  }) async {
    if (!isReady) return [];

    final params = <String, dynamic>{
      'p_individuals_only': individualsOnly,
      'p_limit': limit,
      'p_offset': offset,
    };
    if (state != null && state.isNotEmpty) params['p_state'] = state;
    if (yearFrom != null) params['p_year_from'] = yearFrom;
    if (yearTo != null) params['p_year_to'] = yearTo;
    if (minTotal != null) params['p_min_total'] = minTotal;
    if (maxTotal != null) params['p_max_total'] = maxTotal;
    if (party != null && party.isNotEmpty) params['p_party'] = party;
    if (nameQuery != null && nameQuery.isNotEmpty) params['p_name_query'] = nameQuery;

    final data = await _readClient.rpc('search_donors', params: params);
    return (data as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
  }

  // ---------------------------------------------------------------------------
  // searchContributions
  // ---------------------------------------------------------------------------

  /// Search MEC contributions by contributor name, company, committee, or MEC ID.
  ///
  /// Supports filtering by year range, amount range, committee-only flag, and
  /// pagination via [limit] / [offset].
  Future<List<MecContribution>> searchContributions({
    String? query,
    String? mecId,
    int? yearFrom,
    int? yearTo,
    double? minAmount,
    double? maxAmount,
    bool? committeeOnly,
    String sortBy = 'contribution_date',
    bool ascending = false,
    int limit = 100,
    int offset = 0,
  }) async {
    if (!isReady) return [];

    final allowedSorts = <String>{
      'contribution_date',
      'contribution_amount',
      'contributor_last_name',
      'committee_name',
      'filing_year',
    };
    final resolvedSort = allowedSorts.contains(sortBy) ? sortBy : 'contribution_date';

    var builder = _readClient.from('mec_contributions').select();

    // MEC ID filter — exact match
    if (mecId != null && mecId.isNotEmpty) {
      builder = builder.eq('mec_id', mecId);
    }

    // Free-text search: OR across contributor name / company / committee fields
    if (query != null && query.trim().isNotEmpty) {
      final terms = query.trim().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
      final conditions = <String>[];

      for (final term in terms) {
        conditions.add('contributor_last_name.ilike.%$term%');
        conditions.add('contributor_first_name.ilike.%$term%');
        conditions.add('contributor_company.ilike.%$term%');
        conditions.add('contributor_committee.ilike.%$term%');
        conditions.add('committee_name.ilike.%$term%');
      }

      builder = builder.or(conditions.join(','));
    }

    // Year range filters
    if (yearFrom != null) {
      builder = builder.gte('filing_year', yearFrom);
    }
    if (yearTo != null) {
      builder = builder.lte('filing_year', yearTo);
    }

    // Amount range filters
    if (minAmount != null) {
      builder = builder.gte('contribution_amount', minAmount);
    }
    if (maxAmount != null) {
      builder = builder.lte('contribution_amount', maxAmount);
    }

    // Committee-only filter
    if (committeeOnly == true) {
      builder = builder.eq('is_committee_contributor', true);
    }

    final data = await builder
        .order(resolvedSort, ascending: ascending)
        .order('id', ascending: true)
        .range(offset, offset + limit - 1);

    return (data as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(MecContribution.fromJson)
        .toList();
  }

  // ---------------------------------------------------------------------------
  // getContributorProfile
  // ---------------------------------------------------------------------------

  /// Build an aggregated profile for a contributor identified by last name, and
  /// optionally first name or company.
  ///
  /// Returns a map with:
  /// - `contributions`: List<MecContribution> (all matching rows)
  /// - `totalAmount`: double
  /// - `count`: int
  /// - `committees`: List<Map> sorted by total descending, each with
  ///   `mecId`, `committeeName`, `total`, `count`
  /// - `firstYear`: int?
  /// - `lastYear`: int?
  Future<Map<String, dynamic>> getContributorProfile({
    required String lastName,
    String? firstName,
    String? company,
  }) async {
    if (!isReady) {
      return {
        'contributions': <MecContribution>[],
        'totalAmount': 0.0,
        'count': 0,
        'committees': <Map<String, dynamic>>[],
        'firstYear': null,
        'lastYear': null,
      };
    }

    var builder = _readClient
        .from('mec_contributions')
        .select()
        .ilike('contributor_last_name', lastName);

    if (firstName != null && firstName.isNotEmpty) {
      builder = builder.ilike('contributor_first_name', firstName);
    }
    if (company != null && company.isNotEmpty) {
      builder = builder.ilike('contributor_company', company);
    }

    final data = await builder.order('contribution_date', ascending: false);

    final contributions = (data as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(MecContribution.fromJson)
        .toList();

    if (contributions.isEmpty) {
      return {
        'contributions': <MecContribution>[],
        'totalAmount': 0.0,
        'count': 0,
        'committees': <Map<String, dynamic>>[],
        'firstYear': null,
        'lastYear': null,
      };
    }

    // Aggregate totals
    double totalAmount = 0;
    int? firstYear;
    int? lastYear;

    // Aggregate by committee
    final committeeMap = <String, _CommitteeAgg>{};

    for (final c in contributions) {
      final amt = c.contributionAmount ?? 0;
      totalAmount += amt;

      final year = c.filingYear ?? c.contributionDate?.year;
      if (year != null) {
        firstYear = firstYear == null ? year : (year < firstYear ? year : firstYear);
        lastYear = lastYear == null ? year : (year > lastYear ? year : lastYear);
      }

      final key = c.mecId ?? c.committeeName ?? 'unknown';
      final agg = committeeMap.putIfAbsent(
        key,
        () => _CommitteeAgg(mecId: c.mecId, committeeName: c.committeeName),
      );
      agg.total += amt;
      agg.count += 1;
    }

    final committees = committeeMap.values.toList()
      ..sort((a, b) => b.total.compareTo(a.total));

    return {
      'contributions': contributions,
      'totalAmount': totalAmount,
      'count': contributions.length,
      'committees': committees
          .map((c) => {
                'mecId': c.mecId,
                'committeeName': c.committeeName,
                'total': c.total,
                'count': c.count,
              })
          .toList(),
      'firstYear': firstYear,
      'lastYear': lastYear,
    };
  }

  // ---------------------------------------------------------------------------
  // getCommittee
  // ---------------------------------------------------------------------------

  /// Fetch a single MEC committee record by its MEC ID.
  Future<MecCommittee?> getCommittee(String mecId) async {
    if (!isReady) return null;

    final response = await _readClient
        .from('mec_committees')
        .select()
        .eq('mec_id', mecId)
        .maybeSingle();

    if (response == null) return null;
    return MecCommittee.fromJson(response as Map<String, dynamic>);
  }

  // ---------------------------------------------------------------------------
  // getTopContributors
  // ---------------------------------------------------------------------------

  /// Get the top contributors to a specific committee, aggregated by
  /// contributor name.
  ///
  /// Returns a list of maps sorted by total amount descending, each with:
  /// `name`, `total`, `count`, `city`, `state`, `employer`, `occupation`,
  /// `lastDate`.
  Future<List<Map<String, dynamic>>> getTopContributors({
    required String mecId,
    int limit = 25,
  }) async {
    if (!isReady) return [];

    final data = await _readClient
        .from('mec_contributions')
        .select()
        .eq('mec_id', mecId)
        .order('contribution_date', ascending: false);

    final rows = (data as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(MecContribution.fromJson)
        .toList();

    // Aggregate by contributor display name
    final map = <String, _ContributorAgg>{};

    for (final c in rows) {
      final name = c.contributorDisplayName;
      final agg = map.putIfAbsent(name, () => _ContributorAgg(name: name));
      final amt = c.contributionAmount ?? 0;
      agg.total += amt;
      agg.count += 1;

      // Keep the most recent metadata
      if (agg.lastDate == null ||
          (c.contributionDate != null && c.contributionDate!.isAfter(agg.lastDate!))) {
        agg.lastDate = c.contributionDate;
        agg.city = c.city;
        agg.state = c.state;
        agg.employer = c.employer;
        agg.occupation = c.occupation;
      }
    }

    final sorted = map.values.toList()..sort((a, b) => b.total.compareTo(a.total));

    return sorted.take(limit).map((a) => {
          'name': a.name,
          'total': a.total,
          'count': a.count,
          'city': a.city,
          'state': a.state,
          'employer': a.employer,
          'occupation': a.occupation,
          'lastDate': a.lastDate?.toIso8601String(),
        }).toList();
  }
}

// ---------------------------------------------------------------------------
// Private aggregation helpers
// ---------------------------------------------------------------------------

class _CommitteeAgg {
  final String? mecId;
  final String? committeeName;
  double total = 0;
  int count = 0;

  _CommitteeAgg({this.mecId, this.committeeName});
}

class _ContributorAgg {
  final String name;
  double total = 0;
  int count = 0;
  String? city;
  String? state;
  String? employer;
  String? occupation;
  DateTime? lastDate;

  _ContributorAgg({required this.name});
}
