import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'package:bluebubbles/models/crm/chapter.dart';
import 'package:bluebubbles/models/crm/chapter_document.dart';
import 'package:bluebubbles/database/global/platform_file.dart';
import 'package:mime_type/mime_type.dart';
import 'package:postgrest/postgrest.dart' show PostgrestResponse;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_io/io.dart' as io;

import 'supabase_service.dart';

class ChapterRepository {
  final CRMSupabaseService _supabase = CRMSupabaseService();

  bool get _isReady => _supabase.isInitialized;

  SupabaseClient get _readClient => _supabase.client;

  SupabaseClient get _writeClient => _supabase.client;

  Future<List<Chapter>> getAllChapters({String? chapterType}) async {
    if (!_isReady) return [];

    try {
      var query = _readClient
          .from('chapters')
          .select();

      if (chapterType != null && chapterType.isNotEmpty) {
        query = query.eq('chapter_type', chapterType);
      }

      final response = await query.order('standardized_name', ascending: true);

      return (response as List<dynamic>)
          .map((json) => Chapter.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ Error fetching chapters: $e');
      return [];
    }
  }

  /// Finds a chapter by name the way members link to one: case and spacing
  /// do not matter. Returns null when there is no such chapter, and throws
  /// when the lookup itself fails, so a link can tell the two apart.
  Future<Chapter?> getChapterByName(String chapterName) async {
    if (!_isReady) throw StateError('Chapters are not available yet');
    final wanted = _nameKey(chapterName);
    if (wanted.isEmpty) return null;
    final exact = await _readClient
        .from('chapters')
        .select()
        .eq('chapter_name', chapterName)
        .limit(1);
    final exactRows = exact as List<dynamic>;
    if (exactRows.isNotEmpty) {
      return Chapter.fromJson(Map<String, dynamic>.from(exactRows.first as Map));
    }
    final all = await _readClient.from('chapters').select() as List<dynamic>;
    for (final row in all) {
      final chapter = Chapter.fromJson(Map<String, dynamic>.from(row as Map));
      if (_nameKey(chapter.chapterName) == wanted) return chapter;
    }
    return null;
  }

  static String _nameKey(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Charters a chapter: active, chartered, with the date the executive
  /// committee approved it.
  Future<Chapter?> charterChapter(Chapter chapter, DateTime charterDate) {
    final date = DateTime(charterDate.year, charterDate.month, charterDate.day);
    return updateChapter(chapter.id, {
      'status': 'active',
      'is_chartered': true,
      'charter_date': date.toIso8601String().split('T').first,
      'last_updated': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Hides a pending row from charter review (a duplicate, or an answer that
  /// is not a chapter name). Members keep whatever chapter name they typed.
  Future<Chapter?> archiveChapter(Chapter chapter) {
    return updateChapter(chapter.id, {
      'status': 'archived',
      'last_updated': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Takes a row out of Archived: a chartered chapter goes back to active,
  /// anything else goes back into charter review.
  Future<Chapter?> restoreChapter(Chapter chapter) {
    return updateChapter(chapter.id, {
      'status': chapter.isChartered ? 'active' : 'pending',
      'last_updated': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<List<ChapterDocument>> getDocumentsForChapter(String chapterName) async {
    if (!_isReady) return [];

    try {
      final response = await _readClient
          .from('chapter_documents')
          .select()
          .eq('chapter_name', chapterName)
          .order('document_type', ascending: true);

      return (response as List<dynamic>)
          .map((json) => ChapterDocument.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ Error fetching chapter documents: $e');
      return [];
    }
  }

  Future<ChapterDocument?> uploadChapterDocument({
    required String chapterName,
    required PlatformFile file,
    String? documentType,
  }) async {
    if (!_isReady) return null;

    final bytes = await _resolveFileBytes(file);
    final now = DateTime.now().toUtc();
    const bucket = 'chapter-documents';
    final sanitizedChapter = _sanitizePathSegment(chapterName);
    final sanitizedFileName = _sanitizeFileName(file.name);
    final storagePath = '$sanitizedChapter/$sanitizedFileName-${now.millisecondsSinceEpoch}';
    final contentType = mime(file.name) ?? 'application/octet-stream';

    final storageBucket = _writeClient.storage.from(bucket);
    await storageBucket.uploadBinary(
      storagePath,
      bytes,
      fileOptions: FileOptions(
        contentType: contentType,
        upsert: true,
      ),
    );

    final normalizedTypeRaw = (documentType ?? '').trim();
    final normalizedType = normalizedTypeRaw.isEmpty ? 'General' : normalizedTypeRaw;
    final payload = {
      'chapter_name': chapterName,
      'document_type': normalizedType,
      'file_path': storagePath,
      'public_url': storageBucket.getPublicUrl(storagePath),
      'original_filename': file.name,
      'file_size': file.size,
      'uploaded_at': now.toIso8601String(),
    };

    final response = await _writeClient
        .from('chapter_documents')
        .insert(payload)
        .select()
        .maybeSingle();

    final json = _coerceJsonMap(response);
    if (json == null) {
      return null;
    }
    return ChapterDocument.fromJson(json);
  }

  Future<Uint8List> _resolveFileBytes(PlatformFile file) async {
    if (file.bytes != null) {
      return file.bytes!;
    }

    if (file.path != null) {
      final io.File ioFile = io.File(file.path!);
      return await ioFile.readAsBytes();
    }

    throw StateError('Selected file does not contain readable data.');
  }

  String _sanitizePathSegment(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'chapter';
    }

    var safe = trimmed
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    safe = safe.replaceFirst(RegExp(r'^_+'), '');
    safe = safe.replaceFirst(RegExp(r'_+$'), '');
    return safe.isEmpty ? 'chapter' : safe;
  }

  String _sanitizeFileName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return 'document';
    }
    final safe = trimmed.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return safe.replaceAll(RegExp(r'_+'), '_');
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

  Future<Chapter?> updateChapter(String chapterId, Map<String, dynamic> updates) async {
    if (!_isReady || updates.isEmpty) return null;

    final payload = Map<String, dynamic>.from(updates);

    try {
      final response = await _writeClient
          .from('chapters')
          .update(payload)
          .eq('id', chapterId)
          .select()
          .maybeSingle();

      if (response == null) return null;
      if (response is Map<String, dynamic>) {
        return Chapter.fromJson(response);
      }
      if (response is Map) {
        return Chapter.fromJson(
          response.map((key, dynamic value) => MapEntry(key.toString(), value)),
        );
      }
      throw const FormatException('Supabase returned an unexpected chapter payload');
    } catch (e) {
      debugPrint('❌ Error updating chapter: $e');
      rethrow;
    }
  }
}
