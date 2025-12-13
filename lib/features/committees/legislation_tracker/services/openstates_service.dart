import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for interacting with Open States API via Edge Functions
class OpenStatesService {
  OpenStatesService._internal();
  static final OpenStatesService _instance = OpenStatesService._internal();
  factory OpenStatesService() => _instance;

  SupabaseClient get _supabase => Supabase.instance.client;

  /// Search for bills in the Missouri legislature
  Future<BillSearchResult> searchBills({
    String? query,
    String session = '2026',
    String? chamber,
    String? classification,
    String? subject,
    String? sponsor,
    String? updatedSince,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'openstates-search-bills',
        body: {
          'query': query,
          'session': session,
          'chamber': chamber,
          'classification': classification,
          'subject': subject,
          'sponsor': sponsor,
          'updated_since': updatedSince,
          'page': page,
          'per_page': perPage,
        },
      );

      if (response.status != 200) {
        final errorMsg = response.data is Map ? response.data['error'] : 'Unknown error';
        throw Exception('Failed to search bills: $errorMsg');
      }

      return BillSearchResult.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to search bills: $e');
    }
  }

  /// Get full details for a single bill
  Future<OpenStatesBill> getBill({
    String? openstatesBillId,
    String? jurisdiction,
    String? session,
    String? billId,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'openstates-get-bill',
        body: {
          'openstates_bill_id': openstatesBillId,
          'jurisdiction': jurisdiction,
          'session': session,
          'bill_id': billId,
        },
      );

      if (response.status != 200) {
        final errorMsg = response.data is Map ? response.data['error'] : 'Unknown error';
        throw Exception('Failed to get bill: $errorMsg');
      }

      return OpenStatesBill.fromJson(response.data['bill'] as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to get bill: $e');
    }
  }

  /// Get legislators (for sponsor lookup or geo lookup)
  Future<List<Legislator>> getLegislators({
    double? lat,
    double? lng,
    String? name,
    String? chamber,
    String? party,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'openstates-get-legislators',
        body: {
          'lat': lat,
          'lng': lng,
          'name': name,
          'chamber': chamber,
          'party': party,
        },
      );

      if (response.status != 200) {
        final errorMsg = response.data is Map ? response.data['error'] : 'Unknown error';
        throw Exception('Failed to get legislators: $errorMsg');
      }

      final legislatorsData = response.data['legislators'] as List<dynamic>? ?? [];
      return legislatorsData
          .map((json) => Legislator.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to get legislators: $e');
    }
  }

  /// Trigger sync for tracked bills
  Future<SyncResult> syncTrackedBills({String? billId}) async {
    try {
      final response = await _supabase.functions.invoke(
        'openstates-sync-tracked-bills',
        body: billId != null ? {'bill_id': billId} : {},
      );

      if (response.status != 200) {
        final errorMsg = response.data is Map ? response.data['error'] : 'Unknown error';
        throw Exception('Failed to sync: $errorMsg');
      }

      return SyncResult.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to sync: $e');
    }
  }
}

// Supporting classes for Open States responses

class BillSearchResult {
  final List<OpenStatesBillSummary> results;
  final Pagination pagination;

  BillSearchResult({required this.results, required this.pagination});

  factory BillSearchResult.fromJson(Map<String, dynamic> json) {
    return BillSearchResult(
      results: (json['results'] as List<dynamic>? ?? [])
          .map((e) => OpenStatesBillSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
      pagination: Pagination.fromJson(json['pagination'] as Map<String, dynamic>? ?? {}),
    );
  }
}

class OpenStatesBillSummary {
  final String openstatesBillId;
  final String jurisdiction;
  final String session;
  final String billIdentifier;
  final String title;
  final String? description;
  final String? billType;
  final String? chamber;
  final String? latestActionDate;
  final String? latestActionDescription;
  final String? primarySponsor;
  final int sponsorCount;
  final String? openstatesUrl;

  OpenStatesBillSummary({
    required this.openstatesBillId,
    required this.jurisdiction,
    required this.session,
    required this.billIdentifier,
    required this.title,
    this.description,
    this.billType,
    this.chamber,
    this.latestActionDate,
    this.latestActionDescription,
    this.primarySponsor,
    required this.sponsorCount,
    this.openstatesUrl,
  });

  factory OpenStatesBillSummary.fromJson(Map<String, dynamic> json) {
    return OpenStatesBillSummary(
      openstatesBillId: json['openstates_bill_id'] as String? ?? json['id'] as String? ?? '',
      jurisdiction: json['jurisdiction'] as String? ?? 'mo',
      session: json['session'] as String? ?? '',
      billIdentifier: json['bill_identifier'] as String? ?? json['identifier'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      billType: json['bill_type'] as String?,
      chamber: json['chamber'] as String?,
      latestActionDate: json['latest_action_date'] as String?,
      latestActionDescription: json['latest_action_description'] as String?,
      primarySponsor: json['primary_sponsor'] as String?,
      sponsorCount: json['sponsor_count'] as int? ?? 0,
      openstatesUrl: json['openstates_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'openstates_bill_id': openstatesBillId,
      'jurisdiction': jurisdiction,
      'session': session,
      'bill_identifier': billIdentifier,
      'title': title,
      'description': description,
      'bill_type': billType,
      'chamber': chamber,
      'latest_action_date': latestActionDate,
      'latest_action_description': latestActionDescription,
      'primary_sponsor': primarySponsor,
      'sponsor_count': sponsorCount,
      'openstates_url': openstatesUrl,
    };
  }
}

class OpenStatesBill {
  final String openstatesBillId;
  final String jurisdiction;
  final String session;
  final String billIdentifier;
  final String title;
  final String? description;
  final String? billType;
  final String? chamber;
  final String? latestActionDate;
  final String? latestActionDescription;
  final String? firstActionDate;
  final List<dynamic> sponsors;
  final List<dynamic> actions;
  final List<dynamic> votes;
  final List<dynamic> versions;
  final List<dynamic> documents;
  final List<dynamic> sources;
  final List<String> subjects;
  final String? openstatesUrl;
  final Map<String, dynamic> rawData;

  OpenStatesBill({
    required this.openstatesBillId,
    required this.jurisdiction,
    required this.session,
    required this.billIdentifier,
    required this.title,
    this.description,
    this.billType,
    this.chamber,
    this.latestActionDate,
    this.latestActionDescription,
    this.firstActionDate,
    required this.sponsors,
    required this.actions,
    required this.votes,
    required this.versions,
    required this.documents,
    required this.sources,
    required this.subjects,
    this.openstatesUrl,
    required this.rawData,
  });

  factory OpenStatesBill.fromJson(Map<String, dynamic> json) {
    return OpenStatesBill(
      openstatesBillId: json['openstates_bill_id'] as String? ?? json['id'] as String? ?? '',
      jurisdiction: json['jurisdiction'] as String? ?? 'mo',
      session: json['session'] as String? ?? '',
      billIdentifier: json['bill_identifier'] as String? ?? json['identifier'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      billType: json['bill_type'] as String?,
      chamber: json['chamber'] as String?,
      latestActionDate: json['latest_action_date'] as String?,
      latestActionDescription: json['latest_action_description'] as String?,
      firstActionDate: json['first_action_date'] as String?,
      sponsors: json['sponsors'] as List<dynamic>? ?? [],
      actions: json['actions'] as List<dynamic>? ?? [],
      votes: json['votes'] as List<dynamic>? ?? [],
      versions: json['versions'] as List<dynamic>? ?? [],
      documents: json['documents'] as List<dynamic>? ?? [],
      sources: json['sources'] as List<dynamic>? ?? [],
      subjects: (json['subjects'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      openstatesUrl: json['openstates_url'] as String?,
      rawData: json['raw_data'] as Map<String, dynamic>? ?? json,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'openstates_bill_id': openstatesBillId,
      'jurisdiction': jurisdiction,
      'session': session,
      'bill_identifier': billIdentifier,
      'title': title,
      'description': description,
      'bill_type': billType,
      'chamber': chamber,
      'latest_action_date': latestActionDate,
      'latest_action_description': latestActionDescription,
      'first_action_date': firstActionDate,
      'sponsors': sponsors,
      'actions': actions,
      'votes': votes,
      'versions': versions,
      'documents': documents,
      'sources': sources,
      'subjects': subjects,
      'openstates_url': openstatesUrl,
      'raw_data': rawData,
    };
  }

  /// Get the primary sponsor name
  String? get primarySponsorName {
    for (final sponsor in sponsors) {
      if (sponsor is Map && (sponsor['primary'] == true || sponsor['is_primary'] == true)) {
        return sponsor['name'] as String?;
      }
    }
    return sponsors.isNotEmpty ? (sponsors.first as Map?)?['name'] as String? : null;
  }

  /// Get the primary sponsor party
  String? get primarySponsorParty {
    for (final sponsor in sponsors) {
      if (sponsor is Map && (sponsor['primary'] == true || sponsor['is_primary'] == true)) {
        return sponsor['party'] as String?;
      }
    }
    return sponsors.isNotEmpty ? (sponsors.first as Map?)?['party'] as String? : null;
  }
}

class Legislator {
  final String openstatesId;
  final String name;
  final String? givenName;
  final String? familyName;
  final String? party;
  final String? chamber;
  final String? district;
  final String? title;
  final String? image;
  final String? email;
  final List<dynamic> offices;
  final List<dynamic> links;
  final String? openstatesUrl;

  Legislator({
    required this.openstatesId,
    required this.name,
    this.givenName,
    this.familyName,
    this.party,
    this.chamber,
    this.district,
    this.title,
    this.image,
    this.email,
    required this.offices,
    required this.links,
    this.openstatesUrl,
  });

  factory Legislator.fromJson(Map<String, dynamic> json) {
    return Legislator(
      openstatesId: json['openstates_id'] as String? ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      givenName: json['given_name'] as String?,
      familyName: json['family_name'] as String?,
      party: json['party'] as String?,
      chamber: json['chamber'] as String?,
      district: json['district'] as String?,
      title: json['title'] as String?,
      image: json['image'] as String?,
      email: json['email'] as String?,
      offices: json['offices'] as List<dynamic>? ?? [],
      links: json['links'] as List<dynamic>? ?? [],
      openstatesUrl: json['openstates_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'openstates_id': openstatesId,
      'name': name,
      'given_name': givenName,
      'family_name': familyName,
      'party': party,
      'chamber': chamber,
      'district': district,
      'title': title,
      'image': image,
      'email': email,
      'offices': offices,
      'links': links,
      'openstates_url': openstatesUrl,
    };
  }

  /// Get a readable chamber name
  String get chamberDisplay {
    switch (chamber?.toLowerCase()) {
      case 'lower':
        return 'House';
      case 'upper':
        return 'Senate';
      default:
        return chamber ?? '';
    }
  }
}

class Pagination {
  final int perPage;
  final int page;
  final int maxPage;
  final int totalItems;

  Pagination({
    required this.perPage,
    required this.page,
    required this.maxPage,
    required this.totalItems,
  });

  factory Pagination.fromJson(Map<String, dynamic> json) {
    return Pagination(
      perPage: json['per_page'] as int? ?? 20,
      page: json['page'] as int? ?? 1,
      maxPage: json['max_page'] as int? ?? 1,
      totalItems: json['total_items'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'per_page': perPage,
      'page': page,
      'max_page': maxPage,
      'total_items': totalItems,
    };
  }

  bool get hasMore => page < maxPage;
}

class SyncResult {
  final bool success;
  final int billsChecked;
  final int billsUpdated;
  final int newActionsFound;
  final int newVotesFound;
  final int? durationMs;
  final List<dynamic>? errors;

  SyncResult({
    required this.success,
    required this.billsChecked,
    required this.billsUpdated,
    required this.newActionsFound,
    required this.newVotesFound,
    this.durationMs,
    this.errors,
  });

  factory SyncResult.fromJson(Map<String, dynamic> json) {
    return SyncResult(
      success: json['success'] as bool? ?? false,
      billsChecked: json['bills_checked'] as int? ?? 0,
      billsUpdated: json['bills_updated'] as int? ?? 0,
      newActionsFound: json['new_actions_found'] as int? ?? 0,
      newVotesFound: json['new_votes_found'] as int? ?? 0,
      durationMs: json['duration_ms'] as int?,
      errors: json['errors'] as List<dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'bills_checked': billsChecked,
      'bills_updated': billsUpdated,
      'new_actions_found': newActionsFound,
      'new_votes_found': newVotesFound,
      'duration_ms': durationMs,
      'errors': errors,
    };
  }
}
