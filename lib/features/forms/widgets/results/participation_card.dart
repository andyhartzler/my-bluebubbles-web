import 'package:flutter/material.dart';
import '../../models/vote_analytics.dart';

/// Card widget showing vote participation metrics
class ParticipationCard extends StatelessWidget {
  final VoteResultsSummary results;

  const ParticipationCard({Key? key, required this.results}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final participationColor = results.participationRate >= 50
        ? Colors.green
        : results.participationRate >= 25
            ? Colors.orange
            : Colors.red;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Participation',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _StatColumn(
                    label: 'Total Votes',
                    value: results.totalVotes.toString(),
                    color: Colors.blue,
                  ),
                ),
                Expanded(
                  child: _StatColumn(
                    label: 'Eligible Voters',
                    value: results.eligibleVoters.toString(),
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                Expanded(
                  child: _StatColumn(
                    label: 'Participation',
                    value: '${results.participationRate.toStringAsFixed(1)}%',
                    color: participationColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  Container(
                    height: 16,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: (results.participationRate / 100).clamp(0.0, 1.0),
                    child: Container(
                      height: 16,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            participationColor,
                            participationColor.withOpacity(0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Participation status
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: participationColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: participationColor.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getParticipationIcon(results.participationRate),
                      size: 18,
                      color: participationColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _getParticipationLabel(results.participationRate),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: participationColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getParticipationIcon(double rate) {
    if (rate >= 75) return Icons.sentiment_very_satisfied;
    if (rate >= 50) return Icons.sentiment_satisfied;
    if (rate >= 25) return Icons.sentiment_neutral;
    return Icons.sentiment_dissatisfied;
  }

  String _getParticipationLabel(double rate) {
    if (rate >= 75) return 'Excellent Participation';
    if (rate >= 50) return 'Good Participation';
    if (rate >= 25) return 'Moderate Participation';
    return 'Low Participation';
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatColumn({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Compact participation indicator for cards/list items
class ParticipationIndicator extends StatelessWidget {
  final int totalVotes;
  final int eligibleVoters;

  const ParticipationIndicator({
    Key? key,
    required this.totalVotes,
    required this.eligibleVoters,
  }) : super(key: key);

  double get participationRate =>
      eligibleVoters > 0 ? (totalVotes / eligibleVoters * 100) : 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final color = participationRate >= 50
        ? Colors.green
        : participationRate >= 25
            ? Colors.orange
            : Colors.red;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: (participationRate / 100).clamp(0.0, 1.0),
                strokeWidth: 4,
                backgroundColor: color.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
              Text(
                '${participationRate.toStringAsFixed(0)}%',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$totalVotes votes',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'of $eligibleVoters eligible',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
