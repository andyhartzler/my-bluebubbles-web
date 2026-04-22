import 'package:flutter/material.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/models/crm/candidate.dart';
import 'package:bluebubbles/services/crm/candidate_repository.dart';

/// Hero summary card shown above the filter shelf on mobile/tablet.
///
/// Redesign notes:
///   - Giant leading "Total" number in sunriseGold with a subtle sparkline
///     visualizing the D/R split underneath it.
///   - Four secondary pills (Young Dems, Uncontested-R, Primary Challengers,
///     Endorsed) that tap-toggle their respective filter.
///   - Staggered entrance fade to feel premium.
///   - Designed for widths 360px — 1199px (desktop uses the split panel).
class CandidatesHeroStats extends StatefulWidget {
  final CandidateStats stats;
  final int totalCandidates; // may differ from stats if filters are applied
  final int primaryChallengerCount;
  final int uncontestedRepublicanCount;
  final bool ydActive;
  final bool endorsedActive;
  final VoidCallback onToggleYd;
  final VoidCallback onToggleEndorsed;
  final VoidCallback onTapPrimaryChallengers;
  final VoidCallback onTapUncontested;

  const CandidatesHeroStats({
    super.key,
    required this.stats,
    required this.totalCandidates,
    required this.primaryChallengerCount,
    required this.uncontestedRepublicanCount,
    required this.ydActive,
    required this.endorsedActive,
    required this.onToggleYd,
    required this.onToggleEndorsed,
    required this.onTapPrimaryChallengers,
    required this.onTapUncontested,
  });

  @override
  State<CandidatesHeroStats> createState() => _CandidatesHeroStatsState();
}

class _CandidatesHeroStatsState extends State<CandidatesHeroStats>
    with TickerProviderStateMixin {
  late final AnimationController _entrance;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..forward();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _entrance,
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(_entrance.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 12),
            child: _buildCard(context),
          ),
        );
      },
    );
  }

  Widget _buildCard(BuildContext context) {
    final stats = widget.stats;
    final total = stats.totalCandidates;
    final dem = stats.democrats;
    final rep = stats.republicans;
    final other = (total - dem - rep).clamp(0, total);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            BrandColors.unityBlue.withOpacity(0.96),
            BrandColors.momentumBlue.withOpacity(0.30),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border:
            Border.all(color: BrandColors.sunriseGold.withOpacity(0.25), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.32),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: BrandColors.sunriseGold.withOpacity(0.10),
            blurRadius: 28,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Giant total + YD count pill ───
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Big number
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Missouri 2026',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  ShaderMask(
                    shaderCallback: (rect) => const LinearGradient(
                      colors: [
                        BrandColors.sunriseGold,
                        Color(0xFFFFD265),
                      ],
                    ).createShader(rect),
                    child: Text(
                      '$total',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                        letterSpacing: -1.4,
                      ),
                    ),
                  ),
                  Text(
                    'candidates filed',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.70),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // YD spotlight pill
              _YdSpotlightBadge(count: stats.youngDemocrats),
            ],
          ),
          const SizedBox(height: 16),
          // ─── Party split sparkline ───
          _PartySparkline(dem: dem, rep: rep, other: other),
          const SizedBox(height: 16),
          // ─── Secondary pill row ───
          _buildPillRow(context),
        ],
      ),
    );
  }

  Widget _buildPillRow(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final narrow = constraints.maxWidth < 360;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _HeroPill(
            icon: Icons.star_rounded,
            label: narrow ? 'Young Dems' : 'Young Dems',
            value: '${widget.stats.youngDemocrats}',
            color: BrandColors.sunriseGold,
            active: widget.ydActive,
            onTap: widget.onToggleYd,
          ),
          _HeroPill(
            icon: Icons.swap_horiz_rounded,
            label: 'Primary Challenges',
            value: '${widget.primaryChallengerCount}',
            color: BrandColors.momentumBlue,
            onTap: widget.onTapPrimaryChallengers,
          ),
          _HeroPill(
            icon: Icons.warning_amber_rounded,
            label: 'Uncontested R',
            value: '${widget.uncontestedRepublicanCount}',
            color: const Color(0xFFF59E0B),
            onTap: widget.onTapUncontested,
          ),
          _HeroPill(
            icon: Icons.verified_rounded,
            label: 'Endorsed',
            value: '${widget.stats.endorsed}',
            color: BrandColors.success,
            active: widget.endorsedActive,
            onTap: widget.onToggleEndorsed,
          ),
        ],
      );
    });
  }
}

/// Young Dems spotlight badge: big gold number + star + label.
class _YdSpotlightBadge extends StatelessWidget {
  final int count;
  const _YdSpotlightBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            BrandColors.sunriseGold.withOpacity(0.28),
            BrandColors.sunriseGold.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BrandColors.sunriseGold.withOpacity(0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded,
              color: BrandColors.sunriseGold, size: 18),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$count',
                style: const TextStyle(
                  color: BrandColors.sunriseGold,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                'Young Dems',
                style: TextStyle(
                  color: BrandColors.sunriseGold.withOpacity(0.85),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Horizontal bar showing the proportional D / R / Other split, with numeric
/// labels beneath each segment. Replaces the old "stat card rail" visual.
class _PartySparkline extends StatelessWidget {
  final int dem;
  final int rep;
  final int other;
  const _PartySparkline(
      {required this.dem, required this.rep, required this.other});

  @override
  Widget build(BuildContext context) {
    final total = (dem + rep + other).clamp(1, 9999);
    final demFrac = dem / total;
    final repFrac = rep / total;
    final otherFrac = other / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _legendDot(BrandColors.democratBlue),
            const SizedBox(width: 5),
            Text('$dem Democrats',
                style: const TextStyle(
                    color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
            const SizedBox(width: 12),
            _legendDot(BrandColors.republicanRed),
            const SizedBox(width: 5),
            Text('$rep Republicans',
                style: const TextStyle(
                    color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
            if (other > 0) ...[
              const SizedBox(width: 12),
              _legendDot(const Color(0xFFFCD34D)),
              const SizedBox(width: 5),
              Text('$other Other',
                  style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.w500)),
            ],
          ],
        ),
        const SizedBox(height: 6),
        // Stacked bar
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 8,
            child: Row(
              children: [
                Flexible(
                  flex: (demFrac * 1000).round(),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          BrandColors.democratBlue,
                          BrandColors.democratBlue.withOpacity(0.75),
                        ],
                      ),
                    ),
                  ),
                ),
                if (repFrac > 0)
                  Flexible(
                    flex: (repFrac * 1000).round(),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            BrandColors.republicanRed,
                            BrandColors.republicanRed.withOpacity(0.75),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (otherFrac > 0)
                  Flexible(
                    flex: (otherFrac * 1000).round(),
                    child: Container(color: const Color(0xFFFCD34D)),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _legendDot(Color color) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color.withOpacity(0.55), blurRadius: 4)],
      ),
    );
  }
}

/// Tappable stat pill — icon + value + small label. Animates a brighter
/// tint when active (i.e., the filter is currently engaged).
class _HeroPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  const _HeroPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.active = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: active
                  ? [color.withOpacity(0.45), color.withOpacity(0.20)]
                  : [
                      Colors.white.withOpacity(0.05),
                      Colors.white.withOpacity(0.02),
                    ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active
                  ? color.withOpacity(0.85)
                  : Colors.white.withOpacity(0.10),
              width: active ? 1.4 : 1,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.30),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: active ? Colors.white : color),
              const SizedBox(width: 7),
              Text(
                value,
                style: TextStyle(
                  color: active ? Colors.white : color,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: active
                      ? Colors.white.withOpacity(0.92)
                      : Colors.white.withOpacity(0.65),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Helper: count candidates that are likely "primary challengers" — Young Dems
/// who share a district + office + party with another Democrat in the same
/// filing pool. Static so the page can compute once instead of on every build.
int computePrimaryChallengerCount(List<Candidate> all) {
  final grouped = <String, List<Candidate>>{};
  for (final c in all) {
    if (!c.isDemocrat) continue;
    if (c.district == null || c.district!.isEmpty) continue;
    final key = '${c.office.toLowerCase()}|${c.district}';
    grouped.putIfAbsent(key, () => []).add(c);
  }
  int count = 0;
  for (final list in grouped.values) {
    if (list.length < 2) continue;
    // Only count YDs that are challenging another Democrat in the same race.
    for (final c in list) {
      if (c.isYoungDem) count++;
    }
  }
  return count;
}

int computeUncontestedRepublicanCount(List<Candidate> all) {
  // Districts where at least one Republican filed but no Democrat did.
  final byKey = <String, List<Candidate>>{};
  for (final c in all) {
    if (c.district == null || c.district!.isEmpty) continue;
    final key = '${c.office.toLowerCase()}|${c.district}';
    byKey.putIfAbsent(key, () => []).add(c);
  }
  int count = 0;
  for (final entry in byKey.values) {
    final hasDem = entry.any((c) => c.isDemocrat);
    final hasRep = entry.any((c) => c.isRepublican);
    if (hasRep && !hasDem) count++;
  }
  return count;
}
