// Copyright (C) 2026 AuraStudio Corporation • Pritam
// AuraResize - Unified Precision Design System & Minimalist Theme

import 'package:flutter/material.dart';

class SarkariTheme {
  SarkariTheme._();

  // Unified Precision Palette
  static const Color darkBackground = Color(0xFF0A0D14);
  static const Color surfaceCard = Color(0xFF121722);
  static const Color surfaceElevated = Color(0xFF19202E);
  static const Color surfaceBorder = Color(0xFF232B3E);

  // Unified Brand Accent: Precision Cyan
  static const Color cyanAccent = Color(0xFF00E5FF);
  static const Color cyanDim = Color(0xFF0097A7);
  static const Color emeraldAccent = Color(0xFF10B981);
  static const Color crimsonRed = Color(0xFFEF4444);

  // Muted Typography Colors
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  // Unified Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF00E5FF), Color(0xFF0284C7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF131926), Color(0xFF0F1420)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get themeData {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      primaryColor: cyanAccent,
      colorScheme: const ColorScheme.dark(
        primary: cyanAccent,
        secondary: cyanAccent,
        surface: surfaceCard,
        error: crimsonRed,
      ),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBackground,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: surfaceBorder, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceElevated,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: surfaceBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: surfaceBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: cyanAccent, width: 1.5),
        ),
      ),
    );
  }
}
