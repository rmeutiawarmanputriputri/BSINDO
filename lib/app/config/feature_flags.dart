/// Feature flag compile-time.
abstract final class FeatureFlags {
  /// Login sosial (Google/Facebook/Apple) — di luar MVP (D-10, K-03).
  /// Default `false`: tombol & pembatas "Atau … dengan" disembunyikan agar
  /// tidak ada tombol palsu. Aktifkan hanya setelah integrasi nyata:
  /// `--dart-define=ENABLE_SOCIAL_AUTH=true`.
  static const bool enableSocialAuth = bool.fromEnvironment(
    'ENABLE_SOCIAL_AUTH',
  );
}
