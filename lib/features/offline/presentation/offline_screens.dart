import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/content_page.dart';
import '../../../core/widgets/media_widgets.dart';
import '../../../core/widgets/source_card.dart';
import '../../../core/widgets/state_views.dart';
import '../../dictionary/domain/sign.dart';
import '../../video/video_player_view.dart';
import '../data/offline_repository.dart';

/// Daftar materi yang disimpan di perangkat (H.5 Offline Cache).
class OfflineListScreen extends ConsumerWidget {
  const OfflineListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signs = ref.watch(offlineSignsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Materi Offline'),
        actions: [
          if ((signs.value ?? const <Sign>[]).isNotEmpty)
            IconButton(
              tooltip: 'Hapus semua unduhan',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () async {
                final ok = await showConfirmDialog(
                  context,
                  title: 'Hapus semua unduhan?',
                  message:
                      'Video, gambar, dan audio yang disimpan di perangkat akan dihapus. '
                      'Materi tetap bisa dibuka saat online.',
                  confirmLabel: 'Hapus',
                  destructive: true,
                );
                if (!ok) return;
                await ref.read(offlineSignsProvider.notifier).clearAll();
                if (context.mounted) {
                  showAppSnackBar(context, 'Semua unduhan dihapus');
                }
              },
            ),
        ],
      ),
      body: AsyncValueView<List<Sign>>(
        value: signs,
        onRetry: () => ref.invalidate(offlineSignsProvider),
        isEmpty: (list) => list.isEmpty,
        empty: const EmptyView(
          icon: Icons.download_outlined,
          title: 'Belum ada materi offline',
          message:
              'Buka materi huruf, angka, atau kosakata, lalu ketuk "Simpan offline" '
              'agar bisa dibuka tanpa internet.',
        ),
        data: (list) => ContentListView(
          children: [
            Text(
              '${list.length} materi tersimpan di perangkat ini.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final s in list)
              Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      s.displayTitle.characters.take(2).toString(),
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  title: Text(s.displayTitle),
                  subtitle: Text(
                    [
                      s.contentModule.label,
                      if (s.categoryName != null) s.categoryName!,
                    ].join(' · '),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.offlineSign(s.id)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Detail materi dari data yang disimpan di perangkat (tanpa koneksi).
class OfflineSignScreen extends ConsumerWidget {
  const OfflineSignScreen({super.key, required this.signId});
  final String signId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(offlineSignsProvider);
    final sign = (list.value ?? const <Sign>[])
        .where((s) => s.id == signId)
        .firstOrNull;
    final theme = Theme.of(context);
    Widget section(String title, String? body) {
      if (body == null || body.trim().isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(title, style: theme.textTheme.titleSmall),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(body, style: theme.textTheme.bodyLarge),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Materi Offline')),
      body: list.isLoading
          ? const LoadingView()
          : sign == null
          ? const EmptyView(
              icon: Icons.download_outlined,
              title: 'Materi tidak ada di perangkat',
              message: 'Materi ini sudah dihapus dari daftar offline.',
            )
          : ContentListView(
              children: [
                if (sign.contentModule != ContentModule.vocabulary)
                  Center(
                    child: Text(
                      sign.displayTitle,
                      style: theme.textTheme.displayLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                VideoPlayerView(
                  videoPath: sign.videoPath,
                  posterPath: sign.thumbnailPath,
                  semanticTitle: 'Video isyarat ${sign.displayTitle}',
                ),
                const SizedBox(height: AppSpacing.lg),
                Semantics(
                  header: true,
                  child: Text(sign.term, style: theme.textTheme.headlineSmall),
                ),
                if (sign.categoryName != null)
                  Text(
                    'Kategori: ${sign.categoryName}',
                    style: theme.textTheme.bodyMedium,
                  ),
                if (sign.audioPath != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AudioPlayButton(path: sign.audioPath!),
                  ),
                ],
                section(
                  sign.contentModule == ContentModule.vocabulary
                      ? 'Arti'
                      : 'Keterangan',
                  sign.meaning,
                ),
                section('Petunjuk gerakan tangan', sign.movementDescription),
                if (sign.imagePath != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Panduan visual gerakan',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.contentCard),
                    child: SignedImage(
                      path: sign.imagePath!,
                      fit: BoxFit.contain,
                      aspectRatio: 4 / 3,
                      semanticLabel:
                          'Panduan visual gerakan ${sign.displayTitle}',
                    ),
                  ),
                ],
                section('Contoh penggunaan', sign.usageExample),
                const SizedBox(height: AppSpacing.lg),
                SourceCard(
                  sourceNote: sign.sourceNote,
                  validatedBy: sign.validatedBy,
                  verifiedAt: sign.verifiedAt,
                ),
                const SizedBox(height: AppSpacing.lg),
                OutlinedButton.icon(
                  onPressed: () async {
                    await ref
                        .read(offlineSignsProvider.notifier)
                        .remove(sign.id);
                    if (context.mounted) {
                      showAppSnackBar(context, 'Dihapus dari materi offline');
                      context.pop();
                    }
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Hapus unduhan offline'),
                ),
              ],
            ),
    );
  }
}
