import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

/// Pembatas garis + teks, mis. "Atau masuk dengan" (≥ 12sp, A-3).
class OrDivider extends StatelessWidget {
  const OrDivider({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(text, style: Theme.of(context).textTheme.bodySmall),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

/// Satu tombol sosial persegi membulat (latar = isi input).
///
/// HANYA dirender bila `FeatureFlags.enableSocialAuth == true` (K-03).
/// Ikon resmi (Google/Facebook/Apple) wajib dari aset pemilik/brand
/// guideline — belum tersedia.
class SocialButton extends StatelessWidget {
  const SocialButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
  });

  final Widget icon;

  /// Mis. "Masuk dengan Google" (A-8).
  final String semanticLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Material(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(AppRadius.socialButton),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadius.socialButton),
          child: SizedBox(
            height: AppSizes.socialButtonHeight,
            child: Center(child: icon),
          ),
        ),
      ),
    );
  }
}

/// Deretan tombol sosial. Penyedia yang belum diintegrasikan tidak boleh
/// ditampilkan (aturan: tanpa tombol palsu).
class SocialButtonRow extends StatelessWidget {
  const SocialButtonRow({super.key, required this.buttons});

  final List<SocialButton> buttons;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < buttons.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.md),
          Expanded(child: buttons[i]),
        ],
      ],
    );
  }
}
