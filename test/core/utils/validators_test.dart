import 'package:bisindo_app/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

/// AUTH-01: validator sesuai AUTH_UI_DESIGN_SPEC.md §6.
void main() {
  group('Validators.fullName', () {
    test('kurang dari 2 karakter (setelah trim) → pesan', () {
      expect(Validators.fullName(''), 'Nama lengkap minimal 2 karakter.');
      expect(Validators.fullName(' a '), 'Nama lengkap minimal 2 karakter.');
      expect(Validators.fullName(null), 'Nama lengkap minimal 2 karakter.');
    });
    test('2–80 karakter → valid', () {
      expect(Validators.fullName('Al'), isNull);
      expect(Validators.fullName('  Budi Santoso  '), isNull);
      expect(Validators.fullName('a' * 80), isNull);
    });
    test('lebih dari 80 → pesan', () {
      expect(Validators.fullName('a' * 81), isNotNull);
    });
  });

  group('Validators.email', () {
    const message = 'Masukkan alamat email yang valid.';
    test('kosong / format salah → pesan', () {
      for (final v in ['', '   ', 'nama', 'nama@', '@email.com', 'a@b', 'a b@c.com']) {
        expect(Validators.email(v), message, reason: v);
      }
    });
    test('format valid (trim + huruf besar diterima) → null', () {
      for (final v in ['nama@email.com', '  Nama@Email.COM ', 'a.b+c@sub.id.co']) {
        expect(Validators.email(v), isNull, reason: v);
      }
    });
    test('normalizeEmail: trim + lowercase', () {
      expect(normalizeEmail('  Nama@Email.COM '), 'nama@email.com');
    });
  });

  group('Validators.newPassword', () {
    test('< 8 → pesan; ≥ 8 → null; spasi tidak di-trim', () {
      expect(Validators.newPassword('1234567'), 'Kata sandi minimal 8 karakter.');
      expect(Validators.newPassword('12345678'), isNull);
      expect(Validators.newPassword('        '), isNull);
    });
  });

  group('Validators.confirmPassword', () {
    test('tidak sama / kosong → pesan; sama → null', () {
      const msg = 'Konfirmasi kata sandi tidak sama.';
      expect(Validators.confirmPassword('abcdefgh', 'abcdefgi'), msg);
      expect(Validators.confirmPassword('', ''), msg);
      expect(Validators.confirmPassword('abcdefgh', 'abcdefgh'), isNull);
    });
  });

  group('Validators.loginPassword', () {
    test('wajib diisi', () {
      expect(Validators.loginPassword(''), 'Masukkan kata sandi Anda.');
      expect(Validators.loginPassword(null), 'Masukkan kata sandi Anda.');
      expect(Validators.loginPassword('x'), isNull);
    });
  });
}
