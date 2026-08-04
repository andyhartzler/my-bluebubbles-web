// ═══════════════════════════════════════════════════════════════
//  ENDORSEMENT QUESTIONNAIRE SECTION
//  A candidate's 2026 endorsement questionnaire, as the Questionnaire tab of
//  CandidateDetailScreen renders it. Top to bottom: who on the executive
//  committee voted and how, then the full Gemini verdict, then the answers.
//
//  Data sources:
//    public.candidate_endorsement_responses  (the submission + responses)
//    public.form_schemas                     (so codes resolve to labels)
//    public.endorsement_ai_scores            (+ _history)
//    public.endorsement_votes                (via EndorsementVoteRepository)
//
//  The submission and schema go through SubmissionReviewModel, the SAME model
//  the standalone review screen uses, so the two surfaces never drift.
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bluebubbles/features/forms/models/form_schema.dart';
import 'package:bluebubbles/features/forms/models/form_submission.dart';
import 'package:bluebubbles/features/forms/models/submission_review_model.dart';
import 'package:bluebubbles/features/forms/screens/endorsement_hub/ai_score_repository.dart';
import 'package:bluebubbles/features/forms/screens/endorsement_hub/widgets/decisions/endorsement_vote_repository.dart';
import 'package:bluebubbles/features/forms/theme/moyd_brand.dart';
import 'package:bluebubbles/features/forms/widgets/submission_detail/exec_ballot_block.dart';
import 'package:bluebubbles/features/forms/widgets/submission_detail/review_text.dart';
import 'package:bluebubbles/features/forms/widgets/submission_detail/submission_review_body.dart';

class EndorsementQuestionnaireSection extends StatefulWidget {
  final String candidateId;

  const EndorsementQuestionnaireSection({
    super.key,
    required this.candidateId,
  });

  @override
  State<EndorsementQuestionnaireSection> createState() =>
      EndorsementQuestionnaireSectionState();
}

/// Public so `CandidateDetailScreen` can hold a [GlobalKey] to it and make
/// pull-to-refresh actually re-fetch this tab instead of resolving a fake
/// 250ms delay.
class EndorsementQuestionnaireSectionState
    extends State<EndorsementQuestionnaireSection> {
  /// One vote repository per mounted section. It fetches every ballot on the
  /// table in bounded pages and keeps a realtime subscription, so an exec
  /// voting from the hub while this page is open updates it live.
  final EndorsementVoteRepository _votes = EndorsementVoteRepository();

  FormSchema? _form;
  FormSubmission? _submission;
  AiAlignmentScore? _ai;
  List<AiScoreHistoryEntry> _aiHistory = const [];
  bool _loading = true;
  bool _hasResponse = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _votes.load();
    _load();
  }

  @override
  void dispose() {
    _votes.dispose();
    super.dispose();
  }

  /// Re-run every fetch behind this tab. Wired to the screen's
  /// RefreshIndicator.
  ///
  /// Deliberately does NOT flip back to the skeleton: the content already on
  /// screen stays put and is swapped when the new data lands. A pull that
  /// blanks the page it is refreshing reads as a failure.
  Future<void> reload() async {
    await Future.wait([_load(), _votes.refresh()]);
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
        if (!mounted) return;
        setState(() {
          _hasResponse = false;
          _error = null;
          _loading = false;
        });
        return;
      }

      final row = rows.first;
      final responses =
          (row['responses'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      // The live form is `endorsement-questionnaire-2026`. The old fallback
      // was the un-suffixed slug, which matches no row in form_schemas, so
      // any submission with a null form_slug silently lost its schema and
      // rendered every stored code raw instead of its option label.
      final slug =
          row['form_slug']?.toString() ?? 'endorsement-questionnaire-2026';

      final schemaRows =
          await client.from('form_schemas').select().eq('slug', slug).limit(1);

      FormSchema? form;
      if (schemaRows.isNotEmpty) {
        form = FormSchema.fromJson(schemaRows.first);
      }

      final submittedAt =
          DateTime.tryParse(row['submitted_at']?.toString() ?? '');
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

      // Gemini verdict plus every superseded run; both degrade to null/empty.
      AiAlignmentScore? ai;
      var history = const <AiScoreHistoryEntry>[];
      if (submission.id.isNotEmpty) {
        final repo = EndorsementAiScoreRepository();
        final results = await Future.wait([
          repo.loadOne(submission.id),
          repo.loadHistory(submission.id),
        ]);
        ai = results[0] as AiAlignmentScore?;
        history = results[1] as List<AiScoreHistoryEntry>;
      }

      if (!mounted) return;
      setState(() {
        _hasResponse = true;
        _form = form;
        _submission = submission;
        _ai = ai;
        _aiHistory = history;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const _LoadingSkeleton();
    if (_error != null) return _errorCard(context);
    if (!_hasResponse || _form == null || _submission == null) {
      return _emptyCard(context);
    }

    final submission = _submission!;

    return SubmissionReviewBody(
      form: _form!,
      submission: submission,
      aiAlignment: _ai,
      aiHistory: _aiHistory,
      showHero: false,
      // THE KEY TRAP: endorsement_votes.candidate_id holds the SUBMISSION id
      // as text, not candidates.id. Passing widget.candidateId here would
      // return an empty ballot with no error and render a board on which
      // nobody voted.
      leading: submission.id.isEmpty
          ? null
          : ExecBallotBlock(votes: _votes, submissionId: submission.id),
    );
  }

  // ── states ───────────────────────────────────────────────────────────────

  Widget _errorCard(BuildContext context) {
    return ReviewCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: MoydBrand.opposeBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline,
                    size: 20, color: MoydBrand.opposeFg),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Could not load the questionnaire.',
                    style: ReviewText.bodyStrong(context)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Something failed while fetching this candidate's submission. "
            'Try again.',
            style: ReviewText.secondary(context),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: () {
                setState(() {
                  _loading = true;
                  _error = null;
                });
                _load();
              },
              child: const Text('Retry'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ReviewCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assignment_outlined,
                  size: 20, color: cs.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Text('No questionnaire on file',
                    style: ReviewText.bodyStrong(context)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'This candidate has not submitted the 2026 endorsement '
            'questionnaire.',
            style: ReviewText.secondary(context),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () async {
                final link =
                    'https://moyoungdemocrats.org/forms/endorsement-questionnaire'
                    '?candidate_id=${widget.candidateId}';
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
          ),
        ],
      ),
    );
  }
}

/// Three cards' worth of solid placeholder blocks: ballot, verdict, section.
/// Shaped like what is coming so the page does not jump when it lands.
class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget card(List<Widget> children) => ReviewCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        card(const [
          ReviewSkeletonBar(width: 140, height: 12),
          SizedBox(height: 16),
          ReviewSkeletonBar(height: 10),
          SizedBox(height: 10),
          ReviewSkeletonBar(height: 10),
        ]),
        card(const [
          Row(
            children: [
              ReviewSkeletonBar(width: 64, height: 64, circle: true),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ReviewSkeletonBar(width: 120, height: 12),
                    SizedBox(height: 10),
                    ReviewSkeletonBar(height: 10),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          ReviewSkeletonBar(height: 10),
        ]),
        card(const [
          ReviewSkeletonBar(width: 160, height: 12),
          SizedBox(height: 16),
          ReviewSkeletonBar(height: 10),
          SizedBox(height: 10),
          ReviewSkeletonBar(height: 10),
          SizedBox(height: 10),
          ReviewSkeletonBar(width: 220, height: 10),
        ]),
      ],
    );
  }
}
