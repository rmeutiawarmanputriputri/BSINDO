import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failure_mapper.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../core/utils/json.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/report.dart';

abstract interface class ReportRepository {
  Future<void> create({
    required ReportTargetType targetType,
    required String targetId,
    required ReportCategory category,
    String? description,
  });
  Future<List<ContentReport>> mine();
}

class SupabaseReportRepository implements ReportRepository {
  SupabaseReportRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<void> create({
    required ReportTargetType targetType,
    required String targetId,
    required ReportCategory category,
    String? description,
  }) =>
      guardRequest(() async {
        final text = description?.trim();
        // reporter_id & status diisi default DB; policy menolak nilai lain.
        await _client.from('content_reports').insert({
          targetType.column: targetId,
          'category': category.value,
          'description': (text == null || text.isEmpty) ? null : text,
        });
      });

  @override
  Future<List<ContentReport>> mine() => guardRequest(() async {
        final uid = _client.auth.currentUser?.id;
        if (uid == null) return const <ContentReport>[];
        final data = await _client
            .from('content_reports')
            .select(ContentReport.columns)
            .eq('reporter_id', uid)
            .order('created_at', ascending: false);
        return rows(data).map(ContentReport.fromJson).toList();
      });
}

final reportRepositoryProvider = Provider<ReportRepository>(
  (ref) => SupabaseReportRepository(ref.watch(supabaseClientProvider)),
);

final myReportsProvider = FutureProvider.autoDispose<List<ContentReport>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(reportRepositoryProvider).mine();
});
