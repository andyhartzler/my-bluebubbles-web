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
  final _slugController = TextEditingController();
  final _maxSubmissionsController = TextEditingController();
  final _confirmationEmailController = TextEditingController();
  final _notificationEmailsController = TextEditingController();

  List<FormFieldConfig> _fields = [];
  String _formType = 'survey';
  bool _isLoading = false;
  bool _isSaving = false;

  // Settings
  DateTime? _opensAt;
  DateTime? _closesAt;
  bool _requireLogin = false;
  bool _oneSubmissionPerUser = false;
  bool _showSettings = false;

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
    _slugController.dispose();
    _maxSubmissionsController.dispose();
    _confirmationEmailController.dispose();
    _notificationEmailsController.dispose();
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
        // Create a mutable copy of the fields list (Freezed returns immutable lists)
        _fields = List.from(form.schema.fields);

        // Load settings
        _slugController.text = form.slug ?? '';
        _maxSubmissionsController.text = form.maxSubmissions?.toString() ?? '';
        _confirmationEmailController.text = form.confirmationEmailTemplate ?? '';
        _notificationEmailsController.text = form.notificationEmails?.join(', ') ?? '';
        _opensAt = form.opensAt;
        _closesAt = form.closesAt;
        _requireLogin = form.requireLogin;
        _oneSubmissionPerUser = form.oneSubmissionPerUser;

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

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final padding = isMobile ? 12.0 : 16.0;

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
        padding: EdgeInsets.all(padding),
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
            const SizedBox(height: 16),

            // Settings Section
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.settings),
                    title: const Text('Form Settings'),
                    subtitle: Text(_showSettings ? 'Tap to collapse' : 'Configure scheduling, access control, and more'),
                    trailing: Icon(_showSettings ? Icons.expand_less : Icons.expand_more),
                    onTap: () => setState(() => _showSettings = !_showSettings),
                  ),
                  if (_showSettings) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Custom URL Slug
                          TextField(
                            controller: _slugController,
                            decoration: const InputDecoration(
                              labelText: 'Custom URL Slug (optional)',
                              hintText: 'my-form-name',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.link),
                              helperText: 'Leave blank to auto-generate',
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Scheduling Section
                          Text(
                            'Scheduling',
                            style: TextStyle(
                              fontSize: isMobile ? 14 : 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (isMobile)
                            Column(
                              children: [
                                _buildDatePickerTile(
                                  'Opens At',
                                  _opensAt,
                                  (date) => setState(() => _opensAt = date),
                                  Icons.schedule,
                                ),
                                const SizedBox(height: 8),
                                _buildDatePickerTile(
                                  'Closes At',
                                  _closesAt,
                                  (date) => setState(() => _closesAt = date),
                                  Icons.event_busy,
                                ),
                              ],
                            )
                          else
                            Row(
                              children: [
                                Expanded(
                                  child: _buildDatePickerTile(
                                    'Opens At',
                                    _opensAt,
                                    (date) => setState(() => _opensAt = date),
                                    Icons.schedule,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildDatePickerTile(
                                    'Closes At',
                                    _closesAt,
                                    (date) => setState(() => _closesAt = date),
                                    Icons.event_busy,
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 16),

                          // Access Control Section
                          Text(
                            'Access Control',
                            style: TextStyle(
                              fontSize: isMobile ? 14 : 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SwitchListTile(
                            title: const Text('Require Login'),
                            subtitle: const Text('Users must be logged in to submit'),
                            value: _requireLogin,
                            onChanged: (value) => setState(() => _requireLogin = value),
                            contentPadding: EdgeInsets.zero,
                          ),
                          SwitchListTile(
                            title: const Text('One Submission Per User'),
                            subtitle: const Text('Each user can only submit once'),
                            value: _oneSubmissionPerUser,
                            onChanged: (value) => setState(() => _oneSubmissionPerUser = value),
                            contentPadding: EdgeInsets.zero,
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _maxSubmissionsController,
                            decoration: const InputDecoration(
                              labelText: 'Max Submissions (optional)',
                              hintText: 'e.g., 100',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.format_list_numbered),
                              helperText: 'Leave blank for unlimited',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 16),

                          // Email Settings Section
                          Text(
                            'Email Settings',
                            style: TextStyle(
                              fontSize: isMobile ? 14 : 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _notificationEmailsController,
                            decoration: const InputDecoration(
                              labelText: 'Notification Emails (optional)',
                              hintText: 'admin@example.com, team@example.com',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.notifications),
                              helperText: 'Comma-separated emails to notify on submission',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _confirmationEmailController,
                            decoration: const InputDecoration(
                              labelText: 'Confirmation Email Template (optional)',
                              hintText: 'Thank you for submitting...',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.email),
                            ),
                            maxLines: 3,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Add Field Button - responsive layout
            if (isMobile)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Form Fields',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _showAddFieldDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Field'),
                    ),
                  ),
                ],
              )
            else
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
                  padding: EdgeInsets.all(isMobile ? 24 : 32),
                  child: Text(
                    isMobile
                        ? 'No fields yet. Tap "Add Field" to start.'
                        : 'No fields yet. Click "Add Field" to get started.',
                    style: TextStyle(
                      fontSize: isMobile ? 14 : 16,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              ..._fields.map((field) => _buildFieldCard(field, isMobile: isMobile)).toList(),

            const SizedBox(height: 24),

            // Publishing Controls - stack vertically on mobile
            if (isMobile)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton(
                    onPressed: _isSaving ? null : _saveForm,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Save Draft'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveAndPublish,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Save & Publish'),
                  ),
                ],
              )
            else
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

  Widget _buildFieldCard(FormFieldConfig field, {bool isMobile = false}) {
    // On mobile, use a more compact layout
    if (isMobile) {
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_getFieldIcon(field.type), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      field.label,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (field.required)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Required',
                        style: TextStyle(fontSize: 10, color: Colors.white),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getFieldTypeLabel(field.type),
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        if (field.validatorTypes != null && field.validatorTypes!.isNotEmpty)
                          Text(
                            '${field.validatorTypes!.length} validator(s)',
                            style: TextStyle(fontSize: 11, color: Colors.blue[700]),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: () => _editField(field),
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 20),
                    onPressed: () => _deleteField(field.id),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // Desktop layout
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
      case FormFieldTypes.filePicker:
        return Icons.attach_file;
      case FormFieldTypes.imagePicker:
        return Icons.add_photo_alternate;

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

  Widget _buildDatePickerTile(
    String label,
    DateTime? value,
    Function(DateTime?) onChanged,
    IconData icon,
  ) {
    final formattedDate = value != null
        ? '${value.month}/${value.day}/${value.year} ${value.hour}:${value.minute.toString().padLeft(2, '0')}'
        : 'Not set';

    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
        );
        if (date != null && mounted) {
          final time = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.fromDateTime(value ?? DateTime.now()),
          );
          if (time != null) {
            onChanged(DateTime(
              date.year,
              date.month,
              date.day,
              time.hour,
              time.minute,
            ));
          } else {
            onChanged(date);
          }
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.grey[600]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  Text(
                    formattedDate,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
            if (value != null)
              IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () => onChanged(null),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
      ),
    );
  }

  List<String>? _parseNotificationEmails() {
    final text = _notificationEmailsController.text.trim();
    if (text.isEmpty) return null;
    return text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  int? _parseMaxSubmissions() {
    final text = _maxSubmissionsController.text.trim();
    if (text.isEmpty) return null;
    return int.tryParse(text);
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

      final slug = _slugController.text.trim().isEmpty ? null : _slugController.text.trim();
      final maxSubmissions = _parseMaxSubmissions();
      final notificationEmails = _parseNotificationEmails();
      final confirmationEmail = _confirmationEmailController.text.trim().isEmpty
          ? null
          : _confirmationEmailController.text.trim();

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
          opensAt: _opensAt,
          closesAt: _closesAt,
          requireLogin: _requireLogin,
          oneSubmissionPerUser: _oneSubmissionPerUser,
          maxSubmissions: maxSubmissions,
          slug: slug,
          confirmationEmailTemplate: confirmationEmail,
          notificationEmails: notificationEmails,
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
          opensAt: _opensAt,
          closesAt: _closesAt,
          requireLogin: _requireLogin,
          oneSubmissionPerUser: _oneSubmissionPerUser,
          maxSubmissions: maxSubmissions,
          slug: slug,
          confirmationEmailTemplate: confirmationEmail,
          notificationEmails: notificationEmails,
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
