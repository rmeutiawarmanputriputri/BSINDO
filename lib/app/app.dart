import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/config_error_screen.dart';
import 'config/env.dart';

/// Root aplikasi.
///
/// Fase 0: hanya memeriksa konfigurasi. Router, tema, dan layar auth
/// ditambahkan pada Fase 1; `Supabase.initialize` pada Fase 3.
class BisindoApp extends ConsumerWidget {
  const BisindoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    return MaterialApp(
      title: 'BISINDO',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: config.isValid
          ? const _FoundationScreen()
          : ConfigErrorScreen(problems: config.problems),
    );
  }
}

/// Layar sementara Fase 0 — BUKAN fitur. Diganti pada Fase 1.
class _FoundationScreen extends StatelessWidget {
  const _FoundationScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'BISINDO — fondasi proyek (Fase 0).\nKonfigurasi terbaca.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
