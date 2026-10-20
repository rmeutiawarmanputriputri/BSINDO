import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/sign_up_result.dart';
import 'fake_auth_repository.dart';

/// Kontrak akses autentikasi. Implementasi Supabase dibuat pada Fase 3;
/// semua error teknis diterjemahkan menjadi `AppFailure`.
abstract interface class AuthRepository {
  /// Melempar `AppFailure` bila gagal.
  Future<void> signInWithPassword({
    required String email,
    required String password,
  });

  /// Melempar `AppFailure` bila gagal.
  Future<SignUpResult> signUp({
    required String fullName,
    required String email,
    required String password,
  });
}

/// FASE 1: default memakai [FakeAuthRepository] — TIDAK memanggil Supabase.
/// TODO(P3): ganti dengan `SupabaseAuthRepository`.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => FakeAuthRepository(),
);
