// Candidate Rubric Card — replacement for the legacy "Young Democrat
// Score" checklist + radar painter.
//
// Reads `public.candidate_score_components` (10 rows per candidate, one
// per category). Each row carries `is_auto` flag + optional manual
// override. Auto categories show an "AUTO" chip + inline description
// explaining their inputs from `source_data` jsonb. Manual categories
// surface a stepper for executives to dial 0–10.
//
// Total /100 displayed at top — equals the cached
// `candidates.young_dem_score` int (which the recompute_candidate_score
// SQL function maintains via trigger).
//
// Permission: stepper enabled iff the current user is on the exec
// committee (`members.executive_committee = true`).
//
// Visual: light card-on-card on the candidate Profile gradient backdrop.
// Pure white surface, navy text, branded score chips. Designed to read
// cleanly against the teal/navy gradient that lives on the Profile tab.

import 'package:flutter/material.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

// ===================== design tokens =====================
//
// Centralized so the per-row + header styling stays in lock-step. These
// match the donor_command_center light-filter-panel + mail_screen
// light-surface palette that just shipped.
const Color _kSurface = Colors.white;
const Color _kRowSurface = Color(0xFFF6F8FB);
const Color _kBorder = Color(0xFFE5E7EB);
const Color _kNavy = Color(0xFF1A1F36);
const Color _kSlate600 = Color(0xFF475569);
const Color _kSlate500 = Color(0xFF64748B);
const Color _kSlate400 = Color(0xFF94A3B8);
const Color _kLowBg = Color(0xFFFEE2E2);
const Color _kZeroBg = Color(0xFFF3F4F6);

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
    'Donor breadth: number of contributions, banded.',
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

  /// The 10 category rows + steppers collapse by default so the Profile tab
  /// opens on the Edit CTA, member badge and Social Links without scrolling
  /// past the rubric. Exec stepper state lives in [_byCategory] on this State,
  /// so it survives collapse/expand regardless of the animation.
  bool _expanded = false;

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

  /// Color band for the total /100 chip (and the progress bar).
  /// Spec: democratBlue ≥70, sunriseGold ≥40, momentumBlue otherwise —
  /// never red. Red on a candidate scoring rubric reads as "broken".
  Color get _totalColor {
    final t = _total;
    if (t >= 70) return BrandColors.democratBlue;
    if (t >= 40) return BrandColors.sunriseGold;
    return BrandColors.momentumBlue;
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
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: _loading ? _buildLoading() : _buildContent(),
    );
  }

  Widget _buildLoading() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: CircularProgressIndicator(
          color: BrandColors.momentumBlue,
          strokeWidth: 2.5,
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_byCategory.isEmpty) {
      return _buildEmpty();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTotalHeader(),
        // Body (progress bar + 10 category rows) collapses to nothing.
        // AnimatedCrossFade keeps both children mounted, so the exec steppers
        // never lose state across a collapse/expand.
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 14),
              _buildProgressBar(),
              const SizedBox(height: 18),
              ..._categories.map(_buildRow),
            ],
          ),
          crossFadeState:
              _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 220),
          sizeCurve: Curves.easeInOut,
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kRowSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: BrandColors.sunriseGold.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.info_outline,
              color: BrandColors.sunriseGold,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Score not yet computed',
                  style: TextStyle(
                    color: _kNavy,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Run recompute_candidate_score(candidate_id) to '
                  'populate the rubric.',
                  style: TextStyle(
                    color: _kSlate500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalHeader() {
    final t = _total;
    final color = _totalColor;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.bar_chart, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Candidate Rubric',
                style: TextStyle(
                  color: _kNavy,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                '$t',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  fontFeatures: [FontFeature.tabularFigures()],
                  height: 1.1,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              '/100',
              style: TextStyle(
                color: _kSlate600,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            AnimatedRotation(
              turns: _expanded ? 0.5 : 0.0,
              duration: const Duration(milliseconds: 220),
              child: const Icon(
                Icons.expand_more,
                color: _kSlate500,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    final progress = (_total / 100).clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: progress,
        backgroundColor: _kZeroBg,
        valueColor: AlwaysStoppedAnimation<Color>(_totalColor),
        minHeight: 8,
      ),
    );
  }

  Widget _buildRow(_RubricCategory cat) {
    final row = _byCategory[cat.key];
    final score = (row?['score'] as num?)?.toInt() ?? 0;
    final isAuto = row?['is_auto'] == true;

    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _kRowSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Branded leading icon tile.
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: BrandColors.momentumBlue.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              cat.icon,
              size: 20,
              color: BrandColors.momentumBlue,
            ),
          ),
          const SizedBox(width: 12),
          // Two-line label + description (description is what was the
          // hover-only Tooltip in the legacy layout).
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  cat.label,
                  style: const TextStyle(
                    color: _kNavy,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  cat.description,
                  style: const TextStyle(
                    color: _kSlate500,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Score circle + optional AUTO chip stacked underneath.
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              _ScoreCircle(
                score: score,
                onTap: _isExec ? () => _showStepperSheet(cat, score) : null,
              ),
              if (isAuto) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _kZeroBg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'AUTO',
                    style: TextStyle(
                      color: _kSlate500,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showStepperSheet(_RubricCategory cat, int currentScore) async {
    final newScore = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: _kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        var local = currentScore;
        return StatefulBuilder(builder: (ctx, setSheetState) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Drag handle.
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _kBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  cat.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _kNavy,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  cat.description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _kSlate600,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _StepperButton(
                      icon: Icons.remove,
                      onPressed:
                          local > 0 ? () => setSheetState(() => local--) : null,
                    ),
                    const SizedBox(width: 28),
                    SizedBox(
                      width: 96,
                      child: Text(
                        '$local',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: _kNavy,
                          fontSize: 56,
                          fontWeight: FontWeight.w900,
                          fontFeatures: [FontFeature.tabularFigures()],
                          height: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 28),
                    _StepperButton(
                      icon: Icons.add,
                      onPressed: local < 10
                          ? () => setSheetState(() => local++)
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'out of 10',
                  style: TextStyle(
                    color: _kSlate500,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(ctx).pop(null),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: _kSlate500,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: BrandColors.sunriseGold,
                          foregroundColor: _kNavy,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () => Navigator.of(ctx).pop(local),
                        child: const Text(
                          'Save',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
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

/// 44x44 round score chip. Tap-able when `onTap != null` (exec users).
class _ScoreCircle extends StatelessWidget {
  final int score;
  final VoidCallback? onTap;
  const _ScoreCircle({required this.score, this.onTap});

  /// Branded score-band styling. 0 reads as muted neutral; 1-4 is a soft
  /// red wash with navy text (warning, not error); 5-7 is sunrise gold;
  /// 8-10 is success green. Never raw red — that reads "broken".
  ({Color bg, Color fg}) get _bandColors {
    if (score >= 8) {
      return (bg: BrandColors.success, fg: Colors.white);
    }
    if (score >= 5) {
      return (bg: BrandColors.sunriseGold, fg: _kNavy);
    }
    if (score >= 1) {
      return (bg: _kLowBg, fg: _kNavy);
    }
    return (bg: _kZeroBg, fg: _kSlate400);
  }

  @override
  Widget build(BuildContext context) {
    final colors = _bandColors;
    final circle = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: colors.bg,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.black.withOpacity(0.06),
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        '$score',
        style: TextStyle(
          color: colors.fg,
          fontSize: 16,
          fontWeight: FontWeight.w800,
          fontFeatures: const [FontFeature.tabularFigures()],
          height: 1.0,
        ),
      ),
    );
    if (onTap == null) return circle;
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: circle,
      ),
    );
  }
}

/// Stepper +/- button used inside the bottom-sheet editor.
class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  const _StepperButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _kSurface,
            shape: BoxShape.circle,
            border: Border.all(
              color: enabled
                  ? BrandColors.momentumBlue
                  : _kBorder,
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 22,
            color: enabled
                ? BrandColors.momentumBlue
                : _kSlate400,
          ),
        ),
      ),
    );
  }
}
