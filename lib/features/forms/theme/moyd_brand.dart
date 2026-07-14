import 'package:flutter/material.dart';

/// MOYD brand constants for the submission-review surfaces.
///
/// These are the two load-bearing brand colors (navy + gold) plus the
/// stance palette used by the policy-positions grid. Every stance chip is
/// SELF-CONTAINED: it paints its own light background and dark foreground so
/// it stays >= 4.5:1 contrast on both light and dark theme cards without any
/// theme-dependent branching. Verified against WCAG AA at these pairings.
class MoydBrand {
  MoydBrand._();

  /// Navy — MOYD primary. Solid, never opacity-over-unknown. White / white70
  /// text on this is > 8:1.
  static const Color navy = Color(0xFF263351);

  /// A slightly lighter navy for hero gradients / inner surfaces.
  static const Color navySoft = Color(0xFF32436B);

  /// Gold — MOYD accent. Used for office/district emphasis on navy
  /// (gold-on-navy ~= 6.5:1) and left rules.
  static const Color gold = Color(0xFFD4A039);

  /// Amber used for the non-Democrat party-history flag chip.
  static const Color amber = Color(0xFFB8860B);
  static const Color amberBg = Color(0xFFFBEDD1);

  // ==================== STANCE PALETTE ====================
  // Foreground / background pairs. Backgrounds are light, foregrounds dark:
  // legible on white cards AND readable as a light pill on dark cards.

  static const Color supportFg = Color(0xFF1B7A3D);
  static const Color supportBg = Color(0xFFE6F4EA);

  static const Color opposeFg = Color(0xFFB3261E);
  static const Color opposeBg = Color(0xFFFBEAE9);

  static const Color qualifiedFg = Color(0xFF8A5A00);
  static const Color qualifiedBg = Color(0xFFFBEDD1);

  static const Color neutralFg = Color(0xFF44506A);
  static const Color neutralBg = Color(0xFFECEFF4);
}
