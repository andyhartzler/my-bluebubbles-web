import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'package:bluebubbles/models/crm/survey_model.dart';
import 'package:bluebubbles/models/crm/survey_suggested_questions.dart';
import 'package:bluebubbles/services/crm/survey_repository.dart';
import 'package:bluebubbles/widgets/crm/recipient_selector_widget.dart';
import 'package:bluebubbles/features/committees/theme/brand_colors.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// Survey Builder — 3-Step Wizard
// ═══════════════════════════════════════════════════════════════════════════════

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
  final _step0FormKey = GlobalKey<FormState>();

  // ── Wizard state ──────────────────────────────────────────────────────────
  int _currentStep = 0;

  // ── Survey fields ─────────────────────────────────────────────────────────
  String _targetAudience = 'all_attendees';
  bool _autoSend = false;
  DateTime? _scheduledAt;
  List<_EditableQuestion> _questions = [];
  bool _saving = false;
  bool _sending = false;

  // ── Standalone recipient selection (Step 3, no eventId) ───────────────────
  List<String> _selectedPhones = [];

  bool get _isEditing => widget.existingSurvey != null;
  bool get _hasEvent => (widget.existingSurvey?.eventId ?? widget.eventId) != null;

  static const _stepLabels = ['Details', 'Questions', 'Recipients'];

  // ════════════════════════════════════════════════════════════════════════════
  // LIFECYCLE
  // ════════════════════════════════════════════════════════════════════════════

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

  // ════════════════════════════════════════════════════════════════════════════
  // BUILD SURVEY / QUESTIONS / SAVE / SEND
  // ════════════════════════════════════════════════════════════════════════════

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
          SnackBar(content: Text(_isEditing ? 'Survey updated' : 'Survey saved as draft')),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: BrandColors.momentumBlue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Send Now'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _sending = true);
    try {
      final survey = _buildSurvey(status: 'active');
      final questions = _buildQuestions();

      Survey saved;
      if (_isEditing) {
        saved = await _repo.updateSurvey(survey, questions);
      } else {
        saved = await _repo.createSurvey(survey, questions);
      }

      // Send — pass phoneList when standalone recipients are selected
      final Map<String, dynamic> result;
      if (!_hasEvent && _selectedPhones.isNotEmpty) {
        result = await _repo.sendSurvey(saved.id!, phoneList: _selectedPhones);
      } else {
        result = await _repo.sendSurvey(saved.id!);
      }

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

  // ════════════════════════════════════════════════════════════════════════════
  // STEP NAVIGATION
  // ════════════════════════════════════════════════════════════════════════════

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _step0FormKey.currentState?.validate() ?? false;
      case 1:
        if (_questions.isEmpty) {
          _showSnack('Add at least one question');
          return false;
        }
        for (final q in _questions) {
          if (q.textController.text.trim().isEmpty) {
            _showSnack('All questions must have text');
            return false;
          }
        }
        return true;
      case 2:
        if (!_hasEvent && _selectedPhones.isEmpty) {
          _showSnack('Select at least one recipient');
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _goNext() {
    if (!_validateCurrentStep()) return;
    if (_currentStep < 2) {
      setState(() => _currentStep++);
    }
  }

  void _goBack() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // QUESTION HELPERS
  // ════════════════════════════════════════════════════════════════════════════

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

  void _addSuggestedQuestion(SuggestedQuestion suggestion) {
    setState(() {
      _questions.add(_EditableQuestion(
        text: suggestion.text,
        type: suggestion.type,
        options: suggestion.options.isNotEmpty ? suggestion.options : null,
      ));
    });
  }

  // ════════════════════════════════════════════════════════════════════════════
  // BUILD — ROOT
  // ════════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildStepIndicator(),
          Expanded(child: _buildStepContent()),
          _buildBottomNavigation(),
        ],
      ),
    );
  }

  // ── AppBar ──────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isEditing ? 'Edit Survey' : 'Create Survey',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
          Text(
            'Step ${_currentStep + 1} of 3',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
        ],
      ),
      elevation: 0,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: BrandColors.tileGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      iconTheme: const IconThemeData(color: Colors.white),
      actions: [
        if (_saving || _sending)
          const Padding(
            padding: EdgeInsets.all(16),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
          ),
      ],
    );
  }

  // ── Step Indicator ─────────────────────────────────────────────────────────

  Widget _buildStepIndicator() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: List.generate(3, (index) {
          final isCompleted = index < _currentStep;
          final isActive = index == _currentStep;
          final isPending = index > _currentStep;

          return Expanded(
            child: Row(
              children: [
                // Connector line before (skip first)
                if (index > 0)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: isCompleted || isActive
                          ? BrandColors.momentumBlue
                          : Colors.grey.shade300,
                    ),
                  ),
                // Circle + label
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCompleted
                            ? BrandColors.success
                            : isActive
                                ? BrandColors.momentumBlue
                                : Colors.transparent,
                        border: Border.all(
                          color: isCompleted
                              ? BrandColors.success
                              : isActive
                                  ? BrandColors.momentumBlue
                                  : Colors.grey.shade400,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: isCompleted
                            ? const Icon(Icons.check, color: Colors.white, size: 18)
                            : Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: isActive ? Colors.white : Colors.grey.shade500,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _stepLabels[index],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                        color: isActive
                            ? BrandColors.momentumBlue
                            : isCompleted
                                ? BrandColors.success
                                : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
                // Connector line after (skip last)
                if (index < 2)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: isCompleted
                          ? BrandColors.momentumBlue
                          : Colors.grey.shade300,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ── Step Content Dispatch ──────────────────────────────────────────────────

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep0Details();
      case 1:
        return _buildStep1Questions();
      case 2:
        return _buildStep2Recipients();
      default:
        return const SizedBox.shrink();
    }
  }

  // ── Bottom Navigation ──────────────────────────────────────────────────────

  Widget _buildBottomNavigation() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Back button
            if (_currentStep > 0)
              OutlinedButton.icon(
                onPressed: _goBack,
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Back'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: BrandColors.unityBlue,
                  side: const BorderSide(color: BrandColors.unityBlue),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

            const Spacer(),

            // Step-dependent action buttons
            if (_currentStep < 2) ...[
              // Next button
              ElevatedButton.icon(
                onPressed: _goNext,
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: const Text('Next'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: BrandColors.momentumBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ] else ...[
              // Final step: Save Draft + Send Now
              OutlinedButton(
                onPressed: (_saving || _sending) ? null : () => _save(status: 'draft'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: BrandColors.unityBlue,
                  side: const BorderSide(color: BrandColors.unityBlue),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save Draft'),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: (_saving || _sending) ? null : _sendNow,
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send, size: 18),
                label: const Text('Send Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: BrandColors.sunriseGold,
                  foregroundColor: BrandColors.unityBlue,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // STEP 0 — Survey Details
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildStep0Details() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Form(
            key: _step0FormKey,
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: BrandColors.momentumBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.edit_note,
                            color: BrandColors.momentumBlue,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Text(
                            'Survey Details',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: BrandColors.unityBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Linked event badge
                    if (_hasEvent) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: BrandColors.momentumBlue.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: BrandColors.momentumBlue.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.event,
                              size: 18,
                              color: BrandColors.momentumBlue,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Linked to Event: ${widget.existingSurvey?.eventId ?? widget.eventId}',
                                style: const TextStyle(
                                  color: BrandColors.momentumBlue,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Title field
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: 'Survey Title',
                        hintText: 'e.g., Post-Event Feedback',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.title),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Title is required' : null,
                    ),
                    const SizedBox(height: 20),

                    // Description field
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Description (optional)',
                        hintText: 'Brief description of the survey purpose...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.description_outlined),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // STEP 1 — Questions Builder
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildStep1Questions() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Toolbar: Suggested Questions + Add Question ──
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Questions (${_questions.length})',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: BrandColors.unityBlue,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _showSuggestedQuestionsSheet,
                    icon: const Icon(Icons.lightbulb_outline, size: 18),
                    label: const Text('Suggestions'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: BrandColors.momentumBlue,
                      side: const BorderSide(color: BrandColors.momentumBlue),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _addQuestion,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BrandColors.momentumBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── Question Cards (Reorderable) ──
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

              const SizedBox(height: 24),

              // ── iMessage Preview ──
              _buildIMessagePreview(),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ── Suggested Questions Bottom Sheet ────────────────────────────────────

  void _showSuggestedQuestionsSheet() {
    String? selectedCategory;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, sheetSetState) {
            final filtered = selectedCategory == null
                ? SurveyQuestionSuggestions.all
                : SurveyQuestionSuggestions.byCategory(selectedCategory!);

            return Container(
              height: MediaQuery.of(ctx).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: BrandColors.sunriseGold.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.lightbulb,
                            color: BrandColors.sunriseGold,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Suggested Questions',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: BrandColors.unityBlue,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  // Category filter chips
                  SizedBox(
                    height: 42,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: const Text('All'),
                            selected: selectedCategory == null,
                            onSelected: (_) =>
                                sheetSetState(() => selectedCategory = null),
                            selectedColor: BrandColors.momentumBlue.withOpacity(0.15),
                            checkmarkColor: BrandColors.momentumBlue,
                            labelStyle: TextStyle(
                              color: selectedCategory == null
                                  ? BrandColors.momentumBlue
                                  : Colors.grey.shade700,
                              fontSize: 13,
                              fontWeight: selectedCategory == null
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                        ...SurveyQuestionSuggestions.categories.map((cat) {
                          final isSelected = selectedCategory == cat;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(cat),
                              selected: isSelected,
                              onSelected: (_) =>
                                  sheetSetState(() => selectedCategory = cat),
                              selectedColor:
                                  BrandColors.momentumBlue.withOpacity(0.15),
                              checkmarkColor: BrandColors.momentumBlue,
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? BrandColors.momentumBlue
                                    : Colors.grey.shade700,
                                fontSize: 13,
                                fontWeight:
                                    isSelected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Question list
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                        final suggestion = filtered[i];
                        return _buildSuggestionTile(ctx, suggestion);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSuggestionTile(BuildContext ctx, SuggestedQuestion suggestion) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(
          suggestion.text,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              _buildTypeBadge(suggestion.type),
              const SizedBox(width: 8),
              Text(
                suggestion.category,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.add_circle, color: BrandColors.momentumBlue),
          tooltip: 'Add to survey',
          onPressed: () {
            _addSuggestedQuestion(suggestion);
            Navigator.pop(ctx);
            _showSnack('Question added');
          },
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildTypeBadge(String type) {
    final label = _typeLabel(type);
    final color = _typeColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'yes_no':
        return 'Yes/No';
      case 'rating':
        return 'Rating';
      case 'multiple_choice':
        return 'Multiple Choice';
      case 'short_answer':
        return 'Short Answer';
      default:
        return type;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'yes_no':
        return BrandColors.success;
      case 'rating':
        return BrandColors.sunriseGold;
      case 'multiple_choice':
        return BrandColors.momentumBlue;
      case 'short_answer':
        return BrandColors.slateBlue;
      default:
        return Colors.grey;
    }
  }

  // ── Question Card ─────────────────────────────────────────────────────────

  Widget _buildQuestionCard(int index, {required Key key}) {
    final q = _questions[index];
    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: BrandColors.momentumBlue.withOpacity(0.15),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: drag handle, question number badge, delete
              Row(
                children: [
                  Icon(Icons.drag_handle, color: Colors.grey.shade500),
                  const SizedBox(width: 8),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: BrandColors.momentumBlue,
                    ),
                    child: Center(
                      child: Text(
                        'Q${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Question ${index + 1}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: BrandColors.unityBlue,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  if (_questions.length > 1)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
                      onPressed: () => _removeQuestion(index),
                      tooltip: 'Remove question',
                    ),
                ],
              ),
              const SizedBox(height: 14),

              // Question text
              TextFormField(
                controller: q.textController,
                decoration: InputDecoration(
                  labelText: 'Question text',
                  hintText: 'e.g., How would you rate the event?',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onChanged: (text) {
                  setState(() {});
                  // Debounced type suggestion
                  q._typeSuggestDebounce?.cancel();
                  q._typeSuggestDebounce = Timer(const Duration(milliseconds: 500), () {
                    if (!mounted) return;
                    final suggested = SurveyQuestionSuggestions.suggestType(text);
                    if (suggested != q.type && suggested != q.suggestedType) {
                      setState(() => q.suggestedType = suggested);
                    }
                  });
                },
              ),
              const SizedBox(height: 12),

              // Type dropdown + suggestion chip
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: q.type,
                      decoration: InputDecoration(
                        labelText: 'Question Type',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
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
                          setState(() {
                            q.type = v;
                            q.suggestedType = null;
                          });
                        }
                      },
                    ),
                  ),
                  // Intelligent type suggestion chip
                  if (q.suggestedType != null && q.suggestedType != q.type) ...[
                    const SizedBox(width: 10),
                    ActionChip(
                      avatar: const Icon(Icons.auto_awesome, size: 16, color: BrandColors.sunriseGold),
                      label: Text(
                        _typeLabel(q.suggestedType!),
                        style: const TextStyle(fontSize: 12),
                      ),
                      tooltip: 'Tap to use suggested type',
                      backgroundColor: BrandColors.sunriseGold.withOpacity(0.1),
                      side: BorderSide(color: BrandColors.sunriseGold.withOpacity(0.4)),
                      onPressed: () {
                        setState(() {
                          q.type = q.suggestedType!;
                          q.suggestedType = null;
                        });
                      },
                    ),
                  ],
                ],
              ),

              // Multiple choice options
              if (q.type == 'multiple_choice') ...[
                const SizedBox(height: 14),
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'Answer Options',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: BrandColors.unityBlue,
                  ),
                ),
                const SizedBox(height: 8),
                ...q.optionControllers.asMap().entries.map((entry) {
                  final oi = entry.key;
                  final oc = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey.shade400),
                          ),
                          child: Center(
                            child: Text(
                              '${oi + 1}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: oc,
                            decoration: InputDecoration(
                              hintText: 'Option ${oi + 1}',
                              isDense: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        if (q.optionControllers.length > 2)
                          IconButton(
                            icon: Icon(Icons.close, size: 18, color: Colors.grey.shade500),
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
                  style: TextButton.styleFrom(
                    foregroundColor: BrandColors.momentumBlue,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── iMessage Preview ──────────────────────────────────────────────────────

  Widget _buildIMessagePreview() {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade900.withOpacity(0.5), Colors.green.shade800.withOpacity(0.4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.chat_bubble_outline, size: 18, color: Colors.white),
                ),
                const SizedBox(width: 10),
                const Text(
                  'iMessage Preview',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
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

  // ════════════════════════════════════════════════════════════════════════════
  // STEP 2 — Recipients & Send
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildStep2Recipients() {
    return Column(
      children: [
        // Scheduling section (top card)
        _buildScheduleCard(),

        // Recipients area
        Expanded(
          child: _hasEvent
              ? _buildEventRecipientOptions()
              : RecipientSelectorWidget(
                  onRecipientsChanged: (phones) {
                    setState(() => _selectedPhones = phones);
                  },
                  initialPhones: _selectedPhones,
                ),
        ),
      ],
    );
  }

  // ── Schedule Card ──────────────────────────────────────────────────────────

  Widget _buildScheduleCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: BrandColors.momentumBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.schedule,
                  size: 20,
                  color: BrandColors.momentumBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Schedule (optional)',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: BrandColors.unityBlue,
                      ),
                    ),
                    if (_scheduledAt != null)
                      Text(
                        DateFormat('MMM d, yyyy - h:mm a').format(_scheduledAt!),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
              ),
              if (_scheduledAt != null)
                IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  tooltip: 'Remove schedule',
                  onPressed: () => setState(() => _scheduledAt = null),
                ),
              OutlinedButton(
                onPressed: _pickScheduleDateTime,
                style: OutlinedButton.styleFrom(
                  foregroundColor: BrandColors.momentumBlue,
                  side: const BorderSide(color: BrandColors.momentumBlue),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                child: Text(_scheduledAt == null ? 'Set Time' : 'Change'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickScheduleDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt ?? now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: _scheduledAt != null
          ? TimeOfDay.fromDateTime(_scheduledAt!)
          : TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (time == null || !mounted) return;

    setState(() {
      _scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  // ── Event Recipient Options (when eventId is set) ──────────────────────────

  Widget _buildEventRecipientOptions() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: BrandColors.momentumBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.people_alt,
                          color: BrandColors.momentumBlue,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Text(
                          'Event Recipients',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: BrandColors.unityBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Target audience radio
                  RadioListTile<String>(
                    value: 'all_attendees',
                    groupValue: _targetAudience,
                    onChanged: (v) {
                      if (v != null) setState(() => _targetAudience = v);
                    },
                    activeColor: BrandColors.momentumBlue,
                    title: const Text(
                      'All Attendees',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Send to everyone registered for the event',
                    ),
                    contentPadding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const Divider(height: 1),
                  RadioListTile<String>(
                    value: 'checked_in_only',
                    groupValue: _targetAudience,
                    onChanged: (v) {
                      if (v != null) setState(() => _targetAudience = v);
                    },
                    activeColor: BrandColors.momentumBlue,
                    title: const Text(
                      'Checked-In Only',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Only send to attendees who checked in',
                    ),
                    contentPadding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),

                  // Auto-send toggle
                  SwitchListTile(
                    title: const Text(
                      'Auto-send after event ends',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Automatically send when the event end time passes',
                    ),
                    value: _autoSend,
                    onChanged: (v) => setState(() => _autoSend = v),
                    activeColor: BrandColors.momentumBlue,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// _EditableQuestion — mutable helper for building questions in the form
// ═══════════════════════════════════════════════════════════════════════════════

class _EditableQuestion {
  final String key;
  final String? existingId;
  final TextEditingController textController;
  String type;
  List<TextEditingController> optionControllers;

  /// Populated by SurveyQuestionSuggestions.suggestType() after a debounce.
  String? suggestedType;

  Timer? _typeSuggestDebounce;

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
    _typeSuggestDebounce?.cancel();
    for (final c in optionControllers) {
      c.dispose();
    }
  }
}
