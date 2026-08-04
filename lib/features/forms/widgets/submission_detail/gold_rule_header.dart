import 'package:flutter/material.dart';

import 'review_text.dart';

/// The one block header on the review page: a 4x20 gold rule, the title in
/// [ReviewText.overline], and an optional right-aligned trailing widget.
///
/// Replaces three copy-pasted versions of the same gradient container (section
/// card, documents card, references card) plus the M3 `ExpansionTile` look on
/// the metadata tile. Four header treatments became one.
class GoldRuleHeader extends StatelessWidget {
  final String title;

  /// Right-aligned detail: the answer count on a section card, the tally
  /// sentence on the exec ballot block, a chevron on the metadata tile.
  final Widget? trailing;

  const GoldRuleHeader({super.key, required this.title, this.trailing});

  /// MOYD gold, top-to-bottom. Kept here rather than in [MoydBrand] because
  /// it is this header's rule specifically, not a general brand color.
  static const List<Color> _rule = [Color(0xFFD4A039), Color(0xFFB8860B)];

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: _rule,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: ReviewText.overline(context),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          trailing!,
        ],
      ],
    );
  }
}
