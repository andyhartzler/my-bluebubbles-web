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
            // Collapsed: an overlapping face strip keeps the tab's
            // faces-first identity visible at near-zero vertical cost while
            // the baseline is locked shut; expansion swaps it for the rows.
            firstChild: _FaceStrip(entries: entries, totalCount: totalCount),
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

/// Collapsed-state face strip: the first few decided candidates as small
/// overlapping headshots plus a "+K" pill for the rest. Purely decorative
/// recognition; opening the section is still the only way to read names.
class _FaceStrip extends StatelessWidget {
  final List<CandidateEntry> entries;
  final int totalCount;
  const _FaceStrip({required this.entries, required this.totalCount});

  // 28px avatars overlapped by 10px.
  static const double _face = 28;
  static const double _step = 18;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox(width: double.infinity);
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: LayoutBuilder(builder: (context, constraints) {
          final maxFaces = constraints.maxWidth < 720 ? 6 : 8;
          final shown = entries.take(maxFaces).toList();
          final extra = totalCount - shown.length;
          return Row(
            children: [
              SizedBox(
                width: _face + (shown.length - 1) * _step,
                height: _face,
                child: Stack(
                  children: [
                    for (var i = 0; i < shown.length; i++)
                      Positioned(
                        left: i * _step,
                        child: HeadshotAvatar(
                          file: shown[i].headshot,
                          name: shown[i].name,
                          size: _face,
                        ),
                      ),
                  ],
                ),
              ),
              if (extra > 0) ...[
                const SizedBox(width: 8),
                HubCountPill(text: '+$extra'),
              ],
            ],
          );
        }),
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
