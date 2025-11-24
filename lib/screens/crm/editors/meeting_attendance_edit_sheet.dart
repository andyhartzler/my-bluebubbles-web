import 'package:flutter/material.dart';

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

  static final Map<String, _AttendanceFieldType> _fieldTypes = {
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
    _originalData = widget.attendance.toJson(includeMeeting: false, includeMember: false);
    _isHost = widget.attendance.isHost;
    _controllers['member_id'] = TextEditingController(text: widget.attendance.memberId ?? '');
    _controllers['guest_name'] = TextEditingController(text: widget.attendance.guestName ?? widget.attendance.zoomDisplayName ?? '');
    _controllers['guest_email'] = TextEditingController(text: widget.attendance.guestEmail ?? widget.attendance.zoomEmail ?? '');
    _controllers['guest_phone'] = TextEditingController(text: widget.attendance.guestPhone ?? '');
    _controllers['rsvp_status'] = TextEditingController(text: widget.attendance.rsvpStatus ?? 'attending');
    _controllers['guest_count'] = TextEditingController(
      text: widget.attendance.guestCount?.toString() ?? '',
    );
    _controllers['notes'] = TextEditingController(text: widget.attendance.notes ?? '');
    _isHost = widget.attendance.checkedIn;
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final memberName = widget.attendance.member?.name;
    return Form(
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
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.green[700])),
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
    );
  }

  Widget _buildField(String key, _AttendanceFieldType type) {
    final controller = _controllers[key]!;
    switch (type) {
      case _AttendanceFieldType.bool:
        return DropdownButtonFormField<bool?>(
          value: _isHost,
          decoration: const InputDecoration(
            labelText: 'Checked In',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem<bool?>(value: null, child: Text('Unset')),
            DropdownMenuItem<bool?>(value: true, child: Text('Yes')),
            DropdownMenuItem<bool?>(value: false, child: Text('No')),
          ],
          onChanged: (value) => setState(() => _isHost = value),
        );
      case _AttendanceFieldType.integer:
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
        );
      case _AttendanceFieldType.dateTime:
        return TextFormField(
          controller: controller,
          decoration: InputDecoration(
            labelText: _labelFor(key),
            helperText: 'ISO timestamp',
            border: const OutlineInputBorder(),
          ),
          validator: (value) {
            final text = value?.trim() ?? '';
            if (text.isEmpty) return null;
            if (DateTime.tryParse(text) == null) {
              return 'Enter a valid ISO timestamp';
            }
            return null;
          },
        );
      case _AttendanceFieldType.multiline:
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
            if (parsed != null) compare(key, parsed);
          }
          break;
        case _AttendanceFieldType.dateTime:
          final text = _controllers[key]!.text.trim();
          if (text.isEmpty) {
            compare(key, null);
          } else {
            compare(key, text);
          }
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
      default:
        return key;
    }
  }
}
