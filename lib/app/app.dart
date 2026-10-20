import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bootstrap.dart';
import 'config/config_error_screen.dart';
import 'config/env.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

/// Root aplikasi.
///
/// Konfigurasi kosong → layar error konfigurasi (tidak crash).
/// `Supabase.initialize` gagal → layar error dengan pesan jelas.
class BisindoApp extends ConsumerWidget {
  const BisindoApp({super.key});

  static const _locale = Locale('id');
  static const _delegates = <LocalizationsDelegate<Object>>[
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];
  static const _supportedLocales = [Locale('id'), Locale('en')];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final bootstrapError = ref.watch(bootstrapErrorProvider);
    final theme = buildAppTheme();

    if (!config.isValid || bootstrapError != null) {
      return MaterialApp(
        title: 'BISINDO',
        debugShowCheckedModeBanner: false,
        theme: theme,
        locale: _locale,
        localizationsDelegates: _delegates,
        supportedLocales: _supportedLocales,
        home: ConfigErrorScreen(
          problems: config.isValid
              ? ['Tidak dapat memulai koneksi ke server: $bootstrapError']
              : config.problems,
        ),
      );
    }

    return MaterialApp.router(
      title: 'BISINDO',
      debugShowCheckedModeBanner: false,
      theme: theme,
      locale: _locale,
      localizationsDelegates: _delegates,
      supportedLocales: _supportedLocales,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
