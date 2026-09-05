import 'package:flutter/material.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';

/// The shared avatar for every person rendered in the CRM.
///
/// Loads [imageUrl] with Image.network and falls back to initials (or an
/// icon) when the URL is null, fails to load, or is blocked by CORS, which
/// Gravatar and some Slack CDNs do. CircleAvatar with NetworkImage cannot
/// recover from those failures, which is why this widget exists.
///
/// Callers pass the RESOLVED photo URL. For a member that is
/// `Member.effectiveAvatarUrl`; for a candidate it is
/// `Candidate.effectivePhotoUrl`. Never hand this widget a raw column read:
/// zero of the executive committee have `avatar_url` set while all of them
/// have `profile_pictures`, so a raw `avatarUrl` read renders initials
/// forever. That was the bug behind the identity chip in the top bar.
///
/// Contrast. The defaults are an OPAQUE unityBlue disc under white content,
/// which measures 12.51:1 (computed, WCAG relative luminance). Because the
/// disc is opaque the ratio holds on any surface, including the branded
/// gradient header whose left end is too light for white text on a
/// translucent fill. Callers on the solid navy surfaces may pass the kit's
/// white-20% tile as [backgroundColor]; white on that tile composited over
/// unityBlue measures 6.68:1. Do not pass a translucent [backgroundColor]
/// on the gradient header: white on white-20% over the light end measures
/// 1.91:1.
///
/// Failure behaviour, audited 2026-09-05. There is no path through this
/// widget that renders a broken-image glyph, a bare disc or an unhandled
/// exception. A null or empty [imageUrl] renders the disc plus [fallbackText]
/// initials directly; a non-empty one goes through Image.network, whose
/// errorBuilder returns those same initials on ANY load failure, 404,
/// expired storage path, CORS refusal or malformed URL included, and whose
/// presence is what keeps the image-stream error off the zone. While the
/// image is still in flight the loadingBuilder shows the initials too, so
/// the disc is never empty at any point. An empty or whitespace-only
/// [fallbackText] falls to [fallbackIcon] rather than to nothing, and
/// [initialsOf] returns '?' rather than throwing on a nameless member.
///
/// The default 12.51:1 above clears both the 4.5:1 normal-text and 3:1
/// large-text floors, and clears them at EVERY call site that takes the
/// default, because an opaque disc makes the ratio a property of the widget
/// rather than of the surface behind it. Two figures for the pairings a
/// caller might reach for instead: white on momentumBlue is 2.75:1 and
/// fails both floors, which is what makes momentumBlue non-text-use only,
/// and unityBlue ink on a sunriseGold fill is 7.17:1 if a lighter disc is
/// ever wanted.
class CorsAwareAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final Color? backgroundColor;

  /// A person's display name. The widget derives the initials itself: first
  /// letter of the first and last words, so "Andrew Hartzler" reads "AH" and
  /// a single word reads as one letter.
  final String? fallbackText;
  final IconData fallbackIcon;
  final Color? fallbackIconColor;
  final Color? fallbackTextColor;

  const CorsAwareAvatar({
    super.key,
    this.imageUrl,
    this.radius = 20,
    this.backgroundColor,
    this.fallbackText,
    this.fallbackIcon = Icons.person,
    this.fallbackIconColor,
    this.fallbackTextColor,
  });

  static String initialsOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+'))
      ..removeWhere((p) => p.isEmpty);
    if (parts.isEmpty) return '?';
    final first = parts.first.characters.first.toUpperCase();
    if (parts.length == 1) return first;
    return first + parts.last.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? BrandColors.unityBlue;
    final iconColor = fallbackIconColor ?? Colors.white;
    final textColor = fallbackTextColor ?? Colors.white;

    final name = fallbackText?.trim() ?? '';
    final Widget fallback;
    if (name.isNotEmpty) {
      // Two bold glyphs at 0.75r are about 0.9r wide, inside the 1.41r
      // square the disc inscribes, so one size serves one letter or two.
      fallback = Text(
        initialsOf(name),
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.75,
        ),
      );
    } else {
      fallback = Icon(fallbackIcon, size: radius, color: iconColor);
    }

    if (imageUrl == null || imageUrl!.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: bgColor,
        child: fallback,
      );
    }

    return ClipOval(
      child: Container(
        width: radius * 2,
        height: radius * 2,
        color: bgColor,
        child: Image.network(
          imageUrl!,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(child: fallback);
          },
          errorBuilder: (context, error, stackTrace) {
            return Center(child: fallback);
          },
        ),
      ),
    );
  }
}
