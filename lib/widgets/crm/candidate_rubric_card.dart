// Candidate Rubric Card — replacement for the legacy "Young Democrat
// Score" checklist + radar painter.
//
// Reads `public.candidate_score_components` (10 rows per candidate, one
// per category). Each row carries `is_auto` flag + optional manual
// override. Auto categories show a lock icon + tooltip explaining their
// inputs from `source_data` jsonb. Manual categories surface a stepper
// for executives to dial 0–10.
//
// Total /100 displayed at top — equals the cached
// `candidates.young_dem_score` int (which the recompute_candidate_score
// SQL function maintains via trigger).
//
// Permission: stepper enabled iff the current user is on the exec
// committee (`members.executive_committee = true`).

import 'package:flutter/material.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

/// Display-friendly category metadata. The `key` matches the
/// `candidate_score_components.category` value written by
/// `recompute_candidate_score`.
class _RubricCategory {
  final String key;
  final String label;
  final String description;
  final IconData icon;
  const _RubricCategory(this.key, this.label, this.description, this.icon);
}

const List<_RubricCategory> _categories = [
  _RubricCategory(
    'democratic_affiliation',
    'Democratic Affiliation',
    'Party registration + party_confidence on the candidate row.',
    Icons.flag_outlined,
  ),
  _RubricCategory(
    'filed_for_office',
    'Filed for Office',
    'Filing status (filed / pending / withdrew).',
    Icons.description_outlined,
  ),
  _RubricCategory(
    'incumbent_or_prior_office',
    'Incumbent / Prior Office',
    'Incumbent flag, legislator linkage, or election_history records.',
    Icons.account_balance_outlined,
  ),
  _RubricCategory(
    'primary_voting_record',
    'Primary Voting Record',
    'Primaries voted in the last 4 cycles, from the MO voter file.',
    Icons.how_to_vote_outlined,
  ),
  _RubricCategory(
    'general_voting_record',
    'General Voting Record',
    'General elections voted in the last 4 cycles.',
    Icons.how_to_vote,
  ),
  _RubricCategory(
    'voter_registration_tenure',
    'Voter Registration Tenure',
    'Years since the candidate first registered to vote in MO.',
    Icons.event_available_outlined,
  ),
  _RubricCategory(
    'fundraising_threshold',
    'Fundraising Threshold',
    'Total raised across linked MEC committees, banded.',
    Icons.attach_money,
  ),
  _RubricCategory(
    'fundraising_velocity',
    'Fundraising Velocity',
    'Donor breadth — number of contributions, banded.',
    Icons.bolt_outlined,
  ),
  _RubricCategory(
    'moyd_membership',
    'MOYD Membership',
    'Linked to a Missouri Young Democrats member record.',
    Icons.card_membership_outlined,
  ),
  _RubricCategory(
    'age_eligibility',
    'Age Eligibility',
    'Estimated age fits the Young Democrats brackets (14–36).',
    Icons.cake_outlined,
  ),
];

class CandidateRubricCard extends StatefulWidget {
  final String candidateId;
  const CandidateRubricCard({super.key, required this.candidateId});

  @override
  State<CandidateRubricCard> createState() => _CandidateRubricCardState();
}

class _CandidateRubricCardState extends State<CandidateRubricCard> {
  final _supabase = CRMSupabaseService();
  Map<String, Map<String, dynamic>> _byCategory = {};
  bool _loading = true;
  bool _isExec = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!_supabase.isInitialized) return;
    try {
      final rows = await _supabase.client
          .from('candidate_score_components')
          .select()
          .eq('candidate_id', widget.candidateId);
      final list = (rows as List).cast<Map<String, dynamic>>();
      final mapped = <String, Map<String, dynamic>>{};
      for (final row in list) {
        mapped[row['category'] as String] = row;
      }

      // Best-effort exec-membership check. RLS already gates writes;
      // this just controls the stepper enablement so non-execs see a
      // read-only view.
      final userId = _supabase.client.auth.currentUser?.id;
      var isExec = false;
      if (userId != null) {
        final m = await _supabase.client
            .from('members')
            .select('executive_committee')
            .eq('id', userId)
            .maybeSingle();
        isExec = m != null && m['executive_committee'] == true;
      }

      if (!mounted) return;
      setState(() {
        _byCategory = mapped;
        _isExec = isExec;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _total {
    return _byCategory.values.fold<int>(
      0,
      (sum, row) => sum + ((row['score'] as num?)?.toInt() ?? 0),
    );
  }

  Future<void> _override(String category, int newScore) async {
    if (!_isExec) return;
    final userId = _supabase.client.auth.currentUser?.id;
    final existing = _byCategory[category];
    if (existing == null) return;
    try {
      // The RLS write policy gates non-exec users; if it fails we silently
      // revert the optimistic UI write below.
      await _supabase.client.from('candidate_score_components').update({
        'score': newScore,
        'is_auto': false,
        'scored_by': userId,
      }).eq('candidate_id', widget.candidateId).eq('category', category);
      if (!mounted) return;
      setState(() {
        existing['score'] = newScore;
        existing['is_auto'] = false;
      });
    } catch (_) {
      // Revert on failure — no-op since we didn't update local state yet.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: CircularProgressIndicator(
            color: BrandColors.sunriseGold, strokeWidth: 2,
          ),
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTotalHeader(),
          const SizedBox(height: 16),
          ..._categories.map(_buildRow),
        ],
      ),
    );
  }

  Widget _buildTotalHeader() {
    final t = _total;
    final color = t >= 70
        ? BrandColors.democratBlue
        : t >= 40
            ? BrandColors.sunriseGold
            : Colors.redAccent;
    return Row(
      children: [
        const Icon(Icons.bar_chart, color: BrandColors.sunriseGold, size: 22),
        const SizedBox(width: 10),
        const Text('Candidate Rubric',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            )),
        const Spacer(),
        Text('$t', style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.w900, fontFeatures: const [FontFeature.tabularFigures()])),
        const SizedBox(width: 4),
        Text('/100', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14)),
      ],
    );
  }

  Widget _buildRow(_RubricCategory cat) {
    final row = _byCategory[cat.key];
    final score = (row?['score'] as num?)?.toInt() ?? 0;
    final isAuto = row?['is_auto'] == true;
    final scoreColor = score >= 8
        ? BrandColors.democratBlue
        : score >= 5
            ? BrandColors.sunriseGold
            : Colors.white.withOpacity(0.4);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(cat.icon, size: 16, color: Colors.white.withOpacity(0.6)),
          const SizedBox(width: 10),
          Expanded(
            child: Tooltip(
              message: cat.description,
              child: Text(
                cat.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          if (isAuto)
            Tooltip(
              message: 'Auto-computed. Click the score to override.',
              child: Icon(Icons.auto_awesome,
                  size: 12, color: Colors.white.withOpacity(0.35)),
            ),
          const SizedBox(width: 8),
          if (_isExec)
            _StepperBadge(
              score: score,
              color: scoreColor,
              onTap: () => _showStepperSheet(cat, score),
            )
          else
            _ReadonlyBadge(score: score, color: scoreColor),
        ],
      ),
    );
  }

  Future<void> _showStepperSheet(_RubricCategory cat, int currentScore) async {
    final newScore = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: const Color(0xFF0B1E37),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        var local = currentScore;
        return StatefulBuilder(builder: (ctx, setSheetState) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(cat.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    )),
                const SizedBox(height: 6),
                Text(cat.description,
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton.filled(
                      onPressed: local > 0
                          ? () => setSheetState(() => local--)
                          : null,
                      icon: const Icon(Icons.remove),
                    ),
                    const SizedBox(width: 24),
                    Text('$local',
                        style: const TextStyle(
                          color: BrandColors.sunriseGold,
                          fontSize: 56,
                          fontWeight: FontWeight.w900,
                        )),
                    const SizedBox(width: 24),
                    IconButton.filled(
                      onPressed: local < 10
                          ? () => setSheetState(() => local++)
                          : null,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(ctx).pop(null),
                        child: const Text('Cancel',
                            style: TextStyle(color: Colors.white70)),
                      ),
                    ),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: BrandColors.sunriseGold,
                          foregroundColor: BrandColors.unityBlue,
                        ),
                        onPressed: () => Navigator.of(ctx).pop(local),
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        });
      },
    );
    if (newScore != null && newScore != currentScore) {
      await _override(cat.key, newScore);
    }
  }
}

class _StepperBadge extends StatelessWidget {
  final int score;
  final Color color;
  final VoidCallback onTap;
  const _StepperBadge({
    required this.score,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.18),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text('$score',
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            )),
      ),
    );
  }
}

class _ReadonlyBadge extends StatelessWidget {
  final int score;
  final Color color;
  const _ReadonlyBadge({required this.score, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$score',
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          )),
    );
  }
}
