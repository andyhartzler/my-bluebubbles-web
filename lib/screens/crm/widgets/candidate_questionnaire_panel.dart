import 'package:flutter/material.dart';
import 'package:bluebubbles/screens/crm/widgets/endorsement_questionnaire_section.dart';

/// Tab body for the Questionnaire tab on `CandidateDetailScreen`. Wraps the
/// existing [EndorsementQuestionnaireSection] in a padded [ListView] so the
/// tab content scrolls and matches the other detail tabs' layout.
class CandidateQuestionnairePanel extends StatelessWidget {
  final String candidateId;

  const CandidateQuestionnairePanel({super.key, required this.candidateId});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        EndorsementQuestionnaireSection(candidateId: candidateId),
      ],
    );
  }
}
