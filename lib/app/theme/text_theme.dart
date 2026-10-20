import 'package:flutter/material.dart';

import 'tokens.dart';

/// Keluarga font yang dibundel di `assets/fonts` (D-15, default K-04).
const String kAppFontFamily = 'Inter';

TextStyle _style(
  double size,
  FontWeight weight, {
  Color color = AppColors.textPrimary,
  double height = 1.4,
}) {
  return TextStyle(
    fontFamily: kAppFontFamily,
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
  );
}

/// Skala tipografi DESIGN_SYSTEM.md §2. Semua ukuran dalam sp (mengikuti
/// `TextScaler` pengguna). Minimum 12sp.
TextTheme buildAppTextTheme() {
  const secondary = AppColors.textSecondary;
  return TextTheme(
    displaySmall: _style(28, FontWeight.w700, height: 1.25),
    headlineSmall: _style(24, FontWeight.w700, height: 1.3),
    titleLarge: _style(20, FontWeight.w700, height: 1.3),
    titleMedium: _style(16, FontWeight.w600),
    titleSmall: _style(14, FontWeight.w600),
    bodyLarge: _style(16, FontWeight.w400, height: 1.5),
    bodyMedium: _style(14, FontWeight.w400, height: 1.45),
    bodySmall: _style(12, FontWeight.w400, color: secondary),
    labelLarge: _style(14, FontWeight.w700),
    labelMedium: _style(12, FontWeight.w600, height: 1.35),
    labelSmall: _style(12, FontWeight.w500, color: secondary, height: 1.35),
  );
}
