import 'package:flutter/material.dart';

class AppTheme {
  // Canvas & Surfaces
  static const Color background = Color(0xFF0D0F14);
  static const Color surface = Color(0xFF151821);
  static const Color surfaceElevated = Color(0xFF1E222F);
  static const Color surfaceHover = Color(0xFF262B3B);

  // Borders
  static const Color border = Color(0x1FFFFFFF); // 12% white
  static const Color borderSubtle = Color(0x0FFFFFFF); // 6% white
  static const Color borderActive = Color(0x4DFF0033);

  // Accents
  static const Color youtubeRed = Color(0xFFFF0033);
  static const Color youtubeRedLight = Color(0xFFFF3B5C);
  static const Color pinActive = Color(0xFFFFB800);
  static const Color pinActiveSurface = Color(0x24FFB800);
  static const Color accentCyan = Color(0xFF00E5FF);
  static const Color accentGreen = Color(0xFF00E676);

  // Typography Colors
  static const Color textPrimary = Color(0xFFF5F6FA);
  static const Color textSecondary = Color(0xFF9CA0B4);
  static const Color textMuted = Color(0xFF5D6175);

  // Gradient
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [youtubeRed, youtubeRedLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient headerGradient = LinearGradient(
    colors: [Color(0xFF181B26), Color(0xFF12141C)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: youtubeRed,
      colorScheme: const ColorScheme.dark(
        primary: youtubeRed,
        secondary: accentCyan,
        surface: surface,
      ),
      fontFamily: 'Segoe UI',
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        textStyle: const TextStyle(
          color: textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        waitDuration: const Duration(milliseconds: 300),
      ),
    );
  }
}
