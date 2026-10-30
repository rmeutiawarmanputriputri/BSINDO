import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failure_mapper.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../core/utils/json.dart';
import '../../auth/data/auth_repository.dart';
import '../../dictionary/domain/sign.dart';
import '../domain/study.dart';

/// Data belajar v1.1.0: daftar Alfabet/Angka, progres per materi, ringkasan,
/// riwayat. Semua akses dibatasi RLS (hanya materi published & data milik sendiri).
abstract interface class StudyRepository {
  Future<List<Sign>> listByModule(ContentModule module);
  Future<Map<String, SignProgress>> myProgress();
  Future<SignProgress> recordView(String signId, {bool? learned});
  Future<ProgressSummary> summary();
  Future<List<HistoryEntry>> history({int limit = 30});
  Future<List<Sign>> searchAll(String text, {int limit = 30});
}

class SupabaseStudyRepository implements StudyRepository {
  SupabaseStudyRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<List<Sign>> listByModule(ContentModule module) => guardRequest(() async {
        final data = await _client
            .from('signs')
            .select(Sign.selectColumns)
            .eq('status', 'published')
            .eq('content_module', module.value)
            .order('sort_order', ascending: true)
            .order('term_normalized', ascending: true)
            .limit(500);
        final list = rows(data).map(Sign.fromJson).toList();
        if (module == ContentModule.number) {
          // Urut kelompok (0–9, 10–20, puluhan, 100+) lalu urutan admin.
          list.sort((a, b) {
            final ga = a.numberGroup?.index ?? 99;
            final gb = b.numberGroup?.index ?? 99;
            if (ga != gb) return ga.compareTo(gb);
            if (a.sortOrder != b.sortOrder) return a.sortOrder.compareTo(b.sortOrder);
            return (num.tryParse(a.symbol ?? '') ?? 0).compareTo(num.tryParse(b.symbol ?? '') ?? 0);
          });
        }
        return list;
      });

  @override
  Future<Map<String, SignProgress>> myProgress() => guardRequest(() async {
        final data = await _client
            .from('sign_progress')
            .select('sign_id, learned_at, view_count')
            .limit(5000);
        return {for (final p in rows(data).map(SignProgress.fromJson)) p.signId: p};
      });

  @override
  Future<SignProgress> recordView(String signId, {bool? learned}) =>
      guardRequest(() async {
        final result = await _client.rpc('record_sign_view', params: {
          'p_sign_id': signId,
          'p_learned': learned,
        });
        return SignProgress.fromJson(Map<String, dynamic>.from(result as Map));
      });

  @override
  Future<ProgressSummary> summary() => guardRequest(() async {
        final result = await _client.rpc('my_progress_summary');
        return ProgressSummary.fromJson(Map<String, dynamic>.from(result as Map));
      });

  @override
  Future<List<HistoryEntry>> history({int limit = 30}) => guardRequest(() async {
        final data = await _client
            .from('my_learning_history')
            .select()
            .order('last_accessed_at', ascending: false)
            .limit(limit);
        return rows(data).map(HistoryEntry.fromJson).toList();
      });

  @override
  Future<List<Sign>> searchAll(String text, {int limit = 30}) => guardRequest(() async {
        final escaped = text.replaceAll(RegExp(r'[\\%_,()]'), ' ').trim().toLowerCase();
        if (escaped.isEmpty) return const <Sign>[];
        final data = await _client
            .from('signs')
            .select(Sign.selectColumns)
            .eq('status', 'published')
            .or('term_normalized.ilike.%$escaped%,symbol.ilike.%$escaped%,meaning.ilike.%$escaped%')
            .order('term_normalized', ascending: true)
            .limit(limit);
        return rows(data).map(Sign.fromJson).toList();
      });
}

final studyRepositoryProvider = Provider<StudyRepository>(
  (ref) => SupabaseStudyRepository(ref.watch(supabaseClientProvider)),
);

/// Daftar materi per modul. Tidak autoDispose: materi yang sudah dibuka tetap
/// tersedia selama aplikasi berjalan (cache sesi, juga saat koneksi putus).
final studyListProvider = FutureProvider.family<List<Sign>, ContentModule>((ref, module) {
  ref.watch(currentUserIdProvider);
  return ref.watch(studyRepositoryProvider).listByModule(module);
});

/// Progres per materi milik pengguna aktif + aksi tandai dibuka/dipelajari.
class SignProgressNotifier extends AsyncNotifier<Map<String, SignProgress>> {
  @override
  Future<Map<String, SignProgress>> build() async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const {};
    return ref.watch(studyRepositoryProvider).myProgress();
  }

  /// Catat materi dibuka (riwayat belajar). Gagal diam-diam: tidak memblokir belajar.
  Future<void> markViewed(String signId) async {
    try {
      final p = await ref.read(studyRepositoryProvider).recordView(signId);
      if (!ref.mounted) return;
      state = AsyncData({...?state.value, signId: p});
      ref.invalidate(progressSummaryProvider);
      ref.invalidate(learningHistoryProvider);
    } catch (_) {}
  }

  /// Tandai/batalkan "sudah dipelajari". Melempar error agar UI bisa memberi tahu.
  Future<bool> setLearned(String signId, bool learned) async {
    final p = await ref.read(studyRepositoryProvider).recordView(signId, learned: learned);
    if (ref.mounted) {
      state = AsyncData({...?state.value, signId: p});
      ref.invalidate(progressSummaryProvider);
      ref.invalidate(learningHistoryProvider);
    }
    return p.learned;
  }
}

final signProgressProvider =
    AsyncNotifierProvider<SignProgressNotifier, Map<String, SignProgress>>(
  SignProgressNotifier.new,
);

/// Id materi yang sudah dipelajari.
final learnedIdsProvider = Provider<Set<String>>((ref) {
  final map = ref.watch(signProgressProvider).value ?? const {};
  return {for (final e in map.entries) if (e.value.learned) e.key};
});

final progressSummaryProvider = FutureProvider.autoDispose<ProgressSummary>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(studyRepositoryProvider).summary();
});

final learningHistoryProvider = FutureProvider.autoDispose<List<HistoryEntry>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(studyRepositoryProvider).history();
});
