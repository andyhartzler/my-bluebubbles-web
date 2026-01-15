import 'package:flutter/material.dart';
import '../models/voting_form.dart';

// Brand colors matching the main dashboard
const _unityBlue = Color(0xFF273351);
const _momentumBlue = Color(0xFF32A6DE);

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
  final bool darkBackground;

  const VoteCard({
    Key? key,
    required this.vote,
    required this.onTap,
    this.onEdit,
    this.onDelete,
    this.darkBackground = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (darkBackground) {
      return _buildDarkCard(context);
    }
    return _buildLightCard(context);
  }

  Widget _buildDarkCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: _unityBlue,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
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
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  _buildStatusChip(vote.status),
                  if (onEdit != null || onDelete != null) ...[
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        color: Colors.white.withOpacity(0.8),
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
                const SizedBox(height: 10),
                Text(
                  _stripHtmlTags(vote.description!),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      vote.questionCount == 1
                          ? '${vote.totalOptionCount} options'
                          : '${vote.questionCount} questions',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ),
                  if (vote.isVotingActive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'VOTING OPEN',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              if (vote.votingEndsAt != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.event, size: 16, color: Colors.white.withOpacity(0.7)),
                    const SizedBox(width: 6),
                    Text(
                      vote.isVotingActive
                          ? 'Ends: ${vote.votingEndsAt!.toLocal().toString().split(' ')[0]}'
                          : vote.hasEnded
                              ? 'Ended: ${vote.votingEndsAt!.toLocal().toString().split(' ')[0]}'
                              : 'Starts: ${vote.votingStartsAt != null ? vote.votingStartsAt!.toLocal().toString().split(' ')[0] : "TBD"}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.8),
                      ),
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

  Widget _buildLightCard(BuildContext context) {
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
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
}
