/// Hasil pendaftaran (AUTH spec §5.4).
sealed class SignUpResult {
  const SignUpResult();
}

/// Sesi langsung aktif (verifikasi email OFF, mis. proyek dev) → `/home`.
final class SignUpSignedIn extends SignUpResult {
  const SignUpSignedIn();
}

/// Verifikasi email aktif (sesi null) → `/verify-email` (S06).
final class SignUpNeedsEmailVerification extends SignUpResult {
  const SignUpNeedsEmailVerification(this.email);
  final String email;
}
