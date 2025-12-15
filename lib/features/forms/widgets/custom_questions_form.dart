import 'package:flutter/material.dart';
import '../models/job.dart';

/// Widget for displaying and collecting responses to custom questions
/// in a job application form
class CustomQuestionsForm extends StatefulWidget {
  final List<CustomQuestion> questions;
  final Map<String, dynamic> initialResponses;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final bool readOnly;

  const CustomQuestionsForm({
    super.key,
    required this.questions,
    this.initialResponses = const {},
    required this.onChanged,
    this.readOnly = false,
  });

  @override
  State<CustomQuestionsForm> createState() => _CustomQuestionsFormState();
}

class _CustomQuestionsFormState extends State<CustomQuestionsForm> {
  late Map<String, dynamic> _responses;
  final Map<String, TextEditingController> _textControllers = {};

  @override
  void initState() {
    super.initState();
    _responses = Map<String, dynamic>.from(widget.initialResponses);

    // Initialize text controllers for text/textarea questions
    for (final question in widget.questions) {
      if (question.type == CustomQuestionType.text ||
          question.type == CustomQuestionType.textarea) {
        _textControllers[question.id] = TextEditingController(
          text: _responses[question.id]?.toString() ?? '',
        );
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _updateResponse(String questionId, dynamic value) {
    setState(() {
      _responses[questionId] = value;
    });
    widget.onChanged(_responses);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sortedQuestions = List<CustomQuestion>.from(widget.questions)
      ..sort((a, b) => a.order.compareTo(b.order));

    if (sortedQuestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Icon(Icons.quiz_outlined, color: theme.colorScheme.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              'Additional Questions',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Please answer the following questions from the employer.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),

        // Questions
        ...sortedQuestions.asMap().entries.map((entry) {
          final index = entry.key;
          final question = entry.value;
          return Padding(
            padding: EdgeInsets.only(bottom: index < sortedQuestions.length - 1 ? 20 : 0),
            child: _buildQuestionField(theme, question),
          );
        }),
      ],
    );
  }

  Widget _buildQuestionField(ThemeData theme, CustomQuestion question) {
    switch (question.type) {
      case CustomQuestionType.text:
        return _buildTextField(theme, question);
      case CustomQuestionType.textarea:
        return _buildTextAreaField(theme, question);
      case CustomQuestionType.select:
        return _buildSelectField(theme, question);
      case CustomQuestionType.checkbox:
        return _buildCheckboxField(theme, question);
      case CustomQuestionType.radio:
        return _buildRadioField(theme, question);
    }
  }

  Widget _buildQuestionLabel(ThemeData theme, CustomQuestion question) {
    return Row(
      children: [
        Expanded(
          child: RichText(
            text: TextSpan(
              text: question.question,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              children: [
                if (question.required)
                  TextSpan(
                    text: ' *',
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(ThemeData theme, CustomQuestion question) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildQuestionLabel(theme, question),
        const SizedBox(height: 8),
        TextFormField(
          controller: _textControllers[question.id],
          decoration: InputDecoration(
            hintText: 'Enter your answer...',
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
          ),
          readOnly: widget.readOnly,
          onChanged: (value) => _updateResponse(question.id, value),
          validator: question.required
              ? (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'This field is required';
                  }
                  return null;
                }
              : null,
        ),
      ],
    );
  }

  Widget _buildTextAreaField(ThemeData theme, CustomQuestion question) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildQuestionLabel(theme, question),
        const SizedBox(height: 8),
        TextFormField(
          controller: _textControllers[question.id],
          decoration: InputDecoration(
            hintText: 'Enter your answer...',
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
            alignLabelWithHint: true,
          ),
          readOnly: widget.readOnly,
          maxLines: 4,
          onChanged: (value) => _updateResponse(question.id, value),
          validator: question.required
              ? (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'This field is required';
                  }
                  return null;
                }
              : null,
        ),
      ],
    );
  }

  Widget _buildSelectField(ThemeData theme, CustomQuestion question) {
    final currentValue = _responses[question.id]?.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildQuestionLabel(theme, question),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: question.options.contains(currentValue) ? currentValue : null,
          decoration: InputDecoration(
            hintText: 'Select an option...',
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
          ),
          items: question.options.map((option) {
            return DropdownMenuItem(
              value: option,
              child: Text(option),
            );
          }).toList(),
          onChanged: widget.readOnly
              ? null
              : (value) {
                  if (value != null) {
                    _updateResponse(question.id, value);
                  }
                },
          validator: question.required
              ? (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select an option';
                  }
                  return null;
                }
              : null,
        ),
      ],
    );
  }

  Widget _buildCheckboxField(ThemeData theme, CustomQuestion question) {
    final selectedOptions = _responses[question.id] is List
        ? List<String>.from(_responses[question.id])
        : <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildQuestionLabel(theme, question),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(8),
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
          ),
          child: Column(
            children: question.options.asMap().entries.map((entry) {
              final index = entry.key;
              final option = entry.value;
              final isSelected = selectedOptions.contains(option);

              return Column(
                children: [
                  CheckboxListTile(
                    title: Text(option),
                    value: isSelected,
                    onChanged: widget.readOnly
                        ? null
                        : (checked) {
                            final newSelected = List<String>.from(selectedOptions);
                            if (checked == true) {
                              newSelected.add(option);
                            } else {
                              newSelected.remove(option);
                            }
                            _updateResponse(question.id, newSelected);
                          },
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                  ),
                  if (index < question.options.length - 1)
                    Divider(
                      height: 1,
                      color: theme.colorScheme.outline.withOpacity(0.2),
                    ),
                ],
              );
            }).toList(),
          ),
        ),
        if (question.required && selectedOptions.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 12),
            child: Text(
              'Please select at least one option',
              style: TextStyle(
                color: theme.colorScheme.error,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRadioField(ThemeData theme, CustomQuestion question) {
    final currentValue = _responses[question.id]?.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildQuestionLabel(theme, question),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(8),
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
          ),
          child: Column(
            children: question.options.asMap().entries.map((entry) {
              final index = entry.key;
              final option = entry.value;

              return Column(
                children: [
                  RadioListTile<String>(
                    title: Text(option),
                    value: option,
                    groupValue: currentValue,
                    onChanged: widget.readOnly
                        ? null
                        : (value) {
                            if (value != null) {
                              _updateResponse(question.id, value);
                            }
                          },
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                  ),
                  if (index < question.options.length - 1)
                    Divider(
                      height: 1,
                      color: theme.colorScheme.outline.withOpacity(0.2),
                    ),
                ],
              );
            }).toList(),
          ),
        ),
        if (question.required && currentValue == null)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 12),
            child: Text(
              'Please select an option',
              style: TextStyle(
                color: theme.colorScheme.error,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  /// Validate all required questions have responses
  bool validate() {
    for (final question in widget.questions) {
      if (question.required) {
        final response = _responses[question.id];
        if (response == null) return false;

        if (response is String && response.trim().isEmpty) return false;
        if (response is List && response.isEmpty) return false;
      }
    }
    return true;
  }
}
