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
