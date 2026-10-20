import 'package:bisindo_app/app/router/routes.dart';
import 'package:bisindo_app/app/theme/app_theme.dart';
import 'package:bisindo_app/app/theme/tokens.dart';
import 'package:bisindo_app/features/auth/presentation/screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('Splash biru solid + wordmark putih, lalu ke /login ≥ 600 ms',
      (tester) async {
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
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
    );

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, AppColors.brandDeep);
    final wordmark = tester.widget<Text>(find.text('BISINDO'));
    expect(wordmark.style?.color, Colors.white);

    // Belum pindah sebelum durasi minimum.
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('LOGIN'), findsNothing);

    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();
    expect(find.text('LOGIN'), findsOneWidget);
  });
}
