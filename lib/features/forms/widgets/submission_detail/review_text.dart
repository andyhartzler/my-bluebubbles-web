import 'package:flutter/material.dart';

/// The one type scale and the one card chrome for the submission-review
/// surfaces.
///
/// Before this, the review folder carried a dozen one-off font sizes (10,
/// 10.5, 11.5, 12, 13.5, 14.5, 15) and four different card treatments, so the
/// questionnaire page read as several products stacked on each other. Every
/// widget in this folder now draws its text from [ReviewText] and its card
/// from [ReviewCard].
///
/// Colors always come from `Theme.of(context)`, never baked in, so both
/// themes stay AA without branching. The verdict banner's display type
/// (26/w900 on the self-contained navy gradient) stays bespoke: it is the
/// hero and the only element allowed to shout.
class ReviewText {
  const ReviewText._();

  /// Section headers and block labels: WHERE THE POINTS WENT, ISSUE LEDGER,
  /// EXECUTIVE BALLOT, SUBMISSION INFO, every section card title.
  static TextStyle overline(BuildContext context) => TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.6,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      );

  /// The small muted label above an answer value.
  static TextStyle fieldLabel(BuildContext context) => TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.7,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      );

  /// Running body text: answers, rationales, explanations.
  static TextStyle body(BuildContext context) => TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: Theme.of(context).colorScheme.onSurface,
      );

  /// Body weight for the one line that carries the point.
  static TextStyle bodyStrong(BuildContext context) => TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurface,
      );

  /// Supporting sentence under a body line.
  static TextStyle secondary(BuildContext context) => TextStyle(
        fontSize: 12.5,
        height: 1.4,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      );

  /// Provenance, timestamps, per-tile detail.
  static TextStyle caption(BuildContext context) => TextStyle(
        fontSize: 11.5,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      );
}

/// The single card chrome every block on the review page wears: ambient
/// surface, radius 20, one hairline border, a 20px gutter and 16px of air
/// below. Applied to section cards, documents, references, the metadata tile,
/// the exec ballot block, the verdict block and every empty/error state, so
/// the page reads as one system rather than five.
///
/// `cs.surface` and `cs.outlineVariant` are theme tokens on an ambient
/// surface, which is exactly where M3 tokens are correct. Nothing branded
/// (navy, gold, stance colors) paints this container.
class ReviewCard extends StatelessWidget {
  final Widget child;

  /// Internal gutter. 20 everywhere except where a child is full-bleed (the
  /// verdict banner), which passes zero and pads its own sections.
  final EdgeInsetsGeometry padding;

  /// Space below the card in a vertical flow.
  final EdgeInsetsGeometry margin;

  /// Overrides the hairline (the verdict block tints it crimson when the
  /// candidate is disqualified).
  final Color? borderColor;

  final Clip clipBehavior;

  const ReviewCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin = const EdgeInsets.only(bottom: 16),
    this.borderColor,
    this.clipBehavior = Clip.none,
  });

  static const double radius = 20;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: margin,
      padding: padding,
      clipBehavior: clipBehavior,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? cs.outlineVariant),
      ),
      child: child,
    );
  }
}

/// A solid shimmer-free placeholder block used by every loading state on the
/// page. Solid [ColorScheme.surfaceContainerHighest], never an opacity over
/// an unknown parent.
class ReviewSkeletonBar extends StatelessWidget {
  final double width;
  final double height;
  final bool circle;

  const ReviewSkeletonBar({
    super.key,
    this.width = double.infinity,
    this.height = 10,
    this.circle = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(6),
      ),
    );
  }
}
