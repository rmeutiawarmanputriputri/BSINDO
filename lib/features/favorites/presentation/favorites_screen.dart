import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/content_page.dart';
import '../../../core/widgets/state_views.dart';
import '../../dictionary/domain/sign.dart';
import '../../dictionary/presentation/sign_tile.dart';
import '../data/favorites_repository.dart';

/// S19 Favorit — urut terbaru; hapus dengan geser + "Urungkan".
class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  /// Disembunyikan seketika saat digeser (Dismissible wajib hilang dari tree).
  final Set<String> _hidden = {};

  Future<void> _remove(Sign sign) async {
    setState(() => _hidden.add(sign.id));
    final notifier = ref.read(favoriteIdsProvider.notifier);
    try {
      await notifier.toggle(sign.id);
      if (!mounted) return;
      showAppSnackBar(
        context,
        'Dihapus dari favorit',
        actionLabel: 'Urungkan',
        onAction: () async {
          try {
            await notifier.toggle(sign.id);
          } catch (error) {
            if (mounted) showErrorSnackBar(context, error);
          } finally {
            if (mounted) setState(() => _hidden.remove(sign.id));
          }
        },
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _hidden.remove(sign.id));
      showErrorSnackBar(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final favorites = ref.watch(favoritesListProvider).whenData(
          (list) => list.where((s) => !_hidden.contains(s.id)).toList(),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Favorit')),
      body: AsyncValueView<List<Sign>>(
        value: favorites,
        onRetry: () => ref.invalidate(favoritesListProvider),
        isEmpty: (list) => list.isEmpty,
        empty: EmptyView(
          icon: Icons.favorite_border,
          title: 'Belum ada favorit',
          message: 'Ketuk ikon hati pada kosakata untuk menyimpannya di sini.',
          actionLabel: 'Jelajahi Kamus',
          onAction: () => context.go(AppRoutes.dictionary),
        ),
        data: (list) => ContentListView(
          children: [
            for (final sign in list)
              Dismissible(
                key: ValueKey('fav-${sign.id}'),
                direction: DismissDirection.endToStart,
                background: const ColoredBox(color: Color(0xFFFDECEA)),
                onDismissed: (_) => _remove(sign),
                child: SignTile(
                  sign: sign,
                  onTap: () => context.push(AppRoutes.sign(sign.id)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
