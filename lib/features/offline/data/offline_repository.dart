import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_store.dart';
import '../../auth/data/auth_repository.dart';
import '../../dictionary/domain/sign.dart';
import 'media_cache.dart';

/// Materi yang disimpan untuk dibuka tanpa koneksi (H.5). Daftar disimpan per
/// akun di perangkat; berkas media di [MediaCache]. Hanya materi yang memang
/// dapat dibuka akun ini (RLS) yang bisa disimpan.
class OfflineSignsNotifier extends AsyncNotifier<List<Sign>> {
  String? get _uid => ref.read(currentUserIdProvider);
  String get _storeName => 'offline_${_uid ?? 'anon'}';

  @override
  Future<List<Sign>> build() async {
    final uid = ref.watch(currentUserIdProvider);
    if (uid == null) return const [];
    final data = await ref.watch(localStoreProvider).read('offline_$uid');
    final raw = data['signs'];
    if (raw is! Map) return const [];
    final list = <Sign>[];
    for (final v in raw.values) {
      if (v is Map<String, dynamic>) {
        try {
          list.add(Sign.fromJson(v));
        } catch (_) {}
      }
    }
    list.sort((a, b) => a.displayTitle.compareTo(b.displayTitle));
    return list;
  }

  Future<void> _persist(List<Sign> signs) async {
    await ref.read(localStoreProvider).write(_storeName, {
      'signs': {for (final s in signs) s.id: s.toJson()},
    });
  }

  /// Unduh semua media materi lalu simpan datanya. Melempar error bila gagal
  /// (mis. tidak ada koneksi) agar UI bisa memberi tahu.
  Future<void> save(Sign sign) async {
    final cache = ref.read(mediaCacheProvider);
    for (final path in sign.mediaPaths) {
      await cache.fetch(path);
    }
    final current = [...?state.value]..removeWhere((s) => s.id == sign.id);
    final next = [...current, sign]
      ..sort((a, b) => a.displayTitle.compareTo(b.displayTitle));
    await _persist(next);
    if (ref.mounted) state = AsyncData(next);
  }

  Future<void> remove(String signId) async {
    final current = [...?state.value];
    final removed = current.where((s) => s.id == signId).toList();
    current.removeWhere((s) => s.id == signId);
    await _persist(current);
    final cache = ref.read(mediaCacheProvider);
    final stillUsed = {for (final s in current) ...s.mediaPaths};
    for (final s in removed) {
      for (final p in s.mediaPaths) {
        if (!stillUsed.contains(p)) await cache.remove(p);
      }
    }
    if (ref.mounted) state = AsyncData(current);
  }

  Future<void> clearAll() async {
    await ref.read(localStoreProvider).delete(_storeName);
    await ref.read(mediaCacheProvider).clear();
    if (ref.mounted) state = const AsyncData([]);
  }
}

final offlineSignsProvider =
    AsyncNotifierProvider<OfflineSignsNotifier, List<Sign>>(
      OfflineSignsNotifier.new,
    );

final offlineSignIdsProvider = Provider<Set<String>>(
  (ref) => {
    for (final s in ref.watch(offlineSignsProvider).value ?? const <Sign>[])
      s.id,
  },
);
