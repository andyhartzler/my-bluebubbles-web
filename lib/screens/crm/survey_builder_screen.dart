import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'package:bluebubbles/models/crm/survey_model.dart';
import 'package:bluebubbles/services/crm/survey_repository.dart';

const _unityBlue = Color(0xFF273351);
const _momentumBlue = Color(0xFF32A6DE);
const _sunriseGold = Color(0xFFFDB813);

class SurveyBuilderScreen extends StatefulWidget {
  final Survey? existingSurvey;
  final String? eventId;

  const SurveyBuilderScreen({super.key, this.existingSurvey, this.eventId});

  @override
  State<SurveyBuilderScreen> createState() => _SurveyBuilderScreenState();
}

class _SurveyBuilderScreenState extends State<SurveyBuilderScreen> {
  final _repo = SurveyRepository();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String _targetAudience = 'all_attendees';
  bool _autoSend = false;
  DateTime? _scheduledAt;
  List<_EditableQuestion> _questions = [];
  bool _saving = false;
  bool _sending = false;

  bool get _isEditing => widget.existingSurvey != null;

  @override
  void initState() {
    super.initState();
    if (widget.existingSurvey != null) {
      final s = widget.existingSurvey!;
      _titleController.text = s.title;
      _descriptionController.text = s.description ?? '';
      _targetAudience = s.targetAudience;
      _autoSend = s.autoSend;
      _scheduledAt = s.scheduledAt;
      _questions = s.questions
          .map((q) => _EditableQuestion.fromModel(q))
          .toList();
    }
    if (_questions.isEmpty) {
      _questions.add(_EditableQuestion());
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    for (final q in _questions) {
      q.dispose();
    }
    super.dispose();
  }

  Survey _buildSurvey({String? status}) {
    return Survey(
      id: widget.existingSurvey?.id,
      eventId: widget.existingSurvey?.eventId ?? widget.eventId,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      status: status ?? widget.existingSurvey?.status ?? 'draft',
      targetAudience: _targetAudience,
      autoSend: _autoSend,
      scheduledAt: _scheduledAt,
    );
  }

  List<SurveyQuestion> _buildQuestions() {
    return _questions.asMap().entries.map((entry) {
      final i = entry.key;
      final q = entry.value;
      return SurveyQuestion(
        id: q.existingId,
        questionText: q.textController.text.trim(),
        questionType: q.type,
        options: q.type == 'multiple_choice'
            ? q.optionControllers
                .map((c) => c.text.trim())
                .where((t) => t.isNotEmpty)
                .toList()
            : [],
        questionOrder: i + 1,
      );
    }).toList();
  }

  Future<void> _save({String? status}) async {
    if (!_formKey.currentState!.validate()) return;
    if (_questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one question')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final survey = _buildSurvey(status: status);
      final questions = _buildQuestions();

      Survey result;
      if (_isEditing) {
        result = await _repo.updateSurvey(survey, questions);
      } else {
        result = await _repo.createSurvey(survey, questions);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEditing ? 'Survey updated' : 'Survey created')),
        );
        Navigator.of(context).pop(result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _sendNow() async {
    if (!_formKey.currentState!.validate()) return;
    if (_questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one question')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send Survey Now?'),
        content: const Text(
          'This will save the survey and immediately send it to all recipients via iMessage.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send Now'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _sending = true);
    try {
      // Save first
      final survey = _buildSurvey(status: 'active');
      final questions = _buildQuestions();

      Survey saved;
      if (_isEditing) {
        saved = await _repo.updateSurvey(survey, questions);
      } else {
        saved = await _repo.createSurvey(survey, questions);
      }

      // Send
      final result = await _repo.sendSurvey(saved.id!);
      final sent = result['sent'] ?? 0;
      final total = result['total'] ?? 0;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Survey sent to $sent of $total recipients')),
        );
        Navigator.of(context).pop(saved);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _addQuestion() {
    setState(() {
      _questions.add(_EditableQuestion());
    });
  }

  void _removeQuestion(int index) {
    if (_questions.length <= 1) return;
    setState(() {
      _questions[index].dispose();
      _questions.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Survey' : 'Create Survey'),
        backgroundColor: _unityBlue,
        foregroundColor: Colors.white,
        actions: [
          if (_saving || _sending)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
            )
          else ...[
            TextButton(
              onPressed: () => _save(),
              child: const Text('Save Draft', style: TextStyle(color: Colors.white70)),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _sendNow,
              icon: const Icon(Icons.send, size: 18),
              label: const Text('Send Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _sunriseGold,
                foregroundColor: Colors.black,
              ),
            ),
            const SizedBox(width: 12),
          ],
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Title & Description ──
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Survey Details', style: theme.textTheme.titleMedium),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _titleController,
                            decoration: const InputDecoration(
                              labelText: 'Survey Title',
                              hintText: 'e.g., Post-Event Feedback',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'Title is required' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _descriptionController,
                            decoration: const InputDecoration(
                              labelText: 'Description (optional)',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Settings ──
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Settings', style: theme.textTheme.titleMedium),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _targetAudience,
                            decoration: const InputDecoration(
                              labelText: 'Target Audience',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'all_attendees',
                                child: Text('All Attendees'),
                              ),
                              DropdownMenuItem(
                                value: 'checked_in_only',
                                child: Text('Checked-In Only'),
                              ),
                              DropdownMenuItem(
                                value: 'custom',
                                child: Text('Custom Phone List'),
                              ),
                            ],
                            onChanged: (v) {
                              if (v != null) setState(() => _targetAudience = v);
                            },
                          ),
                          const SizedBox(height: 12),
                          SwitchListTile(
                            title: const Text('Auto-send after event ends'),
                            subtitle: const Text(
                              'Automatically send when the event end time passes',
                            ),
                            value: _autoSend,
                            onChanged: (v) => setState(() => _autoSend = v),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Questions ──
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Questions (${_questions.length})',
                                  style: theme.textTheme.titleMedium,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _addQuestion,
                                icon: const Icon(Icons.add),
                                label: const Text('Add Question'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ReorderableListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _questions.length,
                            onReorder: (oldIndex, newIndex) {
                              setState(() {
                                if (newIndex > oldIndex) newIndex--;
                                final item = _questions.removeAt(oldIndex);
                                _questions.insert(newIndex, item);
                              });
                            },
                            itemBuilder: (context, index) {
                              return _buildQuestionCard(index,
                                  key: ValueKey(_questions[index].key));
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── iMessage Preview ──
                  Card(
                    color: Colors.green.shade900.withOpacity(0.3),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.chat_bubble_outline, size: 20),
                              const SizedBox(width: 8),
                              Text('iMessage Preview',
                                  style: theme.textTheme.titleMedium),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade700,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Text(
                              _buildPreviewText(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionCard(int index, {required Key key}) {
    final q = _questions[index];
    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.drag_handle, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Text(
                    'Question ${index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  if (_questions.length > 1)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _removeQuestion(index),
                      tooltip: 'Remove question',
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: q.textController,
                decoration: const InputDecoration(
                  labelText: 'Question text',
                  hintText: 'e.g., How would you rate the event?',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: q.type,
                decoration: const InputDecoration(
                  labelText: 'Question Type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'yes_no', child: Text('Yes / No')),
                  DropdownMenuItem(value: 'rating', child: Text('Rating (1-5)')),
                  DropdownMenuItem(
                    value: 'multiple_choice',
                    child: Text('Multiple Choice'),
                  ),
                  DropdownMenuItem(
                    value: 'short_answer',
                    child: Text('Short Answer'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() => q.type = v);
                  }
                },
              ),
              if (q.type == 'multiple_choice') ...[
                const SizedBox(height: 12),
                ...q.optionControllers.asMap().entries.map((entry) {
                  final oi = entry.key;
                  final oc = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Text('${oi + 1}.', style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: oc,
                            decoration: InputDecoration(
                              hintText: 'Option ${oi + 1}',
                              isDense: true,
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        if (q.optionControllers.length > 2)
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              setState(() {
                                q.optionControllers[oi].dispose();
                                q.optionControllers.removeAt(oi);
                              });
                            },
                          ),
                      ],
                    ),
                  );
                }),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      q.optionControllers.add(TextEditingController());
                    });
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add option'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _buildPreviewText() {
    final title = _titleController.text.trim().isEmpty
        ? 'Survey Title'
        : _titleController.text.trim();

    if (_questions.isEmpty) return '\u{1F4CA} $title\n\nNo questions added yet.';

    final q = _questions.first;
    final qText = q.textController.text.trim().isEmpty
        ? 'Your question here?'
        : q.textController.text.trim();

    final total = _questions.length;
    final buf = StringBuffer();
    buf.writeln('\u{1F4CA} $title');
    buf.writeln('Q1 of $total: $qText');
    buf.writeln();

    switch (q.type) {
      case 'yes_no':
        buf.writeln('Reply YES or NO');
        break;
      case 'rating':
        buf.writeln('Reply 1-5 (1=Poor, 5=Excellent)');
        break;
      case 'multiple_choice':
        final opts = q.optionControllers
            .map((c) => c.text.trim())
            .where((t) => t.isNotEmpty)
            .toList();
        if (opts.isEmpty) {
          buf.writeln('1. Option 1\n2. Option 2');
        } else {
          for (int i = 0; i < opts.length; i++) {
            buf.writeln('${i + 1}. ${opts[i]}');
          }
        }
        buf.writeln();
        buf.writeln('Reply with the number');
        break;
      case 'short_answer':
        buf.writeln('Reply with your answer');
        break;
    }

    buf.writeln();
    buf.write('Reply SKIP to skip \u00B7 STOP to opt out');
    return buf.toString();
  }
}

// ── Editable question helper ────────────────────────────────────────────────

class _EditableQuestion {
  final String key;
  final String? existingId;
  final TextEditingController textController;
  String type;
  List<TextEditingController> optionControllers;

  _EditableQuestion({
    String? key,
    this.existingId,
    String? text,
    this.type = 'yes_no',
    List<String>? options,
  })  : key = key ?? const Uuid().v4(),
        textController = TextEditingController(text: text ?? ''),
        optionControllers = (options != null && options.isNotEmpty)
            ? options.map((o) => TextEditingController(text: o)).toList()
            : [TextEditingController(), TextEditingController()];

  factory _EditableQuestion.fromModel(SurveyQuestion q) {
    return _EditableQuestion(
      existingId: q.id,
      text: q.questionText,
      type: q.questionType,
      options: q.options.isNotEmpty ? q.options : null,
    );
  }

  void dispose() {
    textController.dispose();
    for (final c in optionControllers) {
      c.dispose();
    }
  }
}
