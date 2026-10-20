import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failure_mapper.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../core/utils/json.dart';
import '../../auth/data/auth_repository.dart';
import '../../dictionary/domain/sign.dart';
import '../domain/difficult_item.dart';

abstract interface class DifficultRepository {
  Future<List<DifficultItem>> list({DifficultStatus? status, int? limit});
  Future<Set<String>> markedSignIds();
  Future<void> mark(String signId);
  Future<void> remove(String signId);
  Future<void> review(DifficultItem item, {required bool understood});
}

class SupabaseDifficultRepository implements DifficultRepository {
  SupabaseDifficultRepository(this._client);
  final SupabaseClient _client;

  static const _columns =
      'id, sign_id, status, review_count, marked_at, last_reviewed_at, '
      'sign:signs(${Sign.selectColumns})';

  @override
  Future<List<DifficultItem>> list({DifficultStatus? status, int? limit}) =>
      guardRequest(() async {
        var filter = _client.from('difficult_vocabulary').select(_columns);
        if (status != null) filter = filter.eq('status', status.name);
        var query = filter
            .order('last_reviewed_at', ascending: true, nullsFirst: true)
            .order('marked_at', ascending: false);
        if (limit != null) query = query.limit(limit);
        final data = await query;
        return rows(data).map(DifficultItem.fromJson).toList();
      });

  @override
  Future<Set<String>> markedSignIds() => guardRequest(() async {
        final data = await _client.from('difficult_vocabulary').select('sign_id');
        return rows(data).map((r) => reqString(r, 'sign_id')).toSet();
      });

  @override
  Future<void> mark(String signId) => guardRequest(() async {
        // Unik (user_id, sign_id) → upsert tanpa duplikat (F7, DIFF-01).
        await _client.from('difficult_vocabulary').upsert(
          {
            'sign_id': signId,
            'status': 'learning',
            'relearned_at': null,
            'marked_at': DateTime.now().toUtc().toIso8601String(),
          },
          onConflict: 'user_id,sign_id',
        );
      });

  @override
  Future<void> remove(String signId) => guardRequest(() async {
        await _client.from('difficult_vocabulary').delete().eq('sign_id', signId);
      });

  @override
  Future<void> review(DifficultItem item, {required bool understood}) =>
      guardRequest(() async {
        final now = DateTime.now().toUtc().toIso8601String();
        await _client.from('difficult_vocabulary').update({
          'review_count': item.reviewCount + 1,
          'last_reviewed_at': now,
          if (understood) 'status': 'relearned',
          if (understood) 'relearned_at': now,
        }).eq('id', item.id);
      });
}

final difficultRepositoryProvider = Provider<DifficultRepository>(
  (ref) => SupabaseDifficultRepository(ref.watch(supabaseClientProvider)),
);

final difficultListProvider = FutureProvider.autoDispose
    .family<List<DifficultItem>, DifficultStatus>((ref, status) {
  ref.watch(currentUserIdProvider);
  return ref.watch(difficultRepositoryProvider).list(status: status);
});

/// Set sign yang ditandai sulit, dengan toggle (upsert / hapus).
class DifficultIdsNotifier extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return <String>{};
    return ref.watch(difficultRepositoryProvider).markedSignIds();
  }

  /// Mengembalikan `true` bila sekarang ditandai sulit.
  Future<bool> toggle(String signId) async {
    // Tunggu muatan awal agar toggle tidak salah arah saat state masih loading.
    final current = state.value ?? await future;
    final wasMarked = current.contains(signId);
    final next = {...current};
    if (wasMarked) {
      next.remove(signId);
    } else {
      next.add(signId);
    }
    state = AsyncData(next);
    try {
      final repo = ref.read(difficultRepositoryProvider);
      if (wasMarked) {
        await repo.remove(signId);
      } else {
        await repo.mark(signId);
      }
      if (ref.mounted) ref.invalidate(difficultListProvider);
      return !wasMarked;
    } catch (_) {
      if (ref.mounted) state = AsyncData(current);
      rethrow;
    }
  }
}

final difficultIdsProvider =
    AsyncNotifierProvider<DifficultIdsNotifier, Set<String>>(
  DifficultIdsNotifier.new,
);
