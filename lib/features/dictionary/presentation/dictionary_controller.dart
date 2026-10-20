import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_mapper.dart';
import '../data/sign_repository.dart';
import '../domain/sign.dart';

class DictionaryState {
  const DictionaryState({
    this.query = const DictionaryQuery(),
    this.items = const [],
    this.page = 0,
    this.hasMore = false,
    this.loading = false,
    this.loadingMore = false,
    this.error,
  });

  final DictionaryQuery query;
  final List<Sign> items;
  final int page;
  final bool hasMore;
  final bool loading;
  final bool loadingMore;
  final AppFailure? error;

  DictionaryState copyWith({
    DictionaryQuery? query,
    List<Sign>? items,
    int? page,
    bool? hasMore,
    bool? loading,
    bool? loadingMore,
    AppFailure? Function()? error,
  }) =>
      DictionaryState(
        query: query ?? this.query,
        items: items ?? this.items,
        page: page ?? this.page,
        hasMore: hasMore ?? this.hasMore,
        loading: loading ?? this.loading,
        loadingMore: loadingMore ?? this.loadingMore,
        error: error != null ? error() : this.error,
      );
}

/// Pencarian kamus dengan pagination 20/halaman (S08). Debounce dilakukan di
/// layar sebelum memanggil [setText].
class DictionaryController extends Notifier<DictionaryState> {
  int _request = 0;

  @override
  DictionaryState build() => const DictionaryState();

  void setText(String text) => _apply(state.query.copyWith(text: text));

  void setCategory(String? categoryId) =>
      _apply(state.query.copyWith(categoryId: () => categoryId));

  void setEntryType(SignEntryType? type) =>
      _apply(state.query.copyWith(entryType: () => type));

  void _apply(DictionaryQuery query) {
    if (query == state.query && state.error == null) return;
    state = state.copyWith(query: query);
    reload();
  }

  Future<void> reload() async {
    final request = ++_request;
    final query = state.query;
    if (query.isEmpty) {
      state = DictionaryState(query: query);
      return;
    }
    state = DictionaryState(query: query, loading: true);
    try {
      final items = await ref.read(signRepositoryProvider).search(query);
      if (!ref.mounted || request != _request) return;
      state = DictionaryState(
        query: query,
        items: items,
        hasMore: items.length == kPageSize,
      );
    } catch (error) {
      if (!ref.mounted || request != _request) return;
      state = DictionaryState(query: query, error: mapError(error));
    }
  }

  Future<void> loadMore() async {
    if (state.loading || state.loadingMore || !state.hasMore) return;
    final request = _request;
    final nextPage = state.page + 1;
    state = state.copyWith(loadingMore: true);
    try {
      final more = await ref
          .read(signRepositoryProvider)
          .search(state.query, page: nextPage);
      if (!ref.mounted || request != _request) return;
      final seen = state.items.map((s) => s.id).toSet();
      state = state.copyWith(
        items: [...state.items, ...more.where((s) => !seen.contains(s.id))],
        page: nextPage,
        hasMore: more.length == kPageSize,
        loadingMore: false,
      );
    } catch (_) {
      if (!ref.mounted || request != _request) return;
      state = state.copyWith(loadingMore: false);
    }
  }
}

final dictionaryControllerProvider =
    NotifierProvider<DictionaryController, DictionaryState>(
  DictionaryController.new,
);
