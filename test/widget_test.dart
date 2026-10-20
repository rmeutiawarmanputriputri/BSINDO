// Berkas ini sengaja ada agar `flutter create .` tidak membuat tes templat
// "counter" (MyApp) yang tidak cocok dengan proyek ini.
import 'package:bisindo_app/app/app.dart';
import 'package:bisindo_app/app/config/env.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('aplikasi ter-boot tanpa konfigurasi tanpa crash', (tester) async {
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
  });
}
