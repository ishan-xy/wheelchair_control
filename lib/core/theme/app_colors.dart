import 'package:flutter/material.dart';

class AppColors {
  static const ink = Color(0xFF03090B);
  static const background = Color(0xFF071014);
  static const surface = Color(0xFF101A1F);
  static const surfaceHigh = Color(0xFF18242A);
  static const glass = Color(0xCC111A1E);
  static const glassSoft = Color(0x99132126);
  static const border = Color(0xFF263238);
  static const borderSoft = Color(0xFF1B272C);

  static const text = Color(0xFFF4F8FA);
  static const textMuted = Color(0xFFA3ADB5);
  static const textDim = Color(0xFF6F7980);

  static const accent = Color(0xFF56A9D4);
  static const accentDeep = Color(0xFF327FA8);
  static const success = Color(0xFF2ED58B);
  static const danger = Color(0xFFFF4655);
  static const warning = Color(0xFFF4B860);

  static const topGlow = Color(0xFF052E3A);
  static const calmBlue = Color(0xFF063342);

  static LinearGradient get appBackground => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF062C38), background, background],
        stops: [0, 0.45, 1],
      );

  static LinearGradient get cardGradient => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF10242C), Color(0xFF0A1114)],
      );

  static LinearGradient get primaryGradient => const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [accent, accentDeep],
      );
}
