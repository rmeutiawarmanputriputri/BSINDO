import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/content_page.dart';
import '../../../core/widgets/state_views.dart';
import '../../video/video_player_view.dart';
import '../data/difficult_repository.dart';
import '../domain/difficult_item.dart';

/// S21 Latihan Ulang: arti disembunyikan dulu; "Sudah paham" / "Masih sulit".
class DifficultReviewScreen extends ConsumerWidget {
  const DifficultReviewScreen({super.key, required this.signId});

  final String signId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Daftar lengkap (semua status) agar item yang dibuka tetap ditemukan.
    final learning = ref.watch(difficultListProvider(DifficultStatus.learning));
    final relearned = ref.watch(difficultListProvider(DifficultStatus.relearned));
    final combined = learning.whenData(
      (a) => [...a, ...(relearned.value ?? const <DifficultItem>[])],
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Latihan Ulang')),
      body: AsyncValueView<List<DifficultItem>>(
        value: combined,
        onRetry: () => ref.invalidate(difficultListProvider),
        data: (items) {
          final item = items.where((i) => i.signId == signId).firstOrNull;
          if (item == null || item.sign == null) {
            return const EmptyView(
              icon: Icons.inventory_2_outlined,
              title: 'Materi tidak tersedia',
              message: 'Kosakata ini tidak ada di daftar sulit Anda.',
            );
          }
          final next = (learning.value ?? const <DifficultItem>[])
              .where((i) => i.signId != signId && i.sign != null)
              .firstOrNull;
          return _ReviewBody(key: ValueKey(item.id), item: item, next: next);
        },
      ),
    );
  }
}

class _ReviewBody extends ConsumerStatefulWidget {
  const _ReviewBody({super.key, required this.item, this.next});
  final DifficultItem item;
  final DifficultItem? next;

  @override
  ConsumerState<_ReviewBody> createState() => _ReviewBodyState();
}

class _ReviewBodyState extends ConsumerState<_ReviewBody> {
  bool _showMeaning = false;
  bool _saving = false;

  Future<void> _answer({required bool understood}) async {
    setState(() => _saving = true);
    try {
      await ref.read(difficultRepositoryProvider).review(widget.item, understood: understood);
      if (!mounted) return;
      ref.invalidate(difficultListProvider);
      showAppSnackBar(context, understood ? 'Bagus! Ditandai sudah paham.' : 'Tetap di daftar latihan.');
      final next = widget.next;
      if (next != null) {
        context.pushReplacement(AppRoutes.difficultReview(next.signId));
      } else {
        context.pop();
      }
    } catch (error) {
      if (mounted) showErrorSnackBar(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sign = widget.item.sign!;
    final theme = Theme.of(context);
    return ContentListView(
      children: [
        VideoPlayerView(
          videoPath: sign.videoPath,
          posterPath: sign.thumbnailPath,
          semanticTitle: 'Video isyarat untuk latihan',
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Perhatikan gerakannya, lalu tebak artinya.', style: theme.textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.md),
        if (!_showMeaning)
          OutlinedButton.icon(
            onPressed: () => setState(() => _showMeaning = true),
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('Tampilkan arti'),
          )
        else
          Semantics(
            liveRegion: true,
            child: Card(
              margin: EdgeInsets.zero,
              color: AppColors.inputFill,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sign.term, style: theme.textTheme.headlineSmall),
                    if (sign.meaning != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(sign.meaning!, style: theme.textTheme.bodyLarge),
                    ],
                    if (sign.movementDescription != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text('Petunjuk gerakan', style: theme.textTheme.titleSmall),
                      Text(sign.movementDescription!),
                    ],
                    if (sign.usageExample != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text('Contoh', style: theme.textTheme.titleSmall),
                      Text(sign.usageExample!),
                    ],
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _saving ? null : () => _answer(understood: false),
                child: const Text('Masih sulit'),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: FilledButton(
                onPressed: _saving ? null : () => _answer(understood: true),
                child: const Text('Sudah paham'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Dilatih ${widget.item.reviewCount}× · latihan manual (tanpa jadwal otomatis).',
          style: theme.textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
