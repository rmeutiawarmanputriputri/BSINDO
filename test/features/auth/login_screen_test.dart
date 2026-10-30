import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_auth_app.dart';

// Urutan TextField di Login: 0 = email, 1 = kata sandi.
void main() {
  testWidgets(
    'menampilkan teks persis seperti gambar; tombol sosial disembunyikan',
    (tester) async {
      await pumpAuthApp(tester);

      expect(find.text('BISINDO'), findsOneWidget);
      expect(find.text('Masuk ke Akun Anda'), findsOneWidget);
      expect(find.text('Alamat Email'), findsOneWidget);
      expect(find.text('Email Anda (contoh: nama@email.com)'), findsOneWidget);
      expect(find.text('Kata Sandi'), findsOneWidget);
      expect(find.text('Masukkan kata sandi'), findsOneWidget);
      expect(find.text('Lupa Kata Sandi?'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Masuk'), findsOneWidget);
      expect(find.text('Belum punya akun?'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Daftar'), findsOneWidget);
      // K-03 default: flag enableSocialAuth=false.
      expect(find.text('Atau masuk dengan'), findsNothing);
    },
  );

  testWidgets(
    'AUTH-02: submit kosong → error per field + fokus ke field pertama',
    (tester) async {
      final repo = await pumpAuthApp(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
      await tester.pumpAndSettle();

      expect(find.text('Masukkan alamat email yang valid.'), findsOneWidget);
      expect(find.text('Masukkan kata sandi Anda.'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsNWidgets(2));
      expect(textFieldWidget(tester, 0).focusNode!.hasFocus, isTrue);
      expect(repo.signInCalls, 0);
    },
  );

  testWidgets(
    'error tidak tampil saat mengetik pertama kali, tampil setelah blur',
    (tester) async {
      await pumpAuthApp(tester);

      await tester.tap(textFieldAt(0));
      await tester.enterText(textFieldAt(0), 'bukan-email');
      await tester.pump();
      expect(find.text('Masukkan alamat email yang valid.'), findsNothing);

      // Pindah ke kolom sandi → kolom email blur.
      await tester.tap(textFieldAt(1));
      await tester.pumpAndSettle();
      expect(find.text('Masukkan alamat email yang valid.'), findsOneWidget);
    },
  );

  testWidgets(
    'AUTH-03: loading menampilkan "Memproses…" dan klik ganda diblokir',
    (tester) async {
      final repo = await pumpAuthApp(tester);

      await tester.enterText(textFieldAt(0), 'Nama@Email.com ');
      await tester.enterText(textFieldAt(1), 'rahasia123');
      await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
      await tester.pump();

      expect(find.text('Memproses…'), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
      expect(textFieldWidget(tester, 0).enabled, isFalse);

      await tester.tap(find.byType(FilledButton), warnIfMissed: false);
      await tester.pump(kFakeLatency);
      await tester.pump();

      expect(repo.signInCalls, 1);
      // Sukses → sesi aktif; navigasi ke /home dilakukan redirect router.
      expect(repo.isSignedIn, isTrue);
    },
  );

  testWidgets('AUTH-04: toggle sandi mengubah obscureText dan tooltip', (
    tester,
  ) async {
    await pumpAuthApp(tester);

    expect(textFieldWidget(tester, 1).obscureText, isTrue);
    await tester.tap(find.byTooltip('Tampilkan kata sandi'));
    await tester.pump();
    expect(textFieldWidget(tester, 1).obscureText, isFalse);
    expect(find.byTooltip('Sembunyikan kata sandi'), findsOneWidget);
  });

  testWidgets('error server tampil sebagai banner (kredensial salah)', (
    tester,
  ) async {
    await pumpAuthApp(tester);

    await tester.enterText(textFieldAt(0), 'salah@contoh.com');
    await tester.enterText(textFieldAt(1), 'apa-saja');
    await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
    await tester.pump();
    await tester.pump(kFakeLatency);
    await tester.pumpAndSettle();

    expect(find.text('Email atau kata sandi salah.'), findsOneWidget);
    await tester.tap(find.byTooltip('Tutup pesan'));
    await tester.pumpAndSettle();
    expect(find.text('Email atau kata sandi salah.'), findsNothing);
  });

  testWidgets('"Lupa Kata Sandi?" membuka layar lupa sandi (S04)', (
    tester,
  ) async {
    await pumpAuthApp(tester);
    await tester.tap(find.text('Lupa Kata Sandi?'));
    await tester.pumpAndSettle();
    expect(find.text('Lupa Kata Sandi'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Kirim Tautan'), findsOneWidget);
  });

  testWidgets('email belum diverifikasi → banner + aksi kirim ulang', (
    tester,
  ) async {
    await pumpAuthApp(tester);
    await tester.enterText(textFieldAt(0), 'belum@contoh.com');
    await tester.enterText(textFieldAt(1), 'apa-saja');
    await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
    await tester.pump();
    await tester.pump(kFakeLatency);
    await tester.pumpAndSettle();

    expect(
      find.text('Email belum diverifikasi. Cek kotak masuk Anda.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Kirim ulang verifikasi'));
    await tester.pumpAndSettle();
    expect(find.text('Verifikasi Email'), findsOneWidget);
    expect(find.textContaining('belum@contoh.com'), findsOneWidget);
  });

  testWidgets('footer "Daftar" membuka Register', (tester) async {
    await pumpAuthApp(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Daftar'));
    await tester.pumpAndSettle();
    expect(find.text('Buat Akun Baru'), findsOneWidget);
  });
}
