import 'package:flutter/material.dart';

import 'package:bluebubbles/models/crm/survey_model.dart';
import 'package:bluebubbles/services/crm/survey_repository.dart';

const _unityBlue = Color(0xFF273351);
const _momentumBlue = Color(0xFF32A6DE);
const _sunriseGold = Color(0xFFFDB813);
const _grassrootsGreen = Color(0xFF43A047);
const _actionRed = Color(0xFFE63946);

class SurveyResultsWidget extends StatefulWidget {
  final String surveyId;
  final String surveyTitle;

  const SurveyResultsWidget({
    super.key,
    required this.surveyId,
    required this.surveyTitle,
  });

  @override
  State<SurveyResultsWidget> createState() => _SurveyResultsWidgetState();
}

class _SurveyResultsWidgetState extends State<SurveyResultsWidget> {
  final _repo = SurveyRepository();
  SurveyResultsSummary? _summary;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final summary = await _repo.fetchResultsSummary(widget.surveyId);
      if (mounted) {
        setState(() {
          _summary = summary;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Error loading results: $_error'),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final s = _summary!;

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Summary cards ──
            _buildSummaryRow(s),
            const SizedBox(height: 24),

            // ── Per-question breakdown ──
            if (s.questionSummaries.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Text('No responses yet'),
                ),
              )
            else
              ...s.questionSummaries.map((qs) => _buildQuestionResult(qs)),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(SurveyResultsSummary s) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _SummaryCard(
          label: 'Sent',
          value: '${s.totalSent}',
          icon: Icons.send,
          color: _momentumBlue,
        ),
        _SummaryCard(
          label: 'Responded',
          value: '${s.totalResponded}',
          icon: Icons.reply,
          color: _sunriseGold,
        ),
        _SummaryCard(
          label: 'Completed',
          value: '${s.totalCompleted}',
          icon: Icons.check_circle,
          color: _grassrootsGreen,
        ),
        _SummaryCard(
          label: 'Response Rate',
          value: '${(s.responseRate * 100).toStringAsFixed(0)}%',
          icon: Icons.trending_up,
          color: _momentumBlue,
        ),
        _SummaryCard(
          label: 'Opted Out',
          value: '${s.totalOptedOut}',
          icon: Icons.block,
          color: _actionRed,
        ),
      ],
    );
  }

  Widget _buildQuestionResult(QuestionResultSummary qs) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _momentumBlue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Q${qs.question.questionOrder}',
                    style: TextStyle(
                      color: _momentumBlue,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    qs.question.questionText,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Text(
                  '${qs.responseCount} responses',
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildQuestionVisualization(qs),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionVisualization(QuestionResultSummary qs) {
    switch (qs.question.questionType) {
      case 'yes_no':
        return _buildYesNoBar(qs);
      case 'rating':
        return _buildRatingDisplay(qs);
      case 'multiple_choice':
        return _buildBarChart(qs);
      case 'short_answer':
        return _buildShortAnswerList(qs);
      default:
        return _buildShortAnswerList(qs);
    }
  }

  Widget _buildYesNoBar(QuestionResultSummary qs) {
    final dist = qs.distribution;
    final yesCount = dist['yes'] ?? 0;
    final noCount = dist['no'] ?? 0;
    final total = yesCount + noCount;
    if (total == 0) return const Text('No responses yet');

    final yesPct = yesCount / total;
    final noPct = noCount / total;

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 32,
            child: Row(
              children: [
                if (yesPct > 0)
                  Expanded(
                    flex: (yesPct * 100).round(),
                    child: Container(
                      color: _grassrootsGreen,
                      alignment: Alignment.center,
                      child: Text(
                        'Yes ${(yesPct * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                if (noPct > 0)
                  Expanded(
                    flex: (noPct * 100).round(),
                    child: Container(
                      color: _actionRed,
                      alignment: Alignment.center,
                      child: Text(
                        'No ${(noPct * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$yesCount Yes, $noCount No',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildRatingDisplay(QuestionResultSummary qs) {
    final avg = qs.averageRating;
    final dist = qs.distribution;
    final total = qs.responseCount;

    return Column(
      children: [
        if (avg != null) ...[
          Row(
            children: [
              Text(
                avg.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: _sunriseGold,
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: List.generate(5, (i) {
                      return Icon(
                        i < avg.round() ? Icons.star : Icons.star_border,
                        color: _sunriseGold,
                        size: 20,
                      );
                    }),
                  ),
                  Text(
                    '$total responses',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        // Distribution bars
        ...List.generate(5, (i) {
          final rating = 5 - i;
          final count = dist['$rating'] ?? 0;
          final pct = total > 0 ? count / total : 0.0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                SizedBox(width: 16, child: Text('$rating', style: const TextStyle(fontSize: 12))),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      backgroundColor: Colors.grey.shade800,
                      valueColor: const AlwaysStoppedAnimation(_sunriseGold),
                      minHeight: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 30,
                  child: Text(
                    '$count',
                    style: const TextStyle(fontSize: 12),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildBarChart(QuestionResultSummary qs) {
    final dist = qs.distribution;
    final total = qs.responseCount;
    if (total == 0) return const Text('No responses yet');

    final entries = dist.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: entries.map((entry) {
        final pct = entry.value / total;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(
                width: 120,
                child: Text(
                  entry.key,
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: Colors.grey.shade800,
                    valueColor: const AlwaysStoppedAnimation(_momentumBlue),
                    minHeight: 20,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 50,
                child: Text(
                  '${entry.value} (${(pct * 100).toStringAsFixed(0)}%)',
                  style: const TextStyle(fontSize: 11),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildShortAnswerList(QuestionResultSummary qs) {
    if (qs.responses.isEmpty) return const Text('No responses yet');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children:
          qs.responses.take(10).map((r) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade700),
              ),
              child: Text(
                r.rawResponse ?? r.parsedResponse ?? '(empty)',
                style: const TextStyle(fontSize: 14),
              ),
            );
          }).toList(),
    );
  }
}

// ── Summary card widget ─────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }
}
