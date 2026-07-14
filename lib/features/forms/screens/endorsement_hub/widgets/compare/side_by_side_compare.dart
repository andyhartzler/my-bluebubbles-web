import 'package:flutter/material.dart';

import '../../../../models/submission_review_model.dart';
import '../../../../theme/moyd_brand.dart';
import '../../../../widgets/review/stance_visuals.dart';
import '../../models/candidate_entry.dart';
import '../headshot_avatar.dart';

/// Side-by-side comparison of 2–6 selected candidates. A sticky left label
/// column names each row; the candidate columns scroll horizontally together.
/// Rows are grouped by section (Vitals, then each policy section). Unanimous
/// policy rows get a faint support wash; split rows get a gold rule + "Split"
/// chip. Header chips filter to unanimous / split, and "Divergence first"
/// reorders policy rows by how contested they are.
class SideBySideCompare extends StatefulWidget {
  final List<CandidateEntry> entries;
  final void Function(CandidateEntry) onOpen;

  const SideBySideCompare({
    super.key,
    required this.entries,
    required this.onOpen,
  });

  @override
  State<SideBySideCompare> createState() => _SideBySideCompareState();
}

enum _RowFilter { all, unanimous, split }

class _PolicyRow {
  final String id;
  final String question;
  final String sectionTitle;
  final List<PolicyPosition?> perCandidate;
  const _PolicyRow(this.id, this.question, this.sectionTitle, this.perCandidate);

  List<Stance> get answered =>
      perCandidate.whereType<PolicyPosition>().map((p) => p.stance).toList();

  Set<Stance> get distinctDecisive => answered
      .where((s) =>
          s == Stance.support || s == Stance.qualified || s == Stance.oppose)
      .toSet();

  bool get unanimous =>
      perCandidate.every((p) => p != null) &&
      distinctDecisive.length == 1 &&
      answered.every((s) =>
          s == Stance.support || s == Stance.qualified || s == Stance.oppose);

  bool get split => distinctDecisive.length > 1;
}

class _SideBySideCompareState extends State<SideBySideCompare> {
  static const double _labelW = 190;
  static const double _colW = 150;

  final ScrollController _hCtrl = ScrollController();
  bool _showExplanations = false;
  bool _divergenceFirst = false;
  _RowFilter _filter = _RowFilter.all;

  @override
  void dispose() {
    _hCtrl.dispose();
    super.dispose();
  }

  List<_PolicyRow> _buildPolicyRows() {
    final entries = widget.entries;
    // Union of policy ids, preserving each candidate's schema order.
    final order = <String>[];
    final seen = <String>{};
    final labels = <String, String>{};
    final sections = <String, String>{};
    for (final e in entries) {
      for (final section in e.model.sections) {
        for (final p in section.policyPositions) {
          if (seen.add(p.id)) {
            order.add(p.id);
            labels[p.id] = p.question;
            sections[p.id] = section.title;
          }
        }
      }
    }
    final rows = <_PolicyRow>[];
    for (final id in order) {
      final per = <PolicyPosition?>[];
      for (final e in entries) {
        PolicyPosition? found;
        for (final p in e.model.allPolicyPositions) {
          if (p.id == id) {
            found = p;
            break;
          }
        }
        per.add(found);
      }
      rows.add(_PolicyRow(id, labels[id]!, sections[id] ?? '', per));
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final entries = widget.entries;

    if (entries.length < 2) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.compare_arrows,
                  size: 48, color: cs.onSurfaceVariant.withOpacity(0.6)),
              const SizedBox(height: 12),
              Text('Pick candidates to compare',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                'Add two or more candidates from the Roster (hover a card, tap '
                'Compare) to line up their vitals and stances here.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    var policyRows = _buildPolicyRows();
    final unanimousCount = policyRows.where((r) => r.unanimous).length;
    final splitCount = policyRows.where((r) => r.split).length;

    if (_filter == _RowFilter.unanimous) {
      policyRows = policyRows.where((r) => r.unanimous).toList();
    } else if (_filter == _RowFilter.split) {
      policyRows = policyRows.where((r) => r.split).toList();
    }
    if (_divergenceFirst) {
      policyRows.sort((a, b) =>
          b.distinctDecisive.length.compareTo(a.distinctDecisive.length));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _controls(theme, unanimousCount, splitCount),
        const SizedBox(height: 8),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sticky label column
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _labelCell(theme, '', header: true, height: 118),
                    ..._vitalLabels()
                        .map((l) => _labelCell(theme, l, height: 44)),
                    ..._sectionedPolicyLabels(theme, policyRows),
                  ],
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _hCtrl,
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var ci = 0; ci < entries.length; ci++)
                          _candidateColumn(theme, entries[ci], ci, policyRows),
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

  Widget _controls(ThemeData theme, int unanimous, int split) {
    final cs = theme.colorScheme;
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _filterChip('${widget.entries.length} candidates', _RowFilter.all,
            MoydBrand.navy),
        _filterChip('$unanimous unanimous', _RowFilter.unanimous,
            MoydBrand.supportFg),
        _filterChip('$split split', _RowFilter.split, MoydBrand.opposeFg),
        const SizedBox(width: 4),
        FilterChip(
          label: const Text('Divergence first'),
          selected: _divergenceFirst,
          onSelected: (v) => setState(() => _divergenceFirst = v),
          showCheckmark: false,
          avatar: Icon(Icons.swap_vert,
              size: 15,
              color: _divergenceFirst ? Colors.white : cs.onSurfaceVariant),
          selectedColor: MoydBrand.navySoft,
          labelStyle: TextStyle(
            color: _divergenceFirst ? Colors.white : cs.onSurface,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          backgroundColor: cs.surface,
          side: BorderSide(color: cs.outlineVariant),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: _showExplanations,
              onChanged: (v) => setState(() => _showExplanations = v),
            ),
            Text('Show explanations',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ),
      ],
    );
  }

  Widget _filterChip(String label, _RowFilter f, Color color) {
    final selected = _filter == f;
    return FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => setState(() => _filter = selected ? _RowFilter.all : f),
      selectedColor: color,
      labelStyle: TextStyle(
        color: selected ? Colors.white : color,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      side: BorderSide(color: color.withOpacity(0.5)),
    );
  }

  List<String> _vitalLabels() => const [
        'Office',
        'District',
        'Alignment',
        'Support / Qual / Oppose',
        'Young Dem',
        'Raised',
        'Self-funded %',
      ];

  Widget _labelCell(ThemeData theme, String text,
      {bool header = false, required double height}) {
    final cs = theme.colorScheme;
    return Container(
      width: _labelW,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: header ? MoydBrand.navy : cs.surface,
        border: Border(
          right: BorderSide(color: cs.outlineVariant),
          bottom: BorderSide(color: cs.outlineVariant.withOpacity(0.6)),
        ),
      ),
      child: Text(
        text,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: header ? Colors.white : cs.onSurface,
        ),
      ),
    );
  }

  List<Widget> _sectionedPolicyLabels(ThemeData theme, List<_PolicyRow> rows) {
    final out = <Widget>[];
    String? lastSection;
    for (final r in rows) {
      if (r.sectionTitle != lastSection && r.sectionTitle.isNotEmpty) {
        out.add(_sectionHeaderLabel(theme, r.sectionTitle));
        lastSection = r.sectionTitle;
      }
      out.add(_labelCell(theme, r.question, height: _rowHeight));
    }
    return out;
  }

  Widget _sectionHeaderLabel(ThemeData theme, String title) {
    final cs = theme.colorScheme;
    return Container(
      width: _labelW,
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.5),
        border: Border(
          right: BorderSide(color: cs.outlineVariant),
          bottom: BorderSide(color: cs.outlineVariant.withOpacity(0.6)),
        ),
      ),
      child: Text(title.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4)),
    );
  }

  static const double _rowHeight = 62;

  Widget _candidateColumn(ThemeData theme, CandidateEntry e, int index,
      List<_PolicyRow> rows) {
    final cs = theme.colorScheme;
    final model = e.model;

    Widget vital(String value, {double height = 44}) => Container(
          width: _colW,
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: cs.surface,
            border: Border(
              right: BorderSide(color: cs.outlineVariant.withOpacity(0.4)),
              bottom: BorderSide(color: cs.outlineVariant.withOpacity(0.6)),
            ),
          ),
          child: Text(value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall),
        );

    final t = model.stanceTally;

    // Header
    final children = <Widget>[
      InkWell(
        onTap: () => widget.onOpen(e),
        child: Container(
          width: _colW,
          height: 118,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: MoydBrand.navy,
            border: Border(
              right: BorderSide(color: cs.outlineVariant.withOpacity(0.4)),
              bottom: BorderSide(color: cs.outlineVariant),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              HeadshotAvatar(file: model.headshot, name: e.name, size: 46),
              const SizedBox(height: 6),
              Text(e.name,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
      vital(model.office ?? '—'),
      vital(model.district ?? '—'),
      // Alignment
      Container(
        width: _colW,
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(
            right: BorderSide(color: cs.outlineVariant.withOpacity(0.4)),
            bottom: BorderSide(color: cs.outlineVariant.withOpacity(0.6)),
          ),
        ),
        child: model.alignmentPct == null
            ? Text('—', style: theme.textTheme.bodySmall)
            : AlignmentBadge(pct: model.alignmentPct!, dense: true),
      ),
      vital('${t.support} / ${t.qualified} / ${t.oppose}'),
      vital(e.isYoungDem ? 'Yes' : 'No'),
      vital(ReviewFormat.currency(model.raisedToDate)),
      vital(model.selfFundedPct == null
          ? '—'
          : '${model.selfFundedPct!.round()}%'),
    ];

    // Policy cells (must align with sectioned labels: insert a spacer for each
    // section header).
    String? lastSection;
    for (final r in rows) {
      if (r.sectionTitle != lastSection && r.sectionTitle.isNotEmpty) {
        children.add(_sectionSpacer(cs));
        lastSection = r.sectionTitle;
      }
      final pos = r.perCandidate[index];
      children.add(_policyCell(theme, r, pos));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }

  Widget _sectionSpacer(ColorScheme cs) => Container(
        width: _colW,
        height: 32,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withOpacity(0.5),
          border: Border(
            right: BorderSide(color: cs.outlineVariant.withOpacity(0.4)),
            bottom: BorderSide(color: cs.outlineVariant.withOpacity(0.6)),
          ),
        ),
      );

  Widget _policyCell(ThemeData theme, _PolicyRow r, PolicyPosition? pos) {
    final cs = theme.colorScheme;
    // Row-agreement wash / rule.
    Color? wash;
    Border sideRule = Border(
      right: BorderSide(color: cs.outlineVariant.withOpacity(0.4)),
      bottom: BorderSide(color: cs.outlineVariant.withOpacity(0.6)),
    );
    if (r.unanimous) {
      wash = MoydBrand.supportBg.withOpacity(0.35);
    } else if (r.split) {
      sideRule = Border(
        left: const BorderSide(color: MoydBrand.gold, width: 3),
        right: BorderSide(color: cs.outlineVariant.withOpacity(0.4)),
        bottom: BorderSide(color: cs.outlineVariant.withOpacity(0.6)),
      );
    }

    return Container(
      width: _colW,
      height: _rowHeight,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: wash ?? cs.surface, border: sideRule),
      child: pos == null
          ? Align(
              alignment: Alignment.centerLeft,
              child: Icon(Icons.horizontal_rule_rounded,
                  size: 16, color: cs.outline),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StanceVisuals.pill(pos.stance, text: pos.answerLabel, dense: true),
                if (_showExplanations &&
                    pos.explanation != null &&
                    pos.explanation!.trim().isNotEmpty)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        pos.explanation!.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
