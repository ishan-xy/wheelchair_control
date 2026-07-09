import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFFF5F6FA);
  static const primary = Color(0xFF2D8C7E);
  static const primaryDark = Color(0xFF237A6B);
  static const danger = Color(0xFFD93025);
  static const warning = Color(0xFFF59E0B);
  static const title = Color(0xFF1A2340);
  static const border = Color(0xFFE0E2EA);
  static const surfaceAlt = Color(0xFFE8EAF0);
}

class AppTheme {
  static ThemeData get light => ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        scaffoldBackgroundColor: AppColors.background,
        useMaterial3: true,
        fontFamily: 'Roboto',
      );
}
