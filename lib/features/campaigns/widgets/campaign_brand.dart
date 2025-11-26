import 'package:flutter/material.dart';

class CampaignBrand {
  static const Color unityBlue = Color(0xFF273351);
  static const Color momentumBlue = Color(0xFF32A6DE);
  static const Color sunriseGold = Color(0xFFFDB813);
  static const Color actionRed = Color(0xFFE63946);
  static const Color justicePurple = Color(0xFF6A1B9A);
  static const Color grassrootsGreen = Color(0xFF43A047);

  static LinearGradient primaryGradient() {
    return const LinearGradient(
      colors: [unityBlue, momentumBlue],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
}
