import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/tokens.dart';
import '../../../../core/widgets/brand_logo.dart';

/// S01 Splash (AUTH spec §1.1, §5.1): biru solid + wordmark putih.
///
/// Fase 1: belum ada inisialisasi Supabase/cek sesi — hanya durasi minimum
/// lalu ke `/login`. TODO(P3): tunggu `Supabase.initialize` + pemulihan sesi
/// (maks 8 s), arahkan ke `/home` bila sesi valid.
class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    this.minDuration = AppDurations.splashMinimum,
  });

  final Duration minDuration;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.minDuration, _goNext);
  }

  void _goNext() {
    if (!mounted) return;
    context.go(AppRoutes.login);
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
