import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

/// Kartu putih radius 24 + bayangan lembut, lebar maks 480 (AUTH spec §1.2).
class AuthCard extends StatelessWidget {
  const AuthCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.xl,
      AppSpacing.xl,
      AppSpacing.xl,
      AppSpacing.xl,
    ),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AppSizes.authMaxWidth),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.authCard)),
          boxShadow: AppShadows.authCard,
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
