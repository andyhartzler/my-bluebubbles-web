import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';

import '../../../../theme/moyd_brand.dart';
import '../../../../widgets/review/stance_visuals.dart';
import '../../models/candidate_entry.dart';
import '../../slate_controller.dart';
import '../headshot_avatar.dart';
import 'decision_activity.dart';
import 'decision_chip.dart';
import 'decision_repository.dart';

/// The committee decision surface: a branded tally header (endorsed /
/// interview / declined / undecided, live-sync indicator, slate progress)
/// over a four-column board of candidate cards. Drag a card between columns
/// to set the decision, or tap it for a side panel with the four-state
/// control, the shared working note and a full-review link. Every change
/// syncs live to all execs via the shared repository; each card shows who
/// last touched it and when. "Copy summary" emits a privacy-safe markdown
/// table (no headshot URLs).
class DecisionBoard extends StatefulWidget {
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
  State<DecisionBoard> createState() => _DecisionBoardState();
}

class _DecisionBoardState extends State<DecisionBoard> {
  late final DecisionActivity _activity = DecisionActivity(widget.repository);
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    // Keep the relative "2m ago" attributions fresh.
    _clock = Timer.periodic(const Duration(seconds: 45), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _activity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!widget.controller.hasSubmissions) {
      return _empty(theme);
    }
    return AnimatedBuilder(
      animation: Listenable.merge([widget.repository, _activity]),
      builder: (context, _) {
        final entries = widget.controller.all;
        final byState = <DecisionState, List<CandidateEntry>>{
          for (final s in DecisionState.values) s: [],
        };
        for (final e in entries) {
          byState[widget.repository.stateFor(e.id)]!.add(e);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TallyHeader(
              byState: byState,
              total: entries.length,
              activity: _activity,
              nameFor: (id) {
                for (final e in entries) {
                  if (e.id == id) return e.name;
                }
                return null;
              },
              onCopy: () => _copySummary(context, entries),
            ),
            const SizedBox(height: 10),
            Text(
              'Drag a candidate between columns, or tap a card to set the '
              'call and leave a working note. Everything here is shared '
              'live with every exec.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: LayoutBuilder(builder: (context, constraints) {
                final columns = [
                  for (final s in DecisionState.values)
                    _Column(
                      state: s,
                      entries: byState[s]!,
                      repository: widget.repository,
                      activity: _activity,
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
                        SizedBox(width: 272, child: columns[i]),
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
        repository: widget.repository,
        activity: _activity,
        onOpen: () {
          Navigator.pop(ctx);
          widget.onOpen(e);
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
        if (widget.repository.stateFor(e.id) != state) continue;
        final align =
            e.alignmentPct == null ? '—' : '${e.alignmentPct!.round()}%';
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
                'Decline. Decisions sync live to every exec.',
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

// ==================== tally header ====================

/// Branded gradient scoreboard: one tile per decision state, a slate progress
/// bar, a pulsing LIVE indicator and the latest shared activity line. Dark
/// navy gradient with white/gold text so it reads identically in both themes.
class _TallyHeader extends StatelessWidget {
  final Map<DecisionState, List<CandidateEntry>> byState;
  final int total;
  final DecisionActivity activity;
  final String? Function(String candidateId) nameFor;
  final VoidCallback onCopy;

  const _TallyHeader({
    required this.byState,
    required this.total,
    required this.activity,
    required this.nameFor,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final decided = total - byState[DecisionState.undecided]!.length;

    String subline = 'Shared board · every change syncs live to all execs';
    final latest = activity.latest;
    if (latest != null) {
      final who = activity.actorLabel(latest.by);
      final candidate = nameFor(latest.candidateId);
      subline = candidate == null
          ? 'Latest change by $who · ${DecisionActivity.timeAgo(latest.at)}'
          : 'Latest: $who updated $candidate · ${DecisionActivity.timeAgo(latest.at)}';
    }

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [BrandColors.unityBlue, BrandColors.royalBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.how_to_vote, color: MoydBrand.gold, size: 20),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Committee decisions',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800)),
              ),
              const _LivePill(),
              const SizedBox(width: 6),
              Tooltip(
                message: 'Copy summary (markdown)',
                child: IconButton(
                  onPressed: onCopy,
                  icon: const Icon(Icons.content_copy,
                      color: Colors.white, size: 18),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(subline,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.75), fontSize: 11.5)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final s in const [
                DecisionState.endorse,
                DecisionState.interview,
                DecisionState.decline,
                DecisionState.undecided,
              ])
                _TallyTile(state: s, count: byState[s]!.length),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : decided / total,
                    minHeight: 8,
                    backgroundColor: Colors.white24,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(MoydBrand.gold),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text('$decided of $total decided',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}

class _TallyTile extends StatelessWidget {
  final DecisionState state;
  final int count;
  const _TallyTile({required this.state, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: DecisionVisuals.accent(state),
              shape: BoxShape.circle,
            ),
            child:
                Icon(DecisionVisuals.icon(state), color: Colors.white, size: 15),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$count',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      height: 1.0)),
              const SizedBox(height: 2),
              Text(state.label.toUpperCase(),
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.78),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Pulsing "LIVE" pill (white text on navy stays AA; the dot is decorative).
class _LivePill extends StatefulWidget {
  const _LivePill();

  @override
  State<_LivePill> createState() => _LivePillState();
}

class _LivePillState extends State<_LivePill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: Tween(begin: 0.35, end: 1.0).animate(
                CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF4ADE80),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Text('LIVE',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1)),
        ],
      ),
    );
  }
}

// ==================== columns ====================

class _Column extends StatefulWidget {
  final DecisionState state;
  final List<CandidateEntry> entries;
  final DecisionRepository repository;
  final DecisionActivity activity;
  final void Function(CandidateEntry) onTapTile;
  const _Column({
    required this.state,
    required this.entries,
    required this.repository,
    required this.activity,
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
    final accent = DecisionVisuals.accent(widget.state);
    final fg = DecisionVisuals.fg(widget.state);

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
        return AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          decoration: BoxDecoration(
            color: _hovering
                ? DecisionVisuals.bg(widget.state).withOpacity(0.55)
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
              // Self-contained light-bg / dark-fg header pill: legible on the
              // column wash in BOTH themes without theme branching.
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: DecisionVisuals.bg(widget.state),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(DecisionVisuals.icon(widget.state),
                        size: 15, color: fg),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(widget.state.label,
                          style: TextStyle(
                              color: fg,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text('${widget.entries.length}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: widget.entries.isEmpty
                    ? Center(
                        child: Text('Drop a candidate here',
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant.withOpacity(0.7))),
                      )
                    : ListView.separated(
                        itemCount: widget.entries.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) => _Tile(
                          entry: widget.entries[i],
                          repository: widget.repository,
                          activity: widget.activity,
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

// ==================== candidate cards ====================

class _Tile extends StatelessWidget {
  final CandidateEntry entry;
  final DecisionRepository repository;
  final DecisionActivity activity;
  final VoidCallback onTap;
  const _Tile({
    required this.entry,
    required this.repository,
    required this.activity,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tile = _TileContent(
      entry: entry,
      repository: repository,
      activity: activity,
      onTap: onTap,
    );
    // Draggable (not long-press) so mouse users on web can drag immediately;
    // a plain click still opens the panel.
    return Draggable<CandidateEntry>(
      data: entry,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 248,
          child: Opacity(
            opacity: 0.94,
            child: _TileContent(
              entry: entry,
              repository: repository,
              activity: activity,
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: tile),
      child: tile,
    );
  }
}

class _TileContent extends StatelessWidget {
  final CandidateEntry entry;
  final DecisionRepository repository;
  final DecisionActivity activity;
  final VoidCallback? onTap;
  const _TileContent({
    required this.entry,
    required this.repository,
    required this.activity,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final record = repository.recordFor(entry.id);
    final note = record.note.trim();
    final who = activity.describe(entry.id);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                HeadshotAvatar(
                    file: entry.model.headshot, name: entry.name, size: 38),
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
                if (entry.alignmentPct != null) ...[
                  const SizedBox(width: 6),
                  AlignmentBadge(pct: entry.alignmentPct!, dense: true),
                ],
              ],
            ),
            if (note.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.sticky_note_2_outlined,
                      size: 13, color: cs.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(note,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontStyle: FontStyle.italic)),
                  ),
                ],
              ),
            ],
            if (who != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.history, size: 12, color: cs.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(who,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: cs.onSurfaceVariant)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ==================== decision panel ====================

class _DecisionPanel extends StatefulWidget {
  final CandidateEntry entry;
  final DecisionRepository repository;
  final DecisionActivity activity;
  final VoidCallback onOpen;
  const _DecisionPanel({
    required this.entry,
    required this.repository,
    required this.activity,
    required this.onOpen,
  });

  @override
  State<_DecisionPanel> createState() => _DecisionPanelState();
}

class _DecisionPanelState extends State<_DecisionPanel> {
  late final TextEditingController _note = TextEditingController(
      text: widget.repository.recordFor(widget.entry.id).note);
  Timer? _noteDebounce;
  bool _noteDirty = false;

  // Debounce note saves so the shared table (and every exec's realtime feed)
  // gets one upsert per pause instead of one per keystroke.
  void _queueNoteSave(String _) {
    _noteDirty = true;
    _noteDebounce?.cancel();
    _noteDebounce = Timer(const Duration(milliseconds: 600), _flushNote);
  }

  void _flushNote() {
    _noteDebounce?.cancel();
    if (!_noteDirty) return;
    _noteDirty = false;
    widget.repository.setNote(widget.entry.id, _note.text);
  }

  @override
  void dispose() {
    _flushNote();
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
        animation:
            Listenable.merge([widget.repository, widget.activity]),
        builder: (context, _) {
          final current = widget.repository.stateFor(e.id);
          final who = widget.activity.describe(e.id);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  HeadshotAvatar(
                      file: e.model.headshot, name: e.name, size: 50),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.name,
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800)),
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
              const SizedBox(height: 18),
              Text('Committee call',
                  style: theme.textTheme.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in DecisionState.values)
                    _StatePill(
                      state: s,
                      selected: current == s,
                      onTap: () => widget.repository.setState(e.id, s),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.history, size: 13, color: cs.onSurfaceVariant),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      who == null
                          ? DecisionVisuals.hint(current)
                          : '$who — ${DecisionVisuals.hint(current)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: cs.onSurfaceVariant),
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
                  labelText: 'Working note (shared)',
                  hintText: 'Committee notes, follow-ups…',
                  helperText: 'Autosaves and syncs live to every exec.',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: _queueNoteSave,
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
                    onPressed: () {
                      _flushNote();
                      Navigator.pop(context);
                    },
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

/// One selectable decision pill: solid accent + white text when selected
/// (all four accents carry white at >= 4.5:1), self-contained light bg +
/// dark fg otherwise, so the control is legible in both themes.
class _StatePill extends StatelessWidget {
  final DecisionState state;
  final bool selected;
  final VoidCallback onTap;
  const _StatePill({
    required this.state,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = DecisionVisuals.fg(state);
    final accent = DecisionVisuals.accent(state);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? accent : DecisionVisuals.bg(state),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? accent : fg.withOpacity(0.35),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(DecisionVisuals.icon(state),
                size: 16, color: selected ? Colors.white : fg),
            const SizedBox(width: 6),
            Text(state.label,
                style: TextStyle(
                    color: selected ? Colors.white : fg,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
