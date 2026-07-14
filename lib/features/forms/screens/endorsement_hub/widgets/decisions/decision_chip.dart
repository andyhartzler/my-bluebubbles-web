import 'package:flutter/material.dart';

import '../../../../theme/moyd_brand.dart';
import 'decision_repository.dart';

/// Visual mapping for a [DecisionState] — reused on roster cards, the kanban
/// tiles and the side panel. Self-contained light-bg / dark-fg pairs so it
/// stays legible in both themes.
class DecisionVisuals {
  const DecisionVisuals._();

  static IconData icon(DecisionState s) => switch (s) {
        DecisionState.endorse => Icons.verified,
        DecisionState.interview => Icons.record_voice_over,
        DecisionState.decline => Icons.block,
        DecisionState.undecided => Icons.help_outline,
      };

  static Color fg(DecisionState s) => switch (s) {
        DecisionState.endorse => MoydBrand.supportFg,
        DecisionState.interview => MoydBrand.qualifiedFg,
        DecisionState.decline => MoydBrand.opposeFg,
        DecisionState.undecided => MoydBrand.neutralFg,
      };

  static Color bg(DecisionState s) => switch (s) {
        DecisionState.endorse => MoydBrand.supportBg,
        DecisionState.interview => MoydBrand.qualifiedBg,
        DecisionState.decline => MoydBrand.opposeBg,
        DecisionState.undecided => MoydBrand.neutralBg,
      };
}

/// A small self-contained pill for a candidate's endorsement decision.
class DecisionChip extends StatelessWidget {
  final DecisionState state;
  final bool compact;
  const DecisionChip({super.key, required this.state, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final fg = DecisionVisuals.fg(state);
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 7 : 9, vertical: compact ? 2 : 4),
      decoration: BoxDecoration(
        color: DecisionVisuals.bg(state),
        borderRadius: BorderRadius.circular(compact ? 6 : 8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(DecisionVisuals.icon(state), size: compact ? 13 : 15, color: fg),
          const SizedBox(width: 4),
          Text(state.label,
              style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w700,
                  fontSize: compact ? 11 : 12.5)),
        ],
      ),
    );
  }
}
