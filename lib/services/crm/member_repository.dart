import 'dart:collection';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:postgrest/postgrest.dart' show CountOption, PostgrestResponse;

import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/services/crm/phone_normalizer.dart';
import 'package:bluebubbles/database/global/platform_file.dart';
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

  SupabaseClient get _readClient =>
      _supabase.hasServiceRole ? _supabase.privilegedClient : _supabase.client;

  SupabaseClient get _writeClient => _supabase.privilegedClient;

  /// Get all members (with optional filters)
  Future<List<Member>> getAllMembers({
    String? county,
    String? congressionalDistrict,
    List<String>? committees,
    String? highSchool,
    String? college,
    String? chapterName,
    String? chapterStatus,
    int? minAge,
    int? maxAge,
    bool? optedOut,
  }) async {
    if (!_isReady) return [];

    try {
      var query = _readClient.from('members').select();

      if (county != null && county.isNotEmpty) {
        query = query.eq('county', county);
      }

      if (congressionalDistrict != null && congressionalDistrict.isNotEmpty) {
        query = query.eq('congressional_district', congressionalDistrict);
      }

      if (committees != null && committees.isNotEmpty) {
        query = query.overlaps('committee', committees);
      }

      if (highSchool != null && highSchool.isNotEmpty) {
        query = query.eq('high_school', highSchool);
      }

      if (college != null && college.isNotEmpty) {
        query = query.eq('college', college);
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
      final response = await _readClient
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
  Future<Member?> getMemberByPhone(String phone) async {
    if (!_isReady) return null;

    final candidates = buildPhoneLookupCandidates(phone);
    if (candidates.isEmpty) return null;

    try {
      final filters = <String>[];
      for (final candidate in candidates) {
        final escaped = candidate.replaceAll(',', '\\,');
        filters.add('phone_e164.eq.$escaped');
        filters.add('phone.eq.$escaped');
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
      print('❌ Error fetching member by phone: $e');
      return null;
    }
  }

  /// Get all unique counties (for filter UI)
  Future<List<String>> getUniqueCounties() async {
    if (!_isReady) return [];

    try {
      final response = await _readClient
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
      final response = await _readClient.from('members').select('committee');
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
      final response = await _readClient.from('members').select('date_of_birth');
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
      print('❌ Error computing age buckets: $e');
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
      print('❌ Error fetching recent members: $e');
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
      print('⚠️ Falling back to local dashboard aggregation: $lastError');
    }

    return _buildFallbackDashboardMetrics();
  }

  /// Get all unique congressional districts (for filter UI)
  Future<List<String>> getUniqueCongressionalDistricts() async {
    if (!_isReady) return [];

    try {
      final response = await _readClient
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
      final response = await _readClient
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

  Future<List<String>> getUniqueHighSchools() async {
    if (!_isReady) return [];

    try {
      final response = await _readClient
          .from('members')
          .select('high_school')
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
      print('❌ Error fetching high schools: $e');
      return [];
    }
  }

  Future<List<String>> getUniqueColleges() async {
    if (!_isReady) return [];

    try {
      final response = await _readClient
          .from('members')
          .select('college')
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
      print('❌ Error fetching colleges: $e');
      return [];
    }
  }

  Future<List<String>> getUniqueChapterNames() async {
    if (!_isReady) return [];

    try {
      final response = await _readClient
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
      await _writeClient
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
      await _writeClient
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

      await _writeClient
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
      await _writeClient
          .from('members')
          .update({'notes': notes})
          .eq('id', memberId);
    } catch (e) {
      print('❌ Error updating notes: $e');
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
      print('❌ Error updating member: $e');
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
    } catch (_) {}
  }

  /// Search members by name or phone
  Future<List<Member>> searchMembers(String query) async {
    if (!_isReady) return [];

    try {
      final response = await _readClient
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
      final response = await _readClient.from('members').select(column);
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
      final response = await _readClient.from('members').select(column);
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
      final response = await _readClient.from('members').select(column);
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
      print('❌ Error fetching member stats: $e');
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
      print('❌ Error building fallback dashboard metrics: $error');
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
        print('⚠️ Skipping invalid member payload: $error');
      }
    }
    return members;
  }
  return null;
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
