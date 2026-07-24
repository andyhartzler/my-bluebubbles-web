import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../widgets/review/stance_visuals.dart';
import '../../models/candidate_entry.dart';
import '../../theme/hub_theme.dart';
import '../headshot_avatar.dart';
import 'decision_activity.dart';
import 'decision_chip.dart';
import 'decision_repository.dart';
import 'endorsement_vote_repository.dart';
import 'tally_widgets.dart';

/// The chair's final-outcome panel: where the committee formally lands
/// (endorse / decline / undecided) plus the shared working note. Reachable
/// only from the chair-gated footer button; every state write goes through
/// the CHECKED path so a flaky network can never fake a recorded decision.
class FinalCallPanel extends StatefulWidget {
  final CandidateEntry entry;
  final DecisionRepository repository;
  final EndorsementVoteRepository votes;
  final DecisionActivity activity;
  final VoidCallback onOpen;
  const FinalCallPanel({
    super.key,
    required this.entry,
    required this.repository,
    required this.votes,
    required this.activity,
    required this.onOpen,
  });

  @override
  State<FinalCallPanel> createState() => _FinalCallPanelState();
}

class _FinalCallPanelState extends State<FinalCallPanel> {
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

  Future<void> _setState(DecisionState s) async {
    final ok = await widget.repository.trySetState(widget.entry.id, s);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text("Final call didn't save. Nothing was recorded."),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(label: 'Retry', onPressed: () => _setState(s)),
      ));
    }
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
    // Scrollable so the panel still fits a phone screen with the keyboard
    // open (the working-note field sits low in the sheet).
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 4,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: AnimatedBuilder(
        animation: Listenable.merge(
            [widget.repository, widget.votes, widget.activity]),
        builder: (context, _) {
          final current = widget.repository.stateFor(e.id);
          final who = widget.activity.describe(e.id);
          final tally = widget.votes.tallyFor(e.id);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  HeadshotAvatar(
                      file: e.headshot, name: e.name, size: 50),
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
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  if (e.alignmentPct != null)
                    AlignmentBadge(pct: e.alignmentPct!, showWord: true),
                ],
              ),
              const SizedBox(height: 14),
              TallyBar(tally: tally),
              const SizedBox(height: 18),
              Text('Final call (after the vote)',
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
                      onTap: () => _setState(s),
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
                          : '$who · ${DecisionVisuals.hint(current)}',
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
                    style: FilledButton.styleFrom(
                        backgroundColor: HubTheme.navy,
                        foregroundColor: Colors.white),
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

/// One selectable final-call pill: solid accent + white text when selected
/// (all accents carry white at >= 4.5:1), self-contained light bg + dark fg
/// otherwise, so the control is legible in both themes.
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
