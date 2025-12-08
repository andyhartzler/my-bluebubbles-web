import 'package:flutter/material.dart';
import '../models/voting_form.dart';

class VoteCard extends StatelessWidget {
  final VotingForm vote;
  final VoidCallback onTap;

  const VoteCard({
    Key? key,
    required this.vote,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
                ],
              ),
              if (vote.description != null) ...[
                const SizedBox(height: 8),
                Text(
                  vote.description!,
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
                    label: Text(vote.votingType),
                    visualDensity: VisualDensity.compact,
                  ),
                  Chip(
                    label: Text('${vote.options.length} options'),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              if (vote.endDate != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.event, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Ends: ${vote.endDate!.toLocal().toString().split(' ')[0]}',
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
