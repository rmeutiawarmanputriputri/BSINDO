import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import 'routes.dart';

/// Router minimal Fase 1 (tanpa guard sesi). Redirect berbasis sesi/role
/// (`refreshListenable: authState`) ditambahkan pada Fase 3 (D-02).
///
/// `pageBuilder` + `MaterialPage` eksplisit: go_router 18 mendeteksi
/// `MaterialApp` dari paket `material_ui`, bukan `package:flutter/material`,
/// sehingga tanpa ini transisi halaman jatuh ke `NoTransitionPage`.
final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        pageBuilder: (context, state) =>
            _page(state, const SplashScreen()),
      ),
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (context, state) => _page(state, const LoginScreen()),
      ),
      GoRoute(
        path: AppRoutes.register,
        pageBuilder: (context, state) =>
            _page(state, const RegisterScreen()),
      ),
    ],
    errorBuilder: (context, state) => const _NotFoundScreen(),
  );
  ref.onDispose(router.dispose);
  return router;
});

Page<void> _page(GoRouterState state, Widget child) =>
    MaterialPage<void>(key: state.pageKey, child: child);

class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Halaman tidak ditemukan.'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.go(AppRoutes.login),
                  child: const Text('Ke halaman Masuk'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
