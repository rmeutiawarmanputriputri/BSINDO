import '../../features/dictionary/domain/sign.dart';
import '../../features/quiz/domain/quiz_bank.dart';

/// Path rute (UI_UX_SPECIFICATION.md §3).
abstract final class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const verifyEmail = '/verify-email';
  static const resetPassword = '/reset-password';

  // Tab (shell)
  static const home = '/home';
  static const dictionary = '/dictionary';
  static const conversations = '/conversations';
  static const learn = '/learn';
  static const profile = '/profile';

  // Layar penuh (di atas shell)
  static const transcribe = '/transcribe';
  static const favorites = '/favorites';
  static const difficult = '/difficult';
  static const reports = '/reports';
  static const reportNew = '/report/new';
  static const admin = '/admin';
  static const learnProgress = '/learn/progress';

  // v1.1.0
  static const alphabet = '/alphabet';
  static const numbers = '/numbers';
  static const quizHub = '/quiz';
  static const quizHistory = '/quiz/history';
  static const search = '/search';
  static const notifications = '/notifications';
  static const faq = '/faq';
  static const premium = '/premium';
  static const history = '/history';

  /// Detail belajar huruf/angka/kosakata. [learnMode] = mode belajar berurutan.
  static String study(ContentModule module, String id, {bool learnMode = false}) => Uri(
        path: '/study/${module.value}/$id',
        queryParameters: learnMode ? {'mode': 'learn'} : null,
      ).toString();

  /// Sesi kuis bank; konfigurasi di query agar aman dari kehilangan state.
  static String quizPlay(QuizConfig config) => Uri(
        path: '/quiz/play',
        queryParameters: {
          'mode': config.mode.value,
          if (config.module != null) 'module': config.module!.value,
          if (config.categoryId != null) 'category': config.categoryId!,
          if (config.categoryName != null) 'categoryName': config.categoryName!,
          if (config.difficulty != null) 'difficulty': config.difficulty!.value,
          'limit': '${config.limit}',
        },
      ).toString();

  static QuizConfig parseQuizConfig(Map<String, String> q) => QuizConfig(
        mode: QuizMode.parse(q['mode']),
        module: QuizModule.parse(q['module']),
        categoryId: q['category'],
        categoryName: q['categoryName'],
        difficulty: q['difficulty'] == null ? null : QuizDifficulty.parse(q['difficulty']),
        limit: (int.tryParse(q['limit'] ?? '') ?? 10).clamp(1, 50),
      );

  /// Rute aplikasi yang boleh dipakai banner CMS (target_type = route).
  static String? bannerRoute(String value) => switch (value) {
        '/alphabet' => alphabet,
        '/numbers' => numbers,
        '/vocabulary' => dictionary,
        '/conversations' => conversations,
        '/quiz' => quizHub,
        '/profile' => profile,
        '/premium' => premium,
        '/faq' => faq,
        _ => null,
      };

  static String sign(String id) => '/dictionary/sign/$id';
  static String conversation(String id) => '/conversations/$id';
  static String lesson(String id) => '/learn/$id';
  static String quiz(String lessonId) => '/learn/$lessonId/quiz';
  static String difficultReview(String signId) => '/difficult/review/$signId';
  static String adminEntity(String entity) => '/admin/$entity';
  static String adminEdit(String entity, String id) => '/admin/$entity/$id';

  static String verifyEmailFor(String email) =>
      Uri(path: verifyEmail, queryParameters: {'email': email}).toString();

  static String newReport({
    required String type,
    required String id,
    required String title,
  }) =>
      Uri(
        path: reportNew,
        queryParameters: {'type': type, 'id': id, 'title': title},
      ).toString();

  /// Rute tamu (hanya untuk yang belum masuk).
  static const guestRoutes = {login, register, forgotPassword, verifyEmail};
}
