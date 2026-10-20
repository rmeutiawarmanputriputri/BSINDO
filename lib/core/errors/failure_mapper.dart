import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_failure.dart';

/// Batas waktu permintaan jaringan (FLUTTER_ARCHITECTURE §7).
const kRequestTimeout = Duration(seconds: 15);

/// Menjalankan [action] dengan timeout dan menerjemahkan semua exception
/// menjadi [AppFailure]. Dipakai di SEMUA repository.
Future<T> guardRequest<T>(Future<T> Function() action) async {
  try {
    return await action().timeout(kRequestTimeout);
  } on AppFailure {
    rethrow;
  } catch (error) {
    throw mapError(error);
  }
}

/// Pemetaan exception teknis → [AppFailure]. Detail hanya ke log debug,
/// tanpa PII (email/sandi tidak pernah dicetak).
AppFailure mapError(Object error) {
  final failure = _map(error);
  if (kDebugMode) {
    debugPrint('mapError: ${error.runtimeType} → ${failure.runtimeType}');
  }
  return failure;
}

AppFailure _map(Object error) {
  if (error is AppFailure) return error;
  if (error is TimeoutException || error is SocketException) {
    return const NetworkFailure();
  }
  if (error is AuthRetryableFetchException) return const NetworkFailure();
  if (error is AuthException) return _mapAuth(error);
  if (error is PostgrestException) return _mapPostgrest(error);
  if (error is StorageException) return _mapStorage(error);
  // http.ClientException (koneksi putus) tanpa bergantung langsung ke paket http.
  final typeName = error.runtimeType.toString();
  if (typeName.contains('ClientException') || error is HttpException) {
    return const NetworkFailure();
  }
  return const UnknownFailure();
}

AppFailure _mapAuth(AuthException e) {
  final code = (e.code ?? '').toLowerCase();
  final status = e.statusCode ?? '';
  final message = e.message.toLowerCase();
  switch (code) {
    case 'invalid_credentials':
      return const AuthFailure(AuthFailureCode.invalidCredentials);
    case 'email_not_confirmed':
      return const AuthFailure(AuthFailureCode.emailNotConfirmed);
    case 'user_already_exists':
    case 'email_exists':
      return const AuthFailure(AuthFailureCode.emailAlreadyRegistered);
    case 'weak_password':
      return const AuthFailure(AuthFailureCode.weakPassword);
    case 'over_request_rate_limit':
    case 'over_email_send_rate_limit':
    case 'over_sms_send_rate_limit':
      return const RateLimitFailure();
  }
  if (e is AuthWeakPasswordException) {
    return const AuthFailure(AuthFailureCode.weakPassword);
  }
  if (status == '429') return const RateLimitFailure();
  // Server lama tanpa kode error.
  if (message.contains('invalid login credentials')) {
    return const AuthFailure(AuthFailureCode.invalidCredentials);
  }
  if (message.contains('email not confirmed')) {
    return const AuthFailure(AuthFailureCode.emailNotConfirmed);
  }
  if (message.contains('already registered')) {
    return const AuthFailure(AuthFailureCode.emailAlreadyRegistered);
  }
  return const UnknownFailure();
}

AppFailure _mapPostgrest(PostgrestException e) {
  final code = e.code ?? '';
  final message = e.message;
  if (code == '42501' || code == 'PGRST301' || code == '401' || code == '403') {
    return const PermissionFailure();
  }
  if (code == '23505') return ConflictFailure(_constraintOf(message));
  if (code == '23514') return ValidationFailure(_constraintOf(message));
  if (code == '23503' || code == '23502' || code == '22P02' || code == '22023') {
    return ValidationFailure(code);
  }
  if (code == 'PGRST116') return const NotFoundFailure();
  if (message.contains('report_rate_limited')) return const RateLimitFailure();
  if (message.contains('quiz_not_available') || code == 'P0002') {
    return const NotFoundFailure();
  }
  return const UnknownFailure();
}

AppFailure _mapStorage(StorageException e) {
  switch (e.statusCode) {
    case '400':
      if (e.message.toLowerCase().contains('not found')) {
        return const NotFoundFailure();
      }
      return const ValidationFailure('storage_400');
    case '401':
    case '403':
      return const PermissionFailure();
    case '404':
      return const NotFoundFailure();
    case '409':
      return const ConflictFailure('storage_409');
    case '413':
      return const ValidationFailure('file_too_large');
    case '415':
      return const ValidationFailure('mime_not_allowed');
    case '429':
      return const RateLimitFailure();
  }
  return const UnknownFailure();
}

/// Mengambil nama constraint dari pesan Postgres, mis.
/// `new row ... violates check constraint "signs_validation_required"`.
String _constraintOf(String message) {
  final match = RegExp(r'constraint "([^"]+)"').firstMatch(message);
  return match?.group(1) ?? message;
}
