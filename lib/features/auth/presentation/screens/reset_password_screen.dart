import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/tokens.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/failure_message.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/auth_card.dart';
import '../../../../core/widgets/auth_error_banner.dart';
import '../../../../core/widgets/auth_scaffold.dart';
import '../../../../core/widgets/password_field.dart';
import '../../data/auth_repository.dart';
import '../widgets/auth_header.dart';

/// S05 Atur Kata Sandi Baru (dibuka dari deep link recovery).
/// [BELUM ADA DESAIN ASLI — memakai token yang sama]
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _expired = false;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).updatePassword(_password.text);
      if (!mounted) return;
      ref.read(authRouterNotifierProvider).completePasswordRecovery();
      showAppSnackBar(context, 'Kata sandi berhasil diperbarui.');
      context.go(AppRoutes.home);
    } on AppFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        // Sesi recovery hilang/kedaluwarsa → minta tautan baru.
        _expired = failure is PermissionFailure ||
            (failure is UnknownFailure &&
                !ref.read(authRepositoryProvider).isSignedIn);
        _error = _expired
            ? 'Tautan sudah kedaluwarsa. Minta tautan baru.'
            : failureMessage(failure);
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const AuthHeader(
            logoSize: AppSizes.registerLogo,
            wordmarkSize: 20,
            title: 'Atur Kata Sandi Baru',
            subtitle: 'Buat kata sandi baru minimal 8 karakter.',
          ),
          const SizedBox(height: AppSpacing.xl),
          if (_error != null) ...[
            AuthErrorBanner(message: _error!),
            const SizedBox(height: AppSpacing.md),
          ],
          AuthCard(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  PasswordField(
                    label: 'Kata Sandi Baru',
                    hintText: 'Buat kata sandi minimal 8 karakter',
                    controller: _password,
                    enabled: !_loading,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                    validator: Validators.newPassword,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  PasswordField(
                    label: 'Konfirmasi Kata Sandi',
                    hintText: 'Ulangi kata sandi Anda',
                    controller: _confirm,
                    enabled: !_loading,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.newPassword],
                    validator: (v) => Validators.confirmPassword(v, _password.text),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(
                    label: 'Simpan Kata Sandi',
                    loading: _loading,
                    onPressed: _submit,
                  ),
                  if (_expired) ...[
                    const SizedBox(height: AppSpacing.md),
                    TextButton(
                      onPressed: () {
                        ref.read(authRouterNotifierProvider).completePasswordRecovery();
                        context.go(AppRoutes.forgotPassword);
                      },
                      child: const Text('Minta tautan baru'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
