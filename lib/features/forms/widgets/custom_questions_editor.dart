import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

/// Question type enum matching the database structure
enum QuestionType {
  text,
  textarea,
  select,
  checkbox,
  radio,
}

/// A custom question for job applications (UI model)
class CustomQuestionData {
  String id;
  String question;
  QuestionType type;
  bool required;
  List<String> options;
  int order;

  CustomQuestionData({
    String? id,
    this.question = '',
    this.type = QuestionType.text,
    this.required = false,
    List<String>? options,
    this.order = 0,
  })  : id = id ?? const Uuid().v4(),
        options = options ?? [];

  factory CustomQuestionData.fromJson(Map<String, dynamic> json) {
    return CustomQuestionData(
      id: json['id'] as String? ?? const Uuid().v4(),
      question: json['question'] as String? ?? '',
      type: _parseType(json['type']),
      required: json['required'] as bool? ?? false,
      options: (json['options'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      order: json['order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'type': type.name,
      'required': required,
      'options': options,
      'order': order,
    };
  }

  static QuestionType _parseType(dynamic value) {
    if (value == null) return QuestionType.text;
    final str = value.toString().toLowerCase();
    switch (str) {
      case 'textarea':
        return QuestionType.textarea;
      case 'select':
        return QuestionType.select;
      case 'checkbox':
        return QuestionType.checkbox;
      case 'radio':
        return QuestionType.radio;
      default:
        return QuestionType.text;
    }
  }

  CustomQuestionData copyWith({
    String? id,
    String? question,
    QuestionType? type,
    bool? required,
    List<String>? options,
    int? order,
  }) {
    return CustomQuestionData(
      id: id ?? this.id,
      question: question ?? this.question,
      type: type ?? this.type,
      required: required ?? this.required,
      options: options ?? List.from(this.options),
      order: order ?? this.order,
    );
  }
}

/// Widget for editing a list of custom questions for job applications
class CustomQuestionsEditor extends StatefulWidget {
  final List<Map<String, dynamic>> initialQuestions;
  final ValueChanged<List<Map<String, dynamic>>> onChanged;

  const CustomQuestionsEditor({
    super.key,
    this.initialQuestions = const [],
    required this.onChanged,
  });

  @override
  State<CustomQuestionsEditor> createState() => _CustomQuestionsEditorState();
}

class _CustomQuestionsEditorState extends State<CustomQuestionsEditor> {
  late List<CustomQuestionData> _questions;

  @override
  void initState() {
    super.initState();
    _questions = widget.initialQuestions
        .map((json) => CustomQuestionData.fromJson(json))
        .toList();
    _reorderQuestions();
  }

  void _reorderQuestions() {
    for (int i = 0; i < _questions.length; i++) {
      _questions[i].order = i;
    }
  }

  void _notifyChanged() {
    widget.onChanged(_questions.map((q) => q.toJson()).toList());
  }

  void _addQuestion() {
    setState(() {
      _questions.add(CustomQuestionData(
        order: _questions.length,
      ));
      _notifyChanged();
    });
  }

  void _removeQuestion(int index) {
    setState(() {
      _questions.removeAt(index);
      _reorderQuestions();
      _notifyChanged();
    });
  }

  void _duplicateQuestion(int index) {
    setState(() {
      final original = _questions[index];
      final duplicate = original.copyWith(
        id: const Uuid().v4(),
        question: '${original.question} (copy)',
        order: _questions.length,
      );
      _questions.add(duplicate);
      _notifyChanged();
    });
  }

  void _moveQuestion(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _questions.removeAt(oldIndex);
      _questions.insert(newIndex, item);
      _reorderQuestions();
      _notifyChanged();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Icon(Icons.quiz_outlined, color: theme.colorScheme.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              'Custom Application Questions',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _addQuestion,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Question'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Add custom questions that applicants must answer when applying for this job.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),

        // Questions list
        if (_questions.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.2),
                style: BorderStyle.solid,
              ),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.help_outline,
                    size: 48,
                    color: theme.colorScheme.outline.withOpacity(0.5),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No custom questions yet',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Click "Add Question" to create custom application questions',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _questions.length,
            onReorder: _moveQuestion,
            itemBuilder: (context, index) {
              return _QuestionCard(
                key: ValueKey(_questions[index].id),
                question: _questions[index],
                index: index,
                onChanged: (updated) {
                  // Update data without setState to avoid focus loss on text fields
                  // Only update the internal state and notify parent
                  _questions[index] = updated;
                  _notifyChanged();
                },
                onStructuralChange: () {
                  // Only call setState for structural changes (type, required, options)
                  // that need visual updates
                  setState(() {});
                },
                onRemove: () => _removeQuestion(index),
                onDuplicate: () => _duplicateQuestion(index),
              );
            },
          ),
      ],
    );
  }
}

class _QuestionCard extends StatefulWidget {
  final CustomQuestionData question;
  final int index;
  final ValueChanged<CustomQuestionData> onChanged;
  final VoidCallback onStructuralChange;
  final VoidCallback onRemove;
  final VoidCallback onDuplicate;

  const _QuestionCard({
    super.key,
    required this.question,
    required this.index,
    required this.onChanged,
    required this.onStructuralChange,
    required this.onRemove,
    required this.onDuplicate,
  });

  @override
  State<_QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<_QuestionCard> {
  late TextEditingController _questionController;
  late TextEditingController _optionController;
  bool _isExpanded = true;

  @override
  void initState() {
    super.initState();
    _questionController = TextEditingController(text: widget.question.question);
    _optionController = TextEditingController();
  }

  @override
  void dispose() {
    _questionController.dispose();
    _optionController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_QuestionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.question.id != widget.question.id) {
      _questionController.text = widget.question.question;
    }
  }

  String _getTypeLabel(QuestionType type) {
    switch (type) {
      case QuestionType.text:
        return 'Short Text';
      case QuestionType.textarea:
        return 'Long Text';
      case QuestionType.select:
        return 'Dropdown';
      case QuestionType.checkbox:
        return 'Checkboxes';
      case QuestionType.radio:
        return 'Radio Buttons';
    }
  }

  IconData _getTypeIcon(QuestionType type) {
    switch (type) {
      case QuestionType.text:
        return Icons.short_text;
      case QuestionType.textarea:
        return Icons.notes;
      case QuestionType.select:
        return Icons.arrow_drop_down_circle_outlined;
      case QuestionType.checkbox:
        return Icons.check_box_outlined;
      case QuestionType.radio:
        return Icons.radio_button_checked;
    }
  }

  bool _needsOptions(QuestionType type) {
    return type == QuestionType.select ||
        type == QuestionType.checkbox ||
        type == QuestionType.radio;
  }

  void _addOption() {
    final text = _optionController.text.trim();
    if (text.isEmpty) return;

    final newOptions = List<String>.from(widget.question.options)..add(text);
    widget.onChanged(widget.question.copyWith(options: newOptions));
    widget.onStructuralChange();
    _optionController.clear();
  }

  void _removeOption(int index) {
    final newOptions = List<String>.from(widget.question.options)
      ..removeAt(index);
    widget.onChanged(widget.question.copyWith(options: newOptions));
    widget.onStructuralChange();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Drag handle
                  ReorderableDragStartListener(
                    index: widget.index,
                    child: Icon(
                      Icons.drag_indicator,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Question number
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        '${widget.index + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Question preview
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.question.question.isEmpty
                              ? 'New Question'
                              : widget.question.question,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: widget.question.question.isEmpty
                                ? theme.colorScheme.outline
                                : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              _getTypeIcon(widget.question.type),
                              size: 14,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _getTypeLabel(widget.question.type),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (widget.question.required) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.errorContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Required',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: theme.colorScheme.onErrorContainer,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Actions
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: widget.onDuplicate,
                    tooltip: 'Duplicate',
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline,
                        size: 18, color: theme.colorScheme.error),
                    onPressed: widget.onRemove,
                    tooltip: 'Delete',
                    visualDensity: VisualDensity.compact,
                  ),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),

          // Expanded content
          if (_isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Question text
                  TextFormField(
                    controller: _questionController,
                    decoration: const InputDecoration(
                      labelText: 'Question *',
                      hintText: 'Enter your question...',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      widget.onChanged(
                          widget.question.copyWith(question: value));
                    },
                  ),
                  const SizedBox(height: 16),

                  // Type and Required row
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<QuestionType>(
                          value: widget.question.type,
                          decoration: const InputDecoration(
                            labelText: 'Question Type',
                            border: OutlineInputBorder(),
                          ),
                          items: QuestionType.values.map((type) {
                            return DropdownMenuItem(
                              value: type,
                              child: Row(
                                children: [
                                  Icon(_getTypeIcon(type), size: 18),
                                  const SizedBox(width: 8),
                                  Text(_getTypeLabel(type)),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              widget.onChanged(
                                  widget.question.copyWith(type: value));
                              widget.onStructuralChange();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Required toggle
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Required',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Switch(
                            value: widget.question.required,
                            onChanged: (value) {
                              widget.onChanged(
                                  widget.question.copyWith(required: value));
                              widget.onStructuralChange();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Options section (for select, checkbox, radio)
                  if (_needsOptions(widget.question.type)) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Options',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Add option input
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _optionController,
                            decoration: const InputDecoration(
                              hintText: 'Add an option...',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onSubmitted: (_) => _addOption(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _addOption,
                          icon: const Icon(Icons.add),
                          tooltip: 'Add Option',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Options list
                    if (widget.question.options.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Add at least one option',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ...widget.question.options.asMap().entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest
                                  .withOpacity(0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  widget.question.type == QuestionType.checkbox
                                      ? Icons.check_box_outline_blank
                                      : widget.question.type ==
                                              QuestionType.radio
                                          ? Icons.radio_button_unchecked
                                          : Icons.arrow_right,
                                  size: 18,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(entry.value),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.close,
                                    size: 16,
                                    color: theme.colorScheme.error,
                                  ),
                                  onPressed: () => _removeOption(entry.key),
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
