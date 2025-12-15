import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/job.dart';

class JobCard extends StatelessWidget {
  final Job job;
  final int? applicationCount;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onViewApplicants;

  const JobCard({
    super.key,
    required this.job,
    this.applicationCount,
    required this.onTap,
    this.onEdit,
    this.onDelete,
    this.onViewApplicants,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isExpired = job.expiresAt != null && _isExpired(job.expiresAt!);
    final isExpiringSoon = job.expiresAt != null && _isExpiringSoon(job.expiresAt!);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: _getStatusColor(job.status),
                width: 4,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // Main content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title row with featured star
                      Row(
                        children: [
                          if (job.featured) ...[
                            Icon(Icons.star, size: 16, color: Colors.amber[700]),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(
                              job.title,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      // Organization
                      Text(
                        job.organization,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      // Submitter info
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
                              '${job.submitterName} • ${job.submitterEmail}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Tags row
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _buildCompactChip(context, job.jobType),
                          if (job.locationType != null)
                            _buildCompactChip(context, job.locationType!),
                          if (job.isPaid)
                            _buildCompactChip(context, 'Paid', color: Colors.green),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Right side info column
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Status chip
                    _buildStatusChip(job.status),
                    const SizedBox(height: 6),
                    // Application count
                    if (applicationCount != null && applicationCount! > 0)
                      InkWell(
                        onTap: onViewApplicants,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 14,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$applicationCount',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 4),
                    // Date info
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isExpired || isExpiringSoon) ...[
                          Icon(
                            Icons.timer_outlined,
                            size: 12,
                            color: isExpired ? Colors.red : Colors.orange,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            isExpired ? 'Expired' : 'Soon',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: isExpired ? Colors.red : Colors.orange,
                              fontWeight: FontWeight.w500,
                              fontSize: 10,
                            ),
                          ),
                        ] else ...[
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 12,
                            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            DateFormat.MMMd().format(job.createdAt),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                // Menu button
                if (onEdit != null || onDelete != null) ...[
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      color: theme.colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          onEdit?.call();
                          break;
                        case 'delete':
                          onDelete?.call();
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      if (onEdit != null)
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined),
                              SizedBox(width: 12),
                              Text('Edit'),
                            ],
                          ),
                        ),
                      if (onDelete != null) ...[
                        if (onEdit != null) const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, color: Colors.red),
                              SizedBox(width: 12),
                              Text('Delete', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactChip(BuildContext context, String label, {IconData? icon, Color? color}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: (color ?? theme.colorScheme.surfaceContainerHighest).withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color ?? theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 2),
          ],
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color ?? theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
              fontSize: 10,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final color = _getStatusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  bool _isExpired(DateTime date) {
    return date.isBefore(DateTime.now());
  }

  bool _isExpiringSoon(DateTime date) {
    final daysUntil = date.difference(DateTime.now()).inDays;
    return daysUntil >= 0 && daysUntil <= 7;
  }
}
