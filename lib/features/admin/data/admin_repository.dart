import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_mapper.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../core/utils/json.dart';
import '../../../core/utils/uuid.dart';
import 'media_upload.dart';

/// Akses data admin. Keamanan sejati di RLS (`is_admin()`); repository ini
/// hanya lapisan kenyamanan.
class AdminRepository {
  AdminRepository(this._client);
  final SupabaseClient _client;

  String? get currentUserId => _client.auth.currentUser?.id;

  Future<Map<String, int>> dashboardCounts() => guardRequest(() async {
        final result = await _client.rpc('admin_dashboard_counts');
        final map = Map<String, dynamic>.from(result as Map);
        return map.map((k, v) => MapEntry(k, (v as num).toInt()));
      });

  Future<List<Json>> list(
    String table, {
    required String columns,
    String? status,
    String orderBy = 'created_at',
    bool ascending = false,
    String? search,
    String? searchColumn,
    Map<String, String> equals = const {},
  }) =>
      guardRequest(() async {
        var filter = _client.from(table).select(columns);
        if (status != null) filter = filter.eq('status', status);
        for (final entry in equals.entries) {
          filter = filter.eq(entry.key, entry.value);
        }
        final q = search?.trim() ?? '';
        if (q.isNotEmpty && searchColumn != null) {
          filter = filter.ilike(searchColumn, '%${q.replaceAll('%', r'\%').replaceAll('_', r'\_')}%');
        }
        final data = await filter.order(orderBy, ascending: ascending).limit(200);
        return rows(data);
      });

  Future<Json> get(String table, String id, {required String columns}) =>
      guardRequest(
        () => _client.from(table).select(columns).eq('id', id).single(),
      );

  /// Mengembalikan id baris baru.
  Future<String> insert(String table, Json values) => guardRequest(() async {
        final row = await _client.from(table).insert(values).select('id').single();
        return reqString(row, 'id');
      });

  Future<void> update(String table, String id, Json values) =>
      guardRequest(() async {
        await _client.from(table).update(values).eq('id', id);
      });

  Future<void> delete(String table, String id) => guardRequest(() async {
        await _client.from(table).delete().eq('id', id);
      });

  Future<void> deleteWhere(String table, String column, String value) =>
      guardRequest(() async {
        await _client.from(table).delete().eq(column, value);
      });

  /// Menukar posisi dua baris. Unique (parent, position) bersifat deferrable,
  /// tetapi tiap panggilan REST adalah transaksi terpisah → pakai posisi
  /// sementara.
  Future<void> swapPositions(String table, Json a, Json b) =>
      guardRequest(() async {
        final idA = reqString(a, 'id');
        final idB = reqString(b, 'id');
        final posA = optInt(a, 'position');
        final posB = optInt(b, 'position');
        await _client.from(table).update({'position': 1000000 + posA}).eq('id', idA);
        await _client.from(table).update({'position': posA}).eq('id', idB);
        await _client.from(table).update({'position': posB}).eq('id', idA);
      });

  Future<Json?> answerKey(String questionId) => guardRequest(
        () => _client
            .from('question_answer_keys')
            .select('question_id, correct_option_id, explanation')
            .eq('question_id', questionId)
            .maybeSingle(),
      );

  Future<void> saveAnswerKey(
    String questionId,
    String optionId,
    String? explanation,
  ) =>
      guardRequest(() async {
        await _client.from('question_answer_keys').upsert(
          {
            'question_id': questionId,
            'correct_option_id': optionId,
            'explanation': explanation,
          },
          onConflict: 'question_id',
        );
      });

  /// Unggah media: validasi → objek Storage (upsert:false) → baris
  /// `media_assets`. Bila langkah DB gagal, objek dihapus (best-effort).
  /// Mengembalikan `(id, path)` aset baru.
  Future<({String id, String path})> uploadMedia({
    required PickedMedia file,
    required MediaKind kind,
    required String folder,
    required String ownerId,
    required String prefix,
  }) async {
    final check = validateMedia(file, kind);
    if (check.error != null) throw MessageFailure(check.error!);
    final assetId = uuidV4();
    final path = mediaObjectPath(
      folder: folder,
      ownerId: ownerId,
      prefix: prefix,
      assetId: assetId,
      extension: file.extension,
    );
    final bucket = _client.storage.from(kMediaBucket);
    await guardRequest(
      () => bucket.uploadBinary(
        path,
        file.bytes,
        fileOptions: FileOptions(contentType: check.mime, upsert: false),
      ),
    );
    try {
      await guardRequest(() async {
        await _client.from('media_assets').insert({
          'id': assetId,
          'kind': kind.name,
          'path': path,
          'mime_type': check.mime,
          'size_bytes': file.bytes.length,
        });
      });
    } catch (_) {
      try {
        await bucket.remove([path]);
      } catch (_) {
        // Best-effort: objek yatim dapat dibersihkan manual.
      }
      rethrow;
    }
    return (id: assetId, path: path);
  }

  /// Menghapus aset lama setelah aset baru tertaut (SECURITY §6).
  Future<void> deleteMedia({required String assetId, required String path}) async {
    await guardRequest(() async {
      await _client.from('media_assets').delete().eq('id', assetId);
    });
    try {
      await _client.storage.from(kMediaBucket).remove([path]);
    } catch (_) {
      // Objek yatim dapat dibersihkan manual (di luar MVP otomatis).
    }
  }
}

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => AdminRepository(ref.watch(supabaseClientProvider)),
);
