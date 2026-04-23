// ═══════════════════════════════════════════════════════════════
//  ENDORSEMENT QUESTIONNAIRE SECTION
//  Renders a candidate's response to the 2026 endorsement questionnaire
//  inside the Intel tab of CandidateDetailScreen.
//
//  Status: PROPOSED — wire up in candidate_detail_screen.dart by calling
//  EndorsementQuestionnaireSection(candidateId: c.id) inside the Intel tab
//  (suggested: a new 4th segment "Endorsement" or inline at the top of
//  the existing "MOYD" segment).
//
//  Data source: public.candidate_endorsement_responses view
//  (see supabase/migrations/20260422000000_endorsement_questionnaire_link.sql)
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bluebubbles/features/committees/theme/brand_colors.dart';

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
  Map<String, dynamic>? _response;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await Supabase.instance.client
          .from('candidate_endorsement_responses')
          .select()
          .eq('candidate_id', widget.candidateId)
          .order('submitted_at', ascending: false)
          .limit(1);

      setState(() {
        _response = rows.isNotEmpty ? rows.first as Map<String, dynamic> : null;
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

    if (_response == null) {
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
            const Text(
              'No response submitted yet.',
              style: TextStyle(color: Colors.white70),
            ),
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

    final responses = (_response!['responses'] as Map<String, dynamic>?) ?? {};
    final submittedAt = DateTime.tryParse(_response!['submitted_at'] ?? '');

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle,
                  color: Color(0xFF4ADE80), size: 22),
              const SizedBox(width: 10),
              const Text('Endorsement Questionnaire',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  )),
              const Spacer(),
              if (submittedAt != null)
                Text(
                  _formatDate(submittedAt),
                  style: const TextStyle(
                      color: Colors.white60, fontSize: 12),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _highlights(responses),
          const SizedBox(height: 16),
          _fullResponse(responses),
        ],
      ),
    );
  }

  Widget _highlights(Map<String, dynamic> r) {
    // Surface the most important fields up top as chips + key quotes
    final chips = <Widget>[];
    void addChip(String label, String? value, {Color? tint}) {
      if (value == null || value.isEmpty) return;
      chips.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: (tint ?? BrandColors.sunriseGold).withOpacity(0.18),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: (tint ?? BrandColors.sunriseGold).withOpacity(0.4)),
        ),
        child: Text(
          '$label: $value',
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ));
    }

    addChip('Race', _prettyRaceType(r['race_type']?.toString()));
    addChip('Ideology', r['ideology']?.toString());
    addChip('Party history', r['party_history']?.toString());
    addChip('M4A', r['pos_medicare_for_all']?.toString());
    addChip('Repro', r['pos_reproductive_rights']?.toString());
    addChip('Min wage', r['pos_minimum_wage']?.toString());
    addChip('Raised', _currency(r['raised_to_date']));

    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }

  Widget _fullResponse(Map<String, dynamic> r) {
    final entries = r.entries
        .where((e) => e.value != null && e.value.toString().isNotEmpty)
        .toList();

    return Theme(
      // Remove the default list-tile splash behavior so the header taps
      // cleanly on mobile without the Material ripple extending past the
      // rounded corners.
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
        splashColor: Colors.transparent,
      ),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        // Clip the expansion content so long answers don't overflow
        // horizontally past the card's rounded border on narrow screens.
        clipBehavior: Clip.antiAlias,
        title: Row(
          children: [
            const Text('Full response',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: BrandColors.sunriseGold.withOpacity(0.16),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${entries.length}',
                style: const TextStyle(
                    color: BrandColors.sunriseGold,
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        iconColor: Colors.white70,
        collapsedIconColor: Colors.white70,
        childrenPadding: const EdgeInsets.only(top: 8),
        children: entries.map((e) {
          final value = e.value.toString();
          final isLong = value.length > 180;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_humanize(e.key),
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 11,
                      letterSpacing: 0.4,
                      fontWeight: FontWeight.w600,
                    )),
                const SizedBox(height: 2),
                // Long free-text answers collapse to 3 lines by default
                // with a "Show more" toggle. Short answers render
                // inline so the reader doesn't have to tap through
                // every chip/yes-no to see its value.
                isLong
                    ? _ExpandableAnswer(text: value)
                    : Text(
                        value,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14, height: 1.4),
                      ),
              ],
            ),
          );
        }).toList(),
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

  String _humanize(String key) => key
      .replaceAll('_', ' ')
      .replaceAllMapped(RegExp(r'\b\w'), (m) => m[0]!.toUpperCase());

  String? _prettyRaceType(String? v) {
    switch (v) {
      case 'open_seat':
        return 'Open seat';
      case 'primary_incumbent_d':
        return 'Primary vs D incumbent';
      case 'challenger_to_r':
        return 'Challenger to R';
      case 'reelection':
        return 'Re-election';
      default:
        return v;
    }
  }

  String? _currency(dynamic v) {
    if (v == null) return null;
    final n = double.tryParse(v.toString());
    if (n == null) return null;
    return '\$${n.toStringAsFixed(0)}';
  }

  String _formatDate(DateTime d) =>
      '${d.month}/${d.day}/${d.year}';
}

/// Collapsible free-text answer: shows 3 lines by default with a
/// "Show more" / "Show less" toggle at the bottom. Used for long-form
/// questionnaire answers so the full response card doesn't balloon to
/// 4 screen-heights tall on mobile when the candidate writes a novel.
class _ExpandableAnswer extends StatefulWidget {
  final String text;
  const _ExpandableAnswer({required this.text});

  @override
  State<_ExpandableAnswer> createState() => _ExpandableAnswerState();
}

class _ExpandableAnswerState extends State<_ExpandableAnswer> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSize(
          duration: MediaQuery.of(context).disableAnimations
              ? Duration.zero
              : const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topLeft,
          child: Text(
            widget.text,
            style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
            maxLines: _expanded ? null : 3,
            overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            // Padding gets the tap area up to a comfortable 44×~28 — still
            // small but paired with the large adjacent text it's reliable.
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _expanded ? 'Show less' : 'Show more',
                  style: const TextStyle(
                    color: BrandColors.sunriseGold,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: BrandColors.sunriseGold,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
