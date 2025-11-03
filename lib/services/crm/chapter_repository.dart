import 'package:bluebubbles/models/crm/chapter.dart';
import 'package:bluebubbles/models/crm/chapter_document.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
