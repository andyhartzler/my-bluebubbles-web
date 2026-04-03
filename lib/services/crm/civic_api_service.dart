import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ═══════════════════════════════════════════════════════════════
//  GOOGLE CIVIC INFORMATION API SERVICE
//  Provides representative lookup, election info, and voter
//  information for Missouri districts.
//
//  API Docs: https://developers.google.com/civic-information
// ═══════════════════════════════════════════════════════════════

class CivicApiService {
  static final CivicApiService _instance = CivicApiService._();
  factory CivicApiService() => _instance;
  CivicApiService._();

  // NOTE: Replace with actual API key from Google Cloud Console
  static const _apiKey = 'AIzaSyBExample'; // placeholder
  static const _baseUrl = 'https://www.googleapis.com/civicinfo/v2';

  final Map<String, _CachedResult> _cache = {};

  // ─── Lookup representatives by address ────────────────────────

  Future<RepresentativeResult?> lookupRepresentatives(String address) async {
    final cacheKey = 'rep:$address';
    if (_cache.containsKey(cacheKey) && !_cache[cacheKey]!.isExpired) {
      return _cache[cacheKey]!.data as RepresentativeResult;
    }

    try {
      final uri = Uri.parse('$_baseUrl/representatives').replace(
        queryParameters: {
          'key': _apiKey,
          'address': address,
          'levels': 'country,administrativeArea1',
          'roles': 'legislatorUpperBody,legislatorLowerBody',
        },
      );

      final response = await http.get(uri).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode != 200) {
        debugPrint('❌ Civic API representatives error: ${response.statusCode}');
        return null;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final result = RepresentativeResult.fromJson(data);

      _cache[cacheKey] = _CachedResult(result);
      return result;
    } catch (e) {
      debugPrint('❌ Civic API lookupRepresentatives error: $e');
      return null;
    }
  }

  // ─── Get election info ────────────────────────────────────────

  Future<List<ElectionInfo>> getUpcomingElections() async {
    const cacheKey = 'elections';
    if (_cache.containsKey(cacheKey) && !_cache[cacheKey]!.isExpired) {
      return _cache[cacheKey]!.data as List<ElectionInfo>;
    }

    try {
      final uri = Uri.parse('$_baseUrl/elections').replace(
        queryParameters: {'key': _apiKey},
      );

      final response = await http.get(uri).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode != 200) return [];

      final data = json.decode(response.body) as Map<String, dynamic>;
      final elections = (data['elections'] as List<dynamic>? ?? [])
          .map((e) => ElectionInfo.fromJson(e as Map<String, dynamic>))
          .toList();

      _cache[cacheKey] = _CachedResult(elections);
      return elections;
    } catch (e) {
      debugPrint('❌ Civic API getUpcomingElections error: $e');
      return [];
    }
  }

  // ─── Get voter info for an address ────────────────────────────

  Future<VoterInfo?> getVoterInfo(String address, {String? electionId}) async {
    final cacheKey = 'voter:$address:$electionId';
    if (_cache.containsKey(cacheKey) && !_cache[cacheKey]!.isExpired) {
      return _cache[cacheKey]!.data as VoterInfo;
    }

    try {
      final params = <String, String>{
        'key': _apiKey,
        'address': address,
      };
      if (electionId != null) {
        params['electionId'] = electionId;
      }

      final uri = Uri.parse('$_baseUrl/voterinfo').replace(
        queryParameters: params,
      );

      final response = await http.get(uri).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode != 200) return null;

      final data = json.decode(response.body) as Map<String, dynamic>;
      final result = VoterInfo.fromJson(data);

      _cache[cacheKey] = _CachedResult(result);
      return result;
    } catch (e) {
      debugPrint('❌ Civic API getVoterInfo error: $e');
      return null;
    }
  }

  // ─── Lookup divisions (districts) ─────────────────────────────

  Future<List<Division>> searchDivisions(String query) async {
    try {
      final uri = Uri.parse('$_baseUrl/divisions').replace(
        queryParameters: {
          'key': _apiKey,
          'query': query,
        },
      );

      final response = await http.get(uri).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode != 200) return [];

      final data = json.decode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>? ?? [];

      return results.map((r) {
        final m = r as Map<String, dynamic>;
        return Division(
          ocdId: m['ocdId'] as String? ?? '',
          name: m['name'] as String? ?? '',
          aliases: (m['aliases'] as List<dynamic>?)
                  ?.map((a) => a as String)
                  .toList() ??
              [],
        );
      }).toList();
    } catch (e) {
      debugPrint('❌ Civic API searchDivisions error: $e');
      return [];
    }
  }

  void clearCache() => _cache.clear();
}

// ─── Cache wrapper ──────────────────────────────────────────────

class _CachedResult {
  final dynamic data;
  final DateTime fetchedAt;

  _CachedResult(this.data) : fetchedAt = DateTime.now();

  bool get isExpired =>
      DateTime.now().difference(fetchedAt).inHours > 6;
}

// ─── Data models ────────────────────────────────────────────────

class RepresentativeResult {
  final String? normalizedAddress;
  final List<Office> offices;
  final List<Official> officials;

  RepresentativeResult({
    this.normalizedAddress,
    this.offices = const [],
    this.officials = const [],
  });

  factory RepresentativeResult.fromJson(Map<String, dynamic> json) {
    final normalizedInput = json['normalizedInput'] as Map<String, dynamic>?;
    String? normalizedAddress;
    if (normalizedInput != null) {
      normalizedAddress =
          '${normalizedInput['line1'] ?? ''} ${normalizedInput['city'] ?? ''}, ${normalizedInput['state'] ?? ''} ${normalizedInput['zip'] ?? ''}'
              .trim();
    }

    final officesJson = json['offices'] as List<dynamic>? ?? [];
    final officialsJson = json['officials'] as List<dynamic>? ?? [];

    return RepresentativeResult(
      normalizedAddress: normalizedAddress,
      offices: officesJson
          .map((o) => Office.fromJson(o as Map<String, dynamic>))
          .toList(),
      officials: officialsJson
          .map((o) => Official.fromJson(o as Map<String, dynamic>))
          .toList(),
    );
  }
}

class Office {
  final String name;
  final String? divisionId;
  final List<String> levels;
  final List<String> roles;
  final List<int> officialIndices;

  Office({
    required this.name,
    this.divisionId,
    this.levels = const [],
    this.roles = const [],
    this.officialIndices = const [],
  });

  factory Office.fromJson(Map<String, dynamic> json) {
    return Office(
      name: json['name'] as String? ?? '',
      divisionId: json['divisionId'] as String?,
      levels: (json['levels'] as List<dynamic>?)
              ?.map((l) => l as String)
              .toList() ??
          [],
      roles: (json['roles'] as List<dynamic>?)
              ?.map((r) => r as String)
              .toList() ??
          [],
      officialIndices: (json['officialIndices'] as List<dynamic>?)
              ?.map((i) => (i as num).toInt())
              .toList() ??
          [],
    );
  }
}

class Official {
  final String name;
  final String? party;
  final String? photoUrl;
  final List<String> phones;
  final List<String> emails;
  final List<String> urls;
  final List<Map<String, String>> channels;

  Official({
    required this.name,
    this.party,
    this.photoUrl,
    this.phones = const [],
    this.emails = const [],
    this.urls = const [],
    this.channels = const [],
  });

  factory Official.fromJson(Map<String, dynamic> json) {
    return Official(
      name: json['name'] as String? ?? '',
      party: json['party'] as String?,
      photoUrl: json['photoUrl'] as String?,
      phones: (json['phones'] as List<dynamic>?)
              ?.map((p) => p as String)
              .toList() ??
          [],
      emails: (json['emails'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      urls: (json['urls'] as List<dynamic>?)
              ?.map((u) => u as String)
              .toList() ??
          [],
      channels: (json['channels'] as List<dynamic>?)
              ?.map((c) {
            final m = c as Map<String, dynamic>;
            return {
              'type': m['type'] as String? ?? '',
              'id': m['id'] as String? ?? '',
            };
          }).toList() ??
          [],
    );
  }
}

class ElectionInfo {
  final String id;
  final String name;
  final String electionDay;
  final String? ocdDivisionId;

  ElectionInfo({
    required this.id,
    required this.name,
    required this.electionDay,
    this.ocdDivisionId,
  });

  factory ElectionInfo.fromJson(Map<String, dynamic> json) {
    return ElectionInfo(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      electionDay: json['electionDay'] as String? ?? '',
      ocdDivisionId: json['ocdDivisionId'] as String?,
    );
  }
}

class VoterInfo {
  final String? stateName;
  final List<PollingLocation> pollingLocations;
  final List<Contest> contests;

  VoterInfo({
    this.stateName,
    this.pollingLocations = const [],
    this.contests = const [],
  });

  factory VoterInfo.fromJson(Map<String, dynamic> json) {
    final state = json['state'] as List<dynamic>?;
    String? stateName;
    if (state != null && state.isNotEmpty) {
      stateName = (state.first as Map<String, dynamic>)['name'] as String?;
    }

    return VoterInfo(
      stateName: stateName,
      pollingLocations: (json['pollingLocations'] as List<dynamic>? ?? [])
          .map((p) => PollingLocation.fromJson(p as Map<String, dynamic>))
          .toList(),
      contests: (json['contests'] as List<dynamic>? ?? [])
          .map((c) => Contest.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }
}

class PollingLocation {
  final String? name;
  final String? address;
  final String? hours;

  PollingLocation({this.name, this.address, this.hours});

  factory PollingLocation.fromJson(Map<String, dynamic> json) {
    final addr = json['address'] as Map<String, dynamic>?;
    String? address;
    if (addr != null) {
      address =
          '${addr['line1'] ?? ''} ${addr['city'] ?? ''}, ${addr['state'] ?? ''} ${addr['zip'] ?? ''}'
              .trim();
    }
    return PollingLocation(
      name: json['name'] as String? ?? addr?['locationName'] as String?,
      address: address,
      hours: json['pollingHours'] as String?,
    );
  }
}

class Contest {
  final String? office;
  final String? district;
  final List<ContestCandidate> candidates;

  Contest({this.office, this.district, this.candidates = const []});

  factory Contest.fromJson(Map<String, dynamic> json) {
    return Contest(
      office: json['office'] as String?,
      district: (json['district'] as Map<String, dynamic>?)?['name'] as String?,
      candidates: (json['candidates'] as List<dynamic>? ?? [])
          .map((c) =>
              ContestCandidate.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ContestCandidate {
  final String name;
  final String? party;

  ContestCandidate({required this.name, this.party});

  factory ContestCandidate.fromJson(Map<String, dynamic> json) {
    return ContestCandidate(
      name: json['name'] as String? ?? '',
      party: json['party'] as String?,
    );
  }
}

class Division {
  final String ocdId;
  final String name;
  final List<String> aliases;

  Division({required this.ocdId, required this.name, this.aliases = const []});
}
