import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failure_mapper.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../core/utils/json.dart';
import '../../auth/data/auth_repository.dart';
import '../../dictionary/domain/sign.dart';

abstract interface class FavoritesRepository {
  Future<Set<String>> favoriteIds();
  Future<List<Sign>> favorites();
  Future<void> add(String signId);
  Future<void> remove(String signId);
}

class SupabaseFavoritesRepository implements FavoritesRepository {
  SupabaseFavoritesRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<Set<String>> favoriteIds() => guardRequest(() async {
        final data = await _client.from('favorites').select('sign_id');
        return rows(data).map((r) => reqString(r, 'sign_id')).toSet();
      });

  @override
  Future<List<Sign>> favorites() => guardRequest(() async {
        final data = await _client
            .from('favorites')
            .select('created_at, sign:signs(${Sign.selectColumns})')
            .order('created_at', ascending: false);
        return rows(data)
            .map((r) => optObject(r, 'sign'))
            .whereType<Json>()
            .map(Sign.fromJson)
            .toList();
      });

  @override
  Future<void> add(String signId) => guardRequest(() async {
        // user_id diisi default auth.uid() (migrasi 0009).
        await _client.from('favorites').upsert(
          {'sign_id': signId},
          onConflict: 'user_id,sign_id',
          ignoreDuplicates: true,
        );
      });

  @override
  Future<void> remove(String signId) => guardRequest(() async {
        await _client.from('favorites').delete().eq('sign_id', signId);
      });
}

final favoritesRepositoryProvider = Provider<FavoritesRepository>(
  (ref) => SupabaseFavoritesRepository(ref.watch(supabaseClientProvider)),
);

/// Set ID favorit dengan toggle optimistik + rollback (F6, FAV-01).
class FavoriteIdsNotifier extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return <String>{};
    return ref.watch(favoritesRepositoryProvider).favoriteIds();
  }

  /// Mengembalikan `true` bila sekarang menjadi favorit. Melempar AppFailure
  /// setelah rollback bila gagal.
  Future<bool> toggle(String signId) async {
    // Tunggu muatan awal agar toggle tidak salah arah (mis. menambah saat
    // pengguna sebenarnya ingin menghapus) ketika state masih loading.
    final current = state.value ?? await future;
    final wasFavorite = current.contains(signId);
    final optimistic = {...current};
    if (wasFavorite) {
      optimistic.remove(signId);
    } else {
      optimistic.add(signId);
    }
    state = AsyncData(optimistic);
    try {
      final repo = ref.read(favoritesRepositoryProvider);
      if (wasFavorite) {
        await repo.remove(signId);
      } else {
        await repo.add(signId);
      }
      if (ref.mounted) ref.invalidate(favoritesListProvider);
      return !wasFavorite;
    } catch (_) {
      if (ref.mounted) state = AsyncData(current);
      rethrow;
    }
  }
}

final favoriteIdsProvider =
    AsyncNotifierProvider<FavoriteIdsNotifier, Set<String>>(
  FavoriteIdsNotifier.new,
);

final favoritesListProvider = FutureProvider.autoDispose<List<Sign>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(favoritesRepositoryProvider).favorites();
});
