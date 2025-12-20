import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/form_schema.dart';
import '../../models/form_field_config.dart';
import '../../models/form_field_types.dart';
import '../../models/form_template_db.dart';
import '../../models/identity_config.dart';
import '../../services/forms_service.dart';
import '../../services/form_templates_service.dart';
import '../../widgets/field_config_dialog.dart';
import '../../widgets/rich_text_description_editor.dart';

class FormBuilderScreen extends StatefulWidget {
  final String? formId; // null for new form
  final FormTemplateDb? templateToApply; // template to pre-populate form

  const FormBuilderScreen({
    Key? key,
    this.formId,
    this.templateToApply,
  }) : super(key: key);

  @override
  State<FormBuilderScreen> createState() => _FormBuilderScreenState();
}

class _FormBuilderScreenState extends State<FormBuilderScreen> {
  final _formsService = FormsService();
  final _uuid = const Uuid();
  final _titleController = TextEditingController();
  final _slugController = TextEditingController();

  // Description is handled by rich text editor
  String _descriptionContent = '';
  final _maxSubmissionsController = TextEditingController();
  final _confirmationEmailController = TextEditingController();
  final _notificationEmailsController = TextEditingController();
  final _confirmationSmsController = TextEditingController();
  final _previewTextController = TextEditingController();

  List<FormFieldConfig> _fields = [];
  String _formType = 'survey';
  bool _isLoading = false;
  bool _isSaving = false;

  // Settings
  DateTime? _opensAt;
  DateTime? _closesAt;
  bool _requireLogin = false;
  bool _oneSubmissionPerUser = false;
  bool _publicForm = false;
  bool _showSettings = false;

  String? _templateId; // Track if form was created from a template

  @override
  void initState() {
    super.initState();
    if (widget.formId != null) {
      _loadForm();
    } else if (widget.templateToApply != null) {
      _applyTemplate(widget.templateToApply!);
    }
  }

  /// Apply a template to pre-populate the form
  void _applyTemplate(FormTemplateDb template) {
    // Check if template has variables that need values
    if (template.hasVariables) {
      // Show dialog to collect variable values
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showVariableInputDialog(template);
      });
    } else {
      _loadTemplateData(template, {});
    }
  }

  void _showVariableInputDialog(FormTemplateDb template) {
    final variables = template.variables.toList();
    final controllers = <String, TextEditingController>{};
    for (final v in variables) {
      controllers[v] = TextEditingController();
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Template Variables'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This template uses variables. Please provide values:',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                ...variables.map((v) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextField(
                        controller: controllers[v],
                        decoration: InputDecoration(
                          labelText: v.replaceAll('_', ' ').toUpperCase(),
                          hintText: 'Enter value for {{$v}}',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    )),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Go back if cancelled
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final values = <String, String>{};
              for (final entry in controllers.entries) {
                values[entry.key] = entry.value.text;
              }
              Navigator.pop(context);
              _loadTemplateData(template, values);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _loadTemplateData(FormTemplateDb template, Map<String, String> variableValues) {
    _templateId = template.id;

    // Apply variable substitutions to schema
    final schema = variableValues.isEmpty
        ? template.schema
        : template.applyVariables(variableValues);

    // Convert template questions to FormFieldConfig
    final questions = schema['questions'] as List? ?? [];
    final fields = <FormFieldConfig>[];

    for (final q in questions) {
      final questionMap = q as Map<String, dynamic>;
      final fieldConfig = _convertQuestionToField(questionMap);
      if (fieldConfig != null) {
        fields.add(fieldConfig);
      }
    }

    setState(() {
      _titleController.text = template.name;
      _descriptionContent = template.description ?? '';
      _fields = fields;

      // Apply template settings
      final settings = template.settings;
      if (settings['confirmation_message'] != null) {
        // Store for later use
      }
    });

    // Increment template use count
    FormTemplatesService().incrementUseCount(template.id).catchError((_) {});
  }

  FormFieldConfig? _convertQuestionToField(Map<String, dynamic> question) {
    final type = question['question_type'] as String? ?? 'short_answer';

    // Skip section headers as they're display-only
    if (type == 'section_header') {
      return FormFieldConfig(
        id: question['id'] as String? ?? _uuid.v4(),
        type: 'section',
        label: question['text'] as String? ?? '',
        help: question['description'] as String?,
      );
    }

    // Map template question types to form field types
    String fieldType;
    switch (type) {
      case 'short_answer':
        fieldType = FormFieldTypes.text;
        break;
      case 'paragraph':
        fieldType = FormFieldTypes.textarea;
        break;
      case 'email':
        fieldType = FormFieldTypes.email;
        break;
      case 'phone':
        fieldType = FormFieldTypes.phone;
        break;
      case 'number':
        fieldType = FormFieldTypes.number;
        break;
      case 'date':
        fieldType = FormFieldTypes.datePicker;
        break;
      case 'dropdown':
        fieldType = FormFieldTypes.dropdown;
        break;
      case 'radio':
        fieldType = FormFieldTypes.radio;
        break;
      case 'checkbox':
        fieldType = FormFieldTypes.checkboxGroup;
        break;
      case 'chips':
        fieldType = FormFieldTypes.filterChips;
        break;
      case 'rating':
        fieldType = FormFieldTypes.rating;
        break;
      case 'slider':
        fieldType = FormFieldTypes.slider;
        break;
      case 'hidden':
        fieldType = 'hidden';
        break;
      default:
        fieldType = FormFieldTypes.text;
    }

    // Convert options if present
    List<FormFieldOption>? options;
    if (question['options'] != null) {
      final optionsList = question['options'] as List;
      options = optionsList
          .map((o) => FormFieldOption(
                value: (o as Map<String, dynamic>)['value'] as String? ?? '',
                label: o['label'] as String? ?? '',
              ))
          .toList();
    }

    // Parse conditional logic
    String? conditionalFieldId;
    String? conditionalOperator;
    dynamic conditionalValue;
    List<Map<String, dynamic>>? conditions;

    final conditionData = question['condition'];
    if (conditionData is Map<String, dynamic>) {
      if (conditionData['and'] is List) {
        // Complex AND conditions
        final andConditions = conditionData['and'] as List;
        conditions = andConditions
            .whereType<Map<String, dynamic>>()
            .map((c) => {
                  'field': c['field'],
                  'value': c['value'],
                  'operator': c['operator'] ?? 'equals',
                })
            .toList();
        if (conditions.isNotEmpty) {
          conditionalFieldId = conditions.first['field'] as String?;
          conditionalValue = conditions.first['value'];
          conditionalOperator = conditions.first['operator'] as String? ?? 'equals';
        }
      } else if (conditionData['field'] != null) {
        // Simple condition
        conditionalFieldId = conditionData['field'] as String?;
        conditionalValue = conditionData['value'];
        conditionalOperator = conditionData['operator'] as String? ?? 'equals';
      }
    }

    return FormFieldConfig(
      id: question['id'] as String? ?? _uuid.v4(),
      type: fieldType,
      label: question['text'] as String? ?? '',
      required: question['required'] as bool? ?? false,
      placeholder: question['placeholder'] as String?,
      help: question['helper_text'] as String? ?? question['description'] as String?,
      options: options,
      defaultValue: question['default_value'],
      pageNumber: question['page'] as int? ?? 1,
      conditionalFieldId: conditionalFieldId,
      conditionalOperator: conditionalOperator,
      conditionalValue: conditionalValue,
      conditions: conditions,
      fileConfig: question['file_config'] as Map<String, dynamic>?,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _slugController.dispose();
    _maxSubmissionsController.dispose();
    _confirmationEmailController.dispose();
    _notificationEmailsController.dispose();
    _confirmationSmsController.dispose();
    _previewTextController.dispose();
    super.dispose();
  }

  Future<void> _loadForm() async {
    setState(() => _isLoading = true);

    try {
      final form = await _formsService.getForm(widget.formId!);

      setState(() {
        _titleController.text = form.title;
        _descriptionContent = form.description ?? '';
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
        _publicForm = form.publicForm;
        _previewTextController.text = form.previewText ?? '';

        // Load SMS confirmation message from schema
        _confirmationSmsController.text =
            form.schema.confirmation?['sms_message'] as String? ?? '';

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
            RichTextDescriptionEditor(
              key: ValueKey('description_$_descriptionContent'),
              initialContent: _descriptionContent,
              label: 'Description (optional)',
              placeholder: 'Enter form description... (supports bold, italic, underline, and links)',
              minHeight: 80,
              onChanged: (content) {
                _descriptionContent = content;
              },
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
                DropdownMenuItem(value: 'vote', child: Text('Vote')),
              ],
              onChanged: (value) {
                setState(() {
                  _formType = value!;
                  // Auto-enable require_login for vote forms
                  if (value == 'vote') {
                    _requireLogin = true;
                    _oneSubmissionPerUser = true;
                  }
                });
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
                            subtitle: Text(
                              _formType == 'vote'
                                  ? 'Required for vote forms (locked)'
                                  : 'Users must be logged in to submit',
                            ),
                            value: _requireLogin,
                            onChanged: _formType == 'vote'
                                ? null // Locked for vote forms
                                : (value) => setState(() => _requireLogin = value),
                            contentPadding: EdgeInsets.zero,
                          ),
                          SwitchListTile(
                            title: const Text('One Submission Per User'),
                            subtitle: Text(
                              _formType == 'vote'
                                  ? 'Required for vote forms (locked)'
                                  : 'Each user can only submit once',
                            ),
                            value: _oneSubmissionPerUser,
                            onChanged: _formType == 'vote'
                                ? null // Locked for vote forms
                                : (value) => setState(() => _oneSubmissionPerUser = value),
                            contentPadding: EdgeInsets.zero,
                          ),
                          SwitchListTile(
                            title: const Text('Display Preview on Forms Homepage'),
                            subtitle: const Text(
                              'Show this form in the public forms list',
                            ),
                            value: _publicForm,
                            onChanged: (value) => setState(() => _publicForm = value),
                            contentPadding: EdgeInsets.zero,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _previewTextController,
                            decoration: const InputDecoration(
                              labelText: 'Preview Text (optional)',
                              hintText: 'Short description for preview tiles and social shares',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.short_text),
                              helperText: 'Used in preview tiles on the website and as social share text',
                            ),
                            maxLines: 3,
                          ),
                          const SizedBox(height: 16),
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
                              helperText: 'Supports {{name}}, {{email}}, {{form_title}} variables',
                            ),
                            maxLines: 3,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _confirmationSmsController,
                            decoration: const InputDecoration(
                              labelText: 'Confirmation SMS Message (optional)',
                              hintText: 'Thank you {{name}} for your submission!',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.sms),
                              helperText: 'Supports {{name}}, {{form_title}} variables',
                            ),
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Identity Fields Notice - conditional based on require_login
            _buildIdentityFieldsSection(isMobile: isMobile),

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

            // Fields List with drag-and-drop reordering
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
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                proxyDecorator: (child, index, animation) {
                  return AnimatedBuilder(
                    animation: animation,
                    builder: (context, child) {
                      final animValue = Curves.easeInOut.transform(animation.value);
                      final elevation = lerpDouble(0, 8, animValue)!;
                      return Material(
                        elevation: elevation,
                        borderRadius: BorderRadius.circular(12),
                        child: child,
                      );
                    },
                    child: child,
                  );
                },
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex--;
                    final item = _fields.removeAt(oldIndex);
                    _fields.insert(newIndex, item);
                  });
                },
                itemCount: _fields.length,
                itemBuilder: (context, index) {
                  final field = _fields[index];
                  return _buildFieldCard(field, isMobile: isMobile, index: index, key: ValueKey(field.id));
                },
              ),

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

  /// Builds the identity fields section - shows different content based on require_login
  Widget _buildIdentityFieldsSection({bool isMobile = false}) {
    if (_requireLogin) {
      // Member portal form - identity auto-captured from profile
      return _buildMemberIdentityNotice(isMobile: isMobile);
    } else {
      // Public form - identity fields required
      return _buildIdentityFieldsNotice(isMobile: isMobile);
    }
  }

  /// Notice shown when require_login = true (member portal forms)
  Widget _buildMemberIdentityNotice({bool isMobile = false}) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_user, color: Colors.green.shade700, size: isMobile ? 18 : 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Member Identity Auto-Captured',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade900,
                    fontSize: isMobile ? 14 : 16,
                  ),
                ),
                SizedBox(height: isMobile ? 4 : 6),
                Text(
                  'Since login is required, submitter identity will be automatically captured from their member profile. No need to add identity fields.',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontSize: isMobile ? 12 : 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityFieldsNotice({bool isMobile = false}) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock_outline, color: Colors.blue.shade700, size: isMobile ? 18 : 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Identity Fields (Always Included)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                    fontSize: isMobile ? 14 : 16,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 6 : 8),
          Text(
            'Every form automatically includes Phone → Name → Email → Zip Code at the start. '
            'These fields enable person lookup and analytics tracking.',
            style: TextStyle(
              color: Colors.blue.shade700,
              fontSize: isMobile ? 12 : 14,
            ),
          ),
          SizedBox(height: isMobile ? 10 : 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildIdentityFieldChip('Phone Number', Icons.phone, isMobile: isMobile),
              _buildIdentityFieldChip('Full Name', Icons.person, isMobile: isMobile),
              _buildIdentityFieldChip('Email', Icons.email, isMobile: isMobile),
              _buildIdentityFieldChip('Zip Code', Icons.location_on, isMobile: isMobile),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityFieldChip(String label, IconData icon, {bool isMobile = false}) {
    return Chip(
      avatar: Icon(icon, size: isMobile ? 14 : 16, color: Colors.blue.shade700),
      label: Text(
        label,
        style: TextStyle(fontSize: isMobile ? 11 : 12),
      ),
      backgroundColor: Colors.white,
      padding: isMobile ? EdgeInsets.zero : null,
      visualDensity: isMobile ? VisualDensity.compact : null,
    );
  }

  Widget _buildFieldCard(FormFieldConfig field, {bool isMobile = false, int index = 0, Key? key}) {
    final hasCondition = field.conditionalFieldId != null ||
        (field.conditions != null && field.conditions!.isNotEmpty);

    // On mobile, use a more compact layout
    if (isMobile) {
      return Card(
        key: key,
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Drag handle
                  ReorderableDragStartListener(
                    index: index,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(Icons.drag_indicator, size: 18, color: Colors.blue.shade700),
                    ),
                  ),
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
                        // Conditional logic indicator
                        if (hasCondition)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.call_split, size: 12, color: Colors.purple.shade700),
                                const SizedBox(width: 4),
                                Text(
                                  'Conditional',
                                  style: TextStyle(fontSize: 10, color: Colors.purple.shade700, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
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
      key: key,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            ReorderableDragStartListener(
              index: index,
              child: Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.drag_indicator, size: 20, color: Colors.blue.shade700),
              ),
            ),
            Icon(_getFieldIcon(field.type)),
          ],
        ),
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
            // Conditional logic indicator
            if (hasCondition)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.purple.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.call_split, size: 14, color: Colors.purple.shade700),
                    const SizedBox(width: 4),
                    Text(
                      'Conditional: Shows when ${field.conditionalFieldId ?? "condition"} = ${field.conditionalValue ?? "..."}',
                      style: TextStyle(fontSize: 11, color: Colors.purple.shade700, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
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
      // Build confirmation map with SMS message if provided
      final confirmationMap = <String, dynamic>{};
      final smsMessage = _confirmationSmsController.text.trim();
      if (smsMessage.isNotEmpty) {
        confirmationMap['sms_message'] = smsMessage;
      }

      final schema = FormSchemaData(
        fields: _fields,
        styling: {},
        confirmation: confirmationMap,
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
          description: _descriptionContent.isEmpty
              ? null
              : _descriptionContent,
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
          publicForm: _publicForm,
          previewText: _previewTextController.text.trim().isEmpty
              ? null
              : _previewTextController.text.trim(),
        );
      } else {
        // Update existing
        await _formsService.updateForm(
          widget.formId!,
          title: _titleController.text,
          description: _descriptionContent.isEmpty
              ? null
              : _descriptionContent,
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
          publicForm: _publicForm,
          previewText: _previewTextController.text.trim().isEmpty
              ? null
              : _previewTextController.text.trim(),
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
