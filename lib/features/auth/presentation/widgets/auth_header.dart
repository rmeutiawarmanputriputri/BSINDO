import 'package:flutter/material.dart';

import '../../../../app/theme/tokens.dart';
import '../../../../core/widgets/brand_logo.dart';

/// Logo + teks "BISINDO" (+ judul/subjudul opsional) di atas kartu.
class AuthHeader extends StatelessWidget {
  const AuthHeader({
    super.key,
    required this.logoSize,
    required this.wordmarkSize,
    this.wordmarkLetterSpacing = 0,
    this.title,
    this.subtitle,
  });

  final double logoSize;
  final double wordmarkSize;
  final double wordmarkLetterSpacing;
  final String? title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Logo mengecil di layar pendek (AUTH spec §5.2: clamp).
    final screenHeight = MediaQuery.sizeOf(context).height;
    final scale = (screenHeight / 800).clamp(0.75, 1.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandLogoIcon(size: logoSize * scale),
        const SizedBox(height: AppSpacing.sm),
        BrandWordmark(
          color: AppColors.primary,
          fontSize: wordmarkSize,
          letterSpacing: wordmarkLetterSpacing,
        ),
        if (title != null) ...[
          const SizedBox(height: AppSpacing.md),
          Semantics(
            header: true,
            child: Text(
              title!,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
          ),
        ],
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}
