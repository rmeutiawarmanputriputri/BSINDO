import 'package:bisindo_app/app/router/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_auth_app.dart';

// Urutan TextField di Register: 0 nama, 1 email, 2 sandi, 3 konfirmasi.
Finder get _daftarButton => find.widgetWithText(FilledButton, 'Daftar');

Future<void> _fillValid(WidgetTester tester, {String email = 'budi@email.com'}) async {
  await tester.enterText(textFieldAt(0), 'Budi Santoso');
  await tester.enterText(textFieldAt(1), email);
  await tester.enterText(textFieldAt(2), 'rahasia123');
  await tester.enterText(textFieldAt(3), 'rahasia123');
}

void main() {
  testWidgets('menampilkan teks persis seperti gambar; tombol sosial disembunyikan',
      (tester) async {
    await pumpAuthApp(tester, initialLocation: AppRoutes.register);

    expect(find.byTooltip('Kembali'), findsOneWidget);
    expect(find.text('BISINDO'), findsOneWidget);
    expect(find.text('Buat Akun Baru'), findsOneWidget);
    expect(
      find.text('Mari mulai perjalanan belajar isyarat bersama'),
      findsOneWidget,
    );
    expect(find.text('Nama Lengkap'), findsOneWidget);
    expect(find.text('Masukkan nama lengkap Anda'), findsOneWidget);
    expect(find.text('Alamat Email'), findsOneWidget);
    expect(find.text('Email Anda (contoh: nama@email.com)'), findsOneWidget);
    expect(find.text('Kata Sandi'), findsOneWidget);
    expect(find.text('Buat kata sandi minimal 8 karakter'), findsOneWidget);
    expect(find.text('Konfirmasi Kata Sandi'), findsOneWidget);
    expect(find.text('Ulangi kata sandi Anda'), findsOneWidget);
    expect(_daftarButton, findsOneWidget);
    expect(find.text('Sudah punya akun?'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Masuk'), findsOneWidget);
    expect(find.text('Atau daftar dengan'), findsNothing);
  });

  testWidgets('AUTH-02: submit kosong → 4 error per field + fokus ke Nama',
      (tester) async {
    final repo = await pumpAuthApp(tester, initialLocation: AppRoutes.register);

    await tester.ensureVisible(_daftarButton);
    await tester.tap(_daftarButton);
    await tester.pumpAndSettle();

    expect(find.text('Nama lengkap minimal 2 karakter.'), findsOneWidget);
    expect(find.text('Masukkan alamat email yang valid.'), findsOneWidget);
    expect(find.text('Kata sandi minimal 8 karakter.'), findsOneWidget);
    expect(find.text('Konfirmasi kata sandi tidak sama.'), findsOneWidget);
    expect(textFieldWidget(tester, 0).focusNode!.hasFocus, isTrue);
    expect(repo.signUpCalls, 0);
  });

  testWidgets('konfirmasi tidak sama → hanya error konfirmasi', (tester) async {
    await pumpAuthApp(tester, initialLocation: AppRoutes.register);
    await _fillValid(tester);
    await tester.enterText(textFieldAt(3), 'berbeda123');

    await tester.ensureVisible(_daftarButton);
    await tester.tap(_daftarButton);
    await tester.pumpAndSettle();

    expect(find.text('Konfirmasi kata sandi tidak sama.'), findsOneWidget);
    expect(find.text('Nama lengkap minimal 2 karakter.'), findsNothing);
    expect(textFieldWidget(tester, 3).focusNode!.hasFocus, isTrue);
  });

  testWidgets('AUTH-03: loading tidak ganda; signUp dipanggil sekali',
      (tester) async {
    final repo = await pumpAuthApp(tester, initialLocation: AppRoutes.register);
    await _fillValid(tester);

    await tester.ensureVisible(_daftarButton);
    await tester.tap(_daftarButton);
    await tester.pump();

    expect(find.text('Memproses…'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    await tester.tap(find.byType(FilledButton), warnIfMissed: false);

    await tester.pump(kFakeLatency);
    await tester.pump();
    expect(repo.signUpCalls, 1);
    expect(find.textContaining('repository palsu'), findsOneWidget);
    await settleSnackBars(tester);
  });

  testWidgets('AUTH-04: dua toggle sandi bekerja terpisah', (tester) async {
    await pumpAuthApp(tester, initialLocation: AppRoutes.register);

    expect(find.byTooltip('Tampilkan kata sandi'), findsNWidgets(2));
    await tester.tap(find.byTooltip('Tampilkan kata sandi').first);
    await tester.pump();
    expect(textFieldWidget(tester, 2).obscureText, isFalse);
    expect(textFieldWidget(tester, 3).obscureText, isTrue);
  });

  testWidgets('email sudah terdaftar → banner', (tester) async {
    await pumpAuthApp(tester, initialLocation: AppRoutes.register);
    await _fillValid(tester, email: 'terdaftar@contoh.com');

    await tester.ensureVisible(_daftarButton);
    await tester.tap(_daftarButton);
    await tester.pump();
    await tester.pump(kFakeLatency);
    await tester.pumpAndSettle();

    expect(find.text('Email ini sudah terdaftar. Silakan masuk.'), findsOneWidget);
  });

  testWidgets('panah kembali kembali ke Login', (tester) async {
    await pumpAuthApp(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Daftar'));
    await tester.pumpAndSettle();
    expect(find.text('Buat Akun Baru'), findsOneWidget);

    await tester.tap(find.byTooltip('Kembali'));
    await tester.pumpAndSettle();
    expect(find.text('Masuk ke Akun Anda'), findsOneWidget);
  });

  testWidgets('Register dibuka langsung: footer "Masuk" tetap ke Login',
      (tester) async {
    await pumpAuthApp(tester, initialLocation: AppRoutes.register);
    await tester.ensureVisible(find.widgetWithText(TextButton, 'Masuk'));
    await tester.tap(find.widgetWithText(TextButton, 'Masuk'));
    await tester.pumpAndSettle();
    expect(find.text('Masuk ke Akun Anda'), findsOneWidget);
  });
}
