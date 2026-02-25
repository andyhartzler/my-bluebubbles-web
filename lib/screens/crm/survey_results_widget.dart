import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/models/crm/survey_model.dart';
import 'package:bluebubbles/services/crm/survey_export_service.dart';
import 'package:bluebubbles/services/crm/survey_repository.dart';

const _brandedGreen = Color(0xFF43A047);
const _brandedRed = Color(0xFFE63946);

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
  bool _exporting = false;
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

  // ── Export methods ──────────────────────────────────────────────────────────

  Future<void> _exportPdf() async {
    setState(() => _exporting = true);
    try {
      final sessions = await _repo.fetchSessions(widget.surveyId);
      final pdfBytes = await SurveyExportService.generatePdf(
        surveyTitle: widget.surveyTitle,
        summary: _summary!,
        sessions: sessions,
      );
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: '${widget.surveyTitle.replaceAll(' ', '_')}_results.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _exportExcel() async {
    setState(() => _exporting = true);
    try {
      final sessions = await _repo.fetchSessions(widget.surveyId);
      final excelBytes = await SurveyExportService.generateExcel(
        surveyTitle: widget.surveyTitle,
        summary: _summary!,
        sessions: sessions,
      );
      await Printing.sharePdf(
        bytes: excelBytes,
        filename: '${widget.surveyTitle.replaceAll(' ', '_')}_results.xlsx',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildErrorState();
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
            _buildStatsDashboard(s),
            const SizedBox(height: 4),

            // ── Export row ──
            _buildExportRow(),
            const SizedBox(height: 16),

            // ── Respondent list ──
            if (s.sessionDetails.isNotEmpty) ...[
              _buildRespondentList(s),
              const SizedBox(height: 16),
            ],

            // ── Per-question breakdown ──
            if (s.questionSummaries.isEmpty)
              _buildEmptyState()
            else
              ...s.questionSummaries.map((qs) => _buildQuestionResult(qs)),
          ],
        ),
      ),
    );
  }

  // ── Error state ────────────────────────────────────────────────────────────

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.error_outline, size: 48, color: Colors.red),
          ),
          const SizedBox(height: 16),
          const Text(
            'Error loading results',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: BrandColors.unityBlue,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _error ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: BrandColors.unityBlue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: BrandColors.momentumBlue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.poll_outlined,
                size: 48,
                color: BrandColors.momentumBlue.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No responses yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: BrandColors.unityBlue,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Results will appear here once respondents start answering.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  // ── Stats Dashboard — Tier 1: Hero Metrics ─────────────────────────────────

  Widget _buildStatsDashboard(SurveyResultsSummary s) {
    return Column(
      children: [
        // Tier 1: Hero metrics
        Row(
          children: [
            Expanded(child: _buildHeroCard(
              label: 'Sent',
              value: '${s.totalSent}',
              icon: Icons.send_rounded,
              iconColor: BrandColors.momentumBlue,
            )),
            const SizedBox(width: 12),
            Expanded(child: _buildCircularProgressCard(
              label: 'Response Rate',
              value: s.responseRate,
              color: BrandColors.momentumBlue,
            )),
            const SizedBox(width: 12),
            Expanded(child: _buildCircularProgressCard(
              label: 'Completion',
              value: s.completionRate,
              color: BrandColors.success,
            )),
          ],
        ),
        const SizedBox(height: 12),
        // Tier 2: Breakdown chips
        Row(
          children: [
            Expanded(child: _buildBreakdownChip(
              label: 'Completed',
              count: s.totalCompleted,
              color: BrandColors.success,
            )),
            const SizedBox(width: 8),
            Expanded(child: _buildBreakdownChip(
              label: 'In Progress',
              count: s.totalInProgress,
              color: BrandColors.momentumBlue,
            )),
            const SizedBox(width: 8),
            Expanded(child: _buildBreakdownChip(
              label: 'Opted Out',
              count: s.totalOptedOut,
              color: BrandColors.error,
            )),
            const SizedBox(width: 8),
            Expanded(child: _buildBreakdownChip(
              label: 'No Response',
              count: s.totalNoResponse,
              color: Colors.grey,
            )),
          ],
        ),
      ],
    );
  }

  Widget _buildHeroCard({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: BrandColors.unityBlue,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircularProgressCard({
    required String label,
    required double value,
    required Color color,
  }) {
    final pct = (value * 100).toStringAsFixed(0);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 56,
                  height: 56,
                  child: CircularProgressIndicator(
                    value: value,
                    strokeWidth: 5,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation(color),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Text(
                  '$pct%',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: BrandColors.unityBlue,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownChip({
    required String label,
    required int count,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ── Export row ──────────────────────────────────────────────────────────────

  Widget _buildExportRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton.icon(
            onPressed: _exporting ? null : _exportPdf,
            icon: const Icon(Icons.picture_as_pdf, size: 18),
            label: const Text('Export PDF'),
            style: OutlinedButton.styleFrom(
              foregroundColor: BrandColors.unityBlue,
              side: BorderSide(color: BrandColors.unityBlue.withOpacity(0.3)),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _exporting ? null : _exportExcel,
            icon: const Icon(Icons.table_chart, size: 18),
            label: const Text('Export Excel'),
            style: OutlinedButton.styleFrom(
              foregroundColor: BrandColors.unityBlue,
              side: BorderSide(color: BrandColors.unityBlue.withOpacity(0.3)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Respondent List (Tier 3) ──────────────────────────────────────────────

  Widget _buildRespondentList(SurveyResultsSummary s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Respondents',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: BrandColors.unityBlue,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: BrandColors.momentumBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${s.sessionDetails.length}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: BrandColors.momentumBlue,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...s.sessionDetails.map((detail) => _buildRespondentCard(detail, s)),
      ],
    );
  }

  Widget _buildRespondentCard(SurveySessionDetail detail, SurveyResultsSummary summary) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          leading: _buildRespondentAvatar(detail),
          title: Text(
            detail.displayName,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: BrandColors.unityBlue,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (detail.memberName != null)
                Text(
                  detail.memberPhone ?? detail.session.phoneE164,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: detail.progress,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation(
                          _statusColor(detail.displayStatus),
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${detail.questionsAnswered}/${detail.totalQuestions}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          trailing: _buildStatusBadge(detail.displayStatus),
          children: [
            if (detail.responses.isNotEmpty)
              ...detail.responses.map((r) {
                final question = summary.questionSummaries
                    .where((qs) => qs.question.id == r.questionId)
                    .firstOrNull;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: BrandColors.momentumBlue.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${question?.question.questionOrder ?? '?'}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: BrandColors.momentumBlue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              question?.question.questionText ?? 'Question',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              r.parsedResponse ?? r.rawResponse ?? '(empty)',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: BrandColors.unityBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            if (detail.responses.isEmpty)
              Text(
                detail.session.status == 'opted_out'
                    ? 'Opted out before answering'
                    : 'No responses yet',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRespondentAvatar(SurveySessionDetail detail) {
    final name = detail.memberName ?? '';
    final url = detail.profilePhotoUrl;
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: 20,
        backgroundImage: CachedNetworkImageProvider(url),
        backgroundColor: BrandColors.unityBlue.withOpacity(0.1),
      );
    }
    return CircleAvatar(
      radius: 20,
      backgroundColor: BrandColors.unityBlue.withOpacity(0.1),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
          color: BrandColors.unityBlue,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Completed':
        return BrandColors.success;
      case 'In Progress':
        return BrandColors.momentumBlue;
      case 'Opted Out':
        return BrandColors.error;
      case 'No Response':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  // ── Question result card ───────────────────────────────────────────────────

  Widget _buildQuestionResult(QuestionResultSummary qs) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: BrandColors.unityBlue.withOpacity(0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Q badge — filled circle with branded background
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: BrandColors.momentumBlue,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${qs.question.questionOrder}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    qs.question.questionText,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: BrandColors.unityBlue,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: BrandColors.momentumBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${qs.responseCount} responses',
                    style: TextStyle(fontSize: 11, color: BrandColors.unityBlue.withOpacity(0.7)),
                  ),
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

  // ── Yes / No bar ───────────────────────────────────────────────────────────

  Widget _buildYesNoBar(QuestionResultSummary qs) {
    final dist = qs.distribution;
    final yesCount = dist['yes'] ?? 0;
    final noCount = dist['no'] ?? 0;
    final total = yesCount + noCount;
    if (total == 0) {
      return const Text('No responses yet',
          style: TextStyle(color: Colors.grey, fontSize: 13));
    }

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
                      color: _brandedGreen,
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
                      color: _brandedRed,
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
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
      ],
    );
  }

  // ── Rating display ─────────────────────────────────────────────────────────

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
                  color: BrandColors.sunriseGold,
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
                        color: BrandColors.sunriseGold,
                        size: 20,
                      );
                    }),
                  ),
                  Text(
                    '$total responses',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
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
                SizedBox(
                  width: 16,
                  child: Text('$rating', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation(BrandColors.sunriseGold),
                      minHeight: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 30,
                  child: Text(
                    '$count',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
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

  // ── Bar chart (multiple choice) ────────────────────────────────────────────

  Widget _buildBarChart(QuestionResultSummary qs) {
    final dist = qs.distribution;
    final total = qs.responseCount;
    if (total == 0) {
      return const Text('No responses yet',
          style: TextStyle(color: Colors.grey, fontSize: 13));
    }

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
                  style: const TextStyle(fontSize: 13, color: BrandColors.unityBlue),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation(BrandColors.momentumBlue),
                    minHeight: 20,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 50,
                child: Text(
                  '${entry.value} (${(pct * 100).toStringAsFixed(0)}%)',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── Short answer list ──────────────────────────────────────────────────────

  Widget _buildShortAnswerList(QuestionResultSummary qs) {
    if (qs.responses.isEmpty) {
      return const Text('No responses yet',
          style: TextStyle(color: Colors.grey, fontSize: 13));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children:
          qs.responses.take(10).map((r) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                r.rawResponse ?? r.parsedResponse ?? '(empty)',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
              ),
            );
          }).toList(),
    );
  }
}
