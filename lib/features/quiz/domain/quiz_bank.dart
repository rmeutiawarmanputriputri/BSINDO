import '../../../core/utils/json.dart';

/// Jenis soal bank kuis (v1.1.0). Nilai = kolom `questions.question_type`.
enum QuizType {
  guessLetter('guess_letter', 'Tebak huruf'),
  guessNumber('guess_number', 'Tebak angka'),
  guessSign('guess_sign', 'Tebak gerakan'),
  multipleChoice('multiple_choice', 'Pilihan ganda'),
  matchImage('match_image', 'Cocokkan gambar & arti'),
  arrangeWord('arrange_word', 'Susun kosakata');

  const QuizType(this.value, this.label);
  final String value;
  final String label;

  /// Jenis dengan satu jawaban benar.
  bool get isSingleChoice =>
      this != QuizType.matchImage && this != QuizType.arrangeWord;

  static QuizType parse(String? value) => QuizType.values.firstWhere(
    (t) => t.value == value,
    orElse: () => QuizType.multipleChoice,
  );
}

/// Modul kuis (kolom `questions.module`).
enum QuizModule {
  alphabet('alphabet', 'Alfabet'),
  number('number', 'Angka'),
  vocabulary('vocabulary', 'Kosakata'),
  conversation('conversation', 'Percakapan'),
  general('general', 'Umum');

  const QuizModule(this.value, this.label);
  final String value;
  final String label;

  static QuizModule? parse(String? value) {
    for (final m in values) {
      if (m.value == value) return m;
    }
    return null;
  }
}

enum QuizDifficulty {
  easy('easy', 'Mudah'),
  medium('medium', 'Sedang'),
  hard('hard', 'Sulit');

  const QuizDifficulty(this.value, this.label);
  final String value;
  final String label;

  static QuizDifficulty parse(String? value) => QuizDifficulty.values
      .firstWhere((d) => d.value == value, orElse: () => QuizDifficulty.medium);
}

/// Mode kuis: per kategori/modul, campuran, atau latihan materi yang belum dikuasai.
enum QuizMode {
  category('category', 'Per kategori'),
  mixed('mixed', 'Campuran'),
  weak('weak', 'Latihan yang belum dikuasai');

  const QuizMode(this.value, this.label);
  final String value;
  final String label;

  static QuizMode parse(String? value) => QuizMode.values.firstWhere(
    (m) => m.value == value,
    orElse: () => QuizMode.mixed,
  );
}

/// Konfigurasi sesi kuis (dikirim ke RPC `get_quiz_questions`).
class QuizConfig {
  const QuizConfig({
    this.mode = QuizMode.mixed,
    this.module,
    this.categoryId,
    this.categoryName,
    this.difficulty,
    this.limit = 10,
  });

  final QuizMode mode;
  final QuizModule? module;
  final String? categoryId;
  final String? categoryName;
  final QuizDifficulty? difficulty;
  final int limit;

  String get title => switch (mode) {
    QuizMode.category => 'Kuis ${categoryName ?? module?.label ?? ''}'.trim(),
    QuizMode.mixed => 'Kuis Campuran',
    QuizMode.weak => 'Latihan Ulang',
  };

  Map<String, dynamic> toRpcParams() => {
    'p_mode': mode.value,
    'p_module': module?.value,
    'p_category_id': categoryId,
    'p_difficulty': difficulty?.value,
    'p_limit': limit,
  };

  @override
  bool operator ==(Object other) =>
      other is QuizConfig &&
      other.mode == mode &&
      other.module == module &&
      other.categoryId == categoryId &&
      other.difficulty == difficulty &&
      other.limit == limit;

  @override
  int get hashCode => Object.hash(mode, module, categoryId, difficulty, limit);
}

class QuizOption {
  const QuizOption({
    required this.id,
    required this.label,
    this.side,
    this.imagePath,
  });

  factory QuizOption.fromJson(Json json) => QuizOption(
    id: reqString(json, 'id'),
    label: optString(json, 'label') ?? '',
    side: optString(json, 'side'),
    imagePath: optString(json, 'image_path'),
  );

  final String id;
  final String label;

  /// `left` (gambar) / `right` (arti) untuk soal cocokkan; null untuk lainnya.
  final String? side;
  final String? imagePath;
}

/// Soal bank TANPA kunci jawaban (kunci hanya ada di server).
class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.type,
    required this.prompt,
    required this.options,
    this.module,
    this.difficulty = QuizDifficulty.medium,
    this.videoPath,
    this.imagePath,
    this.isPremium = false,
  });

  factory QuizQuestion.fromJson(Json json) => QuizQuestion(
    id: reqString(json, 'id'),
    type: QuizType.parse(optString(json, 'question_type')),
    prompt: optString(json, 'prompt') ?? '',
    module: QuizModule.parse(optString(json, 'module')),
    difficulty: QuizDifficulty.parse(optString(json, 'difficulty')),
    videoPath: optString(json, 'video_path'),
    imagePath: optString(json, 'image_path'),
    isPremium: optBool(json, 'is_premium'),
    options: optList(json, 'options').map(QuizOption.fromJson).toList(),
  );

  final String id;
  final QuizType type;
  final String prompt;
  final List<QuizOption> options;
  final QuizModule? module;
  final QuizDifficulty difficulty;
  final String? videoPath;
  final String? imagePath;
  final bool isPremium;

  List<QuizOption> get leftOptions =>
      options.where((o) => o.side == 'left').toList();
  List<QuizOption> get rightOptions =>
      options.where((o) => o.side == 'right').toList();
}

/// Jawaban pengguna untuk satu soal.
sealed class QuizAnswer {
  const QuizAnswer();

  Map<String, dynamic> toJson();

  /// Jawaban sudah lengkap untuk soal [q]?
  bool isCompleteFor(QuizQuestion q);
}

class ChoiceAnswer extends QuizAnswer {
  const ChoiceAnswer(this.optionId);
  final String optionId;

  @override
  Map<String, dynamic> toJson() => {'option_id': optionId};

  @override
  bool isCompleteFor(QuizQuestion q) => q.options.any((o) => o.id == optionId);
}

class SequenceAnswer extends QuizAnswer {
  const SequenceAnswer(this.optionIds);
  final List<String> optionIds;

  @override
  Map<String, dynamic> toJson() => {'sequence': optionIds};

  @override
  bool isCompleteFor(QuizQuestion q) =>
      optionIds.length == q.options.length &&
      optionIds.toSet().length == optionIds.length;
}

class PairsAnswer extends QuizAnswer {
  const PairsAnswer(this.pairs);

  /// id opsi kiri → id opsi kanan.
  final Map<String, String> pairs;

  @override
  Map<String, dynamic> toJson() => {
    'pairs': [
      for (final e in pairs.entries) {'left': e.key, 'right': e.value},
    ],
  };

  @override
  bool isCompleteFor(QuizQuestion q) {
    final lefts = q.leftOptions.map((o) => o.id).toSet();
    return lefts.isNotEmpty &&
        pairs.keys.toSet().containsAll(lefts) &&
        pairs.values.toSet().length == pairs.length;
  }
}

/// Kunci yang diungkap server setelah menjawab.
class QuizReveal {
  const QuizReveal({
    required this.questionId,
    required this.isCorrect,
    this.correctOptionId,
    this.correctSequence = const [],
    this.correctPairs = const {},
    this.explanation,
  });

  factory QuizReveal.fromJson(Json json) {
    final seq = json['correct_sequence'];
    final pairs = json['pairs'];
    return QuizReveal(
      questionId: reqString(json, 'question_id'),
      isCorrect: optBool(json, 'is_correct'),
      correctOptionId: optString(json, 'correct_option_id'),
      correctSequence: seq is List
          ? seq.whereType<String>().toList()
          : const [],
      correctPairs: pairs is List
          ? {
              for (final p in pairs.whereType<Map<String, dynamic>>())
                if (p['left'] is String && p['right'] is String)
                  p['left'] as String: p['right'] as String,
            }
          : const {},
      explanation: optString(json, 'explanation'),
    );
  }

  final String questionId;
  final bool isCorrect;
  final String? correctOptionId;
  final List<String> correctSequence;
  final Map<String, String> correctPairs;
  final String? explanation;
}

/// Hasil sesi (RPC `submit_quiz_session`; dinilai server).
class QuizSessionResult {
  const QuizSessionResult({
    required this.sessionId,
    required this.scorePercent,
    required this.correctCount,
    required this.totalCount,
    required this.details,
  });

  factory QuizSessionResult.fromJson(Json json) => QuizSessionResult(
    sessionId: optString(json, 'session_id') ?? '',
    scorePercent: optInt(json, 'score_percent'),
    correctCount: optInt(json, 'correct_count'),
    totalCount: optInt(json, 'total_count'),
    details: optList(json, 'details').map(QuizReveal.fromJson).toList(),
  );

  final String sessionId;
  final int scorePercent;
  final int correctCount;
  final int totalCount;
  final List<QuizReveal> details;

  List<String> get wrongQuestionIds => [
    for (final d in details)
      if (!d.isCorrect) d.questionId,
  ];
}

/// Satu baris riwayat kuis (bank `quiz_sessions` atau kuis pelajaran lama).
class QuizHistoryEntry {
  const QuizHistoryEntry({
    required this.id,
    required this.title,
    required this.scorePercent,
    required this.submittedAt,
    this.correctCount,
    this.totalCount,
  });

  factory QuizHistoryEntry.fromSession(Json json) {
    final mode = QuizMode.parse(optString(json, 'mode'));
    final module = QuizModule.parse(optString(json, 'module'));
    final title = switch (mode) {
      QuizMode.category => 'Kuis ${module?.label ?? 'Kategori'}',
      QuizMode.mixed => 'Kuis Campuran',
      QuizMode.weak => 'Latihan Ulang',
    };
    return QuizHistoryEntry(
      id: reqString(json, 'id'),
      title: title,
      scorePercent: optInt(json, 'score_percent'),
      correctCount: optInt(json, 'correct_count'),
      totalCount: optInt(json, 'total_count'),
      submittedAt:
          DateTime.tryParse(optString(json, 'submitted_at') ?? '')?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  final String id;
  final String title;
  final int scorePercent;
  final int? correctCount;
  final int? totalCount;
  final DateTime submittedAt;
}

/// Pesan umpan balik sesuai skor.
String quizFeedback(int percent) {
  if (percent >= 90) return 'Luar biasa! Pertahankan.';
  if (percent >= 70) return 'Bagus! Sedikit lagi sempurna.';
  if (percent >= 50) return 'Cukup baik. Ulangi soal yang salah, ya.';
  return 'Tetap semangat! Pelajari lagi materinya lalu coba kembali.';
}
