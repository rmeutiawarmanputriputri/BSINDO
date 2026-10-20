import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/feature_flags.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/tokens.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/failure_message.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/auth_card.dart';
import '../../../../core/widgets/auth_error_banner.dart';
import '../../../../core/widgets/auth_scaffold.dart';
import '../../../../core/widgets/password_field.dart';
import '../../../../core/widgets/social_buttons.dart';
import '../auth_strings.dart';
import '../controllers/login_controller.dart';
import '../controllers/submit_state.dart';
import '../widgets/auth_footer_link.dart';
import '../widgets/auth_header.dart';

/// S02 Login (AUTH spec §1.2, §5.3). Referensi: docs/design/reference/login.png
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _submit() {
    final controller = ref.read(loginControllerProvider.notifier);
    if (ref.read(loginControllerProvider).isLoading) return;
    controller.clearError();
    final valid = _formKey.currentState?.validate() ?? false;
    setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
    if (!valid) {
      _focusFirstError();
      return;
    }
    FocusScope.of(context).unfocus();
    controller.submit(
      email: _emailController.text,
      password: _passwordController.text,
    );
  }

  void _focusFirstError() {
    if (Validators.email(_emailController.text) != null) {
      _emailFocus.requestFocus();
    } else if (Validators.loginPassword(_passwordController.text) != null) {
      _passwordFocus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sukses: router (refreshListenable) otomatis mengarah ke /home.
    final state = ref.watch(loginControllerProvider);
    final loading = state.isLoading;
    final theme = Theme.of(context);

    return AuthScaffold(
      footer: AuthFooterLink(
        prompt: AuthStrings.noAccount,
        action: AuthStrings.toRegister,
        onPressed: () => context.push(AppRoutes.register),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppSpacing.lg),
          const AuthHeader(
            logoSize: AppSizes.loginLogo,
            wordmarkSize: 22,
            wordmarkLetterSpacing: 2,
          ),
          const SizedBox(height: AppSpacing.xl),
          if (state case SubmitFailed<void>(:final failure)) ...[
            AuthErrorBanner(
              message: failureMessage(failure),
              onDismiss: ref.read(loginControllerProvider.notifier).clearError,
            ),
            if (failure case AuthFailure(code: AuthFailureCode.emailNotConfirmed))
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.push(
                    AppRoutes.verifyEmailFor(
                      normalizeEmail(_emailController.text),
                    ),
                  ),
                  child: const Text('Kirim ulang verifikasi'),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
          ],
          AuthCard(
            child: AutofillGroup(
              child: Form(
                key: _formKey,
                autovalidateMode: _autovalidate,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        AuthStrings.loginTitle,
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    AppTextField(
                      label: AuthStrings.emailLabel,
                      hintText: AuthStrings.emailHint,
                      controller: _emailController,
                      focusNode: _emailFocus,
                      enabled: !loading,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      autocorrect: false,
                      enableSuggestions: false,
                      validator: Validators.email,
                      onSubmitted: (_) => _passwordFocus.requestFocus(),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    PasswordField(
                      label: AuthStrings.passwordLabel,
                      hintText: AuthStrings.loginPasswordHint,
                      controller: _passwordController,
                      focusNode: _passwordFocus,
                      enabled: !loading,
                      textInputAction: TextInputAction.done,
                      validator: Validators.loginPassword,
                      toggleStyle: kLoginPasswordToggleStyle,
                      onSubmitted: (_) => _submit(),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: loading
                            ? null
                            : () => context.push(AppRoutes.forgotPassword),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs,
                          ),
                          textStyle: theme.textTheme.labelLarge?.copyWith(
                            fontSize: 13,
                          ),
                        ),
                        child: const Text(AuthStrings.forgotPassword),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppButton(
                      label: AuthStrings.loginButton,
                      trailingArrow: true,
                      loading: loading,
                      onPressed: _submit,
                    ),
                    if (FeatureFlags.enableSocialAuth) ...[
                      const SizedBox(height: AppSpacing.xl),
                      const OrDivider(text: AuthStrings.loginDivider),
                      const SizedBox(height: AppSpacing.lg),
                      // TODO(K-03): isi tombol sosial setelah integrasi nyata.
                      const SocialButtonRow(buttons: []),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
