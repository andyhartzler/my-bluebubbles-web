import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:universal_html/html.dart' as html;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/models/crm/survey_model.dart';
import 'package:bluebubbles/screens/crm/member_detail_screen.dart';
import 'package:bluebubbles/services/crm/member_repository.dart';
import 'package:bluebubbles/services/crm/survey_export_service.dart';
import 'package:bluebubbles/services/crm/survey_repository.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

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
  final _memberRepo = MemberRepository();
  final _supabase = CRMSupabaseService();
  SurveyResultsSummary? _summary;
  bool _loading = true;
  bool _exporting = false;
  bool _closing = false;
  bool _resending = false;
  String? _error;

  // Event name resolution
  String? _eventTitle;

  // Respondent filtering & pagination
  String _respondentFilter = 'all'; // all, completed, in_progress, opted_out, no_response
  String _respondentSearch = '';
  final _respondentSearchController = TextEditingController();
  static const _respondentPageSize = 25;
  int _respondentDisplayCount = _respondentPageSize;

  // Short answer show all toggles (per question id)
  final Set<String> _expandedShortAnswers = {};

  // Realtime subscriptions
  RealtimeChannel? _responsesChannel;
  RealtimeChannel? _sessionsChannel;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _respondentSearchController.dispose();
    _unsubscribeRealtime();
    super.dispose();
  }

  // ── Realtime ──────────────────────────────────────────────────────────────

  void _subscribeRealtime() {
    try {
      final client = _supabase.client;

      _responsesChannel = client.channel('survey_responses_${widget.surveyId}')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'survey_responses',
          callback: (payload) {
            _onRealtimeChange();
          },
        )
        .subscribe();

      _sessionsChannel = client.channel('survey_sessions_${widget.surveyId}')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'survey_sessions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'survey_id',
            value: widget.surveyId,
          ),
          callback: (payload) {
            _onRealtimeChange();
          },
        )
        .subscribe();
    } catch (e) {
      debugPrint('Failed to subscribe to realtime: $e');
    }
  }

  void _unsubscribeRealtime() {
    try {
      _responsesChannel?.unsubscribe();
      _sessionsChannel?.unsubscribe();
    } catch (_) {}
  }

  Timer? _debounceTimer;
  void _onRealtimeChange() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) _load(silent: true);
    });
  }

  // ── Data ──────────────────────────────────────────────────────────────────

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final summary = await _repo.fetchResultsSummary(widget.surveyId);

      // Resolve event name if needed
      if (_eventTitle == null) {
        final survey = await _repo.fetchSurvey(widget.surveyId);
        if (survey?.eventId != null) {
          _eventTitle = await _repo.fetchEventTitle(survey!.eventId!);
        }
      }

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
      final filename = '${widget.surveyTitle.replaceAll(' ', '_')}_results.xlsx';
      final blob = html.Blob([excelBytes],
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..style.display = 'none';
      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();
      html.Url.revokeObjectUrl(url);
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

  // ── Close Survey ──────────────────────────────────────────────────────────

  Future<void> _closeSurvey() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Close Survey?'),
        content: const Text(
          'This will mark all active sessions as completed and prevent new responses. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: BrandColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Close Survey'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _closing = true);
    try {
      await _repo.closeSurvey(widget.surveyId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Survey closed successfully')),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error closing survey: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _closing = false);
    }
  }

  // ── Resend to Non-Responders ──────────────────────────────────────────────

  Future<void> _resendToNonResponders() async {
    setState(() => _resending = true);
    try {
      final phones = await _repo.getNonResponderPhones(widget.surveyId);
      if (phones.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No non-responders to resend to')),
          );
        }
        return;
      }

      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Resend Survey?'),
          content: Text(
            'This will resend the survey to ${phones.length} '
            'respondent${phones.length == 1 ? '' : 's'} who have not yet responded.',
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
              child: const Text('Resend'),
            ),
          ],
        ),
      );
      if (confirm != true) return;

      await _repo.prepareSurveySessions(widget.surveyId, phoneList: phones);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Resent survey to ${phones.length} non-responders')),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error resending: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  Future<void> _navigateToMemberProfile(String memberId) async {
    try {
      final member = await _memberRepo.getMemberById(memberId);
      if (member != null && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => MemberDetailScreen(member: member)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load member: $e')),
        );
      }
    }
  }

  // ── Respondent filtering ──────────────────────────────────────────────────

  List<SurveySessionDetail> get _filteredRespondents {
    if (_summary == null) return [];
    var list = _summary!.sessionDetails;

    // Status filter
    switch (_respondentFilter) {
      case 'completed':
        list = list.where((d) => d.session.status == 'completed').toList();
        break;
      case 'in_progress':
        list = list.where((d) => d.session.status == 'active' && d.questionsAnswered > 0).toList();
        break;
      case 'opted_out':
        list = list.where((d) => d.session.status == 'opted_out').toList();
        break;
      case 'no_response':
        list = list.where((d) => d.session.status == 'active' && d.questionsAnswered == 0).toList();
        break;
    }

    // Text search
    if (_respondentSearch.isNotEmpty) {
      final q = _respondentSearch.toLowerCase();
      list = list.where((d) {
        final name = d.displayName.toLowerCase();
        final phone = d.memberPhone?.toLowerCase() ?? d.session.phoneE164.toLowerCase();
        return name.contains(q) || phone.contains(q);
      }).toList();
    }

    return list;
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
            // ── Event name badge ──
            if (_eventTitle != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: BrandColors.sunriseGold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: BrandColors.sunriseGold.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.event, size: 16, color: BrandColors.sunriseGold),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        _eventTitle!,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: BrandColors.unityBlue,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // ── Summary cards (responsive) ──
            _buildStatsDashboard(s),
            const SizedBox(height: 4),

            // ── Action row: Export + Close + Resend ──
            _buildActionRow(),
            const SizedBox(height: 16),

            // ── Respondent list ──
            if (s.sessionDetails.isNotEmpty) ...[
              _buildRespondentSection(s),
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

  // ── Stats Dashboard (responsive) ──────────────────────────────────────────

  Widget _buildStatsDashboard(SurveyResultsSummary s) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 600;

        final heroCards = [
          _buildHeroCard(
            label: 'Sent',
            value: '${s.totalSent}',
            icon: Icons.send_rounded,
            iconColor: BrandColors.momentumBlue,
          ),
          _buildCircularProgressCard(
            label: 'Response Rate',
            value: s.responseRate,
            color: BrandColors.momentumBlue,
          ),
          _buildCircularProgressCard(
            label: 'Completion',
            value: s.completionRate,
            color: BrandColors.success,
          ),
        ];

        final breakdownChips = [
          _buildBreakdownChip(label: 'Completed', count: s.totalCompleted, color: BrandColors.success),
          _buildBreakdownChip(label: 'In Progress', count: s.totalInProgress, color: BrandColors.momentumBlue),
          _buildBreakdownChip(label: 'Opted Out', count: s.totalOptedOut, color: BrandColors.error),
          _buildBreakdownChip(label: 'No Response', count: s.totalNoResponse, color: Colors.grey),
        ];

        if (isCompact) {
          return Column(
            children: [
              // Hero cards as wrap
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: heroCards.map((c) => SizedBox(
                  width: (constraints.maxWidth - 16) / 2,
                  child: c,
                )).toList(),
              ),
              const SizedBox(height: 12),
              // Breakdown chips as wrap
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: breakdownChips.map((c) => SizedBox(
                  width: (constraints.maxWidth - 8) / 2,
                  child: c,
                )).toList(),
              ),
            ],
          );
        }

        // Desktop layout
        return Column(
          children: [
            Row(
              children: [
                Expanded(child: heroCards[0]),
                const SizedBox(width: 12),
                Expanded(child: heroCards[1]),
                const SizedBox(width: 12),
                Expanded(child: heroCards[2]),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: breakdownChips[0]),
                const SizedBox(width: 8),
                Expanded(child: breakdownChips[1]),
                const SizedBox(width: 8),
                Expanded(child: breakdownChips[2]),
                const SizedBox(width: 8),
                Expanded(child: breakdownChips[3]),
              ],
            ),
          ],
        );
      },
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

  // ── Action row (Export + Close + Resend) ───────────────────────────────────

  Widget _buildActionRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.end,
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
          OutlinedButton.icon(
            onPressed: _exporting ? null : _exportExcel,
            icon: const Icon(Icons.table_chart, size: 18),
            label: const Text('Export Excel'),
            style: OutlinedButton.styleFrom(
              foregroundColor: BrandColors.unityBlue,
              side: BorderSide(color: BrandColors.unityBlue.withOpacity(0.3)),
            ),
          ),
          if (_summary != null && _summary!.totalNoResponse > 0)
            OutlinedButton.icon(
              onPressed: _resending ? null : _resendToNonResponders,
              icon: _resending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.replay, size: 18),
              label: Text(_resending ? 'Resending...' : 'Resend to Non-Responders'),
              style: OutlinedButton.styleFrom(
                foregroundColor: BrandColors.momentumBlue,
                side: BorderSide(color: BrandColors.momentumBlue.withOpacity(0.3)),
              ),
            ),
          if (_summary != null && (_summary!.totalInProgress > 0 || _summary!.totalNoResponse > 0))
            ElevatedButton.icon(
              onPressed: _closing ? null : _closeSurvey,
              icon: _closing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.lock_outline, size: 18),
              label: Text(_closing ? 'Closing...' : 'Close Survey'),
              style: ElevatedButton.styleFrom(
                backgroundColor: BrandColors.error,
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  // ── Respondent Section (filter chips + search + paginated list) ────────────

  Widget _buildRespondentSection(SurveyResultsSummary s) {
    final filtered = _filteredRespondents;
    final displayList = filtered.take(_respondentDisplayCount).toList();
    final hasMore = filtered.length > _respondentDisplayCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
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
                '${filtered.length}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: BrandColors.momentumBlue,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Search field
        TextField(
          controller: _respondentSearchController,
          decoration: InputDecoration(
            hintText: 'Search respondents...',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _respondentSearch.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _respondentSearchController.clear();
                      setState(() {
                        _respondentSearch = '';
                        _respondentDisplayCount = _respondentPageSize;
                      });
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
          onChanged: (v) {
            setState(() {
              _respondentSearch = v;
              _respondentDisplayCount = _respondentPageSize;
            });
          },
        ),
        const SizedBox(height: 8),

        // Filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip('All', 'all', s.sessionDetails.length),
              const SizedBox(width: 6),
              _buildFilterChip('Completed', 'completed', s.totalCompleted),
              const SizedBox(width: 6),
              _buildFilterChip('In Progress', 'in_progress', s.totalInProgress),
              const SizedBox(width: 6),
              _buildFilterChip('Opted Out', 'opted_out', s.totalOptedOut),
              const SizedBox(width: 6),
              _buildFilterChip('No Response', 'no_response', s.totalNoResponse),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Paginated respondent list using ListView.builder in a constrained box
        if (displayList.isEmpty)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Text(
                'No respondents match the current filter',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              ),
            ),
          )
        else ...[
          // Use a SizedBox with a ListView.builder for lazy rendering
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: displayList.length <= 5
                  ? displayList.length * 120.0
                  : 600,
            ),
            child: ListView.builder(
              shrinkWrap: displayList.length <= 5,
              physics: displayList.length <= 5
                  ? const NeverScrollableScrollPhysics()
                  : const AlwaysScrollableScrollPhysics(),
              itemCount: displayList.length,
              itemBuilder: (context, index) {
                return _buildRespondentCard(displayList[index], s);
              },
            ),
          ),
          if (hasMore)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _respondentDisplayCount += _respondentPageSize;
                    });
                  },
                  icon: const Icon(Icons.expand_more),
                  label: Text('Show More (${filtered.length - _respondentDisplayCount} remaining)'),
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildFilterChip(String label, String filterValue, int count) {
    final isSelected = _respondentFilter == filterValue;
    return FilterChip(
      label: Text('$label ($count)'),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _respondentFilter = filterValue;
          _respondentDisplayCount = _respondentPageSize;
        });
      },
      selectedColor: BrandColors.momentumBlue.withOpacity(0.15),
      checkmarkColor: BrandColors.momentumBlue,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        color: isSelected ? BrandColors.momentumBlue : Colors.grey.shade700,
      ),
      backgroundColor: Colors.white,
      side: BorderSide(
        color: isSelected ? BrandColors.momentumBlue : Colors.grey.shade300,
      ),
      visualDensity: VisualDensity.compact,
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
          leading: GestureDetector(
            onTap: detail.memberId != null
                ? () => _navigateToMemberProfile(detail.memberId!)
                : null,
            child: _buildRespondentAvatar(detail),
          ),
          title: GestureDetector(
            onTap: detail.memberId != null
                ? () => _navigateToMemberProfile(detail.memberId!)
                : null,
            child: Text(
              detail.displayName,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: BrandColors.unityBlue,
              ),
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
            // View Member Profile button
            if (detail.memberId != null) ...[
              const Divider(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _navigateToMemberProfile(detail.memberId!),
                  icon: const Icon(Icons.person, size: 16, color: BrandColors.momentumBlue),
                  label: const Text(
                    'View Member Profile',
                    style: TextStyle(color: BrandColors.momentumBlue, fontSize: 13),
                  ),
                ),
              ),
            ],
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
                // Q badge
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
      case 'true_false':
        return _buildTrueFalseBar(qs);
      case 'rating':
        return _buildRatingDisplay(qs);
      case 'multiple_choice':
        return _buildBarChart(qs);
      case 'multi_select':
        return _buildMultiSelectChart(qs);
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

  // ── True / False bar ─────────────────────────────────────────────────────────

  Widget _buildTrueFalseBar(QuestionResultSummary qs) {
    final dist = qs.distribution;
    final trueCount = dist['true'] ?? 0;
    final falseCount = dist['false'] ?? 0;
    final total = trueCount + falseCount;
    if (total == 0) {
      return const Text('No responses yet',
          style: TextStyle(color: Colors.grey, fontSize: 13));
    }

    final truePct = trueCount / total;
    final falsePct = falseCount / total;

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 32,
            child: Row(
              children: [
                if (truePct > 0)
                  Expanded(
                    flex: (truePct * 100).round(),
                    child: Container(
                      color: BrandColors.momentumBlue,
                      alignment: Alignment.center,
                      child: Text(
                        'True ${(truePct * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                if (falsePct > 0)
                  Expanded(
                    flex: (falsePct * 100).round(),
                    child: Container(
                      color: BrandColors.slateBlue,
                      alignment: Alignment.center,
                      child: Text(
                        'False ${(falsePct * 100).toStringAsFixed(0)}%',
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
          '$trueCount True, $falseCount False',
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
    final maxRating = qs.question.ratingMax ?? 5;

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
                    children: List.generate(maxRating.clamp(1, 10), (i) {
                      return Icon(
                        i < avg.round() ? Icons.star : Icons.star_border,
                        color: BrandColors.sunriseGold,
                        size: maxRating > 5 ? 16 : 20,
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
        ...List.generate(maxRating, (i) {
          final rating = maxRating - i;
          final count = dist['$rating'] ?? 0;
          final pct = total > 0 ? count / total : 0.0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                SizedBox(
                  width: maxRating > 5 ? 24 : 16,
                  child: Text('$rating',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      backgroundColor: Colors.grey.shade200,
                      valueColor:
                          const AlwaysStoppedAnimation(BrandColors.sunriseGold),
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

  // ── Bar chart (multiple choice) — flexible labels ──────────────────────────

  Widget _buildBarChart(QuestionResultSummary qs) {
    final dist = qs.distribution;
    final total = qs.responseCount;
    if (total == 0) {
      return const Text('No responses yet',
          style: TextStyle(color: Colors.grey, fontSize: 13));
    }

    final entries = dist.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 400;

        return Column(
          children: entries.map((entry) {
            final pct = entry.value / total;
            final barAndCount = Row(
              children: [
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
            );

            if (isCompact) {
              // Stacked: label above bar
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.key,
                      style: const TextStyle(fontSize: 13, color: BrandColors.unityBlue),
                    ),
                    const SizedBox(height: 4),
                    barAndCount,
                  ],
                ),
              );
            }

            // Desktop: label + bar side by side with flexible label
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Flexible(
                    flex: 2,
                    child: Text(
                      entry.key,
                      style: const TextStyle(fontSize: 13, color: BrandColors.unityBlue),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 5,
                    child: barAndCount,
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ── Multi-select chart — flexible labels + note ────────────────────────────

  Widget _buildMultiSelectChart(QuestionResultSummary qs) {
    final total = qs.responseCount;
    if (total == 0) {
      return const Text('No responses yet',
          style: TextStyle(color: Colors.grey, fontSize: 13));
    }

    // Multi-select responses are JSON arrays — count each option
    final optionCounts = <String, int>{};
    for (final r in qs.responses) {
      final parsed = r.parsedResponse ?? '';
      List<String> selected = [];
      if (parsed.startsWith('[')) {
        try {
          selected = parsed
              .replaceAll(RegExp(r'[\[\]"]'), '')
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();
        } catch (_) {
          selected = [parsed];
        }
      } else {
        selected = [parsed];
      }
      for (final opt in selected) {
        optionCounts[opt] = (optionCounts[opt] ?? 0) + 1;
      }
    }

    final entries = optionCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 400;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.checklist, size: 16, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Text(
                    '$total respondents \u00B7 multiple selections',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            ...entries.map((entry) {
              final pct = entry.value / total;
              final barAndCount = Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: const AlwaysStoppedAnimation(Color(0xFF8B5CF6)),
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
              );

              if (isCompact) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key,
                        style: const TextStyle(fontSize: 13, color: BrandColors.unityBlue),
                      ),
                      const SizedBox(height: 4),
                      barAndCount,
                    ],
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Flexible(
                      flex: 2,
                      child: Text(
                        entry.key,
                        style: const TextStyle(fontSize: 13, color: BrandColors.unityBlue),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 5,
                      child: barAndCount,
                    ),
                  ],
                ),
              );
            }),
            // Multi-select note
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Percentages may exceed 100% as respondents could select multiple options.',
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey.shade500,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Short answer list — show all / show less toggle ────────────────────────

  Widget _buildShortAnswerList(QuestionResultSummary qs) {
    if (qs.responses.isEmpty) {
      return const Text('No responses yet',
          style: TextStyle(color: Colors.grey, fontSize: 13));
    }

    final summary = _summary;
    final questionId = qs.question.id ?? '';
    final isExpanded = _expandedShortAnswers.contains(questionId);
    final displayResponses = isExpanded ? qs.responses : qs.responses.take(5).toList();
    final hasMore = qs.responses.length > 5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...displayResponses.map((r) {
          SurveySessionDetail? respondent;
          if (summary != null) {
            respondent = summary.sessionDetails
                .where((d) => d.session.id == r.sessionId)
                .firstOrNull;
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (respondent != null) ...[
                  _buildMiniAvatar(respondent),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (respondent != null)
                        Text(
                          respondent.displayName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      if (respondent != null) const SizedBox(height: 3),
                      Text(
                        r.rawResponse ?? r.parsedResponse ?? '(empty)',
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
        if (hasMore)
          Center(
            child: TextButton(
              onPressed: () {
                setState(() {
                  if (isExpanded) {
                    _expandedShortAnswers.remove(questionId);
                  } else {
                    _expandedShortAnswers.add(questionId);
                  }
                });
              },
              child: Text(
                isExpanded
                    ? 'Show Less'
                    : 'Show All (${qs.responses.length} responses)',
                style: const TextStyle(
                  color: BrandColors.momentumBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMiniAvatar(SurveySessionDetail detail) {
    final name = detail.memberName ?? '';
    final url = detail.profilePhotoUrl;
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: 14,
        backgroundImage: CachedNetworkImageProvider(url),
        backgroundColor: BrandColors.unityBlue.withOpacity(0.1),
      );
    }
    return CircleAvatar(
      radius: 14,
      backgroundColor: BrandColors.unityBlue.withOpacity(0.1),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
          color: BrandColors.unityBlue,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }
}
