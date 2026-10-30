import 'package:bisindo_app/core/errors/app_failure.dart';
import 'package:bisindo_app/features/auth/data/auth_repository.dart';
import 'package:bisindo_app/features/auth/data/fake_auth_repository.dart';
import 'package:bisindo_app/features/auth/domain/sign_up_result.dart';
import 'package:bisindo_app/features/auth/presentation/controllers/login_controller.dart';
import 'package:bisindo_app/features/auth/presentation/controllers/register_controller.dart';
import 'package:bisindo_app/features/auth/presentation/controllers/submit_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ProviderContainer _container(FakeAuthRepository repo) {
  final container = ProviderContainer(
    overrides: [authRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('LoginController', () {
    test('submit ganda saat loading → repository dipanggil sekali', () async {
      final repo = FakeAuthRepository(latency: Duration.zero);
      final container = _container(repo);
      final sub = container.listen(loginControllerProvider, (prev, next) {});
      addTearDown(sub.close);

      final notifier = container.read(loginControllerProvider.notifier);
      final first = notifier.submit(email: 'a@b.co', password: 'x');
      final second = notifier.submit(email: 'a@b.co', password: 'x');
      expect(
        container.read(loginControllerProvider),
        isA<SubmitLoading<void>>(),
      );
      await Future.wait([first, second]);

      expect(repo.signInCalls, 1);
      expect(
        container.read(loginControllerProvider),
        isA<SubmitSucceeded<void>>(),
      );
    });

    test(
      'email dinormalisasi; kredensial salah → SubmitFailed(AuthFailure)',
      () async {
        final repo = FakeAuthRepository(latency: Duration.zero);
        final container = _container(repo);
        final sub = container.listen(loginControllerProvider, (prev, next) {});
        addTearDown(sub.close);

        await container
            .read(loginControllerProvider.notifier)
            .submit(email: '  SALAH@contoh.com ', password: 'x');

        final state = container.read(loginControllerProvider);
        expect(state, isA<SubmitFailed<void>>());
        final failure = (state as SubmitFailed<void>).failure;
        expect(failure, isA<AuthFailure>());
        expect(
          (failure as AuthFailure).code,
          AuthFailureCode.invalidCredentials,
        );
      },
    );
  });

  group('RegisterController', () {
    test(
      'berhasil → SignUpNeedsEmailVerification dengan email ternormalisasi',
      () async {
        final repo = FakeAuthRepository(latency: Duration.zero);
        final container = _container(repo);
        final sub = container.listen(
          registerControllerProvider,
          (prev, next) {},
        );
        addTearDown(sub.close);

        await container
            .read(registerControllerProvider.notifier)
            .submit(
              fullName: ' Budi ',
              email: 'Budi@Email.com',
              password: '12345678',
            );

        final state = container.read(registerControllerProvider);
        expect(state, isA<SubmitSucceeded<SignUpResult>>());
        final value = (state as SubmitSucceeded<SignUpResult>).value;
        expect(value, isA<SignUpNeedsEmailVerification>());
        expect((value as SignUpNeedsEmailVerification).email, 'budi@email.com');
        expect(repo.signUpCalls, 1);
      },
    );

    test('jaringan gagal → SubmitFailed(NetworkFailure)', () async {
      final repo = FakeAuthRepository(latency: Duration.zero);
      final container = _container(repo);
      final sub = container.listen(registerControllerProvider, (prev, next) {});
      addTearDown(sub.close);

      await container
          .read(registerControllerProvider.notifier)
          .submit(
            fullName: 'Budi',
            email: 'offline@contoh.com',
            password: '12345678',
          );

      final state = container.read(registerControllerProvider);
      expect(state, isA<SubmitFailed<SignUpResult>>());
      expect(
        (state as SubmitFailed<SignUpResult>).failure,
        isA<NetworkFailure>(),
      );
    });
  });
}
