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
import 'package:bluebubbles/features/forms/screens/submission_detail_screen.dart';
import 'package:bluebubbles/features/forms/theme/moyd_brand.dart';

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
  SubmissionReviewModel? _model;
  FormSchema? _form;
  FormSubmission? _submission;
  DateTime? _submittedAt;
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

      setState(() {
        _hasResponse = true;
        _form = form;
        _submission = submission;
        _submittedAt = submittedAt;
        _model = form != null
            ? SubmissionReviewModel.from(form, submission)
            : null;
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

    if (!_hasResponse || _model == null) {
      return _emptyCard();
    }

    return _card(child: _reviewSummary(_model!));
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

  Widget _reviewSummary(SubmissionReviewModel m) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF4ADE80), size: 22),
            const SizedBox(width: 10),
            const Text('Endorsement Questionnaire',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                )),
            const Spacer(),
            if (_submittedAt != null)
              Text(_formatDate(_submittedAt!),
                  style: const TextStyle(color: Colors.white60, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 14),
        _chips(m),
        if (m.allPolicyPositions.isNotEmpty) ...[
          const SizedBox(height: 14),
          _stanceStrip(m),
        ],
        if (m.topPriority != null && m.topPriority!.trim().isNotEmpty) ...[
          const SizedBox(height: 14),
          _topPriorityQuote(m.topPriority!.trim()),
        ],
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: MoydBrand.gold,
              foregroundColor: const Color(0xFF1A1200),
            ),
            onPressed: (_form != null && _submission != null)
                ? () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SubmissionDetailScreen(
                          submission: _submission,
                          form: _form,
                        ),
                      ),
                    );
                  }
                : null,
            icon: const Icon(Icons.open_in_full, size: 16),
            label: const Text('Open full review'),
          ),
        ),
      ],
    );
  }

  Widget _chips(SubmissionReviewModel m) {
    final chips = <Widget>[];
    void add(String label, String? value, {bool amber = false}) {
      if (value == null || value.isEmpty) return;
      final base = amber ? MoydBrand.amber : BrandColors.sunriseGold;
      chips.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: base.withOpacity(0.18),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: base.withOpacity(0.45)),
        ),
        child: Text('$label: $value',
            style: const TextStyle(color: Colors.white, fontSize: 12)),
      ));
    }

    final officeDistrict = [
      if (m.office != null) m.office,
      if (m.district != null) m.district,
    ].whereType<String>().join(' · ');

    add('Office', officeDistrict.isEmpty ? null : officeDistrict);
    add('Ideology', m.ideology);
    if (m.nonDemHistory) add('Party history', m.partyHistory, amber: true);
    add('Raised', m.raisedToDate == null ? null : _currency(m.raisedToDate!));
    add('Track', m.track);

    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }

  Widget _stanceStrip(SubmissionReviewModel m) {
    final t = m.stanceTally;
    final segs = <Widget>[];
    void seg(String label, int count, Color fg, Color bg) {
      if (count <= 0) return;
      segs.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('$count $label',
            style: TextStyle(
                color: fg, fontSize: 12, fontWeight: FontWeight.w700)),
      ));
    }

    seg('support', t.support, MoydBrand.supportFg, MoydBrand.supportBg);
    seg('oppose', t.oppose, MoydBrand.opposeFg, MoydBrand.opposeBg);
    seg('qualified', t.qualified, MoydBrand.qualifiedFg, MoydBrand.qualifiedBg);
    if (t.other > 0) {
      seg('other', t.other, MoydBrand.neutralFg, MoydBrand.neutralBg);
    }

    if (segs.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Positions',
            style: TextStyle(
                color: Colors.white60,
                fontSize: 11,
                letterSpacing: 0.4,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: segs),
      ],
    );
  }

  Widget _topPriorityQuote(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: const Border(
          left: BorderSide(color: MoydBrand.gold, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Would fight hardest for',
              style: TextStyle(
                  color: Colors.white60,
                  fontSize: 11,
                  letterSpacing: 0.4,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('“$text”',
              style: const TextStyle(
                  color: Colors.white, fontSize: 14, height: 1.4)),
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

  String _currency(num v) => '\$${v.toStringAsFixed(0)}';

  String _formatDate(DateTime d) => '${d.month}/${d.day}/${d.year}';
}
