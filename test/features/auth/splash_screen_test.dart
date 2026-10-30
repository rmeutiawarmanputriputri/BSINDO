import 'package:bisindo_app/app/router/routes.dart';
import 'package:bisindo_app/app/theme/app_theme.dart';
import 'package:bisindo_app/app/theme/tokens.dart';
import 'package:bisindo_app/features/auth/data/auth_repository.dart';
import 'package:bisindo_app/features/auth/data/fake_auth_repository.dart';
import 'package:bisindo_app/features/auth/presentation/screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Future<void> _pumpSplash(WidgetTester tester, {required bool signedIn}) async {
  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const Scaffold(body: Text('LOGIN')),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const Scaffold(body: Text('HOME')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(signedIn: signedIn),
        ),
      ],
      child: MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
    ),
  );
}

void main() {
  testWidgets('Splash biru solid + wordmark putih, lalu ke /login ≥ 600 ms', (
    tester,
  ) async {
    await _pumpSplash(tester, signedIn: false);

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, AppColors.brandDeep);
    final wordmark = tester.widget<Text>(find.text('BISINDO'));
    expect(wordmark.style?.color, Colors.white);

    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('LOGIN'), findsNothing);

    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();
    expect(find.text('LOGIN'), findsOneWidget);
  });

  testWidgets('sesi tersimpan → Splash ke /home (F1, termasuk saat offline)', (
    tester,
  ) async {
    await _pumpSplash(tester, signedIn: true);
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
  });
}
