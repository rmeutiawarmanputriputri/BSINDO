import 'package:bisindo_app/app/app.dart';
import 'package:bisindo_app/app/bootstrap.dart';
import 'package:bisindo_app/app/config/env.dart';
import 'package:bisindo_app/features/auth/data/auth_repository.dart';
import 'package:bisindo_app/features/auth/data/fake_auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _validConfig = AppConfig(
  supabaseUrl: 'https://abcd.supabase.co',
  supabaseAnonKey: 'dummy',
);

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

  testWidgets('inisialisasi Supabase gagal → layar error, tidak crash',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_validConfig),
          bootstrapErrorProvider.overrideWithValue('TimeoutException'),
        ],
        child: const BisindoApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Tidak dapat memulai koneksi'), findsOneWidget);
  });

  testWidgets('konfigurasi valid, tanpa sesi → Splash lalu Login (redirect)',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_validConfig),
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(latency: Duration.zero),
          ),
        ],
        child: const BisindoApp(),
      ),
    );
    await tester.pump();
    expect(find.text('BISINDO'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    expect(find.text('Masuk ke Akun Anda'), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
