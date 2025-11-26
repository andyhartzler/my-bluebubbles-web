import 'package:flutter/material.dart';

class CampaignStatsWidget extends StatelessWidget {
  final int sent;
  final int expected;
  final int opened;
  final int clicked;
  final Color? color;

  const CampaignStatsWidget({
    super.key,
    required this.sent,
    required this.expected,
    required this.opened,
    required this.clicked,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = color ?? theme.colorScheme.onSurface;

    Widget buildStat(String label, int value) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value.toString(),
            style: theme.textTheme.titleLarge?.copyWith(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(color: textColor.withOpacity(0.8)),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        buildStat('Expected', expected),
        buildStat('Sent', sent),
        buildStat('Opened', opened),
        buildStat('Clicked', clicked),
      ],
    );
  }
}
