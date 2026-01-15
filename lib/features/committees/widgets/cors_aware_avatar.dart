import 'package:flutter/material.dart';

/// An avatar widget that handles CORS and network errors gracefully.
///
/// Unlike CircleAvatar with NetworkImage, this widget properly handles
/// network failures (including CORS errors from services like Gravatar)
/// by falling back to a placeholder.
class CorsAwareAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final Color? backgroundColor;
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

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? Theme.of(context).primaryColor.withOpacity(0.2);
    final iconColor = fallbackIconColor ?? Theme.of(context).primaryColor;
    final textColor = fallbackTextColor ?? Theme.of(context).primaryColor;

    // Build fallback widget
    Widget fallback = fallbackText != null && fallbackText!.isNotEmpty
        ? Text(
            fallbackText![0].toUpperCase(),
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: radius * 0.7,
            ),
          )
        : Icon(
            fallbackIcon,
            size: radius,
            color: iconColor,
          );

    // If no URL, show fallback immediately
    if (imageUrl == null || imageUrl!.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: bgColor,
        child: fallback,
      );
    }

    // Use Image.network with errorBuilder to handle CORS and network errors
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
          // Show fallback while loading
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(child: fallback);
          },
          // Handle network errors (including CORS)
          errorBuilder: (context, error, stackTrace) {
            return Center(child: fallback);
          },
        ),
      ),
    );
  }
}

/// Creates a CorsAwareAvatar configured for user profiles
class UserAvatar extends StatelessWidget {
  final String? photoUrl;
  final String? userName;
  final double radius;
  final Color? accentColor;

  const UserAvatar({
    super.key,
    this.photoUrl,
    this.userName,
    this.radius = 20,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? Theme.of(context).primaryColor;

    return CorsAwareAvatar(
      imageUrl: photoUrl,
      radius: radius,
      backgroundColor: color.withOpacity(0.2),
      fallbackText: userName,
      fallbackIcon: Icons.person,
      fallbackIconColor: color,
      fallbackTextColor: color,
    );
  }
}
