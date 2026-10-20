import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failure_mapper.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/json.dart';
import '../../auth/data/auth_repository.dart';

class ProgressEntry {
  const ProgressEntry({
    this.lessonId,
    this.moduleId,
    required this.completed,
    required this.percent,
    required this.lastPosition,
    this.lastAccessedAt,
    this.title,
  });

  factory ProgressEntry.fromJson(Json json) {
    final lesson = optObject(json, 'lesson');
    final module = optObject(json, 'module');
    return ProgressEntry(
      lessonId: optString(json, 'lesson_id'),
      moduleId: optString(json, 'conversation_module_id'),
      completed: optString(json, 'status') == 'completed',
      percent: optInt(json, 'progress_percent'),
      lastPosition: optInt(json, 'last_position'),
      lastAccessedAt: parseDate(json['last_accessed_at']),
      title: (lesson != null ? optString(lesson, 'title') : null) ??
          (module != null ? optString(module, 'title') : null),
    );
  }

  final String? lessonId;
  final String? moduleId;
  final bool completed;
  final int percent;
  final int lastPosition;
  final DateTime? lastAccessedAt;

  /// Judul materi (dari embed) bila tersedia.
  final String? title;
}

abstract interface class ProgressRepository {
  Future<List<ProgressEntry>> all();
  Future<ProgressEntry?> latest();

  /// RPC `touch_progress` (migrasi 0010).
  Future<void> touch({
    String? lessonId,
    String? moduleId,
    int? percent,
    int? lastPosition,
    bool completed = false,
  });
}

class SupabaseProgressRepository implements ProgressRepository {
  SupabaseProgressRepository(this._client);
  final SupabaseClient _client;

  static const _columns =
      'lesson_id, conversation_module_id, status, progress_percent, '
      'last_position, last_accessed_at, '
      'lesson:lessons(title), module:conversation_modules(title)';

  @override
  Future<List<ProgressEntry>> all() => guardRequest(() async {
        final data = await _client
            .from('user_progress')
            .select(_columns)
            .order('last_accessed_at', ascending: false);
        return rows(data).map(ProgressEntry.fromJson).toList();
      });

  @override
  Future<ProgressEntry?> latest() => guardRequest(() async {
        final data = await _client
            .from('user_progress')
            .select(_columns)
            .order('last_accessed_at', ascending: false)
            .limit(1);
        final list = rows(data).map(ProgressEntry.fromJson).toList();
        // Materi yang sudah tidak published tidak punya judul → abaikan.
        return list.isEmpty || list.first.title == null ? null : list.first;
      });

  @override
  Future<void> touch({
    String? lessonId,
    String? moduleId,
    int? percent,
    int? lastPosition,
    bool completed = false,
  }) =>
      guardRequest(() async {
        await _client.rpc('touch_progress', params: {
          'p_lesson_id': lessonId,
          'p_module_id': moduleId,
          'p_progress_percent': percent,
          'p_last_position': lastPosition,
          'p_completed': completed,
        });
      });
}

final progressRepositoryProvider = Provider<ProgressRepository>(
  (ref) => SupabaseProgressRepository(ref.watch(supabaseClientProvider)),
);

/// Semua progres pengguna, dimuat ulang saat pengguna berganti.
final progressListProvider = FutureProvider<List<ProgressEntry>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(progressRepositoryProvider).all();
});
