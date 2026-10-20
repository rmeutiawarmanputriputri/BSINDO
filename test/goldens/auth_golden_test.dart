@Tags(['golden'])
library;

import 'dart:io';

import 'package:bisindo_app/app/router/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_auth_app.dart';

/// AUTH-11 / AUTH spec §9 butir 5: golden Login & Register pada 2 ukuran.
///
/// Baseline BELUM ADA. Buat sekali di mesin Anda lalu commit:
///   flutter test --update-goldens test/goldens
/// Golden bergantung platform (render font) — buat & jalankan di OS yang sama.
///
/// Selama baseline belum ada, tes dilewati (bukan gagal) agar `flutter test`
/// biasa tetap hijau; `--update-goldens` selalu menjalankannya.
bool _skipWithoutBaseline(String name) =>
    !autoUpdateGoldenFiles &&
    !File('test/goldens/goldens/$name.png').existsSync();

void main() {
  const sizes = {
    '360x640': Size(360, 640),
    '411x891': Size(411, 891),
  };

  for (final entry in sizes.entries) {
    testWidgets('Login ${entry.key}',
        skip: _skipWithoutBaseline('login_${entry.key}'), (tester) async {
      await pumpAuthApp(tester, screenSize: entry.value);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/login_${entry.key}.png'),
      );
    });

    testWidgets('Register ${entry.key}',
        skip: _skipWithoutBaseline('register_${entry.key}'), (tester) async {
      await pumpAuthApp(
        tester,
        initialLocation: AppRoutes.register,
        screenSize: entry.value,
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/register_${entry.key}.png'),
      );
    });
  }
}
