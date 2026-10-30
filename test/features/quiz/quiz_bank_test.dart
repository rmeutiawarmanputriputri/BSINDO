import 'package:bisindo_app/features/quiz/domain/quiz_bank.dart';
import 'package:flutter_test/flutter_test.dart';

// Data uji bertanda TEST_ — bukan materi BISINDO.
Map<String, dynamic> _question({String type = 'multiple_choice', List<Map<String, dynamic>>? options}) => {
      'id': 'q1',
      'question_type': type,
      'prompt': 'TEST prompt',
      'module': 'alphabet',
      'difficulty': 'hard',
      'video_path': 'library/video/x.mp4',
      'is_premium': true,
      'options': options ??
          [
            {'id': 'o1', 'label': 'TEST_A', 'side': null, 'image_path': null},
            {'id': 'o2', 'label': 'TEST_B'},
          ],
    };

void main() {
  group('QuizQuestion.fromJson', () {
    test('membaca semua kolom RPC get_quiz_questions', () {
      final q = QuizQuestion.fromJson(_question());
      expect(q.id, 'q1');
      expect(q.type, QuizType.multipleChoice);
      expect(q.module, QuizModule.alphabet);
      expect(q.difficulty, QuizDifficulty.hard);
      expect(q.videoPath, 'library/video/x.mp4');
      expect(q.isPremium, true);
      expect(q.options.length, 2);
      expect(q.options.first.label, 'TEST_A');
    });

    test('jenis tidak dikenal → pilihan ganda; kolom hilang tidak membuat crash', () {
      final q = QuizQuestion.fromJson({'id': 'q', 'question_type': 'baru', 'options': 'bukan list'});
      expect(q.type, QuizType.multipleChoice);
      expect(q.options.isEmpty, true);
      expect(q.prompt, '');
      expect(q.module, null);
    });

    test('opsi kiri/kanan untuk soal cocokkan', () {
      final q = QuizQuestion.fromJson(_question(type: 'match_image', options: [
        {'id': 'l1', 'label': 'Gambar 1', 'side': 'left', 'image_path': 'i1.png'},
        {'id': 'r1', 'label': 'TEST satu', 'side': 'right'},
        {'id': 'l2', 'label': 'Gambar 2', 'side': 'left', 'image_path': 'i2.png'},
        {'id': 'r2', 'label': 'TEST dua', 'side': 'right'},
      ]));
      expect(q.type.isSingleChoice, false);
      expect(q.leftOptions.map((o) => o.id).toList(), ['l1', 'l2']);
      expect(q.rightOptions.map((o) => o.id).toList(), ['r1', 'r2']);
    });
  });

  group('QuizAnswer', () {
    final mc = QuizQuestion.fromJson(_question());

    test('ChoiceAnswer → {option_id} & lengkap hanya untuk opsi soal itu', () {
      expect(const ChoiceAnswer('o2').toJson(), {'option_id': 'o2'});
      expect(const ChoiceAnswer('o2').isCompleteFor(mc), true);
      expect(const ChoiceAnswer('lain').isCompleteFor(mc), false);
    });

    test('SequenceAnswer harus memakai semua ubin tepat sekali', () {
      final q = QuizQuestion.fromJson(_question(type: 'arrange_word', options: [
        {'id': 't1', 'label': 'M'},
        {'id': 't2', 'label': 'A'},
        {'id': 't3', 'label': 'M'},
      ]));
      expect(const SequenceAnswer(['t3', 't2', 't1']).isCompleteFor(q), true);
      expect(const SequenceAnswer(['t3', 't2']).isCompleteFor(q), false);
      expect(const SequenceAnswer(['t1', 't1', 't2']).isCompleteFor(q), false);
      expect(const SequenceAnswer(['t1', 't2']).toJson(), {'sequence': ['t1', 't2']});
    });

    test('PairsAnswer lengkap bila semua gambar dipasangkan ke arti berbeda', () {
      final q = QuizQuestion.fromJson(_question(type: 'match_image', options: [
        {'id': 'l1', 'label': 'G1', 'side': 'left'},
        {'id': 'r1', 'label': 'A1', 'side': 'right'},
        {'id': 'l2', 'label': 'G2', 'side': 'left'},
        {'id': 'r2', 'label': 'A2', 'side': 'right'},
      ]));
      expect(const PairsAnswer({'l1': 'r1', 'l2': 'r2'}).isCompleteFor(q), true);
      expect(const PairsAnswer({'l1': 'r1'}).isCompleteFor(q), false);
      expect(const PairsAnswer({'l1': 'r1', 'l2': 'r1'}).isCompleteFor(q), false);
      expect(const PairsAnswer({'l1': 'r2'}).toJson(), {
        'pairs': [
          {'left': 'l1', 'right': 'r2'},
        ],
      });
    });
  });

  group('Hasil & kunci dari server', () {
    test('QuizReveal membaca kunci tiap jenis', () {
      final r = QuizReveal.fromJson({
        'question_id': 'q1',
        'is_correct': false,
        'correct_option_id': null,
        'correct_sequence': ['a', 'b'],
        'pairs': [
          {'left': 'l1', 'right': 'r1'},
        ],
        'explanation': 'TEST pembahasan',
      });
      expect(r.isCorrect, false);
      expect(r.correctSequence, ['a', 'b']);
      expect(r.correctPairs, {'l1': 'r1'});
      expect(r.explanation, 'TEST pembahasan');
    });

    test('QuizSessionResult & daftar soal salah', () {
      final r = QuizSessionResult.fromJson({
        'session_id': 's1',
        'score_percent': 67,
        'correct_count': 2,
        'total_count': 3,
        'details': [
          {'question_id': 'a', 'is_correct': true},
          {'question_id': 'b', 'is_correct': false},
          {'question_id': 'c', 'is_correct': true},
        ],
      });
      expect(r.scorePercent, 67);
      expect(r.wrongQuestionIds, ['b']);
    });

    test('riwayat sesi: judul sesuai mode', () {
      final e = QuizHistoryEntry.fromSession({
        'id': 'x',
        'mode': 'category',
        'module': 'number',
        'score_percent': 80,
        'correct_count': 8,
        'total_count': 10,
        'submitted_at': '2026-10-30T03:00:00Z',
      });
      expect(e.title, 'Kuis Angka');
      expect(e.totalCount, 10);
      expect(QuizHistoryEntry.fromSession({'id': 'y', 'mode': 'weak'}).title, 'Latihan Ulang');
    });
  });

  group('QuizConfig', () {
    test('parameter RPC & kesetaraan (dipakai sebagai kunci provider)', () {
      const a = QuizConfig(mode: QuizMode.category, module: QuizModule.vocabulary, categoryId: 'c1', limit: 5);
      expect(a.toRpcParams(), {
        'p_mode': 'category',
        'p_module': 'vocabulary',
        'p_category_id': 'c1',
        'p_difficulty': null,
        'p_limit': 5,
      });
      expect(a == const QuizConfig(mode: QuizMode.category, module: QuizModule.vocabulary, categoryId: 'c1', limit: 5), true);
      expect(a == const QuizConfig(mode: QuizMode.mixed), false);
      expect(const QuizConfig(mode: QuizMode.weak).title, 'Latihan Ulang');
    });
  });

  test('umpan balik skor', () {
    expect(quizFeedback(95).startsWith('Luar biasa'), true);
    expect(quizFeedback(70).startsWith('Bagus'), true);
    expect(quizFeedback(50).startsWith('Cukup'), true);
    expect(quizFeedback(10).startsWith('Tetap semangat'), true);
  });
}
