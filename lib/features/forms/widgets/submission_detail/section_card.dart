import 'package:flutter/material.dart';
import '../../models/submission_review_model.dart';

/// One card per form section: a titled, elevation-0 container whose answers
/// render as label/value rows separated by dividers. Responsive — the row
/// stacks (label above value) under 700px, otherwise a fixed 220px label
/// column with a flexible value.
class SectionCard extends StatelessWidget {
  final ReviewSection section;

  /// Optional widget rendered above the answer rows (e.g. a policy grid).
  final Widget? leading;

  const SectionCard({super.key, required this.section, this.leading});

  static const double _stackBreakpoint = 700;
  static const double _labelWidth = 220;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (section.title.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  section.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            if (leading != null) ...[
              const SizedBox(height: 8),
              leading!,
            ],
            for (int i = 0; i < section.answers.length; i++) ...[
              if (i > 0 || leading != null || section.title.isNotEmpty)
                Divider(height: 1, color: cs.outlineVariant.withOpacity(0.6)),
              AnswerRow(answer: section.answers[i]),
            ],
          ],
        ),
      ),
    );
  }
}

/// A single label/value row. Long free text gets a "Show more" toggle.
class AnswerRow extends StatelessWidget {
  final ReviewAnswer answer;

  const AnswerRow({super.key, required this.answer});

  bool get _isLong => answer.type == 'long_answer' || answer.type == 'textarea';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final label = Text(
      answer.label,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: cs.onSurfaceVariant,
        fontWeight: FontWeight.w500,
        height: 1.3,
      ),
    );

    final value = _ValueText(text: answer.displayValue, long: _isLong);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stack = constraints.maxWidth < SectionCard._stackBreakpoint;
          if (stack) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                label,
                const SizedBox(height: 6),
                value,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: SectionCard._labelWidth, child: label),
              const SizedBox(width: 16),
              Expanded(child: value),
            ],
          );
        },
      ),
    );
  }
}

class _ValueText extends StatefulWidget {
  final String text;
  final bool long;
  const _ValueText({required this.text, required this.long});

  @override
  State<_ValueText> createState() => _ValueTextState();
}

class _ValueTextState extends State<_ValueText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (!widget.long) {
      return Text(
        widget.text,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      );
    }

    // Long free text: gold left-rule block, collapsed to 4 lines with toggle.
    final isTruncatable = widget.text.length > 240;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(color: cs.primary, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 160),
            alignment: Alignment.topLeft,
            child: Text(
              widget.text,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
              maxLines: _expanded ? null : 4,
              overflow:
                  _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            ),
          ),
          if (isTruncatable) ...[
            const SizedBox(height: 4),
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                child: Text(
                  _expanded ? 'Show less' : 'Show more',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
