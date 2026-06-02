import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    const primary = Color(0xFFE8A04C);
    const surface = Color(0xFF1C1C1E);
    const background = Color(0xFF0F0F10);
    const onSurface = Color(0xFFE5E5E7);
    const border = Color(0xFF2C2C2E);

    return base.copyWith(
      colorScheme: const ColorScheme.dark(
        primary: primary,
        onPrimary: background,
        surface: surface,
        onSurface: onSurface,
        error: Color(0xFFE06C75),
      ),
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: onSurface,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: const CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(6)),
          side: BorderSide(color: border, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        space: 1,
        thickness: 1,
      ),
      listTileTheme: const ListTileThemeData(
        textColor: onSurface,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: background,
      ),
      textTheme: base.textTheme.copyWith(
        bodyLarge: const TextStyle(fontFamily: 'Menlo', fontSize: 14),
        bodyMedium: const TextStyle(fontFamily: 'Menlo', fontSize: 13),
        bodySmall: const TextStyle(fontFamily: 'Menlo', fontSize: 12),
        titleLarge: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
        labelSmall: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          fontFamily: 'Menlo',
        ),
      ),
    );
  }
}
