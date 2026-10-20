import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/content_page.dart';
import '../../../core/widgets/section_header.dart';
import '../../auth/data/auth_repository.dart';
import '../../difficult_vocab/data/difficult_repository.dart';
import '../../difficult_vocab/domain/difficult_item.dart';
import '../../learning/data/learning_repository.dart';
import '../../learning/data/progress_repository.dart';
import '../../profile/data/profile_repository.dart';

/// Blok "Latihan ulang" Beranda: maks 5 kosakata `learning`.
final homeReviewProvider = FutureProvider.autoDispose<List<DifficultItem>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref
      .watch(difficultRepositoryProvider)
      .list(status: DifficultStatus.learning, limit: 5);
});

/// Blok ringkasan progres.
final homeSummaryProvider =
    FutureProvider.autoDispose<({int lessonsDone, int lessonsTotal, int difficult})>(
        (ref) async {
  final progress = await ref.watch(progressListProvider.future);
  final total = await ref.watch(learningRepositoryProvider).publishedLessonCount();
  final difficult = await ref.watch(homeReviewProvider.future);
  return (
    lessonsDone: progress
        .where((p) => p.lessonId != null && p.completed && p.title != null)
        .length,
    lessonsTotal: total,
    difficult: difficult.length,
  );
});

/// S07 Beranda: tiap blok memuat/gagal terpisah.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profile = ref.watch(currentProfileProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('Beranda')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(progressListProvider);
          ref.invalidate(homeReviewProvider);
          ref.invalidate(currentProfileProvider);
        },
        child: ContentListView(
          children: [
            Semantics(
              header: true,
              child: Text(
                'Halo, ${profile?.fullName ?? 'Teman'}!',
                style: theme.textTheme.headlineSmall,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text('Ayo lanjutkan belajar isyarat hari ini.',
                style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.lg),
            const _ContinueCard(),
            const SectionHeader(title: 'Akses cepat'),
            const _QuickGrid(),
            const SectionHeader(title: 'Ringkasan progres'),
            const _SummaryBlock(),
            SectionHeader(
              title: 'Latihan ulang',
              actionLabel: 'Lihat semua',
              onAction: () => context.push(AppRoutes.difficult),
            ),
            const _ReviewBlock(),
          ],
        ),
      ),
    );
  }
}

class _BlockError extends StatelessWidget {
  const _BlockError({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(errorMessageOf(error))),
          TextButton(onPressed: onRetry, child: const Text('Coba Lagi')),
        ],
      ),
    );
  }
}

class _ContinueCard extends ConsumerWidget {
  const _ContinueCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressListProvider);
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      color: AppColors.primary,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: progress.when(
          loading: () => const SizedBox(
            height: 72,
            child: Center(child: CircularProgressIndicator(color: Colors.white)),
          ),
          error: (e, _) => DefaultTextStyle.merge(
            style: const TextStyle(color: Colors.white),
            child: Row(
              children: [
                const Expanded(child: Text('Tidak dapat memuat materi terakhir.')),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  onPressed: () => ref.invalidate(progressListProvider),
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
          data: (list) {
            final latest = list.where((p) => p.title != null).firstOrNull;
            final white = theme.textTheme.bodyMedium?.copyWith(color: Colors.white);
            if (latest == null) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mulai belajar',
                      style: theme.textTheme.titleLarge?.copyWith(color: Colors.white)),
                  const SizedBox(height: AppSpacing.xs),
                  Text('Pilih pelajaran pertama Anda.', style: white),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton.tonal(
                    onPressed: () => context.go(AppRoutes.learn),
                    child: const Text('Lihat pelajaran'),
                  ),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Lanjutkan belajar', style: white),
                const SizedBox(height: AppSpacing.xs),
                Text(latest.title!,
                    style: theme.textTheme.titleLarge?.copyWith(color: Colors.white)),
                const SizedBox(height: AppSpacing.sm),
                LinearProgressIndicator(
                  value: latest.completed ? 1 : latest.percent / 100,
                  color: Colors.white,
                  backgroundColor: Colors.white24,
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton.tonal(
                  onPressed: () => context.push(latest.lessonId != null
                      ? AppRoutes.lesson(latest.lessonId!)
                      : AppRoutes.conversation(latest.moduleId!)),
                  child: const Text('Lanjutkan'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _QuickGrid extends StatelessWidget {
  const _QuickGrid();

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, VoidCallback)>[
      (Icons.menu_book_outlined, 'Kamus', () => context.go(AppRoutes.dictionary)),
      (Icons.forum_outlined, 'Percakapan', () => context.go(AppRoutes.conversations)),
      (Icons.record_voice_over_outlined, 'Transkripsi', () => context.push(AppRoutes.transcribe)),
      (Icons.flag_outlined, 'Kosakata Sulit', () => context.push(AppRoutes.difficult)),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisExtent: 96,
      ),
      itemBuilder: (context, i) {
        final (icon, label, onTap) = items[i];
        return Material(
          color: AppColors.inputFill,
          borderRadius: BorderRadius.circular(AppRadius.contentCard),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.contentCard),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ExcludeSemantics(child: Icon(icon, color: AppColors.primary, size: 28)),
                  const SizedBox(height: AppSpacing.xs),
                  Text(label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SummaryBlock extends ConsumerWidget {
  const _SummaryBlock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(homeSummaryProvider);
    final theme = Theme.of(context);
    return summary.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => _BlockError(error: e, onRetry: () => ref.invalidate(homeSummaryProvider)),
      data: (s) {
        final percent =
            s.lessonsTotal == 0 ? 0 : ((s.lessonsDone / s.lessonsTotal) * 100).round();
        return Row(
          children: [
            Expanded(
              child: _StatTile(
                value: '$percent%',
                label: 'Pelajaran selesai (${s.lessonsDone}/${s.lessonsTotal})',
                theme: theme,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _StatTile(
                value: '${s.difficult}${s.difficult >= 5 ? '+' : ''}',
                label: 'Kosakata perlu dilatih',
                theme: theme,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label, required this.theme});
  final String value;
  final String label;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(AppRadius.contentCard),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: theme.textTheme.headlineSmall),
              Text(label, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewBlock extends ConsumerWidget {
  const _ReviewBlock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final review = ref.watch(homeReviewProvider);
    return review.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => _BlockError(error: e, onRetry: () => ref.invalidate(homeReviewProvider)),
      data: (items) {
        final available = items.where((i) => i.sign != null).toList();
        if (available.isEmpty) {
          return const Text('Belum ada kosakata sulit. Tandai dari halaman detail kosakata.');
        }
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final item in available)
              ActionChip(
                avatar: const Icon(Icons.replay, size: 18),
                label: Text(item.sign!.term),
                onPressed: () => context.push(AppRoutes.difficultReview(item.signId)),
              ),
          ],
        );
      },
    );
  }
}
