import 'package:flutter/material.dart';
import '../../models/submission_review_model.dart';
import 'answer_display.dart';
import 'gold_rule_header.dart';
import 'review_text.dart';

/// One card per form section: the shared [GoldRuleHeader] (gold rule + title +
/// answer count), then the answers rendered as content via [AnswerDisplay]. On
/// wide cards (>= 560px inner width) consecutive short answers flow two-up so
/// a run of one-word answers reads as a tidy grid instead of a wall.
///
/// The navy-tinted header band is gone. It was the only card on the page
/// wearing one, which made the section cards read as a different product from
/// the verdict block sitting directly above them.
class SectionCard extends StatelessWidget {
  final ReviewSection section;

  /// Optional widget rendered above the answer rows (e.g. a policy grid).
  final Widget? leading;

  const SectionCard({super.key, required this.section, this.leading});

  /// Card inner width at which consecutive short answers flow two-up.
  static const double _twoUpMin = 560;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final answerCount =
        section.answers.length + section.policyPositions.length;

    return ReviewCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (section.title.isNotEmpty) ...[
            GoldRuleHeader(
              title: section.title,
              trailing: Text(
                answerCount == 1 ? '1 answer' : '$answerCount answers',
                style: ReviewText.caption(context),
              ),
            ),
            const SizedBox(height: 8),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              final blocks = _contentBlocks(constraints.maxWidth);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int i = 0; i < blocks.length; i++) ...[
                    if (i > 0)
                      Divider(
                          height: 1,
                          color: cs.outlineVariant.withValues(alpha: 0.6)),
                    blocks[i],
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// Leading widget + answer rows, with consecutive short answers grouped
  /// into a two-up wrap when the card body is wide enough.
  List<Widget> _contentBlocks(double width) {
    final twoUp = width >= _twoUpMin;
    final blocks = <Widget>[];
    if (leading != null) blocks.add(leading!);

    final answers = section.answers;
    var i = 0;
    while (i < answers.length) {
      if (twoUp && AnswerDisplay.flowsTwoUp(answers[i])) {
        final group = <ReviewAnswer>[];
        while (i < answers.length && AnswerDisplay.flowsTwoUp(answers[i])) {
          group.add(answers[i]);
          i++;
        }
        if (group.length == 1) {
          blocks.add(AnswerDisplay(answer: group.first));
        } else {
          final itemWidth = (width - 16) / 2;
          blocks.add(Wrap(
            spacing: 16,
            children: [
              for (final a in group)
                SizedBox(width: itemWidth, child: AnswerDisplay(answer: a)),
            ],
          ));
        }
      } else {
        blocks.add(AnswerDisplay(answer: answers[i]));
        i++;
      }
    }
    return blocks;
  }
}
