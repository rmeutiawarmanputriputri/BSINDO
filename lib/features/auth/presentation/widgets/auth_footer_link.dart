import 'package:flutter/material.dart';

import '../../../../app/theme/tokens.dart';

/// Footer tautan silang, mis. "Belum punya akun? **Daftar**".
/// Tautan memakai TextButton → area sentuh ≥ 48dp (A-7).
class AuthFooterLink extends StatelessWidget {
  const AuthFooterLink({
    super.key,
    required this.prompt,
    required this.action,
    required this.onPressed,
  });

  final String prompt;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(prompt, style: theme.textTheme.bodyMedium),
        TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs + 2),
            textStyle: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          child: Text(action),
        ),
      ],
    );
  }
}
