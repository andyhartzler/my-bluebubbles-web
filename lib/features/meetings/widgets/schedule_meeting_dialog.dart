import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:bluebubbles/features/meetings/models/scheduled_meeting.dart';
import 'package:bluebubbles/features/meetings/services/zoom_meeting_service.dart';

/// Dialog for scheduling a new Zoom meeting
class ScheduleMeetingDialog extends StatefulWidget {
  final String? committeeId;
  final String? committeeName;
  final String createdBy;
  final ScheduledMeeting? existingMeeting;

  const ScheduleMeetingDialog({
    super.key,
    this.committeeId,
    this.committeeName,
    required this.createdBy,
    this.existingMeeting,
  });

  /// Shows the dialog and returns the created/updated meeting if successful
  static Future<ScheduledMeeting?> show(
    BuildContext context, {
    String? committeeId,
    String? committeeName,
    required String createdBy,
    ScheduledMeeting? existingMeeting,
  }) {
    return showDialog<ScheduledMeeting>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ScheduleMeetingDialog(
        committeeId: committeeId,
        committeeName: committeeName,
        createdBy: createdBy,
        existingMeeting: existingMeeting,
      ),
    );
  }

  @override
  State<ScheduleMeetingDialog> createState() => _ScheduleMeetingDialogState();
}

class _ScheduleMeetingDialogState extends State<ScheduleMeetingDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  int _selectedDuration = 60;

  bool _isLoading = false;
  String? _error;

  bool get _isEditing => widget.existingMeeting != null;

  @override
  void initState() {
    super.initState();

    if (_isEditing) {
      final meeting = widget.existingMeeting!;
      _titleController.text = meeting.title;
      _descriptionController.text = meeting.description ?? '';
      _selectedDate = meeting.meetingDate;
      final timeParts = meeting.startTime.split(':');
      _selectedTime = TimeOfDay(
        hour: int.parse(timeParts[0]),
        minute: int.parse(timeParts[1]),
      );
      _selectedDuration = meeting.durationMinutes;
    } else {
      // Default to today or tomorrow if past business hours
      final now = DateTime.now();
      if (now.hour >= 18) {
        _selectedDate = DateTime(now.year, now.month, now.day + 1);
      } else {
        _selectedDate = DateTime(now.year, now.month, now.day);
      }

      // Default to the next hour
      final nextHour = now.hour + 1;
      if (nextHour >= 24) {
        _selectedDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day + 1);
        _selectedTime = const TimeOfDay(hour: 9, minute: 0);
      } else {
        _selectedTime = TimeOfDay(hour: nextHour, minute: 0);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
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
        constraints: const BoxConstraints(maxWidth: 500),
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
                    Icons.videocam,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isEditing ? 'Edit Meeting' : 'Schedule Zoom Meeting',
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
                          labelText: 'Meeting Title *',
                          hintText: 'e.g., Executive Committee Meeting',
                          prefixIcon: Icon(Icons.title),
                          border: OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.words,
                        enabled: !_isLoading,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a meeting title';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Description field
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description (optional)',
                          hintText: 'Meeting agenda or notes',
                          prefixIcon: Icon(Icons.description),
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                        enabled: !_isLoading,
                      ),

                      const SizedBox(height: 20),

                      // Date and time row
                      if (isSmallScreen) ...[
                        _buildDatePicker(context),
                        const SizedBox(height: 12),
                        _buildTimePicker(context),
                      ] else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildDatePicker(context)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildTimePicker(context)),
                          ],
                        ),

                      const SizedBox(height: 16),

                      // Duration dropdown
                      DropdownButtonFormField<int>(
                        value: _selectedDuration,
                        decoration: const InputDecoration(
                          labelText: 'Duration *',
                          prefixIcon: Icon(Icons.timer),
                          border: OutlineInputBorder(),
                        ),
                        items: ScheduledMeeting.durationOptions.map((duration) {
                          return DropdownMenuItem<int>(
                            value: duration,
                            child: Text(ScheduledMeeting.durationLabel(duration)),
                          );
                        }).toList(),
                        onChanged: _isLoading
                            ? null
                            : (value) {
                                if (value != null) {
                                  setState(() => _selectedDuration = value);
                                }
                              },
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
                border: Border(
                  top: BorderSide(color: theme.dividerColor),
                ),
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
                        : (_isEditing ? 'Save Changes' : 'Create Meeting')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker(BuildContext context) {
    final dateFormat = DateFormat('EEEE, MMMM d, y');

    return InkWell(
      onTap: _isLoading ? null : () => _selectDate(context),
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Date *',
          prefixIcon: Icon(Icons.calendar_today),
          border: OutlineInputBorder(),
        ),
        child: Text(dateFormat.format(_selectedDate)),
      ),
    );
  }

  Widget _buildTimePicker(BuildContext context) {
    return InkWell(
      onTap: _isLoading ? null : () => _selectTime(context),
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Time *',
          prefixIcon: Icon(Icons.access_time),
          border: OutlineInputBorder(),
        ),
        child: Text(_formatTime(_selectedTime)),
      ),
    );
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<void> _selectDate(BuildContext context) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(today) ? today : _selectedDate,
      firstDate: today,
      lastDate: DateTime(now.year + 1, 12, 31),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );

    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate that the date/time is in the future
    final meetingDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    if (meetingDateTime.isBefore(DateTime.now())) {
      setState(() {
        _error = 'Meeting date and time must be in the future';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final service = ZoomMeetingService();
      final startTime =
          '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';

      ScheduledMeeting meeting;

      if (_isEditing) {
        meeting = await service.updateMeeting(
          meeting: widget.existingMeeting!,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          meetingDate: _selectedDate,
          startTime: startTime,
          durationMinutes: _selectedDuration,
        );
      } else {
        meeting = await service.createMeeting(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          meetingDate: _selectedDate,
          startTime: startTime,
          durationMinutes: _selectedDuration,
          committeeId: widget.committeeId,
          committeeName: widget.committeeName,
          createdBy: widget.createdBy,
        );
      }

      if (mounted) {
        Navigator.of(context).pop(meeting);
      }
    } on ZoomMeetingException catch (e) {
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
