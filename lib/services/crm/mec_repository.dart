import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/models/crm/fec_contribution.dart';
import 'package:bluebubbles/models/crm/mec_contribution.dart';
import 'package:bluebubbles/models/crm/mec_committee.dart';
import 'package:bluebubbles/utils/postgrest_filters.dart';

import 'supabase_service.dart';

class MecRepository {
  final CRMSupabaseService _supabase = CRMSupabaseService();

  bool get isReady => CRMConfig.crmEnabled && _supabase.isInitialized;

  SupabaseClient get _readClient => _supabase.client;

  /// Explicit projection for public.mec_contributions, replacing the bare
  /// `.select()` this repository used to send against a 3.27M-row table.
  /// Every column here is one MecContribution.fromJson reads; naming them
  /// stops the payload growing silently as the table gains columns.
  static const String _contributionColumns =
      'id,mec_id,donor_id,committee_name,report,contributor_committee,'
      'contributor_company,contributor_last_name,contributor_first_name,'
      'address1,address2,city,state,zip,employer,occupation,'
      'contribution_date,contribution_amount,monetary_or_inkind,'
      'is_committee_contributor,report_type,filing_year,created_at';

  /// How many contribution rows the contributor profile renders.
  ///
  /// Deliberately 1000, which is exactly the ceiling PostgREST was already
  /// imposing on the old unranged select. The rendered list is therefore the
  /// same set of rows it has always been; what changes is that the totals
  /// beside it are now computed server-side over EVERY matching row instead
  /// of being folded from this slice. Making the bound explicit is the point:
  /// the cap is now a decision rather than an accident.
  static const int contributionRowDisplayLimit = 1000;

  // ---------------------------------------------------------------------------
  // searchDonors (RPC — aggregated donor search)
  // ---------------------------------------------------------------------------

  /// Smart donor search using the search_donors_v2 RPC function.
  ///
  /// Returns aggregated donor rows with total amounts, party affiliations,
  /// committee counts, and enrichment data (gender, age, phone, etc.).
  Future<List<Map<String, dynamic>>> searchDonors({
    String? state,
    int? yearFrom,
    int? yearTo,
    double? minTotal,
    double? maxTotal,
    String? party,
    String? nameQuery,
    String? city,
    String? zip,
    String? employer,
    String? occupation,
    String? gender,
    int? ageMin,
    int? ageMax,
    bool? hasPhone,
    bool? hasEmail,
    bool? isHomeowner,
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
    if (city != null && city.isNotEmpty) params['p_city'] = city;
    if (zip != null && zip.isNotEmpty) params['p_zip'] = zip;
    if (employer != null && employer.isNotEmpty) params['p_employer'] = employer;
    if (occupation != null && occupation.isNotEmpty) params['p_occupation'] = occupation;
    if (gender != null && gender.isNotEmpty) params['p_gender'] = gender;
    if (ageMin != null) params['p_age_min'] = ageMin;
    if (ageMax != null) params['p_age_max'] = ageMax;
    if (hasPhone != null) params['p_has_phone'] = hasPhone;
    if (hasEmail != null) params['p_has_email'] = hasEmail;
    if (isHomeowner != null) params['p_is_homeowner'] = isHomeowner;

    final data = await _readClient.rpc('search_donors_v2', params: params);
    return (data as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
  }

  // ---------------------------------------------------------------------------
  // getDonorEnrichment
  // ---------------------------------------------------------------------------

  /// Fetch enrichment data for a specific donor by donor_id.
  Future<Map<String, dynamic>?> getDonorEnrichment(int donorId) async {
    if (!isReady) return null;
    final data = await _readClient
        .from('donor_enrichment')
        .select()
        .eq('donor_id', donorId)
        .maybeSingle();
    return data;
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
      const searchColumns = <String>[
        'contributor_last_name',
        'contributor_first_name',
        'contributor_company',
        'contributor_committee',
        'committee_name',
      ];
      final conditions = <String>[];

      for (final term in terms) {
        conditions.add(buildIlikeOrClauses(searchColumns, term));
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
    const empty = <String, dynamic>{
      'contributions': <MecContribution>[],
      'totalAmount': 0.0,
      'count': 0,
      'committees': <Map<String, dynamic>>[],
      'firstYear': null,
      'lastYear': null,
    };

    if (!isReady) {
      return Map<String, dynamic>.from(empty);
    }

    // The aggregates used to be folded in Dart over the result of an UNRANGED
    // `.select()` against public.mec_contributions (3.27M rows). PostgREST
    // caps an unranged select at 1000 rows, so totalAmount, count and the
    // year bounds were computed from the 1000 most recent contributions and
    // any contributor above that reported a total that was simply wrong, with
    // no error. public.get_mec_contributor_profile() computes them over every
    // matching row server-side.
    //
    // NOTE FOR THE HANDOFF: these numbers move UPWARD after this change for
    // any contributor with more than 1000 contributions. That is the
    // correction landing, not a regression.
    double totalAmount = 0;
    int count = 0;
    int? firstYear;
    int? lastYear;
    var committees = <Map<String, dynamic>>[];

    try {
      final agg = await _readClient.rpc(
        'get_mec_contributor_profile',
        params: {
          'p_last_name': lastName,
          'p_first_name': firstName,
          'p_company': company,
        },
      );

      if (agg is Map) {
        totalAmount = (agg['total_amount'] as num?)?.toDouble() ?? 0;
        count = (agg['count'] as num?)?.toInt() ?? 0;
        firstYear = (agg['first_year'] as num?)?.toInt();
        lastYear = (agg['last_year'] as num?)?.toInt();

        final rawCommittees = agg['committees'];
        if (rawCommittees is List) {
          committees = rawCommittees
              .whereType<Map>()
              .map((c) => <String, dynamic>{
                    'mecId': c['mecId'] as String?,
                    'committeeName': c['committeeName'] as String?,
                    'total': (c['total'] as num?)?.toDouble() ?? 0,
                    'count': (c['count'] as num?)?.toInt() ?? 0,
                  })
              .toList();
        }
      }
    } catch (e) {
      debugPrint('❌ MecRepository.getContributorProfile aggregate error: $e');
      return Map<String, dynamic>.from(empty);
    }

    if (count == 0) {
      return Map<String, dynamic>.from(empty);
    }

    // The row list is for DISPLAY only now, so it carries an explicit column
    // list and an explicit .range() instead of relying on the PostgREST cap.
    // The headline figures above no longer depend on how many rows come back.
    final contributions = <MecContribution>[];
    try {
      var rowQuery = _readClient
          .from('mec_contributions')
          .select(_contributionColumns)
          .ilike('contributor_last_name', lastName);

      if (firstName != null && firstName.isNotEmpty) {
        rowQuery = rowQuery.ilike('contributor_first_name', firstName);
      }
      if (company != null && company.isNotEmpty) {
        rowQuery = rowQuery.ilike('contributor_company', company);
      }

      final data = await rowQuery
          .order('contribution_date', ascending: false)
          .order('id', ascending: false)
          .range(0, contributionRowDisplayLimit - 1);

      contributions.addAll((data as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(MecContribution.fromJson));
    } catch (e) {
      debugPrint('❌ MecRepository.getContributorProfile rows error: $e');
    }

    return <String, dynamic>{
      'contributions': contributions,
      'totalAmount': totalAmount,
      'count': count,
      'committees': committees,
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
  // searchDonorsUnified (RPC — unified MEC+FEC search via search_donors_v3)
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> searchDonorsUnified({
    String? state,
    int? yearFrom,
    int? yearTo,
    double? minTotal,
    double? maxTotal,
    String? party,
    String? nameQuery,
    String? city,
    String? zip,
    String? employer,
    String? occupation,
    String? gender,
    int? ageMin,
    int? ageMax,
    bool? hasPhone,
    bool? hasEmail,
    bool? isHomeowner,
    bool individualsOnly = true,
    String source = 'both',
    int limit = 100,
    int offset = 0,
  }) async {
    if (!isReady) return [];

    final params = <String, dynamic>{
      'p_individuals_only': individualsOnly,
      'p_source': source,
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
    if (city != null && city.isNotEmpty) params['p_city'] = city;
    if (zip != null && zip.isNotEmpty) params['p_zip'] = zip;
    if (employer != null && employer.isNotEmpty) params['p_employer'] = employer;
    if (occupation != null && occupation.isNotEmpty) params['p_occupation'] = occupation;
    if (gender != null && gender.isNotEmpty) params['p_gender'] = gender;
    if (ageMin != null) params['p_age_min'] = ageMin;
    if (ageMax != null) params['p_age_max'] = ageMax;
    if (hasPhone != null) params['p_has_phone'] = hasPhone;
    if (hasEmail != null) params['p_has_email'] = hasEmail;
    if (isHomeowner != null) params['p_is_homeowner'] = isHomeowner;

    final data = await _readClient.rpc('search_donors_v3', params: params);
    return (data as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
  }

  // ---------------------------------------------------------------------------
  // getDonorUnifiedProfile (RPC — full MEC+FEC profile)
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>?> getDonorUnifiedProfile(int donorId) async {
    if (!isReady) return null;

    final data = await _readClient.rpc('get_donor_unified_profile', params: {
      'p_donor_id': donorId,
    });

    if (data == null) return null;
    return data as Map<String, dynamic>;
  }

  // ---------------------------------------------------------------------------
  // getCommitteeDonorsPaginated (RPC — all donors for a committee)
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getCommitteeDonorsPaginated({
    required String mecId,
    int limit = 100,
    int offset = 0,
    String sortBy = 'total',
    bool ascending = false,
  }) async {
    if (!isReady) return [];

    final data = await _readClient.rpc('get_committee_donors_paginated', params: {
      'p_mec_id': mecId,
      'p_limit': limit,
      'p_offset': offset,
      'p_sort_by': sortBy,
      'p_ascending': ascending,
    });

    return (data as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
  }

  // ---------------------------------------------------------------------------
  // searchCommitteesUnified (RPC — MEC+FEC committees)
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> searchCommitteesUnified({
    String? query,
    String? status,
    String? party,
    String source = 'both',
    int limit = 50,
    int offset = 0,
  }) async {
    if (!isReady) return [];

    final params = <String, dynamic>{
      'p_source': source,
      'p_limit': limit,
      'p_offset': offset,
    };
    if (query != null && query.isNotEmpty) params['p_query'] = query;
    if (status != null && status.isNotEmpty) params['p_status'] = status;
    if (party != null && party.isNotEmpty) params['p_party'] = party;

    final data = await _readClient.rpc('search_committees_unified', params: params);
    return (data as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
  }
}
