import 'package:flutter/material.dart';

/// Centralized brand colors for the committees feature
///
/// Color Scheme:
/// - Background: Light blue gradient (momentumBlue-based) or background image asset
/// - Tiles/Cards/Elements: Navy blue gradient (unityBlue to momentumBlue)
/// - Text on navy backgrounds: White
/// - Secondary text on navy: White with 70-80% opacity
class BrandColors {
  BrandColors._();

  // ==================== PRIMARY BRAND COLORS ====================

  /// Navy blue - primary dark color for tiles, cards, and elements
  static const Color unityBlue = Color(0xFF273351);

  /// Light blue - accent color, used in gradients
  static const Color momentumBlue = Color(0xFF32A6DE);

  /// Gold accent
  static const Color sunriseGold = Color(0xFFFDB813);

  // ==================== EXTENDED PALETTE ====================

  static const Color steelBlue = Color(0xFF4682B4);
  static const Color navyBlue = Color(0xFF1E3A5F);
  static const Color slateBlue = Color(0xFF5A7FA3);
  static const Color royalBlue = Color(0xFF2B4B8C);

  // ==================== POLITICAL PARTY COLORS ====================

  static const Color democratBlue = Color(0xFF3B82F6);
  static const Color republicanRed = Color(0xFFEF4444);

  // ==================== SEMANTIC COLORS ====================

  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);

  // ==================== BACKGROUND ASSET ====================

  /// Background image asset path
  static const String backgroundAsset = 'assets/images/Blue-Gradient-Background.png';

  /// Overlay opacity for background image
  static const double backgroundOverlayOpacity = 0.18;

  // ==================== GRADIENTS ====================

  /// Primary gradient for tiles and cards (navy to light blue)
  static const List<Color> tileGradient = [unityBlue, momentumBlue];

  /// Reversed gradient
  static const List<Color> tileGradientReversed = [momentumBlue, unityBlue];

  /// Background gradient (light to dark)
  static const List<Color> backgroundGradient = [momentumBlue, unityBlue];

  /// Build a linear gradient for tiles
  static LinearGradient getTileGradient({
    AlignmentGeometry begin = Alignment.topLeft,
    AlignmentGeometry end = Alignment.bottomRight,
    bool reversed = false,
  }) {
    return LinearGradient(
      colors: reversed ? tileGradientReversed : tileGradient,
      begin: begin,
      end: end,
    );
  }

  // ==================== PREDEFINED GRADIENT SETS ====================

  /// Pre-defined gradient color combinations for widgets
  static const List<List<Color>> widgetGradients = [
    [unityBlue, momentumBlue],           // Unity Blue (default)
    [momentumBlue, Color(0xFF43A047)],   // Momentum
    [Color(0xFF43A047), sunriseGold],    // Grassroots
    [sunriseGold, Color(0xFFE63946)],    // Sunrise
    [Color(0xFFE63946), Color(0xFF6A1B9A)], // Action
    [Color(0xFF6A1B9A), momentumBlue],   // Justice
    [democratBlue, Color(0xFF1D4ED8)],   // Democrat Blue
    [republicanRed, Color(0xFFB91C1C)],  // Republican Red
    [success, Color(0xFF059669)],        // Success Green
    [warning, Color(0xFFD97706)],        // Warning Amber
    [Color(0xFF8B5CF6), Color(0xFF7C3AED)], // Purple
    [Color(0xFF06B6D4), Color(0xFF0891B2)], // Cyan
  ];

  static const List<String> widgetGradientNames = [
    'Unity Blue',
    'Momentum',
    'Grassroots',
    'Sunrise',
    'Action',
    'Justice',
    'Democrat',
    'Republican',
    'Success',
    'Warning',
    'Purple',
    'Cyan',
  ];
}

/// Extension for building consistent card decorations
extension BrandCardDecoration on BoxDecoration {
  /// Create a standard branded card decoration with navy gradient
  static BoxDecoration brandedCard({
    double borderRadius = 16,
    List<Color>? colors,
  }) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: colors ?? BrandColors.tileGradient,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(borderRadius),
    );
  }
}

/// Widget for branded gradient background
class BrandedBackground extends StatelessWidget {
  final Widget child;
  final bool showOverlay;

  const BrandedBackground({
    super.key,
    required this.child,
    this.showOverlay = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background image
        Positioned.fill(
          child: Image.asset(
            BrandColors.backgroundAsset,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: BrandColors.backgroundGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
        ),
        // Optional overlay
        if (showOverlay)
          Positioned.fill(
            child: Container(
              color: Colors.white.withOpacity(BrandColors.backgroundOverlayOpacity),
            ),
          ),
        // Content
        child,
      ],
    );
  }
}

/// Branded card widget with consistent styling
class BrandedCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final List<Color>? gradientColors;
  final VoidCallback? onTap;
  final double elevation;

  const BrandedCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 16,
    this.gradientColors,
    this.onTap,
    this.elevation = 4,
  });

  @override
  Widget build(BuildContext context) {
    final colors = gradientColors ?? BrandColors.tileGradient;

    return Card(
      elevation: elevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: padding ?? const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }
}

/// Text styles for use on branded (navy) backgrounds
class BrandTextStyles {
  BrandTextStyles._();

  static const TextStyle title = TextStyle(
    color: Colors.white,
    fontSize: 18,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle titleLarge = TextStyle(
    color: Colors.white,
    fontSize: 24,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle subtitle = TextStyle(
    color: Colors.white70,
    fontSize: 14,
  );

  static const TextStyle body = TextStyle(
    color: Colors.white,
    fontSize: 14,
  );

  static const TextStyle bodySecondary = TextStyle(
    color: Colors.white70,
    fontSize: 14,
  );

  static const TextStyle caption = TextStyle(
    color: Colors.white60,
    fontSize: 12,
  );

  static const TextStyle stat = TextStyle(
    color: Colors.white,
    fontSize: 32,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle statLabel = TextStyle(
    color: Colors.white70,
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );
}
