import 'package:flutter/material.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';

// ═════════════════════════════════════════════════════════════
//  VOLUNTEERS THEME: the ONE palette for every Candidate Volunteers
//  surface (map chrome, statewide rail, region detail, toolkit sheet).
//
//  WHY THIS FILE NO LONGER CARRIES A PALETTE OF ITS OWN
//  It used to resolve every token from the active [ColorScheme]. That made the
//  workspace a SECOND source of truth alongside [BrandColors]: two independent
//  definitions of one visual intent, free to drift apart every time either
//  side moved. The drift IS the bug, and it is why this area and the Slack
//  pages stopped looking like one product. The fix is one DERIVED source:
//  every token below is computed from BrandColors, so the two cannot disagree
//  and a brand change lands on both at once.
//
//  Three consequences worth knowing before editing:
//   • The palette is FIXED, not theme-responsive. The branded look is
//     deliberate, exactly like the Slack pages. Nothing here reads
//     Theme.of(context); `of(context)` keeps its parameter only so the
//     existing `vt.*` call sites across the workspace compile unchanged.
//   • Surfaces are the navy end of the brand gradient and every foreground is
//     white at a fixed alpha, which is the pairing the Slack kit is built for:
//     white primary, white70 secondary, white-20% icon tiles, white-10% rows.
//   • Roles stay PAIRED, and the pairs are NOT interchangeable. Measured WCAG
//     ratios, computed rather than assumed:
//         text (white) on surface (unityBlue) ............... 12.51:1
//         secondary (white70) on surface .................... 7.03:1
//         onAccentSoft (white) on accentSoft (white-20%) .... 6.68:1
//         onEmphasis (unityBlue) on emphasisFill (gold) ..... 7.17:1
//         onAccent (white) on accent (momentumBlue) ......... 2.75:1
//     Only the last of those FAILS: 2.75:1 is under the 4.5:1 normal-text bar
//     and under the 3:1 large-text and graphical-object bar as well. See
//     [accent] for what that means for call sites.
// ═════════════════════════════════════════════════════════════
class VolunteersTheme {
  const VolunteersTheme._({
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
    required this.emphasisFill,
    required this.onEmphasis,
    required this.inverseSurface,
    required this.onInverseSurface,
    required this.primary,
  });

  /// Panel, sheet and card fill: the navy the Slack cards start from.
  final Color surface;

  /// Row fills, field fills, hot-row fills: the white-10% pill the branded
  /// activity feed uses.
  final Color inset;

  /// Primary body text. White on [surface] measures 12.51:1.
  final Color text;

  /// Labels, meta lines, muted captions. White70 on [surface] measures
  /// 7.03:1 once the alpha is composited against the navy.
  final Color secondary;

  /// Hairline separators (white 10%, the branded divider).
  final Color divider;

  /// The single accent, for NON-TEXT use only: active-tab underlines, rules,
  /// focus rings, spinner and chart strokes, map selection rings. It sits at
  /// 4.55:1 against [surface], which clears the 3:1 bar for graphical objects.
  ///
  /// DO NOT PUT TEXT ON IT. [onAccent] over [accent] measures 2.75:1, which
  /// fails the 4.5:1 normal-text bar and the 3:1 large-text bar too. A filled
  /// button or pill that carries a label uses [emphasisFill] / [onEmphasis]
  /// instead, which measures 7.17:1. [onAccent] survives because a handful of
  /// glyph-only call sites outside this file still read it; every one of those
  /// is a contrast bug of the same 2.75:1 kind and none is text.
  final Color accent;
  final Color onAccent;

  /// Soft accent surface: the signature white-20% icon tile / selected row.
  /// [onAccentSoft] over [accentSoft] measures 6.68:1.
  final Color accentSoft;
  final Color onAccentSoft;

  /// The highlight hue on its own: young-dem pins, priority swatches, section
  /// rules. This is a MARK rather than a surface, so it carries no `on*`
  /// partner; sunriseGold against [surface] measures 7.17:1.
  final Color highlight;

  /// THE EMPHASIS PAIR. A sunriseGold fill under unityBlue content, which is
  /// the kit's gold-on-navy emphasis pairing and measures 7.17:1 either way
  /// round. This is the ONLY pair in this palette a filled control may put a
  /// LABEL on: primary action buttons, organize pills, selected markers.
  final Color emphasisFill;
  final Color onEmphasis;

  /// Older names for the same pair, kept as getters rather than as a second
  /// set of fields so there is exactly one definition of the colours. The map
  /// still reads them; fold those call sites onto [emphasisFill] /
  /// [onEmphasis] and delete these two lines.
  Color get highlightSoft => emphasisFill;
  Color get onHighlightSoft => onEmphasis;

  /// High-contrast tooltip surface (inverse of the navy panel).
  final Color inverseSurface;
  final Color onInverseSurface;

  /// The hue the choropleth ramp is built from.
  final Color primary;

  /// One instance for the whole app: the palette no longer depends on
  /// anything in the tree, so there is nothing to rebuild per frame.
  static final VolunteersTheme _brand = VolunteersTheme._(
    surface: BrandColors.unityBlue,
    inset: Colors.white.withValues(alpha: 0.1),
    text: Colors.white,
    secondary: Colors.white70,
    divider: Colors.white.withValues(alpha: 0.1),
    accent: BrandColors.momentumBlue,
    onAccent: Colors.white,
    accentSoft: Colors.white.withValues(alpha: 0.2),
    onAccentSoft: Colors.white,
    highlight: BrandColors.sunriseGold,
    emphasisFill: BrandColors.sunriseGold,
    onEmphasis: BrandColors.unityBlue,
    inverseSurface: Colors.white,
    onInverseSurface: BrandColors.unityBlue,
    primary: BrandColors.momentumBlue,
  );

  /// [context] is deliberately unused: the palette is fixed. The parameter
  /// stays so every `VolunteersTheme.of(context)` call site is untouched.
  factory VolunteersTheme.of(BuildContext context) => _brand;

  // ── Choropleth ────────────────────────────────────────────────
  /// Five member-density alpha stops over [primary]. One ramp, not two: the
  /// canvas is now always [mask] rather than whatever the member's theme
  /// happened to be, so there is no second case to compensate for.
  static const List<int> _ramp = [0x22, 0x52, 0x81, 0xB1, 0xE0];

  /// Choropleth fill for a 5-step quantile [bin] (0..4), clamped.
  Color choropleth(int bin) =>
      primary.withAlpha(_ramp[bin.clamp(0, _ramp.length - 1)]);

  /// Out-of-state / map canvas fill: unityBlue driven down toward black.
  ///
  /// It is deliberately NOT [surface]. The desktop war room sets panes flush
  /// against the map with a one-pixel divider between them, so a map painted
  /// the same navy as the panels would merge into one field and lose the
  /// seam. Recessing the canvas reads the way the Slack pages do, panels
  /// raised and ground behind them, and it widens the range the choropleth
  /// climbs through.
  Color get mask => Color.lerp(surface, Colors.black, 0.35)!;
}
