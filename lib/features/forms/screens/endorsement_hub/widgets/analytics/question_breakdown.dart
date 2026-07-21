import 'package:flutter/material.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';

import '../../../../models/form_field_config.dart';
import '../../../../models/form_schema.dart';
import '../../../../models/submission_review_model.dart';
import '../../../../theme/moyd_brand.dart';
import '../../../../widgets/review/stance_visuals.dart';
import '../../models/candidate_entry.dart';
import '../../theme/hub_theme.dart';
import '../headshot_avatar.dart';

/// Question-by-question response analytics, INCLUDING the "no answer" count
/// per question (who skipped it and how many), which the committee asked for
/// explicitly.
///
/// For every answerable field in the endorsement form this computes, across
/// the submitted candidates:
///   - eligible:  candidates the question was actually shown to (conditional
///     fields only count candidates whose answers satisfy the condition, so a
///     skipped follow-up is never blamed on someone who was never asked);
///   - answered:  eligible candidates with a non-empty value;
///   - no answer: eligible minus answered.
///
/// Each question row is expandable; every option row (and the "No answer"
/// row) drills into the actual candidates behind the number, tappable
/// through to the full review.
class QuestionBreakdown extends StatefulWidget {
  final FormSchema form;
  final List<CandidateEntry> entries;
  final void Function(CandidateEntry) onOpen;

  const QuestionBreakdown({
    super.key,
    required this.form,
    required this.entries,
    required this.onOpen,
  });

  @override
  State<QuestionBreakdown> createState() => _QuestionBreakdownState();
}

enum _SortMode { formOrder, mostSkipped }

class _QuestionBreakdownState extends State<QuestionBreakdown> {
  static const int _collapsedCount = 12;

  _SortMode _sort = _SortMode.formOrder;
  bool _skippedOnly = false;
  bool _showAll = false;
  final Set<String> _expanded = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    if (widget.entries.isEmpty) return const SizedBox.shrink();

    final stats = _QuestionStat.buildAll(widget.form, widget.entries);
    if (stats.isEmpty) return const SizedBox.shrink();

    final totalQ = stats.length;
    final withSkips = stats.where((s) => s.skipped.isNotEmpty).length;
    final avgRate = stats.isEmpty
        ? 0
        : (stats.map((s) => s.answerRate).reduce((a, b) => a + b) /
                stats.length *
                100)
            .round();

    var visible = _skippedOnly
        ? stats.where((s) => s.skipped.isNotEmpty).toList()
        : List.of(stats);
    if (_sort == _SortMode.mostSkipped) {
      visible.sort((a, b) {
        final cmp = b.skipped.length.compareTo(a.skipped.length);
        return cmp != 0 ? cmp : a.order.compareTo(b.order);
      });
    }
    final truncated = !_showAll && visible.length > _collapsedCount;
    final shown = truncated ? visible.sublist(0, _collapsedCount) : visible;

    return HubCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Branded gradient banner (every stop of the hero sweep carries
          // white at >= 4.5:1 in both themes).
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              gradient: HubTheme.hero,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(Icons.fact_check_outlined,
                      color: HubTheme.gold, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Question-by-question',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text(
                        '$totalQ questions · $avgRate% average answer rate · '
                        '$withSkips with no-answers',
                        style: const TextStyle(
                            color: Color(0xE6FFFFFF), fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              'Tap a question to expand it; tap any answer (or "No answer") '
              'to see exactly which candidates are behind the number.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SegmentedButton<_SortMode>(
                style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                segments: const [
                  ButtonSegment(
                      value: _SortMode.formOrder, label: Text('Form order')),
                  ButtonSegment(
                      value: _SortMode.mostSkipped,
                      label: Text('Most skipped')),
                ],
                selected: {_sort},
                onSelectionChanged: (s) => setState(() => _sort = s.first),
              ),
              FilterChip(
                label: const Text('Only questions with no answers'),
                selected: _skippedOnly,
                onSelected: (v) => setState(() => _skippedOnly = v),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'Every candidate answered every question they were asked. '
                  'A clean sweep.',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            )
          else
            ..._rows(context, shown),
          if (truncated)
            Center(
              child: TextButton.icon(
                onPressed: () => setState(() => _showAll = true),
                icon: const Icon(Icons.expand_more),
                label: Text('Show all ${visible.length} questions'),
              ),
            )
          else if (_showAll && visible.length > _collapsedCount)
            Center(
              child: TextButton.icon(
                onPressed: () => setState(() => _showAll = false),
                icon: const Icon(Icons.expand_less),
                label: const Text('Collapse the list'),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _rows(BuildContext context, List<_QuestionStat> shown) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final out = <Widget>[];
    String? section;
    for (final stat in shown) {
      if (_sort == _SortMode.formOrder &&
          stat.section.isNotEmpty &&
          stat.section != section) {
        section = stat.section;
        out.add(Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 2, left: 2),
          child: Text(section.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6)),
        ));
      }
      out.add(_QuestionRow(
        stat: stat,
        total: widget.entries.length,
        expanded: _expanded.contains(stat.field.id),
        onToggle: () => setState(() {
          if (!_expanded.remove(stat.field.id)) _expanded.add(stat.field.id);
        }),
        onDrill: (title, subtitle, rows) =>
            _openCandidateSheet(context, title, subtitle, rows),
      ));
      out.add(Divider(height: 1, color: cs.outlineVariant.withOpacity(0.6)));
    }
    if (out.isNotEmpty) out.removeLast();
    return out;
  }

  void _openCandidateSheet(
    BuildContext context,
    String title,
    String subtitle,
    List<({CandidateEntry entry, String? snippet})> rows,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final cs = theme.colorScheme;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.72),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                Divider(height: 1, color: cs.outlineVariant),
                Flexible(
                  child: rows.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(28),
                          child: Center(
                            child: Text('Nobody here.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                    color: cs.onSurfaceVariant)),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          itemCount: rows.length,
                          separatorBuilder: (_, __) => Divider(
                              height: 1,
                              indent: 68,
                              color: cs.outlineVariant.withOpacity(0.5)),
                          itemBuilder: (context, i) {
                            final r = rows[i];
                            final e = r.entry;
                            return ListTile(
                              leading: HeadshotAvatar(
                                  file: e.headshot,
                                  name: e.name,
                                  size: 40),
                              title: Text(e.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              subtitle: Text(
                                r.snippet?.isNotEmpty == true
                                    ? r.snippet!
                                    : (e.officeLine.isEmpty
                                        ? '—'
                                        : e.officeLine),
                                maxLines: r.snippet == null ? 1 : 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (e.alignmentPct != null)
                                    AlignmentBadge(
                                        pct: e.alignmentPct!, dense: true),
                                  const SizedBox(width: 4),
                                  Icon(Icons.chevron_right,
                                      size: 18, color: cs.onSurfaceVariant),
                                ],
                              ),
                              onTap: () {
                                Navigator.pop(ctx);
                                widget.onOpen(e);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ==================== one question row ====================

class _QuestionRow extends StatelessWidget {
  final _QuestionStat stat;
  final int total;
  final bool expanded;
  final VoidCallback onToggle;
  final void Function(
    String title,
    String subtitle,
    List<({CandidateEntry entry, String? snippet})> rows,
  ) onDrill;

  const _QuestionRow({
    required this.stat,
    required this.total,
    required this.expanded,
    required this.onToggle,
    required this.onDrill,
  });

  /// Vibrant categorical fills (labels always print beside the bar, never on
  /// it, so the fill color never carries text contrast).
  static const List<Color> _palette = [
    Color(0xFF6366F1), // Indigo
    Color(0xFF8B5CF6), // Violet
    Color(0xFFEC4899), // Pink
    Color(0xFFF59E0B), // Amber
    Color(0xFF10B981), // Emerald
    Color(0xFF3B82F6), // Blue
    Color(0xFFEF4444), // Red
    Color(0xFF14B8A6), // Teal
    Color(0xFFF97316), // Orange
    Color(0xFF84CC16), // Lime
  ];

  Color _noAnswerColor(ColorScheme cs) =>
      cs.onSurfaceVariant.withOpacity(0.35);

  /// Stance-mapped color for single-select policy answers (support green,
  /// oppose red, qualified amber); categorical palette otherwise.
  Color _optionColor(String value, int index) {
    if (stat.isSingleSelect) {
      final s = SubmissionReviewModel.stanceFor(value);
      if (s != Stance.neutral) return StanceVisuals.fg(s);
    }
    return _palette[index % _palette.length];
  }

  String _optionLabel(String value) {
    final opts = stat.field.options;
    if (opts != null) {
      for (final o in opts) {
        if (o.value == value) return o.label;
      }
    }
    return value;
  }

  /// Option values in form-defined order, then any stray stored values.
  List<String> _orderedValues() {
    final seen = <String>{};
    final out = <String>[];
    final opts = stat.field.options;
    if (opts != null) {
      for (final o in opts) {
        if (stat.optionCounts.containsKey(o.value) && seen.add(o.value)) {
          out.add(o.value);
        }
      }
    }
    for (final v in stat.optionCounts.keys) {
      if (seen.add(v)) out.add(v);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final skipped = stat.skipped.length;
    final answered = stat.answered.length;
    final eligible = stat.eligible.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(stat.field.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 10),
                    _skipPill(skipped),
                    const SizedBox(width: 4),
                    Icon(expanded ? Icons.expand_less : Icons.expand_more,
                        size: 18, color: cs.onSurfaceVariant),
                  ],
                ),
                const SizedBox(height: 8),
                _stackedBar(cs),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Text('$answered of $eligible answered',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: cs.onSurfaceVariant)),
                    const Spacer(),
                    if (eligible < total)
                      Text('asked of $eligible/$total (conditional)',
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.only(left: 2, right: 2, bottom: 12),
            child: _expandedRows(context),
          ),
      ],
    );
  }

  Widget _skipPill(int skipped) {
    if (skipped == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: MoydBrand.supportBg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_rounded, size: 13, color: MoydBrand.supportFg),
            SizedBox(width: 3),
            Text('All answered',
                style: TextStyle(
                    color: MoydBrand.supportFg,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: MoydBrand.qualifiedBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('$skipped no answer',
          style: const TextStyle(
              color: MoydBrand.qualifiedFg,
              fontSize: 11,
              fontWeight: FontWeight.w700)),
    );
  }

  Widget _stackedBar(ColorScheme cs) {
    final eligible = stat.eligible.length;
    final skipped = stat.skipped.length;
    final segments = <(int, Color)>[];
    if (eligible == 0) {
      segments.add((1, _noAnswerColor(cs)));
    } else if (stat.isSingleSelect) {
      final values = _orderedValues();
      for (var i = 0; i < values.length; i++) {
        final c = stat.optionCounts[values[i]] ?? 0;
        if (c > 0) segments.add((c, _optionColor(values[i], i)));
      }
      if (skipped > 0) segments.add((skipped, _noAnswerColor(cs)));
    } else {
      // Multi-select and free-text: answered vs no answer.
      if (stat.answered.isNotEmpty) {
        segments.add((stat.answered.length, BrandColors.momentumBlue));
      }
      if (skipped > 0) segments.add((skipped, _noAnswerColor(cs)));
    }
    if (segments.isEmpty) segments.add((1, _noAnswerColor(cs)));

    return SizedBox(
      height: 10,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Row(
          children: [
            for (var i = 0; i < segments.length; i++)
              Expanded(
                flex: segments[i].$1,
                child: Container(
                  margin: EdgeInsets.only(
                      right: i == segments.length - 1 ? 0 : 1),
                  color: segments[i].$2,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _expandedRows(BuildContext context) {
    final eligible = stat.eligible.length;
    final rows = <Widget>[];

    if (stat.isChoice) {
      final values = _orderedValues();
      for (var i = 0; i < values.length; i++) {
        final v = values[i];
        final count = stat.optionCounts[v] ?? 0;
        rows.add(_OptionLine(
          color: _optionColor(v, i),
          label: _optionLabel(v),
          count: count,
          denominator: eligible,
          onTap: () => onDrill(
            _optionLabel(v),
            '${stat.field.label} · $count of $eligible candidates',
            stat.candidatesFor(v),
          ),
        ));
      }
    } else {
      rows.add(_OptionLine(
        color: BrandColors.momentumBlue,
        label: 'Answered',
        count: stat.answered.length,
        denominator: eligible,
        onTap: () => onDrill(
          'Answered',
          '${stat.field.label} · ${stat.answered.length} of $eligible candidates',
          stat.answeredWithSnippets(),
        ),
      ));
    }

    // The marquee row: who left it blank.
    rows.add(_OptionLine(
      color: _noAnswerColor(Theme.of(context).colorScheme),
      label: 'No answer',
      count: stat.skipped.length,
      denominator: eligible,
      emphasized: stat.skipped.isNotEmpty,
      onTap: () => onDrill(
        'No answer',
        '${stat.field.label} · ${stat.skipped.length} of $eligible left this blank',
        [for (final e in stat.skipped) (entry: e, snippet: null)],
      ),
    ));

    return Column(children: rows);
  }
}

/// One drillable line inside an expanded question: color key, label,
/// count + share, mini bar, chevron. Text always renders in theme colors on
/// the theme surface; the color is only ever a fill.
class _OptionLine extends StatelessWidget {
  final Color color;
  final String label;
  final int count;
  final int denominator;
  final bool emphasized;
  final VoidCallback onTap;

  const _OptionLine({
    required this.color,
    required this.label,
    required this.count,
    required this.denominator,
    required this.onTap,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final pct = denominator == 0 ? 0.0 : count / denominator;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight:
                              emphasized ? FontWeight.w700 : FontWeight.w500)),
                ),
                const SizedBox(width: 8),
                Text('$count · ${(pct * 100).round()}%',
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w700)),
                const SizedBox(width: 2),
                Icon(Icons.chevron_right, size: 15, color: cs.onSurfaceVariant),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 6,
                backgroundColor: color.withOpacity(0.14),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== stats model ====================

class _QuestionStat {
  final FormFieldConfig field;
  final int order;
  final String section;
  final List<CandidateEntry> eligible;
  final List<({CandidateEntry entry, dynamic value})> answered;
  final List<CandidateEntry> skipped;
  final Map<String, int> optionCounts;

  const _QuestionStat({
    required this.field,
    required this.order,
    required this.section,
    required this.eligible,
    required this.answered,
    required this.skipped,
    required this.optionCounts,
  });

  static const Set<String> _displayOnly = {'section_header', 'reference_block'};
  static const Set<String> _singleSelectTypes = {
    'radio',
    'dropdown',
    'choice_chips',
  };

  double get answerRate =>
      eligible.isEmpty ? 1 : answered.length / eligible.length;

  bool get isSingleSelect =>
      _singleSelectTypes.contains(field.type) &&
      (field.options?.isNotEmpty ?? false);

  /// Any field with defined options (single or multi select) gets a
  /// per-option distribution; everything else gets answered vs no answer.
  bool get isChoice => (field.options?.isNotEmpty ?? false);

  /// Candidates who picked [value] (member-of for multi-select answers).
  List<({CandidateEntry entry, String? snippet})> candidatesFor(String value) {
    final out = <({CandidateEntry entry, String? snippet})>[];
    for (final a in answered) {
      final v = a.value;
      final match = v is List
          ? v.map((e) => e.toString()).contains(value)
          : v.toString() == value;
      if (match) out.add((entry: a.entry, snippet: null));
    }
    return out;
  }

  /// Answered candidates with their resolved display value as a snippet
  /// (used for free-text drill-downs).
  List<({CandidateEntry entry, String? snippet})> answeredWithSnippets() {
    return [
      for (final a in answered)
        (
          entry: a.entry,
          snippet: SubmissionReviewModel.resolveDisplay(field, a.value),
        ),
    ];
  }

  static bool _isEmptyValue(dynamic v) {
    if (v == null) return true;
    if (v is String) return v.trim().isEmpty;
    if (v is Iterable) return v.isEmpty;
    if (v is Map) return v.isEmpty;
    return false;
  }

  static List<_QuestionStat> buildAll(
      FormSchema form, List<CandidateEntry> entries) {
    final out = <_QuestionStat>[];
    var section = '';
    var order = 0;
    for (final f in form.schema.fields) {
      if (f.type == 'section_header') {
        section = f.label;
        continue;
      }
      if (_displayOnly.contains(f.type)) continue;

      final eligible = <CandidateEntry>[];
      final answered = <({CandidateEntry entry, dynamic value})>[];
      final skipped = <CandidateEntry>[];
      final counts = <String, int>{};

      for (final e in entries) {
        final data = e.submission.data;
        if (!f.isVisibleFor(data)) continue;
        eligible.add(e);
        final v = data[f.id];
        if (_isEmptyValue(v)) {
          skipped.add(e);
          continue;
        }
        answered.add((entry: e, value: v));
        if (v is List) {
          for (final x in v) {
            final k = x.toString();
            counts[k] = (counts[k] ?? 0) + 1;
          }
        } else {
          final k = v.toString();
          counts[k] = (counts[k] ?? 0) + 1;
        }
      }

      out.add(_QuestionStat(
        field: f,
        order: order++,
        section: section,
        eligible: eligible,
        answered: answered,
        skipped: skipped,
        optionCounts: counts,
      ));
    }
    return out;
  }
}
