import 'package:bluebubbles/models/crm/chapter.dart';
import 'package:bluebubbles/models/crm/chapter_document.dart';

import 'supabase_service.dart';

class ChapterRepository {
  final CRMSupabaseService _supabase = CRMSupabaseService();

  bool get _isReady => _supabase.isInitialized;

  Future<List<Chapter>> getAllChapters() async {
    if (!_isReady) return [];

    try {
      final response = await _supabase.client
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
      final response = await _supabase.client
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
}
