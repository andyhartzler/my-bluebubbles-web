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
  static const Color federalBlue = Color(0xFF0B3D91);

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

/// Branded stat card with icon tile, big value, and optional subtitle.
///
/// Promoted from `_BrandedSummaryCard` in `analytics_tab.dart`. Use for
/// KPI tiles on Slack-style pages.
class BrandedStatCard extends StatelessWidget {
  const BrandedStatCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    this.gradientColors,
  });

  /// Label shown next to the icon tile (white70, 13, w500).
  final String title;

  /// Big metric value (white, 32, bold).
  final String value;

  /// Optional footnote under the value (white60, 12).
  final String? subtitle;

  /// Icon rendered inside a 44x44 white-20% tile.
  final IconData icon;

  /// Optional override for the card's background gradient. Defaults to
  /// [BrandColors.tileGradient].
  final List<Color>? gradientColors;

  @override
  Widget build(BuildContext context) {
    final colors = gradientColors ?? BrandColors.tileGradient;
    return BrandedCard(
      gradientColors: colors,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  // White70/60 drop below 3:1 on the sunriseGold gradient
                  // (Avg Gift tile). Bump to full white and add a subtle
                  // shadow so the title stays legible on any gradient.
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    shadows: [
                      Shadow(
                        color: Color(0x66000000),
                        offset: Offset(0, 1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  color: Color(0x66000000),
                  offset: Offset(0, 1),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: const TextStyle(
                color: Color(0xE6FFFFFF),
                fontSize: 12,
                shadows: [
                  Shadow(
                    color: Color(0x66000000),
                    offset: Offset(0, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Data model for one row inside a [BrandedRankedListCard].
class BrandedRankedItem {
  const BrandedRankedItem({
    required this.label,
    required this.valueLabel,
    required this.progressFraction,
    this.sublabel,
  });

  /// Primary text (e.g. donor name).
  final String label;

  /// Right-aligned bold value (e.g. "$12,500").
  final String valueLabel;

  /// 0.0-1.0 fraction for the progress bar (typically value / max).
  final double progressFraction;

  /// Optional sub-label displayed under [label] (e.g. "3 contributions").
  final String? sublabel;
}

/// Branded card that renders a top-N ranked list with rank badges and
/// a per-row progress bar.
class BrandedRankedListCard extends StatelessWidget {
  const BrandedRankedListCard({
    super.key,
    required this.title,
    required this.icon,
    required this.items,
    this.gradientColors,
    this.onItemTap,
    this.emptyLabel,
  });

  /// Header title (rendered with [BrandTextStyles.title]).
  final String title;

  /// Icon placed inside the 24x24 header tile.
  final IconData icon;

  /// Ranked items, highest rank first (rank 1 at index 0).
  final List<BrandedRankedItem> items;

  /// Optional override for the card's background gradient.
  final List<Color>? gradientColors;

  /// Optional tap handler; receives the 0-indexed position of the tapped row.
  final void Function(int index)? onItemTap;

  /// Text shown in the empty-state row (defaults to "No items").
  final String? emptyLabel;

  @override
  Widget build(BuildContext context) {
    final colors = gradientColors ?? BrandColors.tileGradient;
    return BrandedCard(
      gradientColors: colors,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: BrandTextStyles.title,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            SizedBox(
              height: 80,
              child: Center(
                child: Text(
                  emptyLabel ?? 'No items',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = items[index];
                final progress = item.progressFraction.clamp(0.0, 1.0);
                final row = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (item.sublabel != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  item.sublabel!,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          item.valueLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(Colors.white),
                        minHeight: 6,
                      ),
                    ),
                  ],
                );
                if (onItemTap == null) return row;
                return InkWell(
                  onTap: () => onItemTap!(index),
                  borderRadius: BorderRadius.circular(8),
                  child: row,
                );
              },
            ),
        ],
      ),
    );
  }
}

/// Branded activity-feed row (white-10% pill) with avatar, texts, optional
/// action pill, chips and chevron.
class BrandedActivityFeedItem extends StatelessWidget {
  const BrandedActivityFeedItem({
    super.key,
    required this.primaryText,
    required this.secondaryText,
    this.tertiaryText,
    this.actionLabel,
    this.actionColor,
    this.leadingIcon,
    this.avatarInitials,
    this.onTap,
    this.showChevron = true,
    this.trailingChips,
  });

  /// Top line (white, w600, 14).
  final String primaryText;

  /// Middle line (white70, 13).
  final String secondaryText;

  /// Optional third line (white60, 11).
  final String? tertiaryText;

  /// Uppercase pill text on the right. If null, no pill is rendered.
  final String? actionLabel;

  /// Optional pill background color. Defaults to white-20%.
  final Color? actionColor;

  /// Optional icon for the leading avatar. Takes precedence over
  /// [avatarInitials].
  final IconData? leadingIcon;

  /// Optional initials (1-2 chars) when no [leadingIcon] is set.
  final String? avatarInitials;

  /// Tap handler for the whole row.
  final VoidCallback? onTap;

  /// Show the trailing chevron. Defaults to true.
  final bool showChevron;

  /// Optional chip widgets rendered in a [Wrap] below the texts.
  final List<Widget>? trailingChips;

  Widget _buildAvatar() {
    if (leadingIcon != null) {
      return Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: BrandColors.unityBlue,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(leadingIcon, color: Colors.white, size: 18),
      );
    }
    if (avatarInitials != null && avatarInitials!.isNotEmpty) {
      return Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: BrandColors.unityBlue,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          avatarInitials!,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      );
    }
    return Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(
        color: BrandColors.unityBlue,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.person, color: Colors.white, size: 18),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      primaryText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      secondaryText,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (tertiaryText != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        tertiaryText!,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (trailingChips != null && trailingChips!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: trailingChips!,
                      ),
                    ],
                  ],
                ),
              ),
              if (actionLabel != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: actionColor ?? Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    actionLabel!.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
              if (showChevron) ...[
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right,
                  color: Colors.white54,
                  size: 18,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
