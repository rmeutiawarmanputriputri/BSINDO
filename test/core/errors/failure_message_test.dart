import 'package:bisindo_app/core/errors/app_failure.dart';
import 'package:bisindo_app/core/errors/failure_message.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bagian dari AUTH-05 (pesan). Pemetaan exception Supabase → AppFailure
/// diuji pada Fase 3 saat repository Supabase dibuat.
void main() {
  test('pesan auth sesuai AUTH spec §6', () {
    expect(
      failureMessage(const AuthFailure(AuthFailureCode.invalidCredentials)),
      'Email atau kata sandi salah.',
    );
    expect(
      failureMessage(const AuthFailure(AuthFailureCode.emailNotConfirmed)),
      'Email belum diverifikasi. Cek kotak masuk Anda.',
    );
    expect(
      failureMessage(const AuthFailure(AuthFailureCode.emailAlreadyRegistered)),
      'Email ini sudah terdaftar. Silakan masuk.',
    );
    expect(
      failureMessage(const AuthFailure(AuthFailureCode.weakPassword)),
      'Kata sandi terlalu lemah.',
    );
    expect(
      failureMessage(const RateLimitFailure()),
      'Terlalu banyak percobaan. Coba lagi beberapa saat lagi.',
    );
    expect(
      failureMessage(const NetworkFailure()),
      'Tidak ada koneksi. Periksa internet Anda lalu coba lagi.',
    );
    expect(
      failureMessage(const UnknownFailure()),
      'Terjadi kesalahan. Coba lagi.',
    );
  });

  test('semua jenis failure punya pesan tidak kosong', () {
    const all = <AppFailure>[
      NetworkFailure(),
      AuthFailure(AuthFailureCode.invalidCredentials),
      PermissionFailure(),
      NotFoundFailure(),
      ValidationFailure(),
      RateLimitFailure(),
      UnknownFailure(),
    ];
    for (final f in all) {
      expect(failureMessage(f), isNotEmpty);
    }
  });
}
