import 'package:flutter/material.dart';

/// Theme colors for the Communications Committee Social Media Analytics dashboard
class CommunicationsCommitteeTheme {
  CommunicationsCommitteeTheme._();

  // Primary colors - matching the committee's momentum blue
  static const Color primary = Color(0xFF32A6DE);
  static const Color primaryLight = Color(0xFF6BD7FF);
  static const Color primaryDark = Color(0xFF0078AC);

  // Platform-specific accent colors
  static const Map<String, Color> platformColors = {
    'facebook': Color(0xFF1877F2),
    'instagram': Color(0xFFE4405F),
    'threads': Color(0xFF000000),
    'youtube': Color(0xFFFF0000),
    'reddit': Color(0xFFFF4500),
    'tiktok': Color(0xFF000000),
    'twitter': Color(0xFF1DA1F2),
    'x': Color(0xFF000000),
  };

  // Chart colors palette
  static const List<Color> chartPalette = [
    Color(0xFF32A6DE), // Momentum Blue
    Color(0xFF26A69A), // Teal
    Color(0xFFFFCA28), // Amber
    Color(0xFFEF5350), // Red
    Color(0xFF66BB6A), // Green
    Color(0xFFAB47BC), // Purple
    Color(0xFF42A5F5), // Light Blue
    Color(0xFFFF7043), // Deep Orange
  ];

  /// Get platform color with fallback
  static Color getPlatformColor(String platform) {
    return platformColors[platform.toLowerCase()] ?? Colors.grey;
  }

  /// Get chart color by index with wrap-around
  static Color getChartColor(int index) {
    return chartPalette[index % chartPalette.length];
  }
}
