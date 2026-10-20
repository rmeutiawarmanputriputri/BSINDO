import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

// TODO(K-01): ganti placeholder dengan aset resmi pemilik di `assets/brand/`
// (logo_icon.svg / logo_wordmark_white.svg). JANGAN menggambar ulang logo
// dari gambar referensi. Setelah aset ada, gunakan SvgPicture.asset(...)
// dengan semanticsLabel 'Logo BISINDO'.

/// PLACEHOLDER ikon logo untuk Login/Register.
///
/// Memakai ikon generik Material `sign_language` — BUKAN logo BISINDO.
class BrandLogoIcon extends StatelessWidget {
  const BrandLogoIcon({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Logo BISINDO',
      image: true,
      child: ExcludeSemantics(
        child: Icon(
          Icons.sign_language,
          size: size,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

/// PLACEHOLDER wordmark: teks "BISINDO" (K-01 default).
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({
    super.key,
    required this.color,
    required this.fontSize,
    this.letterSpacing = 0,
    this.semanticLabel,
  });

  final Color color;
  final double fontSize;
  final double letterSpacing;

  /// Bila null, teks dibaca apa adanya ("BISINDO").
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Text(
      'BISINDO',
      textAlign: TextAlign.center,
      semanticsLabel: semanticLabel,
      style: TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: fontSize,
        letterSpacing: letterSpacing,
        color: color,
        height: 1.15,
      ),
    );
  }
}
