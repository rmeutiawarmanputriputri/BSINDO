import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/env.dart';

/// Batas waktu inisialisasi (AUTH spec §5.1).
const kBootstrapTimeout = Duration(seconds: 8);

/// Pesan kegagalan inisialisasi (null = berhasil / belum dicoba).
final bootstrapErrorProvider = Provider<String?>((ref) => null);

/// Menginisialisasi Supabase (memulihkan sesi tersimpan; tidak butuh internet).
/// Mengembalikan pesan error atau null.
Future<String?> bootstrapSupabase(AppConfig config) async {
  if (!config.isValid) return null;
  try {
    await Supabase.initialize(
      url: config.supabaseUrl.trim(),
      // anon key lama tetap diterima sebagai publishableKey (D-14).
      publishableKey: config.supabaseAnonKey.trim(),
      debug: false,
    ).timeout(kBootstrapTimeout);
    return null;
  } catch (error) {
    if (kDebugMode) debugPrint('bootstrapSupabase: ${error.runtimeType}');
    return error.runtimeType.toString();
  }
}
