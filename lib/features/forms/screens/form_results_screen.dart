import 'package:flutter/material.dart';
import '../models/form_schema.dart';
import '../models/form_submission.dart';
import '../services/forms_service.dart';
import '../services/form_analytics_service.dart';
import '../widgets/results/results_summary_card.dart';
import '../widgets/results/response_charts.dart';
import 'submission_detail_screen.dart';

/// Beautiful form results screen with tabs for Overview, Responses, and Submissions
class FormResultsScreen extends StatefulWidget {
  final String formId;

  const FormResultsScreen({
    Key? key,
    required this.formId,
  }) : super(key: key);

  @override
  State<FormResultsScreen> createState() => _FormResultsScreenState();
}

class _FormResultsScreenState extends State<FormResultsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formsService = FormsService();
  final _analyticsService = FormAnalyticsService();

  FormSchema? _form;
  List<FormSubmission> _submissions = [];
  FormAnalyticsSummary? _analytics;
  List<TimeSeriesData> _timeSeriesData = [];
  bool _isLoading = true;
  String? _error;

  // Filter and search state
  String _searchQuery = '';
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
      ]);

      setState(() {
        _form = results[0] as FormSchema;
        _submissions = results[1] as List<FormSubmission>;
        _analytics = results[2] as FormAnalyticsSummary;
        _timeSeriesData = results[3] as List<TimeSeriesData>;
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

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((s) {
        final searchLower = _searchQuery.toLowerCase();
        return s.submitterName?.toLowerCase().contains(searchLower) == true ||
            s.submitterEmail?.toLowerCase().contains(searchLower) == true ||
            s.data.values.any((v) => v.toString().toLowerCase().contains(searchLower));
      }).toList();
    }

    // Apply date filter
    if (_startDate != null) {
      filtered = filtered.where((s) => s.createdAt.isAfter(_startDate!)).toList();
    }
    if (_endDate != null) {
      filtered = filtered.where((s) => s.createdAt.isBefore(_endDate!.add(const Duration(days: 1)))).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _form?.title ?? 'Form Results',
              style: const TextStyle(fontSize: 18),
            ),
            if (_form != null)
              Text(
                '${_submissions.length} submissions',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'export_csv':
                  _exportToCsv();
                  break;
                case 'share':
                  _shareResults();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export_csv',
                child: Row(
                  children: [
                    Icon(Icons.download),
                    SizedBox(width: 12),
                    Text('Export to CSV'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share),
                    SizedBox(width: 12),
                    Text('Share Results'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard_outlined)),
            Tab(text: 'Responses', icon: Icon(Icons.bar_chart_outlined)),
            Tab(text: 'Submissions', icon: Icon(Icons.list_alt_outlined)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
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
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _loadData,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(),
                    _buildResponsesTab(),
                    _buildSubmissionsTab(),
                  ],
                ),
    );
  }

  Widget _buildOverviewTab() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_submissions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 80,
              color: colorScheme.onSurfaceVariant.withOpacity(0.3),
            ),
            const SizedBox(height: 24),
            Text(
              'No submissions yet',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Share your form to start collecting responses',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _shareResults,
              icon: const Icon(Icons.share),
              label: const Text('Share Form'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Analytics summary
            if (_analytics != null) ResultsSummaryCard(analytics: _analytics!),
            const SizedBox(height: 20),

            // Time series chart
            SubmissionTimeSeriesChart(data: _timeSeriesData),
            const SizedBox(height: 20),

            // Quick stats cards
            _buildQuickStatsRow(),
            const SizedBox(height: 20),

            // Recent submissions
            _buildRecentSubmissionsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStatsRow() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Calculate some quick stats
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
          child: _buildQuickStatCard(
            'Today',
            todaySubmissions.toString(),
            Icons.today,
            Colors.blue,
            theme,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildQuickStatCard(
            'This Week',
            thisWeekSubmissions.toString(),
            Icons.date_range,
            Colors.green,
            theme,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildQuickStatCard(
            'Total',
            _submissions.length.toString(),
            Icons.assessment,
            Colors.purple,
            theme,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
    ThemeData theme,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
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
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentSubmissionsCard() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final recentSubmissions = _submissions.take(5).toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.history, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Recent Submissions',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    _tabController.animateTo(2);
                  },
                  child: const Text('View All'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (recentSubmissions.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: Text('No submissions yet')),
            )
          else
            ...recentSubmissions.map((submission) {
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: colorScheme.primaryContainer,
                  child: Text(
                    (submission.submitterName?.isNotEmpty == true
                            ? submission.submitterName![0]
                            : submission.submitterEmail?.isNotEmpty == true
                                ? submission.submitterEmail![0]
                                : '?')
                        .toUpperCase(),
                    style: TextStyle(color: colorScheme.onPrimaryContainer),
                  ),
                ),
                title: Text(
                  submission.submitterName ?? submission.submitterEmail ?? 'Anonymous',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  _formatDate(submission.createdAt),
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _viewSubmission(submission),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildResponsesTab() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_form == null || _submissions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bar_chart_outlined,
              size: 80,
              color: colorScheme.onSurfaceVariant.withOpacity(0.3),
            ),
            const SizedBox(height: 24),
            Text(
              'No response data',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Response charts will appear once you have submissions',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
            ),
          ],
        ),
      );
    }

    final fields = _form!.schema.fields;
    final aggregatedData = ResponseAggregator.aggregate(fields, _submissions);

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Field-by-Field Analysis',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Visualizations for each field in your form',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            ...aggregatedData.map((fieldData) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildFieldChart(fieldData),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldChart(FieldResponseData fieldData) {
    // Choose the appropriate chart type based on field type
    switch (fieldData.fieldType) {
      case 'dropdown':
      case 'radio':
      case 'choice_chips':
      case 'segmented_control':
        return SelectionPieChart(data: fieldData);

      case 'checkbox_group':
      case 'filter_chips':
        return SelectionBarChart(data: fieldData);

      case 'rating':
        return RatingDistributionChart(data: fieldData);

      case 'switch':
      case 'checkbox':
        return BooleanResponseChart(data: fieldData);

      case 'number':
      case 'slider':
      case 'range_slider':
      case 'touch_spin':
        return NumericSummaryCard(data: fieldData);

      case 'text':
      case 'textarea':
      case 'email':
      case 'phone':
      case 'url':
        return TextResponsesList(data: fieldData);

      default:
        // For unsupported types, show as text list
        return TextResponsesList(data: fieldData);
    }
  }

  Widget _buildSubmissionsTab() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final filtered = _filteredSubmissions;

    return Column(
      children: [
        // Search and filter bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border(
              bottom: BorderSide(color: colorScheme.outlineVariant),
            ),
          ),
          child: Column(
            children: [
              TextField(
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
                  ),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _selectDateRange(),
                      icon: const Icon(Icons.date_range, size: 18),
                      label: Text(
                        _startDate != null || _endDate != null
                            ? '${_formatShortDate(_startDate)} - ${_formatShortDate(_endDate)}'
                            : 'Date Range',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if (_startDate != null || _endDate != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _startDate = null;
                          _endDate = null;
                        });
                      },
                      tooltip: 'Clear date filter',
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        // Results count
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${filtered.length} submission${filtered.length == 1 ? '' : 's'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (filtered.length != _submissions.length)
                Text(
                  'of ${_submissions.length} total',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        // Submissions list
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 64,
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
                            _startDate = null;
                            _endDate = null;
                          });
                        },
                        child: const Text('Clear filters'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final submission = filtered[index];
                      return _buildSubmissionCard(submission, index);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildSubmissionCard(FormSubmission submission, int index) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Get a preview of the submission data
    final previewFields = submission.data.entries.take(2).toList();

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: () => _viewSubmission(submission),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: colorScheme.primaryContainer,
                    radius: 20,
                    child: Text(
                      (submission.submitterName?.isNotEmpty == true
                              ? submission.submitterName![0]
                              : submission.submitterEmail?.isNotEmpty == true
                                  ? submission.submitterEmail![0]
                                  : '#')
                          .toUpperCase(),
                      style: TextStyle(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          submission.submitterName ??
                              submission.submitterEmail ??
                              'Submission #${_submissions.length - index}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (submission.submitterEmail != null &&
                            submission.submitterName != null)
                          Text(
                            submission.submitterEmail!,
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
                      Text(
                        _formatDate(submission.createdAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          submission.status,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (previewFields.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                ...previewFields.map((entry) {
                  final fieldLabel = _getFieldLabel(entry.key);
                  final value = entry.value?.toString() ?? '-';
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
                          ),
                        ),
                        Expanded(
                          child: Text(
                            value.length > 50 ? '${value.substring(0, 50)}...' : value,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _getFieldLabel(String fieldId) {
    if (_form == null) return fieldId;
    final field = _form!.schema.fields.where((f) => f.id == fieldId).firstOrNull;
    return field?.label ?? fieldId;
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

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  void _exportToCsv() {
    // TODO: Implement CSV export
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export feature coming soon')),
    );
  }

  void _shareResults() {
    // TODO: Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share feature coming soon')),
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

  String _formatShortDate(DateTime? date) {
    if (date == null) return 'Any';
    return '${date.month}/${date.day}';
  }
}
