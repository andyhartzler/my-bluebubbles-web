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
  String _eventType = 'event'; // 'event', 'committee', 'social', 'deadline'
  bool _syncToGoogle = true;

  bool _isLoading = false;
  String? _error;

  bool get _isEditing => widget.existingEvent != null;

  String? get _currentUserId =>
      Supabase.instance.client.auth.currentUser?.id;

  // Event type options
  static const _eventTypes = [
    ('event', 'General Event'),
    ('committee', 'Committee Meeting'),
    ('social', 'Social Event'),
    ('deadline', 'Deadline'),
  ];

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
      _eventType = event.eventType ?? 'event';
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
        _eventType = 'committee';
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
    final isDark = theme.brightness == Brightness.dark;
    final isSmallScreen = MediaQuery.of(context).size.width < 500;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 40,
        vertical: 24,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                color: const Color(0xFF3B82F6).withOpacity(0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.event,
                    color: Color(0xFF3B82F6),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isEditing ? 'Edit Event' : 'Create Event',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close,
                      color: isDark ? const Color(0xFF98989F) : const Color(0xFF6B7280),
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
                        decoration: InputDecoration(
                          labelText: 'Event Title *',
                          hintText: 'e.g., Monthly Meeting',
                          prefixIcon: const Icon(Icons.title),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
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
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF2C2C2E)
                              : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: SwitchListTile(
                          title: Text(
                            'All Day Event',
                            style: TextStyle(
                              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                            ),
                          ),
                          value: _allDay,
                          onChanged: _isLoading
                              ? null
                              : (value) {
                                  setState(() => _allDay = value);
                                },
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Start date/time
                      Text(
                        'Start',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFF98989F)
                              : const Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: _buildDatePicker(context, isDark, true)),
                          if (!_allDay) ...[
                            const SizedBox(width: 12),
                            Expanded(child: _buildTimePicker(context, isDark, true)),
                          ],
                        ],
                      ),

                      const SizedBox(height: 16),

                      // End date/time
                      Text(
                        'End',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFF98989F)
                              : const Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: _buildDatePicker(context, isDark, false)),
                          if (!_allDay) ...[
                            const SizedBox(width: 12),
                            Expanded(child: _buildTimePicker(context, isDark, false)),
                          ],
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Location field
                      TextFormField(
                        controller: _locationController,
                        decoration: InputDecoration(
                          labelText: 'Location (optional)',
                          hintText: 'e.g., Room 101 or Zoom',
                          prefixIcon: const Icon(Icons.location_on),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        enabled: !_isLoading,
                      ),

                      const SizedBox(height: 16),

                      // Description field
                      TextFormField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          labelText: 'Description (optional)',
                          hintText: 'Event details or agenda',
                          prefixIcon: const Icon(Icons.description),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignLabelWithHint: true,
                        ),
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                        enabled: !_isLoading,
                      ),

                      const SizedBox(height: 16),

                      // Event type dropdown
                      DropdownButtonFormField<String>(
                        value: _eventType,
                        decoration: InputDecoration(
                          labelText: 'Event Type',
                          prefixIcon: const Icon(Icons.category),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        items: _eventTypes.map((type) {
                          return DropdownMenuItem<String>(
                            value: type.$1,
                            child: Text(type.$2),
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

                      // Sync to Google Calendar
                      if (!_isEditing)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF2C2C2E)
                                : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: SwitchListTile(
                            title: Text(
                              'Sync to Google Calendar',
                              style: TextStyle(
                                color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                              ),
                            ),
                            subtitle: Text(
                              'Add to shared organization calendar',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? const Color(0xFF98989F)
                                    : const Color(0xFF6B7280),
                              ),
                            ),
                            value: _syncToGoogle,
                            onChanged: _isLoading
                                ? null
                                : (value) {
                                    setState(() => _syncToGoogle = value);
                                  },
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),

                      // Error message
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(color: Colors.red, fontSize: 13),
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
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? const Color(0xFF38383A)
                        : const Color(0xFFE5E7EB),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: isDark
                            ? const Color(0xFF98989F)
                            : const Color(0xFF6B7280),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _isLoading ? null : _submitForm,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(_isEditing ? Icons.save : Icons.add),
                    label: Text(_isLoading
                        ? (_isEditing ? 'Saving...' : 'Creating...')
                        : (_isEditing ? 'Save Changes' : 'Create Event')),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker(BuildContext context, bool isDark, bool isStart) {
    final dateFormat = DateFormat('EEE, MMM d');
    final date = isStart ? _startDate : _endDate;

    return InkWell(
      onTap: _isLoading ? null : () => _selectDate(context, isStart),
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.calendar_today, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Text(dateFormat.format(date)),
      ),
    );
  }

  Widget _buildTimePicker(BuildContext context, bool isDark, bool isStart) {
    final time = isStart ? _startTime : _endTime;

    return InkWell(
      onTap: _isLoading ? null : () => _selectTime(context, isStart),
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.access_time, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
    if (endDateTime.isBefore(startDateTime) ||
        endDateTime.isAtSameMomentAs(startDateTime)) {
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
          isAllDay: _allDay,
          eventType: _eventType,
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
          isAllDay: _allDay,
          eventType: _eventType,
          committeeName: widget.committeeName,
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
