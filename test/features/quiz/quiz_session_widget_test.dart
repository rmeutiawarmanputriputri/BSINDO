import 'package:bisindo_app/app/theme/app_theme.dart';
import 'package:bisindo_app/features/auth/data/auth_repository.dart';
import 'package:bisindo_app/features/dictionary/domain/sign.dart';
import 'package:bisindo_app/features/quiz/data/quiz_bank_repository.dart';
import 'package:bisindo_app/features/quiz/domain/quiz_bank.dart';
import 'package:bisindo_app/features/quiz/presentation/quiz_play_screen.dart';
import 'package:bisindo_app/features/study/data/study_repository.dart';
import 'package:bisindo_app/features/study/presentation/module_grid_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Repository kuis palsu: penilaian lokal sederhana (BUKAN kunci asli; data TEST_).
class _FakeQuizRepo implements QuizBankRepository {
  _FakeQuizRepo(this.correct);
  final Map<String, String> correct;

  @override
  Future<QuizReveal> check(String questionId, QuizAnswer answer) async =>
      QuizReveal(
        questionId: questionId,
        isCorrect:
            answer is ChoiceAnswer && answer.optionId == correct[questionId],
        correctOptionId: correct[questionId],
        explanation: 'TEST pembahasan',
      );

  @override
  Future<List<QuizQuestion>> fetch(QuizConfig config) async => const [];

  @override
  Future<List<QuizHistoryEntry>> history() async => const [];

  @override
  Future<QuizSessionResult> submit(
    QuizConfig config,
    Map<String, QuizAnswer?> answers, {
    DateTime? startedAt,
  }) async {
    final details = [
      for (final e in answers.entries)
        QuizReveal(
          questionId: e.key,
          isCorrect:
              e.value is ChoiceAnswer &&
              (e.value as ChoiceAnswer).optionId == correct[e.key],
          correctOptionId: correct[e.key],
        ),
    ];
    final ok = details.where((d) => d.isCorrect).length;
    return QuizSessionResult(
      sessionId: 's',
      scorePercent: (100 * ok / details.length).round(),
      correctCount: ok,
      totalCount: details.length,
      details: details,
    );
  }
}

const _q = QuizQuestion(
  id: 'q1',
  type: QuizType.multipleChoice,
  prompt: 'TEST pertanyaan?',
  options: [
    QuizOption(id: 'a', label: 'TEST_A'),
    QuizOption(id: 'b', label: 'TEST_B'),
  ],
);

void main() {
  testWidgets(
    'kuis: pilih jawaban → umpan balik + pembahasan → hasil dinilai',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            quizBankRepositoryProvider.overrideWithValue(
              _FakeQuizRepo({'q1': 'b'}),
            ),
            currentUserIdProvider.overrideWithValue(null),
          ],
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const Scaffold(
              body: QuizSession(config: QuizConfig(), questions: [_q]),
            ),
          ),
        ),
      );

      expect(find.text('TEST pertanyaan?'), findsOneWidget);
      await tester.tap(find.text('TEST_B'));
      await tester.pump();
      await tester.tap(find.text('Periksa jawaban'));
      await tester.pumpAndSettle();
      expect(find.text('Benar!'), findsOneWidget);
      expect(find.text('TEST pembahasan'), findsOneWidget);

      await tester.tap(find.text('Lihat hasil'));
      await tester.pumpAndSettle();
      expect(find.text('100'), findsOneWidget);
      expect(find.textContaining('1 benar dari 1 soal'), findsOneWidget);
    },
  );

  testWidgets('Alfabet tanpa materi published → "Materi belum tersedia"', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue(null),
          studyListProvider.overrideWith((ref, module) async => const <Sign>[]),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const ModuleGridScreen(module: ContentModule.alphabet),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Materi belum tersedia'), findsOneWidget);
  });
}
