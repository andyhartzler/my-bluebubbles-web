import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../models/job.dart';
import '../../models/job_application.dart';
import '../../models/job_notification_log.dart';
import '../../models/job_analytics.dart';
import '../../services/jobs_service.dart';
import '../../widgets/job_applicant_card.dart';
import 'job_builder_screen.dart';
import 'job_applicants_screen.dart';
import 'job_analytics_screen.dart';

class JobDetailScreen extends StatefulWidget {
  final String jobId;

  const JobDetailScreen({
    super.key,
    required this.jobId,
  });

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  final _jobsService = JobsService();
  bool _isLoading = true;
  Job? _job;
  int _applicationCount = 0;
  List<JobApplication> _recentApplications = [];
  List<JobNotificationLog> _notificationLogs = [];
  bool _loadingLogs = true;

  // Analytics state
  JobAnalyticsSummary? _analyticsSummary;
  List<JobMemberInteraction> _memberInteractions = [];
  bool _loadingAnalytics = true;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadJob(),
      _loadApplications(),
      _loadNotificationLogs(),
      _loadAnalytics(),
    ]);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadJob() async {
    try {
      final job = await _jobsService.getJob(widget.jobId);
      if (mounted && job != null) {
        setState(() => _job = job);
      }
    } catch (e) {
      debugPrint('_JobDetailScreenState._loadJob error: $e');
    }
  }

  Future<void> _loadAnalytics() async {
    setState(() => _loadingAnalytics = true);
    try {
      final summary = await _jobsService.getJobAnalyticsSummary(widget.jobId);
      final interactions = await _jobsService.getTopEngagedMembers(widget.jobId, limit: 5);

      if (mounted) {
        setState(() {
          _analyticsSummary = summary;
          _memberInteractions = interactions;
          _loadingAnalytics = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingAnalytics = false);
      }
    }
  }

  Future<void> _loadApplications() async {
    try {
      final applications = await _jobsService.getJobApplications(widget.jobId);
      if (mounted) {
        setState(() {
          _applicationCount = applications.length;
          _recentApplications = applications.take(3).toList();
        });
      }
    } catch (_) {
      // Ignore
    }
  }

  Future<void> _loadNotificationLogs() async {
    setState(() => _loadingLogs = true);
    try {
      final logs = await _jobsService.getNotificationLogsForJob(widget.jobId);
      if (mounted) {
        setState(() {
          _notificationLogs = logs;
          _loadingLogs = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingLogs = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadAllData,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new),
            onPressed: () => _openInBrowser(),
            tooltip: 'View on Website',
          ),
        ],
      ),
      body: _buildBody(theme),
      bottomNavigationBar: _buildBottomBar(theme),
    );
  }

  Widget? _buildBottomBar(ThemeData theme) {
    final job = _job;
    if (job == null) return null;

    if (job.status != 'pending') {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _editJob(job),
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit Job'),
                ),
              ),
              if (_applicationCount > 0) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _viewApplicants(job),
                    icon: const Icon(Icons.people),
                    label: Text('View $_applicationCount Applicants'),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Edit button row
            OutlinedButton.icon(
              onPressed: _isLoading ? null : () => _editJob(job),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit Before Approving'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
              ),
            ),
            const SizedBox(height: 12),
            // Approve/Reject row
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => _rejectJob(job),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _isLoading ? null : () => _approveJob(job),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Approve & Publish'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading && _job == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final job = _job;
    if (job == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            const Text('Failed to load job'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadAllData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return _buildJobContent(theme, job);
  }

  Widget _buildJobContent(ThemeData theme, Job job) {
    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Banner
            if (job.status == 'pending')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Colors.orange[100],
                child: Row(
                  children: [
                    Icon(Icons.pending_outlined, color: Colors.orange[900]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This job is pending approval',
                        style: TextStyle(
                          color: Colors.orange[900],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Job Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and status
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          job.title,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      _buildStatusChip(job.status),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Organization
                  Text(
                    job.organization,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Tags
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildChip(job.jobType, Colors.blue, Icons.work_outline),
                      if (job.locationType != null)
                        _buildChip(job.locationType!, Colors.green, Icons.laptop_mac),
                      if (job.isPaid)
                        _buildChip('Paid', Colors.purple, Icons.attach_money),
                      if (job.featured)
                        _buildChip('Featured', Colors.amber, Icons.star),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Applicants Card
                  _buildApplicantsCard(theme, job),
                  const SizedBox(height: 16),

                  // Location
                  if (job.location != null) ...[
                    _buildSection(theme, 'Location', job.location!, Icons.location_on_outlined),
                    const SizedBox(height: 16),
                  ],

                  // Description
                  _buildSection(theme, 'Description', job.description, Icons.description_outlined),
                  const SizedBox(height: 16),

                  // Custom Questions
                  if (job.customQuestions.isNotEmpty) ...[
                    _buildCustomQuestionsCard(theme, job),
                    const SizedBox(height: 16),
                  ],

                  // Requirements
                  if (job.requirements != null) ...[
                    _buildSection(theme, 'Requirements', job.requirements!, Icons.checklist_outlined),
                    const SizedBox(height: 16),
                  ],

                  // Qualifications
                  if (job.qualifications != null) ...[
                    _buildSection(theme, 'Qualifications', job.qualifications!, Icons.school_outlined),
                    const SizedBox(height: 16),
                  ],

                  // Compensation
                  if (job.salaryRange != null || job.hourlyRate != null) ...[
                    _buildSection(
                      theme,
                      'Compensation',
                      job.salaryRange ?? job.hourlyRate ?? '',
                      Icons.payments_outlined,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Contact Info
                  _buildContactCard(theme, job),
                  const SizedBox(height: 16),

                  // Submitter Info
                  _buildSubmitterCard(theme, job),
                  const SizedBox(height: 16),

                  // Dates and metadata
                  _buildMetadataCard(theme, job),
                  const SizedBox(height: 16),

                  // Analytics Section (only for approved jobs)
                  if (job.status == 'approved') ...[
                    _buildAnalyticsSummaryCard(theme, job),
                    const SizedBox(height: 16),
                    _buildMemberEngagementCard(theme, job),
                    const SizedBox(height: 16),
                  ],

                  // Notification Logs
                  _buildNotificationLogsCard(theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApplicantsCard(ThemeData theme, Job job) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.3),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.people_outline,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Applicants',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '$_applicationCount total application${_applicationCount == 1 ? '' : 's'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_applicationCount > 0)
                  FilledButton.tonal(
                    onPressed: () => _viewApplicants(job),
                    child: const Text('View All'),
                  ),
              ],
            ),
          ),
          // Recent applicants preview
          if (_recentApplications.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent Applicants',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._recentApplications.map((app) => _buildMiniApplicantRow(theme, app)),
                ],
              ),
            ),
          ] else if (_applicationCount == 0) ...[
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 48,
                      color: theme.colorScheme.outline.withOpacity(0.5),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No applications yet',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniApplicantRow(ThemeData theme, JobApplication app) {
    final statusColor = Color(JobApplication.statusColor(app.status));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            child: Text(
              _getInitials(app.applicantName),
              style: theme.textTheme.labelSmall?.copyWith(
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
                  app.applicantName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  DateFormat.MMMd().format(app.createdAt),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              JobApplication.statusLabel(app.status),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'pending':
        color = Colors.orange;
        break;
      case 'approved':
        color = Colors.green;
        break;
      case 'rejected':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        status.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildChip(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(ThemeData theme, String title, String content, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildContactCard(ThemeData theme, Job job) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.contact_mail_outlined, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Contact Information',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow(theme, 'Email', job.contactEmail),
            if (job.contactName != null)
              _buildInfoRow(theme, 'Contact', job.contactName!),
            if (job.contactPhone != null)
              _buildInfoRow(theme, 'Phone', job.contactPhone!),
            if (job.applicationUrl != null)
              _buildInfoRow(theme, 'Apply URL', job.applicationUrl!, isLink: true),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitterCard(ThemeData theme, Job job) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person_outline, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Submitted By',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow(theme, 'Name', job.submitterName),
            _buildInfoRow(theme, 'Email', job.submitterEmail),
            if (job.submitterOrganization != null)
              _buildInfoRow(theme, 'Organization', job.submitterOrganization!),
            if (job.submitterPhone != null)
              _buildInfoRow(theme, 'Phone', job.submitterPhone!),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataCard(ThemeData theme, Job job) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Job Details',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow(theme, 'Posted', DateFormat.yMMMd().format(job.createdAt)),
            if (job.expiresAt != null)
              _buildInfoRow(
                theme,
                'Expires',
                DateFormat.yMMMd().format(job.expiresAt!),
                highlight: job.expiresAt!.isBefore(DateTime.now()),
              ),
            if (job.approvedAt != null)
              _buildInfoRow(theme, 'Approved', DateFormat.yMMMd().format(job.approvedAt!)),
            _buildInfoRow(theme, 'Views', '${job.viewCount}'),
            _buildInfoRow(theme, 'Applications', '$_applicationCount'),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsSummaryCard(ThemeData theme, Job job) {
    final colorScheme = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: InkWell(
        onTap: () => _openAnalyticsScreen(job, 0),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Compact Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primaryContainer,
                    colorScheme.secondaryContainer.withOpacity(0.5),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.analytics_rounded,
                      color: colorScheme.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Analytics Overview',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'View detailed insights',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
            // Compact Stats
            if (_loadingAnalytics)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_analyticsSummary != null) ...[
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Primary metrics row
                    Row(
                      children: [
                        Expanded(
                          child: _buildCompactStat(
                            theme,
                            value: '${_analyticsSummary!.totalViews}',
                            label: 'Views',
                            icon: Icons.visibility_rounded,
                            color: Colors.blue,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: colorScheme.outlineVariant.withOpacity(0.3),
                        ),
                        Expanded(
                          child: _buildCompactStat(
                            theme,
                            value: '${_analyticsSummary!.uniqueViewers}',
                            label: 'Unique',
                            icon: Icons.people_rounded,
                            color: Colors.indigo,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: colorScheme.outlineVariant.withOpacity(0.3),
                        ),
                        Expanded(
                          child: _buildCompactStat(
                            theme,
                            value: '${_analyticsSummary!.applyClicks}',
                            label: 'Clicks',
                            icon: Icons.touch_app_rounded,
                            color: Colors.orange,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: colorScheme.outlineVariant.withOpacity(0.3),
                        ),
                        Expanded(
                          child: _buildCompactStat(
                            theme,
                            value: '${_analyticsSummary!.applications}',
                            label: 'Applied',
                            icon: Icons.check_circle_rounded,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Secondary metrics row
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildMiniMetric(theme, _analyticsSummary!.formattedAvgTime, 'Avg Time'),
                          _buildMiniMetric(theme, _analyticsSummary!.formattedClickThroughRate, 'CTR'),
                          _buildMiniMetric(theme, '${_analyticsSummary!.shares}', 'Shares'),
                          _buildMiniMetric(theme, '${_analyticsSummary!.maxScrollDepth}%', 'Scroll'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.analytics_outlined,
                        size: 40,
                        color: colorScheme.outline.withOpacity(0.5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No analytics data yet',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactStat(
    ThemeData theme, {
    required String value,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildMiniMetric(ThemeData theme, String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  void _openAnalyticsScreen(Job job, int initialTab) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => JobAnalyticsScreen(
          job: job,
          initialTab: initialTab,
        ),
      ),
    ).then((_) {
      _loadAnalytics(); // Refresh after returning
    });
  }

  Widget _buildStatTile(
    ThemeData theme, {
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberEngagementCard(ThemeData theme, Job job) {
    final colorScheme = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: InkWell(
        onTap: () => _openAnalyticsScreen(job, 1),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer.withOpacity(0.3),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colorScheme.secondary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.group_rounded,
                      color: colorScheme.secondary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Member Engagement',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${_memberInteractions.length} engaged members',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
            // Member avatars preview
            if (_loadingAnalytics)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_memberInteractions.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.person_search_outlined,
                        size: 40,
                        color: colorScheme.outline.withOpacity(0.5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No member activity yet',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Stacked avatars with member names
                    ...(_memberInteractions.take(3).toList().asMap().entries.map((entry) {
                      final interaction = entry.value;
                      return _buildMemberInteractionTile(theme, interaction, entry.key + 1);
                    })),
                    if (_memberInteractions.length > 3)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '+${_memberInteractions.length - 3} more members',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberInteractionTile(ThemeData theme, JobMemberInteraction interaction, int rank) {
    final colorScheme = theme.colorScheme;

    // Get engagement level color
    Color engagementColor;
    switch (interaction.engagementLevel) {
      case 'High':
        engagementColor = Colors.green;
        break;
      case 'Medium':
        engagementColor = Colors.orange;
        break;
      case 'Low':
        engagementColor = Colors.blue;
        break;
      default:
        engagementColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: rank <= 3 ? Border.all(
          color: engagementColor.withOpacity(0.2),
        ) : null,
      ),
      child: Row(
        children: [
          // Avatar with rank badge
          Stack(
            children: [
              if (interaction.hasProfilePhoto)
                CircleAvatar(
                  radius: 22,
                  backgroundImage: CachedNetworkImageProvider(
                    interaction.memberProfilePhotoUrl!,
                  ),
                  backgroundColor: colorScheme.surfaceContainerHighest,
                )
              else
                CircleAvatar(
                  radius: 22,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Text(
                    interaction.initials,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              if (rank <= 3)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: rank == 1
                          ? Colors.amber
                          : rank == 2
                              ? Colors.grey[400]
                              : Colors.orange[300],
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        '$rank',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          // Member info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        interaction.displayName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: engagementColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: engagementColor.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            interaction.engagementLevel == 'High'
                                ? Icons.local_fire_department_rounded
                                : Icons.trending_up_rounded,
                            size: 10,
                            color: engagementColor,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${interaction.engagementScore}%',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: engagementColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  interaction.memberHomeLocation ?? interaction.locationDescription,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                // Quick action chips
                Row(
                  children: [
                    _buildActivityChip(
                      theme,
                      icon: Icons.visibility_rounded,
                      label: '${interaction.viewCount}',
                    ),
                    const SizedBox(width: 6),
                    _buildActivityChip(
                      theme,
                      icon: Icons.timer_rounded,
                      label: interaction.formattedTotalTime,
                    ),
                    if (interaction.hasApplied) ...[
                      const SizedBox(width: 6),
                      _buildActivityChip(
                        theme,
                        icon: Icons.check_circle_rounded,
                        label: 'Applied',
                        highlight: true,
                      ),
                    ] else if (interaction.hasClickedApply) ...[
                      const SizedBox(width: 6),
                      _buildActivityChip(
                        theme,
                        icon: Icons.touch_app_rounded,
                        label: 'Clicked',
                        color: Colors.orange,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityChip(
    ThemeData theme, {
    required IconData icon,
    required String label,
    bool highlight = false,
    Color? color,
  }) {
    final chipColor = color ?? (highlight ? Colors.green : null);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: chipColor != null
            ? chipColor.withOpacity(0.1)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
        border: chipColor != null
            ? Border.all(color: chipColor.withOpacity(0.3))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 11,
            color: chipColor ?? theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10,
              color: chipColor ?? theme.colorScheme.onSurfaceVariant,
              fontWeight: chipColor != null ? FontWeight.w600 : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomQuestionsCard(ThemeData theme, Job job) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer.withOpacity(0.3),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.quiz_outlined,
                  color: theme.colorScheme.secondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Application Questions',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${job.customQuestions.length} custom question${job.customQuestions.length == 1 ? '' : 's'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Questions list
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: job.customQuestions.asMap().entries.map((entry) {
                final index = entry.key;
                final question = entry.value;
                return _buildCustomQuestionItem(theme, question, index + 1);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomQuestionItem(ThemeData theme, CustomQuestion question, int number) {
    // Get question type label and icon
    String typeLabel;
    IconData typeIcon;
    switch (question.type) {
      case CustomQuestionType.text:
        typeLabel = 'Short text';
        typeIcon = Icons.short_text;
        break;
      case CustomQuestionType.textarea:
        typeLabel = 'Long text';
        typeIcon = Icons.notes;
        break;
      case CustomQuestionType.select:
        typeLabel = 'Dropdown';
        typeIcon = Icons.arrow_drop_down_circle_outlined;
        break;
      case CustomQuestionType.checkbox:
        typeLabel = 'Checkboxes';
        typeIcon = Icons.check_box_outlined;
        break;
      case CustomQuestionType.radio:
        typeLabel = 'Multiple choice';
        typeIcon = Icons.radio_button_checked;
        break;
    }

    return Padding(
      padding: EdgeInsets.only(bottom: number < 10 ? 12 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '$number',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            question.question,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (question.required)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Required',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(typeIcon, size: 14, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          typeLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    if (question.options.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: question.options.map((option) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              option,
                              style: theme.textTheme.bodySmall,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(ThemeData theme, String label, String value, {bool isLink = false, bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: isLink
                ? InkWell(
                    onTap: () => _launchUrl(value),
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            value,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              decoration: TextDecoration.underline,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.open_in_new,
                          size: 14,
                          color: theme.colorScheme.primary,
                        ),
                      ],
                    ),
                  )
                : Text(
                    value,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: highlight ? Colors.red : null,
                      fontWeight: highlight ? FontWeight.bold : null,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    // Ensure URL has a scheme
    String urlToLaunch = url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      urlToLaunch = 'https://$url';
    }

    final uri = Uri.parse(urlToLaunch);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not open $url'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening URL: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _approveJob(Job job) async {
    setState(() => _isLoading = true);

    try {
      await _jobsService.approveJob(job.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Job approved and published!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _rejectJob(Job job) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => _RejectJobDialog(),
    );

    if (reason == null) return;

    setState(() => _isLoading = true);

    try {
      await _jobsService.rejectJob(job.id, reason);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Job rejected'),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _editJob(Job job) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => JobBuilderScreen(jobId: job.id),
      ),
    ).then((_) {
      setState(() {}); // Refresh after edit
    });
  }

  void _viewApplicants(Job job) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => JobApplicantsScreen(job: job),
      ),
    ).then((_) {
      _loadApplications(); // Refresh counts
    });
  }

  void _openInBrowser() {
    // TODO: Implement URL launcher
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '??';
    final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return '??';
  }

  Widget _buildNotificationLogsCard(ThemeData theme) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiaryContainer.withOpacity(0.3),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.notifications_outlined,
                  color: theme.colorScheme.tertiary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notification History',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_notificationLogs.length} notification${_notificationLogs.length == 1 ? '' : 's'} sent',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadNotificationLogs,
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ),
          // Content
          if (_loadingLogs)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_notificationLogs.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.notifications_off_outlined,
                      size: 48,
                      color: theme.colorScheme.outline.withOpacity(0.5),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No notifications sent yet',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Notifications will appear here when triggered',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _notificationLogs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final log = _notificationLogs[index];
                return _buildNotificationLogTile(theme, log);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildNotificationLogTile(ThemeData theme, JobNotificationLog log) {
    final statusColor = log.isSuccess
        ? Colors.green
        : log.isFailed
            ? Colors.red
            : Colors.orange;

    final channelIcon = log.channel == 'email'
        ? Icons.email_outlined
        : Icons.sms_outlined;

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          channelIcon,
          color: statusColor,
          size: 20,
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              log.triggerTypeLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              log.statusLabel,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.person_outline,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  log.recipientName ?? log.recipientEmail,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (log.subjectRendered != null) ...[
            const SizedBox(height: 2),
            Text(
              log.subjectRendered!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                fontStyle: FontStyle.italic,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (log.errorMessage != null) ...[
            const SizedBox(height: 2),
            Text(
              'Error: ${log.errorMessage}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.red,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
      trailing: Text(
        log.createdAt != null
            ? _formatCentralTime(log.createdAt!)
            : '',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }

  String _formatCentralTime(DateTime dateTime) {
    final central = tz.getLocation('America/Chicago');
    final centralTime = tz.TZDateTime.from(dateTime.toUtc(), central);
    return DateFormat.MMMd().add_jm().format(centralTime);
  }
}

class _RejectJobDialog extends StatefulWidget {
  @override
  State<_RejectJobDialog> createState() => _RejectJobDialogState();
}

class _RejectJobDialogState extends State<_RejectJobDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reject Job'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          labelText: 'Reason for rejection',
          hintText: 'Provide feedback to the submitter...',
        ),
        maxLines: 3,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red,
          ),
          child: const Text('Reject'),
        ),
      ],
    );
  }
}
