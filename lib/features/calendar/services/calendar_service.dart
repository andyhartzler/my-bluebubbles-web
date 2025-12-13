import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:bluebubbles/features/calendar/models/calendar_event.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

/// Exception thrown when calendar operations fail
class CalendarException implements Exception {
  final String message;
  final Object? cause;

  CalendarException(this.message, {this.cause});

  @override
  String toString() => 'CalendarException: $message';
}

/// Response from Google Calendar API via edge function
class GoogleCalendarEventResponse {
  final String googleEventId;
  final String? htmlLink;

  const GoogleCalendarEventResponse({
    required this.googleEventId,
    this.htmlLink,
  });

  factory GoogleCalendarEventResponse.fromJson(Map<String, dynamic> json) {
    return GoogleCalendarEventResponse(
      googleEventId: json['google_event_id'] as String,
      htmlLink: json['html_link'] as String?,
    );
  }
}

/// Service for managing calendar events through Supabase and Google Calendar
class CalendarService {
  static final CalendarService _instance = CalendarService._internal();
  factory CalendarService() => _instance;
  CalendarService._internal();

  final CRMSupabaseService _supabase = CRMSupabaseService();
  final Uuid _uuid = const Uuid();

  bool get isReady => _supabase.isInitialized;

  SupabaseClient get _client =>
      _supabase.hasServiceRole ? _supabase.privilegedClient : _supabase.client;

  /// Creates a new calendar event, optionally syncing to Google Calendar
  Future<CalendarEvent> createEvent({
    required String title,
    String? description,
    String? location,
    required DateTime startTime,
    required DateTime endTime,
    bool allDay = false,
    String timezone = 'America/Chicago',
    String? recurrenceRule,
    DateTime? recurrenceEnd,
    EventType eventType = EventType.general,
    String? committeeName,
    bool isPublic = true,
    EventVisibility visibility = EventVisibility.organization,
    required String createdBy,
    bool syncToGoogleCalendar = true,
  }) async {
    await _ensureInitialized();

    String? googleEventId;

    // Step 1: Create event in Google Calendar if requested
    if (syncToGoogleCalendar) {
      final response = await _createGoogleCalendarEvent(
        title: title,
        description: description,
        location: location,
        startTime: startTime,
        endTime: endTime,
        allDay: allDay,
        timezone: timezone,
        recurrenceRule: recurrenceRule,
      );
      googleEventId = response.googleEventId;
    }

    // Step 2: Save to calendar_events table
    final eventId = _uuid.v4();
    final now = DateTime.now();

    final event = CalendarEvent(
      id: eventId,
      createdAt: now,
      title: title,
      description: description,
      location: location,
      startTime: startTime,
      endTime: endTime,
      allDay: allDay,
      timezone: timezone,
      recurrenceRule: recurrenceRule,
      recurrenceEnd: recurrenceEnd,
      eventType: eventType,
      committeeName: committeeName,
      isPublic: isPublic,
      visibility: visibility,
      createdBy: createdBy,
      googleEventId: googleEventId,
      status: EventStatus.confirmed,
    );

    try {
      await _client.from('calendar_events').insert(event.toJson());
    } catch (e) {
      // If database insert fails and we created a Google event, try to delete it
      if (googleEventId != null) {
        try {
          await _deleteGoogleCalendarEvent(googleEventId);
        } catch (_) {
          // Ignore cleanup error
        }
      }
      throw CalendarException('Failed to save event to database: $e', cause: e);
    }

    return event;
  }

  /// Updates an existing calendar event
  Future<CalendarEvent> updateEvent({
    required CalendarEvent event,
    String? title,
    String? description,
    String? location,
    DateTime? startTime,
    DateTime? endTime,
    bool? allDay,
    String? recurrenceRule,
    DateTime? recurrenceEnd,
    EventType? eventType,
    bool? isPublic,
    EventVisibility? visibility,
  }) async {
    await _ensureInitialized();

    final newTitle = title ?? event.title;
    final newDescription = description ?? event.description;
    final newLocation = location ?? event.location;
    final newStartTime = startTime ?? event.startTime;
    final newEndTime = endTime ?? event.endTime;
    final newAllDay = allDay ?? event.allDay;
    final newRecurrenceRule = recurrenceRule ?? event.recurrenceRule;
    final newRecurrenceEnd = recurrenceEnd ?? event.recurrenceEnd;

    // Update Google Calendar if we have a Google event ID
    if (event.googleEventId != null) {
      await _updateGoogleCalendarEvent(
        googleEventId: event.googleEventId!,
        title: newTitle,
        description: newDescription,
        location: newLocation,
        startTime: newStartTime,
        endTime: newEndTime,
        allDay: newAllDay,
        timezone: event.timezone,
        recurrenceRule: newRecurrenceRule,
      );
    }

    // Update in database
    final updatedEvent = event.copyWith(
      title: newTitle,
      description: newDescription,
      location: newLocation,
      startTime: newStartTime,
      endTime: newEndTime,
      allDay: newAllDay,
      recurrenceRule: newRecurrenceRule,
      recurrenceEnd: newRecurrenceEnd,
      eventType: eventType,
      isPublic: isPublic,
      visibility: visibility,
      updatedAt: DateTime.now(),
    );

    try {
      await _client
          .from('calendar_events')
          .update({
            'title': updatedEvent.title,
            'description': updatedEvent.description,
            'location': updatedEvent.location,
            'start_time': updatedEvent.startTime.toUtc().toIso8601String(),
            'end_time': updatedEvent.endTime.toUtc().toIso8601String(),
            'all_day': updatedEvent.allDay,
            'recurrence_rule': updatedEvent.recurrenceRule,
            'recurrence_end': updatedEvent.recurrenceEnd?.toUtc().toIso8601String(),
            'event_type': updatedEvent.eventType.name,
            'is_public': updatedEvent.isPublic,
            'visibility': updatedEvent.visibility.name,
            'updated_at': updatedEvent.updatedAt!.toUtc().toIso8601String(),
          })
          .eq('id', event.id);
    } catch (e) {
      throw CalendarException('Failed to update event in database: $e', cause: e);
    }

    return updatedEvent;
  }

  /// Cancels (soft deletes) an event
  Future<CalendarEvent> cancelEvent(CalendarEvent event) async {
    await _ensureInitialized();

    // Delete from Google Calendar if we have a Google event ID
    if (event.googleEventId != null) {
      await _deleteGoogleCalendarEvent(event.googleEventId!);
    }

    // Update status in database
    final now = DateTime.now();
    final cancelledEvent = event.copyWith(
      status: EventStatus.cancelled,
      updatedAt: now,
    );

    try {
      await _client
          .from('calendar_events')
          .update({
            'status': 'cancelled',
            'updated_at': now.toUtc().toIso8601String(),
          })
          .eq('id', event.id);
    } catch (e) {
      throw CalendarException('Failed to cancel event in database: $e', cause: e);
    }

    return cancelledEvent;
  }

  /// Gets events for a date range
  Future<List<CalendarEvent>> getEvents({
    required DateTime startDate,
    required DateTime endDate,
    String? committeeName,
    EventType? eventType,
    bool includeAll = false,
    int limit = 100,
  }) async {
    await _ensureInitialized();

    try {
      var query = _client
          .from('calendar_events')
          .select()
          .gte('start_time', startDate.toUtc().toIso8601String())
          .lte('start_time', endDate.toUtc().toIso8601String());

      if (!includeAll) {
        query = query.neq('status', 'cancelled');
      }

      if (committeeName != null) {
        query = query.eq('committee_name', committeeName);
      }

      if (eventType != null) {
        query = query.eq('event_type', eventType.name);
      }

      final data = await query
          .order('start_time', ascending: true)
          .limit(limit);

      return (data as List<dynamic>)
          .map((item) => CalendarEvent.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw CalendarException('Failed to fetch events: $e', cause: e);
    }
  }

  /// Gets upcoming events
  Future<List<CalendarEvent>> getUpcomingEvents({
    String? committeeName,
    EventType? eventType,
    int limit = 10,
  }) async {
    await _ensureInitialized();

    try {
      var query = _client
          .from('calendar_events')
          .select()
          .gte('start_time', DateTime.now().toUtc().toIso8601String())
          .neq('status', 'cancelled');

      if (committeeName != null) {
        query = query.eq('committee_name', committeeName);
      }

      if (eventType != null) {
        query = query.eq('event_type', eventType.name);
      }

      final data = await query
          .order('start_time', ascending: true)
          .limit(limit);

      return (data as List<dynamic>)
          .map((item) => CalendarEvent.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw CalendarException('Failed to fetch upcoming events: $e', cause: e);
    }
  }

  /// Gets events for a specific month
  Future<List<CalendarEvent>> getEventsForMonth(
    int year,
    int month, {
    String? committeeName,
  }) async {
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 0, 23, 59, 59);

    return getEvents(
      startDate: startDate,
      endDate: endDate,
      committeeName: committeeName,
    );
  }

  /// Gets a single event by ID
  Future<CalendarEvent?> getEventById(String id) async {
    await _ensureInitialized();

    try {
      final data = await _client
          .from('calendar_events')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (data == null) return null;
      return CalendarEvent.fromJson(data);
    } catch (e) {
      throw CalendarException('Failed to fetch event: $e', cause: e);
    }
  }

  /// Gets the Google Calendar subscription URL
  Future<String?> getCalendarSubscriptionUrl({String? committeeName}) async {
    await _ensureInitialized();

    try {
      final response = await _client.functions.invoke(
        'calendar-get-subscription-url',
        body: {
          if (committeeName != null) 'committee_name': committeeName,
        },
      );

      if (response.status != 200) {
        return null;
      }

      final data = response.data as Map<String, dynamic>;
      return data['subscription_url'] as String?;
    } catch (e) {
      throw CalendarException('Failed to get subscription URL: $e', cause: e);
    }
  }

  // Private helper methods

  Future<void> _ensureInitialized() async {
    if (!_supabase.isInitialized) {
      try {
        await _supabase.initialize();
      } catch (e) {
        throw CalendarException('Failed to initialize Supabase: $e', cause: e);
      }
    }

    if (!_supabase.isInitialized) {
      throw CalendarException('Supabase is not configured');
    }
  }

  Future<GoogleCalendarEventResponse> _createGoogleCalendarEvent({
    required String title,
    String? description,
    String? location,
    required DateTime startTime,
    required DateTime endTime,
    required bool allDay,
    required String timezone,
    String? recurrenceRule,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'calendar-create-event',
        body: {
          'title': title,
          if (description != null && description.isNotEmpty)
            'description': description,
          if (location != null && location.isNotEmpty) 'location': location,
          'start_time': startTime.toUtc().toIso8601String(),
          'end_time': endTime.toUtc().toIso8601String(),
          'all_day': allDay,
          'timezone': timezone,
          if (recurrenceRule != null) 'recurrence_rule': recurrenceRule,
        },
      );

      final statusCode = response.status;
      if (statusCode != 200) {
        final data = response.data;
        final errorMessage = data is Map
            ? (data['error']?.toString() ?? 'Unknown error')
            : 'Unknown error';
        throw CalendarException(
            'Failed to create Google Calendar event (HTTP $statusCode): $errorMessage');
      }

      final data = response.data as Map<String, dynamic>;
      return GoogleCalendarEventResponse.fromJson(data);
    } catch (e) {
      if (e is CalendarException) rethrow;
      throw CalendarException('Failed to create Google Calendar event: $e',
          cause: e);
    }
  }

  Future<void> _updateGoogleCalendarEvent({
    required String googleEventId,
    required String title,
    String? description,
    String? location,
    required DateTime startTime,
    required DateTime endTime,
    required bool allDay,
    required String timezone,
    String? recurrenceRule,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'calendar-update-event',
        body: {
          'google_event_id': googleEventId,
          'title': title,
          if (description != null) 'description': description,
          if (location != null) 'location': location,
          'start_time': startTime.toUtc().toIso8601String(),
          'end_time': endTime.toUtc().toIso8601String(),
          'all_day': allDay,
          'timezone': timezone,
          if (recurrenceRule != null) 'recurrence_rule': recurrenceRule,
        },
      );

      final statusCode = response.status;
      if (statusCode != 200) {
        final data = response.data;
        final errorMessage = data is Map
            ? (data['error']?.toString() ?? 'Unknown error')
            : 'Unknown error';
        throw CalendarException(
            'Failed to update Google Calendar event (HTTP $statusCode): $errorMessage');
      }
    } catch (e) {
      if (e is CalendarException) rethrow;
      throw CalendarException('Failed to update Google Calendar event: $e',
          cause: e);
    }
  }

  Future<void> _deleteGoogleCalendarEvent(String googleEventId) async {
    try {
      final response = await _client.functions.invoke(
        'calendar-delete-event',
        body: {
          'google_event_id': googleEventId,
        },
      );

      final statusCode = response.status;
      if (statusCode != 200) {
        final data = response.data;
        final errorMessage = data is Map
            ? (data['error']?.toString() ?? 'Unknown error')
            : 'Unknown error';
        throw CalendarException(
            'Failed to delete Google Calendar event (HTTP $statusCode): $errorMessage');
      }
    } catch (e) {
      if (e is CalendarException) rethrow;
      throw CalendarException('Failed to delete Google Calendar event: $e',
          cause: e);
    }
  }
}
