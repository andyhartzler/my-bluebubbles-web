import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for tracking form analytics and interactions
class FormAnalyticsService {
  final _supabase = Supabase.instance.client;

  /// Track when a form is viewed
  Future<void> trackFormView(String formId, String? userId, {String? memberId}) async {
    try {
      await _supabase.from('form_analytics').insert({
        'form_id': formId,
        'user_id': userId,
        'member_id': memberId,
        'event_type': 'view',
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Silently fail - analytics shouldn't break the app
      print('Analytics tracking error: $e');
    }
  }

  /// Track when a form is started (first field interaction)
  Future<void> trackFormStart(String formId, String? userId, {String? memberId}) async {
    try {
      await _supabase.from('form_analytics').insert({
        'form_id': formId,
        'user_id': userId,
        'member_id': memberId,
        'event_type': 'start',
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
  }) async {
    try {
      await _supabase.from('form_analytics').insert({
        'form_id': formId,
        'user_id': userId,
        'member_id': memberId,
        'event_type': 'submit',
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
  }) async {
    try {
      await _supabase.from('form_analytics').insert({
        'form_id': formId,
        'user_id': userId,
        'member_id': memberId,
        'event_type': 'abandon',
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

  /// Track field-level interactions
  Future<void> trackFieldInteraction(
    String formId,
    String fieldId,
    String fieldType,
    String? userId, {
    String? memberId,
  }) async {
    try {
      await _supabase.from('form_field_analytics').insert({
        'form_id': formId,
        'field_id': fieldId,
        'field_type': fieldType,
        'user_id': userId,
        'member_id': memberId,
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
  }) async {
    try {
      await _supabase.from('form_field_analytics').insert({
        'form_id': formId,
        'field_id': fieldId,
        'user_id': userId,
        'member_id': memberId,
        'event_type': 'validation_error',
        'timestamp': DateTime.now().toIso8601String(),
        'metadata': {'error': errorMessage},
      });
    } catch (e) {
      print('Analytics tracking error: $e');
    }
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

      // Get actual submission count from form_submissions table
      final submissionCountResponse = await _supabase
          .from('form_submissions')
          .select('id')
          .eq('form_id', formId);

      final actualSubmissions = (submissionCountResponse as List).length;

      final views = analyticsData.where((e) => e['event_type'] == 'view').length;
      final starts = analyticsData.where((e) => e['event_type'] == 'start').length;
      final trackedSubmissions = analyticsData.where((e) => e['event_type'] == 'submit').length;
      final abandonments = analyticsData.where((e) => e['event_type'] == 'abandon').length;

      // Use actual submissions as the authoritative count
      final submissions = actualSubmissions > trackedSubmissions ? actualSubmissions : trackedSubmissions;

      // Calculate rates based on starts (if we have starts data)
      // Otherwise estimate based on submissions
      final effectiveStarts = starts > 0 ? starts : submissions;
      final completionRate = effectiveStarts > 0 ? (submissions / effectiveStarts * 100) : (submissions > 0 ? 100.0 : 0.0);
      final abandonmentRate = effectiveStarts > 0 ? (abandonments / effectiveStarts * 100) : 0.0;

      return FormAnalyticsSummary(
        formId: formId,
        totalViews: views > 0 ? views : submissions, // Estimate views if not tracked
        totalStarts: effectiveStarts,
        totalSubmissions: submissions,
        totalAbandonments: abandonments,
        completionRate: completionRate.clamp(0, 100),
        abandonmentRate: abandonmentRate.clamp(0, 100),
      );
    } catch (e) {
      print('Error fetching analytics: $e');
      // Try to get at least submission count
      try {
        final submissionCountResponse = await _supabase
            .from('form_submissions')
            .select('id')
            .eq('form_id', formId);
        final actualSubmissions = (submissionCountResponse as List).length;

        return FormAnalyticsSummary(
          formId: formId,
          totalViews: actualSubmissions,
          totalStarts: actualSubmissions,
          totalSubmissions: actualSubmissions,
          totalAbandonments: 0,
          completionRate: actualSubmissions > 0 ? 100.0 : 0.0,
          abandonmentRate: 0,
        );
      } catch (_) {
        return FormAnalyticsSummary(
          formId: formId,
          totalViews: 0,
          totalStarts: 0,
          totalSubmissions: 0,
          totalAbandonments: 0,
          completionRate: 0,
          abandonmentRate: 0,
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
      // First try to get from actual submissions (more reliable)
      var query = _supabase
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
      final response = await _supabase
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
      final response = await _supabase
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

/// Form analytics summary
class FormAnalyticsSummary {
  final String formId;
  final int totalViews;
  final int totalStarts;
  final int totalSubmissions;
  final int totalAbandonments;
  final double completionRate;
  final double abandonmentRate;

  FormAnalyticsSummary({
    required this.formId,
    required this.totalViews,
    required this.totalStarts,
    required this.totalSubmissions,
    required this.totalAbandonments,
    required this.completionRate,
    required this.abandonmentRate,
  });
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
