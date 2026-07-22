// ═══════════════════════════════════════════════════════════════
//  ENDORSEMENT QUESTIONNAIRE SECTION
//  Renders a candidate's response to the 2026 endorsement questionnaire
//  inside the Intel tab of CandidateDetailScreen.
//
//  Data source: public.candidate_endorsement_responses view
//  (see supabase/migrations/20260422000000_endorsement_questionnaire_link.sql)
//  plus the form schema (public.form_schemas) so codes resolve to option
//  labels via SubmissionReviewModel — the SAME model the full results page
//  uses, so the two surfaces never drift.
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/features/forms/models/form_schema.dart';
import 'package:bluebubbles/features/forms/models/form_submission.dart';
import 'package:bluebubbles/features/forms/models/submission_review_model.dart';
import 'package:bluebubbles/features/forms/screens/endorsement_hub/ai_score_repository.dart';
import 'package:bluebubbles/features/forms/widgets/submission_detail/submission_review_body.dart';

class EndorsementQuestionnaireSection extends StatefulWidget {
  final String candidateId;

  const EndorsementQuestionnaireSection({
    super.key,
    required this.candidateId,
  });

  @override
  State<EndorsementQuestionnaireSection> createState() =>
      _EndorsementQuestionnaireSectionState();
}

class _EndorsementQuestionnaireSectionState
    extends State<EndorsementQuestionnaireSection> {
  FormSchema? _form;
  FormSubmission? _submission;
  AiAlignmentScore? _ai;
  bool _loading = true;
  bool _hasResponse = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final client = Supabase.instance.client;
      final rows = await client
          .from('candidate_endorsement_responses')
          .select()
          .eq('candidate_id', widget.candidateId)
          .order('submitted_at', ascending: false)
          .limit(1);

      if (rows.isEmpty) {
        setState(() {
          _hasResponse = false;
          _loading = false;
        });
        return;
      }

      final row = rows.first;
      final responses =
          (row['responses'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      final slug = row['form_slug']?.toString() ?? 'endorsement-questionnaire-2026';

      final schemaRows = await client
          .from('form_schemas')
          .select()
          .eq('slug', slug)
          .limit(1);

      FormSchema? form;
      if (schemaRows.isNotEmpty) {
        form = FormSchema.fromJson(schemaRows.first);
      }

      final submittedAt = DateTime.tryParse(row['submitted_at']?.toString() ?? '');
      final submission = FormSubmission(
        id: row['submission_id']?.toString() ?? '',
        createdAt: submittedAt ?? DateTime.now(),
        formId: form?.id ?? '',
        data: responses,
        submitterName: row['submitter_name']?.toString(),
        submitterEmail: row['submitter_email']?.toString(),
        submitterPhone: row['submitter_phone']?.toString(),
        candidateId: row['candidate_id']?.toString(),
        status: row['status']?.toString() ?? 'submitted',
      );

      // Gemini verdict for the inline review; degrades to null gracefully.
      AiAlignmentScore? ai;
      if (submission.id.isNotEmpty) {
        ai = await EndorsementAiScoreRepository().loadOne(submission.id);
      }

      setState(() {
        _hasResponse = true;
        _form = form;
        _submission = submission;
        _ai = ai;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return _card(
        child: Text('Error loading response: $_error',
            style: const TextStyle(color: Colors.redAccent)),
      );
    }

    if (!_hasResponse || _form == null || _submission == null) {
      return _emptyCard();
    }

    // The full redesigned review, inline: verdict block (with disqualifiers)
    // plus every questionnaire section. Same widget as the standalone
    // Candidate Review screen so the two surfaces never drift.
    return SubmissionReviewBody(
      form: _form!,
      submission: _submission!,
      aiAlignment: _ai,
      showHero: false,
    );
  }

  Widget _emptyCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.description_outlined,
                  color: BrandColors.sunriseGold, size: 22),
              SizedBox(width: 10),
              Text('Endorsement Questionnaire',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  )),
            ],
          ),
          const SizedBox(height: 12),
          const Text('No response submitted yet.',
              style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () async {
              final link =
                  'https://forms.moyoungdemocrats.org/endorsement-questionnaire-2026?candidate_id=${widget.candidateId}';
              await Clipboard.setData(ClipboardData(text: link));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Copied: $link'),
                  duration: const Duration(seconds: 3),
                ),
              );
            },
            icon: const Icon(Icons.link, size: 16),
            label: const Text('Copy candidate-specific link'),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BrandColors.unityBlue.withOpacity(0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: child,
    );
  }

}
