import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/form_schema.dart';
import '../models/form_submission.dart';
import '../services/forms_service.dart';
import '../services/form_analytics_service.dart';
import '../widgets/results/results_summary_card.dart';
import '../widgets/results/response_charts.dart';
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
  String _searchQuery = '';
  String _statusFilter = 'all';

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
        ...chartableFields.take(3).map((fieldData) => Padding(
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
    final previewFields = submission.data.entries.take(3).toList();

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
                  // Avatar
                  CircleAvatar(
                    backgroundColor: colorScheme.primaryContainer,
                    radius: 20,
                    child: Text(
                      submission.displayInitial,
                      style: TextStyle(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Name and email
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          submission.displayName,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (submission.displayEmail != null &&
                            submission.displayEmail != submission.displayName)
                          Text(
                            submission.displayEmail!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Status and date
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

              // Preview fields
              if (previewFields.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: previewFields.map((entry) {
                      final fieldLabel = _getFieldLabel(entry.key);
                      final value = _formatValue(entry.value);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 100,
                              child: Text(
                                fieldLabel,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                value,
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
              ],

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

  String _getFieldLabel(String fieldId) {
    if (_form == null) return fieldId;
    final field = _form!.schema.fields.where((f) => f.id == fieldId).firstOrNull;
    return field?.label ?? fieldId;
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
