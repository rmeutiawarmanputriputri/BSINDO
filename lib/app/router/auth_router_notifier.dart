import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/domain/auth_event.dart';
import 'routes.dart';

/// Menyambungkan peristiwa auth ke `GoRouter.refreshListenable` dan
/// menyimpan status pemulihan sandi.
class AuthRouterNotifier extends ChangeNotifier {
  AuthRouterNotifier(this._repository) {
    _subscription = _repository.events.listen(_onEvent);
  }

  final AuthRepository _repository;
  late final StreamSubscription<AuthEvent> _subscription;
  bool _passwordRecovery = false;

  bool get isSignedIn => _repository.isSignedIn;
  bool get isPasswordRecovery => _passwordRecovery;

  void _onEvent(AuthEvent event) {
    switch (event) {
      case AuthEvent.passwordRecovery:
        _passwordRecovery = true;
      case AuthEvent.signedOut:
        _passwordRecovery = false;
      case AuthEvent.signedIn:
      case AuthEvent.userUpdated:
      case AuthEvent.other:
        break;
    }
    notifyListeners();
  }

  /// Dipanggil setelah sandi baru tersimpan.
  void completePasswordRecovery() {
    _passwordRecovery = false;
    notifyListeners();
  }

  /// Logika redirect (D-02). Mengembalikan path tujuan atau null.
  String? redirect(String location) {
    if (location == AppRoutes.splash) return null;
    if (_passwordRecovery) {
      return location == AppRoutes.resetPassword ? null : AppRoutes.resetPassword;
    }
    if (location == AppRoutes.resetPassword) {
      return isSignedIn ? null : AppRoutes.login;
    }
    final guest = AppRoutes.guestRoutes.contains(location);
    if (!isSignedIn) return guest ? null : AppRoutes.login;
    if (guest) return AppRoutes.home;
    return null;
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
