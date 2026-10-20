import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/tokens.dart';

/// Kerangka halaman auth (AUTH spec §5.2): gradien, SafeArea, scroll,
/// aman keyboard, lebar maks 480, footer di dasar layar bila ruang cukup
/// dan ikut ter-scroll bila layar pendek / keyboard terbuka.
///
/// Tidak memakai IntrinsicHeight: `ConstrainedBox(minHeight)` + `Column`
/// `spaceBetween` memberi hasil yang sama tanpa biaya layout intrinsik.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.body,
    this.footer,
    this.onBack,
  });

  /// Isi utama (logo, judul, kartu).
  final Widget body;

  /// Tautan bawah (mis. "Belum punya akun? Daftar").
  final Widget? footer;

  /// Bila diisi, panah kembali tampil di kiri atas.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Latar terang → ikon status bar gelap.
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: AppColors.bgGradientBottom,
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.bgGradientTop, AppColors.bgGradientBottom],
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pageHorizontal,
                ),
                // Center (lebar) → ConstrainedBox(maxWidth + minHeight) →
                // Column spaceBetween: footer menempel di bawah bila konten
                // lebih pendek dari layar.
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: AppSizes.authMaxWidth,
                      minHeight: constraints.maxHeight,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (onBack != null)
                              _BackButton(onPressed: onBack!)
                            else
                              const SizedBox(height: AppSpacing.xl),
                            body,
                          ],
                        ),
                        if (footer != null)
                          Padding(
                            padding: const EdgeInsets.only(
                              top: AppSpacing.xl,
                              bottom: AppSpacing.lg,
                            ),
                            child: footer,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        // Geser ke kiri agar ikon sejajar tepi konten seperti gambar,
        // tetapi area sentuh tetap 48×48dp.
        child: Transform.translate(
          offset: const Offset(-12, 0),
          child: IconButton(
            onPressed: onPressed,
            tooltip: 'Kembali',
            color: AppColors.textPrimary,
            icon: const Icon(Icons.arrow_back),
          ),
        ),
      ),
    );
  }
}
