import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/voting_form.dart';

/// Beautiful animated vote results display with pie chart and progress bars
class VoteResultsChart extends StatefulWidget {
  final VotingForm vote;
  final bool showAnimation;

  const VoteResultsChart({
    Key? key,
    required this.vote,
    this.showAnimation = true,
  }) : super(key: key);

  @override
  State<VoteResultsChart> createState() => _VoteResultsChartState();
}

class _VoteResultsChartState extends State<VoteResultsChart>
    with SingleTickerProviderStateMixin {
  int touchedIndex = -1;
  late AnimationController _animationController;
  late Animation<double> _animation;

  static const List<Color> _chartColors = [
    Color(0xFF6366F1), // Indigo
    Color(0xFF8B5CF6), // Violet
    Color(0xFF10B981), // Emerald
    Color(0xFFF59E0B), // Amber
    Color(0xFFEC4899), // Pink
    Color(0xFF3B82F6), // Blue
    Color(0xFFEF4444), // Red
    Color(0xFF14B8A6), // Teal
    Color(0xFFF97316), // Orange
    Color(0xFF84CC16), // Lime
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
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

  int get totalVotes =>
      widget.vote.options.fold(0, (sum, option) => sum + option.votes);

  VotingOption? get winningOption {
    if (widget.vote.options.isEmpty) return null;
    return widget.vote.options.reduce((a, b) => a.votes > b.votes ? a : b);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (widget.vote.options.isEmpty) {
      return _buildEmptyState(theme, colorScheme);
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Results header
            _buildResultsHeader(theme, colorScheme),
            const SizedBox(height: 24),

            // Main chart and legend
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 500;
                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 1,
                        child: _buildPieChart(),
                      ),
                      const SizedBox(width: 32),
                      Expanded(
                        flex: 1,
                        child: _buildProgressBars(theme),
                      ),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      SizedBox(
                        height: 220,
                        child: _buildPieChart(),
                      ),
                      const SizedBox(height: 24),
                      _buildProgressBars(theme),
                    ],
                  );
                }
              },
            ),
            const SizedBox(height: 24),

            // Winner announcement (if voting ended)
            if (widget.vote.hasEnded && winningOption != null)
              _buildWinnerCard(theme, colorScheme),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.how_to_vote_outlined,
            size: 64,
            color: colorScheme.onSurfaceVariant.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No votes yet',
            style: theme.textTheme.titleLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsHeader(ThemeData theme, ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.how_to_vote,
                size: 28,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Votes',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  TweenAnimationBuilder<int>(
                    tween: IntTween(
                      begin: 0,
                      end: (totalVotes * _animation.value).round(),
                    ),
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return Text(
                        value.toString(),
                        style: theme.textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            _buildVotingStatusBadge(theme, colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildVotingStatusBadge(ThemeData theme, ColorScheme colorScheme) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (widget.vote.notStarted) {
      statusColor = Colors.orange;
      statusText = 'Pending';
      statusIcon = Icons.schedule;
    } else if (widget.vote.isVotingActive) {
      statusColor = Colors.green;
      statusText = 'Active';
      statusIcon = Icons.play_circle_outline;
    } else {
      statusColor = Colors.grey;
      statusText = 'Ended';
      statusIcon = Icons.check_circle_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, size: 18, color: statusColor),
          const SizedBox(width: 6),
          Text(
            statusText,
            style: theme.textTheme.labelLarge?.copyWith(
              color: statusColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart() {
    return SizedBox(
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        pieTouchResponse == null ||
                        pieTouchResponse.touchedSection == null) {
                      touchedIndex = -1;
                      return;
                    }
                    touchedIndex =
                        pieTouchResponse.touchedSection!.touchedSectionIndex;
                  });
                },
              ),
              sectionsSpace: 3,
              centerSpaceRadius: 60,
              startDegreeOffset: -90,
              sections: _buildPieSections(),
            ),
          ),
          // Center text
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (touchedIndex >= 0 &&
                  touchedIndex < widget.vote.options.length) ...[
                Text(
                  '${(widget.vote.options[touchedIndex].votes / totalVotes * 100 * _animation.value).toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _chartColors[touchedIndex % _chartColors.length],
                  ),
                ),
                Text(
                  widget.vote.options[touchedIndex].label,
                  style: const TextStyle(fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ] else ...[
                Text(
                  '${widget.vote.options.length}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'Options',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildPieSections() {
    return widget.vote.options.asMap().entries.map((entry) {
      final index = entry.key;
      final option = entry.value;
      final isTouched = index == touchedIndex;
      final isWinner =
          widget.vote.hasEnded && option.id == winningOption?.id;
      final percentage =
          totalVotes > 0 ? (option.votes / totalVotes * 100) : 0.0;

      return PieChartSectionData(
        color: _chartColors[index % _chartColors.length],
        value: (option.votes * _animation.value).clamp(0.01, double.infinity),
        title: '',
        radius: isTouched
            ? 55
            : isWinner
                ? 50
                : 45,
        badgeWidget: isTouched
            ? null
            : isWinner
                ? Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.emoji_events,
                      color: Colors.white,
                      size: 16,
                    ),
                  )
                : null,
        badgePositionPercentageOffset: 1.3,
      );
    }).toList();
  }

  Widget _buildProgressBars(ThemeData theme) {
    final sortedOptions = List<VotingOption>.from(widget.vote.options)
      ..sort((a, b) => b.votes.compareTo(a.votes));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sortedOptions.asMap().entries.map((entry) {
        final index = entry.key;
        final option = entry.value;
        final originalIndex = widget.vote.options.indexOf(option);
        final percentage =
            totalVotes > 0 ? (option.votes / totalVotes) : 0.0;
        final isWinner =
            widget.vote.hasEnded && option.id == winningOption?.id;
        final color = _chartColors[originalIndex % _chartColors.length];

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (isWinner)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(
                        Icons.emoji_events,
                        size: 16,
                        color: Colors.amber,
                      ),
                    ),
                  Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      option.label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: isWinner ? FontWeight.bold : FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: percentage * _animation.value),
                    duration: Duration(milliseconds: 800 + (index * 100)),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return Text(
                        '${(value * 100).toStringAsFixed(1)}%',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Stack(
                children: [
                  Container(
                    height: 28,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: percentage * _animation.value),
                    duration: Duration(milliseconds: 800 + (index * 100)),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return FractionallySizedBox(
                        widthFactor: value.clamp(0.0, 1.0),
                        child: Container(
                          height: 28,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                color,
                                color.withOpacity(0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: isWinner
                                ? [
                                    BoxShadow(
                                      color: color.withOpacity(0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 8),
                          child: value > 0.1
                              ? Text(
                                  '${(option.votes * _animation.value).round()}',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildWinnerCard(ThemeData theme, ColorScheme colorScheme) {
    final winner = winningOption!;
    final winnerIndex = widget.vote.options.indexOf(winner);
    final winnerColor = _chartColors[winnerIndex % _chartColors.length];
    final percentage =
        totalVotes > 0 ? (winner.votes / totalVotes * 100) : 0.0;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.8 + (0.2 * value),
          child: Opacity(
            opacity: value,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [
                      Colors.amber.shade300,
                      Colors.amber.shade600,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.emoji_events,
                          size: 32,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Winner',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                            Text(
                              winner.label,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${percentage.toStringAsFixed(1)}%',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '${winner.votes} votes',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Compact vote results widget for cards/list items
class VoteResultsCompact extends StatelessWidget {
  final VotingForm vote;

  const VoteResultsCompact({
    Key? key,
    required this.vote,
  }) : super(key: key);

  int get totalVotes =>
      vote.options.fold(0, (sum, option) => sum + option.votes);

  static const List<Color> _chartColors = [
    Color(0xFF6366F1),
    Color(0xFF8B5CF6),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEC4899),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (totalVotes == 0) {
      return Text(
        'No votes yet',
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      );
    }

    // Show top 3 options as mini bars
    final topOptions = List<VotingOption>.from(vote.options)
      ..sort((a, b) => b.votes.compareTo(a.votes));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: topOptions.take(3).map((option) {
        final index = vote.options.indexOf(option);
        final percentage = option.votes / totalVotes;
        final color = _chartColors[index % _chartColors.length];

        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  option.label,
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: percentage,
                    backgroundColor: color.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 35,
                child: Text(
                  '${(percentage * 100).toStringAsFixed(0)}%',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
