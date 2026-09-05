import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/job_application.dart';
import '../../../models/crm/member.dart';

/// Card widget to display a job applicant
class JobApplicantCard extends StatelessWidget {
  final JobApplication application;
  final Member? member;
  final VoidCallback? onTap;
  final VoidCallback? onMemberTap;
  final ValueChanged<String>? onStatusChanged;

  const JobApplicantCard({
    super.key,
    required this.application,
    this.member,
    this.onTap,
    this.onMemberTap,
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
                  // Avatar - clickable to go to member profile
                  GestureDetector(
                    onTap: member != null ? onMemberTap : null,
                    child: _buildAvatar(theme),
                  ),
                  const SizedBox(width: 12),
                  // Name and email
                  Expanded(
                    child: GestureDetector(
                      onTap: member != null ? onMemberTap : null,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  application.applicantName,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: member != null ? theme.colorScheme.primary : null,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (member != null) ...[
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.verified,
                                  size: 16,
                                  color: theme.colorScheme.primary,
                                ),
                              ],
                            ],
                          ),
                          Text(
                            application.applicantEmail,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (member != null)
                            Text(
                              'Member',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
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
                        onPressed: () => _openStorageDoc(application.resumeUrl!),
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
                            _openStorageDoc(path);
                          }
                        },
                        icon: const Icon(Icons.article_outlined, size: 16),
                        label: const Text('Cover Letter'),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    if (member != null)
                      TextButton.icon(
                        onPressed: onMemberTap,
                        icon: const Icon(Icons.person_outlined, size: 16),
                        label: const Text('Profile'),
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

  Widget _buildAvatar(ThemeData theme) {
    final photoUrl = member?.effectiveAvatarUrl;

    if (photoUrl != null && photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundColor: theme.colorScheme.primaryContainer,
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: photoUrl,
            width: 48,
            height: 48,
            fit: BoxFit.cover,
            placeholder: (context, url) => Center(
              child: Text(
                _getInitials(application.applicantName),
                style: TextStyle(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            errorWidget: (context, url, error) => Text(
              _getInitials(application.applicantName),
              style: TextStyle(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: 24,
      backgroundColor: member != null
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainerHighest,
      child: Text(
        _getInitials(application.applicantName),
        style: TextStyle(
          color: member != null
              ? theme.colorScheme.onPrimaryContainer
              : theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.bold,
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

  /// Reduce a stored value to a bucket-relative object path. New rows store the
  /// bare path; legacy rows may hold a full /object/public/ URL, so strip
  /// everything up to and including the bucket segment.
  String _storagePath(String value) {
    const marker = '/job-applications/';
    final idx = value.indexOf(marker);
    return idx >= 0 ? value.substring(idx + marker.length) : value;
  }

  /// The job-applications bucket is private. Staff (is_staff() true) can read it
  /// under the storage SELECT policy, so mint a short-lived signed URL from the
  /// stored path instead of building a dead /object/public/ link.
  Future<void> _openStorageDoc(String pathOrUrl) async {
    try {
      final signedUrl = await Supabase.instance.client.storage
          .from('job-applications')
          .createSignedUrl(_storagePath(pathOrUrl), 3600);
      await _openUrl(signedUrl);
    } catch (_) {
      // Signing failed (missing object or transient error); nothing to open.
    }
  }
}
