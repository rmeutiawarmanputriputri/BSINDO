/// Semua teks UI auth di satu tempat (FLUTTER_ARCHITECTURE.md §13).
/// Teks layar Login/Register disalin PERSIS dari gambar referensi.
abstract final class AuthStrings {
  // Login (docs/design/reference/login.png)
  static const loginTitle = 'Masuk ke Akun Anda';
  static const emailLabel = 'Alamat Email';
  static const emailHint = 'Email Anda (contoh: nama@email.com)';
  static const passwordLabel = 'Kata Sandi';
  static const loginPasswordHint = 'Masukkan kata sandi';
  static const forgotPassword = 'Lupa Kata Sandi?';
  static const loginButton = 'Masuk';
  static const loginDivider = 'Atau masuk dengan';
  static const noAccount = 'Belum punya akun?';
  static const toRegister = 'Daftar';

  // Register (docs/design/reference/register.png)
  static const registerTitle = 'Buat Akun Baru';
  static const registerSubtitle =
      'Mari mulai perjalanan belajar isyarat bersama';
  static const fullNameLabel = 'Nama Lengkap';
  static const fullNameHint = 'Masukkan nama lengkap Anda';
  static const registerPasswordHint = 'Buat kata sandi minimal 8 karakter';
  static const confirmPasswordLabel = 'Konfirmasi Kata Sandi';
  static const confirmPasswordHint = 'Ulangi kata sandi Anda';
  static const registerButton = 'Daftar';
  static const registerDivider = 'Atau daftar dengan';
  static const haveAccount = 'Sudah punya akun?';
  static const toLogin = 'Masuk';
}
