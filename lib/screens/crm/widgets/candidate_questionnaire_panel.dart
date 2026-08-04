import 'package:flutter/material.dart';
import 'package:bluebubbles/screens/crm/widgets/endorsement_questionnaire_section.dart';

/// Tab body for the Questionnaire tab on `CandidateDetailScreen`. Wraps
/// [EndorsementQuestionnaireSection] in a padded [ListView] so the tab content
/// scrolls and matches the other detail tabs' layout.
///
/// Uses `AlwaysScrollableScrollPhysics` so the parent RefreshIndicator on
/// `CandidateDetailScreen` fires even when the response is short enough to fit
/// without scrolling.
class CandidateQuestionnairePanel extends StatelessWidget {
  final String candidateId;

  /// Lets the screen reach the section's state and re-fetch it on pull to
  /// refresh.
  final Key? sectionKey;

  const CandidateQuestionnairePanel({
    super.key,
    required this.candidateId,
    this.sectionKey,
  });

  /// Readable measure. The review body flows its section cards into two
  /// columns from 980px, so the cap sits just above that rather than letting
  /// the columns stretch across an ultrawide monitor.
  static const double _maxContentWidth = 1100;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;
    // 16 on phones, 20 from 600 up. The cards carry a 20px internal gutter of
    // their own, so anything larger here just eats content width.
    final side = isMobile ? 16.0 : 20.0;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        side,
        side,
        side,
        // Extra bottom padding on mobile so the FAB speed-dial does not
        // overlap the last card.
        isMobile ? 96 : 40,
      ),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxContentWidth),
            child: EndorsementQuestionnaireSection(
              key: sectionKey,
              candidateId: candidateId,
            ),
          ),
        ),
      ],
    );
  }
}
