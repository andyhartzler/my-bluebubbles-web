import 'package:flutter/material.dart';
import '../../models/vote_analytics.dart';

/// Animated engagement funnel visualization showing voter journey
class EngagementFunnelWidget extends StatefulWidget {
  final VoteAnalytics analytics;
  final bool showAnimation;

  const EngagementFunnelWidget({
    Key? key,
    required this.analytics,
    this.showAnimation = true,
  }) : super(key: key);

  @override
  State<EngagementFunnelWidget> createState() => _EngagementFunnelWidgetState();
}

class _EngagementFunnelWidgetState extends State<EngagementFunnelWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    if (widget.showAnimation) {
      _animationController.forward();
    } else {
      _animationController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final stages = [
      _FunnelStage(
        'Views',
        widget.analytics.totalViews,
        Colors.blue.shade300,
        Icons.visibility,
      ),
      _FunnelStage(
        'Started',
        widget.analytics.totalStarts,
        Colors.blue.shade500,
        Icons.play_circle_outline,
      ),
      _FunnelStage(
        'Submitted',
        widget.analytics.totalSubmissions,
        Colors.green,
        Icons.check_circle_outline,
      ),
    ];

    // Calculate max for width ratio
    final maxCount = stages.map((s) => s.count).reduce((a, b) => a > b ? a : b);

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
                Icon(Icons.filter_list, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Engagement Funnel',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Column(
                  children: stages.asMap().entries.map((entry) {
                    final index = entry.key;
                    final stage = entry.value;
                    final widthRatio = maxCount > 0
                        ? stage.count / maxCount
                        : 1.0;

                    return Column(
                      children: [
                        Row(
                          children: [
                            SizedBox(
                              width: 90,
                              child: Row(
                                children: [
                                  Icon(stage.icon, size: 18, color: stage.color),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      stage.label,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final barWidth = constraints.maxWidth * widthRatio * _animation.value;
                                  return Stack(
                                    children: [
                                      Container(
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: stage.color.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      AnimatedContainer(
                                        duration: const Duration(milliseconds: 300),
                                        height: 36,
                                        width: barWidth.clamp(0.0, constraints.maxWidth),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              stage.color,
                                              stage.color.withOpacity(0.8),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          '${(stage.count * _animation.value).round()}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        if (index < stages.length - 1) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const SizedBox(width: 90),
                              Padding(
                                padding: const EdgeInsets.only(left: 12),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.arrow_downward,
                                      size: 14,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _getConversionRate(index, stages),
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                        ],
                      ],
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            // Overall conversion rate
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.trending_up, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Overall Conversion: ${widget.analytics.overallConversionRate.toStringAsFixed(1)}%',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getConversionRate(int index, List<_FunnelStage> stages) {
    if (stages[index].count == 0) return '0% conversion';
    final rate = (stages[index + 1].count / stages[index].count) * 100;
    return '${rate.toStringAsFixed(1)}% conversion';
  }
}

class _FunnelStage {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  _FunnelStage(this.label, this.count, this.color, this.icon);
}
