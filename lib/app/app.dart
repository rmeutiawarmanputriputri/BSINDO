import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/config_error_screen.dart';
import 'config/env.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

/// Root aplikasi.
///
/// Konfigurasi kosong → layar error konfigurasi (tidak crash).
/// `Supabase.initialize` ditambahkan pada Fase 3.
class BisindoApp extends ConsumerWidget {
  const BisindoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final theme = buildAppTheme();

    if (!config.isValid) {
      return MaterialApp(
        title: 'BISINDO',
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: ConfigErrorScreen(problems: config.problems),
      );
    }

    return MaterialApp.router(
      title: 'BISINDO',
      debugShowCheckedModeBanner: false,
      theme: theme,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
