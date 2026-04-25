import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bluebubbles/models/crm/assignment.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/services/crm/assignments_service.dart';
import 'package:bluebubbles/services/crm/member_repository.dart';

/// Modal for creating a new explicit assignment, or editing an existing one.
/// Returns the created/updated `Assignment` on save, or `null` on cancel.
///
/// Pre-fillable from any source (candidate detail, bill detail, etc.) by
/// passing `prefillEntityType` / `prefillEntityId` / `prefillEntityUrl`.
class AssignmentCreateDialog extends StatefulWidget {
  final String currentAuthUserId;
  final Assignment? existing;
  final String? prefillTitle;
  final String? prefillEntityType;
  final String? prefillEntityId;
  final String? prefillEntityUrl;

  const AssignmentCreateDialog({
    super.key,
    required this.currentAuthUserId,
    this.existing,
    this.prefillTitle,
    this.prefillEntityType,
    this.prefillEntityId,
    this.prefillEntityUrl,
  });

  @override
  State<AssignmentCreateDialog> createState() => _AssignmentCreateDialogState();
}

class _AssignmentCreateDialogState extends State<AssignmentCreateDialog> {
  final _service = AssignmentsService();
  final _memberRepo = MemberRepository();

  late final TextEditingController _title;
  late final TextEditingController _note;
  String _priority = 'medium';
  DateTime? _dueDate;

  Member? _selectedAssignee;
  List<Member> _assigneeCandidates = const [];
  bool _searching = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? widget.prefillTitle ?? '');
    _note = TextEditingController(text: e?.note ?? '');
    _priority = e?.priority ?? 'medium';
    _dueDate = e?.dueDate;
    _loadStaffCandidates();
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _loadStaffCandidates() async {
    // Edit mode hides the dropdown — no need to load the staff list.
    if (widget.existing != null) {
      setState(() => _searching = false);
      return;
    }
    setState(() => _searching = true);
    try {
      final result = await _memberRepo.getAllMembers(fetchAll: true);
      final staff = result.members.where((m) =>
          m.executiveCommittee == true ||
          (m.committee != null && m.committee!.isNotEmpty));
      setState(() {
        _assigneeCandidates = staff.toList()..sort((a, b) => a.name.compareTo(b.name));
      });
    } catch (e) {
      setState(() => _error = 'Failed to load staff: $e');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _save() async {
    final isEdit = widget.existing != null;
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Title is required');
      return;
    }
    // Edit mode keeps the existing assignee — re-assignment is not
    // supported in v1 (the dropdown is hidden in edit mode). Create
    // mode requires a selection from the dropdown.
    if (!isEdit && _selectedAssignee == null) {
      setState(() => _error = 'Pick an assignee');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    Assignment? result;
    if (isEdit) {
      final updated = widget.existing!.copyWith(
        title: title,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        priority: _priority,
        dueDate: _dueDate,
      );
      final ok = await _service.update(updated);
      if (!ok) {
        setState(() {
          _saving = false;
          _error = 'Update failed';
        });
        return;
      }
      result = updated;
    } else {
      // Resolve the assignee's auth user id by querying members.user_id
      final assigneeAuthId = await _resolveAuthUserId(_selectedAssignee!);
      if (assigneeAuthId == null) {
        setState(() {
          _saving = false;
          _error = 'Selected member does not have a linked auth account yet';
        });
        return;
      }
      result = await _service.create(
        assignedTo: assigneeAuthId,
        assignedBy: widget.currentAuthUserId,
        title: title,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        priority: _priority,
        dueDate: _dueDate,
        entityType: widget.prefillEntityType,
        entityId: widget.prefillEntityId,
        entityUrl: widget.prefillEntityUrl,
      );
      if (result == null) {
        setState(() {
          _saving = false;
          _error = 'Create failed';
        });
        return;
      }
    }

    if (mounted) Navigator.of(context).pop(result);
  }

  Future<String?> _resolveAuthUserId(Member m) async {
    // Members store `user_id` (auth.users.id) on the row. The Member model
    // doesn't currently expose it as a typed field, so fetch it directly.
    try {
      final row = await Supabase.instance.client
          .from('members')
          .select('user_id')
          .eq('id', m.id)
          .maybeSingle();
      final id = row?['user_id'];
      return id is String && id.isNotEmpty ? id : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? 'Edit assignment' : 'Create assignment'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isEdit) ...[
                _searching
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: LinearProgressIndicator(),
                      )
                    : DropdownButtonFormField<Member>(
                        decoration: const InputDecoration(
                          labelText: 'Assign to',
                          border: OutlineInputBorder(),
                        ),
                        value: _selectedAssignee,
                        items: _assigneeCandidates
                            .map((m) => DropdownMenuItem(
                                  value: m,
                                  child: Text(m.name),
                                ))
                            .toList(),
                        onChanged: (m) => setState(() => _selectedAssignee = m),
                      ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Priority',
                        border: OutlineInputBorder(),
                      ),
                      value: _priority,
                      items: const [
                        DropdownMenuItem(value: 'low', child: Text('Low')),
                        DropdownMenuItem(value: 'medium', child: Text('Medium')),
                        DropdownMenuItem(value: 'high', child: Text('High')),
                      ],
                      onChanged: (v) => setState(() => _priority = v ?? 'medium'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _dueDate ?? DateTime.now(),
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                        );
                        if (picked != null) setState(() => _dueDate = picked);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Due date (optional)',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(_dueDate == null
                            ? 'Pick a date'
                            : '${_dueDate!.year}-${_dueDate!.month.toString().padLeft(2, '0')}-${_dueDate!.day.toString().padLeft(2, '0')}'),
                      ),
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(isEdit ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}
