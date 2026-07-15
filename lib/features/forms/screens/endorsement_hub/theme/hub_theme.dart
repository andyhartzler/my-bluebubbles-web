import 'package:flutter/material.dart';

/// The Endorsement HQ design system.
///
/// One vibrant, gradient-rich visual language shared by every tab of the hub
/// (Roster, Compare, Analytics, Decisions) and the candidate review screen,
/// modeled on the Slack-management brand treatment Andrew likes.
///
/// CONTRAST CONTRACT: every gradient defined here is dark enough end-to-end
/// that pure white text clears WCAG AA (>= 4.5:1) at every stop. White70 is
/// only ever used at >= 4.5:1 stops (the navy family). Nothing in this file
/// reads Theme.cardColor onto a colored surface.
class HubTheme {
  HubTheme._();

  // ==================== BRAND CORE ====================

  /// MOYD navy. White on this is ~11:1.
  static const Color navy = Color(0xFF263351);

  /// Royal mid-stop. White on this is ~8.4:1.
  static const Color royal = Color(0xFF2B4B8C);

  /// Deep sky end-stop. White on this is ~5.4:1 (checked).
  static const Color skyDeep = Color(0xFF1D6FA8);

  /// MOYD gold. On navy it reads ~5.7:1; used for accents and labels on the
  /// navy family only (never as a text color on light surfaces).
  static const Color gold = Color(0xFFD4A039);

  /// Brighter gold for indicator lines / rings where it is decorative.
  static const Color goldBright = Color(0xFFE8B54A);

  // ==================== GRADIENTS ====================

  /// The hero sweep used by the hub banner, compare headers, tally header and
  /// the review hero: navy -> royal -> deep sky. A vibrant hue shift that
  /// stays dark enough for white text everywhere.
  static const List<Color> heroColors = [navy, royal, skyDeep];

  static const LinearGradient hero = LinearGradient(
    colors: heroColors,
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// A quieter navy-only gradient for icon tiles and small chrome.
  static const LinearGradient chip = LinearGradient(
    colors: [navy, royal],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// KPI-tile gradients. All stops carry white at >= 4.5:1.
  static const List<Color> gradNavy = [Color(0xFF263351), Color(0xFF2B4B8C)];
  static const List<Color> gradIndigo = [Color(0xFF4F46E5), Color(0xFF4338CA)];
  static const List<Color> gradEmerald = [Color(0xFF047857), Color(0xFF065F46)];
  static const List<Color> gradAmber = [Color(0xFFB45309), Color(0xFF92400E)];
  static const List<Color> gradCyan = [Color(0xFF0E7490), Color(0xFF155E75)];
  static const List<Color> gradPurple = [Color(0xFF6D28D9), Color(0xFF5B21B6)];
  static const List<Color> gradCrimson = [Color(0xFFB91C1C), Color(0xFF991B1B)];
  static const List<Color> gradSlate = [Color(0xFF44506A), Color(0xFF334155)];
  static const List<Color> gradSky = [Color(0xFF1D6FA8), Color(0xFF155E96)];

  // ==================== TEXT ON GRADIENT ====================

  static const TextStyle onGradientTitle = TextStyle(
    color: Colors.white,
    fontSize: 16,
    fontWeight: FontWeight.w800,
  );

  static const TextStyle onGradientSub = TextStyle(
    color: Color(0xE6FFFFFF), // white-90: safe even at the lightest stop
    fontSize: 12,
  );
}

/// A theme-aware surface card: rounded 18, hairline border, whisper shadow.
/// The workhorse container for every analytics / list panel in the hub.
class HubCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const HubCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(dark ? 0.30 : 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: padding,
      child: child,
    );
  }
}

/// The shared card header: a 36x36 gradient icon tile, a bold title, an
/// optional muted subtitle and an optional trailing widget. Gives every panel
/// in the hub the same voice.
class HubCardHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final List<Color>? tileGradient;

  const HubCardHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.tileGradient,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: tileGradient ?? HubTheme.gradNavy,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing!,
        ],
      ],
    );
  }
}

/// A gradient KPI tile: icon chip, big white value, small label. White text
/// with a soft shadow so it stays crisp on every gradient in [HubTheme].
class HubStatTile extends StatelessWidget {
  final List<Color> gradient;
  final IconData icon;
  final String value;
  final String label;
  final String? sub;
  final VoidCallback? onTap;

  const HubStatTile({
    super.key,
    required this.gradient,
    required this.icon,
    required this.value,
    required this.label,
    this.sub,
    this.onTap,
  });

  static const _shadow = [
    Shadow(color: Color(0x55000000), offset: Offset(0, 1), blurRadius: 2),
  ];

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withOpacity(0.28),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 15),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    shadows: _shadow,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                height: 1.0,
                shadows: _shadow,
              )),
          if (sub != null) ...[
            const SizedBox(height: 3),
            Text(sub!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  shadows: _shadow,
                )),
          ],
        ],
      ),
    );
    if (onTap == null) return tile;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: tile,
    );
  }
}

/// The hub's shared empty / zero state: icon inside a gradient ring, bold
/// title, centered message, optional action.
class HubEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const HubEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: HubTheme.hero,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: HubTheme.royal.withOpacity(0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(icon, size: 32, color: Colors.white),
            ),
            const SizedBox(height: 18),
            Text(title,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Text(message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: cs.onSurfaceVariant, height: 1.4)),
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

/// A small navy pill with white text, used for counts / badges on light or
/// dark theme surfaces (self-contained colors, no theme branching).
class HubCountPill extends StatelessWidget {
  final String text;
  final IconData? icon;
  const HubCountPill({super.key, required this.text, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: HubTheme.chip,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: Colors.white),
            const SizedBox(width: 5),
          ],
          Text(text,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
