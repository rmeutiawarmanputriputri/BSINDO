import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/source_card.dart';
import '../../favorites/data/favorites_repository.dart';
import '../domain/sign.dart';

/// Baris kosakata: kata, kategori/jenis, indikator video, tombol favorit.
class SignTile extends ConsumerWidget {
  const SignTile({super.key, required this.sign, required this.onTap});

  final Sign sign;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoriteIdsProvider).value ?? const <String>{};
    final isFavorite = favorites.contains(sign.id);
    final subtitle = [
      sign.entryType.label,
      if (sign.categoryName != null) sign.categoryName!,
      sign.hasVideo ? 'ada video' : 'video belum tersedia',
    ].join(' · ');
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.contentCard),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        minVerticalPadding: AppSpacing.md,
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: AppColors.inputFill,
          child: ExcludeSemantics(
            child: Icon(
              sign.hasVideo ? Icons.play_circle_outline : Icons.videocam_off_outlined,
              color: sign.hasVideo ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(sign.term, style: Theme.of(context).textTheme.titleMedium),
            ),
            if (sign.isSample) ...[
              const SizedBox(width: AppSpacing.sm),
              const SampleBadge(),
            ],
          ],
        ),
        subtitle: Text(subtitle),
        trailing: IconButton(
          tooltip: isFavorite ? 'Hapus dari favorit' : 'Tambah ke favorit',
          isSelected: isFavorite,
          icon: Icon(
            isFavorite ? Icons.favorite : Icons.favorite_border,
            color: isFavorite ? AppColors.error : AppColors.textSecondary,
          ),
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
        ),
      ),
    );
  }
}
