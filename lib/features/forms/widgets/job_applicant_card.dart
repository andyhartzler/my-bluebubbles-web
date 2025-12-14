import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/job_application.dart';

/// Card widget to display a job applicant
class JobApplicantCard extends StatelessWidget {
  final JobApplication application;
  final VoidCallback? onTap;
  final ValueChanged<String>? onStatusChanged;

  const JobApplicantCard({
    super.key,
    required this.application,
    this.onTap,
    this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = Color(JobApplication.statusColor(application.status));

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Avatar
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      _getInitials(application.applicantName),
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
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
                          application.applicantName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          application.applicantEmail,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status chip
                  _buildStatusChip(statusColor),
                ],
              ),
              const SizedBox(height: 8),
              // Additional info row
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  if (application.applicantPhone != null)
                    _buildInfoChip(
                      context,
                      Icons.phone_outlined,
                      application.applicantPhone!,
                    ),
                  if (application.applicantCity != null)
                    _buildInfoChip(
                      context,
                      Icons.location_on_outlined,
                      application.applicantCity!,
                    ),
                  _buildInfoChip(
                    context,
                    Icons.calendar_today_outlined,
                    DateFormat.yMMMd().format(application.createdAt),
                  ),
                ],
              ),
              // Quick actions row
              if (application.resumeUrl != null || application.coverLetter != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (application.resumeUrl != null)
                      TextButton.icon(
                        onPressed: () => _openUrl(application.resumeUrl!),
                        icon: const Icon(Icons.description_outlined, size: 16),
                        label: const Text('Resume'),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    if (application.hasCoverLetterFile)
                      TextButton.icon(
                        onPressed: () {
                          final path = application.coverLetterFilePath;
                          if (path != null) {
                            _openUrl('https://faajpcarasilbfndzkmd.supabase.co/storage/v1/object/public/job-applications/$path');
                          }
                        },
                        icon: const Icon(Icons.article_outlined, size: 16),
                        label: const Text('Cover Letter'),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    const Spacer(),
                    // Status dropdown
                    if (onStatusChanged != null)
                      PopupMenuButton<String>(
                        initialValue: application.status,
                        onSelected: onStatusChanged,
                        tooltip: 'Change status',
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: theme.colorScheme.outline.withOpacity(0.5)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Status',
                                style: theme.textTheme.labelSmall,
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_drop_down, size: 18),
                            ],
                          ),
                        ),
                        itemBuilder: (context) => [
                          _buildStatusMenuItem('submitted', 'Submitted'),
                          _buildStatusMenuItem('reviewed', 'Reviewed'),
                          _buildStatusMenuItem('shortlisted', 'Shortlisted'),
                          _buildStatusMenuItem('accepted', 'Accepted'),
                          _buildStatusMenuItem('rejected', 'Rejected'),
                        ],
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        JobApplication.statusLabel(application.status),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildInfoChip(BuildContext context, IconData icon, String text) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  PopupMenuItem<String> _buildStatusMenuItem(String value, String label) {
    final color = Color(JobApplication.statusColor(value));
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(label),
          if (application.status == value) ...[
            const Spacer(),
            Icon(Icons.check, size: 16, color: color),
          ],
        ],
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
