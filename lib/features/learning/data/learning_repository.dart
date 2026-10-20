import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failure_mapper.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../core/utils/json.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/learning.dart';

abstract interface class LearningRepository {
  Future<List<Lesson>> lessons();
  Future<Lesson> lesson(String id);
  Future<Quiz> quizForLesson(String lessonId);

  /// Jawaban: questionId → optionId. Penilaian di server (D-07).
  Future<QuizResult> submitQuiz(String quizId, Map<String, String> answers);
  Future<List<QuizAttempt>> attempts({String? quizId});
  Future<int> publishedLessonCount();
  Future<int> publishedModuleCount();
}

class SupabaseLearningRepository implements LearningRepository {
  SupabaseLearningRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<List<Lesson>> lessons() => guardRequest(() async {
        final data = await _client
            .from('lessons')
            .select(Lesson.listColumns)
            .eq('status', 'published')
            .order('sort_order', ascending: true);
        return rows(data).map(Lesson.fromJson).toList();
      });

  @override
  Future<Lesson> lesson(String id) => guardRequest(() async {
        final row = await _client
            .from('lessons')
            .select(Lesson.detailColumns)
            .eq('id', id)
            .single();
        return Lesson.fromJson(row);
      });

  @override
  Future<Quiz> quizForLesson(String lessonId) => guardRequest(() async {
        final row = await _client
            .from('quizzes')
            .select(Quiz.columns)
            .eq('lesson_id', lessonId)
            .eq('is_active', true)
            .single();
        return Quiz.fromJson(row);
      });

  @override
  Future<QuizResult> submitQuiz(String quizId, Map<String, String> answers) =>
      guardRequest(() async {
        final result = await _client.rpc('submit_quiz_attempt', params: {
          'p_quiz_id': quizId,
          'p_answers': [
            for (final entry in answers.entries)
              {'question_id': entry.key, 'option_id': entry.value},
          ],
        });
        return QuizResult.fromJson(Map<String, dynamic>.from(result as Map));
      });

  @override
  Future<List<QuizAttempt>> attempts({String? quizId}) =>
      guardRequest(() async {
        var filter = _client
            .from('quiz_attempts')
            .select('id, quiz_id, score_percent, passed, submitted_at, quiz:quizzes(title)');
        if (quizId != null) filter = filter.eq('quiz_id', quizId);
        final data = await filter.order('submitted_at', ascending: false).limit(50);
        return rows(data).map(QuizAttempt.fromJson).toList();
      });

  @override
  Future<int> publishedLessonCount() => guardRequest(() async {
        final response = await _client
            .from('lessons')
            .select('id')
            .eq('status', 'published')
            .count(CountOption.exact);
        return response.count;
      });

  @override
  Future<int> publishedModuleCount() => guardRequest(() async {
        final response = await _client
            .from('conversation_modules')
            .select('id')
            .eq('status', 'published')
            .count(CountOption.exact);
        return response.count;
      });
}

final learningRepositoryProvider = Provider<LearningRepository>(
  (ref) => SupabaseLearningRepository(ref.watch(supabaseClientProvider)),
);

final lessonsProvider = FutureProvider.autoDispose<List<Lesson>>(
  (ref) => ref.watch(learningRepositoryProvider).lessons(),
);

final lessonDetailProvider = FutureProvider.autoDispose.family<Lesson, String>(
  (ref, id) => ref.watch(learningRepositoryProvider).lesson(id),
);

final quizProvider = FutureProvider.autoDispose.family<Quiz, String>(
  (ref, lessonId) => ref.watch(learningRepositoryProvider).quizForLesson(lessonId),
);

final attemptsProvider =
    FutureProvider.autoDispose.family<List<QuizAttempt>, String?>((ref, quizId) {
  ref.watch(currentUserIdProvider);
  return ref.watch(learningRepositoryProvider).attempts(quizId: quizId);
});
