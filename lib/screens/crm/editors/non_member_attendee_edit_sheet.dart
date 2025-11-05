import 'package:flutter/material.dart';

import 'package:bluebubbles/models/crm/meeting.dart';
import 'package:bluebubbles/services/crm/meeting_repository.dart';

import 'member_search_sheet.dart';

class NonMemberEditResult {
  final NonMemberAttendee? attendee;
  final MeetingAttendance? convertedAttendance;
  final bool removed;

  const NonMemberEditResult({this.attendee, this.convertedAttendance, this.removed = false});
}

class NonMemberAttendeeEditSheet extends StatefulWidget {
  final Meeting meeting;
  final NonMemberAttendee attendee;

  const NonMemberAttendeeEditSheet({super.key, required this.meeting, required this.attendee});

  @override
  State<NonMemberAttendeeEditSheet> createState() => _NonMemberAttendeeEditSheetState();
}

class _NonMemberAttendeeEditSheetState extends State<NonMemberAttendeeEditSheet> {
  final MeetingRepository _repository = MeetingRepository();
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  bool _saving = false;

  static const Map<String, String> _fieldLabels = {
    'display_name': 'Display Name',
    'email': 'Email',
    'phone_number': 'Phone Number',
    'pronouns': 'Pronouns',
    'total_duration_minutes': 'Total Duration (minutes)',
    'number_of_joins': 'Number of Joins',
    'first_join_time': 'First Join Time (ISO)',
    'last_leave_time': 'Last Leave Time (ISO)',
  };

  @override
  void initState() {
    super.initState();
    _controllers['display_name'] = TextEditingController(text: widget.attendee.displayName);
    _controllers['email'] = TextEditingController(text: widget.attendee.email ?? '');
    _controllers['phone_number'] = TextEditingController(text: widget.attendee.phoneNumber ?? '');
    _controllers['pronouns'] = TextEditingController(text: widget.attendee.pronouns ?? '');
    _controllers['total_duration_minutes'] =
        TextEditingController(text: widget.attendee.totalDurationMinutes?.toString() ?? '');
    _controllers['number_of_joins'] =
        TextEditingController(text: widget.attendee.numberOfJoins?.toString() ?? '');
    _controllers['first_join_time'] =
        TextEditingController(text: widget.attendee.firstJoinTime?.toIso8601String() ?? '');
    _controllers['last_leave_time'] =
        TextEditingController(text: widget.attendee.lastLeaveTime?.toIso8601String() ?? '');
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
    final attendee = widget.attendee;
    return SafeArea(
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.person_outline),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Guest Participant',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                child: Column(
                  children: [
                    ..._fieldLabels.entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: _buildField(entry.key, entry.value),
                      ),
                    ),
                    Card(
                      margin: const EdgeInsets.only(top: 4),
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                      child: ListTile(
                        leading: const Icon(Icons.link_outlined),
                        title: const Text('Link to Member Profile'),
                        subtitle: const Text('Convert this guest into a tracked member attendee.'),
                        onTap: _saving ? null : _linkToMember,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: _saving ? null : _delete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remove'),
                    style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.save_alt),
                    label: Text(_saving ? 'Saving...' : 'Save Changes'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String key, String label) {
    final controller = _controllers[key]!;
    final isNumber = key.contains('duration') || key.contains('number_of_joins');
    final isTimestamp = key.contains('_time');
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      validator: (value) {
        final text = value?.trim() ?? '';
        if (key == 'display_name' && text.isEmpty) {
          return 'Display name is required';
        }
        if (text.isEmpty) return null;
        if (isNumber && int.tryParse(text) == null) {
          return 'Enter a valid number';
        }
        if (isTimestamp && DateTime.tryParse(text) == null) {
          return 'Enter a valid ISO timestamp';
        }
        return null;
      },
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final updates = <String, dynamic>{};
    void compare(String key, String? newValue) {
      final trimmed = newValue?.trim();
      final original = _originalValueFor(key);
      if ((trimmed == null || trimmed.isEmpty) && original == null) return;
      if (trimmed == null || trimmed.isEmpty) {
        if (original != null) updates[key] = null;
        return;
      }
      if (trimmed != original) {
        updates[key] = key.contains('duration') || key.contains('number_of_joins')
            ? int.tryParse(trimmed) ?? trimmed
            : trimmed;
      }
    }

    for (final key in _fieldLabels.keys) {
      compare(key, _controllers[key]?.text);
    }

    if (updates.isEmpty) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    setState(() => _saving = true);

    try {
      final updated = await _repository.updateNonMemberAttendee(widget.attendee.id, updates);
      if (!mounted) return;
      Navigator.of(context).pop(NonMemberEditResult(attendee: updated ?? widget.attendee));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update attendee: $e')),
      );
    }
  }

  Future<void> _delete() async {
    setState(() => _saving = true);
    try {
      await _repository.deleteNonMemberAttendee(widget.attendee.id);
      if (!mounted) return;
      Navigator.of(context).pop(const NonMemberEditResult(removed: true));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove attendee: $e')),
      );
    }
  }

  Future<void> _linkToMember() async {
    final meeting = widget.meeting;
    final attendee = widget.attendee;
    final selected = await showMemberSearchSheet(context);
    if (selected == null) return;

    setState(() => _saving = true);

    try {
      final attendance = await _repository.convertNonMemberToAttendance(
        attendeeId: attendee.id,
        meetingId: meeting.id,
        memberId: selected.id,
      );
      if (!mounted) return;
      Navigator.of(context).pop(NonMemberEditResult(convertedAttendance: attendance));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to link attendee: $e')),
      );
    }
  }

  String? _originalValueFor(String key) {
    switch (key) {
      case 'display_name':
        return widget.attendee.displayName;
      case 'email':
        return widget.attendee.email;
      case 'phone_number':
        return widget.attendee.phoneNumber;
      case 'pronouns':
        return widget.attendee.pronouns;
      case 'total_duration_minutes':
        return widget.attendee.totalDurationMinutes?.toString();
      case 'number_of_joins':
        return widget.attendee.numberOfJoins?.toString();
      case 'first_join_time':
        return widget.attendee.firstJoinTime?.toIso8601String();
      case 'last_leave_time':
        return widget.attendee.lastLeaveTime?.toIso8601String();
      default:
        return null;
    }
  }
}
