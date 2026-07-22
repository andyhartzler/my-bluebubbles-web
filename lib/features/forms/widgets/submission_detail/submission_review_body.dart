import 'package:flutter/material.dart';

import '../../models/form_schema.dart';
import '../../models/form_submission.dart';
import '../../models/submission_review_model.dart';
import 'candidate_hero_header.dart';
import 'documents_card.dart';
import 'policy_positions_grid.dart';
import 'references_card.dart';
import 'section_card.dart';
import 'verdict_block.dart';

/// The candidate-review content, shared between [SubmissionDetailScreen] and
/// the Questionnaire tab on `CandidateDetailScreen` so both surfaces render
/// the identical redesigned review: verdict block first, then the
/// questionnaire sections flowed into two columns on wide screens.
///
/// A plain Column (no scroll view of its own) so hosts can embed it in
/// whatever scrolling context they already have.
class SubmissionReviewBody extends StatelessWidget {
  final FormSchema form;
  final FormSubmission submission;
  final AiAlignmentScore? aiAlignment;

  /// Show the MOYD hero header. The candidate-profile tab hides it (the
  /// profile already renders the candidate's identity above the tabs).
  final bool showHero;

  final VoidCallback? onOpenLinkedProfile;
  final String? linkedProfileLabel;

  const SubmissionReviewBody({
    super.key,
    required this.form,
    required this.submission,
    this.aiAlignment,
    this.showHero = true,
    this.onOpenLinkedProfile,
    this.linkedProfileLabel,
  });

  @override
  Widget build(BuildContext context) {
    final model =
        SubmissionReviewModel.from(form, submission, aiAlignment: aiAlignment);

    final sectionCards = <Widget>[
      for (final section in model.sections)
        SectionCard(
          section: section,
          leading: section.isPolicyGrid
              ? PolicyPositionsGrid(positions: section.policyPositions)
              : null,
        ),
    ];
    final tailCards = <Widget>[
      if (model.hasDocuments) DocumentsCard(model: model),
      if (model.references.isNotEmpty)
        ReferencesCard(references: model.references),
      ReviewMetadataTile(submission: submission, form: form),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHero)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: CandidateHeroHeader(
              model: model,
              status: submission.status,
              onOpenLinkedProfile: onOpenLinkedProfile,
              linkedProfileLabel: linkedProfileLabel,
            ),
          ),
        if (model.aiAlignment != null)
          VerdictBlock(ai: model.aiAlignment!, rulePct: model.ruleAlignmentPct),
        _SectionsFlow(cards: [...sectionCards, ...tailCards]),
      ],
    );
  }
}

/// Flows review cards into two balanced columns when the host is wide enough
/// to hold them at a readable measure; single column otherwise. Cards are
/// dealt greedily left/right by order so the reading sequence stays roughly
/// top-to-bottom.
class _SectionsFlow extends StatelessWidget {
  final List<Widget> cards;
  const _SectionsFlow({required this.cards});

  static const double _twoColumnMin = 980;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < _twoColumnMin || cards.length < 2) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: cards,
          );
        }
        final left = <Widget>[];
        final right = <Widget>[];
        for (var i = 0; i < cards.length; i++) {
          (i.isEven ? left : right).add(cards[i]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Column(children: left)),
            const SizedBox(width: 16),
            Expanded(child: Column(children: right)),
          ],
        );
      },
    );
  }
}

/// Collapsed submission-metadata tile (moved out of the detail screen so the
/// embedded review shows the same provenance).
class ReviewMetadataTile extends StatelessWidget {
  final FormSubmission submission;
  final FormSchema form;

  const ReviewMetadataTile({
    super.key,
    required this.submission,
    required this.form,
  });

  String _fmt(DateTime d) =>
      '${d.month}/${d.day}/${d.year} at ${d.hour}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 120,
                child: Text(label,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant)),
              ),
              Expanded(
                child: SelectableText(value,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        );

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(Icons.info_outline, color: cs.onSurfaceVariant),
          title: Text('Submission info',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            row('Submission ID', submission.id),
            row('Form ID', submission.formId),
            if (submission.memberId != null)
              row('Member ID', submission.memberId!),
            if (submission.candidateId != null)
              row('Candidate ID', submission.candidateId!),
            row('Submitted at', _fmt(submission.createdAt)),
            row('Status', submission.status),
          ],
        ),
      ),
    );
  }
}
