import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/job.dart';
import '../../models/job_application.dart';
import '../../models/job_notification_log.dart';
import '../../services/jobs_service.dart';
import '../../widgets/job_applicant_card.dart';
import 'job_builder_screen.dart';
import 'job_applicants_screen.dart';

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
  bool _isLoading = false;
  int _applicationCount = 0;
  List<JobApplication> _recentApplications = [];
  List<JobNotificationLog> _notificationLogs = [];
  bool _loadingLogs = true;

  @override
  void initState() {
    super.initState();
    _loadApplications();
    _loadNotificationLogs();
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
            icon: const Icon(Icons.open_in_new),
            onPressed: () => _openInBrowser(),
            tooltip: 'View on Website',
          ),
        ],
      ),
      body: FutureBuilder<Job>(
        future: _jobsService.getJob(widget.jobId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final job = snapshot.data!;

          return SingleChildScrollView(
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

                      // Notification Logs
                      _buildNotificationLogsCard(theme),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: FutureBuilder<Job>(
        future: _jobsService.getJob(widget.jobId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox.shrink();

          final job = snapshot.data!;

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
              child: Row(
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
            ),
          );
        },
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
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isLink
                    ? theme.colorScheme.primary
                    : highlight
                        ? Colors.red
                        : null,
                decoration: isLink ? TextDecoration.underline : null,
                fontWeight: highlight ? FontWeight.bold : null,
              ),
            ),
          ),
        ],
      ),
    );
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
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
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
            ? DateFormat.MMMd().add_jm().format(log.createdAt!)
            : '',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
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
