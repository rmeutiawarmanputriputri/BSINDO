import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/content_page.dart';
import '../../../core/widgets/state_views.dart';
import '../data/difficult_repository.dart';
import '../domain/difficult_item.dart';

/// S20 Daftar Kosakata Sulit — tab "Perlu dilatih" / "Sudah dipelajari ulang".
class DifficultListScreen extends StatelessWidget {
  const DifficultListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: _AppBar(),
        body: TabBarView(
          children: [
            _DifficultTab(status: DifficultStatus.learning),
            _DifficultTab(status: DifficultStatus.relearned),
          ],
        ),
      ),
    );
  }
}

class _AppBar extends StatelessWidget implements PreferredSizeWidget {
  const _AppBar();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + kTextTabBarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('Kosakata Sulit'),
      bottom: const TabBar(
        tabs: [Tab(text: 'Perlu dilatih'), Tab(text: 'Sudah dipelajari ulang')],
      ),
    );
  }
}

class _DifficultTab extends ConsumerWidget {
  const _DifficultTab({required this.status});
  final DifficultStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(difficultListProvider(status));
    return AsyncValueView<List<DifficultItem>>(
      value: list,
      onRetry: () => ref.invalidate(difficultListProvider(status)),
      isEmpty: (items) => items.isEmpty,
      empty: EmptyView(
        icon: Icons.flag_outlined,
        title: status == DifficultStatus.learning
            ? 'Belum ada kosakata sulit'
            : 'Belum ada yang dipelajari ulang',
        message: 'Tandai kosakata sulit dari halaman detail.',
      ),
      data: (items) => ContentListView(
        children: [
          for (final item in items)
            Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              color: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.contentCard),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: ListTile(
                title: Text(item.sign?.term ?? 'Materi tidak tersedia'),
                subtitle: Text(
                  item.sign == null
                      ? 'Kosakata ini sudah tidak tersedia.'
                      : [
                          if (item.sign!.categoryName != null) item.sign!.categoryName!,
                          'Dilatih ${item.reviewCount}×',
                        ].join(' · '),
                ),
                onTap: item.sign == null
                    ? null
                    : () => context.push(AppRoutes.difficultReview(item.signId)),
                trailing: IconButton(
                  tooltip: 'Hapus dari daftar',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final ok = await showConfirmDialog(
                      context,
                      title: 'Hapus dari daftar?',
                      message: 'Kosakata ini akan dihapus dari daftar sulit Anda.',
                      confirmLabel: 'Hapus',
                      destructive: true,
                    );
                    // WidgetRef tidak boleh dipakai setelah widget di-unmount.
                    if (!ok || !context.mounted) return;
                    final ids = ref.read(difficultIdsProvider.notifier);
                    final marked =
                        (ref.read(difficultIdsProvider).value ?? const <String>{})
                            .contains(item.signId);
                    final repo = ref.read(difficultRepositoryProvider);
                    try {
                      if (marked) {
                        await ids.toggle(item.signId);
                      } else {
                        await repo.remove(item.signId);
                        if (context.mounted) ref.invalidate(difficultListProvider);
                      }
                      if (context.mounted) showAppSnackBar(context, 'Dihapus dari daftar sulit');
                    } catch (error) {
                      if (context.mounted) showErrorSnackBar(context, error);
                    }
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
