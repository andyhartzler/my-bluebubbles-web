import 'package:flutter/material.dart';
import 'package:bluebubbles/features/committees/theme/brand_colors.dart';

/// Shared UI helpers used across candidate detail tabs.
/// Extracted from candidate_detail_screen.dart to reduce file size.
class CandidateUI {
  CandidateUI._();

  /// Solid-dark card with title+icon header and arbitrary child content.
  static Widget card(String title, IconData icon, Color accent, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: BrandColors.unityBlue.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 6)),
          BoxShadow(color: accent.withOpacity(0.05), blurRadius: 30, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: accent.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: accent, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
              ),
            ],
          ),
          child,
        ],
      ),
    );
  }

  /// Small pill badge with gradient background.
  static Widget badge(String text, Color color, {Color textColor = Colors.white}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.25), color.withOpacity(0.12)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Text(text, style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.2)),
    );
  }

  /// Legend color-dot + label, used in chart legends.
  static Widget legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  /// Centered empty-state placeholder with big icon, title, and subtitle.
  static Widget emptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Icon(icon, color: Colors.white.withOpacity(0.7), size: 48),
            ),
            const SizedBox(height: 20),
            Text(title, style: const TextStyle(color: Colors.white70, fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
            const SizedBox(height: 8),
            Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 13, height: 1.4), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  /// Compact money formatter: $1.2M, $5.3K, $420.
  static String formatMoney(double amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K';
    return amount.toStringAsFixed(amount == amount.truncateToDouble() ? 0 : 2);
  }

  /// Shortest-possible money formatter: rounds to integer when truncated.
  static String formatMoneyShort(double amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(0)}M';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(0)}K';
    return amount.toStringAsFixed(0);
  }

  /// Compact number formatter: 1.2M, 5.3K, 420.
  static String formatNumber(int number) {
    if (number >= 1000000) return '${(number / 1000000).toStringAsFixed(1)}M';
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(number >= 10000 ? 0 : 1)}K';
    }
    return number.toString();
  }

  /// "Mar 15, 2026" date formatter.
  static String formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  /// Animated shimmer placeholder (used while tab data fetches).
  /// Uses a sweeping gradient to visually distinguish loading from empty.
  static Widget shimmerSkeleton({int cardCount = 3}) {
    return _ShimmerSkeletonWidget(cardCount: cardCount);
  }

  /// Stat card used on finance summary rows (money / count / metric).
  /// Wraps value text in FittedBox to prevent overflow on small screens.
  static Widget financeStatCard(String label, String value, IconData icon, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent.withOpacity(0.12), accent.withOpacity(0.04)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: accent.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: accent.withOpacity(0.15), shape: BoxShape.circle),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
          ),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(color: accent.withOpacity(0.7), fontSize: 11, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

/// Animated shimmer skeleton with sweeping gradient.
class _ShimmerSkeletonWidget extends StatefulWidget {
  final int cardCount;
  const _ShimmerSkeletonWidget({required this.cardCount});

  @override
  State<_ShimmerSkeletonWidget> createState() => _ShimmerSkeletonWidgetState();
}

class _ShimmerSkeletonWidgetState extends State<_ShimmerSkeletonWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final value = _controller.value;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          physics: const NeverScrollableScrollPhysics(),
          children: List.generate(widget.cardCount, (i) {
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              height: i == 0 ? 100 : 160,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.03),
                    Colors.white.withOpacity(0.09),
                    Colors.white.withOpacity(0.03),
                  ],
                  stops: [
                    (value - 0.3).clamp(0.0, 1.0),
                    value,
                    (value + 0.3).clamp(0.0, 1.0),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: i == 0
                  ? Row(
                      children: [
                        const SizedBox(width: 16),
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                height: 14,
                                width: 140,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                height: 10,
                                width: 90,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.04),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : null,
            );
          }),
        );
      },
    );
  }
}
