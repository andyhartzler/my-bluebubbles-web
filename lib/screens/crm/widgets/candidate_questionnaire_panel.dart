import 'package:flutter/material.dart';
import 'package:bluebubbles/screens/crm/widgets/endorsement_questionnaire_section.dart';

/// Tab body for the Questionnaire tab on `CandidateDetailScreen`. Wraps the
/// existing [EndorsementQuestionnaireSection] in a padded [ListView] so the
/// tab content scrolls and matches the other detail tabs' layout.
///
/// Uses `AlwaysScrollableScrollPhysics` so the parent RefreshIndicator
/// on `CandidateDetailScreen` fires even when the response is short
/// enough to fit without scrolling.
class CandidateQuestionnairePanel extends StatelessWidget {
  final String candidateId;

  const CandidateQuestionnairePanel({super.key, required this.candidateId});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      // Tighter horizontal padding on mobile — the response card
      // already has its own 16px internal padding; doubling that on
      // narrow screens wastes content width.
      padding: EdgeInsets.fromLTRB(
        isMobile ? 12 : 16,
        isMobile ? 12 : 16,
        isMobile ? 12 : 16,
        // Extra bottom padding on mobile so the FAB speed-dial doesn't
        // overlap the last response entry.
        isMobile ? 96 : 40,
      ),
      children: [
        EndorsementQuestionnaireSection(candidateId: candidateId),
      ],
    );
  }
}
