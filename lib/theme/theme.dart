import 'package:flutter/material.dart';
import 'accent_provider.dart';

ThemeData buildDarkTheme(AppAccent accent) => ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      colorScheme: ColorScheme.dark(
        primary: accent.accentDark,
        secondary: accent.accent,
        surface: const Color(0xFF1E293B),
        error: const Color(0xFFEF4444),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Color(0xFFE2E8F0),
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: Color(0xFF94A3B8)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent.accentDark,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Color(0xFF1E293B),
        contentTextStyle: TextStyle(color: Color(0xFFE2E8F0)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      dividerColor: Colors.white10,
      iconTheme: const IconThemeData(color: Color(0xFF94A3B8)),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Color(0xFFE2E8F0)),
        bodyMedium: TextStyle(color: Color(0xFF94A3B8)),
        bodySmall: TextStyle(color: Color(0xFF64748B)),
      ),
    );

// Keep for backwards compatibility
final darkTheme = buildDarkTheme(appAccents[0]);
