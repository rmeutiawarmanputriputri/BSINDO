import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/tokens.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/auth_card.dart';
import '../../../../core/widgets/auth_scaffold.dart';
import '../../data/auth_repository.dart';
import '../widgets/auth_header.dart';

/// S06 Verifikasi Email. Setelah tautan email dibuka, deep link membuat sesi
/// → router otomatis mengarah ke /home.
/// [BELUM ADA DESAIN ASLI — memakai token yang sama]
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key, required this.email});

  final String email;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  static const _cooldown = 60;
  int _secondsLeft = _cooldown;
  bool _sending = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    _secondsLeft = _cooldown;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) timer.cancel();
    });
  }

  Future<void> _resend() async {
    if (_sending || _secondsLeft > 0 || widget.email.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref.read(authRepositoryProvider).resendVerification(widget.email);
      if (!mounted) return;
      showAppSnackBar(context, 'Tautan verifikasi dikirim ulang.');
      setState(_startCooldown);
    } catch (error) {
      if (mounted) showErrorSnackBar(context, error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AuthScaffold(
      footer: Center(
        child: TextButton(
          onPressed: () => context.go(AppRoutes.login),
          child: const Text('Kembali ke Masuk'),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const AuthHeader(
            logoSize: AppSizes.registerLogo,
            wordmarkSize: 20,
            title: 'Verifikasi Email',
          ),
          const SizedBox(height: AppSpacing.xl),
          AuthCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const ExcludeSemantics(
                  child: Icon(Icons.mark_email_unread_outlined,
                      size: 56, color: AppColors.primary),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  widget.email.isEmpty
                      ? 'Kami mengirim tautan verifikasi ke email Anda.'
                      : 'Kami mengirim tautan ke ${widget.email}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Buka email tersebut dan ketuk tautannya untuk mengaktifkan '
                  'akun. Periksa juga folder spam.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: _secondsLeft > 0
                      ? 'Kirim Ulang ($_secondsLeft dtk)'
                      : 'Kirim Ulang',
                  loading: _sending,
                  onPressed: _secondsLeft > 0 ? null : _resend,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
