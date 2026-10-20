import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/utils/validators.dart';
import '../../data/auth_repository.dart';
import 'submit_state.dart';

class LoginController extends Notifier<SubmitState<void>> {
  @override
  SubmitState<void> build() => const SubmitIdle();

  /// Mengirim kredensial. Panggilan kedua saat masih memuat diabaikan
  /// (mencegah klik ganda).
  Future<void> submit({required String email, required String password}) async {
    if (state.isLoading) return;
    state = const SubmitLoading();
    try {
      await ref.read(authRepositoryProvider).signInWithPassword(
            email: normalizeEmail(email),
            password: password,
          );
      if (!ref.mounted) return;
      state = const SubmitSucceeded(null);
    } on AppFailure catch (failure) {
      if (!ref.mounted) return;
      state = SubmitFailed(failure);
    } catch (error) {
      // Detail teknis hanya untuk debug; tanpa email/sandi.
      debugPrint('LoginController: ${error.runtimeType}');
      if (!ref.mounted) return;
      state = const SubmitFailed(UnknownFailure());
    }
  }

  void clearError() {
    if (state is SubmitFailed<void>) state = const SubmitIdle();
  }
}

final loginControllerProvider =
    NotifierProvider.autoDispose<LoginController, SubmitState<void>>(
  LoginController.new,
);
