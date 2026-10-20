import '../../../core/errors/app_failure.dart';
import '../domain/sign_up_result.dart';
import 'auth_repository.dart';

/// Repository PALSU untuk Fase 1 (UI tanpa backend). Tidak ada jaringan,
/// tidak menyimpan apa pun. Email pemicu skenario error (untuk uji manual):
///
/// * `salah@contoh.com`     → kredensial salah (login)
/// * `belum@contoh.com`     → email belum diverifikasi (login)
/// * `terdaftar@contoh.com` → email sudah terdaftar (daftar)
/// * `offline@contoh.com`   → tidak ada koneksi (keduanya)
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.latency = const Duration(milliseconds: 900)});

  final Duration latency;

  int signInCalls = 0;
  int signUpCalls = 0;

  @override
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    signInCalls++;
    await Future<void>.delayed(latency);
    switch (email) {
      case 'salah@contoh.com':
        throw const AuthFailure(AuthFailureCode.invalidCredentials);
      case 'belum@contoh.com':
        throw const AuthFailure(AuthFailureCode.emailNotConfirmed);
      case 'offline@contoh.com':
        throw const NetworkFailure();
    }
  }

  @override
  Future<SignUpResult> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    signUpCalls++;
    await Future<void>.delayed(latency);
    switch (email) {
      case 'terdaftar@contoh.com':
        throw const AuthFailure(AuthFailureCode.emailAlreadyRegistered);
      case 'offline@contoh.com':
        throw const NetworkFailure();
    }
    return SignUpNeedsEmailVerification(email);
  }
}
