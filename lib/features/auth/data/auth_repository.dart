import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../domain/auth_event.dart';
import '../domain/sign_up_result.dart';
import 'supabase_auth_repository.dart';

/// Kontrak autentikasi. Semua error teknis dilempar sebagai `AppFailure`.
abstract interface class AuthRepository {
  bool get isSignedIn;
  String? get currentUserId;
  String? get currentEmail;

  /// Aliran peristiwa auth (login, logout, pemulihan sandi).
  Stream<AuthEvent> get events;

  Future<void> signInWithPassword({
    required String email,
    required String password,
  });

  Future<SignUpResult> signUp({
    required String fullName,
    required String email,
    required String password,
  });

  /// Selalu sukses dari sudut pandang UI (pesan netral, tanpa enumerasi email).
  Future<void> sendPasswordReset(String email);

  Future<void> updatePassword(String newPassword);

  Future<void> resendVerification(String email);

  Future<void> signOut();
}

/// Deep link auth (D-09).
const kAuthRedirectUrl = 'bisindo://auth-callback';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => SupabaseAuthRepository(ref.watch(supabaseClientProvider)),
);

/// Aliran peristiwa auth sebagai provider.
final authEventsProvider = StreamProvider<AuthEvent>(
  (ref) => ref.watch(authRepositoryProvider).events,
);

/// ID pengguna aktif; provider data pribadi menontonnya sehingga otomatis
/// dimuat ulang saat pengguna berganti / keluar.
final currentUserIdProvider = Provider<String?>((ref) {
  ref.watch(authEventsProvider);
  return ref.watch(authRepositoryProvider).currentUserId;
});
