import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/widgets/media_widgets.dart';
import '../../dictionary/domain/sign.dart';
import '../data/home_content_repository.dart';
import '../domain/home_content.dart';

/// Banner Beranda dari CMS. Tidak tampil sama sekali bila kosong/gagal
/// (bukan bagian penting; tidak boleh memblokir Beranda).
class BannerCarousel extends ConsumerStatefulWidget {
  const BannerCarousel({super.key});

  @override
  ConsumerState<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends ConsumerState<BannerCarousel> {
  final _controller = PageController(viewportFraction: 0.92);
  Timer? _timer;
  int _page = 0;

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _ensureAutoplay(int count) {
    if (count < 2 ||
        _timer != null ||
        MediaQuery.disableAnimationsOf(context)) {
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || !_controller.hasClients) return;
      _controller.animateToPage(
        (_page + 1) % count,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _open(HomeBanner b) async {
    final v = b.targetValue ?? '';
    switch (b.targetType) {
      case 'route':
        final route = AppRoutes.bannerRoute(v);
        if (route != null) context.push(route);
      case 'url':
        final uri = Uri.tryParse(v);
        if (uri != null && uri.scheme == 'https') {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      case 'sign':
        context.push(AppRoutes.study(ContentModule.vocabulary, v));
      case 'conversation':
        context.push(AppRoutes.conversation(v));
      case 'category':
        context.go(AppRoutes.dictionary);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bannerState = ref.watch(bannersProvider);
    final banners = bannerState.value ?? const <HomeBanner>[];
    final visible = banners.where((b) => b.imagePath != null).toList();
    if (visible.isEmpty) {
      // Tanpa banner aktif: banner perkenalan aplikasi (A.1), bila diaktifkan.
      final layout = ref.watch(homeLayoutProvider).value ?? const HomeLayout();
      if (bannerState.isLoading || !layout.show('intro')) {
        return const SizedBox.shrink();
      }
      return IntroBanner(layout: layout);
    }
    _ensureAutoplay(visible.length);
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 2 / 1,
          child: PageView.builder(
            controller: _controller,
            itemCount: visible.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) {
              final b = visible[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Semantics(
                  button: b.isTappable,
                  label: [
                    b.title,
                    if (b.description != null) b.description!,
                  ].join('. '),
                  excludeSemantics: true,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.contentCard),
                    child: InkWell(
                      onTap: b.isTappable ? () => _open(b) : null,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          SignedImage(path: b.imagePath!),
                          DecoratedBox(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Color(0xAA0F172A)],
                              ),
                            ),
                            child: Align(
                              alignment: Alignment.bottomLeft,
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      b.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(color: Colors.white),
                                    ),
                                    if (b.description != null)
                                      Text(
                                        b.description!,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(color: Colors.white),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (visible.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: ExcludeSemantics(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < visible.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _page ? 18 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: i == _page
                            ? AppColors.primary
                            : AppColors.outline,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Banner perkenalan aplikasi. Teks bawaan atau dari CMS (bukan materi BISINDO).
class IntroBanner extends StatelessWidget {
  const IntroBanner({super.key, required this.layout});
  final HomeLayout layout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.contentCard),
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF3B6FE0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const ExcludeSemantics(
                child: Icon(Icons.sign_language, color: Colors.white, size: 32),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    layout.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            layout.text,
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.tonalIcon(
            onPressed: () => context.go(AppRoutes.learn),
            icon: const Icon(Icons.grid_view_rounded),
            label: const Text('Lihat semua modul'),
          ),
        ],
      ),
    );
  }
}
