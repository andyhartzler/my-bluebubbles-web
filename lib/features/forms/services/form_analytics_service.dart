import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for tracking form analytics and interactions
class FormAnalyticsService {
  final _supabase = Supabase.instance.client;

  /// Track when a form is viewed
  Future<void> trackFormView(String formId, String? userId) async {
    try {
      await _supabase.from('form_analytics').insert({
        'form_id': formId,
        'user_id': userId,
        'event_type': 'view',
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Silently fail - analytics shouldn't break the app
      print('Analytics tracking error: $e');
    }
  }

  /// Track when a form is started (first field interaction)
  Future<void> trackFormStart(String formId, String? userId) async {
    try {
      await _supabase.from('form_analytics').insert({
        'form_id': formId,
        'user_id': userId,
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
    Map<String, dynamic> submissionData,
  ) async {
    try {
      await _supabase.from('form_analytics').insert({
        'form_id': formId,
        'user_id': userId,
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
    Map<String, dynamic> partialData,
  ) async {
    try {
      await _supabase.from('form_analytics').insert({
        'form_id': formId,
        'user_id': userId,
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
    String? userId,
  ) async {
    try {
      await _supabase.from('form_field_analytics').insert({
        'form_id': formId,
        'field_id': fieldId,
        'field_type': fieldType,
        'user_id': userId,
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
    String? userId,
  ) async {
    try {
      await _supabase.from('form_field_analytics').insert({
        'form_id': formId,
        'field_id': fieldId,
        'user_id': userId,
        'event_type': 'validation_error',
        'timestamp': DateTime.now().toIso8601String(),
        'metadata': {'error': errorMessage},
      });
    } catch (e) {
      print('Analytics tracking error: $e');
    }
  }

  /// Get form analytics summary
  Future<FormAnalyticsSummary> getFormAnalytics(String formId) async {
    try {
      final response = await _supabase
          .from('form_analytics')
          .select()
          .eq('form_id', formId);

      final data = response as List;

      final views = data.where((e) => e['event_type'] == 'view').length;
      final starts = data.where((e) => e['event_type'] == 'start').length;
      final submissions = data.where((e) => e['event_type'] == 'submit').length;
      final abandonments = data.where((e) => e['event_type'] == 'abandon').length;

      final completionRate = starts > 0 ? (submissions / starts * 100) : 0.0;
      final abandonmentRate = starts > 0 ? (abandonments / starts * 100) : 0.0;

      return FormAnalyticsSummary(
        formId: formId,
        totalViews: views,
        totalStarts: starts,
        totalSubmissions: submissions,
        totalAbandonments: abandonments,
        completionRate: completionRate,
        abandonmentRate: abandonmentRate,
      );
    } catch (e) {
      print('Error fetching analytics: $e');
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
  Future<List<TimeSeriesData>> getSubmissionTimeSeries(
    String formId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var query = _supabase
          .from('form_analytics')
          .select()
          .eq('form_id', formId)
          .eq('event_type', 'submit');

      if (startDate != null) {
        query = query.gte('timestamp', startDate.toIso8601String());
      }
      if (endDate != null) {
        query = query.lte('timestamp', endDate.toIso8601String());
      }

      final response = await query;
      final data = response as List;

      // Group by date
      final dateMap = <String, int>{};
      for (final item in data) {
        final timestamp = DateTime.parse(item['timestamp'] as String);
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
