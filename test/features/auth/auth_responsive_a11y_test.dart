import 'package:bisindo_app/app/router/routes.dart';
import 'package:bisindo_app/core/widgets/auth_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_auth_app.dart';

/// RESP-01/03, A11Y-02/03, AUTH spec §9 butir 2–4.
void main() {
  for (final route in [AppRoutes.login, AppRoutes.register]) {
    group(route, () {
      for (final scale in [1.0, 1.3, 2.0]) {
        testWidgets('360×640 @ skala teks $scale → tanpa overflow', (
          tester,
        ) async {
          await pumpAuthApp(
            tester,
            initialLocation: route,
            screenSize: const Size(360, 640),
            textScale: scale,
          );
          // Overflow RenderFlex dilaporkan sebagai exception oleh framework.
          expect(tester.takeException(), isNull);

          // Konten dapat di-scroll sampai tombol utama terlihat (butir 3).
          final button = find.byType(FilledButton);
          await tester.ensureVisible(button);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final rect = tester.getRect(button);
          expect(rect.bottom, lessThanOrEqualTo(640));
          expect(rect.top, greaterThanOrEqualTo(0));
        });
      }

      testWidgets('360×640 @ 200% dengan semua pesan error → tanpa overflow', (
        tester,
      ) async {
        await pumpAuthApp(
          tester,
          initialLocation: route,
          screenSize: const Size(360, 640),
          textScale: 2.0,
        );
        final button = find.byType(FilledButton);
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('tablet 600×960: kartu dibatasi ≤ 480 dan terpusat', (
        tester,
      ) async {
        await pumpAuthApp(
          tester,
          initialLocation: route,
          screenSize: const Size(600, 960),
        );
        final rect = tester.getRect(find.byType(AuthCard));
        expect(rect.width, lessThanOrEqualTo(480));
        expect((rect.center.dx - 300).abs(), lessThan(1));
      });

      testWidgets('target sentuh ≥ 48dp & semua tap target berlabel', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await pumpAuthApp(tester, initialLocation: route);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });

      testWidgets('kolom teks punya label semantik dari label visual', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await pumpAuthApp(tester, initialLocation: route);
        expect(find.bySemanticsLabel(RegExp('Alamat Email')), findsWidgets);
        expect(find.bySemanticsLabel(RegExp('Kata Sandi')), findsWidgets);
        expect(find.bySemanticsLabel('Logo BISINDO'), findsOneWidget);
        handle.dispose();
      });
    });
  }
}
