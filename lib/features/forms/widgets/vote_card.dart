import 'package:flutter/material.dart';
import '../models/voting_form.dart';

/// Strip HTML tags from a string for plain text display
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

class VoteCard extends StatelessWidget {
  final VotingForm vote;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const VoteCard({
    Key? key,
    required this.vote,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      vote.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _buildStatusChip(vote.status),
                  if (onEdit != null || onDelete != null) ...[
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        color: colorScheme.onSurfaceVariant,
                      ),
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
              if (vote.description != null && vote.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _stripHtmlTags(vote.description!),
                  style: const TextStyle(color: Colors.grey),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  Chip(
                    label: Text(vote.questionCount == 1
                      ? '${vote.totalOptionCount} options'
                      : '${vote.questionCount} questions'),
                    visualDensity: VisualDensity.compact,
                  ),
                  if (vote.isVotingActive)
                    const Chip(
                      label: Text('VOTING OPEN'),
                      backgroundColor: Colors.green,
                      labelStyle: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              if (vote.votingEndsAt != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.event, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      vote.isVotingActive
                        ? 'Ends: ${vote.votingEndsAt!.toLocal().toString().split(' ')[0]}'
                        : vote.hasEnded
                          ? 'Ended: ${vote.votingEndsAt!.toLocal().toString().split(' ')[0]}'
                          : 'Starts: ${vote.votingStartsAt != null ? vote.votingStartsAt!.toLocal().toString().split(' ')[0] : "TBD"}',
                      style: const TextStyle(fontSize: 14),
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

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'draft':
        color = Colors.grey;
        break;
      case 'active':
        color = Colors.green;
        break;
      case 'closed':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Chip(
      label: Text(
        status.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: color,
      visualDensity: VisualDensity.compact,
    );
  }
}
