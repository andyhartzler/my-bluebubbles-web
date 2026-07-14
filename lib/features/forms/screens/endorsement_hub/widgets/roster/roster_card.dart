import 'package:flutter/material.dart';

import '../../../../theme/moyd_brand.dart';
import '../../../../widgets/review/stance_visuals.dart';
import '../../models/candidate_entry.dart';
import '../headshot_avatar.dart';

/// A single candidate tile in the roster gallery: face on top, an info block on
/// the (opaque) card surface below, a 3-segment stance strip, and flag chips.
///
/// The face never carries text; every label sits on the solid card surface so
/// it stays legible in both themes. Hovering reveals a select checkbox and a
/// compare affordance.
class RosterCard extends StatefulWidget {
  final CandidateEntry entry;
  final bool selected;
  final VoidCallback onOpen;
  final VoidCallback onToggleSelect;

  /// Optional decision chip (built by the Decisions layer when present).
  final Widget? decisionChip;

  const RosterCard({
    super.key,
    required this.entry,
    required this.selected,
    required this.onOpen,
    required this.onToggleSelect,
    this.decisionChip,
  });

  @override
  State<RosterCard> createState() => _RosterCardState();
}

class _RosterCardState extends State<RosterCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final entry = widget.entry;
    final model = entry.model;
    final showControls = _hover || widget.selected;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onOpen,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.selected ? MoydBrand.gold : cs.outlineVariant,
              width: widget.selected ? 2 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---- face ----
              AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    HeadshotAvatar(
                      file: model.headshot,
                      name: entry.name,
                      circle: false,
                      radius: 0,
                      size: 220,
                    ),
                    // status chip (top-left)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: _StatusChip(status: entry.submission.status),
                    ),
                    // alignment badge (top-right)
                    if (model.alignmentPct != null)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: _Frosted(
                          child: AlignmentBadge(
                              pct: model.alignmentPct!, dense: true),
                        ),
                      ),
                    // hover controls
                    if (showControls)
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: _SelectButton(
                          selected: widget.selected,
                          onTap: widget.onToggleSelect,
                        ),
                      ),
                  ],
                ),
              ),
              // ---- info block ----
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (entry.isYoungDem)
                          Container(
                            width: 3,
                            height: 34,
                            margin: const EdgeInsets.only(right: 8, top: 1),
                            decoration: BoxDecoration(
                              color: MoydBrand.gold,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (entry.officeLine.isNotEmpty)
                                Text(
                                  entry.officeLine,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _StanceStrip(entry: entry),
                    if (entry.flags.any) ...[
                      const SizedBox(height: 10),
                      _FlagChips(flags: entry.flags),
                    ],
                    if (widget.decisionChip != null) ...[
                      const SizedBox(height: 10),
                      widget.decisionChip!,
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The three-segment support / qualified / oppose strip.
class _StanceStrip extends StatelessWidget {
  final CandidateEntry entry;
  const _StanceStrip({required this.entry});

  @override
  Widget build(BuildContext context) {
    final t = entry.stanceTally;
    final total = t.support + t.qualified + t.oppose + t.other;
    if (total == 0) {
      return Text(
        'No policy answers',
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      );
    }
    final segs = <(Color, int)>[
      (MoydBrand.supportFg, t.support),
      (MoydBrand.qualifiedFg, t.qualified),
      (MoydBrand.opposeFg, t.oppose),
      (MoydBrand.neutralFg, t.other),
    ].where((e) => e.$2 > 0).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 8,
            child: Row(
              children: [
                for (final s in segs)
                  Expanded(flex: s.$2, child: ColoredBox(color: s.$1)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${t.support} support · ${t.qualified} qualified · ${t.oppose} oppose',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _FlagChips extends StatelessWidget {
  final CandidateFlags flags;
  const _FlagChips({required this.flags});

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    if (flags.nonDemHistory) {
      chips.add(_chip(Icons.swap_horiz, 'Non-Dem history'));
    }
    if (flags.selfFundedMajority) {
      chips.add(_chip(Icons.savings_outlined, 'Self-funded >50%'));
    }
    if (flags.missingDocs) {
      chips.add(_chip(Icons.folder_off_outlined, 'Missing docs'));
    }
    if (flags.uncertified) {
      chips.add(_chip(Icons.history_edu_outlined, 'Not certified'));
    }
    return Wrap(spacing: 6, runSpacing: 6, children: chips);
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: MoydBrand.amberBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: MoydBrand.amber),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: MoydBrand.amber,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      'reviewed' => 'Reviewed',
      'processed' => 'Processed',
      _ => 'Submitted',
    };
    return _Frosted(
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// A dark translucent pill so a badge stays legible over any photo without
/// putting readable text directly on the image itself.
class _Frosted extends StatelessWidget {
  final Widget child;
  const _Frosted({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: MoydBrand.navy.withOpacity(0.82),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}

class _SelectButton extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  const _SelectButton({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? MoydBrand.gold : MoydBrand.navy.withOpacity(0.9),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? Icons.check_circle : Icons.add_circle_outline,
                size: 15,
                color: selected ? MoydBrand.navy : Colors.white,
              ),
              const SizedBox(width: 4),
              Text(
                selected ? 'Added' : 'Compare',
                style: TextStyle(
                  color: selected ? MoydBrand.navy : Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
