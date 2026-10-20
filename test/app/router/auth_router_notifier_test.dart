import 'package:bisindo_app/app/router/auth_router_notifier.dart';
import 'package:bisindo_app/app/router/routes.dart';
import 'package:bisindo_app/features/auth/data/fake_auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// D-02: redirect berbasis sesi (AUTH-09 sebagian).
void main() {
  test('tanpa sesi: rute terlindungi → /login; rute tamu tetap', () {
    final n = AuthRouterNotifier(FakeAuthRepository());
    addTearDown(n.dispose);
    expect(n.redirect(AppRoutes.splash), isNull);
    expect(n.redirect(AppRoutes.home), AppRoutes.login);
    expect(n.redirect('/dictionary/sign/abc'), AppRoutes.login);
    expect(n.redirect(AppRoutes.admin), AppRoutes.login);
    expect(n.redirect(AppRoutes.login), isNull);
    expect(n.redirect(AppRoutes.register), isNull);
    expect(n.redirect(AppRoutes.forgotPassword), isNull);
    expect(n.redirect(AppRoutes.resetPassword), AppRoutes.login);
  });

  test('dengan sesi: rute tamu → /home; rute terlindungi tetap', () {
    final n = AuthRouterNotifier(FakeAuthRepository(signedIn: true));
    addTearDown(n.dispose);
    expect(n.redirect(AppRoutes.login), AppRoutes.home);
    expect(n.redirect(AppRoutes.register), AppRoutes.home);
    expect(n.redirect(AppRoutes.home), isNull);
    expect(n.redirect(AppRoutes.profile), isNull);
  });

  test('event pemulihan sandi → semua rute ke /reset-password', () async {
    final repo = FakeAuthRepository(signedIn: true);
    final n = AuthRouterNotifier(repo);
    addTearDown(n.dispose);
    var notified = 0;
    n.addListener(() => notified++);

    repo.simulatePasswordRecovery();
    await Future<void>.delayed(Duration.zero);

    expect(notified, greaterThan(0));
    expect(n.redirect(AppRoutes.home), AppRoutes.resetPassword);
    expect(n.redirect(AppRoutes.resetPassword), isNull);

    n.completePasswordRecovery();
    expect(n.redirect(AppRoutes.home), isNull);
  });

  test('logout memicu refresh dan kembali ke /login', () async {
    final repo = FakeAuthRepository(signedIn: true);
    final n = AuthRouterNotifier(repo);
    addTearDown(n.dispose);
    var notified = 0;
    n.addListener(() => notified++);
    await repo.signOut();
    await Future<void>.delayed(Duration.zero);
    expect(notified, 1);
    expect(n.redirect(AppRoutes.home), AppRoutes.login);
  });
}
