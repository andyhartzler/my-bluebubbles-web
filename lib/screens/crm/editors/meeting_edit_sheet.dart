import 'package:flutter/material.dart';

import 'package:bluebubbles/models/crm/meeting.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/screens/crm/editors/member_search_sheet.dart';
import 'package:bluebubbles/services/crm/meeting_repository.dart';
import 'package:bluebubbles/services/crm/member_repository.dart';

enum _MeetingFieldType { text, multiline, integer, dateTime }

class _MeetingFieldDefinition {
  final String key;
  final String label;
  final _MeetingFieldType type;
  final String? helper;

  const _MeetingFieldDefinition(this.key, this.label, this.type, {this.helper});
}

class MeetingEditSheet extends StatefulWidget {
  final Meeting meeting;

  const MeetingEditSheet({super.key, required this.meeting});

  @override
  State<MeetingEditSheet> createState() => _MeetingEditSheetState();
}

class _MeetingEditSheetState extends State<MeetingEditSheet> {
  final MeetingRepository _meetingRepository = MeetingRepository();
  final MemberRepository _memberRepository = MemberRepository();
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, Member?> _selectedMembers = {};
  late final Map<String, dynamic> _originalData;
  bool _saving = false;

  static final List<_MeetingFieldDefinition> _fields = [
    _MeetingFieldDefinition('meeting_title', 'Meeting Title', _MeetingFieldType.text),
    _MeetingFieldDefinition('meeting_date', 'Meeting Date', _MeetingFieldType.dateTime,
        helper: 'ISO string, e.g. 2024-05-14T18:00:00Z'),
    _MeetingFieldDefinition('zoom_meeting_id', 'Zoom Meeting ID', _MeetingFieldType.text),
    _MeetingFieldDefinition('meeting_host', 'Host Member ID', _MeetingFieldType.text,
        helper: 'UUID of meeting host'),
    _MeetingFieldDefinition('duration_minutes', 'Duration (minutes)', _MeetingFieldType.integer),
    _MeetingFieldDefinition('attendance_count', 'Attendance Count', _MeetingFieldType.integer),
    _MeetingFieldDefinition('processing_status', 'Processing Status', _MeetingFieldType.text),
    _MeetingFieldDefinition('processing_error', 'Processing Error', _MeetingFieldType.multiline),
    _MeetingFieldDefinition('recording_url', 'Recording URL', _MeetingFieldType.text),
    _MeetingFieldDefinition('recording_embed_url', 'Recording Embed URL', _MeetingFieldType.text),
    _MeetingFieldDefinition('transcript_file_path', 'Transcript File Path', _MeetingFieldType.text),
    _MeetingFieldDefinition('executive_recap', 'Executive Recap', _MeetingFieldType.multiline),
    _MeetingFieldDefinition('agenda_reviewed', 'Agenda Reviewed', _MeetingFieldType.multiline),
    _MeetingFieldDefinition('discussion_highlights', 'Discussion Highlights', _MeetingFieldType.multiline),
    _MeetingFieldDefinition('decisions_rationales', 'Decisions & Rationales', _MeetingFieldType.multiline),
    _MeetingFieldDefinition('risks_open_questions', 'Risks & Open Questions', _MeetingFieldType.multiline),
    _MeetingFieldDefinition('action_items', 'Action Items', _MeetingFieldType.multiline),
  ];

  @override
  void initState() {
    super.initState();
    _originalData = widget.meeting.toJson(includeAttendance: false);
    for (final field in _fields) {
      final value = _originalData[field.key];
      String initial = '';
      if (value != null) {
        if (field.type == _MeetingFieldType.dateTime) {
          initial = value.toString();
        } else {
          initial = value.toString();
        }
      }
      _controllers[field.key] = TextEditingController(text: initial);
    }

    final hostId = _controllers['meeting_host']?.text.trim();
    if (hostId != null && hostId.isNotEmpty) {
      _selectedMembers['meeting_host'] = null;
      _prefetchHostMember(hostId);
    }
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
    return SafeArea(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.event_note),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Edit Meeting',
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
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                child: Column(
                  children: _fields
                      .map((field) => Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: _buildField(field),
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
    );
  }

  Widget _buildField(_MeetingFieldDefinition field) {
    if (field.key == 'meeting_host') {
      return _buildMeetingHostSelector(field);
    }

    final controller = _controllers[field.key]!;
    switch (field.type) {
      case _MeetingFieldType.multiline:
        return TextFormField(
          controller: controller,
          minLines: 3,
          maxLines: 5,
          decoration: InputDecoration(
            labelText: field.label,
            helperText: field.helper,
            border: const OutlineInputBorder(),
          ),
        );
      case _MeetingFieldType.integer:
        return TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: field.label,
            helperText: field.helper,
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
      case _MeetingFieldType.dateTime:
        return TextFormField(
          controller: controller,
          decoration: InputDecoration(
            labelText: field.label,
            helperText: field.helper,
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
      case _MeetingFieldType.text:
      default:
        return TextFormField(
          controller: controller,
          decoration: InputDecoration(
            labelText: field.label,
            helperText: field.helper,
            border: const OutlineInputBorder(),
          ),
        );
    }
  }

  Widget _buildMeetingHostSelector(_MeetingFieldDefinition field) {
    final controller = _controllers[field.key]!;
    final Member? selectedMember = _selectedMembers[field.key];
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final subtleColor = colorScheme.onSurface.withOpacity(0.6);
    final idText = controller.text.trim();

    return InputDecorator(
      decoration: InputDecoration(
        labelText: field.label,
        helperText: field.helper ?? 'Select a member to host this meeting.',
        border: const OutlineInputBorder(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (selectedMember != null) ...[
            Text(
              selectedMember.name,
              style: theme.textTheme.titleMedium,
            ),
            if ((selectedMember.phoneE164 ?? selectedMember.phone)?.isNotEmpty ?? false)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  selectedMember.phoneE164 ?? selectedMember.phone!,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'ID: ${selectedMember.id}',
                style: theme.textTheme.bodySmall?.copyWith(color: subtleColor),
              ),
            ),
          ] else if (idText.isNotEmpty) ...[
            Text(
              'Current ID: $idText',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Select a member to see their details.',
              style: theme.textTheme.bodySmall?.copyWith(color: subtleColor),
            ),
          ] else
            Text(
              'No host selected',
              style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.person_search),
                label: const Text('Choose Member'),
                onPressed: _saving
                    ? null
                    : () async {
                        final member = await showMemberSearchSheet(context);
                        if (member == null) return;
                        setState(() {
                          _selectedMembers[field.key] = member;
                          controller.text = member.id;
                        });
                      },
              ),
              TextButton(
                onPressed: _saving
                    ? null
                    : () async {
                        final manualId = await _promptForManualHostId(controller.text.trim());
                        if (manualId == null) return;
                        setState(() {
                          _selectedMembers[field.key] = null;
                          controller.text = manualId;
                        });
                      },
                child: const Text('Enter ID Manually'),
              ),
              if (selectedMember != null || idText.isNotEmpty)
                TextButton(
                  onPressed: _saving
                      ? null
                      : () {
                          setState(() {
                            _selectedMembers[field.key] = null;
                            controller.text = '';
                          });
                        },
                  child: const Text('Clear'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _prefetchHostMember(String id) async {
    final member = await _memberRepository.getMemberById(id);
    if (!mounted || member == null) return;
    setState(() {
      _selectedMembers['meeting_host'] = member;
    });
  }

  Future<String?> _promptForManualHostId(String initialValue) async {
    final textController = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Host Member ID'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Member ID',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(textController.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    textController.dispose();
    final trimmed = result?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final updates = <String, dynamic>{};

    for (final field in _fields) {
      final controller = _controllers[field.key]!;
      final text = controller.text.trim();
      final original = _originalData[field.key];

      if (field.key == 'meeting_host') {
        final selectedMember = _selectedMembers[field.key];
        final newValue = selectedMember?.id ?? text;
        final originalValue = original?.toString();

        if ((newValue.isEmpty) && (originalValue == null || originalValue.isEmpty)) {
          continue;
        }

        if (newValue.isEmpty && originalValue != null && originalValue.isNotEmpty) {
          updates[field.key] = null;
        } else if (newValue != originalValue) {
          updates[field.key] = newValue;
        }
        continue;
      }

      switch (field.type) {
        case _MeetingFieldType.integer:
          if (text.isEmpty) {
            if (original != null) updates[field.key] = null;
          } else {
            final value = int.tryParse(text);
            if (value != null && value != original) {
              updates[field.key] = value;
            }
          }
          break;
        case _MeetingFieldType.dateTime:
          if (text.isEmpty) {
            if (original != null) updates[field.key] = null;
          } else if (text != original) {
            updates[field.key] = text;
          }
          break;
        case _MeetingFieldType.multiline:
        case _MeetingFieldType.text:
          if (text.isEmpty && (original == null || original.toString().isEmpty)) {
            continue;
          }
          if (text.isEmpty && original != null && original.toString().isNotEmpty) {
            updates[field.key] = null;
          } else if (text != original) {
            updates[field.key] = text;
          }
          break;
      }
    }

    if (updates.isEmpty) {
      if (mounted) {
        Navigator.of(context).pop(widget.meeting);
      }
      return;
    }

    setState(() => _saving = true);

    try {
      final updated = await _meetingRepository.updateMeeting(widget.meeting.id, updates);
      if (!mounted) return;
      Navigator.of(context).pop(updated ?? widget.meeting);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update meeting: $e')),
      );
    }
  }
}
