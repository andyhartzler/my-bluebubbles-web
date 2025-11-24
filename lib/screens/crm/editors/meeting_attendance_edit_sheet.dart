import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:bluebubbles/models/crm/meeting.dart';
import 'package:bluebubbles/services/crm/meeting_repository.dart';

import 'member_search_sheet.dart';

enum _AttendanceFieldType { text, multiline, integer, dateTime, bool }

class MeetingAttendanceEditSheet extends StatefulWidget {
  final MeetingAttendance attendance;

  const MeetingAttendanceEditSheet({super.key, required this.attendance});

  @override
  State<MeetingAttendanceEditSheet> createState() => _MeetingAttendanceEditSheetState();
}

class _MeetingAttendanceEditSheetState extends State<MeetingAttendanceEditSheet> {
  final MeetingRepository _meetingRepository = MeetingRepository();
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  bool? _isHost;
  bool _saving = false;
  late final Map<String, dynamic> _originalData;
  late final Map<String, _AttendanceFieldType> _fieldTypes;
  final DateFormat _timeFormat = DateFormat('h:mma');
  late final DateTime _meetingStart;
  DateTime? _firstJoinTime;
  DateTime? _lastLeaveTime;
  int? _totalDurationMinutes;

  static const Map<String, _AttendanceFieldType> _meetingFieldTypes = {
    'member_id': _AttendanceFieldType.text,
    'total_duration_minutes': _AttendanceFieldType.integer,
    'number_of_joins': _AttendanceFieldType.integer,
    'first_join_time': _AttendanceFieldType.dateTime,
    'last_leave_time': _AttendanceFieldType.dateTime,
    'zoom_display_name': _AttendanceFieldType.text,
    'zoom_email': _AttendanceFieldType.text,
    'matched_by': _AttendanceFieldType.text,
    'notes': _AttendanceFieldType.multiline,
    'is_host': _AttendanceFieldType.bool,
  };

  static const Map<String, _AttendanceFieldType> _eventFieldTypes = {
    'member_id': _AttendanceFieldType.text,
    'guest_name': _AttendanceFieldType.text,
    'guest_email': _AttendanceFieldType.text,
    'guest_phone': _AttendanceFieldType.text,
    'rsvp_status': _AttendanceFieldType.text,
    'guest_count': _AttendanceFieldType.integer,
    'notes': _AttendanceFieldType.multiline,
    'checked_in': _AttendanceFieldType.bool,
  };

  @override
  void initState() {
    super.initState();
    _fieldTypes = _isEventAttendance
        ? Map<String, _AttendanceFieldType>.from(_eventFieldTypes)
        : Map<String, _AttendanceFieldType>.from(_meetingFieldTypes);
    _originalData = widget.attendance.toJson(includeMeeting: false, includeMember: false);
    _isHost = _fieldTypes.containsKey('is_host')
        ? widget.attendance.isHost
        : widget.attendance.checkedIn;
    _meetingStart = widget.attendance.meetingDate ??
        widget.attendance.meeting?.meetingDate ??
        DateTime.now();
    _firstJoinTime = widget.attendance.firstJoinTime;
    _lastLeaveTime = widget.attendance.lastLeaveTime;
    _totalDurationMinutes = widget.attendance.totalDurationMinutes;

    void assignController(String key, String? value) {
      _controllers[key] = TextEditingController(text: value ?? '');
    }

    if (_fieldTypes.containsKey('member_id')) {
      assignController('member_id', widget.attendance.memberId);
    }
    if (_fieldTypes.containsKey('guest_name')) {
      assignController('guest_name', widget.attendance.guestName ?? widget.attendance.zoomDisplayName);
    }
    if (_fieldTypes.containsKey('guest_email')) {
      assignController('guest_email', widget.attendance.guestEmail ?? widget.attendance.zoomEmail);
    }
    if (_fieldTypes.containsKey('guest_phone')) {
      assignController('guest_phone', widget.attendance.guestPhone);
    }
    if (_fieldTypes.containsKey('rsvp_status')) {
      assignController('rsvp_status', widget.attendance.rsvpStatus ?? 'attending');
    }
    if (_fieldTypes.containsKey('guest_count')) {
      assignController('guest_count', widget.attendance.guestCount?.toString());
    }
    if (_fieldTypes.containsKey('notes')) {
      assignController('notes', widget.attendance.notes);
    }
    if (_fieldTypes.containsKey('total_duration_minutes')) {
      assignController('total_duration_minutes', _totalDurationMinutes?.toString());
    }
    if (_fieldTypes.containsKey('number_of_joins')) {
      assignController('number_of_joins', widget.attendance.numberOfJoins?.toString());
    }
    if (_fieldTypes.containsKey('first_join_time')) {
      assignController('first_join_time', _formatTime(_firstJoinTime ?? _meetingStart));
    }
    if (_fieldTypes.containsKey('last_leave_time')) {
      assignController('last_leave_time', _formatTime(_lastLeaveTime));
    }
    if (_fieldTypes.containsKey('zoom_display_name')) {
      assignController('zoom_display_name', widget.attendance.zoomDisplayName);
    }
    if (_fieldTypes.containsKey('zoom_email')) {
      assignController('zoom_email', widget.attendance.zoomEmail);
    }
    if (_fieldTypes.containsKey('matched_by')) {
      assignController('matched_by', widget.attendance.matchedBy);
    }

    _syncTimesFromDurationIfPossible();
    _syncDurationFromTimes();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _formatTime(DateTime? value) {
    if (value == null) return '';
    return _timeFormat.format(value.toLocal());
  }

  Future<void> _pickTime(String key) async {
    final currentValue = key == 'first_join_time' ? _firstJoinTime : _lastLeaveTime;
    final base = currentValue ?? _meetingStart;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );

    if (picked == null) return;

    final updated = DateTime(base.year, base.month, base.day, picked.hour, picked.minute);
    setState(() {
      if (key == 'first_join_time') {
        _firstJoinTime = updated;
        _controllers[key]?.text = _formatTime(_firstJoinTime);
        _syncTimesFromDurationIfPossible();
        _syncDurationFromTimes();
      } else {
        _lastLeaveTime = updated;
        _controllers[key]?.text = _formatTime(_lastLeaveTime);
        _syncDurationFromTimes();
      }
    });
  }

  void _syncDurationFromTimes() {
    if (_firstJoinTime != null && _lastLeaveTime != null) {
      final minutes = _lastLeaveTime!.difference(_firstJoinTime!).inMinutes;
      _totalDurationMinutes = minutes >= 0 ? minutes : 0;
      final durationController = _controllers['total_duration_minutes'];
      if (durationController != null) {
        durationController.text = _totalDurationMinutes.toString();
      }
    }
  }

  void _syncTimesFromDurationIfPossible() {
    if (_totalDurationMinutes == null) return;
    _firstJoinTime ??= _meetingStart;
    _lastLeaveTime = _firstJoinTime!.add(Duration(minutes: _totalDurationMinutes!));
    _controllers['first_join_time']?.text = _formatTime(_firstJoinTime);
    _controllers['last_leave_time']?.text = _formatTime(_lastLeaveTime);
  }

  void _syncTimesFromDuration() {
    final durationText = _controllers['total_duration_minutes']?.text.trim();
    final parsed = int.tryParse(durationText ?? '');
    _totalDurationMinutes = parsed;
    if (parsed == null) return;
    _firstJoinTime ??= _meetingStart;
    _lastLeaveTime = _firstJoinTime!.add(Duration(minutes: parsed));
    _controllers['first_join_time']?.text = _formatTime(_firstJoinTime);
    _controllers['last_leave_time']?.text = _formatTime(_lastLeaveTime);
  }

  @override
  Widget build(BuildContext context) {
    final memberName = widget.attendance.member?.name;
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.9,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.person_search),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Edit Attendance',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: _saving ? null : () => Navigator.of(context).pop(),
                    )
                  ],
                ),
              ),
              if (memberName != null && memberName.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Linked Member: $memberName',
                        style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.green[700])),
                  ),
                ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  child: Column(
                    children: _fieldTypes.entries
                        .map((entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: _buildField(entry.key, entry.value),
                            ))
                        .toList(),
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _saving ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _saving ? null : _submit,
                      icon: _saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.save),
                      label: Text(_saving ? 'Saving...' : 'Save Changes'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(String key, _AttendanceFieldType type) {
    TextEditingController ensureController() =>
        _controllers.putIfAbsent(key, () => TextEditingController());

    switch (type) {
      case _AttendanceFieldType.bool:
        return DropdownButtonFormField<bool?>(
          value: _isHost,
          decoration: InputDecoration(
            labelText: _labelFor(key),
            border: const OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem<bool?>(value: null, child: Text('Unset')),
            DropdownMenuItem<bool?>(value: true, child: Text('Yes')),
            DropdownMenuItem<bool?>(value: false, child: Text('No')),
          ],
          onChanged: (value) => setState(() => _isHost = value),
        );
      case _AttendanceFieldType.integer:
        final controller = ensureController();
        return TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: _labelFor(key),
            border: const OutlineInputBorder(),
          ),
          validator: (value) {
            final text = value?.trim() ?? '';
            if (text.isEmpty) return null;
            if (int.tryParse(text) == null) {
              return 'Enter a valid number';
            }
            return null;
          },
          onChanged: key == 'total_duration_minutes' ? (_) => _syncTimesFromDuration() : null,
        );
      case _AttendanceFieldType.dateTime:
        final controller = ensureController();
        return TextFormField(
          controller: controller,
          readOnly: true,
          decoration: InputDecoration(
            labelText: _labelFor(key),
            border: const OutlineInputBorder(),
            suffixIcon: const Icon(Icons.access_time),
          ),
          onTap: () => _pickTime(key),
        );
      case _AttendanceFieldType.multiline:
        final controller = ensureController();
        return TextFormField(
          controller: controller,
          minLines: 3,
          maxLines: 5,
          decoration: InputDecoration(
            labelText: _labelFor(key),
            border: const OutlineInputBorder(),
          ),
        );
      case _AttendanceFieldType.text:
      default:
        final controller = ensureController();
        final isMemberField = key == 'member_id';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: controller,
              decoration: InputDecoration(
                labelText: _labelFor(key),
                border: const OutlineInputBorder(),
              ),
            ),
            if (isMemberField)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.search),
                  label: const Text('Find Member'),
                  onPressed: _saving
                      ? null
                      : () async {
                          final member = await showMemberSearchSheet(context);
                          if (member != null) {
                            setState(() {
                              controller.text = member.id;
                            });
                          }
                        },
                ),
              ),
          ],
        );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final updates = <String, dynamic>{};

    void compare(String key, dynamic newValue) {
      final originalValue = _originalData[key];
      if (originalValue == null && (newValue == null || (newValue is String && newValue.trim().isEmpty))) {
        return;
      }
      if (newValue is String && newValue.trim().isEmpty) {
        if (originalValue != null && originalValue.toString().isNotEmpty) {
          updates[key] = null;
        }
      } else if (newValue != originalValue) {
        updates[key] = newValue;
      }
    }

    if (_totalDurationMinutes != null && _firstJoinTime == null) {
      _firstJoinTime = _meetingStart;
    }
    if (_totalDurationMinutes != null && _firstJoinTime != null && _lastLeaveTime == null) {
      _lastLeaveTime = _firstJoinTime!.add(Duration(minutes: _totalDurationMinutes!));
    }

    for (final entry in _fieldTypes.entries) {
      final key = entry.key;
      switch (entry.value) {
        case _AttendanceFieldType.bool:
          compare(key, _isHost);
          break;
        case _AttendanceFieldType.integer:
          final text = _controllers[key]!.text.trim();
          if (text.isEmpty) {
            compare(key, null);
          } else {
            final parsed = int.tryParse(text);
            if (key == 'total_duration_minutes') {
              _totalDurationMinutes = parsed;
            }
            if (parsed != null) compare(key, parsed);
          }
          break;
        case _AttendanceFieldType.dateTime:
          final value = key == 'first_join_time' ? _firstJoinTime : _lastLeaveTime;
          compare(key, value?.toUtc().toIso8601String());
          break;
        case _AttendanceFieldType.multiline:
        case _AttendanceFieldType.text:
          compare(key, _controllers[key]!.text.trim());
          break;
      }
    }

    if (updates.isEmpty) {
      if (mounted) {
        Navigator.of(context).pop(widget.attendance);
      }
      return;
    }

    setState(() => _saving = true);

    try {
      final updated = await _meetingRepository.updateAttendance(widget.attendance.id, updates);
      if (!mounted) return;
      Navigator.of(context).pop(updated ?? widget.attendance);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update attendance: $e')),
      );
    }
  }

  String _labelFor(String key) {
    switch (key) {
      case 'member_id':
        return 'Member ID';
      case 'guest_name':
        return 'Name';
      case 'guest_email':
        return 'Email';
      case 'guest_phone':
        return 'Phone';
      case 'rsvp_status':
        return 'RSVP Status';
      case 'guest_count':
        return 'Guest Count';
      case 'notes':
        return 'Notes';
      case 'checked_in':
        return 'Checked In';
      case 'total_duration_minutes':
        return 'Total Duration (min)';
      case 'number_of_joins':
        return 'Number of Joins';
      case 'first_join_time':
        return 'First Join Time';
      case 'last_leave_time':
        return 'Last Leave Time';
      case 'zoom_display_name':
        return 'Zoom Display Name';
      case 'zoom_email':
        return 'Zoom Email';
      case 'matched_by':
        return 'Matched By';
      case 'is_host':
        return 'Is Host';
      default:
        return key;
    }
  }

  bool get _isEventAttendance =>
      widget.attendance.rsvpStatus != null ||
      widget.attendance.guestName != null ||
      widget.attendance.guestEmail != null ||
      widget.attendance.checkedIn != null;
}
