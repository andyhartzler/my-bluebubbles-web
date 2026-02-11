import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:bluebubbles/models/crm/survey_model.dart';
import 'package:bluebubbles/services/crm/survey_repository.dart';
import 'package:bluebubbles/screens/crm/survey_builder_screen.dart';
import 'package:bluebubbles/screens/crm/survey_results_widget.dart';

const _unityBlue = Color(0xFF273351);
const _momentumBlue = Color(0xFF32A6DE);
const _sunriseGold = Color(0xFFFDB813);
const _grassrootsGreen = Color(0xFF43A047);
const _actionRed = Color(0xFFE63946);

class SurveysScreen extends StatefulWidget {
  const SurveysScreen({super.key});

  @override
  State<SurveysScreen> createState() => _SurveysScreenState();
}

class _SurveysScreenState extends State<SurveysScreen> {
  final _repo = SurveyRepository();
  List<Survey> _surveys = [];
  bool _loading = true;
  String _filter = 'all'; // all, active, draft, completed

  @override
  void initState() {
    super.initState();
    _loadSurveys();
  }

  Future<void> _loadSurveys() async {
    setState(() => _loading = true);
    try {
      final status = _filter == 'all' ? null : _filter;
      final surveys = await _repo.fetchSurveys(status: status);
      if (mounted) {
        setState(() {
          _surveys = surveys;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading surveys: $e')),
        );
      }
    }
  }

  void _openBuilder({Survey? existing}) async {
    final result = await Navigator.of(context).push<Survey>(
      MaterialPageRoute(
        builder: (_) => SurveyBuilderScreen(existingSurvey: existing),
      ),
    );
    if (result != null) _loadSurveys();
  }

  void _openResults(Survey survey) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: Text(survey.title),
            backgroundColor: _unityBlue,
            foregroundColor: Colors.white,
          ),
          body: SurveyResultsWidget(
            surveyId: survey.id!,
            surveyTitle: survey.title,
          ),
        ),
      ),
    );
  }

  Future<void> _deleteSurvey(Survey survey) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Survey?'),
        content: Text('Delete "${survey.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _actionRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _repo.deleteSurvey(survey.id!);
      _loadSurveys();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        // ── Header ──
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Row(
            children: [
              const Icon(Icons.poll_outlined, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Surveys', style: theme.textTheme.headlineSmall),
              ),
              ElevatedButton.icon(
                onPressed: () => _openBuilder(),
                icon: const Icon(Icons.add),
                label: const Text('Create Survey'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _momentumBlue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),

        // ── Filters ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            children: [
              _FilterChip(
                label: 'All',
                selected: _filter == 'all',
                onTap: () {
                  setState(() => _filter = 'all');
                  _loadSurveys();
                },
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Active',
                selected: _filter == 'active',
                onTap: () {
                  setState(() => _filter = 'active');
                  _loadSurveys();
                },
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Draft',
                selected: _filter == 'draft',
                onTap: () {
                  setState(() => _filter = 'draft');
                  _loadSurveys();
                },
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Completed',
                selected: _filter == 'completed',
                onTap: () {
                  setState(() => _filter = 'completed');
                  _loadSurveys();
                },
              ),
            ],
          ),
        ),

        const Divider(),

        // ── Survey list ──
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _surveys.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.poll_outlined, size: 64, color: Colors.grey.shade600),
                          const SizedBox(height: 16),
                          const Text('No surveys yet'),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () => _openBuilder(),
                            icon: const Icon(Icons.add),
                            label: const Text('Create your first survey'),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadSurveys,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        itemCount: _surveys.length,
                        itemBuilder: (context, index) =>
                            _buildSurveyCard(_surveys[index]),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildSurveyCard(Survey survey) {
    final theme = Theme.of(context);
    final dateFmt = DateFormat('MMM d, y');
    final statusColor = _statusColor(survey.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (survey.status == 'draft') {
            _openBuilder(existing: survey);
          } else {
            _openResults(survey);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Status indicator
              Container(
                width: 4,
                height: 60,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 16),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            survey.title,
                            style: theme.textTheme.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            survey.status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (survey.eventId != null) ...[
                          const Icon(Icons.event, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            'Event-linked',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Icon(Icons.help_outline, size: 14, color: Colors.grey.shade400),
                        const SizedBox(width: 4),
                        Text(
                          '${survey.questions.length} questions',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                        ),
                        const SizedBox(width: 12),
                        if (survey.sessionCount > 0) ...[
                          Icon(Icons.people, size: 14, color: Colors.grey.shade400),
                          const SizedBox(width: 4),
                          Text(
                            '${survey.completedCount}/${survey.sessionCount} completed',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                          ),
                        ],
                      ],
                    ),
                    if (survey.createdAt != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Created ${dateFmt.format(survey.createdAt!)}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ],
                ),
              ),

              // Actions
              PopupMenuButton<String>(
                onSelected: (action) {
                  switch (action) {
                    case 'edit':
                      _openBuilder(existing: survey);
                      break;
                    case 'results':
                      _openResults(survey);
                      break;
                    case 'delete':
                      _deleteSurvey(survey);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  if (survey.status != 'draft')
                    const PopupMenuItem(value: 'results', child: Text('View Results')),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active':
        return _grassrootsGreen;
      case 'draft':
        return Colors.grey;
      case 'paused':
        return _sunriseGold;
      case 'completed':
        return _momentumBlue;
      default:
        return Colors.grey;
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? _momentumBlue.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? _momentumBlue : Colors.grey.shade600,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: selected ? _momentumBlue : Colors.grey.shade400,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
