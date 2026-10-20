import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

enum AppButtonVariant { primary, secondary, text }

/// Tombol aplikasi (DESIGN_SYSTEM.md §5).
///
/// * `primary`: pill biru penuh lebar + bayangan biru, panah opsional.
/// * `loading`: spinner + "Memproses…", tidak bisa diklik (mencegah klik ganda).
/// * `onPressed == null`: disabled.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.loading = false,
    this.trailingArrow = false,
    this.loadingLabel = 'Memproses…',
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool loading;
  final bool trailingArrow;
  final String loadingLabel;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = loading ? null : onPressed;
    final content = _ButtonContent(
      label: loading ? loadingLabel : label,
      loading: loading,
      trailingArrow: trailingArrow && !loading,
      spinnerColor: variant == AppButtonVariant.primary
          ? AppColors.onPrimary
          : AppColors.primary,
      // Text button bisa berada di Row tanpa batas lebar → tanpa Flexible.
      flexibleLabel: variant != AppButtonVariant.text,
    );

    final Widget button = switch (variant) {
      AppButtonVariant.primary => FilledButton(
          onPressed: effectiveOnPressed,
          // Tetap biru saat loading (bukan abu-abu disabled bawaan M3).
          style: FilledButton.styleFrom(
            disabledBackgroundColor: AppColors.primary.withValues(
              alpha: loading ? 0.85 : 0.6,
            ),
            disabledForegroundColor: AppColors.onPrimary,
          ),
          child: content,
        ),
      AppButtonVariant.secondary => FilledButton.tonal(
          onPressed: effectiveOnPressed,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(AppSizes.primaryButtonHeight),
            shape: const StadiumBorder(),
          ),
          child: content,
        ),
      AppButtonVariant.text => TextButton(
          onPressed: effectiveOnPressed,
          child: content,
        ),
    };

    return Semantics(
      // Diumumkan pembaca layar saat berubah menjadi "Memproses…".
      liveRegion: loading,
      child: variant == AppButtonVariant.primary
          ? DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                boxShadow: effectiveOnPressed == null && !loading
                    ? null
                    : AppShadows.primaryButton,
              ),
              child: SizedBox(width: double.infinity, child: button),
            )
          : button,
    );
  }
}

class _ButtonContent extends StatelessWidget {
  const _ButtonContent({
    required this.label,
    required this.loading,
    required this.trailingArrow,
    required this.spinnerColor,
    required this.flexibleLabel,
  });

  final String label;
  final bool loading;
  final bool trailingArrow;
  final Color spinnerColor;
  final bool flexibleLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading) ...[
          SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: spinnerColor,
              semanticsLabel: 'Memuat',
            ),
          ),
          const SizedBox(width: AppSpacing.md),
        ],
        if (flexibleLabel)
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          )
        else
          Text(label),
        if (trailingArrow) ...[
          const SizedBox(width: AppSpacing.sm),
          // Dekoratif: label sudah menjelaskan aksi.
          const ExcludeSemantics(child: Icon(Icons.arrow_forward, size: 20)),
        ],
      ],
    );
  }
}
