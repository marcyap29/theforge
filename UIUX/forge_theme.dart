import 'package:flutter/material.dart';

/// The Forge palette, from `The-Forge_Design-Language_v1.md`.
///
/// The mapping that matters, and that the app icon already teaches:
///   brass = done,  ember = happening now,  steel = not yet,  rust = trouble.
/// Keep that consistent everywhere and the icon reads as a legend for the UI.
abstract final class ForgeColors {
  // Ground
  static const navy = Color(0xFF0E1B2E);
  static const navyLift = Color(0xFF152A40);
  static const navyDeep = Color(0xFF08131F);

  // Metals
  static const brass = Color(0xFFA9793F);
  static const brassLo = Color(0xFF8A6234);
  static const steel = Color(0xFF6C7C88);
  static const steelDim = Color(0xFF47555F);
  static const ivory = Color(0xFFEFE7D8);

  // Heat
  static const emberHi = Color(0xFFFFC46B);
  static const ember = Color(0xFFFF7A2F);
  static const emberLo = Color(0xFFB4451C);

  // Trouble. NOT in design language v1 — added here, fold it into v2.
  static const rust = Color(0xFF7A3826);
  static const rustLit = Color(0xFFA85138);

  // Lines. Elevation is a surface swap, never a drop shadow.
  static const hairline = Color(0x1AEFE7D8);
  static const hairlineStrong = Color(0x29EFE7D8);
  static const surface = Color(0x08EFE7D8);
}

/// Drop-in replacement for `AppTheme.dark` in `lib/core/theme/app_theme.dart`.
///
/// Swaps the old #0F0F10 / #E8A04C scheme for the navy + ember system. If you
/// want to stage this, keep `AppTheme.dark` around and point `TheForgeApp` at
/// `ForgeTheme.dark` only when you're ready for the whole app to change.
class ForgeTheme {
  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      colorScheme: const ColorScheme.dark(
        primary: ForgeColors.ember,
        onPrimary: ForgeColors.navyDeep,
        secondary: ForgeColors.brass,
        onSecondary: ForgeColors.navyDeep,
        surface: ForgeColors.navy,
        onSurface: ForgeColors.ivory,
        error: ForgeColors.rustLit,
        onError: ForgeColors.ivory,
        outline: ForgeColors.hairlineStrong,
      ),
      scaffoldBackgroundColor: ForgeColors.navy,
      appBarTheme: const AppBarTheme(
        backgroundColor: ForgeColors.navyDeep,
        foregroundColor: ForgeColors.ivory,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: ForgeColors.ivory,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
      cardTheme: const CardThemeData(
        color: ForgeColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(5)),
          side: BorderSide(color: ForgeColors.hairline, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: ForgeColors.hairline,
        space: 1,
        thickness: 1,
      ),
      listTileTheme: const ListTileThemeData(
        textColor: ForgeColors.ivory,
        iconColor: ForgeColors.steel,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ForgeColors.ember,
          foregroundColor: ForgeColors.navyDeep,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(3)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          textStyle: const TextStyle(
            fontFamily: 'Menlo',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ForgeColors.steel,
          side: const BorderSide(color: ForgeColors.hairlineStrong),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(3)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          textStyle: const TextStyle(
            fontFamily: 'Menlo',
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.1,
          ),
        ),
      ),
      textTheme: base.textTheme.copyWith(
        // Display / headings. Unbounded once it's bundled — see the notes file.
        headlineSmall: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.4,
          color: ForgeColors.ivory,
          height: 1.2,
        ),
        titleLarge: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: ForgeColors.ivory,
        ),
        titleMedium: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: ForgeColors.ivory,
          letterSpacing: -0.1,
        ),
        bodyLarge: const TextStyle(fontSize: 15, color: ForgeColors.ivory),
        bodyMedium: const TextStyle(fontSize: 14, color: ForgeColors.steel),
        bodySmall: const TextStyle(fontSize: 13, color: ForgeColors.steelDim),
        // Utility: counters, timestamps, labels. Tabular so digits don't jitter.
        labelSmall: const TextStyle(
          fontFamily: 'Menlo',
          fontSize: 10,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.4,
          color: ForgeColors.steel,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
        labelMedium: const TextStyle(
          fontFamily: 'Menlo',
          fontSize: 11,
          letterSpacing: 0.6,
          color: ForgeColors.steel,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
