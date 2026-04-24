import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/models/crm/survey_model.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

class SurveyRepository {
  final CRMSupabaseService _supabase = CRMSupabaseService();

  bool get isReady => CRMConfig.crmEnabled && _supabase.isInitialized;

  SupabaseClient get _readClient => _supabase.client;

  SupabaseClient get _writeClient => _supabase.client;

  // ── Surveys ───────────────────────────────────────────────────────────────

  Future<List<Survey>> fetchSurveys({
    String? eventId,
    String? status,
    String? searchQuery,
  }) async {
    if (!isReady) return [];

    var query = _readClient.from('surveys').select('''
      *,
      survey_questions(*)
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

    // Batch-fetch session counts for all surveys in a single query
    final surveyIds = list
        .map((json) => json['id'] as String?)
        .where((id) => id != null)
        .cast<String>()
        .toList();

    Map<String, int> sessionCountMap = {};
    Map<String, int> completedCountMap = {};

    if (surveyIds.isNotEmpty) {
      final sessionsData = await _readClient
          .from('survey_sessions')
          .select('survey_id, status')
          .inFilter('survey_id', surveyIds);

      for (final s in (sessionsData as List<dynamic>? ?? []).whereType<Map<String, dynamic>>()) {
        final sid = s['survey_id'] as String?;
        if (sid != null) {
          sessionCountMap[sid] = (sessionCountMap[sid] ?? 0) + 1;
          if (s['status'] == 'completed') {
            completedCountMap[sid] = (completedCountMap[sid] ?? 0) + 1;
          }
        }
      }
    }

    final surveys = list.map((json) {
      final surveyId = json['id'] as String?;
      return Survey.fromJson({
        ...json,
        'session_count': surveyId != null ? (sessionCountMap[surveyId] ?? 0) : 0,
        'completed_count': surveyId != null ? (completedCountMap[surveyId] ?? 0) : 0,
      });
    }).toList();

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
          .map((q) {
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
          .map((q) {
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

  /// Duplicate a survey and all its questions as a new draft.
  Future<Survey> duplicateSurvey(String sourceId) async {
    if (!isReady) throw Exception('CRM not configured');

    final source = await fetchSurvey(sourceId);
    if (source == null) throw Exception('Source survey not found');

    final newSurvey = source.copyWith(
      id: null,
      title: '${source.title} (Copy)',
      status: 'draft',
      createdAt: null,
      scheduledAt: null,
      completedAt: null,
      sessionCount: 0,
      completedCount: 0,
    );

    final newQuestions = source.questions
        .map((q) => q.copyWith(id: null, surveyId: null))
        .toList();

    return createSurvey(newSurvey, newQuestions);
  }

  Future<void> updateSurveyStatus(String id, String status) async {
    if (!isReady) throw Exception('CRM not configured');
    final payload = <String, dynamic>{'status': status};
    if (status == 'completed') {
      payload['completed_at'] = DateTime.now().toUtc().toIso8601String();
    }
    await _writeClient.from('surveys').update(payload).eq('id', id);
  }

  // ── Prepare survey sessions (calls edge function) ────────────────────────
  // Returns { phones, sessions, firstMessage, total }.
  // Message sending is handled client-side via CRMMessageService.

  Future<Map<String, dynamic>> prepareSurveySessions(
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
        .select('id, status, phone_e164, member_id, current_question_order, started_at, completed_at, last_message_at')
        .eq('survey_id', surveyId);

    final sessions =
        (sessionsData as List<dynamic>? ?? []).whereType<Map<String, dynamic>>().toList();

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

    final totalQuestions = questions.length;

    // Fetch all responses
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

    // Fetch member data by member_id
    final memberIds = sessions
        .map((s) => s['member_id'] as String?)
        .where((id) => id != null)
        .cast<String>()
        .toSet()
        .toList();

    Map<String, Map<String, dynamic>> memberMap = {};
    if (memberIds.isNotEmpty) {
      final membersData = await _readClient
          .from('members')
          .select('id, name, phone_e164, profile_pictures, slack_user_id')
          .inFilter('id', memberIds);

      for (final m in (membersData as List<dynamic>? ?? [])) {
        if (m is Map<String, dynamic> && m['id'] != null) {
          memberMap[m['id'] as String] = m;
        }
      }
    }

    // Fetch members by phone for sessions without member_id
    final phonesWithoutMember = sessions
        .where((s) => s['member_id'] == null)
        .map((s) => s['phone_e164'] as String?)
        .where((p) => p != null && p.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();

    Map<String, Map<String, dynamic>> phoneMemberMap = {};
    if (phonesWithoutMember.isNotEmpty) {
      final phoneMembers = await _readClient
          .from('members')
          .select('id, name, phone_e164, profile_pictures, slack_user_id')
          .inFilter('phone_e164', phonesWithoutMember);

      for (final m in (phoneMembers as List<dynamic>? ?? [])) {
        if (m is Map<String, dynamic> && m['phone_e164'] != null) {
          phoneMemberMap[m['phone_e164'] as String] = m;
        }
      }
    }

    // Fetch Slack avatars for members that have slack_user_id
    final allMembers = {...memberMap, ...phoneMemberMap.map((k, v) => MapEntry(v['id'] as String? ?? k, v))};
    final slackUserIds = allMembers.values
        .map((m) => m['slack_user_id'] as String?)
        .where((id) => id != null && id.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();

    Map<String, String> slackAvatarMap = {}; // slack_user_id -> avatar_url
    if (slackUserIds.isNotEmpty) {
      final slackData = await _readClient
          .from('slack_user_mapping')
          .select('slack_user_id, slack_avatar_url, cached_avatar_path')
          .inFilter('slack_user_id', slackUserIds);

      for (final s in (slackData as List<dynamic>? ?? [])) {
        if (s is Map<String, dynamic> && s['slack_user_id'] != null) {
          final avatarUrl = s['cached_avatar_path'] as String? ?? s['slack_avatar_url'] as String?;
          if (avatarUrl != null && avatarUrl.isNotEmpty) {
            slackAvatarMap[s['slack_user_id'] as String] = avatarUrl;
          }
        }
      }
    }

    // Build session details
    final sessionDetails = <SurveySessionDetail>[];
    int totalInProgress = 0;
    int totalNoResponse = 0;

    for (final s in sessions) {
      final sessionId = s['id'] as String;
      final memberId = s['member_id'] as String?;
      final phone = s['phone_e164'] as String? ?? '';
      final status = s['status'] as String? ?? '';

      Map<String, dynamic>? member;
      if (memberId != null && memberMap.containsKey(memberId)) {
        member = memberMap[memberId];
      } else if (phoneMemberMap.containsKey(phone)) {
        member = phoneMemberMap[phone];
      }

      String? photoUrl;
      if (member != null && member['profile_pictures'] != null) {
        final photos = MemberProfilePhoto.parseList(member['profile_pictures']);
        if (photos.isNotEmpty) {
          final primary = photos.firstWhere(
            (p) => p.isPrimary,
            orElse: () => photos.first,
          );
          photoUrl = primary.publicUrl;
        }
      }
      // Fallback to Slack avatar if no profile picture
      if ((photoUrl == null || photoUrl.isEmpty) && member != null) {
        final slackId = member['slack_user_id'] as String?;
        if (slackId != null && slackAvatarMap.containsKey(slackId)) {
          photoUrl = slackAvatarMap[slackId];
        }
      }

      final sessionResponses = allResponses.where((r) => r.sessionId == sessionId).toList();
      final answeredCount = sessionResponses.length;

      if (status == 'active') {
        if (answeredCount > 0) {
          totalInProgress++;
        } else {
          totalNoResponse++;
        }
      }

      // Resolve member ID (from session or phone-matched member)
      final resolvedMemberId = memberId ?? (member?['id'] as String?);

      sessionDetails.add(SurveySessionDetail(
        session: SurveySession.fromJson(s),
        memberId: resolvedMemberId,
        memberName: member?['name'] as String?,
        memberPhone: phone,
        profilePhotoUrl: photoUrl,
        questionsAnswered: answeredCount,
        totalQuestions: totalQuestions,
        responses: sessionResponses,
      ));
    }

    sessionDetails.sort((a, b) {
      const order = {'completed': 0, 'active': 1, 'opted_out': 2, 'expired': 3};
      final aOrder = order[a.session.status] ?? 3;
      final bOrder = order[b.session.status] ?? 3;
      if (aOrder != bOrder) return aOrder.compareTo(bOrder);
      return b.questionsAnswered.compareTo(a.questionsAnswered);
    });

    final totalSent = sessions.length;
    final totalCompleted = sessions.where((s) => s['status'] == 'completed').length;
    final totalOptedOut = sessions.where((s) => s['status'] == 'opted_out').length;
    final respondedSessionIds = allResponses.map((r) => r.sessionId).toSet();
    final totalResponded = respondedSessionIds.length;

    final questionSummaries = questions.map((q) {
      final qResponses = allResponses.where((r) => r.questionId == q.id).toList();
      return QuestionResultSummary(question: q, responses: qResponses);
    }).toList();

    return SurveyResultsSummary(
      totalSent: totalSent,
      totalResponded: totalResponded,
      totalCompleted: totalCompleted,
      totalOptedOut: totalOptedOut,
      totalInProgress: totalInProgress,
      totalNoResponse: totalNoResponse,
      questionSummaries: questionSummaries,
      sessionDetails: sessionDetails,
    );
  }

  // ── Close Survey ──────────────────────────────────────────────────────────

  /// Close a survey: set all active sessions to completed and mark survey as completed.
  Future<void> closeSurvey(String surveyId) async {
    if (!isReady) throw Exception('CRM not configured');

    // Set all active sessions to completed
    await _writeClient
        .from('survey_sessions')
        .update({
          'status': 'completed',
          'completed_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('survey_id', surveyId)
        .eq('status', 'active');

    // Mark survey itself as completed
    await updateSurveyStatus(surveyId, 'completed');
  }

  // ── Resend to Non-Responders ──────────────────────────────────────────────

  /// Get phone numbers of sessions with status 'active' and 0 responses.
  Future<List<String>> getNonResponderPhones(String surveyId) async {
    if (!isReady) return [];

    final sessionsData = await _readClient
        .from('survey_sessions')
        .select('id, phone_e164')
        .eq('survey_id', surveyId)
        .eq('status', 'active');

    final sessions = (sessionsData as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();

    if (sessions.isEmpty) return [];

    final sessionIds = sessions.map((s) => s['id'] as String).toList();

    // Find which sessions have responses
    final responsesData = await _readClient
        .from('survey_responses')
        .select('session_id')
        .inFilter('session_id', sessionIds);

    final respondedSessionIds = (responsesData as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map((r) => r['session_id'] as String?)
        .whereType<String>()
        .toSet();

    // Return phones for sessions with zero responses
    return sessions
        .where((s) => !respondedSessionIds.contains(s['id'] as String))
        .map((s) => s['phone_e164'] as String)
        .where((p) => p.isNotEmpty)
        .toList();
  }

  // ── Event Name Resolution ─────────────────────────────────────────────────

  /// Fetch event title by ID. Returns null if not found.
  Future<String?> fetchEventTitle(String eventId) async {
    if (!isReady) return null;

    final data = await _readClient
        .from('events')
        .select('title')
        .eq('id', eventId)
        .maybeSingle();

    return data?['title'] as String?;
  }
}
