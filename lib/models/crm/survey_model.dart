/// Models for the survey system: Survey, SurveyQuestion, SurveySession, SurveyResponse.

DateTime? _parseSurveyDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value.toLocal();
  if (value is String && value.isNotEmpty) {
    final parsed = DateTime.tryParse(value);
    return parsed?.toLocal();
  }
  return null;
}

bool _parseSurveyBool(dynamic value, {bool defaultValue = false}) {
  if (value == null) return defaultValue;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final lower = value.trim().toLowerCase();
    if (lower == 'true' || lower == '1') return true;
    if (lower == 'false' || lower == '0') return false;
  }
  return defaultValue;
}

int? _parseSurveyInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

// ─── Survey ──────────────────────────────────────────────────────────────────

const _undefined = Object();

class Survey {
  final String? id;
  final String? eventId;
  final String title;
  final String? description;
  final String status;
  final String targetAudience;
  final bool autoSend;
  final DateTime? createdAt;
  final DateTime? scheduledAt;
  final DateTime? completedAt;

  /// Joined data (not persisted)
  final List<SurveyQuestion> questions;
  final int sessionCount;
  final int completedCount;

  const Survey({
    this.id,
    this.eventId,
    required this.title,
    this.description,
    this.status = 'draft',
    this.targetAudience = 'all_attendees',
    this.autoSend = false,
    this.createdAt,
    this.scheduledAt,
    this.completedAt,
    this.questions = const [],
    this.sessionCount = 0,
    this.completedCount = 0,
  });

  factory Survey.fromJson(Map<String, dynamic> json) {
    final questionsList = json['survey_questions'];
    List<SurveyQuestion> questions = [];
    if (questionsList is List) {
      questions = questionsList
          .whereType<Map<String, dynamic>>()
          .map((q) => SurveyQuestion.fromJson(q))
          .toList()
        ..sort((a, b) => a.questionOrder.compareTo(b.questionOrder));
    }

    return Survey(
      id: json['id'] as String?,
      eventId: json['event_id'] as String?,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      status: json['status'] as String? ?? 'draft',
      targetAudience: json['target_audience'] as String? ?? 'all_attendees',
      autoSend: _parseSurveyBool(json['auto_send']),
      createdAt: _parseSurveyDateTime(json['created_at']),
      scheduledAt: _parseSurveyDateTime(json['scheduled_at']),
      completedAt: _parseSurveyDateTime(json['completed_at']),
      questions: questions,
      sessionCount: _parseSurveyInt(json['session_count']) ?? 0,
      completedCount: _parseSurveyInt(json['completed_count']) ?? 0,
    );
  }

  Map<String, dynamic> toInsertPayload() => {
        if (eventId != null) 'event_id': eventId,
        'title': title,
        if (description != null) 'description': description,
        'status': status,
        'target_audience': targetAudience,
        'auto_send': autoSend,
        if (scheduledAt != null) 'scheduled_at': scheduledAt!.toUtc().toIso8601String(),
      };

  Map<String, dynamic> toUpdatePayload() => {
        'title': title,
        'description': description,
        'status': status,
        'target_audience': targetAudience,
        'auto_send': autoSend,
        'scheduled_at': scheduledAt?.toUtc().toIso8601String(),
        'completed_at': completedAt?.toUtc().toIso8601String(),
      };

  Survey copyWith({
    Object? id = _undefined,
    Object? eventId = _undefined,
    Object? title = _undefined,
    Object? description = _undefined,
    Object? status = _undefined,
    Object? targetAudience = _undefined,
    Object? autoSend = _undefined,
    Object? createdAt = _undefined,
    Object? scheduledAt = _undefined,
    Object? completedAt = _undefined,
    Object? questions = _undefined,
    Object? sessionCount = _undefined,
    Object? completedCount = _undefined,
  }) =>
      Survey(
        id: id == _undefined ? this.id : id as String?,
        eventId: eventId == _undefined ? this.eventId : eventId as String?,
        title: title == _undefined ? this.title : title as String,
        description: description == _undefined ? this.description : description as String?,
        status: status == _undefined ? this.status : status as String,
        targetAudience: targetAudience == _undefined ? this.targetAudience : targetAudience as String,
        autoSend: autoSend == _undefined ? this.autoSend : autoSend as bool,
        createdAt: createdAt == _undefined ? this.createdAt : createdAt as DateTime?,
        scheduledAt: scheduledAt == _undefined ? this.scheduledAt : scheduledAt as DateTime?,
        completedAt: completedAt == _undefined ? this.completedAt : completedAt as DateTime?,
        questions: questions == _undefined ? this.questions : questions as List<SurveyQuestion>,
        sessionCount: sessionCount == _undefined ? this.sessionCount : sessionCount as int,
        completedCount: completedCount == _undefined ? this.completedCount : completedCount as int,
      );
}

// ─── SurveyQuestion ──────────────────────────────────────────────────────────

class SurveyQuestion {
  final String? id;
  final String? surveyId;
  final String questionText;
  final String questionType;
  final List<String> options;
  final int questionOrder;
  final int? ratingMax;
  final String? ratingMinLabel;
  final String? ratingMaxLabel;

  const SurveyQuestion({
    this.id,
    this.surveyId,
    required this.questionText,
    required this.questionType,
    this.options = const [],
    required this.questionOrder,
    this.ratingMax,
    this.ratingMinLabel,
    this.ratingMaxLabel,
  });

  factory SurveyQuestion.fromJson(Map<String, dynamic> json) {
    List<String> options = [];
    int? ratingMax;
    String? ratingMinLabel;
    String? ratingMaxLabel;
    final raw = json['options'];
    if (raw is List) {
      options = raw.map((e) => e.toString()).toList();
    } else if (raw is Map) {
      if (raw['max'] != null) {
        ratingMax = int.tryParse(raw['max'].toString());
      }
      if (raw['choices'] is List) {
        options = (raw['choices'] as List).map((e) => e.toString()).toList();
      }
      // Read custom rating labels
      if (raw['labels'] is Map) {
        final labels = raw['labels'] as Map;
        final min = raw['min']?.toString() ?? '1';
        final max = raw['max']?.toString() ?? '5';
        ratingMinLabel = labels[min]?.toString();
        ratingMaxLabel = labels[max]?.toString();
      }
    }

    return SurveyQuestion(
      id: json['id'] as String?,
      surveyId: json['survey_id'] as String?,
      questionText: json['question_text'] as String? ?? '',
      questionType: json['question_type'] as String? ?? 'short_answer',
      options: options,
      questionOrder: _parseSurveyInt(json['question_order']) ?? 0,
      ratingMax: ratingMax,
      ratingMinLabel: ratingMinLabel,
      ratingMaxLabel: ratingMaxLabel,
    );
  }

  Map<String, dynamic> toInsertPayload(String surveyId) {
    final payload = <String, dynamic>{
      'survey_id': surveyId,
      'question_text': questionText,
      'question_type': questionType,
      'question_order': questionOrder,
    };
    if (questionType == 'multiple_choice' && options.isNotEmpty) {
      payload['options'] = options;
    } else if (questionType == 'multi_select' && options.isNotEmpty) {
      payload['options'] = options;
    } else if (questionType == 'rating') {
      final max = ratingMax ?? 5;
      final ratingOpts = <String, dynamic>{'min': 1, 'max': max};
      final minLbl = ratingMinLabel ?? 'Poor';
      final maxLbl = ratingMaxLabel ?? 'Excellent';
      ratingOpts['labels'] = {'1': minLbl, '$max': maxLbl};
      payload['options'] = ratingOpts;
    }
    return payload;
  }

  SurveyQuestion copyWith({
    String? id, String? surveyId, String? questionText, String? questionType,
    List<String>? options, int? questionOrder, int? ratingMax,
    String? ratingMinLabel, String? ratingMaxLabel,
  }) => SurveyQuestion(
        id: id ?? this.id, surveyId: surveyId ?? this.surveyId,
        questionText: questionText ?? this.questionText,
        questionType: questionType ?? this.questionType,
        options: options ?? this.options,
        questionOrder: questionOrder ?? this.questionOrder,
        ratingMax: ratingMax ?? this.ratingMax,
        ratingMinLabel: ratingMinLabel ?? this.ratingMinLabel,
        ratingMaxLabel: ratingMaxLabel ?? this.ratingMaxLabel,
      );

  /// Format the question text as it will appear in an iMessage.
  String formatForMessage({required int questionNumber, required int totalQuestions}) {
    final buf = StringBuffer();
    // First question: no prefix. Subsequent questions: Q2, Q3, etc. (no "of N")
    if (questionNumber == 1) {
      buf.writeln(questionText);
    } else {
      buf.writeln('Q$questionNumber: $questionText');
    }
    buf.writeln();
    switch (questionType) {
      case 'yes_no':
        buf.writeln('Reply YES or NO');
        break;
      case 'true_false':
        buf.writeln('Reply TRUE or FALSE');
        break;
      case 'rating':
        final max = ratingMax ?? 5;
        final minLbl = ratingMinLabel ?? 'Poor';
        final maxLbl = ratingMaxLabel ?? 'Excellent';
        buf.writeln('Reply 1-$max (1=$minLbl, $max=$maxLbl)');
        break;
      case 'multiple_choice':
        for (int i = 0; i < options.length; i++) {
          buf.writeln('${i + 1}. ${options[i]}');
        }
        buf.writeln();
        buf.writeln('Reply with the number');
        break;
      case 'multi_select':
        for (int i = 0; i < options.length; i++) {
          buf.writeln('${i + 1}. ${options[i]}');
        }
        buf.writeln();
        buf.writeln('Reply with numbers separated by commas (e.g. 1,3)');
        break;
      case 'short_answer':
        buf.writeln('Reply with your answer');
        break;
    }
    buf.writeln();
    buf.write('Reply SKIP to skip \u00B7 STOP to opt out');
    return buf.toString();
  }
}

// ─── SurveySession ───────────────────────────────────────────────────────────

class SurveySession {
  final String? id;
  final String? surveyId;
  final String phoneE164;
  final String? memberId;
  final int currentQuestionOrder;
  final String status;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? lastMessageAt;

  const SurveySession({
    this.id,
    this.surveyId,
    required this.phoneE164,
    this.memberId,
    this.currentQuestionOrder = 0,
    this.status = 'pending',
    this.startedAt,
    this.completedAt,
    this.lastMessageAt,
  });

  factory SurveySession.fromJson(Map<String, dynamic> json) => SurveySession(
        id: json['id'] as String?,
        surveyId: json['survey_id'] as String?,
        phoneE164: json['phone_e164'] as String? ?? '',
        memberId: json['member_id'] as String?,
        currentQuestionOrder: _parseSurveyInt(json['current_question_order']) ?? 0,
        status: json['status'] as String? ?? 'pending',
        startedAt: _parseSurveyDateTime(json['started_at']),
        completedAt: _parseSurveyDateTime(json['completed_at']),
        lastMessageAt: _parseSurveyDateTime(json['last_message_at']),
      );
}

// ─── SurveyResponse ──────────────────────────────────────────────────────────

class SurveyResponse {
  final String? id;
  final String? sessionId;
  final String? questionId;
  final String? rawResponse;
  final String? parsedResponse;
  final DateTime? respondedAt;

  const SurveyResponse({
    this.id,
    this.sessionId,
    this.questionId,
    this.rawResponse,
    this.parsedResponse,
    this.respondedAt,
  });

  factory SurveyResponse.fromJson(Map<String, dynamic> json) => SurveyResponse(
        id: json['id'] as String?,
        sessionId: json['session_id'] as String?,
        questionId: json['question_id'] as String?,
        rawResponse: json['raw_response'] as String?,
        parsedResponse: json['parsed_response'] as String?,
        respondedAt: _parseSurveyDateTime(json['responded_at']),
      );
}

// ─── Aggregate helpers ───────────────────────────────────────────────────────

class SurveyResultsSummary {
  final int totalSent;
  final int totalResponded;
  final int totalCompleted;
  final int totalOptedOut;
  final int totalInProgress;
  final int totalNoResponse;
  final List<QuestionResultSummary> questionSummaries;
  final List<SurveySessionDetail> sessionDetails;

  const SurveyResultsSummary({
    this.totalSent = 0,
    this.totalResponded = 0,
    this.totalCompleted = 0,
    this.totalOptedOut = 0,
    this.totalInProgress = 0,
    this.totalNoResponse = 0,
    this.questionSummaries = const [],
    this.sessionDetails = const [],
  });

  double get responseRate => totalSent > 0 ? totalResponded / totalSent : 0;
  double get completionRate => totalSent > 0 ? totalCompleted / totalSent : 0;
}

class QuestionResultSummary {
  final SurveyQuestion question;
  final List<SurveyResponse> responses;

  const QuestionResultSummary({required this.question, required this.responses});

  int get responseCount => responses.length;

  /// For yes/no: {"yes": 12, "no": 5}
  /// For multiple choice: {"Option A": 8, "Option B": 3, ...}
  /// For rating: {"1": 2, "2": 3, "3": 10, "4": 8, "5": 5}
  Map<String, int> get distribution {
    final counts = <String, int>{};
    for (final r in responses) {
      final key = r.parsedResponse ?? r.rawResponse ?? 'unknown';
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  /// Average for rating questions
  double? get averageRating {
    if (question.questionType != 'rating') return null;
    final values = responses
        .map((r) => double.tryParse(r.parsedResponse ?? ''))
        .whereType<double>()
        .toList();
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }
}

// ─── SurveySessionDetail ────────────────────────────────────────────────────

class SurveySessionDetail {
  final SurveySession session;
  final String? memberId;
  final String? memberName;
  final String? memberPhone;
  final String? profilePhotoUrl;
  final int questionsAnswered;
  final int totalQuestions;
  final List<SurveyResponse> responses;

  const SurveySessionDetail({
    required this.session,
    this.memberId,
    this.memberName,
    this.memberPhone,
    this.profilePhotoUrl,
    this.questionsAnswered = 0,
    this.totalQuestions = 0,
    this.responses = const [],
  });

  String get displayStatus {
    switch (session.status) {
      case 'completed':
        return 'Completed';
      case 'opted_out':
        return 'Opted Out';
      case 'expired':
        return 'Expired';
      case 'active':
        return questionsAnswered > 0 ? 'In Progress' : 'No Response';
      default:
        return session.status;
    }
  }

  String get displayName => memberName ?? session.phoneE164;

  double get progress {
    // Completed sessions are 100% even if some questions were skipped
    if (session.status == 'completed') return 1.0;
    return totalQuestions > 0 ? questionsAnswered / totalQuestions : 0.0;
  }
}
