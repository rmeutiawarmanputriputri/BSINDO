import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failure_mapper.dart';
import '../domain/auth_event.dart';
import '../domain/sign_up_result.dart';
import 'auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  GoTrueClient get _auth => _client.auth;

  @override
  bool get isSignedIn => _auth.currentSession != null;

  @override
  String? get currentUserId => _auth.currentUser?.id;

  @override
  String? get currentEmail => _auth.currentUser?.email;

  @override
  Stream<AuthEvent> get events => _auth.onAuthStateChange.map(
        (state) => switch (state.event) {
          AuthChangeEvent.signedIn => AuthEvent.signedIn,
          AuthChangeEvent.signedOut => AuthEvent.signedOut,
          AuthChangeEvent.passwordRecovery => AuthEvent.passwordRecovery,
          AuthChangeEvent.userUpdated => AuthEvent.userUpdated,
          _ => AuthEvent.other,
        },
      );

  @override
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) =>
      guardRequest(
        () => _auth.signInWithPassword(email: email, password: password),
      );

  @override
  Future<SignUpResult> signUp({
    required String fullName,
    required String email,
    required String password,
  }) =>
      guardRequest(() async {
        final response = await _auth.signUp(
          email: email,
          password: password,
          emailRedirectTo: kAuthRedirectUrl,
          data: {'full_name': fullName},
        );
        // Supabase mengembalikan user tanpa identitas bila email sudah
        // terdaftar (perlindungan enumerasi) saat konfirmasi email aktif.
        final identities = response.user?.identities;
        if (response.session == null &&
            identities != null &&
            identities.isEmpty) {
          return SignUpNeedsEmailVerification(email);
        }
        return response.session != null
            ? const SignUpSignedIn()
            : SignUpNeedsEmailVerification(email);
      });

  @override
  Future<void> sendPasswordReset(String email) => guardRequest(
        () => _auth.resetPasswordForEmail(email, redirectTo: kAuthRedirectUrl),
      );

  @override
  Future<void> updatePassword(String newPassword) => guardRequest(
        () => _auth.updateUser(UserAttributes(password: newPassword)),
      );

  @override
  Future<void> resendVerification(String email) => guardRequest(
        () => _auth.resend(
          type: OtpType.signup,
          email: email,
          emailRedirectTo: kAuthRedirectUrl,
        ),
      );

  @override
  Future<void> signOut() async {
    try {
      await guardRequest(() => _auth.signOut());
    } catch (_) {
      // F14: gagal jaringan → sesi lokal tetap dihapus.
      await _auth.signOut(scope: SignOutScope.local);
    }
  }
}
