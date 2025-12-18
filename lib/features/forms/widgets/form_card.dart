import 'package:flutter/material.dart';
import '../models/form_schema.dart';

class FormCard extends StatelessWidget {
  final FormSchema form;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onViewResults;
  final VoidCallback? onDelete;
  final VoidCallback? onDuplicate;

  const FormCard({
    Key? key,
    required this.form,
    required this.onTap,
    this.onEdit,
    this.onViewResults,
    this.onDelete,
    this.onDuplicate,
  }) : super(key: key);

  /// Strips HTML tags from a string and returns plain text
  String _stripHtmlTags(String htmlString) {
    // Remove HTML tags
    final withoutTags = htmlString.replaceAll(RegExp(r'<[^>]*>'), ' ');
    // Decode common HTML entities
    return withoutTags
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Form type icon
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _getFormTypeColor(form.formType).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getFormTypeIcon(form.formType),
                      color: _getFormTypeColor(form.formType),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          form.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _buildStatusChip(context, form.status),
                            const SizedBox(width: 8),
                            Text(
                              _capitalize(form.formType),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (form.description != null && form.description!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  _stripHtmlTags(form.description!),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 16),
              // Stats row
              Row(
                children: [
                  _buildStatItem(
                    context,
                    Icons.list_alt,
                    '${form.schema.fields.length} fields',
                  ),
                  const SizedBox(width: 16),
                  if (form.submissionCount > 0)
                    _buildStatItem(
                      context,
                      Icons.people_outline,
                      '${form.submissionCount} submissions',
                    ),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 12),
              // Actions row
              Row(
                children: [
                  if (form.submissionCount > 0 && onViewResults != null)
                    _buildActionButton(
                      context,
                      Icons.bar_chart,
                      'Results',
                      onViewResults!,
                      isPrimary: true,
                    ),
                  const Spacer(),
                  if (onEdit != null)
                    IconButton(
                      icon: Icon(
                        Icons.edit_outlined,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      onPressed: onEdit,
                      tooltip: 'Edit Form',
                      style: IconButton.styleFrom(
                        backgroundColor: colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    onSelected: (value) {
                      switch (value) {
                        case 'delete':
                          onDelete?.call();
                          break;
                        case 'duplicate':
                          onDuplicate?.call();
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'duplicate',
                        child: Row(
                          children: [
                            Icon(Icons.copy),
                            SizedBox(width: 12),
                            Text('Duplicate'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'share',
                        child: Row(
                          children: [
                            Icon(Icons.share),
                            SizedBox(width: 12),
                            Text('Share'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
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
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, IconData icon, String label) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onPressed, {
    bool isPrimary = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (isPrimary) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          visualDensity: VisualDensity.compact,
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context, String status) {
    Color color;
    IconData icon;

    switch (status) {
      case 'draft':
        color = Colors.orange;
        icon = Icons.edit_note;
        break;
      case 'active':
        color = Colors.green;
        icon = Icons.check_circle_outline;
        break;
      default:
        color = Colors.grey;
        icon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            _capitalize(status),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getFormTypeIcon(String type) {
    switch (type) {
      case 'survey':
        return Icons.poll_outlined;
      case 'registration':
        return Icons.person_add_outlined;
      case 'feedback':
        return Icons.feedback_outlined;
      case 'vote':
        return Icons.how_to_vote_outlined;
      default:
        return Icons.description_outlined;
    }
  }

  Color _getFormTypeColor(String type) {
    switch (type) {
      case 'survey':
        return const Color(0xFF6366F1); // Indigo
      case 'registration':
        return const Color(0xFF10B981); // Emerald
      case 'feedback':
        return const Color(0xFFF59E0B); // Amber
      case 'vote':
        return const Color(0xFF8B5CF6); // Violet
      default:
        return const Color(0xFF3B82F6); // Blue
    }
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}
