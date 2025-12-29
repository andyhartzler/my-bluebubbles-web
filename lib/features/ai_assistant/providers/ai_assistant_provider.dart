import 'package:flutter/foundation.dart';
import '../services/ai_assistant_service.dart';
import '../models/chat_session.dart';
import '../models/chat_message.dart';
import '../models/knowledge_stats.dart';
import '../models/query_response.dart';

class AIAssistantProvider extends ChangeNotifier {
  final AIAssistantService _service = AIAssistantService();

  // State
  List<ChatSession> _sessions = [];
  ChatSession? _currentSession;
  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isSending = false;
  String? _error;
  KnowledgeStats? _stats;
  MemoriesUsed? _lastMemoriesUsed;

  // Getters
  List<ChatSession> get sessions => _sessions;
  ChatSession? get currentSession => _currentSession;
  List<ChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  String? get error => _error;
  KnowledgeStats? get stats => _stats;
  MemoriesUsed? get lastMemoriesUsed => _lastMemoriesUsed;
  bool get hasCurrentSession => _currentSession != null;

  // ============================================
  // SESSION MANAGEMENT
  // ============================================

  Future<void> loadSessions() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _sessions = await _service.getSessions();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createNewSession() async {
    try {
      final session = await _service.createSession();
      _sessions.insert(0, session);
      _currentSession = session;
      _messages = [];
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> selectSession(String sessionId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentSession = await _service.getSession(sessionId);
      _messages = await _service.getMessages(sessionId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> archiveCurrentSession() async {
    if (_currentSession == null) return;

    try {
      await _service.archiveSession(_currentSession!.id);
      _sessions.removeWhere((s) => s.id == _currentSession!.id);
      _currentSession = null;
      _messages = [];
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteCurrentSession() async {
    if (_currentSession == null) return;

    try {
      await _service.deleteSession(_currentSession!.id);
      _sessions.removeWhere((s) => s.id == _currentSession!.id);
      _currentSession = null;
      _messages = [];
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void clearCurrentSession() {
    _currentSession = null;
    _messages = [];
    notifyListeners();
  }

  // ============================================
  // QUERYING
  // ============================================

  Future<void> sendMessage(String query) async {
    if (query.trim().isEmpty) return;

    _isSending = true;
    _error = null;
    notifyListeners();

    try {
      // Create session if none exists
      if (_currentSession == null) {
        await createNewSession();
      }

      // Add user message optimistically
      final tempUserMsg = ChatMessage(
        id: 'temp-user-${DateTime.now().millisecondsSinceEpoch}',
        createdAt: DateTime.now(),
        sessionId: _currentSession!.id,
        role: 'user',
        content: query,
      );
      _messages.add(tempUserMsg);
      notifyListeners();

      // Send query
      final response = await _service.query(
        query: query,
        sessionId: _currentSession!.id,
      );

      // Store memories used for UI indicator
      _lastMemoriesUsed = response.memoriesUsed;

      // Add assistant message
      final assistantMsg = ChatMessage(
        id: 'temp-assistant-${DateTime.now().millisecondsSinceEpoch}',
        createdAt: DateTime.now(),
        sessionId: _currentSession!.id,
        role: 'assistant',
        content: response.response,
        sourceDocuments: response.sources,
        tokensUsed: {
          'input': response.inputTokens,
          'output': response.outputTokens,
        },
      );
      _messages.add(assistantMsg);

      // Update session in list (move to top)
      final sessionIndex = _sessions.indexWhere((s) => s.id == _currentSession!.id);
      if (sessionIndex >= 0) {
        final session = _sessions.removeAt(sessionIndex);
        _sessions.insert(0, session.copyWith(
          updatedAt: DateTime.now(),
          title: session.title ?? (query.length > 50 ? '${query.substring(0, 47)}...' : query),
        ));
      }

    } catch (e) {
      _error = e.toString();
      // Remove the optimistic user message on error
      if (_messages.isNotEmpty && _messages.last.role == 'user') {
        _messages.removeLast();
      }
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  // ============================================
  // STATS
  // ============================================

  Future<void> loadStats() async {
    try {
      _stats = await _service.getStats();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // ============================================
  // FEEDBACK
  // ============================================

  /// Submit feedback for a message
  Future<void> submitFeedback({
    required String messageId,
    required String feedbackType,
  }) async {
    if (_currentSession == null) return;

    // Find the message and the preceding user query
    final messageIndex = _messages.indexWhere((m) => m.id == messageId);
    if (messageIndex < 0) return;

    final message = _messages[messageIndex];
    String query = '';
    if (messageIndex > 0 && _messages[messageIndex - 1].role == 'user') {
      query = _messages[messageIndex - 1].content;
    }

    // Update feedback state in UI immediately
    final newState = feedbackType == 'positive'
        ? FeedbackState.positive
        : FeedbackState.negative;

    _messages[messageIndex] = ChatMessage(
      id: message.id,
      createdAt: message.createdAt,
      sessionId: message.sessionId,
      role: message.role,
      content: message.content,
      sourceDocuments: message.sourceDocuments,
      tokensUsed: message.tokensUsed,
      feedbackState: newState,
    );
    notifyListeners();

    // Submit to backend
    await _service.submitFeedback(
      sessionId: _currentSession!.id,
      messageId: messageId,
      query: query,
      response: message.content,
      feedbackType: feedbackType,
      sourcesUsed: message.sourceDocuments
          .map((s) => {
                'id': s.id,
                'source_type': s.sourceType,
                'source_table': s.sourceTable,
                'title': s.title,
              })
          .toList(),
    );
  }

  /// Regenerate a response
  Future<void> regenerateResponse(String messageId) async {
    if (_currentSession == null) return;

    // Find the message and the preceding user query
    final messageIndex = _messages.indexWhere((m) => m.id == messageId);
    if (messageIndex <= 0) return;

    final userMessage = _messages[messageIndex - 1];
    if (userMessage.role != 'user') return;

    // Submit regenerate feedback
    final message = _messages[messageIndex];
    await _service.submitFeedback(
      sessionId: _currentSession!.id,
      messageId: messageId,
      query: userMessage.content,
      response: message.content,
      feedbackType: 'regenerate',
    );

    // Remove the old response
    _messages.removeAt(messageIndex);
    // Remove the user message too since sendMessage will add it again
    _messages.removeAt(messageIndex - 1);
    notifyListeners();

    // Re-query with the same message
    await sendMessage(userMessage.content);
  }

  // ============================================
  // ADMIN ACTIONS
  // ============================================

  Future<Map<String, dynamic>> processEmbeddings() async {
    try {
      return await _service.processEmbeddings();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> indexStorageFiles() async {
    try {
      return await _service.indexStorageFiles();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> discoverTables() async {
    try {
      return await _service.discoverTables();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // ============================================
  // UTILITIES
  // ============================================

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
