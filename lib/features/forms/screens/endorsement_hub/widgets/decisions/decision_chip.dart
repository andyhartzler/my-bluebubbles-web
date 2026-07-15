import 'package:flutter/material.dart';

import '../../../../theme/moyd_brand.dart';
import 'decision_repository.dart';

/// Visual mapping for a [DecisionState] — reused on roster cards, the kanban
/// tiles and the side panel. Self-contained light-bg / dark-fg pairs so it
/// stays legible in both themes.
///
/// Interview gets its own blue pair (rather than reusing the amber "qualified"
/// stance pair) so the four decision states read as four distinct colors:
/// endorse green, interview blue, decline red, undecided slate. Every fg is
/// >= 4.5:1 on its bg AND on white; every fg also carries white text at
/// >= 4.5:1 when used as a solid accent fill.
class DecisionVisuals {
  const DecisionVisuals._();

  /// Interview blue (dark fg / light bg), checked against WCAG AA.
  static const Color _interviewFg = Color(0xFF135E96);
  static const Color _interviewBg = Color(0xFFE1F0FB);

  static IconData icon(DecisionState s) => switch (s) {
        DecisionState.endorse => Icons.verified,
        DecisionState.interview => Icons.record_voice_over,
        DecisionState.decline => Icons.block,
        DecisionState.undecided => Icons.help_outline,
      };

  static Color fg(DecisionState s) => switch (s) {
        DecisionState.endorse => MoydBrand.supportFg,
        DecisionState.interview => _interviewFg,
        DecisionState.decline => MoydBrand.opposeFg,
        DecisionState.undecided => MoydBrand.neutralFg,
      };

  static Color bg(DecisionState s) => switch (s) {
        DecisionState.endorse => MoydBrand.supportBg,
        DecisionState.interview => _interviewBg,
        DecisionState.decline => MoydBrand.opposeBg,
        DecisionState.undecided => MoydBrand.neutralBg,
      };

  /// Solid accent for filled controls (selected pills, count badges, dots).
  /// White text/icons on any of these are >= 4.5:1.
  static Color accent(DecisionState s) => fg(s);

  /// One-line meaning of the state, used as a caption in the decision panel.
  static String hint(DecisionState s) => switch (s) {
        DecisionState.endorse => 'Recommend for the MOYD endorsement slate.',
        DecisionState.interview => 'Bring in for a committee interview first.',
        DecisionState.decline => 'Pass on endorsing this cycle.',
        DecisionState.undecided => 'No committee call yet.',
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
        border: Border.all(color: fg.withOpacity(0.22)),
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
