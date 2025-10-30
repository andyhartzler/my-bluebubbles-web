import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:postgrest/postgrest.dart' show CountOption, PostgrestResponse;

import 'package:bluebubbles/models/crm/member.dart';

import 'supabase_service.dart';

/// Repository for member CRUD operations
/// All Supabase queries for members go through here
class MemberRepository {
  final CRMSupabaseService _supabase = CRMSupabaseService();

  bool get _isReady => _supabase.isInitialized;

  /// Get all members (with optional filters)
  Future<List<Member>> getAllMembers({
    String? county,
    String? congressionalDistrict,
    List<String>? committees,
    String? schoolName,
    String? chapterName,
    String? chapterStatus,
    int? minAge,
    int? maxAge,
    bool? optedOut,
  }) async {
    if (!_isReady) return [];

    try {
      var query = _supabase.client.from('members').select();

      if (county != null && county.isNotEmpty) {
        query = query.eq('county', county);
      }

      if (congressionalDistrict != null && congressionalDistrict.isNotEmpty) {
        query = query.eq('congressional_district', congressionalDistrict);
      }

      if (committees != null && committees.isNotEmpty) {
        query = query.overlaps('committee', committees);
      }

      if (schoolName != null && schoolName.isNotEmpty) {
        query = query.eq('school_name', schoolName);
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

      final response = await query;
      final data = response as List<dynamic>;

      List<Member> members = data
          .map((json) => Member.fromJson(json as Map<String, dynamic>))
          .toList();

      if (minAge != null || maxAge != null) {
        members = members.where((member) {
          final age = member.age;
          if (age == null) return false;
          if (minAge != null && age < minAge) return false;
          if (maxAge != null && age > maxAge) return false;
          return true;
        }).toList();
      }

      return members;
    } catch (e) {
      print('❌ Error fetching members: $e');
      rethrow;
    }
  }

  /// Get member by ID
  Future<Member?> getMemberById(String id) async {
    if (!_isReady) return null;

    try {
      final response = await _supabase.client
          .from('members')
          .select()
          .eq('id', id)
          .single();

      return Member.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      print('❌ Error fetching member by ID: $e');
      return null;
    }
  }

  /// Get member by phone number (E.164 format)
  /// This is the KEY lookup for linking to BlueBubbles Handles
  Future<Member?> getMemberByPhone(String phoneE164) async {
    if (!_isReady) return null;

    try {
      final response = await _supabase.client
          .from('members')
          .select()
          .eq('phone_e164', phoneE164)
          .maybeSingle();

      if (response == null) return null;
      return Member.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      print('❌ Error fetching member by phone: $e');
      return null;
    }
  }

  /// Get all unique counties (for filter UI)
  Future<List<String>> getUniqueCounties() async {
    if (!_isReady) return [];

    try {
      final response = await _supabase.client
          .from('members')
          .select('county')
          .not('county', 'is', null);

      final counties = (response as List<dynamic>)
          .map((item) => Member.normalizeText(item['county']))
          .whereType<String>()
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList();

      counties.sort();
      return counties;
    } catch (e) {
      print('❌ Error fetching counties: $e');
      return [];
    }
  }

  Future<Map<String, int>> getCountyCounts() => _aggregateTextField('county');

  Future<Map<String, int>> getDistrictCounts() => _aggregateTextField(
        'congressional_district',
        normalize: Member.normalizeDistrict,
        postProcess: Member.formatDistrictLabel,
      );

  Future<Map<String, int>> getSchoolCounts() => _aggregateTextField(
        'school_name',
        normalize: Member.normalizeText,
      );

  Future<Map<String, int>> getCommitteeCounts() async {
    if (!_isReady) return {};

    try {
      final response = await _supabase.client.from('members').select('committee');
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
      print('❌ Error aggregating committee counts: $e');
      return {};
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

  Future<Map<String, int>> getIndustryCounts() => _aggregateTextField(
        'industry',
        normalize: Member.normalizeText,
      );

  Future<Map<String, int>> getEducationLevelCounts() => _aggregateTextField(
        'education_level',
        normalize: Member.normalizeText,
      );

  Future<Map<String, int>> getLanguageCounts() => _aggregateDelimitedField('languages');

  Future<Map<String, int>> getRegisteredVoterCounts() => _aggregateBooleanField(
        'registered_voter',
        trueLabel: 'Registered',
        falseLabel: 'Not Registered',
      );

  Future<List<Member>> getRecentMembers({int limit = 5}) async {
    if (!_isReady) return [];

    try {
      final response = await _supabase.client
          .from('members')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List<dynamic>)
          .map((json) => Member.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('❌ Error fetching recent members: $e');
      return [];
    }
  }

  /// Get all unique congressional districts (for filter UI)
  Future<List<String>> getUniqueCongressionalDistricts() async {
    if (!_isReady) return [];

    try {
      final response = await _supabase.client
          .from('members')
          .select('congressional_district')
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
      print('❌ Error fetching congressional districts: $e');
      return [];
    }
  }

  /// Get all unique committees (for filter UI)
  Future<List<String>> getUniqueCommittees() async {
    if (!_isReady) return [];

    try {
      final response = await _supabase.client
          .from('members')
          .select('committee')
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
      print('❌ Error fetching committees: $e');
      return [];
    }
  }

  Future<List<String>> getUniqueSchools() async {
    if (!_isReady) return [];

    try {
      final response = await _supabase.client
          .from('members')
          .select('school_name')
          .not('school_name', 'is', null);

      final schools = (response as List<dynamic>)
          .map((item) => Member.normalizeText(item['school_name']))
          .whereType<String>()
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList();

      schools.sort();
      return schools;
    } catch (e) {
      print('❌ Error fetching schools: $e');
      return [];
    }
  }

  Future<List<String>> getUniqueChapterNames() async {
    if (!_isReady) return [];

    try {
      final response = await _supabase.client
          .from('members')
          .select('chapter_name')
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
      print('❌ Error fetching chapter names: $e');
      return [];
    }
  }

  /// Update member's last contacted timestamp
  Future<void> updateLastContacted(String memberId) async {
    if (!_isReady) return;

    try {
      await _supabase.client
          .from('members')
          .update({'last_contacted': DateTime.now().toIso8601String()})
          .eq('id', memberId);
    } catch (e) {
      print('❌ Error updating last contacted: $e');
    }
  }

  /// Update member's intro sent timestamp
  Future<void> markIntroSent(String memberId) async {
    if (!_isReady) return;

    try {
      await _supabase.client
          .from('members')
          .update({'intro_sent_at': DateTime.now().toIso8601String()})
          .eq('id', memberId);
    } catch (e) {
      print('❌ Error marking intro sent: $e');
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
        optOut ? 'opt_out_date' : 'opt_in_date': DateTime.now().toIso8601String(),
      };

      if (reason != null) {
        data['opt_out_reason'] = reason;
      }

      await _supabase.client
          .from('members')
          .update(data)
          .eq('id', memberId);
    } catch (e) {
      print('❌ Error updating opt-out status: $e');
    }
  }

  /// Update member notes
  Future<void> updateNotes(String memberId, String notes) async {
    if (!_isReady) return;

    try {
      await _supabase.client
          .from('members')
          .update({'notes': notes})
          .eq('id', memberId);
    } catch (e) {
      print('❌ Error updating notes: $e');
    }
  }

  /// Search members by name or phone
  Future<List<Member>> searchMembers(String query) async {
    if (!_isReady) return [];

    try {
      final response = await _supabase.client
          .from('members')
          .select()
          .or('name.ilike.%$query%,phone.ilike.%$query%,phone_e164.ilike.%$query%');

      return (response as List<dynamic>)
          .map((json) => Member.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('❌ Error searching members: $e');
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
      final response = await _supabase.client.from('members').select(column);
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
      print('❌ Error aggregating $column counts: $e');
      return {};
    }
  }

  Future<Map<String, int>> _aggregateDelimitedField(String column) async {
    if (!_isReady) return {};

    try {
      final response = await _supabase.client.from('members').select(column);
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
      print('❌ Error aggregating $column list counts: $e');
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
      final response = await _supabase.client.from('members').select(column);
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
      print('❌ Error aggregating $column boolean counts: $e');
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

  /// Get member statistics
  Future<Map<String, dynamic>> getMemberStats() async {
    if (!_isReady) {
      return {'total': 0, 'optedOut': 0, 'contactable': 0, 'withPhone': 0};
    }

    try {
      final PostgrestResponse totalResponse = await _supabase.client
          .from('members')
          .select('id')
          .count(CountOption.exact);
      final total = totalResponse.count ?? 0;

      final PostgrestResponse optedOutResponse = await _supabase.client
          .from('members')
          .select('id')
          .eq('opt_out', true)
          .count(CountOption.exact);
      final optedOut = optedOutResponse.count ?? 0;

      final PostgrestResponse withPhoneResponse = await _supabase.client
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
      print('❌ Error fetching member stats: $e');
      return {
        'total': 0,
        'optedOut': 0,
        'contactable': 0,
        'withPhone': 0,
      };
    }
  }
}
