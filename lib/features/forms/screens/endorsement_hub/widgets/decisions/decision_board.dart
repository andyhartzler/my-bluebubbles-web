import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../theme/moyd_brand.dart';
import '../../../../widgets/review/stance_visuals.dart';
import '../../models/candidate_entry.dart';
import '../../slate_controller.dart';
import '../headshot_avatar.dart';
import 'decision_chip.dart';
import 'decision_repository.dart';

/// A four-column kanban (Undecided / Interview / Endorse / Decline) of the
/// slate. Drag a candidate tile between columns to set the decision; tap a tile
/// to open a side panel with a working note and a full-review link. "Copy
/// summary" emits a privacy-safe markdown table (no headshot URLs).
class DecisionBoard extends StatelessWidget {
  final SlateController controller;
  final DecisionRepository repository;
  final void Function(CandidateEntry) onOpen;

  const DecisionBoard({
    super.key,
    required this.controller,
    required this.repository,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!controller.hasSubmissions) {
      return _empty(theme);
    }
    return AnimatedBuilder(
      animation: repository,
      builder: (context, _) {
        final entries = controller.all;
        final byState = <DecisionState, List<CandidateEntry>>{
          for (final s in DecisionState.values) s: [],
        };
        for (final e in entries) {
          byState[repository.stateFor(e.id)]!.add(e);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Drag candidates between columns to decide.',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ),
                TextButton.icon(
                  onPressed: () => _copySummary(context, entries),
                  icon: const Icon(Icons.content_copy, size: 16),
                  label: const Text('Copy summary'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: LayoutBuilder(builder: (context, constraints) {
                final columns = [
                  for (final s in DecisionState.values)
                    _Column(
                      state: s,
                      entries: byState[s]!,
                      repository: repository,
                      onOpen: onOpen,
                      onTapTile: (e) => _openPanel(context, e),
                    ),
                ];
                // 4-up on wide screens, horizontal scroll otherwise.
                if (constraints.maxWidth >= 900) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < columns.length; i++) ...[
                        if (i > 0) const SizedBox(width: 12),
                        Expanded(child: columns[i]),
                      ],
                    ],
                  );
                }
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < columns.length; i++) ...[
                        if (i > 0) const SizedBox(width: 12),
                        SizedBox(width: 260, child: columns[i]),
                      ],
                    ],
                  ),
                );
              }),
            ),
          ],
        );
      },
    );
  }

  void _openPanel(BuildContext context, CandidateEntry e) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _DecisionPanel(
        entry: e,
        repository: repository,
        onOpen: () {
          Navigator.pop(ctx);
          onOpen(e);
        },
      ),
    );
  }

  void _copySummary(BuildContext context, List<CandidateEntry> entries) {
    final buf = StringBuffer();
    buf.writeln('# Endorsement decisions');
    buf.writeln();
    buf.writeln('| Candidate | Office | Alignment | Decision |');
    buf.writeln('| --- | --- | --- | --- |');
    // Group by decision, endorse first.
    const order = [
      DecisionState.endorse,
      DecisionState.interview,
      DecisionState.undecided,
      DecisionState.decline,
    ];
    for (final state in order) {
      for (final e in entries) {
        if (repository.stateFor(e.id) != state) continue;
        final align = e.alignmentPct == null ? '—' : '${e.alignmentPct!.round()}%';
        buf.writeln(
            '| ${e.name} | ${e.officeLine.isEmpty ? '—' : e.officeLine} | $align | ${state.label} |');
      }
    }
    Clipboard.setData(ClipboardData(text: buf.toString()));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Decision summary copied (markdown)'),
      behavior: SnackBarBehavior.floating,
    ));
  }

  Widget _empty(ThemeData theme) {
    final cs = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.how_to_reg_outlined,
                size: 56, color: cs.onSurfaceVariant.withOpacity(0.6)),
            const SizedBox(height: 16),
            Text('No candidates to decide on yet',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(
                'Once submissions arrive, sort them into Interview, Endorse or '
                'Decline. Decisions save on this device.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Column extends StatefulWidget {
  final DecisionState state;
  final List<CandidateEntry> entries;
  final DecisionRepository repository;
  final void Function(CandidateEntry) onOpen;
  final void Function(CandidateEntry) onTapTile;
  const _Column({
    required this.state,
    required this.entries,
    required this.repository,
    required this.onOpen,
    required this.onTapTile,
  });

  @override
  State<_Column> createState() => _ColumnState();
}

class _ColumnState extends State<_Column> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final accent = DecisionVisuals.fg(widget.state);

    return DragTarget<CandidateEntry>(
      onWillAcceptWithDetails: (_) {
        setState(() => _hovering = true);
        return true;
      },
      onLeave: (_) => setState(() => _hovering = false),
      onAcceptWithDetails: (d) {
        setState(() => _hovering = false);
        widget.repository.setState(d.data.id, widget.state);
      },
      builder: (context, candidate, rejected) {
        return Container(
          decoration: BoxDecoration(
            color: _hovering
                ? DecisionVisuals.bg(widget.state).withOpacity(0.6)
                : cs.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hovering ? accent : cs.outlineVariant,
              width: _hovering ? 2 : 1,
            ),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(DecisionVisuals.icon(widget.state),
                      size: 16, color: accent),
                  const SizedBox(width: 6),
                  Text(widget.state.label,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text('${widget.entries.length}',
                      style: theme.textTheme.labelMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: widget.entries.isEmpty
                    ? Center(
                        child: Text('Drop here',
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant.withOpacity(0.7))),
                      )
                    : ListView.separated(
                        itemCount: widget.entries.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) => _Tile(
                          entry: widget.entries[i],
                          onTap: () => widget.onTapTile(widget.entries[i]),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  final CandidateEntry entry;
  final VoidCallback onTap;
  const _Tile({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tile = _TileContent(entry: entry, onTap: onTap);
    return LongPressDraggable<CandidateEntry>(
      data: entry,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 236,
          child: Opacity(opacity: 0.92, child: _TileContent(entry: entry)),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: tile),
      child: tile,
    );
  }
}

class _TileContent extends StatelessWidget {
  final CandidateEntry entry;
  final VoidCallback? onTap;
  const _TileContent({required this.entry, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          children: [
            HeadshotAvatar(file: entry.model.headshot, name: entry.name, size: 36),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  if (entry.officeLine.isNotEmpty)
                    Text(entry.officeLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            if (entry.alignmentPct != null)
              AlignmentBadge(pct: entry.alignmentPct!, dense: true),
          ],
        ),
      ),
    );
  }
}

class _DecisionPanel extends StatefulWidget {
  final CandidateEntry entry;
  final DecisionRepository repository;
  final VoidCallback onOpen;
  const _DecisionPanel({
    required this.entry,
    required this.repository,
    required this.onOpen,
  });

  @override
  State<_DecisionPanel> createState() => _DecisionPanelState();
}

class _DecisionPanelState extends State<_DecisionPanel> {
  late final TextEditingController _note = TextEditingController(
      text: widget.repository.recordFor(widget.entry.id).note);

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final e = widget.entry;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 4,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: AnimatedBuilder(
        animation: widget.repository,
        builder: (context, _) {
          final current = widget.repository.stateFor(e.id);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  HeadshotAvatar(
                      file: e.model.headshot, name: e.name, size: 46),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.name,
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        if (e.officeLine.isNotEmpty)
                          Text(e.officeLine,
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  if (e.alignmentPct != null)
                    AlignmentBadge(pct: e.alignmentPct!, showWord: true),
                ],
              ),
              const SizedBox(height: 16),
              Text('Decision',
                  style: theme.textTheme.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in DecisionState.values)
                    ChoiceChip(
                      label: Text(s.label),
                      avatar: Icon(DecisionVisuals.icon(s),
                          size: 16,
                          color: current == s
                              ? Colors.white
                              : DecisionVisuals.fg(s)),
                      selected: current == s,
                      onSelected: (_) =>
                          widget.repository.setState(e.id, s),
                      selectedColor: DecisionVisuals.fg(s),
                      labelStyle: TextStyle(
                        color: current == s ? Colors.white : cs.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _note,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Working note',
                  hintText: 'Committee notes, follow-ups…',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (v) => widget.repository.setNote(e.id, v),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: widget.onOpen,
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text('Open full review'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    style:
                        FilledButton.styleFrom(backgroundColor: MoydBrand.navy),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
