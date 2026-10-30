import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/utils/debouncer.dart';
import '../../../core/utils/sanitize_search.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/content_page.dart';
import '../../../core/widgets/state_views.dart';
import '../data/sign_repository.dart';
import '../domain/sign.dart';
import 'dictionary_controller.dart';
import 'sign_tile.dart';

/// S08 Kamus & Pencarian.
class DictionaryScreen extends ConsumerStatefulWidget {
  const DictionaryScreen({super.key});

  @override
  ConsumerState<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends ConsumerState<DictionaryScreen> {
  final _search = TextEditingController();
  final _debouncer = Debouncer();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _search.text = ref.read(dictionaryControllerProvider).query.text;
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debouncer.dispose();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) {
      ref.read(dictionaryControllerProvider.notifier).loadMore();
    }
  }

  void _onChanged(String text) {
    setState(() {});
    _debouncer.run(
      () => ref.read(dictionaryControllerProvider.notifier).setText(text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dictionaryControllerProvider);
    final controller = ref.read(dictionaryControllerProvider.notifier);
    final categories = ref.watch(signCategoriesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kosakata'),
        actions: [
          IconButton(
            tooltip: 'Favorit',
            icon: const Icon(Icons.favorite_border),
            onPressed: () => context.push(AppRoutes.favorites),
          ),
        ],
      ),
      body: Column(
        children: [
          ContentWidth(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
              child: TextField(
                controller: _search,
                onChanged: _onChanged,
                textInputAction: TextInputAction.search,
                maxLength: kMaxSearchLength,
                decoration: InputDecoration(
                  counterText: '',
                  hintText: 'Cari kata atau frasa',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Hapus pencarian',
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _search.clear();
                            _onChanged('');
                          },
                        ),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
              children: [
                for (final type in SignEntryType.values)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: FilterChip(
                      label: Text(type.label),
                      selected: state.query.entryType == type,
                      onSelected: (selected) =>
                          controller.setEntryType(selected ? type : null),
                    ),
                  ),
                const VerticalDivider(width: AppSpacing.lg),
                ...categories.maybeWhen(
                  data: (list) => [
                    for (final c in list)
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: FilterChip(
                          label: Text(c.name),
                          selected: state.query.categoryId == c.id,
                          onSelected: (selected) =>
                              controller.setCategory(selected ? c.id : null),
                        ),
                      ),
                  ],
                  orElse: () => const <Widget>[],
                ),
              ],
            ),
          ),
          Expanded(child: _buildResults(context, state, controller)),
        ],
      ),
    );
  }

  Widget _buildResults(
    BuildContext context,
    DictionaryState state,
    DictionaryController controller,
  ) {
    if (state.loading) return const LoadingView(itemCount: 6);
    if (state.error != null) {
      return ErrorView(
        message: errorMessageOf(state.error!),
        onRetry: controller.reload,
      );
    }
    if (state.query.isEmpty) {
      return const EmptyView(
        icon: Icons.manage_search,
        title: 'Cari kata atau pilih kategori',
        message: 'Ketik kata yang ingin Anda pelajari, atau pilih kategori di atas.',
      );
    }
    if (state.items.isEmpty) {
      final q = state.query.text.trim();
      return EmptyView(
        icon: Icons.search_off,
        title: q.isEmpty ? 'Tidak ada kosakata' : "Tidak menemukan '$q'",
        message: 'Periksa ejaan atau pilih kategori lain.',
      );
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xxl),
      itemCount: state.items.length + 1,
      itemBuilder: (context, index) {
        if (index == state.items.length) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Center(
              child: state.loadingMore
                  ? const CircularProgressIndicator()
                  : Text(
                      state.hasMore ? '' : 'Akhir daftar',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
            ),
          );
        }
        final sign = state.items[index];
        return ContentWidth(
          child: SignTile(
            sign: sign,
            onTap: () => context.push(AppRoutes.sign(sign.id)),
          ),
        );
      },
    );
  }
}
