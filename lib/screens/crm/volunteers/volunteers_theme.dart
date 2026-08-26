import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════
//  VOLUNTEERS THEME — the ONE palette for every Candidate Volunteers
//  surface (map chrome, statewide rail, region detail, toolkit sheet).
//
//  It carries no hardcoded brand hexes. Every token resolves from the
//  active [ColorScheme], exactly like the Slack pages Andrew loves: calm
//  neutral surfaces, ONE accent (scheme.primary), soft grey-blue insets,
//  and a single highlight role (scheme.tertiary) that REPLACES all the old
//  gold. Because it consumes scheme roles, any FlexScheme the member picks
//  recolors the whole area with no islands.
//
//  Build one per frame with [VolunteersTheme.of]. Every text/background
//  pairing built from these tokens clears 4.5:1 in both bundled themes
//  (Bright White + OLED Dark are M3 blue-seed, verified).
// ═══════════════════════════════════════════════════════════════
class VolunteersTheme {
  const VolunteersTheme._({
    required this.isDark,
    required this.surface,
    required this.inset,
    required this.text,
    required this.secondary,
    required this.divider,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.onAccentSoft,
    required this.highlight,
    required this.highlightSoft,
    required this.onHighlightSoft,
    required this.danger,
    required this.inverseSurface,
    required this.onInverseSurface,
    required this.primary,
  });

  final bool isDark;

  /// Panel, sheet and card fill.
  final Color surface;

  /// Chip fills, field fills, hot-row fills — the soft grey-blue inset.
  final Color inset;

  /// Primary body text.
  final Color text;

  /// Labels, meta lines, muted captions.
  final Color secondary;

  /// Hairline separators, matched to the Slack reaction-chip border.
  final Color divider;

  /// Links, active tab, buttons, focus. The single accent.
  final Color accent;
  final Color onAccent;

  /// Soft accent surface (selected chips, roundels behind an accent glyph).
  final Color accentSoft;
  final Color onAccentSoft;

  /// The highlight role that replaces ALL gold: young-dem pins, priority
  /// swatches, the toolkit accents. Use [highlightSoft] as a fill and
  /// [onHighlightSoft] as text/icon on that fill.
  final Color highlight;
  final Color highlightSoft;
  final Color onHighlightSoft;

  final Color danger;

  /// High-contrast tooltip surface (inverse of the page).
  final Color inverseSurface;
  final Color onInverseSurface;

  /// The raw accent hue, used to compute the choropleth ramp.
  final Color primary;

  factory VolunteersTheme.of(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    return VolunteersTheme._(
      isDark: isDark,
      surface: scheme.surface,
      // The app deliberately overrides surfaceVariant as its inset fill (see
      // themes_service.dart), so it stays our inset token despite the M3
      // deprecation of the role name.
      // ignore: deprecated_member_use
      inset: scheme.surfaceVariant,
      text: scheme.onSurface,
      secondary: scheme.onSurfaceVariant,
      divider: scheme.outline.withValues(alpha: 0.3),
      accent: scheme.primary,
      onAccent: scheme.onPrimary,
      accentSoft: scheme.primaryContainer,
      onAccentSoft: scheme.onPrimaryContainer,
      highlight: scheme.tertiary,
      highlightSoft: scheme.tertiaryContainer,
      onHighlightSoft: scheme.onTertiaryContainer,
      danger: scheme.error,
      inverseSurface: scheme.inverseSurface,
      onInverseSurface: scheme.onInverseSurface,
      primary: scheme.primary,
    );
  }

  // ── Choropleth ────────────────────────────────────────────────
  /// Five member-density alpha stops over the accent hue, computed at
  /// runtime so a theme swap recolors the map. Light lifts 0x14→0xCC, dark
  /// 0x22→0xE0 to hold over the darker canvas.
  static const List<int> _rampLight = [0x14, 0x42, 0x70, 0x9E, 0xCC];
  static const List<int> _rampDark = [0x22, 0x52, 0x81, 0xB1, 0xE0];

  /// Choropleth fill for a 5-step quantile [bin] (0..4), clamped.
  Color choropleth(int bin) {
    final ramp = isDark ? _rampDark : _rampLight;
    return primary.withAlpha(ramp[bin.clamp(0, ramp.length - 1)]);
  }

  /// Out-of-state / map canvas fill, matched to the active surface. Light
  /// tints the surface a hair toward the accent so the state reads as an
  /// infographic; dark is the flat surface.
  Color get mask =>
      isDark ? surface : Color.alphaBlend(primary.withValues(alpha: 0.04), surface);
}
