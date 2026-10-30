import '../../../core/utils/date_format.dart';
import '../../../core/utils/json.dart';
import '../../../core/utils/sample.dart';

class Lesson {
  const Lesson({
    required this.id,
    required this.title,
    this.slug,
    this.description,
    this.itemCount = 0,
    this.items = const [],
    this.quizId,
    this.quizTitle,
    this.sourceNote,
    this.validatedBy,
    this.verifiedAt,
    this.status = 'published',
    this.sortOrder = 0,
  });

  static const listColumns =
      'id, slug, title, description, status, sort_order, validated_by, '
      'items:lesson_items(count)';

  static const detailColumns =
      'id, slug, title, description, status, sort_order, source_note, '
      'validated_by, verified_at, '
      'items:lesson_items(id, position, item_type, body_text, sign_id, '
      'conversation_module_id, sign:signs(id, term), '
      'module:conversation_modules(id, title)), '
      'quiz:quizzes(id, title, is_active)';

  factory Lesson.fromJson(Json json) {
    final items = optList(json, 'items')
        .where((i) => i.containsKey('id'))
        .map(LessonItem.fromJson)
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    final quiz = optObject(json, 'quiz');
    // Variabel bool tidak mempromosikan `quiz` → pakai pola null-check.
    final activeQuiz =
        quiz != null && optBool(quiz, 'is_active', true) ? quiz : null;
    return Lesson(
      id: reqString(json, 'id'),
      slug: optString(json, 'slug'),
      title: reqString(json, 'title'),
      description: optString(json, 'description'),
      itemCount: items.isNotEmpty ? items.length : embeddedCount(json, 'items'),
      items: items,
      quizId: activeQuiz != null ? optString(activeQuiz, 'id') : null,
      quizTitle: activeQuiz != null ? optString(activeQuiz, 'title') : null,
      sourceNote: optString(json, 'source_note'),
      validatedBy: optString(json, 'validated_by'),
      verifiedAt: parseDate(json['verified_at']),
      status: optString(json, 'status') ?? 'published',
      sortOrder: optInt(json, 'sort_order'),
    );
  }

  final String id;
  final String? slug;
  final String title;
  final String? description;
  final int itemCount;
  final List<LessonItem> items;
  final String? quizId;
  final String? quizTitle;
  final String? sourceNote;
  final String? validatedBy;
  final DateTime? verifiedAt;
  final String status;
  final int sortOrder;

  bool get isSample => isSampleValidator(validatedBy);
}

enum LessonItemType { sign, conversationModule, text }

class LessonItem {
  const LessonItem({
    required this.id,
    required this.position,
    required this.type,
    this.signId,
    this.signTerm,
    this.moduleId,
    this.moduleTitle,
    this.bodyText,
  });

  factory LessonItem.fromJson(Json json) {
    final type = switch (optString(json, 'item_type')) {
      'sign' => LessonItemType.sign,
      'conversation_module' => LessonItemType.conversationModule,
      _ => LessonItemType.text,
    };
    final sign = optObject(json, 'sign');
    final module = optObject(json, 'module');
    return LessonItem(
      id: reqString(json, 'id'),
      position: optInt(json, 'position'),
      type: type,
      signId: optString(json, 'sign_id'),
      signTerm: sign != null ? optString(sign, 'term') : null,
      moduleId: optString(json, 'conversation_module_id'),
      moduleTitle: module != null ? optString(module, 'title') : null,
      bodyText: optString(json, 'body_text'),
    );
  }

  final String id;
  final int position;
  final LessonItemType type;
  final String? signId;
  final String? signTerm;
  final String? moduleId;
  final String? moduleTitle;
  final String? bodyText;

  /// Judul yang ditampilkan; materi yang tidak lagi published → null.
  String? get displayTitle => switch (type) {
        LessonItemType.sign => signTerm,
        LessonItemType.conversationModule => moduleTitle,
        LessonItemType.text => bodyText,
      };
}

class Quiz {
  const Quiz({
    required this.id,
    required this.lessonId,
    required this.title,
    required this.passScorePercent,
    required this.questions,
  });

  static const columns =
      'id, lesson_id, title, pass_score_percent, '
      'questions(id, position, prompt, sign_id, '
      'sign:signs(term, video:media_assets!video_asset_id(path)), '
      'options:question_options(id, position, label))';

  factory Quiz.fromJson(Json json) {
    final questions = optList(json, 'questions').map(Question.fromJson).toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    return Quiz(
      id: reqString(json, 'id'),
      lessonId: reqString(json, 'lesson_id'),
      title: reqString(json, 'title'),
      passScorePercent: optInt(json, 'pass_score_percent', 70),
      questions: questions,
    );
  }

  final String id;
  final String lessonId;
  final String title;
  final int passScorePercent;
  final List<Question> questions;
}

class Question {
  const Question({
    required this.id,
    required this.position,
    required this.prompt,
    required this.options,
    this.videoPath,
    this.signTerm,
  });

  factory Question.fromJson(Json json) {
    final sign = optObject(json, 'sign');
    final options = optList(json, 'options').map(QuestionOption.fromJson).toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    return Question(
      id: reqString(json, 'id'),
      position: optInt(json, 'position'),
      prompt: reqString(json, 'prompt'),
      options: options,
      videoPath: sign != null ? (optObject(sign, 'video')?['path'] as String?) : null,
      signTerm: sign != null ? optString(sign, 'term') : null,
    );
  }

  final String id;
  final int position;
  final String prompt;
  final List<QuestionOption> options;
  final String? videoPath;
  final String? signTerm;
}

class QuestionOption {
  const QuestionOption({required this.id, required this.position, required this.label});

  factory QuestionOption.fromJson(Json json) => QuestionOption(
        id: reqString(json, 'id'),
        position: optInt(json, 'position'),
        label: reqString(json, 'label'),
      );

  final String id;
  final int position;
  final String label;
}

/// Hasil dari RPC `submit_quiz_attempt` (D-07): skor dihitung server.
class QuizResult {
  const QuizResult({
    required this.attemptId,
    required this.scorePercent,
    required this.correctCount,
    required this.totalCount,
    required this.passed,
    required this.details,
  });

  factory QuizResult.fromJson(Json json) => QuizResult(
        attemptId: optString(json, 'attempt_id') ?? '',
        scorePercent: optInt(json, 'score_percent'),
        correctCount: optInt(json, 'correct_count'),
        totalCount: optInt(json, 'total_count'),
        passed: optBool(json, 'passed'),
        details: optList(json, 'details').map(QuestionReview.fromJson).toList(),
      );

  final String attemptId;
  final int scorePercent;
  final int correctCount;
  final int totalCount;
  final bool passed;
  final List<QuestionReview> details;
}

class QuestionReview {
  const QuestionReview({
    required this.questionId,
    required this.isCorrect,
    this.selectedOptionId,
    this.correctOptionId,
    this.explanation,
  });

  factory QuestionReview.fromJson(Json json) => QuestionReview(
        questionId: optString(json, 'question_id') ?? '',
        selectedOptionId: optString(json, 'selected_option_id'),
        correctOptionId: optString(json, 'correct_option_id'),
        isCorrect: optBool(json, 'is_correct'),
        explanation: optString(json, 'explanation'),
      );

  final String questionId;
  final String? selectedOptionId;
  final String? correctOptionId;
  final bool isCorrect;
  final String? explanation;
}

class QuizAttempt {
  const QuizAttempt({
    required this.id,
    required this.quizId,
    required this.scorePercent,
    required this.passed,
    required this.submittedAt,
    this.quizTitle,
  });

  factory QuizAttempt.fromJson(Json json) => QuizAttempt(
        id: reqString(json, 'id'),
        quizId: reqString(json, 'quiz_id'),
        scorePercent: optInt(json, 'score_percent'),
        passed: optBool(json, 'passed'),
        submittedAt: parseDate(json['submitted_at']) ?? DateTime.now(),
        quizTitle: optObject(json, 'quiz')?['title'] as String?,
      );

  final String id;
  final String quizId;
  final int scorePercent;
  final bool passed;
  final DateTime submittedAt;
  final String? quizTitle;
}
