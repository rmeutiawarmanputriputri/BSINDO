import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../app/theme/tokens.dart';
import '../../core/errors/app_failure.dart';
import '../../core/supabase/signed_url_cache.dart';

/// Pemutar video isyarat (S10, DESIGN_SYSTEM §5): poster dulu, tanpa autoplay,
/// buffering + "Memuat video…", error + "Coba Lagi" (signed URL baru),
/// Play/Pause, Ulangi (loop), kecepatan 0,5×/1×, layar penuh, seekbar.
class VideoPlayerView extends ConsumerStatefulWidget {
  const VideoPlayerView({
    super.key,
    required this.videoPath,
    this.posterPath,
    this.semanticTitle = 'Video isyarat',
    this.aspectRatio = 16 / 9,
  });

  /// Path objek di bucket privat; null → "Video belum tersedia".
  final String? videoPath;
  final String? posterPath;
  final String semanticTitle;
  final double aspectRatio;

  @override
  ConsumerState<VideoPlayerView> createState() => _VideoPlayerViewState();
}

enum _Phase { poster, loading, ready, error }

class _VideoPlayerViewState extends ConsumerState<VideoPlayerView> {
  VideoPlayerController? _controller;
  _Phase _phase = _Phase.poster;
  String? _errorText;
  String? _posterUrl;
  bool _looping = false;
  double _speed = 1.0;

  @override
  void initState() {
    super.initState();
    _loadPoster();
  }

  @override
  void didUpdateWidget(covariant VideoPlayerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoPath != widget.videoPath) {
      _disposeController();
      setState(() => _phase = _Phase.poster);
    }
    if (oldWidget.posterPath != widget.posterPath) {
      _posterUrl = null;
      _loadPoster();
    }
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  void _disposeController() {
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    _controller = null;
  }

  Future<void> _loadPoster() async {
    final path = widget.posterPath;
    if (path == null) return;
    try {
      final url = await ref.read(signedUrlCacheProvider).get(path);
      if (mounted && widget.posterPath == path) setState(() => _posterUrl = url);
    } catch (_) {
      // Poster opsional: abaikan kegagalan.
    }
  }

  Future<void> _start() async {
    final path = widget.videoPath;
    if (path == null) return;
    setState(() {
      _phase = _Phase.loading;
      _errorText = null;
    });
    final cache = ref.read(signedUrlCacheProvider);
    VideoPlayerController? created;
    // Controller sudah dibuang (dispose/didUpdateWidget) selama jeda async.
    bool stale() => !mounted || !identical(_controller, created);
    try {
      final url = await cache.get(path);
      if (!mounted || widget.videoPath != path) return;
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      created = controller;
      _disposeController();
      _controller = controller;
      await controller.initialize();
      if (stale()) return;
      await controller.setLooping(_looping);
      await controller.setPlaybackSpeed(_speed);
      if (stale()) return;
      controller.addListener(_onTick);
      setState(() => _phase = _Phase.ready);
      await controller.play();
    } catch (error) {
      if (!mounted || widget.videoPath != path) return;
      if (created != null && !identical(_controller, created)) return;
      cache.invalidate(path);
      _disposeController();
      setState(() {
        _phase = _Phase.error;
        _errorText = error is NotFoundFailure
            ? 'Video tidak ditemukan. Anda dapat melaporkannya.'
            : 'Video gagal dimuat. Periksa koneksi lalu coba lagi.';
      });
    }
  }

  void _onTick() {
    final value = _controller?.value;
    if (value == null || !mounted) return;
    if (value.hasError && _phase != _Phase.error) {
      final path = widget.videoPath;
      if (path != null) ref.read(signedUrlCacheProvider).invalidate(path);
      setState(() {
        _phase = _Phase.error;
        _errorText = 'Pemutaran terhenti. Coba lagi.';
      });
      return;
    }
    setState(() {});
  }

  Future<void> _togglePlay() async {
    final c = _controller;
    if (c == null) return;
    if (c.value.isPlaying) {
      await c.pause();
    } else {
      if (c.value.isCompleted) await c.seekTo(Duration.zero);
      await c.play();
    }
  }

  Future<void> _toggleLoop() async {
    _looping = !_looping;
    await _controller?.setLooping(_looping);
    if (!mounted) return;
    setState(() {});
    SemanticsService.sendAnnouncement(
      View.of(context),
      _looping ? 'Ulangi aktif' : 'Ulangi nonaktif',
      Directionality.of(context),
    );
  }

  Future<void> _toggleSpeed() async {
    _speed = _speed == 1.0 ? 0.5 : 1.0;
    await _controller?.setPlaybackSpeed(_speed);
    if (mounted) setState(() {});
  }

  Future<void> _openFullscreen() async {
    final c = _controller;
    if (c == null) return;
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => _FullscreenVideoPage(controller: c),
      ),
    );
    if (!mounted || !identical(_controller, c)) return;
    // Sinkronkan pilihan yang diubah di layar penuh.
    setState(() {
      _looping = c.value.isLooping;
      _speed = c.value.playbackSpeed;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.video),
      child: ColoredBox(
        color: const Color(0xFF0F172A),
        child: AspectRatio(
          aspectRatio: _phase == _Phase.ready && _controller != null
              ? _controller!.value.aspectRatio
              : widget.aspectRatio,
          child: _buildBody(context),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);
    const onDark = TextStyle(color: Colors.white);
    if (widget.videoPath == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off_outlined, color: Colors.white70, size: 36),
            const SizedBox(height: AppSpacing.sm),
            Text('Video belum tersedia',
                style: theme.textTheme.bodyMedium?.merge(onDark)),
          ],
        ),
      );
    }
    switch (_phase) {
      case _Phase.poster:
        return Semantics(
          button: true,
          label: 'Putar ${widget.semanticTitle}',
          child: InkWell(
            onTap: _start,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_posterUrl != null)
                  Image.network(
                    _posterUrl!,
                    fit: BoxFit.cover,
                    excludeFromSemantics: true,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox.shrink(),
                  ),
                const Center(
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.play_arrow_rounded,
                        size: 40, color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
        );
      case _Phase.loading:
        return Semantics(
          liveRegion: true,
          label: 'Memuat video',
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Colors.white),
                const SizedBox(height: AppSpacing.md),
                Text('Memuat video…', style: theme.textTheme.bodyMedium?.merge(onDark)),
              ],
            ),
          ),
        );
      case _Phase.error:
        return Semantics(
          liveRegion: true,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.white, size: 32),
                  const SizedBox(height: AppSpacing.sm),
                  Text(_errorText ?? 'Video gagal dimuat.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.merge(onDark)),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton.tonal(onPressed: _start, child: const Text('Coba Lagi')),
                ],
              ),
            ),
          ),
        );
      case _Phase.ready:
        final c = _controller!;
        return Stack(
          fit: StackFit.expand,
          children: [
            Semantics(
              label: widget.semanticTitle,
              child: GestureDetector(onTap: _togglePlay, child: VideoPlayer(c)),
            ),
            if (c.value.isBuffering)
              const Center(child: CircularProgressIndicator(color: Colors.white)),
            Align(
              alignment: Alignment.bottomCenter,
              child: _Controls(
                controller: c,
                looping: _looping,
                speed: _speed,
                onTogglePlay: _togglePlay,
                onToggleLoop: _toggleLoop,
                onToggleSpeed: _toggleSpeed,
                onFullscreen: _openFullscreen,
              ),
            ),
          ],
        );
    }
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.controller,
    required this.looping,
    required this.speed,
    required this.onTogglePlay,
    required this.onToggleLoop,
    required this.onToggleSpeed,
    this.onFullscreen,
    this.onExitFullscreen,
  });

  final VideoPlayerController controller;
  final bool looping;
  final double speed;
  final VoidCallback onTogglePlay;
  final VoidCallback onToggleLoop;
  final VoidCallback onToggleSpeed;
  final VoidCallback? onFullscreen;
  final VoidCallback? onExitFullscreen;

  @override
  Widget build(BuildContext context) {
    final playing = controller.value.isPlaying;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00000000), Color(0xB3000000)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: VideoProgressIndicator(
              controller,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: Colors.white,
                bufferedColor: Colors.white38,
                backgroundColor: Colors.white24,
              ),
            ),
          ),
          IconButtonTheme(
            data: IconButtonThemeData(
              style: IconButton.styleFrom(foregroundColor: Colors.white),
            ),
            child: Row(
              children: [
                IconButton(
                  tooltip: playing ? 'Jeda' : 'Putar',
                  onPressed: onTogglePlay,
                  icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
                ),
                IconButton(
                  tooltip: looping ? 'Matikan ulangi' : 'Ulangi terus',
                  isSelected: looping,
                  onPressed: onToggleLoop,
                  icon: Icon(looping ? Icons.repeat_on_rounded : Icons.repeat_rounded),
                ),
                TextButton(
                  onPressed: onToggleSpeed,
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  child: Semantics(
                    label: 'Kecepatan ${speed == 1.0 ? 'normal' : 'setengah'}, ketuk untuk mengubah',
                    excludeSemantics: true,
                    child: Text(speed == 1.0 ? '1×' : '0,5×'),
                  ),
                ),
                const Spacer(),
                if (onFullscreen != null)
                  IconButton(
                    tooltip: 'Layar penuh',
                    onPressed: onFullscreen,
                    icon: const Icon(Icons.fullscreen_rounded),
                  ),
                if (onExitFullscreen != null)
                  IconButton(
                    tooltip: 'Keluar layar penuh',
                    onPressed: onExitFullscreen,
                    icon: const Icon(Icons.fullscreen_exit_rounded),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Layar penuh: mengizinkan landscape; keluar mengembalikan portrait.
class _FullscreenVideoPage extends StatefulWidget {
  const _FullscreenVideoPage({required this.controller});
  final VideoPlayerController controller;

  @override
  State<_FullscreenVideoPage> createState() => _FullscreenVideoPageState();
}

class _FullscreenVideoPageState extends State<_FullscreenVideoPage> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    widget.controller.addListener(_tick);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_tick);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _tick() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: c.value.aspectRatio,
                child: GestureDetector(
                  onTap: () => c.value.isPlaying ? c.pause() : c.play(),
                  child: VideoPlayer(c),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: _Controls(
                controller: c,
                looping: c.value.isLooping,
                speed: c.value.playbackSpeed,
                onTogglePlay: () => c.value.isPlaying ? c.pause() : c.play(),
                onToggleLoop: () => c.setLooping(!c.value.isLooping),
                onToggleSpeed: () =>
                    c.setPlaybackSpeed(c.value.playbackSpeed == 1.0 ? 0.5 : 1.0),
                onExitFullscreen: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
