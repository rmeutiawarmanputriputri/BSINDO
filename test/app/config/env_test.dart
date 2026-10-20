import 'package:bisindo_app/app/config/env.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppConfig', () {
    test('kosong → tidak valid dengan dua masalah', () {
      const config = AppConfig(supabaseUrl: '', supabaseAnonKey: '');
      expect(config.isValid, isFalse);
      expect(config.problems, hasLength(2));
    });

    test('https + anon key → valid', () {
      const config = AppConfig(
        supabaseUrl: 'https://abcd.supabase.co',
        supabaseAnonKey: 'dummy-anon-key',
      );
      expect(config.isValid, isTrue);
    });

    test('http non-lokal ditolak, http lokal diterima', () {
      const remote = AppConfig(
        supabaseUrl: 'http://abcd.supabase.co',
        supabaseAnonKey: 'k',
      );
      const local = AppConfig(
        supabaseUrl: 'http://10.0.2.2:54321',
        supabaseAnonKey: 'k',
      );
      expect(remote.isValid, isFalse);
      expect(local.isValid, isTrue);
    });

    test('pesan masalah tidak memuat nilai kunci', () {
      const config = AppConfig(
        supabaseUrl: 'bukan-url',
        supabaseAnonKey: '',
      );
      for (final p in config.problems) {
        expect(p, isNot(contains('bukan-url')));
      }
    });
  });
}
