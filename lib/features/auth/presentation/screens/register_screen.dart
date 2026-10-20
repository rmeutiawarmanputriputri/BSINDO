import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/feature_flags.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/tokens.dart';
import '../../../../core/errors/failure_message.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/auth_card.dart';
import '../../../../core/widgets/auth_error_banner.dart';
import '../../../../core/widgets/auth_scaffold.dart';
import '../../../../core/widgets/password_field.dart';
import '../../../../core/widgets/social_buttons.dart';
import '../../domain/sign_up_result.dart';
import '../auth_strings.dart';
import '../controllers/register_controller.dart';
import '../controllers/submit_state.dart';
import '../widgets/auth_footer_link.dart';
import '../widgets/auth_header.dart';

/// S03 Register (AUTH spec §1.3, §5.4).
/// Referensi: docs/design/reference/register.png
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;

  @override
  void dispose() {
    for (final c in [
      _nameController,
      _emailController,
      _passwordController,
      _confirmController,
    ]) {
      c.dispose();
    }
    for (final f in [_nameFocus, _emailFocus, _passwordFocus, _confirmFocus]) {
      f.dispose();
    }
    super.dispose();
  }

  String? _validateConfirm(String? value) =>
      Validators.confirmPassword(value, _passwordController.text);

  void _submit() {
    final controller = ref.read(registerControllerProvider.notifier);
    if (ref.read(registerControllerProvider).isLoading) return;
    controller.clearError();
    final valid = _formKey.currentState?.validate() ?? false;
    setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
    if (!valid) {
      _focusFirstError();
      return;
    }
    FocusScope.of(context).unfocus();
    controller.submit(
      fullName: _nameController.text,
      email: _emailController.text,
      password: _passwordController.text,
    );
  }

  void _focusFirstError() {
    if (Validators.fullName(_nameController.text) != null) {
      _nameFocus.requestFocus();
    } else if (Validators.email(_emailController.text) != null) {
      _emailFocus.requestFocus();
    } else if (Validators.newPassword(_passwordController.text) != null) {
      _passwordFocus.requestFocus();
    } else if (_validateConfirm(_confirmController.text) != null) {
      _confirmFocus.requestFocus();
    }
  }

  void _goToLogin() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<SubmitState<SignUpResult>>(registerControllerProvider, (
      previous,
      next,
    ) {
      if (next case SubmitSucceeded<SignUpResult>(:final value)) {
        switch (value) {
          case SignUpNeedsEmailVerification(:final email):
            context.go(AppRoutes.verifyEmailFor(email));
          case SignUpSignedIn():
            // Router otomatis mengarah ke /home.
            break;
        }
      }
    });

    final state = ref.watch(registerControllerProvider);
    final loading = state.isLoading;

    return AuthScaffold(
      onBack: _goToLogin,
      footer: AuthFooterLink(
        prompt: AuthStrings.haveAccount,
        action: AuthStrings.toLogin,
        onPressed: _goToLogin,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const AuthHeader(
            logoSize: AppSizes.registerLogo,
            wordmarkSize: 20,
            title: AuthStrings.registerTitle,
            subtitle: AuthStrings.registerSubtitle,
          ),
          const SizedBox(height: AppSpacing.xl),
          if (state case SubmitFailed<SignUpResult>(:final failure)) ...[
            AuthErrorBanner(
              message: failureMessage(failure),
              onDismiss:
                  ref.read(registerControllerProvider.notifier).clearError,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          AuthCard(
            padding: const EdgeInsets.all(AppSpacing.lg + 4),
            child: AutofillGroup(
              child: Form(
                key: _formKey,
                autovalidateMode: _autovalidate,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppTextField(
                      label: AuthStrings.fullNameLabel,
                      hintText: AuthStrings.fullNameHint,
                      controller: _nameController,
                      focusNode: _nameFocus,
                      enabled: !loading,
                      keyboardType: TextInputType.name,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.name],
                      validator: Validators.fullName,
                      onSubmitted: (_) => _emailFocus.requestFocus(),
                    ),
                    const SizedBox(height: AppSpacing.lg),
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
                      hintText: AuthStrings.registerPasswordHint,
                      controller: _passwordController,
                      focusNode: _passwordFocus,
                      enabled: !loading,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.newPassword],
                      validator: Validators.newPassword,
                      onSubmitted: (_) => _confirmFocus.requestFocus(),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    PasswordField(
                      label: AuthStrings.confirmPasswordLabel,
                      hintText: AuthStrings.confirmPasswordHint,
                      controller: _confirmController,
                      focusNode: _confirmFocus,
                      enabled: !loading,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.newPassword],
                      validator: _validateConfirm,
                      onSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    AppButton(
                      label: AuthStrings.registerButton,
                      trailingArrow: true,
                      loading: loading,
                      onPressed: _submit,
                    ),
                    if (FeatureFlags.enableSocialAuth) ...[
                      const SizedBox(height: AppSpacing.lg),
                      const OrDivider(text: AuthStrings.registerDivider),
                      const SizedBox(height: AppSpacing.md),
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
