import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/bill_vote.dart';
import '../utils/bill_helpers.dart';

// Brand colors
const _unityBlue = Color(0xFF273351);
const _momentumBlue = Color(0xFF32A6DE);
const _grassrootsGreen = Color(0xFF43A047);
const _actionRed = Color(0xFFE63946);

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
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _unityBlue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.how_to_vote,
              size: 48,
              color: _unityBlue.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No votes yet',
            style: theme.textTheme.titleMedium?.copyWith(
              color: _unityBlue,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Floor votes will appear here when they occur',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: _unityBlue.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoteCard(BuildContext context, ThemeData theme, BillVote vote) {
    final passed = vote.passed;

    return Card(
      elevation: vote.isNew ? 3 : 2,
      color: _unityBlue,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: vote.isNew
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _momentumBlue, width: 2),
              )
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  // Result badge - passed/failed
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: passed ? _grassrootsGreen.withOpacity(0.2) : _actionRed.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: passed ? _grassrootsGreen : _actionRed),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          passed ? Icons.check_circle : Icons.cancel,
                          size: 16,
                          color: passed ? _grassrootsGreen : _actionRed,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          passed ? 'PASSED' : 'FAILED',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: passed ? _grassrootsGreen : _actionRed,
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
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      vote.chamberDisplay,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Date - white text
                  Text(
                    BillHelpers.formatDate(vote.voteDate),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                  if (vote.isNew) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _momentumBlue,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'NEW',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),

              // Motion text - white on dark
              Text(
                vote.motionText,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.9),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),

              // Vote counts and pie chart
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    // Pie chart with dashboard styling
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 3,
                          centerSpaceRadius: 28,
                          sections: [
                            PieChartSectionData(
                              value: vote.yesCount.toDouble(),
                              title: '${vote.yesCount}',
                              color: _grassrootsGreen,
                              radius: 32,
                              titleStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            PieChartSectionData(
                              value: vote.noCount.toDouble(),
                              title: '${vote.noCount}',
                              color: _actionRed,
                              radius: 32,
                              titleStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            if (vote.abstainCount > 0 || vote.notVotingCount > 0)
                              PieChartSectionData(
                                value: (vote.abstainCount + vote.notVotingCount).toDouble(),
                                title: '',
                                color: Colors.grey,
                                radius: 28,
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),

                    // Vote counts breakdown - white text
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildCountRow(label: 'Yes', count: vote.yesCount, color: _grassrootsGreen),
                          const SizedBox(height: 8),
                          _buildCountRow(label: 'No', count: vote.noCount, color: _actionRed),
                          if (vote.abstainCount > 0) ...[
                            const SizedBox(height: 8),
                            _buildCountRow(label: 'Abstain', count: vote.abstainCount, color: Colors.orange),
                          ],
                          if (vote.notVotingCount > 0) ...[
                            const SizedBox(height: 8),
                            _buildCountRow(label: 'Not Voting', count: vote.notVotingCount, color: Colors.grey),
                          ],
                          if (vote.absentCount > 0) ...[
                            const SizedBox(height: 8),
                            _buildCountRow(label: 'Absent', count: vote.absentCount, color: Colors.grey.shade400),
                          ],
                          const SizedBox(height: 12),
                          Text(
                            'Total: ${vote.totalVotes}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Party breakdown (if available)
              if (vote.votesDetail != null && vote.votesDetail!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Divider(color: Colors.white.withOpacity(0.2)),
                const SizedBox(height: 12),
                Text(
                  'By Party',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: _momentumBlue,
                  ),
                ),
                const SizedBox(height: 8),
                _buildPartyBreakdown(vote),
              ],

              // Individual votes expand button
              if (vote.votesDetail != null && vote.votesDetail!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: () => _showIndividualVotes(context, theme, vote),
                    icon: const Icon(Icons.people, size: 18),
                    label: const Text('View Individual Votes'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _momentumBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCountRow({required String label, required int count, required Color color}) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.8)),
          ),
        ),
        Text(
          '$count',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildPartyBreakdown(BillVote vote) {
    final partyVotes = vote.votesByParty;

    return Wrap(
      spacing: 12,
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
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Column(
            children: [
              Text(
                party,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$yes', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  Text(' - ', style: TextStyle(color: Colors.white.withOpacity(0.7))),
                  Text('$no', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
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
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _unityBlue,
                  border: const Border(bottom: BorderSide(color: Colors.white10)),
                ),
                child: Row(
                  children: [
                    const Text(
                      'Individual Votes',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // List - light background with dark text
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: vote.votesDetail!.length,
                  itemBuilder: (context, index) {
                    final detail = vote.votesDetail![index];
                    final color = BillHelpers.getPartyColor(detail.party);
                    final voteColor = detail.option.toLowerCase() == 'yes'
                        ? _grassrootsGreen
                        : detail.option.toLowerCase() == 'no'
                            ? _actionRed
                            : Colors.grey;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: color.withOpacity(0.2),
                        child: Text(
                          BillHelpers.getPartyAbbreviation(detail.party),
                          style: TextStyle(color: color, fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(
                        detail.voterNameFull ?? detail.voterName,
                        style: TextStyle(color: _unityBlue, fontWeight: FontWeight.w500),
                      ),
                      subtitle: detail.party != null
                          ? Text(detail.party!, style: TextStyle(color: _unityBlue.withOpacity(0.6)))
                          : null,
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: voteColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: voteColor.withOpacity(0.4)),
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
      ),
    );
  }
}
