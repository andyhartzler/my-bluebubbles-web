import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/form_schema.dart';
import '../../models/form_field_config.dart';
import '../../services/forms_service.dart';

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
        subtitle: Text(field.type),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (field.required)
              const Chip(
                label: Text('Required', style: TextStyle(fontSize: 11)),
                visualDensity: VisualDensity.compact,
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
      case 'text':
        return Icons.text_fields;
      case 'email':
        return Icons.email;
      case 'phone':
        return Icons.phone;
      case 'textarea':
        return Icons.notes;
      case 'select':
        return Icons.arrow_drop_down_circle;
      case 'checkbox':
        return Icons.check_box;
      case 'radio':
        return Icons.radio_button_checked;
      default:
        return Icons.text_fields;
    }
  }

  void _showAddFieldDialog() {
    showDialog(
      context: context,
      builder: (context) => _AddFieldDialog(
        onAdd: (field) {
          setState(() {
            _fields.add(field);
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

class _AddFieldDialog extends StatefulWidget {
  final Function(FormFieldConfig) onAdd;

  const _AddFieldDialog({required this.onAdd});

  @override
  State<_AddFieldDialog> createState() => _AddFieldDialogState();
}

class _AddFieldDialogState extends State<_AddFieldDialog> {
  final _labelController = TextEditingController();
  String _fieldType = 'text';
  bool _required = false;

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Field'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _labelController,
            decoration: const InputDecoration(
              labelText: 'Field Label',
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _fieldType,
            decoration: const InputDecoration(
              labelText: 'Field Type',
            ),
            items: const [
              DropdownMenuItem(value: 'text', child: Text('Text')),
              DropdownMenuItem(value: 'email', child: Text('Email')),
              DropdownMenuItem(value: 'phone', child: Text('Phone')),
              DropdownMenuItem(value: 'textarea', child: Text('Text Area')),
              DropdownMenuItem(value: 'select', child: Text('Dropdown')),
              DropdownMenuItem(value: 'checkbox', child: Text('Checkbox')),
              DropdownMenuItem(value: 'radio', child: Text('Radio')),
            ],
            onChanged: (value) {
              setState(() => _fieldType = value!);
            },
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            title: const Text('Required'),
            value: _required,
            onChanged: (value) {
              setState(() => _required = value!);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_labelController.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter a field label')),
              );
              return;
            }

            final field = FormFieldConfig(
              id: const Uuid().v4(),
              type: _fieldType,
              label: _labelController.text,
              required: _required,
            );

            widget.onAdd(field);
            Navigator.pop(context);
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
