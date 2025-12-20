import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/form_template_db.dart';
import '../../models/form_field_config.dart';
import '../../models/form_field_types.dart';
import '../../services/form_templates_service.dart';
import '../../widgets/field_config_dialog.dart';

class TemplateBuilderScreen extends StatefulWidget {
  final String? templateId; // null for new template

  const TemplateBuilderScreen({
    Key? key,
    this.templateId,
  }) : super(key: key);

  @override
  State<TemplateBuilderScreen> createState() => _TemplateBuilderScreenState();
}

class _TemplateBuilderScreenState extends State<TemplateBuilderScreen> {
  final _templatesService = FormTemplatesService();
  final _uuid = const Uuid();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();

  List<Map<String, dynamic>> _questions = [];
  String _selectedIcon = 'description_outlined';
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isPublic = false;
  bool _isSystem = false;
  Map<String, dynamic> _settings = {};
  bool _showSettings = false;

  // Settings controllers
  final _confirmationMessageController = TextEditingController();

  final List<_IconOption> _iconOptions = [
    _IconOption('description_outlined', Icons.description_outlined),
    _IconOption('group_add', Icons.group_add),
    _IconOption('event', Icons.event),
    _IconOption('feedback', Icons.feedback),
    _IconOption('poll', Icons.poll),
    _IconOption('volunteer_activism', Icons.volunteer_activism),
    _IconOption('contact_mail', Icons.contact_mail),
    _IconOption('work', Icons.work),
    _IconOption('email', Icons.email),
    _IconOption('support_agent', Icons.support_agent),
    _IconOption('shopping_cart', Icons.shopping_cart),
    _IconOption('card_membership', Icons.card_membership),
    _IconOption('school', Icons.school),
    _IconOption('campaign', Icons.campaign),
    _IconOption('people', Icons.people),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.templateId != null) {
      _loadTemplate();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _confirmationMessageController.dispose();
    super.dispose();
  }

  Future<void> _loadTemplate() async {
    setState(() => _isLoading = true);

    try {
      final template = await _templatesService.getTemplate(widget.templateId!);
      if (template == null) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Template not found'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      setState(() {
        _nameController.text = template.name;
        _descriptionController.text = template.description ?? '';
        _categoryController.text = template.category ?? '';
        _selectedIcon = template.icon ?? 'description_outlined';
        _isPublic = template.isPublic;
        _isSystem = template.isSystem;
        _settings = Map<String, dynamic>.from(template.settings);
        _questions = List<Map<String, dynamic>>.from(template.questions);

        // Load settings
        _confirmationMessageController.text =
            _settings['confirmation_message'] as String? ?? '';

        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading template: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.templateId == null ? 'Create Template' : 'Edit Template'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveTemplate,
              tooltip: 'Save',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Template Settings Card
            Card(
              child: Padding(
                padding: EdgeInsets.all(padding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Template Details',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Template Name *',
                        border: OutlineInputBorder(),
                        hintText: 'e.g., Chapter Registration Form',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                        hintText: 'Describe when and how to use this template...',
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: TemplateCategories.all.contains(_categoryController.text)
                                ? _categoryController.text
                                : null,
                            decoration: const InputDecoration(
                              labelText: 'Category',
                              border: OutlineInputBorder(),
                            ),
                            items: TemplateCategories.all
                                .map((cat) => DropdownMenuItem(
                                      value: cat,
                                      child: Text(cat),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _categoryController.text = value ?? '';
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: theme.dividerColor),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: PopupMenuButton<String>(
                            tooltip: 'Select icon',
                            offset: const Offset(0, 40),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_getIconData(_selectedIcon)),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.arrow_drop_down),
                                ],
                              ),
                            ),
                            itemBuilder: (context) => _iconOptions
                                .map((opt) => PopupMenuItem(
                                      value: opt.name,
                                      child: Row(
                                        children: [
                                          Icon(opt.icon),
                                          const SizedBox(width: 12),
                                          Text(opt.name.replaceAll('_', ' ')),
                                        ],
                                      ),
                                    ))
                                .toList(),
                            onSelected: (value) {
                              setState(() => _selectedIcon = value);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('Public Template'),
                      subtitle: const Text('Allow other users to use this template'),
                      value: _isPublic,
                      onChanged: _isSystem ? null : (value) {
                        setState(() => _isPublic = value);
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Settings Section
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.settings),
                    title: const Text('Template Settings'),
                    subtitle: Text(_showSettings
                        ? 'Tap to collapse'
                        : 'Configure default form settings'),
                    trailing: Icon(_showSettings ? Icons.expand_less : Icons.expand_more),
                    onTap: () => setState(() => _showSettings = !_showSettings),
                  ),
                  if (_showSettings) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: EdgeInsets.all(padding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _confirmationMessageController,
                            decoration: const InputDecoration(
                              labelText: 'Confirmation Message',
                              border: OutlineInputBorder(),
                              hintText: 'Thank you for submitting!',
                              helperText: 'Supports variables like {{name}}',
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Additional settings can be configured in JSON format in the database.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Questions Section
            Card(
              child: Padding(
                padding: EdgeInsets.all(padding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Questions (${_questions.length})',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _addQuestion,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Question'),
                        ),
                      ],
                    ),
                    if (_questions.isEmpty) ...[
                      const SizedBox(height: 24),
                      Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.help_outline,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No questions yet',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add questions to define your template',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 12),
                      ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _questions.length,
                        onReorder: (oldIndex, newIndex) {
                          setState(() {
                            if (oldIndex < newIndex) newIndex--;
                            final item = _questions.removeAt(oldIndex);
                            _questions.insert(newIndex, item);
                          });
                        },
                        itemBuilder: (context, index) {
                          final question = _questions[index];
                          return _QuestionTile(
                            key: ValueKey(question['id'] ?? index),
                            question: question,
                            index: index,
                            onEdit: () => _editQuestion(index),
                            onDelete: () => _deleteQuestion(index),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Variables Preview (if any)
            if (_detectVariables().isNotEmpty) ...[
              Card(
                color: Colors.purple.withOpacity(0.05),
                child: Padding(
                  padding: EdgeInsets.all(padding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.code, color: Colors.purple),
                          const SizedBox(width: 8),
                          Text(
                            'Template Variables',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.purple,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'This template uses the following variables:',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _detectVariables()
                            .map((v) => Chip(
                                  label: Text('{{$v}}'),
                                  backgroundColor: Colors.purple.withOpacity(0.1),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 100), // Space for FAB
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSaving ? null : _saveTemplate,
        icon: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.save),
        label: Text(_isSaving ? 'Saving...' : 'Save Template'),
      ),
    );
  }

  IconData _getIconData(String? iconName) {
    for (final opt in _iconOptions) {
      if (opt.name == iconName) return opt.icon;
    }
    return Icons.description_outlined;
  }

  Set<String> _detectVariables() {
    final vars = <String>{};
    final jsonString = jsonEncode(_questions);
    final regex = RegExp(r'\{\{(\w+)\}\}');
    for (final match in regex.allMatches(jsonString)) {
      vars.add(match.group(1)!);
    }
    // Also check description and confirmation message
    for (final match in regex.allMatches(_descriptionController.text)) {
      vars.add(match.group(1)!);
    }
    for (final match in regex.allMatches(_confirmationMessageController.text)) {
      vars.add(match.group(1)!);
    }
    return vars;
  }

  void _addQuestion() {
    _showQuestionTypeDialog((type) {
      final newQuestion = {
        'id': _uuid.v4(),
        'question_type': type,
        'text': '',
        'required': false,
        'page': 1,
      };

      // Add default options for certain types
      if (['dropdown', 'radio', 'checkbox', 'chips'].contains(type)) {
        newQuestion['options'] = [
          {'id': _uuid.v4(), 'label': 'Option 1', 'value': 'option_1'},
          {'id': _uuid.v4(), 'label': 'Option 2', 'value': 'option_2'},
        ];
      }

      setState(() {
        _questions.add(newQuestion);
      });

      // Immediately open editor for the new question
      Future.delayed(const Duration(milliseconds: 100), () {
        _editQuestion(_questions.length - 1);
      });
    });
  }

  void _showQuestionTypeDialog(void Function(String type) onSelected) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Question Type'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTypeCategory('Basic', [
                  _QuestionTypeOption('short_answer', 'Short Answer', Icons.short_text),
                  _QuestionTypeOption('paragraph', 'Paragraph', Icons.notes),
                  _QuestionTypeOption('email', 'Email', Icons.email),
                  _QuestionTypeOption('phone', 'Phone', Icons.phone),
                  _QuestionTypeOption('number', 'Number', Icons.numbers),
                  _QuestionTypeOption('date', 'Date', Icons.calendar_today),
                ], onSelected),
                const Divider(),
                _buildTypeCategory('Selection', [
                  _QuestionTypeOption('dropdown', 'Dropdown', Icons.arrow_drop_down_circle),
                  _QuestionTypeOption('radio', 'Radio Buttons', Icons.radio_button_checked),
                  _QuestionTypeOption('checkbox', 'Checkboxes', Icons.check_box),
                  _QuestionTypeOption('chips', 'Chips', Icons.label),
                ], onSelected),
                const Divider(),
                _buildTypeCategory('Special', [
                  _QuestionTypeOption('section_header', 'Section Header', Icons.title),
                  _QuestionTypeOption('hidden', 'Hidden Field', Icons.visibility_off),
                  _QuestionTypeOption('rating', 'Rating', Icons.star),
                  _QuestionTypeOption('slider', 'Slider', Icons.linear_scale),
                ], onSelected),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeCategory(
    String title,
    List<_QuestionTypeOption> options,
    void Function(String) onSelected,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options
              .map((opt) => ActionChip(
                    avatar: Icon(opt.icon, size: 18),
                    label: Text(opt.label),
                    onPressed: () {
                      Navigator.pop(context);
                      onSelected(opt.type);
                    },
                  ))
              .toList(),
        ),
      ],
    );
  }

  void _editQuestion(int index) {
    final question = _questions[index];

    showDialog(
      context: context,
      builder: (context) => _QuestionEditDialog(
        question: question,
        onSave: (updated) {
          setState(() {
            _questions[index] = updated;
          });
        },
      ),
    );
  }

  void _deleteQuestion(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Question'),
        content: const Text('Are you sure you want to delete this question?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _questions.removeAt(index);
              });
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveTemplate() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Template name is required'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final schema = {'questions': _questions};
      final settings = <String, dynamic>{
        if (_confirmationMessageController.text.isNotEmpty)
          'confirmation_message': _confirmationMessageController.text,
        ..._settings,
      };

      if (widget.templateId == null) {
        await _templatesService.createTemplate(
          name: name,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          category: _categoryController.text.trim().isEmpty
              ? null
              : _categoryController.text.trim(),
          icon: _selectedIcon,
          schema: schema,
          settings: settings,
          isPublic: _isPublic,
        );
      } else {
        await _templatesService.updateTemplate(
          widget.templateId!,
          name: name,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          category: _categoryController.text.trim().isEmpty
              ? null
              : _categoryController.text.trim(),
          icon: _selectedIcon,
          schema: schema,
          settings: settings,
          isPublic: _isPublic,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.templateId == null
                ? 'Template created'
                : 'Template updated'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving template: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _IconOption {
  final String name;
  final IconData icon;

  const _IconOption(this.name, this.icon);
}

class _QuestionTypeOption {
  final String type;
  final String label;
  final IconData icon;

  const _QuestionTypeOption(this.type, this.label, this.icon);
}

class _QuestionTile extends StatelessWidget {
  final Map<String, dynamic> question;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _QuestionTile({
    super.key,
    required this.question,
    required this.index,
    required this.onEdit,
    required this.onDelete,
  });

  IconData _getQuestionIcon(String type) {
    switch (type) {
      case 'short_answer':
        return Icons.short_text;
      case 'paragraph':
        return Icons.notes;
      case 'email':
        return Icons.email;
      case 'phone':
        return Icons.phone;
      case 'number':
        return Icons.numbers;
      case 'date':
        return Icons.calendar_today;
      case 'dropdown':
        return Icons.arrow_drop_down_circle;
      case 'radio':
        return Icons.radio_button_checked;
      case 'checkbox':
        return Icons.check_box;
      case 'chips':
        return Icons.label;
      case 'section_header':
        return Icons.title;
      case 'hidden':
        return Icons.visibility_off;
      case 'rating':
        return Icons.star;
      case 'slider':
        return Icons.linear_scale;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final type = question['question_type'] as String? ?? 'short_answer';
    final text = question['text'] as String? ?? '';
    final isRequired = question['required'] as bool? ?? false;
    final isHidden = type == 'hidden';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: ReorderableDragStartListener(
          index: index,
          child: Icon(
            Icons.drag_handle,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        title: Row(
          children: [
            Icon(
              _getQuestionIcon(type),
              size: 18,
              color: isHidden ? Colors.grey : theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text.isEmpty
                    ? (isHidden ? '(Hidden: ${question['default_value'] ?? 'No value'})' : '(No question text)')
                    : text,
                style: TextStyle(
                  fontStyle: text.isEmpty ? FontStyle.italic : FontStyle.normal,
                  color: text.isEmpty || isHidden ? Colors.grey : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isRequired)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Required',
                  style: TextStyle(fontSize: 10, color: Colors.red),
                ),
              ),
          ],
        ),
        subtitle: Text(
          type.replaceAll('_', ' ').toUpperCase(),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEdit,
              tooltip: 'Edit',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: onDelete,
              tooltip: 'Delete',
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionEditDialog extends StatefulWidget {
  final Map<String, dynamic> question;
  final void Function(Map<String, dynamic>) onSave;

  const _QuestionEditDialog({
    required this.question,
    required this.onSave,
  });

  @override
  State<_QuestionEditDialog> createState() => _QuestionEditDialogState();
}

class _QuestionEditDialogState extends State<_QuestionEditDialog> {
  late TextEditingController _textController;
  late TextEditingController _descriptionController;
  late TextEditingController _placeholderController;
  late TextEditingController _helperTextController;
  late TextEditingController _defaultValueController;
  late bool _required;
  late List<Map<String, dynamic>> _options;
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.question['text'] as String? ?? '');
    _descriptionController = TextEditingController(text: widget.question['description'] as String? ?? '');
    _placeholderController = TextEditingController(text: widget.question['placeholder'] as String? ?? '');
    _helperTextController = TextEditingController(text: widget.question['helper_text'] as String? ?? '');
    _defaultValueController = TextEditingController(text: widget.question['default_value'] as String? ?? '');
    _required = widget.question['required'] as bool? ?? false;
    _options = List<Map<String, dynamic>>.from(
      (widget.question['options'] as List?)?.cast<Map<String, dynamic>>() ?? [],
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _descriptionController.dispose();
    _placeholderController.dispose();
    _helperTextController.dispose();
    _defaultValueController.dispose();
    super.dispose();
  }

  bool get _hasOptions {
    final type = widget.question['question_type'] as String?;
    return ['dropdown', 'radio', 'checkbox', 'chips'].contains(type);
  }

  bool get _isHidden {
    return widget.question['question_type'] == 'hidden';
  }

  bool get _isSectionHeader {
    return widget.question['question_type'] == 'section_header';
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.question['question_type'] as String? ?? 'short_answer';

    return AlertDialog(
      title: Text('Edit ${type.replaceAll('_', ' ')}'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_isHidden) ...[
                TextField(
                  controller: _textController,
                  decoration: InputDecoration(
                    labelText: _isSectionHeader ? 'Section Title' : 'Question Text',
                    border: const OutlineInputBorder(),
                    hintText: _isSectionHeader
                        ? 'e.g., Personal Information'
                        : 'e.g., What is your name?',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: _isSectionHeader ? 'Section Description' : 'Description (optional)',
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
              if (_isHidden) ...[
                TextField(
                  controller: _defaultValueController,
                  decoration: const InputDecoration(
                    labelText: 'Default Value',
                    border: OutlineInputBorder(),
                    hintText: 'e.g., {{chapter_id}} or a static value',
                    helperText: 'Use {{variable}} for dynamic values',
                  ),
                ),
              ],
              if (!_isSectionHeader && !_isHidden) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _placeholderController,
                  decoration: const InputDecoration(
                    labelText: 'Placeholder (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _helperTextController,
                  decoration: const InputDecoration(
                    labelText: 'Helper Text (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Required'),
                  value: _required,
                  onChanged: (value) => setState(() => _required = value),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
              if (_hasOptions) ...[
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Options',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextButton.icon(
                      onPressed: _addOption,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...List.generate(_options.length, (index) {
                  final option = _options[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: 'Label',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            controller: TextEditingController(
                              text: option['label'] as String? ?? '',
                            ),
                            onChanged: (value) {
                              _options[index]['label'] = value;
                              // Auto-generate value from label if empty
                              if ((_options[index]['value'] as String? ?? '').isEmpty) {
                                _options[index]['value'] = value
                                    .toLowerCase()
                                    .replaceAll(RegExp(r'\s+'), '_')
                                    .replaceAll(RegExp(r'[^a-z0-9_]'), '');
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: 'Value',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            controller: TextEditingController(
                              text: option['value'] as String? ?? '',
                            ),
                            onChanged: (value) {
                              _options[index]['value'] = value;
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => setState(() => _options.removeAt(index)),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final updated = Map<String, dynamic>.from(widget.question);
            updated['text'] = _textController.text;
            updated['description'] = _descriptionController.text.isEmpty
                ? null
                : _descriptionController.text;
            updated['placeholder'] = _placeholderController.text.isEmpty
                ? null
                : _placeholderController.text;
            updated['helper_text'] = _helperTextController.text.isEmpty
                ? null
                : _helperTextController.text;
            updated['default_value'] = _defaultValueController.text.isEmpty
                ? null
                : _defaultValueController.text;
            updated['required'] = _required;
            if (_hasOptions) {
              updated['options'] = _options;
            }
            widget.onSave(updated);
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _addOption() {
    setState(() {
      _options.add({
        'id': _uuid.v4(),
        'label': '',
        'value': '',
      });
    });
  }
}
