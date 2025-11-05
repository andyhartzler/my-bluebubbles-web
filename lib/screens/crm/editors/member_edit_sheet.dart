import 'package:flutter/material.dart';

import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/services/crm/member_repository.dart';

enum _FieldType { text, multiline, bool, date, list }

class _FieldDefinition {
  final String key;
  final String label;
  final _FieldType type;
  final String? helper;

  const _FieldDefinition(this.key, this.label, this.type, {this.helper});
}

class _FieldGroup {
  final String title;
  final List<_FieldDefinition> fields;

  const _FieldGroup(this.title, this.fields);
}

class MemberEditSheet extends StatefulWidget {
  final Member member;

  const MemberEditSheet({super.key, required this.member});

  @override
  State<MemberEditSheet> createState() => _MemberEditSheetState();
}

class _MemberEditSheetState extends State<MemberEditSheet> {
  final _formKey = GlobalKey<FormState>();
  final MemberRepository _memberRepository = MemberRepository();

  late final Map<String, dynamic> _originalData;
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, bool?> _boolValues = {};
  bool _saving = false;

  static final List<_FieldGroup> _groups = [
    _FieldGroup('Contact Information', const [
      _FieldDefinition('name', 'Name', _FieldType.text),
      _FieldDefinition('email', 'Email', _FieldType.text),
      _FieldDefinition('phone', 'Phone', _FieldType.text),
      _FieldDefinition('phone_e164', 'Phone (E.164)', _FieldType.text,
          helper: 'Format as +15555555555'),
      _FieldDefinition('address', 'Address', _FieldType.multiline),
      _FieldDefinition('county', 'County', _FieldType.text),
      _FieldDefinition('congressional_district', 'Congressional District', _FieldType.text),
      _FieldDefinition('languages', 'Languages', _FieldType.text),
    ]),
    _FieldGroup('Demographics', const [
      _FieldDefinition('date_of_birth', 'Date of Birth', _FieldType.date,
          helper: 'YYYY-MM-DD'),
      _FieldDefinition('preferred_pronouns', 'Preferred Pronouns', _FieldType.text),
      _FieldDefinition('gender_identity', 'Gender Identity', _FieldType.text),
      _FieldDefinition('race', 'Race', _FieldType.text),
      _FieldDefinition('sexual_orientation', 'Sexual Orientation', _FieldType.text),
      _FieldDefinition('registered_voter', 'Registered Voter', _FieldType.bool),
      _FieldDefinition('hispanic_latino', 'Hispanic / Latino', _FieldType.bool),
      _FieldDefinition('community_type', 'Community Type', _FieldType.text),
      _FieldDefinition('religion', 'Religion', _FieldType.text),
      _FieldDefinition('zodiac_sign', 'Zodiac Sign', _FieldType.text),
    ]),
    _FieldGroup('Education & Work', const [
      _FieldDefinition('in_school', 'In School', _FieldType.text),
      _FieldDefinition('school_name', 'School Name', _FieldType.text),
      _FieldDefinition('high_school', 'High School', _FieldType.text),
      _FieldDefinition('college', 'College', _FieldType.text),
      _FieldDefinition('school_email', 'School Email', _FieldType.text),
      _FieldDefinition('graduation_year', 'Graduation Year', _FieldType.text),
      _FieldDefinition('employed', 'Employed', _FieldType.text),
      _FieldDefinition('industry', 'Industry', _FieldType.text),
    ]),
    _FieldGroup('Chapter Involvement', const [
      _FieldDefinition('current_chapter_member', 'Current Chapter Member', _FieldType.text),
      _FieldDefinition('chapter_name', 'Chapter Name', _FieldType.text),
      _FieldDefinition('chapter_position', 'Chapter Position', _FieldType.text),
      _FieldDefinition('date_elected', 'Date Elected', _FieldType.date,
          helper: 'YYYY-MM-DD'),
      _FieldDefinition('term_expiration', 'Term Expiration', _FieldType.date,
          helper: 'YYYY-MM-DD'),
      _FieldDefinition('committee', 'Committees', _FieldType.list,
          helper: 'Comma separated'),
    ]),
    _FieldGroup('Engagement & Goals', const [
      _FieldDefinition('desire_to_lead', 'Desire to Lead', _FieldType.text),
      _FieldDefinition('hours_per_week', 'Hours Per Week', _FieldType.text),
      _FieldDefinition('leadership_experience', 'Leadership Experience', _FieldType.multiline),
      _FieldDefinition('goals_and_ambitions', 'Goals & Ambitions', _FieldType.multiline),
      _FieldDefinition('qualified_experience', 'Qualified Experience', _FieldType.multiline),
      _FieldDefinition('referral_source', 'Referral Source', _FieldType.text),
      _FieldDefinition('passionate_issues', 'Passionate Issues', _FieldType.multiline),
      _FieldDefinition('why_issues_matter', 'Why Issues Matter', _FieldType.multiline),
      _FieldDefinition('areas_of_interest', 'Areas of Interest', _FieldType.multiline),
      _FieldDefinition('why_join', 'Why Join', _FieldType.multiline),
    ]),
    _FieldGroup('Social', const [
      _FieldDefinition('instagram', 'Instagram', _FieldType.text),
      _FieldDefinition('tiktok', 'TikTok', _FieldType.text),
      _FieldDefinition('x', 'X (Twitter)', _FieldType.text),
    ]),
  ];

  @override
  void initState() {
    super.initState();
    _originalData = widget.member.toJson();
    for (final group in _groups) {
      for (final field in group.fields) {
        final initial = _originalData[field.key];
        switch (field.type) {
          case _FieldType.bool:
            _boolValues[field.key] = initial is bool ? initial : null;
            break;
          case _FieldType.list:
            final listValue = initial is List
                ? initial.whereType<String>().join(', ')
                : (initial is String ? initial : '');
            _controllers[field.key] = TextEditingController(text: listValue);
            break;
          default:
            final textValue = initial?.toString() ?? '';
            _controllers[field.key] = TextEditingController(text: textValue);
        }
      }
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.edit),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Edit Member',
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
                  children: _groups
                      .map((group) => _buildGroup(context, group))
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
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
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

  Widget _buildGroup(BuildContext context, _FieldGroup group) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            group.title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...group.fields.map((field) => Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: _buildField(field),
              )),
        ],
      ),
    );
  }

  Widget _buildField(_FieldDefinition field) {
    switch (field.type) {
      case _FieldType.bool:
        return DropdownButtonFormField<bool?>(
          value: _boolValues[field.key],
          decoration: InputDecoration(
            labelText: field.label,
            helperText: field.helper,
            border: const OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem<bool?>(value: null, child: Text('Unset')),
            DropdownMenuItem<bool?>(value: true, child: Text('Yes')),
            DropdownMenuItem<bool?>(value: false, child: Text('No')),
          ],
          onChanged: (value) => setState(() => _boolValues[field.key] = value),
        );
      case _FieldType.multiline:
        return TextFormField(
          controller: _controllers[field.key],
          minLines: 3,
          maxLines: 5,
          decoration: InputDecoration(
            labelText: field.label,
            helperText: field.helper,
            border: const OutlineInputBorder(),
          ),
        );
      case _FieldType.date:
        return TextFormField(
          controller: _controllers[field.key],
          decoration: InputDecoration(
            labelText: field.label,
            helperText: field.helper ?? 'YYYY-MM-DD',
            border: const OutlineInputBorder(),
          ),
          validator: (value) {
            final text = value?.trim() ?? '';
            if (text.isEmpty) return null;
            if (!_isValidDate(text)) {
              return 'Enter a valid date (YYYY-MM-DD)';
            }
            return null;
          },
        );
      case _FieldType.list:
        return TextFormField(
          controller: _controllers[field.key],
          decoration: InputDecoration(
            labelText: field.label,
            helperText: field.helper ?? 'Comma separated',
            border: const OutlineInputBorder(),
          ),
        );
      case _FieldType.text:
      default:
        return TextFormField(
          controller: _controllers[field.key],
          decoration: InputDecoration(
            labelText: field.label,
            helperText: field.helper,
            border: const OutlineInputBorder(),
          ),
        );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final updates = <String, dynamic>{};

    for (final group in _groups) {
      for (final field in group.fields) {
        dynamic originalValue = _originalData[field.key];
        switch (field.type) {
          case _FieldType.bool:
            final newValue = _boolValues[field.key];
            if (originalValue is! bool?) {
              originalValue = originalValue == null ? null : originalValue == true;
            }
            if (newValue != originalValue) {
              updates[field.key] = newValue;
            }
            break;
          case _FieldType.list:
            final controller = _controllers[field.key]!;
            final list = controller.text
                .split(',')
                .map((value) => value.trim())
                .where((value) => value.isNotEmpty)
                .toList();
            final normalizedOriginal = originalValue is Iterable
                ? originalValue
                    .whereType<dynamic>()
                    .map((value) => value.toString().trim())
                    .where((value) => value.isNotEmpty)
                    .toList()
                : <String>[];
            if (list.isEmpty && normalizedOriginal.isEmpty) {
              continue;
            }
            if (list.isEmpty && normalizedOriginal.isNotEmpty) {
              updates[field.key] = null;
            } else if (!_listEquals(list, List<String>.from(normalizedOriginal))) {
              updates[field.key] = list;
            }
            break;
          case _FieldType.date:
            final controller = _controllers[field.key]!;
            final text = controller.text.trim();
            final originalText = (originalValue?.toString() ?? '').trim();
            if (text.isEmpty && originalText.isEmpty) {
              continue;
            }
            if (text.isEmpty && originalText.isNotEmpty) {
              updates[field.key] = null;
            } else if (text != originalText) {
              updates[field.key] = text;
            }
            break;
          case _FieldType.multiline:
          case _FieldType.text:
            final controller = _controllers[field.key]!;
            final text = controller.text.trim();
            final originalText = (originalValue?.toString() ?? '').trim();
            if (text.isEmpty && originalText.isEmpty) {
              continue;
            }
            if (text.isEmpty && originalText.isNotEmpty) {
              updates[field.key] = null;
            } else if (text != originalText) {
              updates[field.key] = text;
            }
            break;
        }
      }
    }

    if (updates.isEmpty) {
      if (mounted) {
        Navigator.of(context).pop(widget.member);
      }
      return;
    }

    setState(() => _saving = true);

    try {
      final updatedMember = await _memberRepository.updateMemberFields(widget.member.id, updates);
      if (!mounted) return;
      Navigator.of(context).pop(updatedMember ?? widget.member);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update member: $e')),
      );
    }
  }

  bool _isValidDate(String input) {
    if (input.length != 10) return false;
    final year = int.tryParse(input.substring(0, 4));
    final month = int.tryParse(input.substring(5, 7));
    final day = int.tryParse(input.substring(8, 10));
    if (year == null || month == null || day == null) return false;
    final date = DateTime.tryParse(input);
    return date != null;
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
