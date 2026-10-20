/// Validator form auth (AUTH_UI_DESIGN_SPEC.md §6).
/// Mengembalikan `null` bila valid, atau pesan error Bahasa Indonesia.
abstract final class Validators {
  static const fullNameMin = 2;
  static const fullNameMax = 80;
  static const passwordMin = 8;

  static final RegExp _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

  static String? fullName(String? value) {
    final v = (value ?? '').trim();
    if (v.length < fullNameMin) return 'Nama lengkap minimal 2 karakter.';
    // Batas atas tidak ada pesannya di spesifikasi; teks ini usulan.
    if (v.length > fullNameMax) return 'Nama lengkap maksimal 80 karakter.';
    return null;
  }

  static String? email(String? value) {
    final v = normalizeEmail(value ?? '');
    if (v.isEmpty || !_email.hasMatch(v)) {
      return 'Masukkan alamat email yang valid.';
    }
    return null;
  }

  /// Kata sandi saat mendaftar (≥ 8 karakter; tidak di-trim).
  static String? newPassword(String? value) {
    if ((value ?? '').length < passwordMin) {
      return 'Kata sandi minimal 8 karakter.';
    }
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if ((value ?? '') != password || (value ?? '').isEmpty) {
      return 'Konfirmasi kata sandi tidak sama.';
    }
    return null;
  }

  /// Kata sandi saat masuk: hanya wajib diisi.
  static String? loginPassword(String? value) {
    if ((value ?? '').isEmpty) return 'Masukkan kata sandi Anda.';
    return null;
  }
}

/// Email dinormalisasi: trim + huruf kecil.
String normalizeEmail(String raw) => raw.trim().toLowerCase();
