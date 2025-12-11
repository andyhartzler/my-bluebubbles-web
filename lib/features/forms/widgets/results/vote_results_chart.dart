import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/voting_form.dart';

/// Beautiful animated vote results display supporting multi-question votes
class VoteResultsChart extends StatefulWidget {
  final VotingForm vote;
  final bool showAnimation;
  final Map<String, dynamic>? resultsData;
  /// Optional pre-calculated questions with vote counts (overrides vote.questions)
  final List<Map<String, dynamic>>? calculatedQuestions;

  const VoteResultsChart({
    Key? key,
    required this.vote,
    this.showAnimation = true,
    this.resultsData,
    this.calculatedQuestions,
  }) : super(key: key);

  @override
  State<VoteResultsChart> createState() => _VoteResultsChartState();
}

class _VoteResultsChartState extends State<VoteResultsChart>
    with SingleTickerProviderStateMixin {
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

  /// Get questions - prefer calculatedQuestions if provided
  List<Map<String, dynamic>> get _questions =>
      widget.calculatedQuestions ?? widget.vote.questions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final questions = _questions;

    if (questions.isEmpty) {
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

            // Display each question's results
            ...questions.asMap().entries.map((entry) {
              final index = entry.key;
              final question = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: _buildQuestionResults(
                  theme,
                  colorScheme,
                  question,
                  index,
                ),
              );
            }),
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
            'No questions configured',
            style: theme.textTheme.titleLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsHeader(ThemeData theme, ColorScheme colorScheme) {
    final questionCount = widget.vote.questionCount;

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
                    questionCount == 1 ? '1 Question' : '$questionCount Questions',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    '${widget.vote.totalOptionCount} total options',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
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

  Widget _buildQuestionResults(
    ThemeData theme,
    ColorScheme colorScheme,
    Map<String, dynamic> question,
    int questionIndex,
  ) {
    final questionText = question['text'] as String? ?? 'Question ${questionIndex + 1}';
    final questionType = question['question_type'] as String? ?? 'multiple_choice';
    final options = (question['options'] as List<dynamic>?) ?? [];

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
            // Question header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Q${questionIndex + 1}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    questionText,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildQuestionTypeChip(theme, colorScheme, questionType),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // Results based on question type
            _buildResultsForType(theme, colorScheme, questionType, options, questionIndex),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionTypeChip(
    ThemeData theme,
    ColorScheme colorScheme,
    String questionType,
  ) {
    IconData icon;
    String label;
    Color color;

    switch (questionType) {
      case 'multiple_choice':
        icon = Icons.radio_button_checked;
        label = 'Single Choice';
        color = Colors.blue;
        break;
      case 'multiple_select':
        icon = Icons.check_box;
        label = 'Multi-Select';
        color = Colors.purple;
        break;
      case 'ranked_choice':
        icon = Icons.format_list_numbered;
        label = 'Ranked';
        color = Colors.orange;
        break;
      case 'yes_no':
        icon = Icons.thumbs_up_down;
        label = 'Yes/No';
        color = Colors.green;
        break;
      case 'rating_scale':
        icon = Icons.star;
        label = 'Rating';
        color = Colors.amber;
        break;
      case 'short_answer':
        icon = Icons.short_text;
        label = 'Text';
        color = Colors.teal;
        break;
      default:
        icon = Icons.help_outline;
        label = questionType;
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsForType(
    ThemeData theme,
    ColorScheme colorScheme,
    String questionType,
    List<dynamic> options,
    int questionIndex,
  ) {
    switch (questionType) {
      case 'multiple_choice':
      case 'multiple_select':
        return _buildChoiceResults(theme, colorScheme, options, questionIndex);
      case 'yes_no':
        return _buildYesNoResults(theme, colorScheme, questionIndex);
      case 'rating_scale':
        return _buildRatingResults(theme, colorScheme, options, questionIndex);
      case 'ranked_choice':
        return _buildRankedResults(theme, colorScheme, options, questionIndex);
      case 'short_answer':
        return _buildShortAnswerResults(theme, colorScheme);
      default:
        return _buildChoiceResults(theme, colorScheme, options, questionIndex);
    }
  }

  Widget _buildChoiceResults(
    ThemeData theme,
    ColorScheme colorScheme,
    List<dynamic> options,
    int questionIndex,
  ) {
    if (options.isEmpty) {
      return Text(
        'No options configured',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      );
    }

    // Calculate total votes for this question
    int totalVotes = 0;
    for (final opt in options) {
      final votes = (opt as Map<String, dynamic>)['votes'] as int? ?? 0;
      totalVotes += votes;
    }

    // Find winning option
    Map<String, dynamic>? winner;
    int maxVotes = 0;
    for (final opt in options) {
      final votes = (opt as Map<String, dynamic>)['votes'] as int? ?? 0;
      if (votes > maxVotes) {
        maxVotes = votes;
        winner = opt;
      }
    }

    // Sort by votes descending
    final sortedOptions = List<Map<String, dynamic>>.from(
      options.map((o) => o as Map<String, dynamic>),
    )..sort((a, b) => ((b['votes'] as int?) ?? 0).compareTo((a['votes'] as int?) ?? 0));

    return Column(
      children: [
        ...sortedOptions.asMap().entries.map((entry) {
          final index = entry.key;
          final option = entry.value;
          final label = option['label'] as String? ?? 'Option';
          final votes = option['votes'] as int? ?? 0;
          final percentage = totalVotes > 0 ? votes / totalVotes : 0.0;
          final isWinner = widget.vote.hasEnded && option == winner && votes > 0;
          final color = _chartColors[(questionIndex * 3 + index) % _chartColors.length];

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
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
                        label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: isWinner ? FontWeight.bold : FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(percentage * 100 * _animation.value).toStringAsFixed(1)}%',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Stack(
                  children: [
                    Container(
                      height: 24,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: (percentage * _animation.value).clamp(0.0, 1.0),
                      child: Container(
                        height: 24,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [color, color.withOpacity(0.8)],
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 8),
                        child: percentage > 0.1
                            ? Text(
                                '${(votes * _animation.value).round()}',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
        if (totalVotes > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '$totalVotes total votes',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildYesNoResults(
    ThemeData theme,
    ColorScheme colorScheme,
    int questionIndex,
  ) {
    // For yes/no questions, we'll show a simple two-bar chart
    final options = [
      {'label': 'Yes', 'votes': 0},
      {'label': 'No', 'votes': 0},
    ];

    return _buildChoiceResults(theme, colorScheme, options, questionIndex);
  }

  Widget _buildRatingResults(
    ThemeData theme,
    ColorScheme colorScheme,
    List<dynamic> options,
    int questionIndex,
  ) {
    // For rating scale, show a histogram-style display
    // Options typically represent rating levels (1-5 stars, etc.)
    if (options.isEmpty) {
      return Text(
        'No ratings yet',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Column(
      children: [
        // Show average rating if available
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star, color: Colors.amber, size: 32),
              const SizedBox(width: 8),
              Text(
                'Rating Results',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildChoiceResults(theme, colorScheme, options, questionIndex),
      ],
    );
  }

  Widget _buildRankedResults(
    ThemeData theme,
    ColorScheme colorScheme,
    List<dynamic> options,
    int questionIndex,
  ) {
    // For ranked choice, show options in their ranked order
    if (options.isEmpty) {
      return Text(
        'No rankings yet',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Column(
      children: [
        // Info about ranked choice
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ranked choice voting - Options ranked by voter preference',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.orange.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Display options with rank indicators
        ...options.asMap().entries.map((entry) {
          final index = entry.key;
          final option = entry.value as Map<String, dynamic>;
          final label = option['label'] as String? ?? 'Option';

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _chartColors[index % _chartColors.length],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildShortAnswerResults(
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.text_fields,
            size: 48,
            color: colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'Short Answer Question',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Individual responses can be viewed in the voter details below',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
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
    final questions = vote.questions;

    if (questions.isEmpty) {
      return Text(
        'No questions',
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      );
    }

    // Show summary for the first question
    final firstQuestion = questions.first;
    final options = (firstQuestion['options'] as List<dynamic>?) ?? [];

    if (options.isEmpty) {
      return Text(
        'No options configured',
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      );
    }

    // Calculate total votes
    int totalVotes = 0;
    for (final opt in options) {
      final votes = (opt as Map<String, dynamic>)['votes'] as int? ?? 0;
      totalVotes += votes;
    }

    if (totalVotes == 0) {
      return Text(
        'No votes yet',
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      );
    }

    // Sort by votes descending and take top 3
    final sortedOptions = List<Map<String, dynamic>>.from(
      options.map((o) => o as Map<String, dynamic>),
    )..sort((a, b) => ((b['votes'] as int?) ?? 0).compareTo((a['votes'] as int?) ?? 0));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sortedOptions.take(3).toList().asMap().entries.map((entry) {
        final index = entry.key;
        final option = entry.value;
        final label = option['label'] as String? ?? 'Option';
        final votes = option['votes'] as int? ?? 0;
        final percentage = votes / totalVotes;
        final color = _chartColors[index % _chartColors.length];

        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  label,
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
