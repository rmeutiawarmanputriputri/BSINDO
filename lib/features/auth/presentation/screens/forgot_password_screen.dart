import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
import '../../data/auth_repository.dart';
import '../widgets/auth_header.dart';

/// S04 Lupa Kata Sandi. [BELUM ADA DESAIN ASLI — memakai token yang sama]
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  static const _cooldown = 60;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _loading = false;
  bool _sent = false;
  String? _error;
  int _secondsLeft = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _emailController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _secondsLeft = _cooldown);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) timer.cancel();
    });
  }

  Future<void> _submit() async {
    if (_loading || _secondsLeft > 0) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .sendPasswordReset(normalizeEmail(_emailController.text));
      if (!mounted) return;
      setState(() => _sent = true);
      _startCooldown();
    } on AppFailure catch (failure) {
      if (!mounted) return;
      // Pesan netral untuk semua kegagalan non-jaringan (anti enumerasi).
      if (failure is NetworkFailure || failure is RateLimitFailure) {
        setState(() => _error = failureMessage(failure));
      } else {
        setState(() => _sent = true);
        _startCooldown();
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AuthScaffold(
      onBack: () => context.canPop() ? context.pop() : context.go(AppRoutes.login),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const AuthHeader(
            logoSize: AppSizes.registerLogo,
            wordmarkSize: 20,
            title: 'Lupa Kata Sandi',
            subtitle: 'Masukkan email akun Anda. Kami akan mengirim tautan '
                'untuk membuat kata sandi baru.',
          ),
          const SizedBox(height: AppSpacing.xl),
          if (_error != null) ...[
            AuthErrorBanner(
              message: _error!,
              onDismiss: () => setState(() => _error = null),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          AuthCard(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_sent)
                    Semantics(
                      liveRegion: true,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const ExcludeSemantics(
                              child: Icon(Icons.mark_email_read_outlined,
                                  color: AppColors.success),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                'Jika email terdaftar, tautan telah dikirim.',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  AppTextField(
                    label: 'Alamat Email',
                    hintText: 'Email Anda (contoh: nama@email.com)',
                    controller: _emailController,
                    enabled: !_loading,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.email],
                    autocorrect: false,
                    enableSuggestions: false,
                    validator: Validators.email,
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(
                    label: _secondsLeft > 0
                        ? 'Kirim ulang dalam $_secondsLeft dtk'
                        : (_sent ? 'Kirim Ulang' : 'Kirim Tautan'),
                    loading: _loading,
                    onPressed: _secondsLeft > 0 ? null : _submit,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
