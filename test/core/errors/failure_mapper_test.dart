import 'dart:async';
import 'dart:io';

import 'package:bisindo_app/core/errors/app_failure.dart';
import 'package:bisindo_app/core/errors/failure_mapper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// AUTH-05: pemetaan error Supabase → AppFailure.
void main() {
  AuthFailureCode? authCode(Object e) {
    final f = mapError(e);
    return f is AuthFailure ? f.code : null;
  }

  test('kode Auth Supabase', () {
    expect(authCode(const AuthException('x', code: 'invalid_credentials')),
        AuthFailureCode.invalidCredentials);
    expect(authCode(const AuthException('x', code: 'email_not_confirmed')),
        AuthFailureCode.emailNotConfirmed);
    expect(authCode(const AuthException('x', code: 'user_already_exists')),
        AuthFailureCode.emailAlreadyRegistered);
    expect(authCode(const AuthException('x', code: 'email_exists')),
        AuthFailureCode.emailAlreadyRegistered);
    expect(authCode(const AuthException('x', code: 'weak_password')),
        AuthFailureCode.weakPassword);
    expect(mapError(const AuthException('x', code: 'over_request_rate_limit')),
        isA<RateLimitFailure>());
    expect(mapError(const AuthException('x', statusCode: '429')),
        isA<RateLimitFailure>());
    expect(authCode(const AuthException('Invalid login credentials')),
        AuthFailureCode.invalidCredentials);
    expect(mapError(const AuthException('aneh')), isA<UnknownFailure>());
  });

  test('jaringan', () {
    expect(mapError(const SocketException('x')), isA<NetworkFailure>());
    expect(mapError(TimeoutException('x')), isA<NetworkFailure>());
  });

  test('Postgrest: RLS, unik, CHECK, batas laporan', () {
    expect(mapError(const PostgrestException(message: 'x', code: '42501')),
        isA<PermissionFailure>());
    final conflict = mapError(const PostgrestException(
      message: 'duplicate key value violates unique constraint "content_reports_open_unique"',
      code: '23505',
    ));
    expect(conflict, isA<ConflictFailure>());
    expect((conflict as ConflictFailure).detail, 'content_reports_open_unique');
    final check = mapError(const PostgrestException(
      message: 'new row for relation "signs" violates check constraint "signs_validation_required"',
      code: '23514',
    ));
    expect(check, isA<ValidationFailure>());
    expect((check as ValidationFailure).detail, 'signs_validation_required');
    expect(mapError(const PostgrestException(message: 'report_rate_limited', code: 'P0001')),
        isA<RateLimitFailure>());
    expect(mapError(const PostgrestException(message: 'x', code: 'PGRST116')),
        isA<NotFoundFailure>());
  });

  test('Storage', () {
    expect(mapError(const StorageException('x', statusCode: '404')), isA<NotFoundFailure>());
    expect(mapError(const StorageException('x', statusCode: '403')), isA<PermissionFailure>());
    expect(mapError(const StorageException('x', statusCode: '413')), isA<ValidationFailure>());
  });

  test('guardRequest meneruskan AppFailure & memetakan yang lain', () async {
    await expectLater(
      guardRequest<void>(() async => throw const NotFoundFailure()),
      throwsA(isA<NotFoundFailure>()),
    );
    await expectLater(
      guardRequest<void>(() async => throw const SocketException('x')),
      throwsA(isA<NetworkFailure>()),
    );
  });
}
