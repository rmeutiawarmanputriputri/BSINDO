import 'app_failure.dart';

/// Satu-satunya sumber pesan error untuk pengguna (Bahasa Indonesia).
/// Teks dari AUTH_UI_DESIGN_SPEC.md §6.
String failureMessage(AppFailure failure) {
  return switch (failure) {
    NetworkFailure() =>
      'Tidak ada koneksi. Periksa internet Anda lalu coba lagi.',
    AuthFailure(code: AuthFailureCode.invalidCredentials) =>
      'Email atau kata sandi salah.',
    AuthFailure(code: AuthFailureCode.emailNotConfirmed) =>
      'Email belum diverifikasi. Cek kotak masuk Anda.',
    AuthFailure(code: AuthFailureCode.emailAlreadyRegistered) =>
      'Email ini sudah terdaftar. Silakan masuk.',
    AuthFailure(code: AuthFailureCode.weakPassword) =>
      'Kata sandi terlalu lemah.',
    RateLimitFailure() =>
      'Terlalu banyak percobaan. Coba lagi beberapa saat lagi.',
    PermissionFailure() => 'Anda tidak memiliki akses untuk tindakan ini.',
    NotFoundFailure() => 'Data tidak ditemukan.',
    ValidationFailure() => 'Data yang dikirim tidak valid.',
    UnknownFailure() => 'Terjadi kesalahan. Coba lagi.',
  };
}
