import 'package:flutter/material.dart';

import '../../models/candidate_entry.dart';
import '../../theme/hub_theme.dart';
import '../headshot_avatar.dart';
import 'decision_chip.dart';
import 'decision_repository.dart';

/// "Locked baseline": the decisions the committee already made, read-only.
/// Nothing in the vote path can mutate these; a chair Confirm (elsewhere)
/// is the only way a candidate ever moves in here tonight.
///
/// [entries] is the (possibly search-filtered) list to render; [totalCount]
/// is the full decided count so the header can read "X of Y decided" while a
/// search query is narrowing the section.
class BaselineSection extends StatelessWidget {
  final List<CandidateEntry> entries;
  final int totalCount;
  final bool expanded;
  final VoidCallback onToggle;
  final DecisionState Function(String candidateId) stateFor;
  final void Function(CandidateEntry) onOpen;

  const BaselineSection({
    super.key,
    required this.entries,
    required this.totalCount,
    required this.expanded,
    required this.onToggle,
    required this.stateFor,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (entries.isEmpty) return const SizedBox.shrink();
    final filtered = entries.length != totalCount;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(10),
            child: Row(
              children: [
                Expanded(
                  child: HubCardHeader(
                    icon: Icons.lock_clock,
                    title: filtered
                        ? 'Locked baseline · ${entries.length} of '
                            '$totalCount decided'
                        : 'Locked baseline · $totalCount decided',
                    subtitle: 'Shared decisions already made, read-only',
                    tileGradient: HubTheme.gradAmber,
                  ),
                ),
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  color: cs.onSurfaceVariant,
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final e in entries)
                    BaselineRow(
                      entry: e,
                      state: stateFor(e.id),
                      onOpen: () => onOpen(e),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One locked, already-decided candidate: compact identity + the shared
/// decision chip + a lock glyph. No vote controls, no tally, no final call.
class BaselineRow extends StatelessWidget {
  final CandidateEntry entry;
  final DecisionState state;
  final VoidCallback onOpen;
  const BaselineRow({
    super.key,
    required this.entry,
    required this.state,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(10),
      child: Opacity(
        opacity: 0.92,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Row(
            children: [
              HeadshotAvatar(file: entry.headshot, name: entry.name, size: 36),
              const SizedBox(width: 10),
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
              const SizedBox(width: 8),
              DecisionChip(state: state, compact: true),
              const SizedBox(width: 8),
              Icon(Icons.lock, size: 14, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
