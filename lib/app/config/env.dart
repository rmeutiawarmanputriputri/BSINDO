import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Konfigurasi runtime yang dibaca dari `--dart-define-from-file=env/dev.json`.
///
/// Hanya `SUPABASE_URL` dan anon key yang boleh ada di klien (D-14).
/// Service role key TIDAK PERNAH dimasukkan ke aplikasi.
class AppConfig {
  const AppConfig({required this.supabaseUrl, required this.supabaseAnonKey});

  /// Membaca nilai compile-time. Kosong bila aplikasi dijalankan tanpa
  /// `--dart-define-from-file`.
  const AppConfig.fromEnvironment()
      : supabaseUrl = const String.fromEnvironment('SUPABASE_URL'),
        supabaseAnonKey = const String.fromEnvironment('SUPABASE_ANON_KEY');

  final String supabaseUrl;
  final String supabaseAnonKey;

  /// Daftar masalah konfigurasi (kosong = valid). Nilai kunci tidak pernah
  /// dimasukkan ke pesan agar tidak bocor ke log/layar.
  List<String> get problems {
    final result = <String>[];
    final url = supabaseUrl.trim();
    if (url.isEmpty) {
      result.add('SUPABASE_URL belum diisi.');
    } else {
      if (!_isValidUrl(url)) {
        result.add('SUPABASE_URL tidak valid (harus https://…).');
      }
    }
    if (supabaseAnonKey.trim().isEmpty) {
      result.add('SUPABASE_ANON_KEY belum diisi.');
    }
    return result;
  }

  bool get isValid => problems.isEmpty;

  static bool _isValidUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return false;
    if (uri.scheme == 'https') return true;
    // http hanya untuk Supabase lokal (127.0.0.1 / 10.0.2.2 / localhost).
    return uri.scheme == 'http' && _isLocalHost(uri.host);
  }

  static bool _isLocalHost(String host) =>
      host == 'localhost' || host == '127.0.0.1' || host == '10.0.2.2';
}

/// Provider konfigurasi; dapat di-override di tes.
final appConfigProvider = Provider<AppConfig>(
  (ref) => const AppConfig.fromEnvironment(),
);
