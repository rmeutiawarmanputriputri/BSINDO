import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failure_mapper.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../core/utils/json.dart';
import '../../auth/data/auth_repository.dart';
import '../../learning/data/learning_repository.dart';
import '../domain/quiz_bank.dart';

/// Kuis bank soal v1.1.0. Kunci jawaban TIDAK pernah dikirim ke aplikasi
/// sebelum menjawab; penilaian dilakukan server (RPC).
abstract interface class QuizBankRepository {
  Future<List<QuizQuestion>> fetch(QuizConfig config);
  Future<QuizReveal> check(String questionId, QuizAnswer answer);
  Future<QuizSessionResult> submit(
    QuizConfig config,
    Map<String, QuizAnswer?> answers, {
    DateTime? startedAt,
  });
  Future<List<QuizHistoryEntry>> history();
}

class SupabaseQuizBankRepository implements QuizBankRepository {
  SupabaseQuizBankRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<List<QuizQuestion>> fetch(QuizConfig config) => guardRequest(() async {
        final result = await _client.rpc('get_quiz_questions', params: config.toRpcParams());
        return rows(result).map(QuizQuestion.fromJson).toList();
      });

  @override
  Future<QuizReveal> check(String questionId, QuizAnswer answer) =>
      guardRequest(() async {
        final result = await _client.rpc('check_quiz_answer', params: {
          'p_question_id': questionId,
          'p_answer': answer.toJson(),
        });
        return QuizReveal.fromJson(Map<String, dynamic>.from(result as Map));
      });

  @override
  Future<QuizSessionResult> submit(
    QuizConfig config,
    Map<String, QuizAnswer?> answers, {
    DateTime? startedAt,
  }) =>
      guardRequest(() async {
        final result = await _client.rpc('submit_quiz_session', params: {
          'p_mode': config.mode.value,
          'p_module': config.module?.value,
          'p_category_id': config.categoryId,
          'p_difficulty': config.difficulty?.value,
          'p_started_at': startedAt?.toUtc().toIso8601String(),
          'p_answers': [
            for (final e in answers.entries)
              {'question_id': e.key, 'answer': e.value?.toJson()},
          ],
        });
        return QuizSessionResult.fromJson(Map<String, dynamic>.from(result as Map));
      });

  @override
  Future<List<QuizHistoryEntry>> history() => guardRequest(() async {
        final data = await _client
            .from('quiz_sessions')
            .select('id, mode, module, score_percent, correct_count, total_count, submitted_at')
            .order('submitted_at', ascending: false)
            .limit(50);
        return rows(data).map(QuizHistoryEntry.fromSession).toList();
      });
}

final quizBankRepositoryProvider = Provider<QuizBankRepository>(
  (ref) => SupabaseQuizBankRepository(ref.watch(supabaseClientProvider)),
);

/// Riwayat gabungan: kuis bank (v1.1.0) + kuis pelajaran (versi lama).
final quizHistoryProvider = FutureProvider.autoDispose<List<QuizHistoryEntry>>((ref) async {
  ref.watch(currentUserIdProvider);
  final bank = await ref.watch(quizBankRepositoryProvider).history();
  final legacy = await ref.watch(learningRepositoryProvider).attempts();
  final all = [
    ...bank,
    for (final a in legacy)
      QuizHistoryEntry(
        id: a.id,
        title: a.quizTitle ?? 'Kuis pelajaran',
        scorePercent: a.scorePercent,
        submittedAt: a.submittedAt,
      ),
  ]..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
  return all;
});
