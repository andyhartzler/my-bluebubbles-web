import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/submission_review_model.dart';
import '../../theme/moyd_brand.dart';
import '../review/stance_visuals.dart';

/// Renders one answered question as content: a small muted label above the
/// value, with the value typed by what it is — long free text gets the gold
/// quote block, multi-selects become pills, yes/no-ish choices become stance
/// chips, money gets tabular currency, and emails/phones/urls copy on tap.
/// Everything else is a selectable titleMedium value.
///
/// Dispatch order: long > multi-select > stance chip > currency > copyable >
/// short. All pairings are AA in both themes (stance chips and neutral pills
/// are self-contained fg/bg pairs; plain text uses onSurface tokens).
class AnswerDisplay extends StatelessWidget {
  final ReviewAnswer answer;

  const AnswerDisplay({super.key, required this.answer});

  static const Set<String> _singleSelectTypes = {
    'radio',
    'dropdown',
    'choice_chips',
  };
  static const Set<String> _toggleTypes = {'checkbox', 'toggle'};
  static const Set<String> _copyableTypes = {'email', 'phone', 'url'};
  static const Set<String> _copyableIds = {'email', 'phone'};
  static const Set<String> _currencyIds = {
    'raised_to_date',
    'self_funded_amount',
  };

  static bool _isLong(ReviewAnswer a) =>
      a.type == 'long_answer' || a.type == 'textarea';

  static bool _isMulti(ReviewAnswer a) => a.rawValue is List;

  /// True when this answer renders compactly enough to flow two-up in a wide
  /// card (everything except the full-width long-text block and pill wraps).
  static bool flowsTwoUp(ReviewAnswer a) => !_isLong(a) && !_isMulti(a);

  static bool _isCurrency(ReviewAnswer a) {
    if (a.type == 'currency') return true;
    if (_currencyIds.contains(a.field.id)) return true;
    if (a.type == 'number') {
      final id = a.field.id;
      return id.contains('raised') ||
          id.contains('amount') ||
          id.contains('budget') ||
          id.contains('fund');
    }
    return false;
  }

  static bool _isCopyable(ReviewAnswer a) =>
      _copyableTypes.contains(a.type) || _copyableIds.contains(a.field.id);

  /// Stance for a yes/no-ish choice, or null when the answer isn't stancey.
  /// Checkbox/toggle booleans map true -> support, false -> oppose.
  static Stance? _stanceOf(ReviewAnswer a) {
    final raw = a.rawValue.toString();
    if (_singleSelectTypes.contains(a.type)) {
      final s = SubmissionReviewModel.stanceFor(raw);
      return s == Stance.neutral ? null : s;
    }
    if (_toggleTypes.contains(a.type)) {
      final s = SubmissionReviewModel.stanceFor(raw);
      if (s != Stance.neutral) return s;
      final v = raw.toLowerCase().trim();
      if (v == 'true') return Stance.support;
      if (v == 'false') return Stance.oppose;
    }
    return null;
  }

  /// Resolved option labels for a multi-select value (same lookup as
  /// [SubmissionReviewModel.resolveDisplay], kept per-item for pills).
  List<String> _multiLabels() {
    String optLabel(String v) {
      final opts = answer.field.options;
      if (opts != null) {
        for (final o in opts) {
          if (o.value == v) return o.label;
        }
      }
      return v;
    }

    return (answer.rawValue as List)
        .map((e) => optLabel(e.toString()))
        .where((s) => s.isNotEmpty)
        .toList();
  }

  void _copy(BuildContext context, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${answer.label} copied'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final label = Text(
      answer.label.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.7,
        color: cs.onSurfaceVariant,
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          label,
          const SizedBox(height: 5),
          _value(context, theme, cs),
        ],
      ),
    );
  }

  Widget _value(BuildContext context, ThemeData theme, ColorScheme cs) {
    if (_isLong(answer)) {
      return _LongAnswerText(text: answer.displayValue);
    }

    if (_isMulti(answer)) {
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final l in _multiLabels())
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: MoydBrand.neutralBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                l,
                style: const TextStyle(
                  color: MoydBrand.neutralFg,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      );
    }

    final stance = _stanceOf(answer);
    if (stance != null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: StanceVisuals.pill(stance, text: answer.displayValue),
      );
    }

    if (_isCurrency(answer)) {
      final raw = answer.rawValue;
      final n = raw is num ? raw : num.tryParse(raw.toString());
      if (n != null) {
        return Text(
          ReviewFormat.currency(n),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        );
      }
      // Unparseable number: fall through to the plain value below.
    }

    if (_isCopyable(answer)) {
      return Tooltip(
        message: 'Tap to copy',
        child: InkWell(
          onTap: () => _copy(context, answer.displayValue),
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    answer.displayValue,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.copy_rounded, size: 16, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      );
    }

    return SelectableText(
      answer.displayValue,
      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}

/// Long free text: gold left-rule quote block, collapsed to 5 lines with a
/// Show more / Show less toggle past 240 chars.
class _LongAnswerText extends StatefulWidget {
  final String text;
  const _LongAnswerText({required this.text});

  @override
  State<_LongAnswerText> createState() => _LongAnswerTextState();
}

class _LongAnswerTextState extends State<_LongAnswerText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final isTruncatable = widget.text.length > 240;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(10),
        border: const Border(
          left: BorderSide(color: MoydBrand.gold, width: 3),
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
              maxLines: _expanded ? null : 5,
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
