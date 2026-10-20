import 'package:flutter/material.dart';

/// SATU-SATUNYA tempat nilai desain (DESIGN_SYSTEM.md). Ubah di sini saja.
///
/// Status nilai: ESTIMASI dari gambar referensi (K-04). Warna diukur dengan
/// color picker pada `docs/design/reference/*.png` (2026-10-20); nilai yang
/// berbeda dari estimasi DESIGN_SYSTEM.md diberi komentar.
abstract final class AppColors {
  /// Latar Splash. Gambar: #1C45B9 (doc: ≈ #1C44B7).
  static const brandDeep = Color(0xFF1C45B9);

  /// Tombol utama, tautan, teks "BISINDO". Gambar: #1A56CF (doc: ≈ #1B57CF).
  static const primary = Color(0xFF1A56CF);
  static const onPrimary = Color(0xFFFFFFFF);

  /// Aksen oranye logo — hanya ilustrasi/ikon, bukan teks kecil.
  static const accent = Color(0xFFF4A62A);

  /// Gradien halaman auth. Gambar (atas): #E6EFFC (doc: ≈ #DCE8FF, lebih gelap
  /// dari gambar → mengikuti gambar sesuai hierarki §0).
  static const bgGradientTop = Color(0xFFE6EFFC);

  /// Gambar (bawah): #F9FAFE (doc: ≈ #F8FAFF).
  static const bgGradientBottom = Color(0xFFF9FAFE);

  static const surface = Color(0xFFFFFFFF);

  /// Isi input & tombol sosial. Gambar: #EDF3FA–#F0F4F7 (doc: ≈ #EEF2F7).
  static const inputFill = Color(0xFFEEF2F7);

  static const textPrimary = Color(0xFF0F172A);

  /// Lebih gelap dari gambar (#64748B / #59606C) demi keterbacaan (A-2).
  static const textSecondary = Color(0xFF475569);

  /// Deviasi A-1: gambar ≈ #929AA1 (kontras 2,54:1 → gagal).
  /// #5A6A82 di atas [inputFill] = 4,89:1 (dihitung, lolos AA).
  static const textPlaceholder = Color(0xFF5A6A82);

  /// Garis pembatas dekoratif (bukan informasi).
  static const outline = Color(0xFFCBD5E1);

  // Semantik
  static const success = Color(0xFF15803D);
  static const onSuccess = Color(0xFFFFFFFF);
  static const warning = Color(0xFFB45309);
  static const error = Color(0xFFB3261B);
  static const errorContainer = Color(0xFFFDECEA);
  static const info = primary;
}

/// Grid 4dp.
abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;

  /// Padding horizontal halaman auth (AUTH spec §5.2).
  static const pageHorizontal = 20.0;
}

abstract final class AppRadius {
  static const input = 14.0;
  static const authCard = 24.0;
  static const contentCard = 16.0;
  static const video = 16.0;
  static const pill = 999.0;

  /// Tombol sosial "persegi membulat" (gambar ≈ 12).
  static const socialButton = 12.0;
}

/// Ukuran kontrol (standar baru, deviasi A-4 / I-3).
abstract final class AppSizes {
  static const inputHeight = 52.0;
  static const primaryButtonHeight = 52.0;
  static const socialButtonHeight = 48.0;
  static const minTapTarget = 48.0;
  static const icon = 24.0;

  /// Lebar maksimum konten form/auth.
  static const authMaxWidth = 480.0;

  /// Logo Login lebih besar, Register lebih kecil (I-5, [KONFIRMASI]).
  static const loginLogo = 56.0;
  static const registerLogo = 32.0;
}

abstract final class AppShadows {
  /// Kartu auth: blur 24, y 8, opacity ≈ 8%.
  static const authCard = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  /// Bayangan biru halus tombol utama.
  static const primaryButton = [
    BoxShadow(
      color: Color(0x401A56CF),
      blurRadius: 16,
      offset: Offset(0, 6),
    ),
  ];
}

abstract final class AppDurations {
  /// Durasi minimum Splash agar tidak berkedip (AUTH spec §5.1).
  static const splashMinimum = Duration(milliseconds: 600);
}
