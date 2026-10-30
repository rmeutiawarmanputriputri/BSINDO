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
import '../../dictionary/domain/sign.dart';
import '../../home_content/data/home_content_repository.dart';
import '../../home_content/presentation/banner_carousel.dart';
import '../../learning/data/progress_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../../study/data/study_repository.dart';
import '../../study/presentation/history_and_search_screens.dart';
import '../../study/presentation/learn_module_grid.dart';

/// Blok "Latihan ulang" Beranda: maks 5 kosakata `learning`.
final homeReviewProvider = FutureProvider.autoDispose<List<DifficultItem>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref
      .watch(difficultRepositoryProvider)
      .list(status: DifficultStatus.learning, limit: 5);
});

/// Rekomendasi: materi berikutnya yang belum dipelajari (alfabet → angka → kosakata).
final homeRecommendationsProvider = FutureProvider.autoDispose<List<Sign>>((ref) async {
  final learned = ref.watch(learnedIdsProvider);
  final out = <Sign>[];
  for (final module in ContentModule.values.reversed) {
    final list = await ref.watch(studyListProvider(module).future);
    out.addAll(list.where((s) => !learned.contains(s.id)).take(2));
  }
  return out.take(4).toList();
});

/// S07 Beranda: tiap blok memuat/gagal terpisah.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profile = ref.watch(currentProfileProvider).value;
    final unread = ref.watch(unreadAnnouncementsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Beranda'),
        actions: [
          IconButton(
            tooltip: 'Cari materi',
            icon: const Icon(Icons.search),
            onPressed: () => context.push(AppRoutes.search),
          ),
          IconButton(
            tooltip: unread > 0 ? 'Notifikasi, $unread belum dibaca' : 'Notifikasi',
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(Icons.notifications_none),
            ),
            onPressed: () async {
              await context.push(AppRoutes.notifications);
              ref.invalidate(announcementsProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(progressListProvider);
          ref.invalidate(homeReviewProvider);
          ref.invalidate(currentProfileProvider);
          ref.invalidate(progressSummaryProvider);
          ref.invalidate(learningHistoryProvider);
          ref.invalidate(bannersProvider);
          ref.invalidate(signProgressProvider);
          ref.invalidate(premiumStatusProvider);
          for (final m in ContentModule.values) {
            ref.invalidate(studyListProvider(m));
          }
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
            if (profile != null && !profile.isActive) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.errorContainer,
                  borderRadius: BorderRadius.circular(AppRadius.contentCard),
                ),
                child: const Text(
                  'Akun Anda sedang dinonaktifkan oleh pengelola, sehingga materi tidak dapat dibuka. '
                  'Hubungi admin untuk mengaktifkannya kembali.',
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            const BannerCarousel(),
            const SizedBox(height: AppSpacing.md),
            const _ContinueCard(),
            const SectionHeader(title: 'Materi belajar'),
            const LearnModuleGrid(),
            const SectionHeader(title: 'Ringkasan progres'),
            const _SummaryBlock(),
            const _RecommendationBlock(),
            const _PremiumBlock(),
            const SectionHeader(title: 'Akses cepat'),
            const _QuickGrid(),
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

/// "Mulai belajar" / materi terakhir dipelajari (riwayat lintas modul).
class _ContinueCard extends ConsumerWidget {
  const _ContinueCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(learningHistoryProvider);
    final theme = Theme.of(context);
    final white = theme.textTheme.bodyMedium?.copyWith(color: Colors.white);
    return Card(
      margin: EdgeInsets.zero,
      color: AppColors.primary,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: history.when(
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
                  onPressed: () => ref.invalidate(learningHistoryProvider),
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
          data: (list) {
            final latest = list.firstOrNull;
            if (latest == null) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mulai belajar', style: theme.textTheme.titleLarge?.copyWith(color: Colors.white)),
                  const SizedBox(height: AppSpacing.xs),
                  Text('Awali dengan mengenal huruf A–Z dalam BISINDO.', style: white),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton.tonal(
                    onPressed: () => context.push(AppRoutes.alphabet),
                    child: const Text('Mulai Belajar'),
                  ),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Terakhir dipelajari · ${latest.moduleLabel}', style: white),
                const SizedBox(height: AppSpacing.xs),
                Text(latest.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(color: Colors.white)),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    FilledButton.tonal(
                      onPressed: () => openHistoryEntry(context, latest),
                      child: const Text('Lanjutkan'),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: Colors.white),
                      onPressed: () => context.push(AppRoutes.history),
                      child: const Text('Riwayat belajar'),
                    ),
                  ],
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
      (Icons.record_voice_over_outlined, 'Transkripsi', () => context.push(AppRoutes.transcribe)),
      (Icons.flag_outlined, 'Kosakata Sulit', () => context.push(AppRoutes.difficult)),
      (Icons.favorite_border, 'Favorit', () => context.push(AppRoutes.favorites)),
      (Icons.history_edu_outlined, 'Riwayat Belajar', () => context.push(AppRoutes.history)),
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
    final summary = ref.watch(progressSummaryProvider);
    final difficult = ref.watch(homeReviewProvider).value?.length ?? 0;
    final theme = Theme.of(context);
    return summary.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => _BlockError(error: e, onRetry: () => ref.invalidate(progressSummaryProvider)),
      data: (s) => Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  value: '${s.overallPercent}%',
                  label: 'Materi dipelajari (${s.totalLearned}/${s.totalMaterials})',
                  theme: theme,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _StatTile(
                  value: s.quizSessions == 0 ? '–' : '${s.quizAverage}',
                  label: 'Rata-rata skor kuis (${s.quizSessions}×)',
                  theme: theme,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  value: '${s.conversationsCompleted}/${s.conversationsTotal}',
                  label: 'Percakapan selesai',
                  theme: theme,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _StatTile(
                  value: '$difficult${difficult >= 5 ? '+' : ''}',
                  label: 'Kosakata perlu dilatih',
                  theme: theme,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Rekomendasi materi berikutnya (tidak tampil bila kosong).
class _RecommendationBlock extends ConsumerWidget {
  const _RecommendationBlock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recs = ref.watch(homeRecommendationsProvider).value ?? const <Sign>[];
    if (recs.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Rekomendasi untuk Anda'),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final s in recs)
              ActionChip(
                avatar: Icon(
                  switch (s.contentModule) {
                    ContentModule.alphabet => Icons.abc_rounded,
                    ContentModule.number => Icons.pin_outlined,
                    ContentModule.vocabulary => Icons.menu_book_outlined,
                  },
                  size: 18,
                ),
                label: Text('${s.contentModule.label}: ${s.displayTitle}'),
                onPressed: () => context.push(AppRoutes.study(s.contentModule, s.id)),
              ),
          ],
        ),
      ],
    );
  }
}

/// Info akun Premium (hanya bila pemilik mengaktifkan info Premium di CMS
/// atau pengguna sudah Premium).
class _PremiumBlock extends ConsumerWidget {
  const _PremiumBlock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(premiumStatusProvider).value;
    final info = ref.watch(premiumInfoProvider).value;
    final isPremium = status?.isPremium ?? false;
    if (!isPremium && !(info?.enabled ?? false)) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Card(
        margin: EdgeInsets.zero,
        color: isPremium ? const Color(0xFFDCFCE7) : const Color(0xFFFFF4E0),
        child: ListTile(
          leading: Icon(isPremium ? Icons.workspace_premium : Icons.lock_open_outlined,
              color: isPremium ? AppColors.success : const Color(0xFF8A5300)),
          title: Text(isPremium ? 'Akun Premium aktif' : (info?.title ?? 'Buka semua materi dengan Premium')),
          subtitle: Text(isPremium
              ? (status?.plan != null ? 'Paket ${status!.plan}' : 'Semua materi Premium terbuka.')
              : 'Lihat informasi paket Premium.'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(AppRoutes.premium),
        ),
      ),
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
