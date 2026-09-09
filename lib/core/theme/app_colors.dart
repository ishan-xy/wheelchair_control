import 'package:flutter/material.dart';

class AppColors {
  static bool _lightMode = false;

  static void useLightMode(bool value) => _lightMode = value;
  static bool get isLightMode => _lightMode;

  static const ink = Color(0xFF03090B);
  static Color get background =>
      _lightMode ? const Color(0xFFF4F7F8) : const Color(0xFF071014);
  static Color get surface =>
      _lightMode ? Colors.white : const Color(0xFF101A1F);
  static Color get surfaceHigh =>
      _lightMode ? const Color(0xFFE7EEF1) : const Color(0xFF18242A);
  static Color get glass =>
      _lightMode ? const Color(0xE6FFFFFF) : const Color(0xCC111A1E);
  static Color get glassSoft =>
      _lightMode ? const Color(0x99FFFFFF) : const Color(0x99132126);
  static Color get border =>
      _lightMode ? const Color(0xFFCDD9DE) : const Color(0xFF263238);
  static Color get borderSoft =>
      _lightMode ? const Color(0xFFE0E8EB) : const Color(0xFF1B272C);

  static Color get text =>
      _lightMode ? const Color(0xFF102026) : const Color(0xFFF4F8FA);
  static Color get textMuted =>
      _lightMode ? const Color(0xFF52616A) : const Color(0xFFA3ADB5);
  static Color get textDim =>
      _lightMode ? const Color(0xFF74828A) : const Color(0xFF6F7980);

  static const accent = Color(0xFF56A9D4);
  static const accentDeep = Color(0xFF327FA8);
  static const success = Color(0xFF2ED58B);
  static const danger = Color(0xFFFF4655);
  static const warning = Color(0xFFF4B860);

  static const topGlow = Color(0xFF052E3A);
  static const calmBlue = Color(0xFF063342);

  static LinearGradient get appBackground => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          _lightMode ? const Color(0xFFE2F1F6) : const Color(0xFF062C38),
          background,
          background,
        ],
        stops: [0, 0.45, 1],
      );

  static LinearGradient get cardGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: _lightMode
            ? [Colors.white, const Color(0xFFF0F5F7)]
            : [const Color(0xFF10242C), const Color(0xFF0A1114)],
      );

  static LinearGradient get primaryGradient => const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [accent, accentDeep],
      );
}
