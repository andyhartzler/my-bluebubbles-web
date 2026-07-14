import 'package:flutter/material.dart';

import '../../models/submission_review_model.dart';
import '../../theme/moyd_brand.dart';

/// Shared foreground/background/glyph mapping for a [Stance].
///
/// Every pairing is self-contained (light bg + dark fg) so a stance chip stays
/// >= 4.5:1 contrast on BOTH light and dark theme cards without any
/// theme-dependent branching. Reused by the compare matrix, the policy
/// stance bars and the curated submission card.
class StanceVisuals {
  const StanceVisuals._();

  static Color fg(Stance s) {
    switch (s) {
      case Stance.support:
        return MoydBrand.supportFg;
      case Stance.oppose:
        return MoydBrand.opposeFg;
      case Stance.qualified:
        return MoydBrand.qualifiedFg;
      case Stance.unsure:
      case Stance.neutral:
        return MoydBrand.neutralFg;
    }
  }

  static Color bg(Stance s) {
    switch (s) {
      case Stance.support:
        return MoydBrand.supportBg;
      case Stance.oppose:
        return MoydBrand.opposeBg;
      case Stance.qualified:
        return MoydBrand.qualifiedBg;
      case Stance.unsure:
      case Stance.neutral:
        return MoydBrand.neutralBg;
    }
  }

  /// check / tilde-dash / x glyph. Qualified uses a minus (reads as "~").
  static IconData glyph(Stance s) {
    switch (s) {
      case Stance.support:
        return Icons.check_rounded;
      case Stance.oppose:
        return Icons.close_rounded;
      case Stance.qualified:
        return Icons.remove_rounded;
      case Stance.unsure:
      case Stance.neutral:
        return Icons.horizontal_rule_rounded;
    }
  }

  static String label(Stance s) {
    switch (s) {
      case Stance.support:
        return 'Support';
      case Stance.oppose:
        return 'Oppose';
      case Stance.qualified:
        return 'Qualified';
      case Stance.unsure:
        return 'Unsure';
      case Stance.neutral:
        return 'No answer';
    }
  }

  /// A small self-contained stance pill (glyph + optional text).
  static Widget pill(Stance s, {String? text, bool dense = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 6 : 8,
        vertical: dense ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: bg(s),
        borderRadius: BorderRadius.circular(dense ? 6 : 8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(glyph(s), size: dense ? 13 : 15, color: fg(s)),
          if (text != null) ...[
            const SizedBox(width: 4),
            Text(
              text,
              style: TextStyle(
                color: fg(s),
                fontWeight: FontWeight.w600,
                fontSize: dense ? 11 : 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Small formatting helpers shared across the endorsement review surfaces.
class ReviewFormat {
  const ReviewFormat._();

  /// "$167,000" — thousands-separated whole-dollar currency. No intl dep.
  static String currency(num? value) {
    if (value == null) return '—';
    final whole = value.round();
    final digits = whole.abs().toString();
    final buf = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
      buf.write(digits[i]);
    }
    return '${whole < 0 ? '-' : ''}\$$buf';
  }
}
