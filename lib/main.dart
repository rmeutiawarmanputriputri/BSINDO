import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/bootstrap.dart';
import 'app/config/env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  const config = AppConfig.fromEnvironment();
  final bootstrapError = await bootstrapSupabase(config);

  runApp(
    ProviderScope(
      // Tanpa retry otomatis Riverpod 3: error ditampilkan dengan tombol
      // "Coba Lagi" (UI_UX §2), bukan diulang diam-diam.
      retry: (retryCount, error) => null,
      overrides: [
        bootstrapErrorProvider.overrideWithValue(bootstrapError),
      ],
      child: const BisindoApp(),
    ),
  );
}
