import 'package:bisindo_app/app/router/routes.dart';
import 'package:bisindo_app/app/theme/app_theme.dart';
import 'package:bisindo_app/features/auth/data/auth_repository.dart';
import 'package:bisindo_app/features/auth/data/fake_auth_repository.dart';
import 'package:bisindo_app/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:bisindo_app/features/auth/presentation/screens/login_screen.dart';
import 'package:bisindo_app/features/auth/presentation/screens/register_screen.dart';
import 'package:bisindo_app/features/auth/presentation/screens/verify_email_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Latensi repository palsu di tes.
const kFakeLatency = Duration(milliseconds: 300);

/// Memasang Login/Register dengan router nyata + repository palsu.
Future<FakeAuthRepository> pumpAuthApp(
  WidgetTester tester, {
  String initialLocation = AppRoutes.login,
  FakeAuthRepository? repository,
  Size screenSize = const Size(411, 891),
  double textScale = 1.0,
}) async {
  setScreen(tester, size: screenSize, textScale: textScale);
  final repo = repository ?? FakeAuthRepository(latency: kFakeLatency);
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (context, state) =>
            MaterialPage<void>(key: state.pageKey, child: const LoginScreen()),
      ),
      GoRoute(
        path: AppRoutes.register,
        pageBuilder: (context, state) => MaterialPage<void>(
          key: state.pageKey,
          child: const RegisterScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        pageBuilder: (context, state) => MaterialPage<void>(
          key: state.pageKey,
          child: const ForgotPasswordScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.verifyEmail,
        pageBuilder: (context, state) => MaterialPage<void>(
          key: state.pageKey,
          child: VerifyEmailScreen(
            email: state.uri.queryParameters['email'] ?? '',
          ),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

/// Mengatur ukuran layar logis (dp) dan skala teks.
void setScreen(
  WidgetTester tester, {
  required Size size,
  double textScale = 1.0,
}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// Menunggu SnackBar hilang agar tidak ada Timer tertinggal di akhir tes.
/// Timer 4 s SnackBar baru mulai setelah animasi masuk selesai → dua langkah.
Future<void> settleSnackBars(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

Finder textFieldAt(int index) => find.byType(TextField).at(index);

TextField textFieldWidget(WidgetTester tester, int index) =>
    tester.widget<TextField>(textFieldAt(index));
