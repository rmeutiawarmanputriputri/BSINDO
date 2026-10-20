import 'package:flutter/material.dart';

import 'text_theme.dart';
import 'tokens.dart';

/// Tema Material 3 terang (DESIGN_SYSTEM.md §7). ColorScheme eksplisit agar
/// warna persis token, bukan hasil `fromSeed` murni.
ThemeData buildAppTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
  ).copyWith(
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    secondary: AppColors.primary,
    onSecondary: AppColors.onPrimary,
    tertiary: AppColors.accent,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    onSurfaceVariant: AppColors.textSecondary,
    surfaceContainerHighest: AppColors.inputFill,
    error: AppColors.error,
    onError: Colors.white,
    errorContainer: AppColors.errorContainer,
    onErrorContainer: AppColors.error,
    outline: AppColors.textSecondary,
    outlineVariant: AppColors.outline,
  );

  final textTheme = buildAppTextTheme();

  const inputRadius = BorderRadius.all(Radius.circular(AppRadius.input));
  const noBorder = OutlineInputBorder(
    borderRadius: inputRadius,
    borderSide: BorderSide.none,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    fontFamily: kAppFontFamily,
    textTheme: textTheme,
    scaffoldBackgroundColor: AppColors.surface,
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: AppColors.inputFill,
      hintStyle: textTheme.bodyMedium?.copyWith(
        color: AppColors.textPlaceholder,
      ),
      // Tinggi 52dp: 14 (font) * 1.45 ≈ 20 + 2 * 16 padding.
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      constraints: const BoxConstraints(minHeight: AppSizes.inputHeight),
      border: noBorder,
      enabledBorder: noBorder,
      disabledBorder: noBorder,
      focusedBorder: const OutlineInputBorder(
        borderRadius: inputRadius,
        borderSide: BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: inputRadius,
        borderSide: BorderSide(color: AppColors.error, width: 1.5),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: inputRadius,
        borderSide: BorderSide(color: AppColors.error, width: 2),
      ),
      suffixIconColor: AppColors.textSecondary,
    ),
    filledButtonTheme: FilledButtonThemeData(
      // Warna dibiarkan dari ColorScheme (primary/onPrimary) agar varian
      // tonal tetap tonal. Lebar penuh & warna saat loading diatur AppButton.
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, AppSizes.primaryButtonHeight),
        shape: const StadiumBorder(),
        textStyle: textTheme.labelLarge?.copyWith(fontSize: 16),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        minimumSize: const Size(AppSizes.minTapTarget, AppSizes.minTapTarget),
        textStyle: textTheme.labelLarge,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(AppSizes.minTapTarget, AppSizes.minTapTarget),
      ),
    ),
    cardTheme: const CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.contentCard)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.textPrimary,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.input)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.primary.withValues(alpha: 0.12),
      labelTextStyle: WidgetStatePropertyAll(textTheme.labelMedium),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.outline,
      thickness: 1,
    ),
  );
}
