import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_session.dart';
import '../models/chat_message.dart';
import '../models/source_document.dart';
import '../models/knowledge_stats.dart';

class AIAssistantService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ============================================
  // CHAT SESSIONS
  // ============================================

  /// Create a new chat session
  Future<ChatSession> createSession() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final response = await _supabase
        .from('knowledge_chat_sessions')
        .insert({'user_id': userId})
        .select()
        .single();

    return ChatSession.fromJson(response);
  }

  /// Get all chat sessions for current user
  Future<List<ChatSession>> getSessions({
    bool includeArchived = false,
    int limit = 50,
  }) async {
    var query = _supabase
        .from('knowledge_chat_sessions')
        .select()
        .order('updated_at', ascending: false)
        .limit(limit);

    if (!includeArchived) {
      query = query.eq('is_archived', false);
    }

    final response = await query;
    return (response as List)
        .map((json) => ChatSession.fromJson(json))
        .toList();
  }

  /// Get a single session
  Future<ChatSession> getSession(String sessionId) async {
    final response = await _supabase
        .from('knowledge_chat_sessions')
        .select()
        .eq('id', sessionId)
        .single();

    return ChatSession.fromJson(response);
  }

  /// Update session title
  Future<void> updateSessionTitle(String sessionId, String title) async {
    await _supabase
        .from('knowledge_chat_sessions')
        .update({'title': title})
        .eq('id', sessionId);
  }

  /// Archive a session
  Future<void> archiveSession(String sessionId) async {
    await _supabase
        .from('knowledge_chat_sessions')
        .update({'is_archived': true})
        .eq('id', sessionId);
  }

  /// Delete a session
  Future<void> deleteSession(String sessionId) async {
    await _supabase
        .from('knowledge_chat_sessions')
        .delete()
        .eq('id', sessionId);
  }

  // ============================================
  // MESSAGES
  // ============================================

  /// Get messages for a session
  Future<List<ChatMessage>> getMessages(String sessionId) async {
    final response = await _supabase
        .from('knowledge_chat_messages')
        .select()
        .eq('session_id', sessionId)
        .order('created_at', ascending: true);

    return (response as List).map((json) {
      // Parse source_documents from JSONB
      final sourceDocsJson = json['source_documents'] as List? ?? [];
      final sourceDocs = sourceDocsJson
          .map((doc) => SourceDocument.fromJson(doc as Map<String, dynamic>))
          .toList();

      return ChatMessage(
        id: json['id'],
        createdAt: DateTime.parse(json['created_at']),
        sessionId: json['session_id'],
        role: json['role'],
        content: json['content'],
        sourceDocuments: sourceDocs,
        tokensUsed: json['tokens_used'] as Map<String, dynamic>?,
      );
    }).toList();
  }

  // ============================================
  // QUERY
  // ============================================

  /// Send a query to the AI assistant
  Future<QueryResponse> query({
    required String query,
    String? sessionId,
    int matchCount = 10,
    double threshold = 0.65,
  }) async {
    final userId = _supabase.auth.currentUser?.id;

    final response = await _supabase.functions.invoke(
      'query-knowledge-base',
      body: {
        'query': query,
        'sessionId': sessionId,
        'userId': userId,
        'matchCount': matchCount,
        'threshold': threshold,
      },
    );

    if (response.status != 200) {
      final error = response.data is Map
          ? response.data['error'] ?? 'Unknown error'
          : 'Request failed';
      throw Exception('Query failed: $error');
    }

    final data = response.data as Map<String, dynamic>;

    return QueryResponse(
      response: data['response'] as String,
      sources: (data['sources'] as List? ?? [])
          .map((s) => SourceDocument.fromJson(s as Map<String, dynamic>))
          .toList(),
      inputTokens: data['usage']?['input_tokens'] as int? ?? 0,
      outputTokens: data['usage']?['output_tokens'] as int? ?? 0,
    );
  }

  // ============================================
  // KNOWLEDGE BASE STATS
  // ============================================

  /// Get knowledge base statistics
  Future<KnowledgeStats> getStats() async {
    // Get document counts by status
    final docsResponse = await _supabase
        .from('knowledge_documents')
        .select('source_type, source_table, embedding_status');

    final docs = docsResponse as List;

    int total = docs.length;
    int pending = 0;
    int failed = 0;
    final byTable = <String, int>{};
    final byType = <String, int>{};

    for (final doc in docs) {
      final status = doc['embedding_status'] as String?;
      final table = doc['source_table'] as String?;
      final type = doc['source_type'] as String?;

      if (status == 'pending') pending++;
      if (status == 'failed') failed++;

      if (table != null) {
        byTable[table] = (byTable[table] ?? 0) + 1;
      }
      if (type != null) {
        byType[type] = (byType[type] ?? 0) + 1;
      }
    }

    // Get usage for current month
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    final usageResponse = await _supabase
        .from('knowledge_usage_log')
        .select('estimated_cost_cents')
        .gte('created_at', startOfMonth.toIso8601String());

    final usage = usageResponse as List;
    final totalCostCents = usage.fold<double>(
      0,
      (sum, row) => sum + ((row['estimated_cost_cents'] as num?)?.toDouble() ?? 0),
    );

    // Get table configs
    final configResponse = await _supabase
        .from('knowledge_table_config')
        .select()
        .order('table_name');

    final configs = (configResponse as List)
        .map((c) => TableConfig.fromJson(c as Map<String, dynamic>))
        .toList();

    // Get query count
    final queryCountResponse = await _supabase
        .from('knowledge_usage_log')
        .select('id', const FetchOptions(count: CountOption.exact, head: true))
        .eq('operation', 'query')
        .gte('created_at', startOfMonth.toIso8601String());

    return KnowledgeStats(
      totalDocuments: total,
      pendingEmbeddings: pending,
      failedEmbeddings: failed,
      documentsByTable: byTable,
      documentsByType: byType,
      monthlyUsageDollars: totalCostCents / 100,
      totalQueries: queryCountResponse.count ?? 0,
      tableConfigs: configs,
    );
  }

  // ============================================
  // ADMIN FUNCTIONS
  // ============================================

  /// Trigger embedding processing
  Future<Map<String, dynamic>> processEmbeddings({int batchSize = 20}) async {
    final response = await _supabase.functions.invoke(
      'generate-embeddings',
      body: {'batchSize': batchSize},
    );

    if (response.status != 200) {
      throw Exception('Failed to process embeddings');
    }

    return response.data as Map<String, dynamic>;
  }

  /// Trigger storage file indexing
  Future<Map<String, dynamic>> indexStorageFiles({
    String? bucketName,
    int limit = 50,
  }) async {
    final response = await _supabase.functions.invoke(
      'index-storage-files',
      body: {
        if (bucketName != null) 'bucketName': bucketName,
        'limit': limit,
      },
    );

    if (response.status != 200) {
      throw Exception('Failed to index files');
    }

    return response.data as Map<String, dynamic>;
  }

  /// Discover new tables
  Future<List<Map<String, dynamic>>> discoverTables() async {
    final response = await _supabase.functions.invoke('discover-tables');

    if (response.status != 200) {
      throw Exception('Failed to discover tables');
    }

    return (response.data['discovered_tables'] as List? ?? [])
        .cast<Map<String, dynamic>>();
  }

  /// Enable a table for indexing
  Future<void> enableTable(String tableName) async {
    await _supabase
        .from('knowledge_table_config')
        .update({'is_enabled': true})
        .eq('table_name', tableName);
  }

  /// Disable a table for indexing
  Future<void> disableTable(String tableName) async {
    await _supabase
        .from('knowledge_table_config')
        .update({'is_enabled': false})
        .eq('table_name', tableName);
  }
}

/// Response from AI query
class QueryResponse {
  final String response;
  final List<SourceDocument> sources;
  final int inputTokens;
  final int outputTokens;

  QueryResponse({
    required this.response,
    required this.sources,
    required this.inputTokens,
    required this.outputTokens,
  });

  int get totalTokens => inputTokens + outputTokens;

  /// Estimated cost in cents
  double get estimatedCostCents {
    // Claude Sonnet pricing: $3/1M input, $15/1M output
    return (inputTokens / 1000000 * 300) + (outputTokens / 1000000 * 1500);
  }
}
