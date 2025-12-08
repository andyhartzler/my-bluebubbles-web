import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/form_schema.dart';
import '../../models/form_field_config.dart';
import '../../models/form_field_types.dart';
import '../../services/forms_service.dart';
import '../../widgets/field_config_dialog.dart';

class FormBuilderScreen extends StatefulWidget {
  final String? formId; // null for new form

  const FormBuilderScreen({
    Key? key,
    this.formId,
  }) : super(key: key);

  @override
  State<FormBuilderScreen> createState() => _FormBuilderScreenState();
}

class _FormBuilderScreenState extends State<FormBuilderScreen> {
  final _formsService = FormsService();
  final _uuid = const Uuid();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  List<FormFieldConfig> _fields = [];
  String _formType = 'survey';
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.formId != null) {
      _loadForm();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadForm() async {
    setState(() => _isLoading = true);

    try {
      final form = await _formsService.getForm(widget.formId!);

      setState(() {
        _titleController.text = form.title;
        _descriptionController.text = form.description ?? '';
        _formType = form.formType;
        _fields = form.schema.fields;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      // Handle error
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.formId == null ? 'Create Form' : 'Edit Form'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isSaving ? null : _saveForm,
            tooltip: 'Save',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Form Settings
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Form Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _formType,
              decoration: const InputDecoration(
                labelText: 'Form Type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'survey', child: Text('Survey')),
                DropdownMenuItem(value: 'registration', child: Text('Registration')),
                DropdownMenuItem(value: 'feedback', child: Text('Feedback')),
              ],
              onChanged: (value) {
                setState(() => _formType = value!);
              },
            ),
            const SizedBox(height: 24),

            // Add Field Button
            Row(
              children: [
                const Text(
                  'Form Fields',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _showAddFieldDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Field'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Fields List
            if (_fields.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'No fields yet. Click "Add Field" to get started.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              )
            else
              ..._fields.map((field) => _buildFieldCard(field)).toList(),

            const SizedBox(height: 24),

            // Publishing Controls
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : _saveForm,
                    child: const Text('Save Draft'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveAndPublish,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Text('Save & Publish'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldCard(FormFieldConfig field) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(_getFieldIcon(field.type)),
        title: Text(field.label),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_getFieldTypeLabel(field.type)),
            if (field.validatorTypes != null && field.validatorTypes!.isNotEmpty)
              Text(
                '${field.validatorTypes!.length} validator(s)',
                style: TextStyle(fontSize: 12, color: Colors.blue[700]),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (field.required)
              const Chip(
                label: Text('Required', style: TextStyle(fontSize: 11)),
                visualDensity: VisualDensity.compact,
                backgroundColor: Colors.orange,
              ),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _editField(field),
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _deleteField(field.id),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getFieldIcon(String type) {
    switch (type) {
      // Text fields
      case FormFieldTypes.text:
      case FormFieldTypes.cupertinoTextField:
        return Icons.text_fields;
      case FormFieldTypes.email:
        return Icons.email;
      case FormFieldTypes.phone:
        return Icons.phone;
      case FormFieldTypes.textarea:
        return Icons.notes;
      case FormFieldTypes.url:
        return Icons.link;
      case FormFieldTypes.number:
        return Icons.numbers;

      // Selection fields
      case FormFieldTypes.dropdown:
        return Icons.arrow_drop_down_circle;
      case FormFieldTypes.searchableDropdown:
        return Icons.search;
      case FormFieldTypes.checkbox:
      case FormFieldTypes.cupertinoCheckbox:
        return Icons.check_box;
      case FormFieldTypes.checkboxGroup:
        return Icons.checklist;
      case FormFieldTypes.radio:
        return Icons.radio_button_checked;
      case FormFieldTypes.choiceChips:
        return Icons.label;
      case FormFieldTypes.filterChips:
        return Icons.filter_alt;
      case FormFieldTypes.switchField:
      case FormFieldTypes.cupertinoSwitch:
        return Icons.toggle_on;

      // Date/Time fields
      case FormFieldTypes.datePicker:
        return Icons.calendar_today;
      case FormFieldTypes.timePicker:
        return Icons.access_time;
      case FormFieldTypes.dateTimePicker:
        return Icons.event;
      case FormFieldTypes.dateRangePicker:
        return Icons.date_range;

      // Numeric fields
      case FormFieldTypes.slider:
      case FormFieldTypes.cupertinoSlider:
        return Icons.tune;
      case FormFieldTypes.rangeSlider:
        return Icons.linear_scale;
      case FormFieldTypes.touchSpin:
        return Icons.add_circle_outline;
      case FormFieldTypes.rating:
        return Icons.star;

      // Special fields
      case FormFieldTypes.colorPicker:
        return Icons.color_lens;
      case FormFieldTypes.signaturePad:
        return Icons.draw;
      case FormFieldTypes.typeahead:
        return Icons.keyboard;

      // Cupertino specific
      case FormFieldTypes.cupertinoSegmentedControl:
      case FormFieldTypes.cupertinoSlidingSegmentedControl:
        return Icons.view_carousel;

      default:
        return Icons.help_outline;
    }
  }

  String _getFieldTypeLabel(String type) {
    final typeInfo = FormFieldTypes.allTypes.firstWhere(
      (t) => t.value == type,
      orElse: () => FieldTypeInfo(type, type, ''),
    );
    return typeInfo.label;
  }

  void _showAddFieldDialog() {
    showDialog(
      context: context,
      builder: (context) => FieldConfigDialog(
        onSave: (field) {
          setState(() {
            _fields.add(field);
          });
        },
      ),
    );
  }

  void _editField(FormFieldConfig field) {
    showDialog(
      context: context,
      builder: (context) => FieldConfigDialog(
        existingField: field,
        onSave: (updatedField) {
          setState(() {
            final index = _fields.indexWhere((f) => f.id == field.id);
            if (index != -1) {
              _fields[index] = updatedField;
            }
          });
        },
      ),
    );
  }

  void _deleteField(String fieldId) {
    setState(() {
      _fields.removeWhere((f) => f.id == fieldId);
    });
  }

  Future<void> _saveForm({bool publish = false}) async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a form title')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final schema = FormSchemaData(
        fields: _fields,
        styling: {},
        confirmation: {},
      );

      if (widget.formId == null) {
        // Create new
        await _formsService.createForm(
          title: _titleController.text,
          description: _descriptionController.text.isEmpty
              ? null
              : _descriptionController.text,
          formType: _formType,
          schema: schema,
          status: publish ? 'active' : 'draft',
        );
      } else {
        // Update existing
        await _formsService.updateForm(
          widget.formId!,
          title: _titleController.text,
          description: _descriptionController.text.isEmpty
              ? null
              : _descriptionController.text,
          schema: schema,
          status: publish ? 'active' : null,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(publish ? 'Form published!' : 'Form saved as draft'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _saveAndPublish() async {
    await _saveForm(publish: true);
  }
}
