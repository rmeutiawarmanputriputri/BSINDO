import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // TODO(P3): Supabase.initialize(url, anonKey) di sini setelah konfigurasi
  // valid (FLUTTER_ARCHITECTURE.md §11). Sengaja ditunda pada Fase 0–1.
  runApp(const ProviderScope(child: BisindoApp()));
}
