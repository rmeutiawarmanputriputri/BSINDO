/// Path rute (UI_UX_SPECIFICATION.md §3). Fase 1 hanya memakai 3 rute auth.
abstract final class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';

  // Ditambahkan pada fase berikutnya (belum ada layarnya):
  // forgotPassword '/forgot-password', verifyEmail '/verify-email',
  // resetPassword '/reset-password', home '/home', ...
}
