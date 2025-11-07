import 'dart:typed_data';

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

  SupabaseClient get _readClient =>
      _supabase.hasServiceRole ? _supabase.privilegedClient : _supabase.client;

  SupabaseClient get _writeClient => _supabase.privilegedClient;

  Future<List<Chapter>> getAllChapters() async {
    if (!_isReady) return [];

    try {
      final response = await _readClient
          .from('chapters')
          .select()
          .order('standardized_name', ascending: true);

      return (response as List<dynamic>)
          .map((json) => Chapter.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('❌ Error fetching chapters: $e');
      return [];
    }
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
      print('❌ Error fetching chapter documents: $e');
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
      print('❌ Error updating chapter: $e');
      rethrow;
    }
  }
}
