import 'package:flutter/material.dart';

import '../../../../models/submission_review_model.dart';
import '../../../../theme/moyd_brand.dart';
import '../../../../widgets/review/stance_visuals.dart';
import '../../models/candidate_entry.dart';
import '../../theme/hub_theme.dart';
import '../headshot_avatar.dart';

/// A single candidate tile in the roster gallery: face on top (with a subtle
/// navy scrim at the base so the frosted badges always read), an info block on
/// the opaque card surface below, a 3-segment stance strip, and flag chips.
///
/// The face never carries body text; every label sits on the solid card
/// surface so it stays legible in both themes. Hovering lifts the card and
/// reveals the compare affordance; selection wraps the card in gold.
class RosterCard extends StatefulWidget {
  final CandidateEntry entry;
  final bool selected;
  final VoidCallback onOpen;
  final VoidCallback onToggleSelect;

  /// Optional decision chip (built by the Decisions layer when present).
  final Widget? decisionChip;

  /// Phone layout: face on the left, details on the right, natural height,
  /// and an always-visible Compare button (touch has no hover state).
  final bool horizontal;

  const RosterCard({
    super.key,
    required this.entry,
    required this.selected,
    required this.onOpen,
    required this.onToggleSelect,
    this.decisionChip,
    this.horizontal = false,
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
    final dark = theme.brightness == Brightness.dark;
    final entry = widget.entry;
    final model = entry.model;
    final showControls = _hover || widget.selected;

    if (widget.horizontal) {
      return _horizontalCard(theme, cs, dark, entry, model);
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onOpen,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _hover ? -3 : 0, 0),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: widget.selected
                  ? HubTheme.gold
                  : (_hover ? HubTheme.royal.withOpacity(0.55) : cs.outlineVariant),
              width: widget.selected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _hover
                    ? HubTheme.royal.withOpacity(dark ? 0.45 : 0.22)
                    : Colors.black.withOpacity(dark ? 0.25 : 0.05),
                blurRadius: _hover ? 16 : 8,
                offset: Offset(0, _hover ? 8 : 3),
              ),
            ],
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
                      file: entry.headshot,
                      name: entry.name,
                      circle: false,
                      radius: 0,
                      size: 220,
                    ),
                    // Subtle navy scrim at the base of the photo (decorative;
                    // no text renders on the image itself).
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.center,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              HubTheme.navy.withOpacity(0.32),
                            ],
                          ),
                        ),
                      ),
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      entry.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  if (entry.isYoungDem) ...[
                                    const SizedBox(width: 5),
                                    const Tooltip(
                                      message: 'Young Dem',
                                      child: Icon(Icons.workspace_premium,
                                          size: 15, color: HubTheme.gold),
                                    ),
                                  ],
                                ],
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

extension on _RosterCardState {
  /// Phone-width layout: 96px face thumb + always-visible Compare button on
  /// the left, all text on the opaque card surface to the right. Natural
  /// height, so long flag rows and the decision chip never clip; every label
  /// keeps its theme-surface contrast in both light and dark themes.
  Widget _horizontalCard(ThemeData theme, ColorScheme cs, bool dark,
      CandidateEntry entry, SubmissionReviewModel model) {
    return GestureDetector(
      onTap: widget.onOpen,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.selected ? HubTheme.gold : cs.outlineVariant,
            width: widget.selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(dark ? 0.25 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 96,
                    height: 96,
                    child: HeadshotAvatar(
                      file: entry.headshot,
                      name: entry.name,
                      circle: false,
                      radius: 0,
                      size: 96,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _SelectButton(
                  selected: widget.selected,
                  onTap: widget.onToggleSelect,
                  large: true,
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          entry.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (entry.isYoungDem) ...[
                        const SizedBox(width: 5),
                        const Tooltip(
                          message: 'Young Dem',
                          child: Icon(Icons.workspace_premium,
                              size: 15, color: HubTheme.gold),
                        ),
                      ],
                    ],
                  ),
                  if (entry.officeLine.isNotEmpty)
                    Text(
                      entry.officeLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _StatusChip(status: entry.submission.status),
                      if (model.alignmentPct != null)
                        AlignmentBadge(pct: model.alignmentPct!, dense: true),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _StanceStrip(entry: entry),
                  if (entry.flags.any) ...[
                    const SizedBox(height: 8),
                    _FlagChips(flags: entry.flags),
                  ],
                  if (widget.decisionChip != null) ...[
                    const SizedBox(height: 8),
                    widget.decisionChip!,
                  ],
                ],
              ),
            ),
          ],
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
                for (var i = 0; i < segs.length; i++)
                  Expanded(
                    flex: segs[i].$2,
                    child: Container(
                      margin:
                          EdgeInsets.only(right: i == segs.length - 1 ? 0 : 1),
                      color: segs[i].$1,
                    ),
                  ),
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
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
        color: HubTheme.navy.withOpacity(0.85),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}

class _SelectButton extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;

  /// Touch-friendly sizing for the phone list layout (bigger padding +
  /// glyphs, so the tap target reaches finger size).
  final bool large;

  const _SelectButton(
      {required this.selected, required this.onTap, this.large = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: EdgeInsets.symmetric(
              horizontal: large ? 12 : 9, vertical: large ? 10 : 5),
          decoration: BoxDecoration(
            color: selected ? HubTheme.gold : HubTheme.navy.withOpacity(0.92),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? HubTheme.gold : Colors.white24,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? Icons.check_circle : Icons.add_circle_outline,
                size: large ? 17 : 15,
                color: selected ? HubTheme.navy : Colors.white,
              ),
              const SizedBox(width: 4),
              Text(
                selected ? 'Added' : 'Compare',
                style: TextStyle(
                  color: selected ? HubTheme.navy : Colors.white,
                  fontSize: large ? 12 : 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
