import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTypography {
  static const fontFamily = 'Roboto';

  static TextTheme get textTheme => const TextTheme(
        displayLarge: TextStyle(
          fontSize: 48,
          height: 1,
          fontWeight: FontWeight.w800,
          color: AppColors.text,
          letterSpacing: 0,
        ),
        headlineLarge: TextStyle(
          fontSize: 34,
          height: 1.1,
          fontWeight: FontWeight.w800,
          color: AppColors.text,
          letterSpacing: 0,
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          height: 1.15,
          fontWeight: FontWeight.w800,
          color: AppColors.text,
          letterSpacing: 0,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          height: 1.2,
          fontWeight: FontWeight.w700,
          color: AppColors.text,
          letterSpacing: 0,
        ),
        titleMedium: TextStyle(
          fontSize: 17,
          height: 1.25,
          fontWeight: FontWeight.w700,
          color: AppColors.text,
          letterSpacing: 0,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          height: 1.45,
          fontWeight: FontWeight.w500,
          color: AppColors.textMuted,
          letterSpacing: 0,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          height: 1.35,
          fontWeight: FontWeight.w500,
          color: AppColors.textMuted,
          letterSpacing: 0,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          height: 1.2,
          fontWeight: FontWeight.w800,
          color: AppColors.text,
          letterSpacing: 0,
        ),
      );

  static const overline = TextStyle(
    color: AppColors.textMuted,
    fontSize: 13,
    fontWeight: FontWeight.w800,
    letterSpacing: 6,
  );
}
