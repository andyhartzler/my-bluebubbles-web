import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/job.dart';
import '../../models/job_application.dart';
import '../../services/jobs_service.dart';
import '../../widgets/job_applicant_card.dart';

/// Screen to display and manage applicants for a specific job
class JobApplicantsScreen extends StatefulWidget {
  final Job job;

  const JobApplicantsScreen({
    super.key,
    required this.job,
  });

  @override
  State<JobApplicantsScreen> createState() => _JobApplicantsScreenState();
}

class _JobApplicantsScreenState extends State<JobApplicantsScreen> {
  final _jobsService = JobsService();
  String _statusFilter = 'all';
  Map<String, int>? _statusCounts;

  @override
  void initState() {
    super.initState();
    _loadStatusCounts();
  }

  Future<void> _loadStatusCounts() async {
    try {
      final counts = await _jobsService.getApplicationCountsByStatus(widget.job.id);
      if (mounted) {
        setState(() {
          _statusCounts = counts;
        });
      }
    } catch (_) {
      // Ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Applicants - ${widget.job.title}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => _exportApplicants(context),
            tooltip: 'Export Applicants',
          ),
        ],
      ),
      body: Column(
        children: [
          // Job info summary
          _buildJobInfoCard(theme),

          // Status filter chips
          _buildStatusFilters(theme),

          // Applicants list
          Expanded(
            child: StreamBuilder<List<JobApplication>>(
              stream: _jobsService.watchJobApplications(widget.job.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return _buildErrorState(theme, snapshot.error.toString());
                }

                var applications = snapshot.data ?? [];

                // Apply status filter
                if (_statusFilter != 'all') {
                  applications = applications.where((a) => a.status == _statusFilter).toList();
                }

                if (applications.isEmpty) {
                  return _buildEmptyState(theme);
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    await _loadStatusCounts();
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: applications.length,
                    itemBuilder: (context, index) {
                      final application = applications[index];
                      return JobApplicantCard(
                        application: application,
                        onTap: () => _showApplicantDetails(context, application),
                        onStatusChanged: (newStatus) => _updateApplicationStatus(application, newStatus),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobInfoCard(ThemeData theme) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.job.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.job.organization,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            // Status badge
            _buildJobStatusBadge(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildJobStatusBadge(ThemeData theme) {
    Color color;
    switch (widget.job.status) {
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        widget.job.status.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatusFilters(ThemeData theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildStatusChip('All', 'all', null),
          const SizedBox(width: 8),
          _buildStatusChip('Submitted', 'submitted', Colors.blue),
          const SizedBox(width: 8),
          _buildStatusChip('Reviewed', 'reviewed', Colors.orange),
          const SizedBox(width: 8),
          _buildStatusChip('Shortlisted', 'shortlisted', Colors.purple),
          const SizedBox(width: 8),
          _buildStatusChip('Accepted', 'accepted', Colors.green),
          const SizedBox(width: 8),
          _buildStatusChip('Rejected', 'rejected', Colors.red),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, String value, Color? color) {
    final isSelected = _statusFilter == value;
    final count = value == 'all'
        ? _statusCounts?.values.fold(0, (a, b) => a + b)
        : _statusCounts?[value];

    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (color != null) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(label),
          if (count != null && count > 0) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  color: isSelected
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _statusFilter = value;
        });
      },
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    final isFiltered = _statusFilter != 'all';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isFiltered ? Icons.filter_list_off : Icons.people_outline,
            size: 64,
            color: theme.colorScheme.outline.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            isFiltered
                ? 'No ${_statusFilter} applications'
                : 'No applications yet',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (isFiltered) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => setState(() => _statusFilter = 'all'),
              child: const Text('Show All'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Error loading applications',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showApplicantDetails(BuildContext context, JobApplication application) {
    final theme = Theme.of(context);
    final statusColor = Color(JobApplication.statusColor(application.status));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      _getInitials(application.applicantName),
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          application.applicantName,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          application.applicantEmail,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      JobApplication.statusLabel(application.status),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            // Content
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  // Contact info
                  _buildDetailSection(
                    theme,
                    'Contact Information',
                    Icons.contact_mail_outlined,
                    [
                      _buildDetailRow(theme, 'Email', application.applicantEmail, onTap: () => _openEmail(application.applicantEmail)),
                      if (application.applicantPhone != null)
                        _buildDetailRow(theme, 'Phone', application.applicantPhone!, onTap: () => _openPhone(application.applicantPhone!)),
                      if (application.applicantCity != null || application.applicantZipCode != null)
                        _buildDetailRow(
                          theme,
                          'Location',
                          [application.applicantCity, application.applicantZipCode]
                              .where((e) => e != null)
                              .join(', '),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Application info
                  _buildDetailSection(
                    theme,
                    'Application',
                    Icons.description_outlined,
                    [
                      _buildDetailRow(theme, 'Applied', DateFormat.yMMMd().add_jm().format(application.createdAt)),
                      if (application.resumeUrl != null)
                        _buildDetailRow(
                          theme,
                          'Resume',
                          'View Resume',
                          isLink: true,
                          onTap: () => _openUrl(application.resumeUrl!),
                        ),
                      if (application.hasCoverLetterFile)
                        _buildDetailRow(
                          theme,
                          'Cover Letter',
                          'View Cover Letter',
                          isLink: true,
                          onTap: () {
                            final path = application.coverLetterFilePath;
                            if (path != null) {
                              _openUrl('https://faajpcarasilbfndzkmd.supabase.co/storage/v1/object/public/job-applications/$path');
                            }
                          },
                        )
                      else if (application.coverLetter != null && !application.hasCoverLetterFile)
                        _buildDetailRow(theme, 'Cover Letter', application.coverLetter!),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Status actions
                  Text(
                    'Update Status',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildStatusButton(context, application, 'submitted', 'Submitted', Colors.blue),
                      _buildStatusButton(context, application, 'reviewed', 'Reviewed', Colors.orange),
                      _buildStatusButton(context, application, 'shortlisted', 'Shortlisted', Colors.purple),
                      _buildStatusButton(context, application, 'accepted', 'Accepted', Colors.green),
                      _buildStatusButton(context, application, 'rejected', 'Rejected', Colors.red),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection(
    ThemeData theme,
    String title,
    IconData icon,
    List<Widget> children,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildDetailRow(
    ThemeData theme,
    String label,
    String value, {
    bool isLink = false,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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
            child: InkWell(
              onTap: onTap,
              child: Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isLink ? theme.colorScheme.primary : null,
                  decoration: isLink ? TextDecoration.underline : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusButton(
    BuildContext context,
    JobApplication application,
    String status,
    String label,
    Color color,
  ) {
    final isSelected = application.status == status;

    return FilterChip(
      selected: isSelected,
      label: Text(label),
      selectedColor: color.withOpacity(0.2),
      checkmarkColor: color,
      side: BorderSide(color: isSelected ? color : Colors.grey.withOpacity(0.3)),
      onSelected: isSelected ? null : (_) async {
        Navigator.pop(context);
        await _updateApplicationStatus(application, status);
      },
    );
  }

  Future<void> _updateApplicationStatus(JobApplication application, String newStatus) async {
    try {
      await _jobsService.updateApplicationStatus(application.id, newStatus);
      await _loadStatusCounts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to ${JobApplication.statusLabel(newStatus)}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _exportApplicants(BuildContext context) {
    // TODO: Implement export functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export functionality coming soon')),
    );
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  Future<void> _openEmail(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
