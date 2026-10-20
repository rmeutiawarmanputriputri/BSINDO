import 'dart:async';

import '../../../core/errors/app_failure.dart';
import '../domain/auth_event.dart';
import '../domain/sign_up_result.dart';
import 'auth_repository.dart';

/// Repository PALSU untuk tes & pratinjau UI tanpa backend.
/// Email pemicu skenario error:
///
/// * `salah@contoh.com`     → kredensial salah (login)
/// * `belum@contoh.com`     → email belum diverifikasi (login)
/// * `terdaftar@contoh.com` → email sudah terdaftar (daftar)
/// * `offline@contoh.com`   → tidak ada koneksi
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    this.latency = const Duration(milliseconds: 900),
    bool signedIn = false,
    this.signUpGivesSession = false,
  }) : _signedIn = signedIn;

  final Duration latency;
  final bool signUpGivesSession;
  bool _signedIn;
  final _events = StreamController<AuthEvent>.broadcast();

  int signInCalls = 0;
  int signUpCalls = 0;
  int resetCalls = 0;
  int resendCalls = 0;
  int updatePasswordCalls = 0;

  @override
  bool get isSignedIn => _signedIn;

  @override
  String? get currentUserId => _signedIn ? 'fake-user-id' : null;

  @override
  String? get currentEmail => _signedIn ? 'pengguna@contoh.com' : null;

  @override
  Stream<AuthEvent> get events => _events.stream;

  void _emit(AuthEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  /// Untuk tes: memicu event pemulihan sandi.
  void simulatePasswordRecovery() => _emit(AuthEvent.passwordRecovery);

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
    _signedIn = true;
    _emit(AuthEvent.signedIn);
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
    if (signUpGivesSession) {
      _signedIn = true;
      _emit(AuthEvent.signedIn);
      return const SignUpSignedIn();
    }
    return SignUpNeedsEmailVerification(email);
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    resetCalls++;
    await Future<void>.delayed(latency);
    if (email == 'offline@contoh.com') throw const NetworkFailure();
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    updatePasswordCalls++;
    await Future<void>.delayed(latency);
    _emit(AuthEvent.userUpdated);
  }

  @override
  Future<void> resendVerification(String email) async {
    resendCalls++;
    await Future<void>.delayed(latency);
  }

  @override
  Future<void> signOut() async {
    _signedIn = false;
    _emit(AuthEvent.signedOut);
  }

  Future<void> dispose() => _events.close();
}
