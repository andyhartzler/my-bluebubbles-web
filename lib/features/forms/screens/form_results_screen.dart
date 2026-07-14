import 'package:flutter/material.dart';
import '../models/form_schema.dart';
import '../models/form_submission.dart';
import '../models/submission_review_model.dart';
import '../services/forms_service.dart';
import '../services/form_analytics_service.dart';
import '../theme/moyd_brand.dart';
import '../widgets/results/results_summary_card.dart';
import '../widgets/results/response_charts.dart';
import '../widgets/review/compare_matrix.dart';
import '../widgets/review/policy_stance_bars.dart';
import '../widgets/review/stance_visuals.dart';
import 'submission_detail_screen.dart';

/// Beautiful unified form results screen showing analytics and submissions together
class FormResultsScreen extends StatefulWidget {
  final String formId;

  const FormResultsScreen({
    Key? key,
    required this.formId,
  }) : super(key: key);

  @override
  State<FormResultsScreen> createState() => _FormResultsScreenState();
}

class _FormResultsScreenState extends State<FormResultsScreen> {
  final _formsService = FormsService();
  final _analyticsService = FormAnalyticsService();

  FormSchema? _form;
  List<FormSubmission> _submissions = [];
  FormAnalyticsSummary? _analytics;
  List<TimeSeriesData> _timeSeriesData = [];
  Map<String, int> _statusStats = {};
  bool _isLoading = true;
  String? _error;

  // View state
  bool _showCharts = true;
  bool _compareMode = false;
  String _searchQuery = '';
  String _statusFilter = 'all';

  /// True when the loaded form is "endorsement-shaped": it has the candidate
  /// office field and at least four single-select policy questions. Detected
  /// structurally (not by form id) so it degrades safely for other forms.
  bool get _isEndorsementForm {
    final form = _form;
    if (form == null) return false;
    final fields = form.schema.fields;
    final hasOffice = fields.any((f) => f.id == 'office_sought');
    final policyCount = fields
        .where((f) =>
            f.id.startsWith('pos_') &&
            const {'radio', 'dropdown', 'choice_chips'}.contains(f.type))
        .length;
    return hasOffice && policyCount >= 4;
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _formsService.getForm(widget.formId),
        _formsService.getSubmissions(widget.formId),
        _analyticsService.getFormAnalytics(widget.formId),
        _analyticsService.getSubmissionTimeSeries(widget.formId),
        _analyticsService.getSubmissionsByStatus(widget.formId),
      ]);

      setState(() {
        _form = results[0] as FormSchema;
        _submissions = results[1] as List<FormSubmission>;
        _analytics = results[2] as FormAnalyticsSummary;
        _timeSeriesData = results[3] as List<TimeSeriesData>;
        _statusStats = results[4] as Map<String, int>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<FormSubmission> get _filteredSubmissions {
    var filtered = _submissions;

    // Apply status filter
    if (_statusFilter != 'all') {
      filtered = filtered.where((s) => s.status == _statusFilter).toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((s) {
        final searchLower = _searchQuery.toLowerCase();
        return s.displayName.toLowerCase().contains(searchLower) ||
            (s.displayEmail?.toLowerCase().contains(searchLower) ?? false) ||
            s.data.values.any((v) => v.toString().toLowerCase().contains(searchLower));
      }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (!_isLoading && _error == null && _compareMode && _isEndorsementForm) {
      return Scaffold(body: _buildCompareBody(theme, colorScheme));
    }

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState(theme, colorScheme)
              : CustomScrollView(
                  slivers: [
                    _buildSliverAppBar(theme, colorScheme),
                    SliverToBoxAdapter(
                      child: _buildContent(theme, colorScheme),
                    ),
                  ],
                ),
    );
  }

  /// Full-height compare view. Kept out of the CustomScrollView so the matrix
  /// can own its own vertical + horizontal scrolling.
  Widget _buildCompareBody(ThemeData theme, ColorScheme colorScheme) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            color: MoydBrand.navy,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  tooltip: 'Back to list',
                  onPressed: () => setState(() => _compareMode = false),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Compare candidates',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _form?.title ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  tooltip: 'Refresh',
                  onPressed: _loadData,
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: CompareMatrix(
                form: _form!,
                submissions: _filteredSubmissions,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(ThemeData theme, ColorScheme colorScheme) {
    return SliverAppBar(
      expandedHeight: 120,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          _form?.title ?? 'Form Results',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colorScheme.primaryContainer,
                colorScheme.primary.withOpacity(0.1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      actions: [
        if (_isEndorsementForm)
          IconButton(
            icon: const Icon(Icons.grid_view_outlined),
            onPressed: () => setState(() => _compareMode = true),
            tooltip: 'Compare candidates',
          ),
        IconButton(
          icon: Icon(_showCharts ? Icons.list : Icons.bar_chart),
          onPressed: () {
            setState(() {
              _showCharts = !_showCharts;
            });
          },
          tooltip: _showCharts ? 'Show List View' : 'Show Charts',
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _loadData,
          tooltip: 'Refresh',
        ),
      ],
    );
  }

  Widget _buildErrorState(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading results',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme, ColorScheme colorScheme) {
    if (_submissions.isEmpty) {
      return _buildEmptyState(theme, colorScheme);
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary stats row
            _buildQuickStats(theme, colorScheme),
            const SizedBox(height: 24),

            // Analytics section (collapsible)
            if (_showCharts) ...[
              _buildAnalyticsSection(theme, colorScheme),
              const SizedBox(height: 24),
            ],

            // Submissions section
            _buildSubmissionsSection(theme, colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inbox_outlined,
                size: 64,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No submissions yet',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Share your form to start collecting responses',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () {
                // TODO: Share form
              },
              icon: const Icon(Icons.share),
              label: const Text('Share Form'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats(ThemeData theme, ColorScheme colorScheme) {
    final today = DateTime.now();
    final todaySubmissions = _submissions.where((s) {
      return s.createdAt.year == today.year &&
          s.createdAt.month == today.month &&
          s.createdAt.day == today.day;
    }).length;

    final thisWeekStart = today.subtract(Duration(days: today.weekday - 1));
    final thisWeekSubmissions = _submissions.where((s) {
      return s.createdAt.isAfter(thisWeekStart);
    }).length;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            theme,
            colorScheme,
            'Total',
            _submissions.length.toString(),
            Icons.assessment_outlined,
            colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            theme,
            colorScheme,
            'Today',
            todaySubmissions.toString(),
            Icons.today_outlined,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            theme,
            colorScheme,
            'This Week',
            thisWeekSubmissions.toString(),
            Icons.date_range_outlined,
            Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    ThemeData theme,
    ColorScheme colorScheme,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsSection(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Icon(Icons.analytics_outlined, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Analytics',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Summary card
        if (_analytics != null) ResultsSummaryCard(analytics: _analytics!),
        const SizedBox(height: 16),

        // Time series chart
        if (_timeSeriesData.isNotEmpty) ...[
          SubmissionTimeSeriesChart(data: _timeSeriesData),
          const SizedBox(height: 16),
        ],

        // Response breakdowns (if form has fields)
        if (_form != null && _form!.schema.fields.isNotEmpty) ...[
          _buildResponseBreakdown(theme, colorScheme),
        ],
      ],
    );
  }

  Widget _buildResponseBreakdown(ThemeData theme, ColorScheme colorScheme) {
    // Endorsement form: replace the arbitrary select-field charts with a
    // per-policy 100%-stacked stance breakdown computed across all candidates.
    if (_isEndorsementForm) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PolicyStanceBars(form: _form!, submissions: _submissions),
        ],
      );
    }

    final fields = _form!.schema.fields;
    final aggregatedData = ResponseAggregator.aggregate(fields, _submissions);

    // Only show charts for fields that have visualization (selections, ratings, etc.)
    final chartableFields = aggregatedData.where((f) {
      return ['dropdown', 'radio', 'choice_chips', 'checkbox_group', 'filter_chips', 'rating', 'switch', 'checkbox']
          .contains(f.fieldType);
    }).toList();

    if (chartableFields.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.pie_chart_outline, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Response Breakdown',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...chartableFields.map((fieldData) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildFieldChart(fieldData),
            )),
      ],
    );
  }

  Widget _buildFieldChart(FieldResponseData fieldData) {
    switch (fieldData.fieldType) {
      case 'dropdown':
      case 'radio':
      case 'choice_chips':
        return SelectionBarChart(data: fieldData);
      case 'checkbox_group':
      case 'filter_chips':
        return SelectionBarChart(data: fieldData);
      case 'rating':
        return RatingDistributionChart(data: fieldData);
      case 'switch':
      case 'checkbox':
        return BooleanResponseChart(data: fieldData);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSubmissionsSection(ThemeData theme, ColorScheme colorScheme) {
    final filtered = _filteredSubmissions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header with search
        Row(
          children: [
            Icon(Icons.list_alt_outlined, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Submissions',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Text(
              '${filtered.length} of ${_submissions.length}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Search and filter bar
        _buildSearchFilterBar(theme, colorScheme),
        const SizedBox(height: 16),

        // Status filter chips
        if (_statusStats.length > 1) ...[
          _buildStatusFilters(theme, colorScheme),
          const SizedBox(height: 16),
        ],

        // Submissions list
        if (filtered.isEmpty)
          _buildNoResultsState(theme, colorScheme)
        else
          ...filtered.asMap().entries.map((entry) {
            final index = entry.key;
            final submission = entry.value;
            return _buildSubmissionCard(theme, colorScheme, submission, index);
          }),
      ],
    );
  }

  Widget _buildSearchFilterBar(ThemeData theme, ColorScheme colorScheme) {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Search submissions...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                  });
                },
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
    );
  }

  Widget _buildStatusFilters(ThemeData theme, ColorScheme colorScheme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildStatusChip(theme, colorScheme, 'all', 'All', _submissions.length),
          const SizedBox(width: 8),
          ..._statusStats.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildStatusChip(theme, colorScheme, entry.key, _capitalize(entry.key), entry.value),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStatusChip(
    ThemeData theme,
    ColorScheme colorScheme,
    String value,
    String label,
    int count,
  ) {
    final isSelected = _statusFilter == value;
    final color = _getStatusColor(value);

    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white.withOpacity(0.3) : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count.toString(),
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      selected: isSelected,
      selectedColor: color,
      checkmarkColor: Colors.white,
      onSelected: (selected) {
        setState(() {
          _statusFilter = selected ? value : 'all';
        });
      },
    );
  }

  Widget _buildNoResultsState(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: colorScheme.onSurfaceVariant.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No matching submissions',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                  _statusFilter = 'all';
                });
              },
              child: const Text('Clear filters'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmissionCard(
    ThemeData theme,
    ColorScheme colorScheme,
    FormSubmission submission,
    int index,
  ) {
    final model =
        _isEndorsementForm ? SubmissionReviewModel.from(_form!, submission) : null;

    // Avatar: prefer the endorsement headshot, then any joined member photo.
    final photoUrl = model?.headshot?.url ?? submission.displayPhotoUrl;
    final displayName = model?.candidateName ?? submission.displayName;
    final subtitle = model != null
        ? [model.office, model.district]
            .where((e) => e != null && e.isNotEmpty)
            .join(' · ')
        : (submission.displayEmail != null &&
                submission.displayEmail != submission.displayName
            ? submission.displayEmail!
            : '');

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: () => _viewSubmission(submission),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: colorScheme.primaryContainer,
                    radius: 20,
                    backgroundImage:
                        photoUrl != null ? NetworkImage(photoUrl) : null,
                    child: photoUrl == null
                        ? Text(
                            submission.displayInitial,
                            style: TextStyle(
                              color: colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (subtitle.isNotEmpty)
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildStatusBadge(theme, submission.status),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(submission.createdAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Curated preview (endorsement) or schema-order fallback.
              if (model != null)
                _buildEndorsementPreview(theme, colorScheme, model)
              else
                _buildGenericPreview(theme, colorScheme, submission),

              // View details link
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _viewSubmission(submission),
                    icon: const Icon(Icons.visibility_outlined, size: 16),
                    label: const Text('View Details'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Curated endorsement card body: raised amount + track, stance summary,
  /// and review flags. Built from the [SubmissionReviewModel] curated getters.
  Widget _buildEndorsementPreview(
    ThemeData theme,
    ColorScheme colorScheme,
    SubmissionReviewModel model,
  ) {
    final tally = model.stanceTally;
    final flags = _endorsementFlags(model);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        // Raised + track row.
        Row(
          children: [
            Icon(Icons.savings_outlined, size: 16, color: MoydBrand.navy),
            const SizedBox(width: 6),
            Text(
              ReviewFormat.currency(model.raisedToDate),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: MoydBrand.navy,
              ),
            ),
            Text(
              ' raised',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const Spacer(),
            if (model.track != null) _trackBadge(theme, model.track!),
          ],
        ),
        // Alignment badge + stance summary.
        if (model.alignmentPct != null ||
            tally.support + tally.qualified + tally.oppose + tally.other >
                0) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (model.alignmentPct != null)
                AlignmentBadge(pct: model.alignmentPct!, showWord: true),
              if (tally.support > 0)
                StanceVisuals.pill(Stance.support,
                    text: '${tally.support} support', dense: true),
              if (tally.qualified > 0)
                StanceVisuals.pill(Stance.qualified,
                    text: '${tally.qualified} qualified', dense: true),
              if (tally.oppose > 0)
                StanceVisuals.pill(Stance.oppose,
                    text: '${tally.oppose} oppose', dense: true),
            ],
          ),
        ],
        // Flags.
        if (flags.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: flags.map((f) => _flagChip(theme, f)).toList(),
          ),
        ],
      ],
    );
  }

  List<String> _endorsementFlags(SubmissionReviewModel model) {
    final flags = <String>[];
    if (model.nonDemHistory) flags.add('Non-Dem party history');
    final pct = model.selfFundedPct;
    if (pct != null && pct > 50) {
      flags.add('Self-funded ${pct.round()}%');
    }
    if (model.headshot == null) flags.add('No headshot');
    if (model.budgetFile == null) flags.add('No budget');
    return flags;
  }

  Widget _trackBadge(ThemeData theme, String track) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: MoydBrand.navy,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        track,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _flagChip(ThemeData theme, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: MoydBrand.amberBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: MoydBrand.amber.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flag_outlined, size: 13, color: MoydBrand.amber),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: MoydBrand.amber,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  /// Fallback preview for non-endorsement forms: the first few ANSWERED fields
  /// in schema order (not random JSONB keys).
  Widget _buildGenericPreview(
    ThemeData theme,
    ColorScheme colorScheme,
    FormSubmission submission,
  ) {
    final previewFields = <MapEntry<String, String>>[];
    final fields = _form?.schema.fields ?? const [];
    for (final f in fields) {
      if (f.type == 'section_header' || f.type == 'reference_block') continue;
      final raw = submission.data[f.id];
      if (raw == null) continue;
      if (raw is String && raw.trim().isEmpty) continue;
      if (raw is Iterable && raw.isEmpty) continue;
      final display = SubmissionReviewModel.resolveDisplay(f, raw);
      previewFields.add(
          MapEntry(f.label, display.isEmpty ? _formatValue(raw) : display));
      if (previewFields.length >= 3) break;
    }

    if (previewFields.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: previewFields.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(
                      entry.key,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(ThemeData theme, String status) {
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        _capitalize(status),
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'submitted':
        return Colors.blue;
      case 'reviewed':
        return Colors.orange;
      case 'processed':
        return Colors.green;
      case 'draft':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  String _formatValue(dynamic value) {
    if (value == null) return '-';
    if (value is List) {
      return value.map((v) => v.toString()).join(', ');
    }
    if (value is Map) {
      return value.values.map((v) => v.toString()).join(', ');
    }
    final str = value.toString();
    return str.isEmpty ? '-' : str;
  }

  void _viewSubmission(FormSubmission submission) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SubmissionDetailScreen(
          submission: submission,
          form: _form!,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return '${date.month}/${date.day}/${date.year}';
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}
