import 'package:bisindo_app/app/app.dart';
import 'package:bisindo_app/app/config/env.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('konfigurasi kosong → layar error konfigurasi, tidak crash',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(supabaseUrl: '', supabaseAnonKey: ''),
          ),
        ],
        child: const BisindoApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Konfigurasi aplikasi belum lengkap'), findsOneWidget);
    expect(find.textContaining('SUPABASE_URL belum diisi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('konfigurasi valid → aplikasi ter-boot', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              supabaseUrl: 'https://abcd.supabase.co',
              supabaseAnonKey: 'dummy',
            ),
          ),
        ],
        child: const BisindoApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Konfigurasi aplikasi belum lengkap'), findsNothing);
  });
}
