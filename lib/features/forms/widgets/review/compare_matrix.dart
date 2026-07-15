import 'package:flutter/material.dart';

import '../../models/form_schema.dart';
import '../../models/form_submission.dart';
import '../../models/submission_review_model.dart';
import '../../theme/moyd_brand.dart';
import 'stance_visuals.dart';

/// A candidate x policy-question comparison matrix for the endorsement form.
///
/// Rows are candidates, columns are the "Where you stand" policy questions
/// (derived from every submitted review via [SubmissionReviewModel], in schema
/// order). Each cell is a stance glyph in the MOYD stance palette. Tap a cell
/// for the resolved answer + paired explanation, tap a column header to sort
/// candidates by their stance on that question, and filter by candidate name.
///
/// The left candidate-name column is sticky (stays put during horizontal
/// scroll); the header + body scroll together horizontally, and everything
/// scrolls together vertically.
class CompareMatrix extends StatefulWidget {
  final FormSchema form;
  final List<FormSubmission> submissions;

  /// Optional: when supplied, tapping a candidate name or alignment cell opens
  /// the candidate (e.g. push the deep-dive) instead of the built-in stance
  /// popover. Leaving it null preserves the default popover behavior.
  final void Function(FormSubmission submission)? onOpenCandidate;

  const CompareMatrix({
    Key? key,
    required this.form,
    required this.submissions,
    this.onOpenCandidate,
  }) : super(key: key);

  @override
  State<CompareMatrix> createState() => _CompareMatrixState();
}

class _CandidateRow {
  final FormSubmission submission;
  final SubmissionReviewModel model;
  final Map<String, PolicyPosition> byId;

  _CandidateRow(this.submission, this.model)
      : byId = {for (final p in model.allPolicyPositions) p.id: p};
}

class _Column {
  final String id;
  final String label;
  const _Column(this.id, this.label);
}

class _CompareMatrixState extends State<CompareMatrix> {
  static const double _nameColWidth = 184;
  static const double _colWidth = 128;
  static const double _alignColWidth = 116;
  static const double _rowHeight = 54;
  static const double _headerHeight = 104;

  /// Navy -> royal -> deep-sky header sweep. Every stop keeps white text at
  /// >= 4.5:1 (same verified ramp as the Endorsement HQ hero).
  static const LinearGradient _headerGradient = LinearGradient(
    colors: [Color(0xFF263351), Color(0xFF2B4B8C), Color(0xFF1D6FA8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Sentinel column id for the alignment-score column.
  static const String _alignmentColId = '__alignment__';

  late List<_CandidateRow> _rows;
  late List<_Column> _columns;

  String? _sortColId; // null → sort by candidate name
  bool _sortDesc = true; // supporters first by default
  String _nameFilter = '';

  @override
  void initState() {
    super.initState();
    _build();
    // Rank the slate by alignment out of the gate when the form is scored.
    if (_rows.any((r) => r.model.alignmentPct != null)) {
      _sortColId = _alignmentColId;
      _sortDesc = true;
    }
  }

  @override
  void didUpdateWidget(CompareMatrix oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.submissions != widget.submissions ||
        oldWidget.form != widget.form) {
      _build();
    }
  }

  void _build() {
    _rows = widget.submissions
        .map((s) => _CandidateRow(s, SubmissionReviewModel.from(widget.form, s)))
        .toList();

    // Columns: union of all policy-position ids across candidates, ordered by
    // the field's index in the form schema.
    final order = <String, int>{};
    for (var i = 0; i < widget.form.schema.fields.length; i++) {
      order[widget.form.schema.fields[i].id] = i;
    }
    final labels = <String, String>{};
    for (final r in _rows) {
      for (final p in r.model.allPolicyPositions) {
        labels.putIfAbsent(p.id, () => p.question);
      }
    }
    final ids = labels.keys.toList()
      ..sort((a, b) => (order[a] ?? 1 << 30).compareTo(order[b] ?? 1 << 30));
    _columns = [
      // Alignment leads the columns when the form carries a scoring config.
      if (_rows.any((r) => r.model.alignmentPct != null))
        const _Column(_alignmentColId, 'Alignment'),
      ...ids.map((id) => _Column(id, labels[id]!)),
    ];
  }

  // Support-first ranking for sorting; missing answers sink to the bottom.
  int _rank(Stance? s) {
    switch (s) {
      case Stance.support:
        return 5;
      case Stance.qualified:
        return 4;
      case Stance.neutral:
        return 3;
      case Stance.unsure:
        return 2;
      case Stance.oppose:
        return 1;
      case null:
        return 0;
    }
  }

  List<_CandidateRow> get _visibleRows {
    var rows = _rows;
    if (_nameFilter.trim().isNotEmpty) {
      final q = _nameFilter.toLowerCase();
      rows = rows
          .where((r) =>
              r.model.candidateName.toLowerCase().contains(q) ||
              (r.model.office?.toLowerCase().contains(q) ?? false) ||
              (r.model.district?.toLowerCase().contains(q) ?? false))
          .toList();
    }
    final sorted = [...rows];
    if (_sortColId == null) {
      sorted.sort((a, b) =>
          a.model.candidateName.toLowerCase().compareTo(
              b.model.candidateName.toLowerCase()));
      if (_sortDesc) {
        return sorted.reversed.toList();
      }
      return sorted;
    }
    if (_sortColId == _alignmentColId) {
      // Unscored candidates (null pct) sink to the bottom regardless of order.
      sorted.sort((a, b) {
        final pa = a.model.alignmentPct ?? -1;
        final pb = b.model.alignmentPct ?? -1;
        final cmp = pa.compareTo(pb);
        if (cmp != 0) return _sortDesc ? -cmp : cmp;
        return a.model.candidateName
            .toLowerCase()
            .compareTo(b.model.candidateName.toLowerCase());
      });
      return sorted;
    }
    sorted.sort((a, b) {
      final ra = _rank(a.byId[_sortColId]?.stance);
      final rb = _rank(b.byId[_sortColId]?.stance);
      final cmp = ra.compareTo(rb);
      if (cmp != 0) return _sortDesc ? -cmp : cmp;
      return a.model.candidateName
          .toLowerCase()
          .compareTo(b.model.candidateName.toLowerCase());
    });
    return sorted;
  }

  void _toggleSort(String? colId) {
    setState(() {
      if (_sortColId == colId) {
        _sortDesc = !_sortDesc;
      } else {
        _sortColId = colId;
        _sortDesc = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_columns.isEmpty || _rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'No policy positions to compare yet.',
            style: theme.textTheme.bodyLarge
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    final rows = _visibleRows;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildToolbar(theme, colorScheme, rows.length),
        const SizedBox(height: 8),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sticky candidate-name column (header corner + name cells).
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCornerCell(theme, colorScheme),
                    for (var i = 0; i < rows.length; i++)
                      _buildNameCell(theme, colorScheme, rows[i], i),
                  ],
                ),
                // Scrollable header + body.
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            for (final c in _columns)
                              _buildColumnHeader(theme, colorScheme, c),
                          ],
                        ),
                        for (var i = 0; i < rows.length; i++)
                          Row(
                            children: [
                              for (final c in _columns)
                                _buildCell(
                                    theme, colorScheme, rows[i], c, i),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar(
      ThemeData theme, ColorScheme colorScheme, int shownCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 44,
                child: TextField(
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Filter candidates…',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colorScheme.outlineVariant),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colorScheme.outlineVariant),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onChanged: (v) => setState(() => _nameFilter = v),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$shownCount candidate${shownCount == 1 ? '' : 's'}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Legend.
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            _legendItem(Stance.support, 'Support'),
            _legendItem(Stance.qualified, 'Qualified'),
            _legendItem(Stance.oppose, 'Oppose'),
            _legendItem(Stance.neutral, 'No answer'),
          ],
        ),
      ],
    );
  }

  Widget _legendItem(Stance s, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: StanceVisuals.bg(s),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(StanceVisuals.glyph(s), size: 15, color: StanceVisuals.fg(s)),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildCornerCell(ThemeData theme, ColorScheme colorScheme) {
    final active = _sortColId == null;
    return InkWell(
      onTap: () => _toggleSort(null),
      child: Container(
        width: _nameColWidth,
        height: _headerHeight,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: _headerGradient,
          border: Border(
            right: BorderSide(color: colorScheme.outlineVariant),
            bottom: BorderSide(color: colorScheme.outlineVariant),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Row(
              children: [
                const Flexible(
                  child: Text(
                    'Candidate',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (active)
                  Icon(
                    _sortDesc ? Icons.arrow_downward : Icons.arrow_upward,
                    size: 14,
                    color: MoydBrand.gold,
                  ),
              ],
            ),
            const SizedBox(height: 2),
            const Text(
              'Tap headers to sort',
              style: TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNameCell(
      ThemeData theme, ColorScheme colorScheme, _CandidateRow row, int index) {
    final zebra = index.isOdd;
    final office = row.model.office;
    final district = row.model.district;
    final sub = [office, district].where((e) => e != null && e.isNotEmpty).join(' · ');
    return InkWell(
      onTap: () => _openCandidate(row),
      child: Container(
        width: _nameColWidth,
        height: _rowHeight,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: zebra
              ? colorScheme.surfaceContainerHighest.withOpacity(0.25)
              : colorScheme.surface,
          border: Border(
            right: BorderSide(color: colorScheme.outlineVariant),
            bottom: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.6)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              row.model.candidateName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (sub.isNotEmpty)
              Text(
                sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildColumnHeader(
      ThemeData theme, ColorScheme colorScheme, _Column c) {
    final active = _sortColId == c.id;
    final isAlignment = c.id == _alignmentColId;
    return InkWell(
      onTap: () => _toggleSort(c.id),
      child: Container(
        width: isAlignment ? _alignColWidth : _colWidth,
        height: _headerHeight,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF2B4B8C) : MoydBrand.navy,
          border: Border(
            right: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.4)),
            bottom: active
                ? const BorderSide(color: MoydBrand.gold, width: 3)
                : BorderSide(color: colorScheme.outlineVariant),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (active)
              Align(
                alignment: Alignment.centerRight,
                child: Icon(
                  _sortDesc ? Icons.arrow_downward : Icons.arrow_upward,
                  size: 13,
                  color: MoydBrand.gold,
                ),
              ),
            Expanded(
              child: Tooltip(
                message: isAlignment
                    ? 'Alignment — draft committee weights, tunable'
                    : c.label,
                child: Text(
                  _shortLabel(c.label),
                  maxLines: active ? 4 : 5,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCell(ThemeData theme, ColorScheme colorScheme,
      _CandidateRow row, _Column c, int index) {
    if (c.id == _alignmentColId) {
      return _buildAlignmentCell(theme, colorScheme, row, index);
    }
    final pos = row.byId[c.id];
    final stance = pos?.stance ?? Stance.neutral;
    final zebra = index.isOdd;
    final hasExplain = pos?.explanation != null && pos!.explanation!.isNotEmpty;

    return InkWell(
      onTap: pos == null ? null : () => _openCell(row, c, pos),
      child: Container(
        width: _colWidth,
        height: _rowHeight,
        decoration: BoxDecoration(
          color: zebra
              ? colorScheme.surfaceContainerHighest.withOpacity(0.25)
              : colorScheme.surface,
          border: Border(
            right: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.4)),
            bottom: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.6)),
          ),
        ),
        child: Center(
          child: pos == null
              ? Icon(Icons.horizontal_rule_rounded,
                  size: 16, color: colorScheme.outline)
              : Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: StanceVisuals.bg(stance),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        StanceVisuals.glyph(stance),
                        size: 19,
                        color: StanceVisuals.fg(stance),
                      ),
                    ),
                    if (hasExplain)
                      Positioned(
                        right: -3,
                        top: -3,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: MoydBrand.gold,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildAlignmentCell(ThemeData theme, ColorScheme colorScheme,
      _CandidateRow row, int index) {
    final pct = row.model.alignmentPct;
    final zebra = index.isOdd;
    return InkWell(
      onTap: () => _openCandidate(row),
      child: Container(
        width: _alignColWidth,
        height: _rowHeight,
        decoration: BoxDecoration(
          color: zebra
              ? colorScheme.surfaceContainerHighest.withOpacity(0.25)
              : colorScheme.surface,
          border: Border(
            right: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.4)),
            bottom: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.6)),
          ),
        ),
        child: Center(
          child: pct == null
              ? Icon(Icons.horizontal_rule_rounded,
                  size: 16, color: colorScheme.outline)
              : AlignmentBadge(pct: pct, dense: true),
        ),
      ),
    );
  }

  void _openCell(_CandidateRow row, _Column c, PolicyPosition pos) {
    showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final colorScheme = theme.colorScheme;
        return AlertDialog(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(row.model.candidateName,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(pos.question,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: colorScheme.onSurfaceVariant)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StanceVisuals.pill(pos.stance, text: pos.answerLabel),
              if (pos.explanation != null && pos.explanation!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Explanation',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    )),
                const SizedBox(height: 4),
                Text(pos.explanation!, style: theme.textTheme.bodyMedium),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _openCandidate(_CandidateRow row) {
    // Delegate to the host when a callback is provided (e.g. deep-dive push).
    final cb = widget.onOpenCandidate;
    if (cb != null) {
      cb(row.submission);
      return;
    }
    // Small stance-summary popover for the whole candidate.
    final tally = row.model.stanceTally;
    showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final colorScheme = theme.colorScheme;
        return AlertDialog(
          title: Text(row.model.candidateName,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (row.model.office != null || row.model.district != null)
                Text(
                  [row.model.office, row.model.district]
                      .where((e) => e != null && e.isNotEmpty)
                      .join(' · '),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              if (row.model.alignmentPct != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    AlignmentBadge(pct: row.model.alignmentPct!, showWord: true),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        row.model.alignment!.breakdownLine,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Draft committee weights, tunable.',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  StanceVisuals.pill(Stance.support,
                      text: '${tally.support} support'),
                  StanceVisuals.pill(Stance.qualified,
                      text: '${tally.qualified} qualified'),
                  StanceVisuals.pill(Stance.oppose,
                      text: '${tally.oppose} oppose'),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  /// Trim boilerplate lead-ins so a long policy question reads in a narrow
  /// column header. Generic, not tied to any one field id.
  static String _shortLabel(String label) {
    var s = label.trim();
    const leads = [
      'Do you support ',
      'Where do you stand on ',
      'Which statement best describes your approach to ',
      'If you were offered ',
      'If “right to work” ',
    ];
    for (final l in leads) {
      if (s.toLowerCase().startsWith(l.toLowerCase())) {
        s = s.substring(l.length);
        if (s.isNotEmpty) s = s[0].toUpperCase() + s.substring(1);
        break;
      }
    }
    return s;
  }
}
