import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../app/router/routes.dart';
import '../../app/theme/tokens.dart';
import '../supabase/signed_url_cache.dart';

/// Gambar dari bucket privat (signed URL). Menampilkan placeholder saat memuat
/// dan pesan saat gagal; tidak pernah melempar ke UI.
class SignedImage extends ConsumerStatefulWidget {
  const SignedImage({
    super.key,
    required this.path,
    this.semanticLabel,
    this.fit = BoxFit.cover,
    this.aspectRatio,
  });

  final String path;
  final String? semanticLabel;
  final BoxFit fit;
  final double? aspectRatio;

  @override
  ConsumerState<SignedImage> createState() => _SignedImageState();
}

class _SignedImageState extends ConsumerState<SignedImage> {
  String? _url;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant SignedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _url = null;
      _failed = false;
      _load();
    }
  }

  Future<void> _load() async {
    final path = widget.path;
    try {
      final url = await ref.read(signedUrlCacheProvider).get(path);
      if (mounted && widget.path == path) setState(() => _url = url);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (_failed) {
      child = const _ImagePlaceholder(icon: Icons.broken_image_outlined, text: 'Gambar gagal dimuat');
    } else if (_url == null) {
      child = const _ImagePlaceholder(icon: Icons.image_outlined);
    } else {
      child = Image.network(
        _url!,
        fit: widget.fit,
        semanticLabel: widget.semanticLabel,
        errorBuilder: (_, _, _) {
          ref.read(signedUrlCacheProvider).invalidate(widget.path);
          return const _ImagePlaceholder(icon: Icons.broken_image_outlined, text: 'Gambar gagal dimuat');
        },
        loadingBuilder: (context, img, progress) =>
            progress == null ? img : const _ImagePlaceholder(icon: Icons.image_outlined),
      );
    }
    final ratio = widget.aspectRatio;
    return ratio == null ? child : AspectRatio(aspectRatio: ratio, child: child);
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({required this.icon, this.text});
  final IconData icon;
  final String? text;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.inputFill,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.textSecondary),
            if (text != null)
              Text(text!, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

/// Tombol putar/jeda audio (voice). Memakai `video_player` (ExoPlayer) yang
/// juga memutar MP3/M4A/AAC — tanpa dependensi tambahan.
class AudioPlayButton extends ConsumerStatefulWidget {
  const AudioPlayButton({super.key, required this.path, this.label = 'Putar suara'});

  final String path;
  final String label;

  @override
  ConsumerState<AudioPlayButton> createState() => _AudioPlayButtonState();
}

class _AudioPlayButtonState extends ConsumerState<AudioPlayButton> {
  VideoPlayerController? _controller;
  bool _loading = false;
  bool _error = false;

  @override
  void didUpdateWidget(covariant AudioPlayButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) _dispose();
  }

  @override
  void dispose() {
    _dispose();
    super.dispose();
  }

  void _dispose() {
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    _controller = null;
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  Future<void> _toggle() async {
    final c = _controller;
    if (c != null && c.value.isInitialized) {
      if (c.value.isPlaying) {
        await c.pause();
      } else {
        if (c.value.position >= c.value.duration) await c.seekTo(Duration.zero);
        await c.play();
      }
      return;
    }
    setState(() {
      _loading = true;
      _error = false;
    });
    final path = widget.path;
    final cache = ref.read(signedUrlCacheProvider);
    try {
      final url = await cache.get(path);
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await controller.initialize();
      if (!mounted || widget.path != path) {
        await controller.dispose();
        return;
      }
      _dispose();
      _controller = controller..addListener(_onTick);
      await controller.play();
    } catch (_) {
      cache.invalidate(path);
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final playing = _controller?.value.isPlaying ?? false;
    return OutlinedButton.icon(
      onPressed: _loading ? null : _toggle,
      icon: _loading
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(_error
              ? Icons.refresh
              : playing
                  ? Icons.pause_circle_outline
                  : Icons.volume_up_outlined),
      label: Text(_error ? 'Gagal — coba lagi' : (playing ? 'Jeda suara' : widget.label)),
    );
  }
}

/// Kartu pengganti media untuk konten Premium yang belum dibuka.
class PremiumLockCard extends StatelessWidget {
  const PremiumLockCard({super.key, this.message = 'Materi ini khusus pengguna Premium.'});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E0),
        borderRadius: BorderRadius.circular(AppRadius.video),
        border: Border.all(color: AppColors.accent),
      ),
      child: Column(
        children: [
          const ExcludeSemantics(child: Icon(Icons.lock_outline, size: 40, color: Color(0xFF8A5300))),
          const SizedBox(height: AppSpacing.sm),
          Text('Konten Premium', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(message, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.md),
          FilledButton.tonal(
            onPressed: () => context.push(AppRoutes.premium),
            child: const Text('Lihat info Premium'),
          ),
        ],
      ),
    );
  }
}

/// Lencana kecil "Premium" untuk daftar.
class PremiumBadge extends StatelessWidget {
  const PremiumBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Premium',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF4E0),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.workspace_premium_outlined, size: 14, color: Color(0xFF8A5300)),
            SizedBox(width: 2),
            Text('Premium', style: TextStyle(fontSize: 11, color: Color(0xFF8A5300), fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
