import 'dart:collection';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:postgrest/postgrest.dart'
    show CountOption, PostgrestFilterBuilder, PostgrestResponse;

import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/services/crm/phone_normalizer.dart';
import 'package:bluebubbles/database/global/platform_file.dart';
import 'package:bluebubbles/utils/postgrest_filters.dart';
import 'package:flutter/foundation.dart';
import 'package:mime_type/mime_type.dart';
import 'package:universal_io/io.dart' as io;

import 'supabase_service.dart';

/// Repository for member CRUD operations
/// All Supabase queries for members go through here
class MemberRepository {
  final CRMSupabaseService _supabase = CRMSupabaseService();

  bool get _isReady => _supabase.isInitialized;

  static const String _documentsBucket = 'member-documents';
  static const List<String> _dashboardMetricsSources = [
    'crm_dashboard_metrics',
    'dashboard_metrics',
  ];

  static const List<String> listingColumns = [
    'id',
    'created_at',
    'name',
    'email',
    'school_email',
    'phone',
    'phone_e164',
    'county',
    'congressional_district',
    'house_district',
    'senate_district',
    'committee',
    'chapter_name',
    'chapter_position',
    'school_name',
    'current_chapter_member',
    'registered_voter',
    'opt_out',
    'membership_eligible',
    'date_of_birth',
    'community_type',
    'notes',
    'executive_committee',
    'executive_title',
    'executive_role',
    'profile_pictures',
    'last_contacted',
    'date_joined',
    'intro_sent_at',
  ];

  SupabaseClient get _readClient => _supabase.client;

  SupabaseClient get _writeClient => _supabase.client;


  /// Get all members (with optional filters)
  Future<MemberFetchResult> getAllMembers({
    String? county,
    List<String>? congressionalDistricts,
    List<String>? committees,
    List<String>? highSchools,
    List<String>? colleges,
    bool anyHighSchool = false,
    String? chapterName,
    String? chapterStatus,
    int? minAge,
    int? maxAge,
    bool? optedOut,
    bool? registeredVoter,
    String? searchQuery,
    int? limit,
    int? offset,
    bool fetchTotalCount = false,
    bool fetchAll = false,
    List<String>? columns,
    // Backward-compatible single-value parameters
    String? congressionalDistrict,
    String? highSchool,
    String? college,
  }) async {
    // Handle backward-compatible single values
    final effectiveDistricts = congressionalDistricts ??
        (congressionalDistrict != null ? [congressionalDistrict] : null);
    final effectiveHighSchools = highSchools ??
        (highSchool != null ? [highSchool] : null);
    final effectiveColleges = colleges ??
        (college != null ? [college] : null);

    if (!_isReady) {
      return const MemberFetchResult(members: []);
    }

    try {
      final selection = _resolveColumnSelection(columns);
      final baseQuery = _applyMemberFilters(
        _readClient.from('members').select(selection),
        county: county,
        congressionalDistricts: effectiveDistricts,
        committees: committees,
        highSchools: effectiveHighSchools,
        colleges: effectiveColleges,
        anyHighSchool: anyHighSchool,
        chapterName: chapterName,
        chapterStatus: chapterStatus,
        minAge: minAge,
        maxAge: maxAge,
        optedOut: optedOut,
        registeredVoter: registeredVoter,
        searchQuery: searchQuery,
      );

      var query =
          baseQuery.order('name', ascending: true).order('id', ascending: true);

      final hasLimit = !fetchAll && limit != null && limit > 0;
      final hasOffset = !fetchAll && offset != null && offset > 0;
      final limitValue = hasLimit ? limit! : null;
      final offsetValue = hasOffset ? offset! : null;
      final applyOffsetInMemory = hasOffset && !hasLimit;

      if (hasLimit && hasOffset) {
        final start = offsetValue!;
        final end = start + limitValue! - 1;
        query = query.range(start, end);
      } else if (hasLimit) {
        query = query.limit(limitValue!);
      }

      if (fetchTotalCount) {
        // Need to rebuild query with count option since it must be passed to select()
        final selectionWithCount = _resolveColumnSelection(columns);
        dynamic countQuery = _applyMemberFilters(
          _readClient.from('members').select(selectionWithCount),
          county: county,
          congressionalDistricts: effectiveDistricts,
          committees: committees,
          highSchools: effectiveHighSchools,
          colleges: effectiveColleges,
          anyHighSchool: anyHighSchool,
          chapterName: chapterName,
          chapterStatus: chapterStatus,
          minAge: minAge,
          maxAge: maxAge,
          optedOut: optedOut,
          registeredVoter: registeredVoter,
          searchQuery: searchQuery,
        ).order('name', ascending: true).order('id', ascending: true);

        if (hasLimit && hasOffset) {
          final start = offsetValue!;
          final end = start + limitValue! - 1;
          countQuery = countQuery.range(start, end);
        } else if (hasLimit) {
          countQuery = countQuery.limit(limitValue!);
        }

        final response = await countQuery.count(CountOption.exact);
        final data = _coerceList(response);
        var members = _mapMembers(data);
        if (applyOffsetInMemory && offsetValue != null) {
          members = members.skip(offsetValue).toList();
        }
        final totalCount = (response is PostgrestResponse) ? (response.count ?? members.length) : members.length;
        return MemberFetchResult(members: members, totalCount: totalCount);
      }

      if (fetchAll) {
        // "Fetch everything" must page past the PostgREST 1000-row cap, or it
        // silently returns only the first 1000 eligible members.
        final all = <dynamic>[];
        const pageSize = 1000;
        var pageOffset = 0;
        while (true) {
          final pageData =
              await query.range(pageOffset, pageOffset + pageSize - 1);
          final pageList = _coerceList(pageData);
          all.addAll(pageList);
          if (pageList.length < pageSize) break;
          pageOffset += pageSize;
        }
        return MemberFetchResult(members: _mapMembers(all));
      }

      final data = await query;
      final list = _coerceList(data);
      var members = _mapMembers(list);
      if (applyOffsetInMemory && offsetValue != null) {
        members = members.skip(offsetValue).toList();
      }
      return MemberFetchResult(members: members);
    } catch (e) {
      debugPrint('❌ Error fetching members: $e');
      rethrow;
    }
  }

  String _resolveColumnSelection(List<String>? columns) {
    final selection = columns?.where((column) => column.trim().isNotEmpty).toList();
    if (selection == null || selection.isEmpty) {
      return '*';
    }
    return selection.join(',');
  }

  PostgrestFilterBuilder<T> _applyMemberFilters<T>(
    PostgrestFilterBuilder<T> query, {
    String? county,
    List<String>? congressionalDistricts,
    List<String>? committees,
    List<String>? highSchools,
    List<String>? colleges,
    bool anyHighSchool = false,
    String? chapterName,
    String? chapterStatus,
    int? minAge,
    int? maxAge,
    bool? optedOut,
    bool? registeredVoter,
    String? searchQuery,
  }) {
    // CRITICAL: Always filter to only membership eligible members
    // This ensures bulk messaging never includes ineligible members
    query = query.eq('membership_eligible', true);

    if (county != null && county.isNotEmpty) {
      query = query.eq('county', county);
    }

    if (congressionalDistricts != null && congressionalDistricts.isNotEmpty) {
      if (congressionalDistricts.length == 1) {
        query = query.eq('congressional_district', congressionalDistricts.first);
      } else {
        query = query.inFilter('congressional_district', congressionalDistricts);
      }
    }

    if (committees != null && committees.isNotEmpty) {
      query = query.overlaps('committee', committees);
    }

    // anyHighSchool = true means all members with any high school set
    if (anyHighSchool) {
      query = query.not('high_school', 'is', null);
    } else if (highSchools != null && highSchools.isNotEmpty) {
      if (highSchools.length == 1) {
        query = query.eq('high_school', highSchools.first);
      } else {
        query = query.inFilter('high_school', highSchools);
      }
    }

    if (colleges != null && colleges.isNotEmpty) {
      if (colleges.length == 1) {
        query = query.eq('college', colleges.first);
      } else {
        query = query.inFilter('college', colleges);
      }
    }

    if (chapterName != null && chapterName.isNotEmpty) {
      query = query.eq('chapter_name', chapterName);
    }

    if (chapterStatus != null && chapterStatus.isNotEmpty) {
      query = query.eq('current_chapter_member', chapterStatus);
    }

    if (optedOut != null) {
      query = query.eq('opt_out', optedOut);
    }

    if (registeredVoter != null) {
      query = query.eq('registered_voter', registeredVoter);
    }

    if (minAge != null || maxAge != null) {
      query = _applyAgeFilters<T>(query, minAge: minAge, maxAge: maxAge);
    }

    final trimmedQuery = searchQuery?.trim();
    if (trimmedQuery != null && trimmedQuery.isNotEmpty) {
      query = query.or(buildIlikeOrClauses(const [
        'name',
        'phone',
        'phone_e164',
        'email',
        'school_email',
        'county',
        'congressional_district',
        'chapter_name',
        'chapter_position',
        'community_type',
        'current_chapter_member',
        'notes',
      ], trimmedQuery));
    }

    return query;
  }

  PostgrestFilterBuilder<T> _applyAgeFilters<T>(
    PostgrestFilterBuilder<T> query, {
    int? minAge,
    int? maxAge,
  }) {
    final now = DateTime.now();

    if (minAge != null && minAge > 0) {
      final cutoff = _birthdateForAge(minAge, reference: now);
      query = query.lte('date_of_birth', _formatDateOnly(cutoff));
    }

    if (maxAge != null && maxAge >= 0) {
      final earliest = _birthdateForAge(maxAge + 1, reference: now).add(const Duration(days: 1));
      query = query.gte('date_of_birth', _formatDateOnly(earliest));
    }

    return query;
  }

  String _formatDateOnly(DateTime date) => date.toIso8601String().split('T').first;

  DateTime _birthdateForAge(int age, {DateTime? reference}) {
    final base = reference ?? DateTime.now();
    final targetYear = base.year - age;
    final targetMonth = base.month;
    final targetDay = base.day;
    final lastDayOfMonth = DateTime(targetYear, targetMonth + 1, 0).day;
    final safeDay = targetDay > lastDayOfMonth ? lastDayOfMonth : targetDay;
    return DateTime(targetYear, targetMonth, safeDay);
  }

  int? _calculateAge(DateTime dob, {DateTime? reference}) {
    final now = reference ?? DateTime.now();
    var age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age >= 0 ? age : null;
  }

  List<dynamic> _coerceList(dynamic response) {
    if (response is PostgrestResponse) {
      return _coerceList(response.data);
    }
    if (response is List<dynamic>) {
      return response;
    }
    if (response is List) {
      return response.cast<dynamic>();
    }
    if (response == null) {
      return const [];
    }
    throw FormatException('Unexpected response type: ${response.runtimeType}');
  }

  List<Member> _mapMembers(List<dynamic> data) {
    final members = <Member>[];
    for (final item in data) {
      if (item is Map<String, dynamic>) {
        members.add(Member.fromJson(item));
      } else if (item is Map) {
        final mapped = item.map((key, dynamic value) => MapEntry(key.toString(), value));
        members.add(Member.fromJson(mapped));
      }
    }
    return members;
  }

  /// Get member by ID
  Future<Member?> getMemberById(String id) async {
    if (!_isReady) return null;

    try {
      final response = await _readClient
          .from('members')
          .select()
          .eq('id', id)
          .single();

      return Member.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('❌ Error fetching member by ID: $e');
      return null;
    }
  }

  /// Fetch full member records for a set of ids (order not guaranteed).
  /// Used by roster-driven bulk actions that hold member ids but need Member
  /// objects to hand to the bulk message/email screens.
  Future<List<Member>> membersByIds(List<String> ids) async {
    if (!_isReady || ids.isEmpty) return const <Member>[];

    try {
      final response =
          await _readClient.from('members').select().inFilter('id', ids);
      return (response as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(Member.fromJson)
          .toList();
    } catch (e) {
      debugPrint('❌ Error fetching members by ids: $e');
      return const <Member>[];
    }
  }

  /// Get member by phone number (E.164 format)
  /// This is the KEY lookup for linking to BlueBubbles Handles
  Future<Member?> getMemberByPhone(String phone) async {
    if (!_isReady) return null;

    final candidates = buildPhoneLookupCandidates(phone);
    if (candidates.isEmpty) return null;

    try {
      final filters = <String>[];
      for (final candidate in candidates) {
        final safe = escapeForOr(candidate);
        filters.add('phone_e164.eq.$safe');
        filters.add('phone.eq.$safe');
      }

      var query = _readClient.from('members').select();
      if (filters.isNotEmpty) {
        query = query.or(filters.join(','));
      } else {
        query = query.eq('phone_e164', phone);
      }

      final response = await query.limit(1).maybeSingle();
      if (response == null) return null;

      if (response is Map<String, dynamic>) {
        return Member.fromJson(response);
      }

      if (response is Map) {
        return Member.fromJson(response.map((key, dynamic value) => MapEntry(key.toString(), value)));
      }

      throw FormatException('Unexpected response type: ${response.runtimeType}');
    } catch (e) {
      debugPrint('❌ Error fetching member by phone: $e');
      return null;
    }
  }

  /// Get profile photo URLs for members by their email addresses
  /// Returns a map of email -> profile photo URL
  Future<Map<String, String>> getMemberPhotosByEmails(List<String> emails) async {
    if (!_isReady || emails.isEmpty) return {};

    try {
      // Filter out null/empty emails and lowercase for matching
      final validEmails = emails
          .where((e) => e.isNotEmpty)
          .map((e) => e.toLowerCase())
          .toList();

      if (validEmails.isEmpty) return {};

      debugPrint('[MemberRepository] Fetching photos for ${validEmails.length} emails');

      // Use Supabase.instance.client directly to ensure proper auth headers
      // The _readClient getter may return service role client which can have issues
      final client = Supabase.instance.client;

      final response = await client
          .from('members')
          .select('email, profile_pictures')
          .inFilter('email', validEmails);

      debugPrint('[MemberRepository] Got ${(response as List).length} members with profile_pictures data');

      final Map<String, String> result = {};
      for (final row in response as List<dynamic>) {
        final email = row['email']?.toString().toLowerCase();
        if (email == null || email.isEmpty) continue;

        final profilePictures = row['profile_pictures'];
        if (profilePictures == null) continue;

        // kDebugMode: debugPrint is NOT stripped in release builds, and each
        // per-email line becomes a Sentry breadcrumb — this loop was filling
        // ~90% of the 100-breadcrumb buffer.
        if (kDebugMode) {
          debugPrint('[MemberRepository] Raw profile_pictures for $email: $profilePictures');
        }

        // Parse the profile pictures to get the primary photo URL
        final photos = MemberProfilePhoto.parseList(profilePictures);
        if (kDebugMode) {
          debugPrint('[MemberRepository] Parsed ${photos.length} photos for $email');
        }

        if (photos.isEmpty) continue;

        // Try to find primary photo, otherwise use first one
        final primaryPhoto = photos.firstWhereOrNull((p) => p.isPrimary) ?? photos.first;
        final url = primaryPhoto.publicUrl;
        if (kDebugMode) {
          debugPrint('[MemberRepository] Photo URL for $email: $url');
        }

        if (url != null && url.isNotEmpty) {
          result[email] = url;
          if (kDebugMode) {
            debugPrint('[MemberRepository] ✓ Added photo for $email');
          }
        }
      }

      debugPrint('[MemberRepository] Returning ${result.length} photo URLs');
      return result;
    } catch (e, stackTrace) {
      debugPrint('❌ Error fetching member photos by emails: $e');
      debugPrint('[MemberRepository] Stack trace: $stackTrace');
      return {};
    }
  }

  /// Get all unique counties (for filter UI)
  /// Only includes counties from membership eligible members
  Future<List<String>> getUniqueCounties() async {
    if (!_isReady) return [];

    try {
      final response = await _readClient
          .from('members')
          .select('county')
          .eq('membership_eligible', true)
          .not('county', 'is', null);

      final counties = (response as List<dynamic>)
          .map((item) => Member.normalizeCountyLabel(item['county']))
          .whereType<String>()
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList();

      counties.sort();
      return counties;
    } catch (e) {
      debugPrint('❌ Error fetching counties: $e');
      return [];
    }
  }

  Future<Map<String, int>> getCountyCounts() =>
      _aggregateTextField('county', normalize: Member.normalizeCountyLabel);

  Future<Map<String, int>> getDistrictCounts() => _aggregateTextField(
        'congressional_district',
        normalize: Member.normalizeDistrict,
        postProcess: Member.formatDistrictLabel,
      );

  Future<Map<String, int>> getHighSchoolCounts() => _aggregateTextField(
        'high_school',
        normalize: Member.normalizeText,
      );

  Future<Map<String, int>> getCollegeCounts() => _aggregateTextField(
        'college',
        normalize: Member.normalizeText,
      );

  Future<Map<String, int>> getSexualOrientationCounts() => _aggregateTextField(
        'sexual_orientation',
        normalize: Member.normalizeText,
      );

  Future<Map<String, int>> getCommitteeCounts() async {
    if (!_isReady) return {};

    try {
      // Only aggregate from membership eligible members for bulk messaging safety
      final response = await _readClient
          .from('members')
          .select('committee')
          .eq('membership_eligible', true);
      final counts = <String, int>{};

      for (final item in response as List<dynamic>) {
        final values = Member.normalizeTextList(item['committee']);
        for (final committee in values) {
          final value = committee.trim();
          if (value.isEmpty) continue;
          counts[value] = (counts[value] ?? 0) + 1;
        }
      }

      return _sortCounts(counts);
    } catch (e) {
      debugPrint('❌ Error aggregating committee counts: $e');
      return {};
    }
  }

  Future<Map<String, int>> getLeadershipCountsByChapter() async {
    if (!_isReady) return {};

    try {
      // Only aggregate from membership eligible members for bulk messaging safety
      final response = await _readClient
          .from('members')
          .select('chapter_name, chapter_position')
          .eq('membership_eligible', true)
          .not('chapter_position', 'is', null);

      final counts = <String, int>{};
      for (final item in response as List<dynamic>) {
        final chapter = Member.normalizeText(item['chapter_name']);
        final position = Member.normalizeText(item['chapter_position']);
        if (chapter == null || position == null) continue;
        final trimmed = chapter.trim();
        if (trimmed.isEmpty) continue;
        counts[trimmed] = (counts[trimmed] ?? 0) + 1;
      }

      return _sortCounts(counts);
    } catch (e) {
      debugPrint('❌ Error aggregating leadership counts: $e');
      return {};
    }
  }

  Future<AgeBounds> getAgeBounds() async {
    if (!_isReady) return const AgeBounds();

    try {
      // Only aggregate from membership eligible members for bulk messaging safety
      final response = await _readClient
          .from('members')
          .select('date_of_birth')
          .eq('membership_eligible', true);
      int? minAge;
      int? maxAge;
      final now = DateTime.now();

      for (final item in response as List<dynamic>) {
        final raw = item['date_of_birth'];
        if (raw is! String || raw.isEmpty) continue;
        final parsed = DateTime.tryParse(raw);
        if (parsed == null) continue;
        final age = _calculateAge(parsed, reference: now);
        if (age == null) continue;
        if (minAge == null || age < minAge) {
          minAge = age;
        }
        if (maxAge == null || age > maxAge) {
          maxAge = age;
        }
      }

      return AgeBounds(min: minAge, max: maxAge);
    } catch (e) {
      debugPrint('❌ Error computing age bounds: $e');
      return const AgeBounds();
    }
  }

  Future<Map<String, int>> getChapterStatusCounts() => _aggregateTextField(
        'current_chapter_member',
        normalize: Member.normalizeText,
      );

  Future<Map<String, int>> getChapterCounts() => _aggregateTextField(
        'chapter_name',
        normalize: Member.normalizeText,
      );

  Future<Map<String, int>> getGraduationYearCounts() => _aggregateTextField(
        'graduation_year',
        normalize: Member.normalizeText,
      );

  Future<Map<String, int>> getPronounCounts() => _aggregateTextField(
        'preferred_pronouns',
        normalize: Member.normalizeText,
      );

  Future<Map<String, int>> getGenderIdentityCounts() => _aggregateTextField(
        'gender_identity',
        normalize: Member.normalizeText,
      );

  Future<Map<String, int>> getRaceCounts() => _aggregateTextField(
        'race',
        normalize: Member.normalizeText,
      );

  Future<Map<String, int>> getCommunityTypeCounts() => _aggregateTextField(
        'community_type',
        normalize: Member.normalizeText,
      );

  Future<Map<String, int>> getChapterPositionCounts() => _aggregateTextField(
        'chapter_position',
        normalize: Member.normalizeText,
      );

  Future<Map<String, int>> getIndustryCounts() => _aggregateTextField(
        'industry',
        normalize: Member.normalizeText,
      );

  Future<Map<String, int>> getEducationLevelCounts() => _aggregateTextField(
        'education_level',
        normalize: Member.normalizeText,
      );

  Future<Map<String, int>> getLanguageCounts() => _aggregateDelimitedField('languages');

  Future<Map<String, int>> getAgeBucketCounts() async {
    if (!_isReady) return {};

    try {
      // Only aggregate from membership eligible members for bulk messaging safety
      final response = await _readClient
          .from('members')
          .select('date_of_birth')
          .eq('membership_eligible', true);
      final now = DateTime.now();
      final buckets = LinkedHashMap<String, int>.fromEntries([
        MapEntry('14-17', 0),
        MapEntry('18-21', 0),
        MapEntry('22-25', 0),
        MapEntry('26-29', 0),
        MapEntry('30-33', 0),
        MapEntry('34-36', 0),
        MapEntry('37+', 0),
        MapEntry('Unknown', 0),
      ]);

      for (final item in response as List<dynamic>) {
        final raw = item['date_of_birth'];
        int? age;
        if (raw is String && raw.isNotEmpty) {
          final parsed = DateTime.tryParse(raw);
          if (parsed != null) {
            age = now.year - parsed.year;
            if (now.month < parsed.month ||
                (now.month == parsed.month && now.day < parsed.day)) {
              age--;
            }
          }
        }

        final bucket = _bucketForAge(age);
        buckets[bucket] = (buckets[bucket] ?? 0) + 1;
      }

      final cleaned = LinkedHashMap<String, int>();
      for (final entry in buckets.entries) {
        if (entry.value > 0) {
          cleaned[entry.key] = entry.value;
        }
      }

      return cleaned.isEmpty ? {} : cleaned;
    } catch (e) {
      debugPrint('❌ Error computing age buckets: $e');
      return {};
    }
  }

  String _bucketForAge(int? age) {
    if (age == null || age < 0) return 'Unknown';
    if (age <= 17) return '14-17';
    if (age <= 21) return '18-21';
    if (age <= 25) return '22-25';
    if (age <= 29) return '26-29';
    if (age <= 33) return '30-33';
    if (age <= 36) return '34-36';
    return '37+';
  }

  Future<Map<String, int>> getRegisteredVoterCounts() => _aggregateBooleanField(
        'registered_voter',
        trueLabel: 'Registered',
        falseLabel: 'Not Registered',
      );

  Future<List<Member>> getRecentMembers({int limit = 5}) async {
    if (!_isReady) return [];

    try {
      final response = await _readClient
          .from('members')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List<dynamic>)
          .map((json) => Member.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ Error fetching recent members: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> fetchDashboardMetrics() async {
    if (!_isReady) {
      return _createEmptyDashboardMetrics();
    }

    Map<String, dynamic>? rawPayload;
    Object? lastError;

    for (final source in _dashboardMetricsSources) {
      try {
        final response = await _readClient.rpc(source);
        rawPayload = _coerceJsonMap(response);
        if (rawPayload != null && rawPayload.isNotEmpty) {
          break;
        }
      } catch (error) {
        lastError = error;
      }

      try {
        final response = await _readClient.from(source).select().limit(1).maybeSingle();
        rawPayload = _coerceJsonMap(response);
        if (rawPayload != null && rawPayload.isNotEmpty) {
          break;
        }
      } catch (error) {
        lastError = error;
      }
    }

    if (rawPayload != null && rawPayload.isNotEmpty) {
      final normalized = _normalizeDashboardMetrics(rawPayload);
      if (normalized != null) {
        return normalized;
      }
    }

    if (lastError != null) {
      debugPrint('⚠️ Falling back to local dashboard aggregation: $lastError');
    }

    return _buildFallbackDashboardMetrics();
  }

  /// Get all unique congressional districts (for filter UI)
  /// Only includes districts from membership eligible members
  Future<List<String>> getUniqueCongressionalDistricts() async {
    if (!_isReady) return [];

    try {
      final response = await _readClient
          .from('members')
          .select('congressional_district')
          .eq('membership_eligible', true)
          .not('congressional_district', 'is', null);

      final districts = (response as List<dynamic>)
          .map((item) => Member.normalizeDistrict(item['congressional_district']))
          .map((value) => Member.formatDistrictLabel(value))
          .whereType<String>()
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList();

      districts.sort();
      return districts;
    } catch (e) {
      debugPrint('❌ Error fetching congressional districts: $e');
      return [];
    }
  }

  /// Get all unique committees (for filter UI)
  /// Only includes committees from membership eligible members
  Future<List<String>> getUniqueCommittees() async {
    if (!_isReady) return [];

    try {
      final response = await _readClient
          .from('members')
          .select('committee')
          .eq('membership_eligible', true)
          .not('committee', 'is', null);

      final allCommittees = <String>{};
      for (final item in response as List<dynamic>) {
        final committees = item['committee'];
        final normalized = Member.normalizeTextList(committees);
        allCommittees.addAll(normalized.map((value) => value.trim()).where((value) => value.isNotEmpty));
      }

      final sorted = allCommittees.toList()..sort();
      return sorted;
    } catch (e) {
      debugPrint('❌ Error fetching committees: $e');
      return [];
    }
  }

  /// Get all unique high schools (for filter UI)
  /// Only includes high schools from membership eligible members
  Future<List<String>> getUniqueHighSchools() async {
    if (!_isReady) return [];

    try {
      final response = await _readClient
          .from('members')
          .select('high_school')
          .eq('membership_eligible', true)
          .not('high_school', 'is', null);

      final schools = (response as List<dynamic>)
          .map((item) => Member.normalizeText(item['high_school']))
          .whereType<String>()
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList();

      schools.sort();
      return schools;
    } catch (e) {
      debugPrint('❌ Error fetching high schools: $e');
      return [];
    }
  }

  /// Get all unique colleges (for filter UI)
  /// Only includes colleges from membership eligible members
  Future<List<String>> getUniqueColleges() async {
    if (!_isReady) return [];

    try {
      final response = await _readClient
          .from('members')
          .select('college')
          .eq('membership_eligible', true)
          .not('college', 'is', null);

      final colleges = (response as List<dynamic>)
          .map((item) => Member.normalizeText(item['college']))
          .whereType<String>()
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList();

      colleges.sort();
      return colleges;
    } catch (e) {
      debugPrint('❌ Error fetching colleges: $e');
      return [];
    }
  }

  /// Get all unique chapter names (for filter UI)
  /// Only includes chapters from membership eligible members
  Future<List<String>> getUniqueChapterNames() async {
    if (!_isReady) return [];

    try {
      final response = await _readClient
          .from('members')
          .select('chapter_name')
          .eq('membership_eligible', true)
          .not('chapter_name', 'is', null);

      final chapters = (response as List<dynamic>)
          .map((item) => Member.normalizeText(item['chapter_name']))
          .whereType<String>()
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList();

      chapters.sort();
      return chapters;
    } catch (e) {
      debugPrint('❌ Error fetching chapter names: $e');
      return [];
    }
  }

  /// Update member's last contacted timestamp
  /// Returns true if the write succeeded. Callers that batch this over many
  /// members rely on the bool to count failures instead of reporting every
  /// row as saved.
  Future<bool> updateLastContacted(String memberId) async {
    if (!_isReady) return false;

    try {
      await _writeClient
          .from('members')
          .update({'last_contacted': DateTime.now().toUtc().toIso8601String()})
          .eq('id', memberId);
      return true;
    } catch (e) {
      debugPrint('❌ Error updating last contacted: $e');
      return false;
    }
  }

  /// Update member's intro sent timestamp
  Future<void> markIntroSent(String memberId) async {
    if (!_isReady) return;

    try {
      await _writeClient
          .from('members')
          .update({'intro_sent_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', memberId);
    } catch (e) {
      debugPrint('❌ Error marking intro sent: $e');
    }
  }

  /// Update member's opt-out status
  Future<void> updateOptOutStatus(
    String memberId,
    bool optOut, {
    String? reason,
  }) async {
    if (!_isReady) return;

    try {
      final data = {
        'opt_out': optOut,
        optOut ? 'opt_out_date' : 'opt_in_date':
            DateTime.now().toUtc().toIso8601String(),
      };

      if (reason != null) {
        data['opt_out_reason'] = reason;
      }

      await _writeClient
          .from('members')
          .update(data)
          .eq('id', memberId);
    } catch (e) {
      debugPrint('❌ Error updating opt-out status: $e');
    }
  }

  /// Update member notes
  /// Returns true if the write succeeded, so batched callers can count
  /// failures rather than reporting an RLS-rejected write as saved.
  Future<bool> updateNotes(String memberId, String notes) async {
    if (!_isReady) return false;

    try {
      await _writeClient
          .from('members')
          .update({'notes': notes})
          .eq('id', memberId);
      return true;
    } catch (e) {
      debugPrint('❌ Error updating notes: $e');
      return false;
    }
  }

  Future<Member?> updateMemberFields(String memberId, Map<String, dynamic> updates) async {
    if (!_isReady || updates.isEmpty) return null;

    final payload = <String, dynamic>{};
    updates.forEach((key, value) {
      if (key == 'executive') {
        payload[key] = Member.coerceBool(value) ?? false;
        return;
      }

      if (key == 'executive_title' || key == 'executive_role') {
        payload[key] = Member.normalizeText(value);
        return;
      }

      if (key == 'internal_member_info') {
        if (value is MemberInternalInfo) {
          payload[key] = value.toJson();
        } else if (value is Map<String, dynamic>) {
          payload[key] = value;
        } else if (value is Map) {
          payload[key] =
              value.map((dynamic mapKey, dynamic mapValue) => MapEntry(mapKey.toString(), mapValue));
        } else {
          final parsed = MemberInternalInfo.tryParse(value);
          payload[key] = parsed?.toJson();
        }
        return;
      }

      if (value is MemberInternalInfo) {
        payload[key] = value.toJson();
        return;
      }

      payload[key] = value;
    });

    try {
      final response = await _writeClient
          .from('members')
          .update(payload)
          .eq('id', memberId)
          .select()
          .maybeSingle();

      final json = _coerceJsonMap(response);
      if (json == null) {
        throw const FormatException('Supabase returned an unexpected member payload');
      }
      return Member.fromJson(json);
    } catch (e) {
      debugPrint('❌ Error updating member: $e');
      rethrow;
    }
  }

  /// Upload a new profile photo for the given member and persist metadata.
  Future<Member?> uploadProfilePhoto({
    required Member member,
    required PlatformFile file,
    bool makePrimary = true,
  }) async {
    if (!_isReady) return null;

    final bytes = await _resolveFileBytes(file);
    final now = DateTime.now().toUtc();
    final bucket = 'member-photos';
    final sanitizedName = _sanitizeFileName(file.name);
    final path = '${member.id}/$sanitizedName-${now.millisecondsSinceEpoch}';
    final contentType = mime(file.name) ?? 'application/octet-stream';

    await _writeClient.storage
        .from(bucket)
        .uploadBinary(path, bytes, fileOptions: FileOptions(contentType: contentType, upsert: true));

    final newPhoto = MemberProfilePhoto(
      path: path,
      bucket: bucket,
      filename: file.name,
      uploadedAt: now,
      isPrimary: makePrimary,
    );

    final updatedPhotos = <MemberProfilePhoto>[
      newPhoto,
      ...member.profilePhotos.map((photo) => makePrimary ? photo.copyWith(isPrimary: false) : photo),
    ];

    try {
      final updated = await updateMemberFields(member.id, {
        'profile_pictures': updatedPhotos.map((photo) => photo.toJson()).toList(),
      });
      return updated ?? member.copyWith(profilePhotos: updatedPhotos);
    } catch (error) {
      rethrow;
    }
  }

  Future<Member?> saveInternalReportEntry({
    required Member member,
    required MemberInternalReportEntry entry,
    List<PlatformFile> newFiles = const [],
    bool replaceExistingAttachments = false,
  }) async {
    if (!_isReady) return null;

    final uploads = <MemberInternalReportAttachment>[];
    try {
      for (final file in newFiles) {
        uploads.add(await _uploadInternalReportFile(member: member, file: file));
      }
    } catch (error) {
      for (final attachment in uploads) {
        await _safeRemoveAttachment(attachment);
      }
      rethrow;
    }

    final existingAttachments = replaceExistingAttachments
        ? <MemberInternalReportAttachment>[]
        : entry.attachments
            .where((attachment) =>
                !attachment.isLocalPlaceholder && attachment.path.trim().isNotEmpty)
            .toList();

    final attachments = <MemberInternalReportAttachment>[...existingAttachments, ...uploads];
    final description = entry.description?.trim();
    final resolvedId = entry.id.isEmpty ? MemberInternalReportEntry.generateId() : entry.id;
    final createdAt = entry.createdAt;
    final now = DateTime.now().toUtc();

    final attachmentsChanged = replaceExistingAttachments || newFiles.isNotEmpty;
    final descriptionChanged = description != entry.description;
    final resolvedType = attachmentsChanged || descriptionChanged ? null : entry.type;

    final updatedEntry = MemberInternalReportEntry(
      id: resolvedId,
      type: resolvedType,
      description: description,
      attachments: attachments,
      metadata: entry.metadata,
      createdAt: createdAt,
      updatedAt: now,
    );

    final updatedEntries = <MemberInternalReportEntry>[];
    var replaced = false;
    for (final existing in member.internalInfo.reports) {
      if (existing.id == resolvedId) {
        updatedEntries.add(updatedEntry);
        replaced = true;
      } else {
        updatedEntries.add(existing);
      }
    }
    if (!replaced) {
      updatedEntries.insert(0, updatedEntry);
    }

    final updatedInfo = member.internalInfo.copyWith(reports: updatedEntries);

    try {
      final updated = await updateMemberFields(member.id, {
        'internal_member_info': updatedInfo.toJson(),
      });
      return updated ?? member.copyWith(internalInfo: updatedInfo);
    } catch (error) {
      for (final attachment in uploads) {
        await _safeRemoveAttachment(attachment);
      }
      rethrow;
    }
  }

  Future<Member?> deleteInternalReportEntry({
    required Member member,
    required String entryId,
  }) async {
    if (!_isReady) return null;

    final existing = member.internalInfo.reports.firstWhereOrNull((entry) => entry.id == entryId);
    if (existing == null) {
      return member;
    }

    final remaining =
        member.internalInfo.reports.where((entry) => entry.id != entryId).toList();
    final updatedInfo = member.internalInfo.copyWith(reports: remaining);

    try {
      final updated = await updateMemberFields(member.id, {
        'internal_member_info': updatedInfo.toJson(),
      });
      await _removeInternalReportAttachments(existing.attachments);
      return updated ?? member.copyWith(internalInfo: updatedInfo);
    } catch (error) {
      rethrow;
    }
  }

  Future<Uint8List> _resolveFileBytes(PlatformFile file) async {
    if (file.bytes != null) {
      return file.bytes!;
    }

    if (file.path != null) {
      final dataUriBytes = _tryDecodeDataUri(file.path!);
      if (dataUriBytes != null) {
        return dataUriBytes;
      }
      if (!kIsWeb) {
        final io.File ioFile = io.File(file.path!);
        return await ioFile.readAsBytes();
      }
    }

    throw StateError('Selected file does not contain readable data.');
  }

  Uint8List? _tryDecodeDataUri(String value) {
    try {
      final uri = Uri.parse(value);
      final data = uri.data;
      if (data == null) {
        return null;
      }
      return Uint8List.fromList(data.contentAsBytes());
    } catch (_) {
      return null;
    }
  }

  String _sanitizeFileName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return 'member-photo';
    }
    final safe = trimmed.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return safe.replaceAll(RegExp(r'_+'), '_');
  }

  Future<MemberInternalReportAttachment> _uploadInternalReportFile({
    required Member member,
    required PlatformFile file,
  }) async {
    final bytes = await _resolveFileBytes(file);
    final now = DateTime.now().toUtc();
    final sanitizedName = _sanitizeFileName(file.name);
    final path = '${member.id}/$sanitizedName-${now.millisecondsSinceEpoch}';
    final contentType = mime(file.name) ?? 'application/octet-stream';

    await _writeClient.storage.from(_documentsBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );

    return MemberInternalReportAttachment(
      bucket: _documentsBucket,
      path: path,
      filename: file.name,
      contentType: contentType,
      size: bytes.length,
      uploadedAt: now,
    );
  }

  Future<void> _removeInternalReportAttachments(
    List<MemberInternalReportAttachment> attachments,
  ) async {
    for (final attachment in attachments) {
      await _safeRemoveAttachment(attachment);
    }
  }

  Future<void> _safeRemoveAttachment(MemberInternalReportAttachment attachment) async {
    final path = attachment.path.trim();
    if (path.isEmpty) return;
    try {
      await _writeClient.storage
          .from(attachment.bucket.isEmpty ? _documentsBucket : attachment.bucket)
          .remove([path]);
    } catch (e) {
      debugPrint('MemberRepository._safeRemoveAttachment error: $e');
    }
  }

  /// Search members by name or phone
  /// Only returns membership eligible members for bulk messaging safety
  Future<List<Member>> searchMembers(String query) async {
    if (!_isReady) return [];

    try {
      final response = await _readClient
          .from('members')
          .select()
          .eq('membership_eligible', true)
          .or(buildIlikeOrClauses(const ['name', 'phone', 'phone_e164'], query));

      return (response as List<dynamic>)
          .map((json) => Member.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ Error searching members: $e');
      return [];
    }
  }

  Future<Map<String, int>> _aggregateTextField(
    String column, {
    String? Function(dynamic value)? normalize,
    String? Function(String value)? postProcess,
  }) async {
    if (!_isReady) return {};

    try {
      // Only aggregate from membership eligible members for bulk messaging safety
      final response = await _readClient
          .from('members')
          .select(column)
          .eq('membership_eligible', true);
      final counts = <String, int>{};

      for (final item in response as List<dynamic>) {
        final raw = item[column];
        String? value = normalize != null ? normalize(raw) : Member.normalizeText(raw);
        if (value == null || value.isEmpty) continue;
        if (postProcess != null) {
          value = postProcess(value) ?? value;
        }
        final cleaned = value.trim();
        if (cleaned.isEmpty) continue;
        counts[cleaned] = (counts[cleaned] ?? 0) + 1;
      }

      return _sortCounts(counts);
    } catch (e) {
      debugPrint('❌ Error aggregating $column counts: $e');
      return {};
    }
  }

  Future<Map<String, int>> _aggregateDelimitedField(String column) async {
    if (!_isReady) return {};

    try {
      // Only aggregate from membership eligible members for bulk messaging safety
      final response = await _readClient
          .from('members')
          .select(column)
          .eq('membership_eligible', true);
      final counts = <String, int>{};
      final delimiter = RegExp(r'[;,/\n|]+');

      for (final item in response as List<dynamic>) {
        final raw = item[column];
        if (raw == null) continue;

        Iterable<String> values;
        if (raw is Iterable) {
          values = Member.normalizeTextList(raw);
        } else {
          final normalized = Member.normalizeText(raw);
          if (normalized == null || normalized.isEmpty) continue;
          values = normalized.split(delimiter).map((value) => value.trim()).where((value) => value.isNotEmpty);
        }

        final normalizedValues = <String>{};
        for (final value in values) {
          final cleaned = Member.normalizeText(value) ?? value;
          final trimmed = cleaned.trim();
          if (trimmed.isEmpty) continue;
          normalizedValues.add(trimmed);
        }

        for (final entry in normalizedValues) {
          counts[entry] = (counts[entry] ?? 0) + 1;
        }
      }

      return _sortCounts(counts);
    } catch (e) {
      debugPrint('❌ Error aggregating $column list counts: $e');
      return {};
    }
  }

  Future<Map<String, int>> _aggregateBooleanField(
    String column, {
    String trueLabel = 'Yes',
    String falseLabel = 'No',
  }) async {
    if (!_isReady) return {};

    try {
      // Only aggregate from membership eligible members for bulk messaging safety
      final response = await _readClient
          .from('members')
          .select(column)
          .eq('membership_eligible', true);
      int trueCount = 0;
      int falseCount = 0;

      for (final item in response as List<dynamic>) {
        final value = item[column];
        if (value is bool) {
          if (value) {
            trueCount += 1;
          } else {
            falseCount += 1;
          }
        }
      }

      final counts = <String, int>{};
      if (trueCount > 0) counts[trueLabel] = trueCount;
      if (falseCount > 0) counts[falseLabel] = falseCount;
      return _sortCounts(counts);
    } catch (e) {
      debugPrint('❌ Error aggregating $column boolean counts: $e');
      return {};
    }
  }

  Map<String, int> _sortCounts(Map<String, int> counts) {
    final entries = counts.entries.toList()
      ..sort((a, b) {
        final valueCompare = b.value.compareTo(a.value);
        if (valueCompare != 0) return valueCompare;
        return a.key.compareTo(b.key);
      });
    return {for (final entry in entries) entry.key: entry.value};
  }

  /// Total eligible members, for the county tile's headline and for deriving
  /// how many have no county on file.
  ///
  /// That derivation is subtraction rather than a query on purpose: PostgREST
  /// cannot express "county IS NULL OR county = ''" in one filter, and two
  /// numbers on a tile that do not add up are worse than one number. Total
  /// minus the sum of the per-county counts is exact by construction.
  ///
  /// Applies membership_eligible, matching _applyMemberFilters and the coverage
  /// view, so every number on that tile counts the same population.
  Future<int> countEligibleMembers() async {
    if (!_isReady) return 0;
    final PostgrestResponse res = await _readClient
        .from('members')
        .select('id')
        .eq('membership_eligible', true)
        .count(CountOption.exact);
    return res.count;
  }

  /// The executive committee roster, id and name only. About fifteen rows.
  ///
  /// Deliberately does NOT filter on membership_eligible. An exec who has aged
  /// out of membership is still an exec, and this list exists to answer who was
  /// given a county and who was missed. Filtering here would quietly drop the
  /// person the question is about.
  ///
  /// Reads the executive_committee boolean, which is the derived cache of the
  /// committee array and is what is_staff() itself reads, so this agrees with
  /// the view's own gate.
  Future<List<Member>> getExecutiveRoster() async {
    if (!_isReady) return const [];
    final data = await _readClient
        .from('members')
        .select('id, name')
        .eq('executive_committee', true)
        .order('name');
    return _mapMembers(_coerceList(data));
  }

  /// Every eligible member living in any of [counties], for the County Outreach
  /// page. Full listing columns (name, phone, email, county, district, etc.) so
  /// the page can show and select people and hand them to the text/email send
  /// paths. Applies membership_eligible exactly like every other member query,
  /// so the outreach set is the same population the rest of the CRM counts.
  Future<List<Member>> getMembersInCounties(List<String> counties) async {
    if (!_isReady) return const [];
    final clean = counties
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toList();
    if (clean.isEmpty) return const [];
    final data = await _readClient
        .from('members')
        .select(_resolveColumnSelection(null))
        .eq('membership_eligible', true)
        .inFilter('county', clean)
        .order('county')
        .order('name');
    return _mapMembers(_coerceList(data));
  }

  /// Eligible members whose `house_district` is one of [districts]. Values are
  /// coerced to bare digits ('CD-1' -> '1', '052' -> '52') to match how member
  /// house/senate districts and the map GeoJSON both store them.
  Future<List<Member>> getMembersInHouseDistricts(List<String> districts) =>
      _membersInDistrictField('house_district', districts);

  /// Eligible members whose `senate_district` is one of [districts].
  Future<List<Member>> getMembersInSenateDistricts(List<String> districts) =>
      _membersInDistrictField('senate_district', districts);

  static String? _bareDigits(String raw) {
    final d = raw.replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp(r'^0+(?=\d)'), '');
    return d.isEmpty ? null : d;
  }

  Future<List<Member>> _membersInDistrictField(
      String column, List<String> districts) async {
    if (!_isReady) return const [];
    final clean = districts
        .map((d) => _bareDigits(d))
        .whereType<String>()
        .toSet()
        .toList();
    if (clean.isEmpty) return const [];
    // Page past the 1000-row cap so a dense multi-district selection returns
    // every eligible member, not just the first page.
    final all = <dynamic>[];
    const pageSize = 1000;
    var offset = 0;
    while (true) {
      final data = await _readClient
          .from('members')
          .select(_resolveColumnSelection(null))
          .eq('membership_eligible', true)
          .inFilter(column, clean)
          .order('name')
          .range(offset, offset + pageSize - 1);
      final page = _coerceList(data);
      all.addAll(page);
      if (page.length < pageSize) break;
      offset += pageSize;
    }
    return _mapMembers(all);
  }

  /// Count of eligible members per district/county, keyed to match the map
  /// GeoJSON. [field] is one of 'county', 'congressional_district',
  /// 'house_district', 'senate_district'. County keys are the normalized county
  /// label; district keys are bare digits. Used to color the map by member
  /// density.
  Future<Map<String, int>> getMemberCountsByField(String field) async {
    if (!_isReady) return const {};
    final counts = <String, int>{};
    const pageSize = 1000;
    var offset = 0;
    // Page past the 1000-row cap so the map density choropleth, member range,
    // and priority-district ranking stay accurate once eligible membership
    // grows beyond a single page.
    while (true) {
      final response = await _readClient
          .from('members')
          .select(field)
          .eq('membership_eligible', true)
          .not(field, 'is', null)
          .range(offset, offset + pageSize - 1);
      final rows = _coerceList(response);
      for (final row in rows) {
        final raw = (row as Map)[field];
        if (raw == null) continue;
        final String? key = field == 'county'
            ? Member.normalizeCountyLabel(raw)
            : _bareDigits(raw.toString());
        if (key == null || key.isEmpty) continue;
        counts[key] = (counts[key] ?? 0) + 1;
      }
      if (rows.length < pageSize) break;
      offset += pageSize;
    }
    return counts;
  }

  /// Get member statistics
  Future<Map<String, dynamic>> getMemberStats() async {
    if (!_isReady) {
      return {'total': 0, 'optedOut': 0, 'contactable': 0, 'withPhone': 0};
    }

    try {
      final PostgrestResponse totalResponse = await _readClient
          .from('members')
          .select('id')
          .count(CountOption.exact);
      final total = totalResponse.count ?? 0;

      final PostgrestResponse optedOutResponse = await _readClient
          .from('members')
          .select('id')
          .eq('opt_out', true)
          .count(CountOption.exact);
      final optedOut = optedOutResponse.count ?? 0;

      final PostgrestResponse withPhoneResponse = await _readClient
          .from('members')
          .select('id')
          .not('phone_e164', 'is', null)
          .count(CountOption.exact);
      final withPhone = withPhoneResponse.count ?? 0;

      return {
        'total': total,
        'optedOut': optedOut,
        'contactable': total - optedOut,
        'withPhone': withPhone,
      };
    } catch (e) {
      debugPrint('❌ Error fetching member stats: $e');
      return {
        'total': 0,
        'optedOut': 0,
        'contactable': 0,
        'withPhone': 0,
      };
    }
  }

  Future<Map<String, dynamic>> _buildFallbackDashboardMetrics() async {
    final metrics = _createEmptyDashboardMetrics();

    if (!_isReady) {
      return metrics;
    }

    try {
      final results = await Future.wait<dynamic>([
        getMemberStats(),
        getCountyCounts(),
        getDistrictCounts(),
        getCommitteeCounts(),
        getHighSchoolCounts(),
        getCollegeCounts(),
        getChapterCounts(),
        getChapterStatusCounts(),
        getGraduationYearCounts(),
        getPronounCounts(),
        getGenderIdentityCounts(),
        getRaceCounts(),
        getLanguageCounts(),
        getCommunityTypeCounts(),
        getIndustryCounts(),
        getEducationLevelCounts(),
        getRegisteredVoterCounts(),
        getSexualOrientationCounts(),
        getAgeBucketCounts(),
        getRecentMembers(limit: 6),
      ]);

      return {
        'memberStats': results[0] as Map<String, dynamic>,
        'counties': results[1] as Map<String, int>,
        'districts': results[2] as Map<String, int>,
        'committees': results[3] as Map<String, int>,
        'highSchools': results[4] as Map<String, int>,
        'colleges': results[5] as Map<String, int>,
        'chapters': results[6] as Map<String, int>,
        'chapterStatuses': results[7] as Map<String, int>,
        'graduationYears': results[8] as Map<String, int>,
        'pronouns': results[9] as Map<String, int>,
        'genders': results[10] as Map<String, int>,
        'races': results[11] as Map<String, int>,
        'languages': results[12] as Map<String, int>,
        'communityTypes': results[13] as Map<String, int>,
        'industries': results[14] as Map<String, int>,
        'educationLevels': results[15] as Map<String, int>,
        'registeredVoters': results[16] as Map<String, int>,
        'sexualOrientations': results[17] as Map<String, int>,
        'ageBuckets': results[18] as Map<String, int>,
        'recentMembers': results[19] as List<Member>,
        'chatCount': null,
        'totalMessages': null,
        'weeklyMessages': null,
      };
    } catch (error) {
      debugPrint('❌ Error building fallback dashboard metrics: $error');
      return metrics;
    }
  }
}

Map<String, dynamic> _createEmptyDashboardMetrics() => {
      'memberStats': {'total': 0, 'optedOut': 0, 'contactable': 0, 'withPhone': 0},
      'counties': <String, int>{},
      'districts': <String, int>{},
      'committees': <String, int>{},
      'highSchools': <String, int>{},
      'colleges': <String, int>{},
      'chapters': <String, int>{},
      'chapterStatuses': <String, int>{},
      'graduationYears': <String, int>{},
      'pronouns': <String, int>{},
      'genders': <String, int>{},
      'races': <String, int>{},
      'languages': <String, int>{},
      'communityTypes': <String, int>{},
      'industries': <String, int>{},
      'educationLevels': <String, int>{},
      'registeredVoters': <String, int>{},
      'sexualOrientations': <String, int>{},
      'ageBuckets': <String, int>{},
      'recentMembers': <Member>[],
      'chatCount': null,
      'totalMessages': null,
      'weeklyMessages': null,
    };

Map<String, dynamic>? _normalizeDashboardMetrics(Map<String, dynamic>? raw) {
  if (raw == null) return null;

  final metrics = _createEmptyDashboardMetrics();
  final normalizedRoot = Map<String, dynamic>.from(raw);
  final countsContainer = _coerceJsonMap(raw['counts']);
  if (countsContainer != null) {
    normalizedRoot.addAll(countsContainer);
  }

  final memberStats =
      _coerceJsonMap(raw['member_stats'] ?? raw['memberStats'] ?? raw['stats']);
  if (memberStats != null && memberStats.isNotEmpty) {
    metrics['memberStats'] = {
      'total': _coerceInt(memberStats['total']) ?? 0,
      'optedOut': _coerceInt(memberStats['optedOut'] ?? memberStats['opted_out']) ?? 0,
      'contactable': _coerceInt(memberStats['contactable']) ??
          ((_coerceInt(memberStats['total']) ?? 0) -
              (_coerceInt(memberStats['optedOut'] ?? memberStats['opted_out']) ?? 0)),
      'withPhone': _coerceInt(memberStats['withPhone'] ?? memberStats['with_phone']) ?? 0,
    };
  }

  void assignCountsTo(String targetKey, List<String> keys) {
    for (final key in keys) {
      final value = normalizedRoot[key] ?? raw[key];
      final map = _coerceCountsMap(value);
      if (map != null && map.isNotEmpty) {
        metrics[targetKey] = map;
        return;
      }
    }
  }

  assignCountsTo('counties', const ['counties', 'county_counts']);
  assignCountsTo('districts',
      const ['districts', 'district_counts', 'congressionalDistricts', 'congressional_districts']);
  assignCountsTo('committees', const ['committees', 'committee_counts']);
  assignCountsTo('highSchools', const ['highSchools', 'high_schools', 'high_school_counts']);
  assignCountsTo('colleges', const ['colleges', 'college_counts']);
  assignCountsTo('chapters', const ['chapters', 'chapter_counts']);
  assignCountsTo('chapterStatuses',
      const ['chapterStatuses', 'chapter_statuses', 'chapter_status_counts']);
  assignCountsTo('graduationYears',
      const ['graduationYears', 'graduation_years', 'graduation_year_counts']);
  assignCountsTo('pronouns', const ['pronouns', 'pronoun_counts']);
  assignCountsTo('genders',
      const ['genders', 'gender_counts', 'genderIdentities', 'gender_identities']);
  assignCountsTo('races', const ['races', 'race_counts']);
  assignCountsTo('languages', const ['languages', 'language_counts']);
  assignCountsTo('communityTypes',
      const ['communityTypes', 'community_types', 'community_type_counts']);
  assignCountsTo('industries', const ['industries', 'industry_counts']);
  assignCountsTo('educationLevels',
      const ['educationLevels', 'education_levels', 'education_level_counts']);
  assignCountsTo('registeredVoters',
      const ['registeredVoters', 'registered_voters', 'registered_voter_counts']);
  assignCountsTo('sexualOrientations',
      const ['sexualOrientations', 'sexual_orientations', 'sexual_orientation_counts']);
  assignCountsTo('ageBuckets', const ['ageBuckets', 'age_buckets', 'age_bucket_counts']);

  final recentMembers = _coerceMemberList(raw['recent_members'] ?? raw['recentMembers']);
  if (recentMembers != null) {
    metrics['recentMembers'] = recentMembers;
  }

  final aggregatedChatCount = _coerceInt(raw['chat_count'] ?? raw['chatCount']);
  if (aggregatedChatCount != null) {
    metrics['chatCount'] = aggregatedChatCount;
  }

  final aggregatedTotalMessages =
      _coerceInt(raw['total_messages'] ?? raw['totalMessages']);
  if (aggregatedTotalMessages != null) {
    metrics['totalMessages'] = aggregatedTotalMessages;
  }

  final aggregatedWeeklyMessages =
      _coerceInt(raw['weekly_messages'] ?? raw['weeklyMessages']);
  if (aggregatedWeeklyMessages != null) {
    metrics['weeklyMessages'] = aggregatedWeeklyMessages;
  }

  return metrics;
}

Map<String, int>? _coerceCountsMap(dynamic value) {
  if (value == null) return null;

  if (value is Map) {
    final result = <String, int>{};
    value.forEach((key, dynamic rawValue) {
      final count = _coerceInt(rawValue);
      final label = key == null ? '' : key.toString();
      if (label.isEmpty || count == null) return;
      result[label] = count;
    });
    return result;
  }

  if (value is Iterable) {
    final result = <String, int>{};
    for (final entry in value) {
      final map = _coerceJsonMap(entry);
      if (map == null || map.isEmpty) continue;
      final label = map['label'] ?? map['key'] ?? map['name'] ?? map['value'];
      final count = _coerceInt(map['count'] ?? map['total'] ?? map['members']);
      if (label == null) continue;
      final labelText = label.toString().trim();
      if (labelText.isEmpty || count == null) continue;
      result[labelText] = count;
    }
    if (result.isNotEmpty) {
      return result;
    }
  }

  return null;
}

int? _coerceInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

List<Member>? _coerceMemberList(dynamic value) {
  if (value == null) return null;
  if (value is Iterable) {
    final members = <Member>[];
    for (final item in value) {
      final json = _coerceJsonMap(item);
      if (json == null || json.isEmpty) continue;
      try {
        members.add(Member.fromJson(json));
      } catch (error) {
        debugPrint('⚠️ Skipping invalid member payload: $error');
      }
    }
    return members;
  }
  return null;
}

class MemberFetchResult {
  final List<Member> members;
  final int? totalCount;

  const MemberFetchResult({required this.members, this.totalCount});
}

class AgeBounds {
  final int? min;
  final int? max;

  const AgeBounds({this.min, this.max});
}

Map<String, dynamic>? _coerceJsonMap(dynamic value) {
  if (value == null) return null;
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, dynamic v) => MapEntry(key.toString(), v));
  }
  if (value is PostgrestResponse) {
    return _coerceJsonMap(value.data);
  }
  return null;
}
