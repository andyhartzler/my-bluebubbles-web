import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/bill_vote.dart';
import '../utils/bill_helpers.dart';

/// Widget displaying vote breakdown with chart and details
class VoteBreakdownChart extends StatelessWidget {
  final List<BillVote> votes;
  final VoidCallback? onMarkSeen;
  final bool showMarkSeenButton;

  const VoteBreakdownChart({
    super.key,
    required this.votes,
    this.onMarkSeen,
    this.showMarkSeenButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (votes.isEmpty) {
      return _buildEmptyState(context, theme);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: votes.length,
      itemBuilder: (context, index) {
        final vote = votes[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildVoteCard(context, theme, vote),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.how_to_vote,
            size: 48,
            color: theme.colorScheme.outline.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No votes yet',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Floor votes will appear here when they occur',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoteCard(BuildContext context, ThemeData theme, BillVote vote) {
    final passed = vote.passed;

    return Card(
      elevation: vote.isNew ? 2 : 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                // Result badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: passed ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: passed ? Colors.green : Colors.red,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        passed ? Icons.check_circle : Icons.cancel,
                        size: 16,
                        color: passed ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        passed ? 'PASSED' : 'FAILED',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: passed ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Chamber badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    vote.chamberDisplay,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                // Date
                Text(
                  BillHelpers.formatDate(vote.voteDate),
                  style: theme.textTheme.labelMedium,
                ),
                if (vote.isNew) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'NEW',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // Motion text
            Text(
              vote.motionText,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),

            // Vote counts and pie chart
            Row(
              children: [
                // Pie chart
                SizedBox(
                  width: 120,
                  height: 120,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 30,
                      sections: [
                        PieChartSectionData(
                          value: vote.yesCount.toDouble(),
                          title: '${vote.yesCount}',
                          color: Colors.green,
                          radius: 30,
                          titleStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        PieChartSectionData(
                          value: vote.noCount.toDouble(),
                          title: '${vote.noCount}',
                          color: Colors.red,
                          radius: 30,
                          titleStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (vote.abstainCount > 0 || vote.notVotingCount > 0)
                          PieChartSectionData(
                            value: (vote.abstainCount + vote.notVotingCount).toDouble(),
                            title: '',
                            color: Colors.grey,
                            radius: 30,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 24),

                // Vote counts breakdown
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCountRow(
                        theme,
                        label: 'Yes',
                        count: vote.yesCount,
                        color: Colors.green,
                      ),
                      const SizedBox(height: 8),
                      _buildCountRow(
                        theme,
                        label: 'No',
                        count: vote.noCount,
                        color: Colors.red,
                      ),
                      if (vote.abstainCount > 0) ...[
                        const SizedBox(height: 8),
                        _buildCountRow(
                          theme,
                          label: 'Abstain',
                          count: vote.abstainCount,
                          color: Colors.orange,
                        ),
                      ],
                      if (vote.notVotingCount > 0) ...[
                        const SizedBox(height: 8),
                        _buildCountRow(
                          theme,
                          label: 'Not Voting',
                          count: vote.notVotingCount,
                          color: Colors.grey,
                        ),
                      ],
                      if (vote.absentCount > 0) ...[
                        const SizedBox(height: 8),
                        _buildCountRow(
                          theme,
                          label: 'Absent',
                          count: vote.absentCount,
                          color: Colors.grey.shade400,
                        ),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        'Total: ${vote.totalVotes}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Party breakdown (if available)
            if (vote.votesDetail != null && vote.votesDetail!.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'By Party',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _buildPartyBreakdown(theme, vote),
            ],

            // Individual votes expand button
            if (vote.votesDetail != null && vote.votesDetail!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Center(
                child: TextButton.icon(
                  onPressed: () => _showIndividualVotes(context, theme, vote),
                  icon: const Icon(Icons.people, size: 18),
                  label: const Text('View Individual Votes'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCountRow(
    ThemeData theme, {
    required String label,
    required int count,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: theme.textTheme.bodySmall)),
        Text(
          '$count',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildPartyBreakdown(ThemeData theme, BillVote vote) {
    final partyVotes = vote.votesByParty;

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: partyVotes.entries.map((entry) {
        final party = entry.key;
        final votes = entry.value;
        final yes = votes['yes'] ?? 0;
        final no = votes['no'] ?? 0;
        final color = BillHelpers.getPartyColor(party);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Text(
                party,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$yes',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(' - '),
                  Text(
                    '$no',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  void _showIndividualVotes(BuildContext context, ThemeData theme, BillVote vote) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  bottom: BorderSide(color: theme.dividerColor),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    'Individual Votes',
                    style: theme.textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: vote.votesDetail!.length,
                itemBuilder: (context, index) {
                  final detail = vote.votesDetail![index];
                  final color = BillHelpers.getPartyColor(detail.party);
                  final voteColor = detail.option.toLowerCase() == 'yes'
                      ? Colors.green
                      : detail.option.toLowerCase() == 'no'
                          ? Colors.red
                          : Colors.grey;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: color.withOpacity(0.2),
                      child: Text(
                        BillHelpers.getPartyAbbreviation(detail.party),
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(detail.voterNameFull ?? detail.voterName),
                    subtitle: detail.party != null ? Text(detail.party!) : null,
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: voteColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        detail.option.toUpperCase(),
                        style: TextStyle(
                          color: voteColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
