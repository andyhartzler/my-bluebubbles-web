import 'package:flutter/material.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';

/// Reusable section card for the Personalized Home Screen. Mirrors the
/// Slack management screen's pattern at section level: a navy → momentum
/// gradient header strip carries the title + optional tabs + a trailing
/// action; the body sits below on a white surface with rounded bottom
/// corners. Drop-in replacement for the plain `Card` previously used by
/// the home panels.
class BrandedPanel extends StatelessWidget {
  /// Title shown next to the icon in the gradient header.
  final String title;
  final IconData icon;

  /// Optional trailing widget on the header (e.g. an "Add" button or
  /// IconButton). Rendered with white tint by default — the caller is
  /// responsible for white text/icon styling.
  final Widget? headerAction;

  /// Optional TabBar to embed in the header (immediately under the
  /// title row). Wire it the same way you would a normal TabBar — the
  /// caller controls the controller. Leave null for sections with no
  /// inner tabs (e.g. the metric-tiles section).
  final PreferredSizeWidget? tabBar;

  /// The main content of the section.
  final Widget body;

  /// If true, the body is wrapped in a fixed-height SizedBox. Useful
  /// for tabbed sections so each tab body shares the same height. If
  /// null, the body sizes to its content.
  final double? bodyHeight;

  const BrandedPanel({
    super.key,
    required this.title,
    required this.icon,
    required this.body,
    this.headerAction,
    this.tabBar,
    this.bodyHeight,
  });

  @override
  Widget build(BuildContext context) {
    // Force the body to render against a light surface theme so default
    // text widgets land as dark-on-light regardless of the app-wide
    // dark theme — guarantees AA contrast on the white panel body.
    final lightTheme = Theme.of(context).copyWith(
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        surface: Colors.white,
        onSurface: Color(0xFF1F2937), // slate-800
      ),
      iconTheme: const IconThemeData(color: Color(0xFF334155)), // slate-700
      textTheme: Theme.of(context).textTheme.apply(
            bodyColor: const Color(0xFF1F2937),
            displayColor: const Color(0xFF111827),
          ),
      listTileTheme: const ListTileThemeData(
        textColor: Color(0xFF1F2937),
        iconColor: Color(0xFF475569), // slate-600
        subtitleTextStyle: TextStyle(color: Color(0xFF475569)),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFFE5E7EB)),
    );

    final themedBody = Theme(data: lightTheme, child: this.body);
    final sized = bodyHeight != null
        ? SizedBox(height: bodyHeight, child: themedBody)
        : themedBody;

    // Always paint a near-white surface for the body so default
    // `ListTile` dark-on-light text stays readable on BOTH light and
    // dark themes. We sit on top of `BrandedBackground` (light blue
    // gradient + image overlay), so a near-opaque white reads as a
    // clean card, never as a black slab. NEVER use `Theme.cardColor`
    // here — on dark theme it resolves near-black and kills contrast.
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.96),
          boxShadow: [
            BoxShadow(
              color: BrandColors.unityBlue.withOpacity(0.18),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: BrandColors.tileGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
                    child: Row(
                      children: [
                        Icon(icon, color: BrandColors.sunriseGold, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ),
                        if (headerAction != null) headerAction!,
                      ],
                    ),
                  ),
                  if (tabBar != null) tabBar!,
                ],
              ),
            ),
            sized,
          ],
        ),
      ),
    );
  }
}

/// A pre-styled `TabBar` matching the branded header pattern: white
/// selected/unselected labels with sunrise-gold underline indicator.
/// Use as the `tabBar` argument to [BrandedPanel].
class BrandedHeaderTabBar extends StatelessWidget implements PreferredSizeWidget {
  final TabController controller;
  final List<Widget> tabs;
  final ValueChanged<int>? onTap;
  final bool isScrollable;

  const BrandedHeaderTabBar({
    super.key,
    required this.controller,
    required this.tabs,
    this.onTap,
    this.isScrollable = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(46);

  @override
  Widget build(BuildContext context) {
    return TabBar(
      controller: controller,
      tabs: tabs,
      onTap: onTap,
      isScrollable: isScrollable,
      tabAlignment: isScrollable ? TabAlignment.start : null,
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white.withOpacity(0.7),
      indicatorColor: BrandColors.sunriseGold,
      indicatorWeight: 3,
      labelStyle: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      unselectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 13,
      ),
      dividerColor: Colors.transparent,
      splashFactory: NoSplash.splashFactory,
      overlayColor: WidgetStatePropertyAll(Colors.white.withOpacity(0.08)),
    );
  }
}

/// Pill-style "+ New" button matching the branded header. White text on
/// a transparent surface with a thin white border, shrinks gracefully
/// in the header rail.
class BrandedHeaderPillButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;

  const BrandedHeaderPillButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16, color: BrandColors.sunriseGold),
        label: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        style: TextButton.styleFrom(
          backgroundColor: Colors.white.withOpacity(0.12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withOpacity(0.25)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          minimumSize: Size.zero,
        ),
      ),
    );
  }
}
