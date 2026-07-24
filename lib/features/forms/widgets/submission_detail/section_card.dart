import 'package:flutter/material.dart';
import '../../models/submission_review_model.dart';
import '../../theme/moyd_brand.dart';
import 'answer_display.dart';

/// One card per form section: a full-bleed navy-tinted header band (gold rule
/// + title + answer count), then the answers rendered as content via
/// [AnswerDisplay]. On wide cards (>= 560px inner width) consecutive short
/// answers flow two-up so a run of one-word answers reads as a tidy grid
/// instead of a wall.
class SectionCard extends StatelessWidget {
  final ReviewSection section;

  /// Optional widget rendered above the answer rows (e.g. a policy grid).
  final Widget? leading;

  const SectionCard({super.key, required this.section, this.leading});

  /// Card inner width at which consecutive short answers flow two-up.
  static const double _twoUpMin = 560;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final answerCount =
        section.answers.length + section.policyPositions.length;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (section.title.isNotEmpty)
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              // Navy TINT of the ambient surface — the title stays
              // cs.onSurface, so contrast holds in both themes (~15:1 in
              // light over the 7% navy wash, >= 4.5:1 in dark over the
              // navySoft wash). The brightness branch exists only because
              // the tint direction flips per theme.
              color: isDark
                  ? MoydBrand.navySoft.withOpacity(0.45)
                  : MoydBrand.navy.withOpacity(0.07),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFD4A039), Color(0xFFB8860B)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      section.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  Text(
                    answerCount == 1 ? '1 answer' : '$answerCount answers',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final blocks =
                    _contentBlocks(constraints.maxWidth);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (int i = 0; i < blocks.length; i++) ...[
                      if (i > 0)
                        Divider(
                            height: 1,
                            color: cs.outlineVariant.withOpacity(0.6)),
                      blocks[i],
                    ],
                  ],
                );
              },
            ),
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
