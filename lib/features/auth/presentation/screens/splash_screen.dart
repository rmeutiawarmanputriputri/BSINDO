import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/tokens.dart';
import '../../../../core/widgets/brand_logo.dart';
import '../../data/auth_repository.dart';

/// S01 Splash (AUTH spec §1.1, §5.1): biru solid + wordmark putih.
///
/// `Supabase.initialize` (memulihkan sesi tersimpan) sudah selesai di
/// `main.dart`; layar ini menahan minimal 600 ms agar tidak berkedip lalu
/// mengarah ke `/home` (sesi ada, termasuk saat offline) atau `/login`.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({
    super.key,
    this.minDuration = AppDurations.splashMinimum,
  });

  final Duration minDuration;

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.minDuration, _goNext);
  }

  void _goNext() {
    if (!mounted) return;
    final signedIn = ref.read(authRepositoryProvider).isSignedIn;
    context.go(signedIn ? AppRoutes.home : AppRoutes.login);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    // Wordmark ±46% lebar layar seperti gambar, dibatasi.
    final fontSize = (width * 0.12).clamp(36.0, 56.0);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Latar gelap → ikon status bar terang.
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.brandDeep,
        body: Align(
          // Sedikit di atas tengah vertikal (gambar).
          alignment: const Alignment(0, -0.08),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: BrandWordmark(
                color: Colors.white,
                fontSize: fontSize,
                semanticLabel: 'BISINDO, memuat aplikasi',
              ),
            ),
          ),
        ),
      ),
    );
  }
}
