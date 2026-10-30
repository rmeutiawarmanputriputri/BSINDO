import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/content_page.dart';
import '../../../core/widgets/media_widgets.dart';
import '../../../core/widgets/source_card.dart';
import '../../difficult_vocab/data/difficult_repository.dart';
import '../../dictionary/data/sign_repository.dart';
import '../../dictionary/domain/sign.dart';
import '../../favorites/data/favorites_repository.dart';
import '../../home_content/data/home_content_repository.dart';
import '../../reports/domain/report.dart';
import '../../video/video_player_view.dart';
import '../data/study_repository.dart';

/// Detail materi (huruf, angka, atau kosakata) dengan navigasi
/// sebelumnya/berikutnya, video (0,5×/0,75×/1×), panduan visual, audio,
/// tanda "sudah dipelajari", favorit, kosakata sulit, dan laporan.
///
/// [learnMode] = mode belajar berurutan (tombol "Sudah paham, lanjut").
class SignStudyScreen extends ConsumerWidget {
  const SignStudyScreen({
    super.key,
    required this.module,
    required this.signId,
    this.learnMode = false,
  });

  final ContentModule module;
  final String signId;
  final bool learnMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sign = ref.watch(signDetailProvider(signId));
    final title = switch (module) {
      ContentModule.alphabet => learnMode ? 'Mode Belajar Alfabet' : 'Alfabet',
      ContentModule.number => learnMode ? 'Mode Belajar Angka' : 'Angka',
      ContentModule.vocabulary => 'Detail Kosakata',
    };
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: AsyncValueView<Sign>(
        value: sign,
        onRetry: () => ref.invalidate(signDetailProvider(signId)),
        data: (s) => _StudyBody(sign: s, module: module, learnMode: learnMode),
      ),
    );
  }
}

class _StudyBody extends ConsumerStatefulWidget {
  const _StudyBody({required this.sign, required this.module, required this.learnMode});
  final Sign sign;
  final ContentModule module;
  final bool learnMode;

  @override
  ConsumerState<_StudyBody> createState() => _StudyBodyState();
}

class _StudyBodyState extends ConsumerState<_StudyBody> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Riwayat belajar: catat materi dibuka (gagal diam-diam).
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(signProgressProvider.notifier).markViewed(widget.sign.id),
    );
  }

  /// Daftar saudara untuk navigasi: huruf/angka satu modul; kosakata satu kategori.
  List<Sign> _siblings() {
    final all = ref.watch(studyListProvider(widget.module)).value ?? const <Sign>[];
    if (widget.module != ContentModule.vocabulary) return all;
    return all.where((s) => s.categoryId == widget.sign.categoryId).toList();
  }

  void _goTo(Sign target) {
    context.pushReplacement(
      AppRoutes.study(widget.module, target.id, learnMode: widget.learnMode),
    );
  }

  Future<void> _setLearned(bool value, {Sign? thenGoTo}) async {
    setState(() => _busy = true);
    try {
      await ref.read(signProgressProvider.notifier).setLearned(widget.sign.id, value);
      if (!mounted) return;
      if (thenGoTo != null) {
        _goTo(thenGoTo);
      } else {
        showAppSnackBar(context, value ? 'Ditandai sudah dipelajari 👍' : 'Tanda dipelajari dihapus');
      }
    } catch (error) {
      if (mounted) showErrorSnackBar(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finishLearnMode() async {
    await _setLearned(true);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.emoji_events_outlined, size: 40, color: AppColors.accent),
        title: const Text('Selesai!'),
        content: Text('Anda telah menyelesaikan semua materi ${widget.module.label.toLowerCase()}. '
            'Uji pemahaman Anda dengan kuis.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Tutup')),
        ],
      ),
    );
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final sign = widget.sign;
    final theme = Theme.of(context);
    final learned = ref.watch(learnedIdsProvider).contains(sign.id);
    final isPremiumUser = ref.watch(isPremiumProvider);
    final locked = sign.isPremium && !isPremiumUser;
    final siblings = _siblings();
    final index = siblings.indexWhere((s) => s.id == sign.id);
    final prev = index > 0 ? siblings[index - 1] : null;
    final next = index >= 0 && index < siblings.length - 1 ? siblings[index + 1] : null;
    final isFavorite = (ref.watch(favoriteIdsProvider).value ?? const <String>{}).contains(sign.id);
    final isDifficult = (ref.watch(difficultIdsProvider).value ?? const <String>{}).contains(sign.id);
    final isVocab = widget.module == ContentModule.vocabulary;

    Widget section(String title, String? body) {
      if (body == null || body.trim().isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(header: true, child: Text(title, style: theme.textTheme.titleSmall)),
            const SizedBox(height: AppSpacing.xs),
            Text(body, style: theme.textTheme.bodyLarge),
          ],
        ),
      );
    }

    return ContentListView(
      children: [
        if (index >= 0 && siblings.length > 1) ...[
          Text(
            '${widget.module == ContentModule.alphabet ? 'Huruf' : widget.module == ContentModule.number ? 'Angka' : 'Materi'} '
            '${index + 1} dari ${siblings.length}',
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xs),
          LinearProgressIndicator(value: (index + 1) / siblings.length),
          const SizedBox(height: AppSpacing.md),
        ],
        // Huruf/angka besar
        if (!isVocab)
          Center(
            child: Semantics(
              header: true,
              child: Text(
                sign.displayTitle,
                style: theme.textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        if (locked)
          const PremiumLockCard()
        else
          VideoPlayerView(
            key: ValueKey(sign.id),
            videoPath: sign.videoPath,
            posterPath: sign.thumbnailPath,
            semanticTitle: 'Video isyarat ${sign.displayTitle}',
          ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (isVocab || sign.term != sign.displayTitle)
              Semantics(header: isVocab, child: Text(sign.term, style: theme.textTheme.headlineSmall)),
            if (isVocab) Chip(label: Text(sign.entryType.label)),
            if (sign.isPremium) const PremiumBadge(),
            if (learned)
              const Chip(
                avatar: Icon(Icons.check_circle, color: AppColors.success, size: 18),
                label: Text('Sudah dipelajari'),
              ),
            if (sign.isSample) const SampleBadge(),
          ],
        ),
        if (sign.categoryName != null)
          Text('Kategori: ${sign.categoryName}', style: theme.textTheme.bodyMedium),
        if (!locked && sign.audioPath != null) ...[
          const SizedBox(height: AppSpacing.md),
          Align(alignment: Alignment.centerLeft, child: AudioPlayButton(path: sign.audioPath!)),
        ],
        section(isVocab ? 'Arti' : 'Keterangan', sign.meaning),
        section('Petunjuk gerakan tangan', sign.movementDescription),
        if (!locked && sign.imagePath != null) ...[
          const SizedBox(height: AppSpacing.lg),
          Semantics(header: true, child: Text('Panduan visual gerakan', style: theme.textTheme.titleSmall)),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.contentCard),
            child: SignedImage(
              path: sign.imagePath!,
              fit: BoxFit.contain,
              aspectRatio: 4 / 3,
              semanticLabel: 'Panduan visual gerakan ${sign.displayTitle}',
            ),
          ),
        ],
        section('Contoh penggunaan', sign.usageExample),
        const SizedBox(height: AppSpacing.lg),
        // Mode belajar: satu tombol utama untuk lanjut.
        if (widget.learnMode)
          FilledButton.icon(
            onPressed: _busy
                ? null
                : next != null
                    ? () => _setLearned(true, thenGoTo: next)
                    : _finishLearnMode,
            icon: Icon(next != null ? Icons.arrow_forward_rounded : Icons.flag_circle_outlined),
            label: Text(next != null ? 'Sudah paham, lanjut' : 'Selesai'),
          )
        else
          FilledButton.icon(
            onPressed: _busy ? null : () => _setLearned(!learned),
            style: learned ? FilledButton.styleFrom(backgroundColor: AppColors.success) : null,
            icon: Icon(learned ? Icons.check_circle : Icons.check_circle_outline),
            label: Text(learned ? 'Sudah dipelajari' : 'Tandai sudah dipelajari'),
          ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: prev == null ? null : () => _goTo(prev),
                icon: const Icon(Icons.chevron_left),
                label: Text(prev == null ? 'Sebelumnya' : prev.displayTitle, overflow: TextOverflow.ellipsis),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: next == null ? null : () => _goTo(next),
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.chevron_right),
                label: Text(next == null ? 'Berikutnya' : next.displayTitle, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        SourceCard(sourceNote: sign.sourceNote, validatedBy: sign.validatedBy, verifiedAt: sign.verifiedAt),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                try {
                  final added = await ref.read(favoriteIdsProvider.notifier).toggle(sign.id);
                  if (context.mounted) {
                    showAppSnackBar(context, added ? 'Ditambahkan ke favorit' : 'Dihapus dari favorit');
                  }
                } catch (error) {
                  if (context.mounted) showErrorSnackBar(context, error);
                }
              },
              icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
              label: Text(isFavorite ? 'Favorit' : 'Tambah Favorit'),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                try {
                  final marked = await ref.read(difficultIdsProvider.notifier).toggle(sign.id);
                  if (context.mounted) {
                    showAppSnackBar(context, marked ? 'Ditambahkan ke daftar sulit' : 'Dihapus dari daftar sulit');
                  }
                } catch (error) {
                  if (context.mounted) showErrorSnackBar(context, error);
                }
              },
              icon: Icon(isDifficult ? Icons.flag : Icons.flag_outlined),
              label: Text(isDifficult ? 'Hapus dari daftar sulit' : 'Tandai Sulit'),
            ),
            OutlinedButton.icon(
              onPressed: () => context.push(
                AppRoutes.newReport(type: ReportTargetType.sign.value, id: sign.id, title: sign.term),
              ),
              icon: const Icon(Icons.report_outlined),
              label: const Text('Laporkan'),
            ),
          ],
        ),
      ],
    );
  }
}
