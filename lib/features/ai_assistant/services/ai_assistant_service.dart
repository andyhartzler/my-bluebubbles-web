import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:postgrest/postgrest.dart' show CountOption;
import '../models/chat_session.dart';
import '../models/chat_message.dart';
import '../models/source_document.dart';
import '../models/knowledge_stats.dart';
import '../models/query_response.dart';

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
    final baseQuery = _supabase.from('knowledge_chat_sessions').select();

    final filteredQuery = includeArchived
        ? baseQuery
        : baseQuery.eq('is_archived', false);

    final response = await filteredQuery
        .order('updated_at', ascending: false)
        .limit(limit);

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
  Future<EnhancedQueryResponse> query({
    required String query,
    String? sessionId,
    int matchCount = 15,
    double threshold = 0.4,
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

    // Parse V2 classification (replaces old intent field)
    TaskClassification? classification;
    if (data['classification'] != null) {
      try {
        classification = TaskClassification.fromJson(data['classification'] as Map<String, dynamic>);
      } catch (e) {
        debugPrint('AIAssistantService.query classification parse error: $e');
      }
    }

    return EnhancedQueryResponse(
      response: data['response'] as String,
      sources: (data['sources'] as List? ?? [])
          .map((s) => SourceDocument.fromJson(s as Map<String, dynamic>))
          .toList(),
      classification: classification,
      documentsRetrieved: data['documentsRetrieved'] as int?,
      inputTokens: data['usage']?['input_tokens'] as int? ?? 0,
      outputTokens: data['usage']?['output_tokens'] as int? ?? 0,
    );
  }

  // ============================================
  // FEEDBACK
  // ============================================

  /// Submit feedback for a response
  Future<void> submitFeedback({
    required String sessionId,
    required String messageId,
    required String query,
    required String response,
    required String feedbackType, // 'positive', 'negative', 'regenerate'
    List<Map<String, dynamic>>? sourcesUsed,
    String? comment,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;

      // Calculate feedback score
      double feedbackScore;
      switch (feedbackType) {
        case 'positive':
          feedbackScore = 1.0;
          break;
        case 'negative':
          feedbackScore = -1.0;
          break;
        case 'regenerate':
          feedbackScore = -0.5;
          break;
        default:
          feedbackScore = 0.0;
      }

      await _supabase.from('ai_feedback').insert({
        'session_id': sessionId,
        'message_id': messageId,
        'user_id': userId,
        'query': query,
        'response': response,
        'sources_used': sourcesUsed,
        'feedback_type': feedbackType,
        'feedback_score': feedbackScore,
        'feedback_comment': comment,
      });
    } catch (e) {
      debugPrint('Failed to submit feedback: $e');
      // Don't throw - feedback is non-critical
    }
  }

  // ============================================
  // KNOWLEDGE BASE STATS
  // ============================================

  /// Get knowledge base statistics
  Future<KnowledgeStats> getStats() async {
    int total = 0;
    int pending = 0;
    int failed = 0;
    final byTable = <String, int>{};
    final byType = <String, int>{};
    double totalCostCents = 0;

    // Get total document count using count query (not limited to 1000)
    try {
      final totalResponse = await _supabase
          .from('knowledge_documents')
          .select()
          .count(CountOption.exact);
      total = totalResponse.count ?? 0;
    } catch (e) {
      debugPrint('Error fetching total count: $e');
    }

    // Get pending count
    try {
      final pendingResponse = await _supabase
          .from('knowledge_documents')
          .select()
          .eq('embedding_status', 'pending')
          .count(CountOption.exact);
      pending = pendingResponse.count ?? 0;
    } catch (e) {
      debugPrint('Error fetching pending count: $e');
    }

    // Get failed count
    try {
      final failedResponse = await _supabase
          .from('knowledge_documents')
          .select()
          .eq('embedding_status', 'failed')
          .count(CountOption.exact);
      failed = failedResponse.count ?? 0;
    } catch (e) {
      debugPrint('Error fetching failed count: $e');
    }

    // Get documents by table - fetch in batches to avoid 1000 limit
    try {
      int offset = 0;
      const batchSize = 1000;
      bool hasMore = true;

      while (hasMore) {
        final response = await _supabase
            .from('knowledge_documents')
            .select('source_table, source_type')
            .range(offset, offset + batchSize - 1);

        final docs = response as List;
        if (docs.isEmpty) {
          hasMore = false;
        } else {
          for (final doc in docs) {
            final table = doc['source_table'] as String?;
            final type = doc['source_type'] as String?;

            if (table != null) {
              byTable[table] = (byTable[table] ?? 0) + 1;
            }
            if (type != null) {
              byType[type] = (byType[type] ?? 0) + 1;
            }
          }
          offset += batchSize;
          hasMore = docs.length == batchSize;
        }
      }
    } catch (e) {
      debugPrint('Error fetching document breakdown: $e');
    }

    // Get usage for current month
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    try {
      final usageResponse = await _supabase
          .from('knowledge_usage_log')
          .select('estimated_cost_cents')
          .gte('created_at', startOfMonth.toIso8601String());

      final usage = usageResponse as List;
      totalCostCents = usage.fold<double>(
        0,
        (sum, row) => sum + ((row['estimated_cost_cents'] as num?)?.toDouble() ?? 0),
      );
    } catch (e) {
      debugPrint('Error fetching usage stats: $e');
    }

    // Get table configs
    List<TableConfig> configs = [];
    try {
      final configResponse = await _supabase
          .from('knowledge_table_config')
          .select('table_name, is_enabled, is_discovered, trigger_installed, last_full_sync_at');

      configs = (configResponse as List)
          .map((c) => TableConfig.fromJson(c as Map<String, dynamic>))
          .toList();

      // Sort by table_name locally
      configs.sort((a, b) => a.tableName.compareTo(b.tableName));
    } catch (e) {
      // Table might not exist yet, continue with empty configs
      debugPrint('Error fetching table configs: $e');
    }

    // Get query count
    int totalQueries = 0;
    try {
      final queryCountResponse = await _supabase
          .from('knowledge_usage_log')
          .select('id')
          .eq('operation', 'query')
          .gte('created_at', startOfMonth.toIso8601String())
          .count(CountOption.exact);

      totalQueries = queryCountResponse.count ?? 0;
    } catch (e) {
      debugPrint('Error fetching query count: $e');
    }

    return KnowledgeStats(
      totalDocuments: total,
      pendingEmbeddings: pending,
      failedEmbeddings: failed,
      documentsByTable: byTable,
      documentsByType: byType,
      monthlyUsageDollars: totalCostCents / 100,
      totalQueries: totalQueries,
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

/// Enhanced response from AI query with V2 classification data
class EnhancedQueryResponse {
  final String response;
  final List<SourceDocument> sources;
  final TaskClassification? classification;
  final int? documentsRetrieved;
  final int inputTokens;
  final int outputTokens;

  EnhancedQueryResponse({
    required this.response,
    required this.sources,
    this.classification,
    this.documentsRetrieved,
    required this.inputTokens,
    required this.outputTokens,
  });

  int get totalTokens => inputTokens + outputTokens;

  /// Whether this was a comprehensive/exhaustive research query
  bool get isDeepResearch => classification?.scope == 'exhaustive';

  /// Estimated cost in cents
  double get estimatedCostCents {
    // Claude Sonnet pricing: $3/1M input, $15/1M output
    return (inputTokens / 1000000 * 300) + (outputTokens / 1000000 * 1500);
  }
}
