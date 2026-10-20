/// Hierarki error yang dilihat UI (FLUTTER_ARCHITECTURE.md §7).
/// Repository menerjemahkan exception teknis → [AppFailure].
sealed class AppFailure implements Exception {
  const AppFailure();
}

/// Tidak ada koneksi / timeout.
final class NetworkFailure extends AppFailure {
  const NetworkFailure();
}

enum AuthFailureCode {
  invalidCredentials,
  emailNotConfirmed,
  emailAlreadyRegistered,
  weakPassword,
}

final class AuthFailure extends AppFailure {
  const AuthFailure(this.code);
  final AuthFailureCode code;
}

/// Ditolak RLS / 401 / 403 / 42501.
final class PermissionFailure extends AppFailure {
  const PermissionFailure();
}

final class NotFoundFailure extends AppFailure {
  const NotFoundFailure();
}

final class ValidationFailure extends AppFailure {
  const ValidationFailure([this.detail]);

  /// Penanda singkat (mis. nama constraint `validation_required`) — tanpa PII.
  final String? detail;
}

/// Data bentrok dengan yang sudah ada (unique violation, 23505).
final class ConflictFailure extends AppFailure {
  const ConflictFailure([this.detail]);
  final String? detail;
}

final class RateLimitFailure extends AppFailure {
  const RateLimitFailure();
}

/// Kegagalan dengan pesan siap tampil (mis. validasi berkas lokal).
final class MessageFailure extends AppFailure {
  const MessageFailure(this.message);
  final String message;
}

final class UnknownFailure extends AppFailure {
  const UnknownFailure();
}
