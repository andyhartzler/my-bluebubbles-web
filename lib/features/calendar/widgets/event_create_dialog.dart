import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bluebubbles/features/calendar/models/calendar_event.dart';
import 'package:bluebubbles/features/calendar/services/calendar_service.dart';

/// Dialog for creating or editing a calendar event
class EventCreateDialog extends StatefulWidget {
  final String? committeeName;
  final CalendarEvent? existingEvent;

  const EventCreateDialog({
    super.key,
    this.committeeName,
    this.existingEvent,
  });

  /// Shows the dialog and returns the created/updated event if successful
  static Future<CalendarEvent?> show(
    BuildContext context, {
    String? committeeName,
    CalendarEvent? existingEvent,
  }) {
    return showDialog<CalendarEvent>(
      context: context,
      barrierDismissible: false,
      builder: (context) => EventCreateDialog(
        committeeName: committeeName,
        existingEvent: existingEvent,
      ),
    );
  }

  @override
  State<EventCreateDialog> createState() => _EventCreateDialogState();
}

class _EventCreateDialogState extends State<EventCreateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();

  late DateTime _startDate;
  late TimeOfDay _startTime;
  late DateTime _endDate;
  late TimeOfDay _endTime;
  bool _allDay = false;
  EventType _eventType = EventType.general;
  EventVisibility _visibility = EventVisibility.organization;
  bool _syncToGoogle = true;

  bool _isLoading = false;
  String? _error;

  bool get _isEditing => widget.existingEvent != null;

  String get _currentUserId =>
      Supabase.instance.client.auth.currentUser?.id ?? 'anonymous';

  @override
  void initState() {
    super.initState();

    if (_isEditing) {
      final event = widget.existingEvent!;
      _titleController.text = event.title;
      _descriptionController.text = event.description ?? '';
      _locationController.text = event.location ?? '';
      _startDate = event.startTime.toLocal();
      _startTime = TimeOfDay.fromDateTime(event.startTime.toLocal());
      _endDate = event.endTime.toLocal();
      _endTime = TimeOfDay.fromDateTime(event.endTime.toLocal());
      _allDay = event.allDay;
      _eventType = event.eventType;
      _visibility = event.visibility;
      _syncToGoogle = event.googleEventId != null;
    } else {
      // Default to now rounded to next hour
      final now = DateTime.now();
      final nextHour = DateTime(now.year, now.month, now.day, now.hour + 1);
      _startDate = nextHour;
      _startTime = TimeOfDay.fromDateTime(nextHour);
      _endDate = nextHour.add(const Duration(hours: 1));
      _endTime = TimeOfDay.fromDateTime(nextHour.add(const Duration(hours: 1)));

      // Set event type to committee if we have a committee name
      if (widget.committeeName != null) {
        _eventType = EventType.committee;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  DateTime _combineDateAndTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSmallScreen = MediaQuery.of(context).size.width < 500;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 40,
        vertical: 24,
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.event,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isEditing ? 'Edit Event' : 'Create Event',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),

            // Form content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Title field
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Event Title *',
                          hintText: 'e.g., Monthly Meeting',
                          prefixIcon: Icon(Icons.title),
                          border: OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.words,
                        enabled: !_isLoading,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter an event title';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // All day switch
                      SwitchListTile(
                        title: const Text('All Day Event'),
                        value: _allDay,
                        onChanged: _isLoading
                            ? null
                            : (value) {
                                setState(() => _allDay = value);
                              },
                        contentPadding: EdgeInsets.zero,
                      ),

                      const SizedBox(height: 8),

                      // Start date/time
                      Text(
                        'Start',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: _buildDatePicker(context, true)),
                          if (!_allDay) ...[
                            const SizedBox(width: 12),
                            Expanded(child: _buildTimePicker(context, true)),
                          ],
                        ],
                      ),

                      const SizedBox(height: 16),

                      // End date/time
                      Text(
                        'End',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: _buildDatePicker(context, false)),
                          if (!_allDay) ...[
                            const SizedBox(width: 12),
                            Expanded(child: _buildTimePicker(context, false)),
                          ],
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Location field
                      TextFormField(
                        controller: _locationController,
                        decoration: const InputDecoration(
                          labelText: 'Location (optional)',
                          hintText: 'e.g., Room 101 or Zoom',
                          prefixIcon: Icon(Icons.location_on),
                          border: OutlineInputBorder(),
                        ),
                        enabled: !_isLoading,
                      ),

                      const SizedBox(height: 16),

                      // Description field
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description (optional)',
                          hintText: 'Event details or agenda',
                          prefixIcon: Icon(Icons.description),
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                        enabled: !_isLoading,
                      ),

                      const SizedBox(height: 16),

                      // Event type dropdown
                      DropdownButtonFormField<EventType>(
                        value: _eventType,
                        decoration: const InputDecoration(
                          labelText: 'Event Type',
                          prefixIcon: Icon(Icons.category),
                          border: OutlineInputBorder(),
                        ),
                        items: EventType.values.map((type) {
                          return DropdownMenuItem<EventType>(
                            value: type,
                            child: Text(_eventTypeLabel(type)),
                          );
                        }).toList(),
                        onChanged: _isLoading
                            ? null
                            : (value) {
                                if (value != null) {
                                  setState(() => _eventType = value);
                                }
                              },
                      ),

                      const SizedBox(height: 16),

                      // Visibility dropdown
                      DropdownButtonFormField<EventVisibility>(
                        value: _visibility,
                        decoration: const InputDecoration(
                          labelText: 'Visibility',
                          prefixIcon: Icon(Icons.visibility),
                          border: OutlineInputBorder(),
                        ),
                        items: EventVisibility.values.map((vis) {
                          return DropdownMenuItem<EventVisibility>(
                            value: vis,
                            child: Text(_visibilityLabel(vis)),
                          );
                        }).toList(),
                        onChanged: _isLoading
                            ? null
                            : (value) {
                                if (value != null) {
                                  setState(() => _visibility = value);
                                }
                              },
                      ),

                      const SizedBox(height: 16),

                      // Sync to Google Calendar
                      if (!_isEditing)
                        SwitchListTile(
                          title: const Text('Sync to Google Calendar'),
                          subtitle: const Text('Add this event to the shared calendar'),
                          value: _syncToGoogle,
                          onChanged: _isLoading
                              ? null
                              : (value) {
                                  setState(() => _syncToGoogle = value);
                                },
                          contentPadding: EdgeInsets.zero,
                        ),

                      // Error message
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: theme.colorScheme.onErrorContainer,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: TextStyle(
                                    color: theme.colorScheme.onErrorContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: theme.dividerColor)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _isLoading ? null : _submitForm,
                    icon: _isLoading
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.onPrimary,
                            ),
                          )
                        : Icon(_isEditing ? Icons.save : Icons.add),
                    label: Text(_isLoading
                        ? (_isEditing ? 'Saving...' : 'Creating...')
                        : (_isEditing ? 'Save Changes' : 'Create Event')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker(BuildContext context, bool isStart) {
    final dateFormat = DateFormat('EEE, MMM d');
    final date = isStart ? _startDate : _endDate;

    return InkWell(
      onTap: _isLoading ? null : () => _selectDate(context, isStart),
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.calendar_today),
          border: OutlineInputBorder(),
        ),
        child: Text(dateFormat.format(date)),
      ),
    );
  }

  Widget _buildTimePicker(BuildContext context, bool isStart) {
    final time = isStart ? _startTime : _endTime;

    return InkWell(
      onTap: _isLoading ? null : () => _selectTime(context, isStart),
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.access_time),
          border: OutlineInputBorder(),
        ),
        child: Text(_formatTime(time)),
      ),
    );
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String _eventTypeLabel(EventType type) {
    switch (type) {
      case EventType.general:
        return 'General';
      case EventType.committee:
        return 'Committee';
      case EventType.executive:
        return 'Executive';
      case EventType.social:
        return 'Social';
      case EventType.deadline:
        return 'Deadline';
    }
  }

  String _visibilityLabel(EventVisibility visibility) {
    switch (visibility) {
      case EventVisibility.public:
        return 'Public';
      case EventVisibility.organization:
        return 'Organization';
      case EventVisibility.committee:
        return 'Committee Only';
      case EventVisibility.private:
        return 'Private';
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final now = DateTime.now();
    final currentDate = isStart ? _startDate : _endDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: DateTime(now.year + 2, 12, 31),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          // If end date is before start date, update it
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final currentTime = isStart ? _startTime : _endTime;

    final picked = await showTimePicker(
      context: context,
      initialTime: currentTime,
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Build full datetimes
    DateTime startDateTime;
    DateTime endDateTime;

    if (_allDay) {
      startDateTime = DateTime(_startDate.year, _startDate.month, _startDate.day);
      endDateTime = DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59);
    } else {
      startDateTime = _combineDateAndTime(_startDate, _startTime);
      endDateTime = _combineDateAndTime(_endDate, _endTime);
    }

    // Validate that end is after start
    if (endDateTime.isBefore(startDateTime) || endDateTime.isAtSameMomentAs(startDateTime)) {
      setState(() {
        _error = 'End time must be after start time';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final service = CalendarService();
      CalendarEvent event;

      if (_isEditing) {
        event = await service.updateEvent(
          event: widget.existingEvent!,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          location: _locationController.text.trim().isEmpty
              ? null
              : _locationController.text.trim(),
          startTime: startDateTime,
          endTime: endDateTime,
          allDay: _allDay,
          eventType: _eventType,
          visibility: _visibility,
        );
      } else {
        event = await service.createEvent(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          location: _locationController.text.trim().isEmpty
              ? null
              : _locationController.text.trim(),
          startTime: startDateTime,
          endTime: endDateTime,
          allDay: _allDay,
          eventType: _eventType,
          committeeName: widget.committeeName,
          visibility: _visibility,
          createdBy: _currentUserId,
          syncToGoogleCalendar: _syncToGoogle,
        );
      }

      if (mounted) {
        Navigator.of(context).pop(event);
      }
    } on CalendarException catch (e) {
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'An unexpected error occurred: $e';
        _isLoading = false;
      });
    }
  }
}
