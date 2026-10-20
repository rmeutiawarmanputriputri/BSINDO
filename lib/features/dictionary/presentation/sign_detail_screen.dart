import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/content_page.dart';
import '../../../core/widgets/source_card.dart';
import '../../difficult_vocab/data/difficult_repository.dart';
import '../../favorites/data/favorites_repository.dart';
import '../../reports/domain/report.dart';
import '../../video/video_player_view.dart';
import '../data/sign_repository.dart';
import '../domain/sign.dart';

/// S09 Detail Kosakata.
class SignDetailScreen extends ConsumerWidget {
  const SignDetailScreen({super.key, required this.signId});

  final String signId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sign = ref.watch(signDetailProvider(signId));
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Kosakata')),
      body: AsyncValueView<Sign>(
        value: sign,
        onRetry: () => ref.invalidate(signDetailProvider(signId)),
        data: (sign) => _SignDetailBody(sign: sign),
      ),
    );
  }
}

class _SignDetailBody extends ConsumerWidget {
  const _SignDetailBody({required this.sign});

  final Sign sign;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isFavorite =
        (ref.watch(favoriteIdsProvider).value ?? const <String>{}).contains(sign.id);
    final isDifficult =
        (ref.watch(difficultIdsProvider).value ?? const <String>{}).contains(sign.id);

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
        VideoPlayerView(
          videoPath: sign.videoPath,
          posterPath: sign.thumbnailPath,
          semanticTitle: 'Video isyarat ${sign.term}',
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Semantics(
              header: true,
              child: Text(sign.term, style: theme.textTheme.headlineSmall),
            ),
            Chip(label: Text(sign.entryType.label)),
            if (sign.isSample) const SampleBadge(),
          ],
        ),
        if (sign.categoryName != null)
          Text('Kategori: ${sign.categoryName}', style: theme.textTheme.bodyMedium),
        section('Arti', sign.meaning),
        section('Petunjuk gerakan', sign.movementDescription),
        section('Contoh penggunaan', sign.usageExample),
        const SizedBox(height: AppSpacing.lg),
        SourceCard(
          sourceNote: sign.sourceNote,
          validatedBy: sign.validatedBy,
          verifiedAt: sign.verifiedAt,
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                try {
                  final added =
                      await ref.read(favoriteIdsProvider.notifier).toggle(sign.id);
                  if (context.mounted) {
                    showAppSnackBar(context,
                        added ? 'Ditambahkan ke favorit' : 'Dihapus dari favorit');
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
                  final marked =
                      await ref.read(difficultIdsProvider.notifier).toggle(sign.id);
                  if (context.mounted) {
                    showAppSnackBar(
                      context,
                      marked
                          ? 'Ditambahkan ke daftar sulit'
                          : 'Dihapus dari daftar sulit',
                    );
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
                AppRoutes.newReport(
                  type: ReportTargetType.sign.value,
                  id: sign.id,
                  title: sign.term,
                ),
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
