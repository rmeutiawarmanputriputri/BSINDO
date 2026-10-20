import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Klien Supabase. `Supabase.initialize` dipanggil di `main.dart` sebelum
/// `runApp`. Tes meng-override repository, bukan provider ini.
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

/// Nama bucket media privat (D-05).
const kMediaBucket = 'bisindo-media';
