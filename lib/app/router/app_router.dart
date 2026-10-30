import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/uuid.dart';
import '../../core/widgets/state_views.dart';
import '../../features/admin/presentation/admin_dashboard_screen.dart';
import '../../features/admin/presentation/admin_routes.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/verify_email_screen.dart';
import '../../features/conversation/presentation/conversation_detail_screen.dart';
import '../../features/conversation/presentation/conversation_list_screen.dart';
import '../../features/dictionary/domain/sign.dart';
import '../../features/dictionary/presentation/dictionary_screen.dart';
import '../../features/dictionary/presentation/sign_detail_screen.dart';
import '../../features/difficult_vocab/presentation/difficult_list_screen.dart';
import '../../features/difficult_vocab/presentation/difficult_review_screen.dart';
import '../../features/favorites/presentation/favorites_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/home_content/presentation/info_screens.dart';
import '../../features/learning/presentation/lesson_detail_screen.dart';
import '../../features/learning/presentation/lessons_screen.dart';
import '../../features/learning/presentation/progress_screen.dart';
import '../../features/learning/presentation/quiz_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/quiz/presentation/quiz_history_screen.dart';
import '../../features/quiz/presentation/quiz_hub_screen.dart';
import '../../features/quiz/presentation/quiz_play_screen.dart';
import '../../features/reports/domain/report.dart';
import '../../features/reports/presentation/report_form_screen.dart';
import '../../features/reports/presentation/report_history_screen.dart';
import '../../features/study/presentation/history_and_search_screens.dart';
import '../../features/study/presentation/module_grid_screen.dart';
import '../../features/study/presentation/sign_study_screen.dart';
import '../../features/transcription/presentation/transcription_screen.dart';
import '../shell/app_shell.dart';
import 'auth_router_notifier.dart';
import 'routes.dart';

/// Navigator akar: rute detail/layar penuh tampil di atas NavigationBar.
final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final authRouterNotifierProvider = Provider<AuthRouterNotifier>((ref) {
  final notifier = AuthRouterNotifier(ref.watch(authRepositoryProvider));
  ref.onDispose(notifier.dispose);
  return notifier;
});

/// `pageBuilder` + `MaterialPage` eksplisit: go_router 18 mendeteksi
/// `MaterialApp` dari paket `material_ui`, bukan `package:flutter/material`,
/// sehingga tanpa ini transisi halaman jatuh ke `NoTransitionPage`.
Page<void> _page(GoRouterState state, Widget child) =>
    MaterialPage<void>(key: state.pageKey, child: child);

/// Parameter ID rute divalidasi UUID (FLUTTER_ARCHITECTURE §6).
Widget _withId(
  GoRouterState state,
  String name,
  Widget Function(String id) build,
) {
  final id = state.pathParameters[name];
  return isUuid(id) ? build(id!) : const _NotFoundScreen();
}

GoRoute _route(
  String path,
  Widget Function(GoRouterState state) build, {
  List<RouteBase> routes = const [],
  bool root = false,
}) => GoRoute(
  path: path,
  parentNavigatorKey: root ? rootNavigatorKey : null,
  pageBuilder: (context, state) => _page(state, build(state)),
  routes: routes,
);

final appRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authRouterNotifierProvider);
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    refreshListenable: auth,
    redirect: (context, state) => auth.redirect(state.matchedLocation),
    routes: [
      _route(AppRoutes.splash, (_) => const SplashScreen()),
      _route(AppRoutes.login, (_) => const LoginScreen()),
      _route(AppRoutes.register, (_) => const RegisterScreen()),
      _route(AppRoutes.forgotPassword, (_) => const ForgotPasswordScreen()),
      _route(
        AppRoutes.verifyEmail,
        (s) => VerifyEmailScreen(email: s.uri.queryParameters['email'] ?? ''),
      ),
      _route(AppRoutes.resetPassword, (_) => const ResetPasswordScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [_route(AppRoutes.home, (_) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [
              _route(
                AppRoutes.dictionary,
                (_) => const DictionaryScreen(),
                routes: [
                  _route(
                    'sign/:id',
                    (s) =>
                        _withId(s, 'id', (id) => SignDetailScreen(signId: id)),
                    root: true,
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              _route(
                AppRoutes.conversations,
                (_) => const ConversationListScreen(),
                routes: [
                  _route(
                    ':id',
                    (s) => _withId(
                      s,
                      'id',
                      (id) => ConversationDetailScreen(moduleId: id),
                    ),
                    root: true,
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              _route(
                AppRoutes.learn,
                (_) => const LessonsScreen(),
                routes: [
                  _route('progress', (_) => const ProgressScreen(), root: true),
                  _route(
                    ':id',
                    (s) => _withId(
                      s,
                      'id',
                      (id) => LessonDetailScreen(lessonId: id),
                    ),
                    root: true,
                    routes: [
                      _route(
                        'quiz',
                        (s) =>
                            _withId(s, 'id', (id) => QuizScreen(lessonId: id)),
                        root: true,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [_route(AppRoutes.profile, (_) => const ProfileScreen())],
          ),
        ],
      ),
      _route(AppRoutes.transcribe, (_) => const TranscriptionScreen()),
      _route(AppRoutes.favorites, (_) => const FavoritesScreen()),
      _route(
        AppRoutes.difficult,
        (_) => const DifficultListScreen(),
        routes: [
          _route(
            'review/:signId',
            (s) =>
                _withId(s, 'signId', (id) => DifficultReviewScreen(signId: id)),
          ),
        ],
      ),
      _route(AppRoutes.reports, (_) => const ReportHistoryScreen()),
      _route(AppRoutes.reportNew, (s) {
        final q = s.uri.queryParameters;
        final id = q['id'];
        return ReportFormScreen(
          targetType: ReportTargetType.parse(q['type']),
          targetId: isUuid(id) ? id : null,
          targetTitle: q['title'] ?? '',
        );
      }),
      // ---------------------------------------------------------- v1.1.0
      _route(
        AppRoutes.alphabet,
        (_) => const ModuleGridScreen(module: ContentModule.alphabet),
      ),
      _route(
        AppRoutes.numbers,
        (_) => const ModuleGridScreen(module: ContentModule.number),
      ),
      _route(
        '/study/:module/:id',
        (s) => _withId(
          s,
          'id',
          (id) => SignStudyScreen(
            module: ContentModule.parse(s.pathParameters['module']),
            signId: id,
            learnMode: s.uri.queryParameters['mode'] == 'learn',
          ),
        ),
      ),
      _route(
        AppRoutes.quizHub,
        (_) => const QuizHubScreen(),
        routes: [
          _route('history', (_) => const QuizHistoryScreen()),
          _route(
            'play',
            (s) => QuizPlayScreen(
              config: AppRoutes.parseQuizConfig(s.uri.queryParameters),
            ),
          ),
        ],
      ),
      _route(AppRoutes.search, (_) => const GlobalSearchScreen()),
      _route(AppRoutes.history, (_) => const LearningHistoryScreen()),
      _route(AppRoutes.notifications, (_) => const NotificationsScreen()),
      _route(AppRoutes.faq, (_) => const FaqScreen()),
      _route(AppRoutes.premium, (_) => const PremiumScreen()),
      _route(
        AppRoutes.admin,
        (_) => const AdminDashboardScreen(),
        routes: [
          _route(
            ':entity',
            (s) => adminEntityPage(s.pathParameters['entity'] ?? ''),
            routes: [
              _route(
                ':id',
                (s) => adminEditPage(
                  s.pathParameters['entity'] ?? '',
                  s.pathParameters['id'] ?? '',
                ),
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => const _NotFoundScreen(),
  );
  ref.onDispose(router.dispose);
  return router;
});

class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: EmptyView(
        icon: Icons.help_outline,
        title: 'Halaman tidak ditemukan',
        actionLabel: 'Ke Beranda',
        onAction: () => context.go(AppRoutes.home),
      ),
    );
  }
}
