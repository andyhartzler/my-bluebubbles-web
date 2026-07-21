import 'package:flutter/material.dart';

import '../../../../models/submission_review_model.dart';
import '../../../../widgets/review/stance_visuals.dart';
import '../../models/candidate_entry.dart';
import '../../theme/hub_theme.dart';
import '../headshot_avatar.dart';

/// Side-by-side comparison of selected candidates.
///
/// When fewer than two candidates are selected it becomes a candidate picker
/// (faces + alignment, tap to add) so building a comparison never requires a
/// round-trip to the Roster tab. With two or more, it renders a comparison
/// table: gradient candidate header cards (with remove + open), vitals rows,
/// then policy rows grouped by section. Unanimous rows get a soft support
/// wash and a check on the label; split rows get a gold rule + split chip.
/// Header chips filter to unanimous / split, "Divergence first" reorders by
/// contestedness, and a switch reveals inline explanations.
class SideBySideCompare extends StatefulWidget {
  /// The current compare selection (owned by the SlateController).
  final List<CandidateEntry> selected;

  /// The full slate, used by the inline picker.
  final List<CandidateEntry> all;

  /// Toggle a candidate in / out of the compare selection.
  final void Function(String id) onToggleSelect;

  final void Function(CandidateEntry) onOpen;

  const SideBySideCompare({
    super.key,
    required this.selected,
    required this.all,
    required this.onToggleSelect,
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
  // Column metrics. The sticky label column and candidate columns narrow on
  // phone widths (set from the LayoutBuilder in [_comparisonView]) so the
  // sticky labels never eat most of a 360px viewport.
  double _labelW = 210;
  double _colW = 168;
  static const double _headerH = 152;
  static const double _vitalH = 44;
  static const double _sectionH = 34;

  final ScrollController _hCtrl = ScrollController();
  bool _showExplanations = false;
  bool _divergenceFirst = false;
  _RowFilter _filter = _RowFilter.all;

  double get _rowHeight => _showExplanations ? 88 : 58;

  @override
  void dispose() {
    _hCtrl.dispose();
    super.dispose();
  }

  List<_PolicyRow> _buildPolicyRows() {
    final entries = widget.selected;
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
    if (widget.selected.length < 2) {
      return _PickerView(
        all: widget.all,
        selectedIds: widget.selected.map((e) => e.id).toSet(),
        onToggleSelect: widget.onToggleSelect,
      );
    }
    return _comparisonView(context);
  }

  Widget _comparisonView(BuildContext context) {
    final theme = Theme.of(context);
    final entries = widget.selected;

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

    return LayoutBuilder(builder: (context, constraints) {
      final narrow = constraints.maxWidth < 560;
      _labelW = narrow ? 132 : 210;
      _colW = narrow ? 148 : 168;
      return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _controls(theme, unanimousCount, splitCount),
        const SizedBox(height: 10),
        Expanded(
          child: HubCard(
            padding: EdgeInsets.zero,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sticky label column
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _cornerCell(theme),
                        for (final l in _vitalLabels())
                          _labelCell(theme, l, height: _vitalH),
                        ..._sectionedPolicyLabels(theme, policyRows),
                      ],
                    ),
                    Expanded(
                      child: Scrollbar(
                        controller: _hCtrl,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _hCtrl,
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (var ci = 0; ci < entries.length; ci++)
                                _candidateColumn(
                                    theme, entries[ci], ci, policyRows),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
      );
    });
  }

  // ---------------- controls ----------------

  Widget _controls(ThemeData theme, int unanimous, int split) {
    final cs = theme.colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _filterChip('All ${_buildPolicyRows().length} questions',
            _RowFilter.all, HubTheme.navy),
        _filterChip('$unanimous unanimous', _RowFilter.unanimous,
            StanceVisuals.fg(Stance.support)),
        _filterChip(
            '$split split', _RowFilter.split, StanceVisuals.fg(Stance.oppose)),
        FilterChip(
          label: const Text('Divergence first'),
          selected: _divergenceFirst,
          onSelected: (v) => setState(() => _divergenceFirst = v),
          showCheckmark: false,
          avatar: Icon(Icons.swap_vert,
              size: 15,
              color: _divergenceFirst ? Colors.white : cs.onSurfaceVariant),
          selectedColor: HubTheme.royal,
          labelStyle: TextStyle(
            color: _divergenceFirst ? Colors.white : cs.onSurface,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          backgroundColor: cs.surface,
          side: BorderSide(color: cs.outlineVariant),
        ),
        FilterChip(
          label: const Text('Explanations'),
          selected: _showExplanations,
          onSelected: (v) => setState(() => _showExplanations = v),
          showCheckmark: false,
          avatar: Icon(Icons.notes,
              size: 15,
              color: _showExplanations ? Colors.white : cs.onSurfaceVariant),
          selectedColor: HubTheme.royal,
          labelStyle: TextStyle(
            color: _showExplanations ? Colors.white : cs.onSurface,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          backgroundColor: cs.surface,
          side: BorderSide(color: cs.outlineVariant),
        ),
        ActionChip(
          avatar: const Icon(Icons.person_add_alt,
              size: 15, color: HubTheme.navy),
          label: const Text('Add candidate'),
          labelStyle: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: HubTheme.navy),
          side: const BorderSide(color: HubTheme.gold),
          backgroundColor: HubTheme.gold.withOpacity(0.15),
          onPressed: _openAddSheet,
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

  void _openAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: _PickerView(
              all: widget.all,
              selectedIds: widget.selected.map((e) => e.id).toSet(),
              onToggleSelect: (id) {
                widget.onToggleSelect(id);
                Navigator.pop(ctx);
              },
              compactHeader: true,
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- label column ----------------

  List<String> _vitalLabels() => const [
        'Office',
        'District',
        'Alignment',
        'Support / Qual / Oppose',
        'Young Dem',
        'Raised',
        'Self-funded %',
      ];

  Widget _cornerCell(ThemeData theme) {
    return Container(
      width: _labelW,
      height: _headerH,
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(gradient: HubTheme.chip),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const Icon(Icons.compare_arrows, color: HubTheme.gold, size: 22),
          const SizedBox(height: 8),
          Text('${widget.selected.length} candidates',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          const Text('Tap a face to open the full review',
              style: TextStyle(color: Color(0xB3FFFFFF), fontSize: 10.5)),
        ],
      ),
    );
  }

  Widget _labelCell(ThemeData theme, String text,
      {required double height, Widget? badge, Color? accent}) {
    final cs = theme.colorScheme;
    return Container(
      width: _labelW,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          left: accent == null
              ? BorderSide.none
              : BorderSide(color: accent, width: 3),
          right: BorderSide(color: cs.outlineVariant),
          bottom: BorderSide(color: cs.outlineVariant.withOpacity(0.6)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ),
          if (badge != null) ...[const SizedBox(width: 4), badge],
        ],
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
      Widget? badge;
      Color? accent;
      if (r.unanimous) {
        badge = Icon(Icons.check_circle,
            size: 14, color: StanceVisuals.fg(Stance.support));
      } else if (r.split) {
        badge = const Icon(Icons.bolt, size: 14, color: HubTheme.gold);
        accent = HubTheme.gold;
      }
      out.add(_labelCell(theme, r.question,
          height: _rowHeight, badge: badge, accent: accent));
    }
    return out;
  }

  Widget _sectionHeaderLabel(ThemeData theme, String title) {
    final cs = theme.colorScheme;
    return Container(
      width: _labelW,
      height: _sectionH,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.55),
        border: Border(
          right: BorderSide(color: cs.outlineVariant),
          bottom: BorderSide(color: cs.outlineVariant.withOpacity(0.6)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: HubTheme.gold,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(title.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5)),
          ),
        ],
      ),
    );
  }

  // ---------------- candidate columns ----------------

  Widget _candidateColumn(ThemeData theme, CandidateEntry e, int index,
      List<_PolicyRow> rows) {
    final cs = theme.colorScheme;
    final model = e.model;

    Widget vital(Widget child) => Container(
          width: _colW,
          height: _vitalH,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: cs.surface,
            border: Border(
              right: BorderSide(color: cs.outlineVariant.withOpacity(0.4)),
              bottom: BorderSide(color: cs.outlineVariant.withOpacity(0.6)),
            ),
          ),
          child: child,
        );

    Widget vitalText(String value, {bool strong = false}) => vital(Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
          ),
        ));

    final t = model.stanceTally;

    final children = <Widget>[
      _candidateHeader(theme, e),
      vitalText(model.office ?? '—', strong: true),
      vitalText(model.district ?? '—'),
      vital(model.alignmentPct == null
          ? Text('—', style: theme.textTheme.bodySmall)
          : AlignmentBadge(pct: model.alignmentPct!, dense: true)),
      vital(_stanceMini(t)),
      vital(e.isYoungDem
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.workspace_premium,
                    size: 14, color: HubTheme.gold),
                const SizedBox(width: 4),
                Text('Yes',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ],
            )
          : Text('No', style: theme.textTheme.bodySmall)),
      vitalText(ReviewFormat.currency(model.raisedToDate)),
      vitalText(model.selfFundedPct == null
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

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }

  Widget _candidateHeader(ThemeData theme, CandidateEntry e) {
    return Container(
      width: _colW,
      height: _headerH,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
              color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => widget.onOpen(e),
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              gradient: HubTheme.hero,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: HubTheme.gold, width: 2),
                        ),
                        padding: const EdgeInsets.all(2),
                        child: HeadshotAvatar(
                            file: e.headshot, name: e.name, size: 52),
                      ),
                      const SizedBox(height: 7),
                      Text(e.name,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              height: 1.15,
                              fontWeight: FontWeight.w800)),
                      if (e.officeLine.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(e.officeLine,
                            maxLines: 1,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Color(0xE6FFFFFF), fontSize: 10)),
                      ],
                    ],
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: Tooltip(
                    message: 'Remove from comparison',
                    child: InkWell(
                      onTap: () => widget.onToggleSelect(e.id),
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close,
                            size: 13, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stanceMini(({int support, int oppose, int qualified, int other}) t) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        StanceVisuals.pill(Stance.support, text: '${t.support}', dense: true),
        const SizedBox(width: 4),
        StanceVisuals.pill(Stance.qualified,
            text: '${t.qualified}', dense: true),
        const SizedBox(width: 4),
        StanceVisuals.pill(Stance.oppose, text: '${t.oppose}', dense: true),
      ],
    );
  }

  Widget _sectionSpacer(ColorScheme cs) => Container(
        width: _colW,
        height: _sectionH,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withOpacity(0.55),
          border: Border(
            right: BorderSide(color: cs.outlineVariant.withOpacity(0.4)),
            bottom: BorderSide(color: cs.outlineVariant.withOpacity(0.6)),
          ),
        ),
      );

  Widget _policyCell(ThemeData theme, _PolicyRow r, PolicyPosition? pos) {
    final cs = theme.colorScheme;
    Color? wash;
    if (r.unanimous) {
      wash = StanceVisuals.bg(Stance.support).withOpacity(0.35);
    }

    return Container(
      width: _colW,
      height: _rowHeight,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: wash ?? cs.surface,
        border: Border(
          right: BorderSide(color: cs.outlineVariant.withOpacity(0.4)),
          bottom: BorderSide(color: cs.outlineVariant.withOpacity(0.6)),
        ),
      ),
      child: pos == null
          ? Align(
              alignment: Alignment.centerLeft,
              child: Icon(Icons.horizontal_rule_rounded,
                  size: 16, color: cs.outline),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                StanceVisuals.pill(pos.stance,
                    text: pos.answerLabel, dense: true),
                if (_showExplanations &&
                    pos.explanation != null &&
                    pos.explanation!.trim().isNotEmpty)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        pos.explanation!.trim(),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: cs.onSurfaceVariant, height: 1.25),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

// ==================== candidate picker ====================

/// The "build your comparison" picker shown when fewer than two candidates
/// are selected (and inside the add-candidate sheet). Faces-first, sorted by
/// alignment, tap to add or remove.
class _PickerView extends StatelessWidget {
  final List<CandidateEntry> all;
  final Set<String> selectedIds;
  final void Function(String id) onToggleSelect;
  final bool compactHeader;

  const _PickerView({
    required this.all,
    required this.selectedIds,
    required this.onToggleSelect,
    this.compactHeader = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sorted = [...all]..sort((a, b) {
        final pa = a.alignmentPct ?? -1;
        final pb = b.alignmentPct ?? -1;
        final cmp = pb.compareTo(pa);
        return cmp != 0
            ? cmp
            : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    final header = compactHeader
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add a candidate',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text('Tap a candidate to add them to the comparison.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 14),
            ],
          )
        : Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: HubTheme.hero,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: HubTheme.royal.withOpacity(0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child:
                    const Icon(Icons.compare_arrows, size: 30, color: Colors.white),
              ),
              const SizedBox(height: 14),
              Text('Build a comparison',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(
                selectedIds.isEmpty
                    ? 'Pick two or more candidates to line up their vitals and every policy stance.'
                    : 'One selected — pick at least one more to start the side-by-side.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
            ],
          );

    final grid = Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: compactHeader ? WrapAlignment.start : WrapAlignment.center,
      children: [
        for (final e in sorted)
          _PickChip(
            entry: e,
            selected: selectedIds.contains(e.id),
            onTap: () => onToggleSelect(e.id),
          ),
      ],
    );

    if (compactHeader) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [header, grid],
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(children: [header, grid]),
        ),
      ),
    );
  }
}

class _PickChip extends StatelessWidget {
  final CandidateEntry entry;
  final bool selected;
  final VoidCallback onTap;
  const _PickChip(
      {required this.entry, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        width: 208,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected
              ? HubTheme.gold.withOpacity(0.14)
              : cs.surfaceContainerHighest.withOpacity(0.35),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? HubTheme.gold : cs.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            HeadshotAvatar(file: entry.headshot, name: entry.name, size: 40),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  entry.alignmentPct == null
                      ? Text('Unscored',
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: cs.onSurfaceVariant))
                      : AlignmentBadge(pct: entry.alignmentPct!, dense: true),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              selected ? Icons.check_circle : Icons.add_circle_outline,
              size: 20,
              color: selected ? HubTheme.gold : cs.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
