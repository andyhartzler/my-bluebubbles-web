import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/crm/supabase_service.dart';

/// Event types for form analytics
/// These correspond to the form lifecycle stages
class FormEventTypes {
  /// Form page loaded
  static const String view = 'view';

  /// First field interaction (legacy - prefer phone_entered)
  static const String start = 'start';

  /// Phone number entered - triggers person lookup
  static const String phoneEntered = 'phone_entered';

  /// Existing person found during phone lookup
  static const String identityFound = 'identity_found';

  /// New subscriber created from form
  static const String identityCreated = 'identity_created';

  /// Form submitted successfully
  static const String submit = 'submit';

  /// Form abandoned before completion
  static const String abandon = 'abandon';

  /// Field value updated (auto-save)
  static const String fieldUpdate = 'field_update';
}

/// Service for tracking form analytics and interactions
class FormAnalyticsService {
  final _supabase = Supabase.instance.client;
  final _crmService = CRMSupabaseService();

  /// Get privileged client for bypassing RLS when reading submissions
  SupabaseClient get _readClient =>
      _crmService.isInitialized && _crmService.hasServiceRole
          ? _crmService.privilegedClient
          : _supabase;

  /// Track when a form is viewed
  /// Returns a session token for tracking before subscriber is created
  Future<String?> trackFormView(
    String formId,
    String? userId, {
    String? memberId,
    String? sessionToken,
    String? subscriberId,
  }) async {
    try {
      final token = sessionToken ?? _generateSessionToken();
      await _supabase.from('form_analytics').insert({
        'form_id': formId,
        'user_id': userId,
        'member_id': memberId,
        'subscriber_id': subscriberId,
        'session_token': token,
        'event_type': FormEventTypes.view,
        'timestamp': DateTime.now().toIso8601String(),
      });
      return token;
    } catch (e) {
      // Silently fail - analytics shouldn't break the app
      print('Analytics tracking error: $e');
      return null;
    }
  }

  /// Track when a form is started (first field interaction)
  Future<void> trackFormStart(
    String formId,
    String? userId, {
    String? memberId,
    String? sessionToken,
    String? subscriberId,
  }) async {
    try {
      await _supabase.from('form_analytics').insert({
        'form_id': formId,
        'user_id': userId,
        'member_id': memberId,
        'subscriber_id': subscriberId,
        'session_token': sessionToken,
        'event_type': FormEventTypes.start,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Analytics tracking error: $e');
    }
  }

  /// Track when phone number is entered (triggers person lookup)
  Future<void> trackPhoneEntered(
    String formId,
    String? userId, {
    String? memberId,
    String? sessionToken,
    String? subscriberId,
    String? submissionId,
    String? phoneE164,
  }) async {
    try {
      await _supabase.from('form_analytics').insert({
        'form_id': formId,
        'user_id': userId,
        'member_id': memberId,
        'subscriber_id': subscriberId,
        'submission_id': submissionId,
        'session_token': sessionToken,
        'event_type': FormEventTypes.phoneEntered,
        'timestamp': DateTime.now().toIso8601String(),
        'metadata': {
          if (phoneE164 != null) 'phone_e164': phoneE164,
        },
      });
    } catch (e) {
      print('Analytics tracking error: $e');
    }
  }

  /// Track when an existing identity is found during phone lookup
  Future<void> trackIdentityFound(
    String formId, {
    required String subscriberId,
    String? userId,
    String? memberId,
    String? sessionToken,
    String? submissionId,
    String? source, // 'member', 'subscriber', 'donor', 'attendee'
  }) async {
    try {
      await _supabase.from('form_analytics').insert({
        'form_id': formId,
        'user_id': userId,
        'member_id': memberId,
        'subscriber_id': subscriberId,
        'submission_id': submissionId,
        'session_token': sessionToken,
        'event_type': FormEventTypes.identityFound,
        'timestamp': DateTime.now().toIso8601String(),
        'metadata': {
          if (source != null) 'source': source,
        },
      });
    } catch (e) {
      print('Analytics tracking error: $e');
    }
  }

  /// Track when a new subscriber is created from form submission
  Future<void> trackIdentityCreated(
    String formId, {
    required String subscriberId,
    String? userId,
    String? sessionToken,
    String? submissionId,
  }) async {
    try {
      await _supabase.from('form_analytics').insert({
        'form_id': formId,
        'user_id': userId,
        'subscriber_id': subscriberId,
        'submission_id': submissionId,
        'session_token': sessionToken,
        'event_type': FormEventTypes.identityCreated,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Analytics tracking error: $e');
    }
  }

  /// Track when a form is submitted
  Future<void> trackFormSubmission(
    String formId,
    String? userId,
    Map<String, dynamic> submissionData, {
    String? memberId,
    String? sessionToken,
    String? subscriberId,
    String? submissionId,
  }) async {
    try {
      await _supabase.from('form_analytics').insert({
        'form_id': formId,
        'user_id': userId,
        'member_id': memberId,
        'subscriber_id': subscriberId,
        'submission_id': submissionId,
        'session_token': sessionToken,
        'event_type': FormEventTypes.submit,
        'timestamp': DateTime.now().toIso8601String(),
        'metadata': {
          'field_count': submissionData.length,
          'completed_fields': submissionData.values.where((v) => v != null).length,
        },
      });
    } catch (e) {
      print('Analytics tracking error: $e');
    }
  }

  /// Track when a form is abandoned (user leaves without submitting)
  Future<void> trackFormAbandonment(
    String formId,
    String? userId,
    Map<String, dynamic> partialData, {
    String? memberId,
    String? sessionToken,
    String? subscriberId,
    String? submissionId,
  }) async {
    try {
      await _supabase.from('form_analytics').insert({
        'form_id': formId,
        'user_id': userId,
        'member_id': memberId,
        'subscriber_id': subscriberId,
        'submission_id': submissionId,
        'session_token': sessionToken,
        'event_type': FormEventTypes.abandon,
        'timestamp': DateTime.now().toIso8601String(),
        'metadata': {
          'filled_fields': partialData.length,
          'last_field': partialData.keys.lastOrNull,
        },
      });
    } catch (e) {
      print('Analytics tracking error: $e');
    }
  }

  /// Track when a field value is updated (auto-save)
  Future<void> trackFieldUpdate(
    String formId,
    String fieldId,
    String fieldType,
    String? userId, {
    String? memberId,
    String? sessionToken,
    String? subscriberId,
    String? submissionId,
    bool isIdentityField = false,
  }) async {
    try {
      await _supabase.from('form_field_analytics').insert({
        'form_id': formId,
        'field_id': fieldId,
        'field_type': fieldType,
        'user_id': userId,
        'member_id': memberId,
        'subscriber_id': subscriberId,
        'submission_id': submissionId,
        'session_token': sessionToken,
        'event_type': FormEventTypes.fieldUpdate,
        'timestamp': DateTime.now().toIso8601String(),
        'metadata': {
          'is_identity_field': isIdentityField,
        },
      });
    } catch (e) {
      print('Analytics tracking error: $e');
    }
  }

  /// Track field-level interactions
  Future<void> trackFieldInteraction(
    String formId,
    String fieldId,
    String fieldType,
    String? userId, {
    String? memberId,
    String? sessionToken,
    String? subscriberId,
    String? submissionId,
  }) async {
    try {
      await _supabase.from('form_field_analytics').insert({
        'form_id': formId,
        'field_id': fieldId,
        'field_type': fieldType,
        'user_id': userId,
        'member_id': memberId,
        'subscriber_id': subscriberId,
        'submission_id': submissionId,
        'session_token': sessionToken,
        'event_type': 'interaction',
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Analytics tracking error: $e');
    }
  }

  /// Track validation errors
  Future<void> trackValidationError(
    String formId,
    String fieldId,
    String errorMessage,
    String? userId, {
    String? memberId,
    String? sessionToken,
    String? subscriberId,
    String? submissionId,
  }) async {
    try {
      await _supabase.from('form_field_analytics').insert({
        'form_id': formId,
        'field_id': fieldId,
        'user_id': userId,
        'member_id': memberId,
        'subscriber_id': subscriberId,
        'submission_id': submissionId,
        'session_token': sessionToken,
        'event_type': 'validation_error',
        'timestamp': DateTime.now().toIso8601String(),
        'metadata': {'error': errorMessage},
      });
    } catch (e) {
      print('Analytics tracking error: $e');
    }
  }

  /// Generate a random session token for tracking
  String _generateSessionToken() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp * 31337) % 1000000;
    return 'sess_${timestamp}_$random';
  }

  /// Get form analytics summary - combines form_analytics with actual submission counts
  Future<FormAnalyticsSummary> getFormAnalytics(String formId) async {
    try {
      // Get analytics events
      final analyticsResponse = await _supabase
          .from('form_analytics')
          .select()
          .eq('form_id', formId);

      final analyticsData = analyticsResponse as List;

      // Get actual submission count from form_submissions table (use privileged client)
      final submissionCountResponse = await _readClient
          .from('form_submissions')
          .select('id')
          .eq('form_id', formId);

      final actualSubmissions = (submissionCountResponse as List).length;

      // Count various event types
      final views = analyticsData.where((e) => e['event_type'] == FormEventTypes.view).length;
      final starts = analyticsData.where((e) => e['event_type'] == FormEventTypes.start).length;
      final phoneEntered = analyticsData.where((e) => e['event_type'] == FormEventTypes.phoneEntered).length;
      final identityFound = analyticsData.where((e) => e['event_type'] == FormEventTypes.identityFound).length;
      final identityCreated = analyticsData.where((e) => e['event_type'] == FormEventTypes.identityCreated).length;
      final trackedSubmissions = analyticsData.where((e) => e['event_type'] == FormEventTypes.submit).length;
      final abandonments = analyticsData.where((e) => e['event_type'] == FormEventTypes.abandon).length;

      // Use actual submissions as the authoritative count
      final submissions = actualSubmissions > trackedSubmissions ? actualSubmissions : trackedSubmissions;

      // Calculate rates based on phone entries (preferred) or starts
      // Phone entries represent the true "start" of form engagement with identity tracking
      final effectiveStarts = phoneEntered > 0 ? phoneEntered : (starts > 0 ? starts : submissions);
      final completionRate = effectiveStarts > 0 ? (submissions / effectiveStarts * 100) : (submissions > 0 ? 100.0 : 0.0);
      final abandonmentRate = effectiveStarts > 0 ? (abandonments / effectiveStarts * 100) : 0.0;

      // Calculate identity-related metrics
      final returningUserRate = phoneEntered > 0 ? (identityFound / phoneEntered * 100) : 0.0;
      final newUserRate = phoneEntered > 0 ? (identityCreated / phoneEntered * 100) : 0.0;

      return FormAnalyticsSummary(
        formId: formId,
        totalViews: views > 0 ? views : submissions, // Estimate views if not tracked
        totalStarts: effectiveStarts,
        totalPhoneEntries: phoneEntered,
        totalIdentityFound: identityFound,
        totalIdentityCreated: identityCreated,
        totalSubmissions: submissions,
        totalAbandonments: abandonments,
        completionRate: completionRate.clamp(0, 100),
        abandonmentRate: abandonmentRate.clamp(0, 100),
        returningUserRate: returningUserRate.clamp(0, 100),
        newUserRate: newUserRate.clamp(0, 100),
      );
    } catch (e) {
      print('Error fetching analytics: $e');
      // Try to get at least submission count (use privileged client)
      try {
        final submissionCountResponse = await _readClient
            .from('form_submissions')
            .select('id')
            .eq('form_id', formId);
        final actualSubmissions = (submissionCountResponse as List).length;

        return FormAnalyticsSummary(
          formId: formId,
          totalViews: actualSubmissions,
          totalStarts: actualSubmissions,
          totalPhoneEntries: 0,
          totalIdentityFound: 0,
          totalIdentityCreated: 0,
          totalSubmissions: actualSubmissions,
          totalAbandonments: 0,
          completionRate: actualSubmissions > 0 ? 100.0 : 0.0,
          abandonmentRate: 0,
          returningUserRate: 0,
          newUserRate: 0,
        );
      } catch (_) {
        return FormAnalyticsSummary(
          formId: formId,
          totalViews: 0,
          totalStarts: 0,
          totalPhoneEntries: 0,
          totalIdentityFound: 0,
          totalIdentityCreated: 0,
          totalSubmissions: 0,
          totalAbandonments: 0,
          completionRate: 0,
          abandonmentRate: 0,
          returningUserRate: 0,
          newUserRate: 0,
        );
      }
    }
  }

  /// Get field-level analytics
  Future<List<FieldAnalytics>> getFieldAnalytics(String formId) async {
    try {
      final response = await _supabase
          .from('form_field_analytics')
          .select()
          .eq('form_id', formId);

      final data = response as List;
      final fieldMap = <String, FieldAnalytics>{};

      for (final item in data) {
        final fieldId = item['field_id'] as String;
        final eventType = item['event_type'] as String;

        if (!fieldMap.containsKey(fieldId)) {
          fieldMap[fieldId] = FieldAnalytics(
            fieldId: fieldId,
            fieldType: item['field_type'] as String? ?? 'unknown',
            interactions: 0,
            validationErrors: 0,
          );
        }

        if (eventType == 'interaction') {
          fieldMap[fieldId] = fieldMap[fieldId]!.copyWith(
            interactions: fieldMap[fieldId]!.interactions + 1,
          );
        } else if (eventType == 'validation_error') {
          fieldMap[fieldId] = fieldMap[fieldId]!.copyWith(
            validationErrors: fieldMap[fieldId]!.validationErrors + 1,
          );
        }
      }

      return fieldMap.values.toList();
    } catch (e) {
      print('Error fetching field analytics: $e');
      return [];
    }
  }

  /// Get time-series data for form submissions
  /// Uses form_submissions table as primary source, falls back to form_analytics
  Future<List<TimeSeriesData>> getSubmissionTimeSeries(
    String formId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // First try to get from actual submissions (more reliable, use privileged client)
      var query = _readClient
          .from('form_submissions')
          .select('created_at')
          .eq('form_id', formId);

      if (startDate != null) {
        query = query.gte('created_at', startDate.toIso8601String());
      }
      if (endDate != null) {
        query = query.lte('created_at', endDate.toIso8601String());
      }

      final response = await query.order('created_at', ascending: true);
      final data = response as List;

      if (data.isEmpty) {
        return [];
      }

      // Group by date
      final dateMap = <String, int>{};
      for (final item in data) {
        final timestamp = DateTime.parse(item['created_at'] as String);
        final dateKey = '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}';
        dateMap[dateKey] = (dateMap[dateKey] ?? 0) + 1;
      }

      return dateMap.entries.map((e) {
        return TimeSeriesData(
          date: DateTime.parse(e.key),
          count: e.value,
        );
      }).toList()
        ..sort((a, b) => a.date.compareTo(b.date));
    } catch (e) {
      print('Error fetching time series: $e');
      return [];
    }
  }

  /// Get submission stats by status
  Future<Map<String, int>> getSubmissionsByStatus(String formId) async {
    try {
      // Use privileged client to bypass RLS
      final response = await _readClient
          .from('form_submissions')
          .select('status')
          .eq('form_id', formId);

      final data = response as List;
      final statusMap = <String, int>{};

      for (final item in data) {
        final status = item['status'] as String? ?? 'submitted';
        statusMap[status] = (statusMap[status] ?? 0) + 1;
      }

      return statusMap;
    } catch (e) {
      print('Error fetching submission stats: $e');
      return {};
    }
  }

  /// Get recent submission activity (last N submissions with timestamps)
  Future<List<SubmissionActivity>> getRecentActivity(String formId, {int limit = 10}) async {
    try {
      // Use privileged client to bypass RLS
      final response = await _readClient
          .from('form_submissions')
          .select('id, created_at, submitter_name, submitter_email, status')
          .eq('form_id', formId)
          .order('created_at', ascending: false)
          .limit(limit);

      final data = response as List;
      return data.map((item) => SubmissionActivity(
        id: item['id'] as String,
        createdAt: DateTime.parse(item['created_at'] as String),
        submitterName: item['submitter_name'] as String?,
        submitterEmail: item['submitter_email'] as String?,
        status: item['status'] as String? ?? 'submitted',
      )).toList();
    } catch (e) {
      print('Error fetching recent activity: $e');
      return [];
    }
  }
}

/// Form analytics summary with identity tracking metrics
class FormAnalyticsSummary {
  final String formId;

  /// Total form views
  final int totalViews;

  /// Total form starts (first interaction or phone entry)
  final int totalStarts;

  /// Total phone number entries (form identity initiation)
  final int totalPhoneEntries;

  /// Total returning users (existing identity found)
  final int totalIdentityFound;

  /// Total new users (new subscriber created)
  final int totalIdentityCreated;

  /// Total successful submissions
  final int totalSubmissions;

  /// Total abandoned forms
  final int totalAbandonments;

  /// Completion rate (submitted / started)
  final double completionRate;

  /// Abandonment rate (abandoned / started)
  final double abandonmentRate;

  /// Returning user rate (identity_found / phone_entered)
  final double returningUserRate;

  /// New user rate (identity_created / phone_entered)
  final double newUserRate;

  FormAnalyticsSummary({
    required this.formId,
    required this.totalViews,
    required this.totalStarts,
    this.totalPhoneEntries = 0,
    this.totalIdentityFound = 0,
    this.totalIdentityCreated = 0,
    required this.totalSubmissions,
    required this.totalAbandonments,
    required this.completionRate,
    required this.abandonmentRate,
    this.returningUserRate = 0,
    this.newUserRate = 0,
  });

  /// Convenience getter for conversion rate (phone entered to submitted)
  double get conversionRate {
    if (totalPhoneEntries == 0) return 0;
    return (totalSubmissions / totalPhoneEntries * 100).clamp(0, 100);
  }

  /// Convenience getter for drop-off rate (phone entered but not submitted)
  double get dropOffRate {
    if (totalPhoneEntries == 0) return 0;
    final dropOffs = totalPhoneEntries - totalSubmissions;
    return (dropOffs / totalPhoneEntries * 100).clamp(0, 100);
  }
}

/// Field-level analytics
class FieldAnalytics {
  final String fieldId;
  final String fieldType;
  final int interactions;
  final int validationErrors;

  FieldAnalytics({
    required this.fieldId,
    required this.fieldType,
    required this.interactions,
    required this.validationErrors,
  });

  FieldAnalytics copyWith({
    String? fieldId,
    String? fieldType,
    int? interactions,
    int? validationErrors,
  }) {
    return FieldAnalytics(
      fieldId: fieldId ?? this.fieldId,
      fieldType: fieldType ?? this.fieldType,
      interactions: interactions ?? this.interactions,
      validationErrors: validationErrors ?? this.validationErrors,
    );
  }
}

/// Time series data point
class TimeSeriesData {
  final DateTime date;
  final int count;

  TimeSeriesData({
    required this.date,
    required this.count,
  });
}

/// Submission activity for recent activity list
class SubmissionActivity {
  final String id;
  final DateTime createdAt;
  final String? submitterName;
  final String? submitterEmail;
  final String status;

  SubmissionActivity({
    required this.id,
    required this.createdAt,
    this.submitterName,
    this.submitterEmail,
    required this.status,
  });

  String get displayName {
    if (submitterName != null && submitterName!.isNotEmpty) {
      return submitterName!;
    }
    if (submitterEmail != null && submitterEmail!.isNotEmpty) {
      return submitterEmail!;
    }
    return 'Anonymous';
  }
}
