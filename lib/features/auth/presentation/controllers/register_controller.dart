import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/utils/validators.dart';
import '../../data/auth_repository.dart';
import '../../domain/sign_up_result.dart';
import 'submit_state.dart';

class RegisterController extends Notifier<SubmitState<SignUpResult>> {
  @override
  SubmitState<SignUpResult> build() => const SubmitIdle();

  Future<void> submit({
    required String fullName,
    required String email,
    required String password,
  }) async {
    if (state.isLoading) return;
    state = const SubmitLoading();
    try {
      final result = await ref.read(authRepositoryProvider).signUp(
            fullName: fullName.trim(),
            email: normalizeEmail(email),
            password: password,
          );
      if (!ref.mounted) return;
      state = SubmitSucceeded(result);
    } on AppFailure catch (failure) {
      if (!ref.mounted) return;
      state = SubmitFailed(failure);
    } catch (error) {
      debugPrint('RegisterController: ${error.runtimeType}');
      if (!ref.mounted) return;
      state = const SubmitFailed(UnknownFailure());
    }
  }

  void clearError() {
    if (state is SubmitFailed<SignUpResult>) state = const SubmitIdle();
  }
}

final registerControllerProvider =
    NotifierProvider.autoDispose<RegisterController, SubmitState<SignUpResult>>(
  RegisterController.new,
);
