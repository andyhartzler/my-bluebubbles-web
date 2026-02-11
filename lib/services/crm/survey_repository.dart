import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/models/crm/survey_model.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

class SurveyRepository {
  final CRMSupabaseService _supabase = CRMSupabaseService();

  bool get isReady => CRMConfig.crmEnabled && _supabase.isInitialized;

  SupabaseClient get _readClient =>
      _supabase.hasServiceRole ? _supabase.privilegedClient : _supabase.client;

  SupabaseClient get _writeClient => _supabase.privilegedClient;

  // ── Surveys ───────────────────────────────────────────────────────────────

  Future<List<Survey>> fetchSurveys({
    String? eventId,
    String? status,
    String? searchQuery,
  }) async {
    if (!isReady) return [];

    var query = _readClient.from('surveys').select('''
      *,
      survey_questions(*),
      session_stats:survey_sessions(count),
      completed_stats:survey_sessions(count)
    ''');

    if (eventId != null) {
      query = query.eq('event_id', eventId);
    }
    if (status != null && status.isNotEmpty) {
      query = query.eq('status', status);
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      query = query.ilike('title', '%${searchQuery.trim()}%');
    }

    final data = await query.order('created_at', ascending: false);
    final list =
        (data as List<dynamic>? ?? []).whereType<Map<String, dynamic>>().toList();

    // Fetch session counts separately for accurate numbers
    final surveys = <Survey>[];
    for (final json in list) {
      final surveyId = json['id'] as String?;
      int sessionCount = 0;
      int completedCount = 0;

      if (surveyId != null) {
        final sessionsData = await _readClient
            .from('survey_sessions')
            .select('id, status')
            .eq('survey_id', surveyId);
        final sessionsList =
            (sessionsData as List<dynamic>? ?? []).whereType<Map<String, dynamic>>().toList();
        sessionCount = sessionsList.length;
        completedCount =
            sessionsList.where((s) => s['status'] == 'completed').length;
      }

      surveys.add(Survey.fromJson({
        ...json,
        'session_count': sessionCount,
        'completed_count': completedCount,
      }));
    }

    return surveys;
  }

  Future<Survey?> fetchSurvey(String id) async {
    if (!isReady) return null;

    final data = await _readClient
        .from('surveys')
        .select('*, survey_questions(*)')
        .eq('id', id)
        .maybeSingle();

    if (data == null) return null;

    // Get session counts
    final sessions = await _readClient
        .from('survey_sessions')
        .select('id, status')
        .eq('survey_id', id);
    final sessionList = (sessions as List<dynamic>? ?? []);
    final sessionCount = sessionList.length;
    final completedCount =
        sessionList.where((s) => s['status'] == 'completed').length;

    return Survey.fromJson({
      ...data as Map<String, dynamic>,
      'session_count': sessionCount,
      'completed_count': completedCount,
    });
  }

  Future<Survey> createSurvey(Survey survey, List<SurveyQuestion> questions) async {
    if (!isReady) throw Exception('CRM not configured');

    final surveyId = const Uuid().v4();
    final payload = {
      ...survey.toInsertPayload(),
      'id': surveyId,
    };

    await _writeClient.from('surveys').insert(payload);

    // Insert questions
    if (questions.isNotEmpty) {
      final questionPayloads = questions
          .map((q) => {
            final p = q.toInsertPayload(surveyId);
            p['id'] = const Uuid().v4();
            return p;
          })
          .toList();
      await _writeClient.from('survey_questions').insert(questionPayloads);
    }

    final created = await fetchSurvey(surveyId);
    if (created != null) return created;
    throw Exception('Survey created but could not be fetched');
  }

  Future<Survey> updateSurvey(Survey survey, List<SurveyQuestion> questions) async {
    if (!isReady) throw Exception('CRM not configured');

    final surveyId = survey.id;
    if (surveyId == null) throw Exception('Cannot update survey without id');

    await _writeClient
        .from('surveys')
        .update(survey.toUpdatePayload())
        .eq('id', surveyId);

    // Replace questions: delete old, insert new
    await _writeClient
        .from('survey_questions')
        .delete()
        .eq('survey_id', surveyId);

    if (questions.isNotEmpty) {
      final questionPayloads = questions
          .map((q) => {
            final p = q.toInsertPayload(surveyId);
            p['id'] = q.id ?? const Uuid().v4();
            return p;
          })
          .toList();
      await _writeClient.from('survey_questions').insert(questionPayloads);
    }

    final updated = await fetchSurvey(surveyId);
    if (updated != null) return updated;
    throw Exception('Survey updated but could not be fetched');
  }

  Future<void> deleteSurvey(String id) async {
    if (!isReady) throw Exception('CRM not configured');
    await _writeClient.from('surveys').delete().eq('id', id);
  }

  Future<void> updateSurveyStatus(String id, String status) async {
    if (!isReady) throw Exception('CRM not configured');
    final payload = <String, dynamic>{'status': status};
    if (status == 'completed') {
      payload['completed_at'] = DateTime.now().toUtc().toIso8601String();
    }
    await _writeClient.from('surveys').update(payload).eq('id', id);
  }

  // ── Send survey (calls edge function) ─────────────────────────────────────

  Future<Map<String, dynamic>> sendSurvey(
    String surveyId, {
    List<String>? phoneList,
  }) async {
    if (!isReady) throw Exception('CRM not configured');

    final body = <String, dynamic>{'survey_id': surveyId};
    if (phoneList != null && phoneList.isNotEmpty) {
      body['phone_list'] = phoneList;
    }

    final response = await _writeClient.functions.invoke(
      'send-survey',
      body: body,
    );

    if (response.status != 200) {
      final error = response.data is Map
          ? response.data['error'] ?? 'Unknown error'
          : 'Send failed (${response.status})';
      throw Exception(error.toString());
    }

    return response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : {'success': true};
  }

  // ── Sessions ──────────────────────────────────────────────────────────────

  Future<List<SurveySession>> fetchSessions(String surveyId) async {
    if (!isReady) return [];

    final data = await _readClient
        .from('survey_sessions')
        .select('*')
        .eq('survey_id', surveyId)
        .order('started_at', ascending: false);

    return (data as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map((json) => SurveySession.fromJson(json))
        .toList();
  }

  Future<bool> hasActiveSurveySession(String phoneE164) async {
    if (!isReady) return false;

    final data = await _readClient
        .from('survey_sessions')
        .select('id')
        .eq('phone_e164', phoneE164)
        .eq('status', 'active')
        .limit(1);

    return (data as List<dynamic>? ?? []).isNotEmpty;
  }

  // ── Responses ─────────────────────────────────────────────────────────────

  Future<List<SurveyResponse>> fetchResponses(String sessionId) async {
    if (!isReady) return [];

    final data = await _readClient
        .from('survey_responses')
        .select('*')
        .eq('session_id', sessionId)
        .order('responded_at');

    return (data as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map((json) => SurveyResponse.fromJson(json))
        .toList();
  }

  /// Fetch all responses for a survey grouped by question, for results display.
  Future<SurveyResultsSummary> fetchResultsSummary(String surveyId) async {
    if (!isReady) {
      return const SurveyResultsSummary();
    }

    // Fetch sessions
    final sessionsData = await _readClient
        .from('survey_sessions')
        .select('id, status')
        .eq('survey_id', surveyId);

    final sessions =
        (sessionsData as List<dynamic>? ?? []).whereType<Map<String, dynamic>>().toList();

    final totalSent = sessions.length;
    final totalCompleted =
        sessions.where((s) => s['status'] == 'completed').length;
    final totalOptedOut =
        sessions.where((s) => s['status'] == 'opted_out').length;

    // Fetch questions
    final questionsData = await _readClient
        .from('survey_questions')
        .select('*')
        .eq('survey_id', surveyId)
        .order('question_order');

    final questions = (questionsData as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map((json) => SurveyQuestion.fromJson(json))
        .toList();

    // Fetch all responses for this survey's sessions
    final sessionIds = sessions.map((s) => s['id'] as String).toList();
    List<SurveyResponse> allResponses = [];

    if (sessionIds.isNotEmpty) {
      final responsesData = await _readClient
          .from('survey_responses')
          .select('*')
          .inFilter('session_id', sessionIds);

      allResponses = (responsesData as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((json) => SurveyResponse.fromJson(json))
          .toList();
    }

    // Unique sessions that have at least one response
    final respondedSessionIds = allResponses.map((r) => r.sessionId).toSet();
    final totalResponded = respondedSessionIds.length;

    // Group responses by question
    final questionSummaries = questions.map((q) {
      final qResponses =
          allResponses.where((r) => r.questionId == q.id).toList();
      return QuestionResultSummary(question: q, responses: qResponses);
    }).toList();

    return SurveyResultsSummary(
      totalSent: totalSent,
      totalResponded: totalResponded,
      totalCompleted: totalCompleted,
      totalOptedOut: totalOptedOut,
      questionSummaries: questionSummaries,
    );
  }
}
