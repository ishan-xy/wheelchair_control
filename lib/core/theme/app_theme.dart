import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'typography.dart';

class AppTheme {
  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.dark,
      surface: AppColors.surface,
      error: AppColors.danger,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: AppTypography.fontFamily,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: scheme.copyWith(
        primary: AppColors.accent,
        secondary: AppColors.accentDeep,
        surface: AppColors.surface,
      ),
      textTheme: AppTypography.textTheme,
      splashColor: AppColors.accent.withValues(alpha: 0.08),
      highlightColor: Colors.white.withValues(alpha: 0.03),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.accent,
        inactiveTrackColor: Colors.white.withValues(alpha: 0.18),
        thumbColor: AppColors.accent,
        overlayColor: AppColors.accent.withValues(alpha: 0.12),
        trackHeight: 6,
      ),
    );
  }
}
