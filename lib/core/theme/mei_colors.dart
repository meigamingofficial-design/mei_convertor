import 'package:flutter/material.dart';

/// Mei Convertor — Core Color Palette
/// Japanese-inspired minimalism: soft whites, sakura pinks, calm grays
abstract final class MeiColors {
  // === Base ===
  static const Color white = Color(0xFFFFFFFF);
  static const Color offWhite = Color(0xFFF9F7F5);
  static const Color warmWhite = Color(0xFFFAF8F6);
  static const Color surface = Color(0xFFF5F3F0);
  static const Color surfaceVariant = Color(0xFFEDEBE8);

  // === Sakura Pink (Primary) ===
  static const Color sakura = Color(0xFFE8A0B4);
  static const Color sakuraLight = Color(0xFFF2C5D4);
  static const Color sakuraLighter = Color(0xFFFAECF1);
  static const Color sakuraDark = Color(0xFFD4789A);
  static const Color sakuraDeep = Color(0xFFC05A82);

  // === Lavender (Secondary) ===
  static const Color lavender = Color(0xFFB8AECC);
  static const Color lavenderLight = Color(0xFFD4CEE4);
  static const Color lavenderLighter = Color(0xFFEEEBF5);
  static const Color lavenderDark = Color(0xFF9A8FB4);

  // === Neutral Grays ===
  static const Color gray50 = Color(0xFFF8F7F5);
  static const Color gray100 = Color(0xFFEFEDEA);
  static const Color gray200 = Color(0xFFE0DDD9);
  static const Color gray300 = Color(0xFFC8C5C0);
  static const Color gray400 = Color(0xFFAEAAA4);
  static const Color gray500 = Color(0xFF8E8A84);
  static const Color gray600 = Color(0xFF6E6A65);
  static const Color gray700 = Color(0xFF4E4B47);
  static const Color gray800 = Color(0xFF332F2C);
  static const Color gray900 = Color(0xFF1C1A18);

  // === Semantic ===
  static const Color textPrimary = Color(0xFF1C1A18);
  static const Color textSecondary = Color(0xFF6E6A65);
  static const Color textTertiary = Color(0xFFAEAAA4);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  static const Color border = Color(0xFFE8E5E1);
  static const Color borderStrong = Color(0xFFD0CCC8);
  static const Color divider = Color(0xFFF0EDE9);

  static const Color success = Color(0xFF6BAE7F);
  static const Color successLight = Color(0xFFD4EBD9);
  static const Color error = Color(0xFFD4756A);
  static const Color errorLight = Color(0xFFF5DDD9);
  static const Color warning = Color(0xFFDBAD6A);
  static const Color warningLight = Color(0xFFF5E9D4);

  // === Shadows ===
  static const Color shadowSoft = Color(0x0A1C1A18);
  static const Color shadowMedium = Color(0x141C1A18);
  static const Color shadowStrong = Color(0x201C1A18);

  // === Feature Colors ===
  static const Color pdfRed = Color(0xFFE87A6A);
  static const Color pdfRedLight = Color(0xFFFAEAE8);
  static const Color pdfRedDeep = Color(0xFFC04B3B);
  static const Color imageBlue = Color(0xFF7AAED4);
  static const Color imageBlueLight = Color(0xFFE8F2FA);
  static const Color imageBlueDeep = Color(0xFF3B7AA8);
  static const Color docGreen = Color(0xFF7AB88A);
  static const Color docGreenLight = Color(0xFFE8F5EC);
  static const Color docGreenDeep = Color(0xFF3B8250);
  static const Color convertPurple = Color(0xFF9A8FB4);
  static const Color convertPurpleLight = Color(0xFFEEEBF5);
  static const Color convertPurpleDeep = Color(0xFF6B5C8D);
}
