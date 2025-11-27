import 'package:flutter/material.dart';

/// Premium dark theme for the email campaign builder
/// Inspired by Mailchimp's professional interface with MOYD branding
class CampaignBuilderTheme {
  // MOYD Brand Colors
  static const Color moyDBlue = Color(0xFF1E3A8A); // Primary brand blue
  static const Color brightBlue = Color(0xFF3B82F6); // Accent blue
  static const Color successGreen = Color(0xFF10B981); // Success actions
  static const Color warningOrange = Color(0xFFF59E0B); // Warnings
  static const Color errorRed = Color(0xFFEF4444); // Errors

  // Dark Theme Colors
  static const Color darkNavy = Color(0xFF0F172A); // Main background
  static const Color slate = Color(0xFF1E293B); // Surface/cards
  static const Color slateLight = Color(0xFF334155); // Borders/dividers
  static const Color slateLighter = Color(0xFF475569); // Hover states

  // Light Theme Colors (for email canvas)
  static const Color lightGray = Color(0xFFF8FAFC);
  static const Color white = Color(0xFFFFFFFF);
  static const Color offWhite = Color(0xFFFAFAFA);

  // Text Colors (Dark Theme)
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFCBD5E1);
  static const Color textTertiary = Color(0xFF94A3B8);

  /// Get the premium dark theme for campaign builder
  static ThemeData get darkTheme => ThemeData.dark().copyWith(
        useMaterial3: true,
        scaffoldBackgroundColor: darkNavy,
        primaryColor: moyDBlue,
        colorScheme: const ColorScheme.dark(
          primary: moyDBlue,
          secondary: brightBlue,
          surface: slate,
          background: darkNavy,
          error: errorRed,
          onPrimary: textPrimary,
          onSecondary: textPrimary,
          onSurface: textPrimary,
          onBackground: textPrimary,
        ),

        // App Bar Theme
        appBarTheme: const AppBarTheme(
          backgroundColor: slate,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: textPrimary),
        ),

        // Card Theme
        cardTheme: CardTheme(
          color: slate,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: slateLight, width: 1),
          ),
          margin: EdgeInsets.zero,
        ),

        // Elevated Button Theme
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: moyDBlue,
            foregroundColor: textPrimary,
            elevation: 0,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ),

        // Outlined Button Theme
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: textPrimary,
            side: const BorderSide(color: slateLight, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ),

        // Text Button Theme
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: brightBlue,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // Input Decoration Theme
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: darkNavy,
          hoverColor: slateLight.withOpacity(0.1),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: slateLight, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: slateLight, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: moyDBlue, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: errorRed, width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: errorRed, width: 2),
          ),
          labelStyle: const TextStyle(color: textSecondary, fontSize: 14),
          hintStyle: const TextStyle(color: textTertiary, fontSize: 14),
          errorStyle: const TextStyle(color: errorRed, fontSize: 12),
        ),

        // Chip Theme
        chipTheme: ChipThemeData(
          backgroundColor: slateLight,
          selectedColor: moyDBlue.withOpacity(0.3),
          secondarySelectedColor: moyDBlue.withOpacity(0.3),
          disabledColor: slateLight.withOpacity(0.5),
          labelStyle: const TextStyle(color: textPrimary, fontSize: 13),
          secondaryLabelStyle: const TextStyle(color: textPrimary, fontSize: 13),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          checkmarkColor: moyDBlue,
          iconTheme: const IconThemeData(color: textPrimary, size: 18),
        ),

        // Divider Theme
        dividerTheme: const DividerThemeData(
          color: slateLight,
          thickness: 1,
          space: 1,
        ),

        // Icon Theme
        iconTheme: const IconThemeData(
          color: textSecondary,
          size: 24,
        ),

        // Text Theme
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            color: textPrimary,
            fontSize: 32,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
          displayMedium: TextStyle(
            color: textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
          displaySmall: TextStyle(
            color: textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.3,
          ),
          headlineLarge: TextStyle(
            color: textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
          headlineMedium: TextStyle(
            color: textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          headlineSmall: TextStyle(
            color: textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          titleLarge: TextStyle(
            color: textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          titleMedium: TextStyle(
            color: textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          titleSmall: TextStyle(
            color: textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: TextStyle(
            color: textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.normal,
            height: 1.5,
          ),
          bodyMedium: TextStyle(
            color: textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.normal,
            height: 1.5,
          ),
          bodySmall: TextStyle(
            color: textTertiary,
            fontSize: 12,
            fontWeight: FontWeight.normal,
            height: 1.4,
          ),
          labelLarge: TextStyle(
            color: textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
          labelMedium: TextStyle(
            color: textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          labelSmall: TextStyle(
            color: textTertiary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),

        // Tooltip Theme
        tooltipTheme: TooltipThemeData(
          decoration: BoxDecoration(
            color: slate,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: slateLight),
          ),
          textStyle: const TextStyle(
            color: textPrimary,
            fontSize: 13,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),

        // Progress Indicator Theme
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: brightBlue,
          linearTrackColor: slateLight,
          circularTrackColor: slateLight,
        ),

        // Snackbar Theme
        snackBarTheme: SnackBarThemeData(
          backgroundColor: slate,
          contentTextStyle: const TextStyle(
            color: textPrimary,
            fontSize: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: slateLight),
          ),
          behavior: SnackBarBehavior.floating,
        ),

        // Dialog Theme
        dialogTheme: DialogTheme(
          backgroundColor: slate,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: slateLight),
          ),
          titleTextStyle: const TextStyle(
            color: textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          contentTextStyle: const TextStyle(
            color: textSecondary,
            fontSize: 14,
            height: 1.5,
          ),
        ),

        // List Tile Theme
        listTileTheme: const ListTileThemeData(
          tileColor: slate,
          selectedTileColor: moyDBlue,
          textColor: textPrimary,
          iconColor: textSecondary,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      );

  /// Get success button style
  static ButtonStyle get successButtonStyle => ElevatedButton.styleFrom(
        backgroundColor: successGreen,
        foregroundColor: textPrimary,
      );

  /// Get warning button style
  static ButtonStyle get warningButtonStyle => ElevatedButton.styleFrom(
        backgroundColor: warningOrange,
        foregroundColor: darkNavy,
      );

  /// Get error/danger button style
  static ButtonStyle get dangerButtonStyle => ElevatedButton.styleFrom(
        backgroundColor: errorRed,
        foregroundColor: textPrimary,
      );

  /// Get gradient overlay for premium cards
  static Decoration get premiumGradientDecoration => BoxDecoration(
        gradient: const LinearGradient(
          colors: [moyDBlue, brightBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: moyDBlue.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      );

  /// Get glass morphism effect decoration
  static Decoration get glassMorphismDecoration => BoxDecoration(
        color: slate.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: slateLight.withOpacity(0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      );

  /// Get shimmer loading effect colors
  static const List<Color> shimmerColors = [
    slateLight,
    slate,
    slateLight,
  ];
}
