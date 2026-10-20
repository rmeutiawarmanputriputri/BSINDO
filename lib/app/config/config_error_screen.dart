import 'package:flutter/material.dart';

/// Ditampilkan bila konfigurasi wajib tidak tersedia. Aplikasi tidak crash.
class ConfigErrorScreen extends StatelessWidget {
  const ConfigErrorScreen({super.key, required this.problems});

  final List<String> problems;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.settings_suggest_outlined,
                    size: 48,
                    color: theme.colorScheme.error,
                    semanticLabel: 'Kesalahan konfigurasi',
                  ),
                  const SizedBox(height: 16),
                  Semantics(
                    header: true,
                    child: Text(
                      'Konfigurasi aplikasi belum lengkap',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final p in problems)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• $p', style: theme.textTheme.bodyMedium),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    'Jalankan aplikasi dengan:\n'
                    'flutter run --dart-define-from-file=env/dev.json\n\n'
                    'Salin env/example.json menjadi env/dev.json lalu isi '
                    'SUPABASE_URL dan SUPABASE_ANON_KEY proyek dev.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
