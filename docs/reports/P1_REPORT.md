# Laporan Fase 1 — Design system + UI Splash/Login/Register

**FASE:** P1 — Design system + UI Splash/Login/Register (tanpa backend)
**STATUS:** SEBAGIAN — kode lengkap; **BELUM TERVERIFIKASI** dengan Flutter (SDK tidak tersedia; dilanjutkan atas persetujuan pemilik 2026-10-20).
**Cabang:** `phase/p1-auth-ui` (bercabang dari `phase/p0-foundation`)

## LINGKUNGAN
Sama dengan P0: tidak ada Flutter/Dart/Android SDK/emulator; pub.dev & storage.googleapis.com diblokir. Tersedia: shell, GitHub (baca), gcc, Node. Gambar referensi terbaca.

## FILE DIBUAT/DIUBAH
**Tema & token**: `lib/app/theme/tokens.dart` (satu-satunya tempat nilai desain), `app_theme.dart`, `text_theme.dart`
**Konfigurasi/router**: `lib/app/config/feature_flags.dart` (`enableSocialAuth=false`), `lib/app/router/routes.dart`, `lib/app/router/app_router.dart`, `lib/app/app.dart` (diubah: tema + router)
**Inti**: `lib/core/errors/{app_failure,failure_message}.dart`, `lib/core/utils/validators.dart`
**Komponen** (`lib/core/widgets/`): `app_button.dart`, `app_text_field.dart`, `password_field.dart`, `auth_card.dart`, `auth_scaffold.dart`, `auth_error_banner.dart`, `social_buttons.dart` (tidak dirender, flag), `state_views.dart`, `brand_logo.dart` (placeholder K-01)
**Fitur auth**: `lib/features/auth/domain/sign_up_result.dart`, `data/{auth_repository,fake_auth_repository}.dart`, `presentation/controllers/{submit_state,login_controller,register_controller}.dart`, `presentation/auth_strings.dart`, `presentation/screens/{splash,login,register}_screen.dart`, `presentation/widgets/{auth_header,auth_footer_link}.dart`
**Aset**: `assets/fonts/Inter-{Regular,Medium,SemiBold,Bold,ExtraBold}.ttf` + `OFL.txt` (Inter 4.1 resmi dari github.com/rsms/inter, SIL OFL 1.1)
**Android**: `res/values/colors.xml`, `res/values-v31/styles.xml`, `res/values-night-v31/styles.xml`, `res/drawable{,-v21}/launch_background.xml` (latar splash native #1C45B9)
**pubspec.yaml**: fonts, konfigurasi `flutter_native_splash`, batas Flutter ≥ 3.47.0
**Tes**: `test/helpers/pump_auth_app.dart`, `test/core/utils/validators_test.dart`, `test/core/errors/failure_message_test.dart`, `test/features/auth/{auth_controllers,login_screen,register_screen,splash_screen,auth_responsive_a11y}_test.dart`, `test/goldens/{auth_golden_test,flutter_test_config}.dart`, `test/app/app_boot_test.dart` (diubah), `dart_test.yaml`

## ANALISIS GAMBAR vs AUTH_UI_DESIGN_SPEC §1–3
Warna diukur dengan color picker (Python/Pillow) pada gambar:

| Elemen | Estimasi dokumen | Terukur di gambar | Dipakai |
|---|---|---|---|
| Latar Splash | #1C44B7 | #1C45B9 | #1C45B9 |
| Tombol utama | #1B57CF | #1A56CF (login), #1A55C5 (register) | #1A56CF |
| Gradien atas | #DCE8FF | #E6EFFC (login), #E5EBFD (register) | #E6EFFC — **gambar lebih terang dari dokumen; mengikuti gambar (hierarki §0)** |
| Gradien bawah | #F8FAFF | #F9FAFE | #F9FAFE |
| Isi input | #EEF2F7 | #EDF3FA–#F0F4F7 | #EEF2F7 |
| Placeholder | #9AA5B5 | #8C949B–#929AA1 | #5A6A82 (deviasi A-1) |
| Subjudul | #64748B | ≈ #59606C | #475569 (deviasi A-2) |

[KONFIRMASI] tidak terbaca pasti dari gambar: nama font asli (K-04); ukuran px persis (skala tiap gambar berbeda); apakah teks "BISINDO" di Login/Register bagian dari logo atau teks; jarak huruf "BISINDO" Register (tampak lebih rapat dari Login → dipakai 0 vs 2).

**Kontras (dihitung, rumus WCAG 2.x — A11Y-04)**: putih/primary 6,41:1 ✅ · putih/brandDeep 8,07:1 ✅ · placeholder baru #5A6A82/inputFill 4,89:1 ✅ (gambar 2,54:1 ❌) · textSecondary/gradien atas 6,54:1 ✅ · tautan primary/gradien atas 5,53:1 ✅ · error/errorContainer 5,72:1 ✅ · outline #CBD5E1 1,48:1 (hanya garis dekoratif).

## PERINTAH DIJALANKAN & VALIDASI
| Kriteria | Status | Bukti / alasan |
|---|---|---|
| `flutter analyze` | ⚠️ TIDAK DIJALANKAN | SDK tidak ada |
| `flutter test` (10 berkas tes, ±56 kasus termasuk 4 golden) | ⚠️ TIDAK DIJALANKAN | SDK tidak ada |
| `flutter build apk --debug` | ⚠️ TIDAK DIJALANKAN | SDK + Android SDK tidak ada |
| Golden 2 ukuran (AUTH-11) | ⚠️ TIDAK DIJALANKAN | baseline belum ada; perlu `flutter test --update-goldens test/goldens` |
| Tangkapan layar berdampingan dengan gambar | ⚠️ TIDAK DIJALANKAN | tidak ada emulator/perangkat; **saya tidak mengklaim "sesuai desain"** — lihat perbandingan manual di bawah |
| Cek sintaks Dart (tree-sitter-dart terbaru, dibangun native) | ✅ DIJALANKAN & LULUS | `46 berkas diperiksa, 0 dengan kesalahan parse`; uji negatif menangkap berkas rusak; grammar mendukung pola Dart 3 |
| Review statis independen (subagent) terhadap source asli Flutter 3.47.7, Riverpod 3.4.3, go_router 18.1.0, lints 6.0.0 | ✅ DIJALANKAN | 0 compile error ditemukan; 1 info lint, 3 temuan runtime → **sudah diperbaiki** (lihat RISIKO) |
| pubspec/XML valid, aset font ada | ✅ DIJALANKAN & LULUS | PyYAML, `xmllint`, cek path |
| Pemindaian rahasia | ✅ DIJALANKAN & LULUS | 0 temuan |

### Kriteria AUTH_UI_DESIGN_SPEC §9
| # | Kriteria | Status |
|---|---|---|
| 1 | Perbandingan berdampingan dengan gambar | ⚠️ belum bisa (tanpa render). Perbandingan manual kode vs gambar di bawah |
| 2 | Tanpa overflow 360×640 @ 200% | ⚠️ tes ditulis (`auth_responsive_a11y_test.dart`, skala 1.0/1.3/2.0 + kondisi semua error), belum dijalankan |
| 3 | Keyboard tidak menutup field/tombol | ⚠️ `resizeToAvoidBottomInset`, scroll, `scrollPadding`; tes `ensureVisible`; uji keyboard nyata butuh perangkat |
| 4 | Target sentuh ≥ 48dp; label TalkBack | ⚠️ tes `androidTapTargetGuideline` + `labeledTapTargetGuideline` + label semantik ditulis; TalkBack manual butuh perangkat |
| 5 | Golden Login & Register 2 ukuran | ⚠️ tes ditulis (360×640, 411×891), baseline belum ada |

### Perbandingan manual (kode ↔ gambar)
Sama: urutan elemen (logo → BISINDO → [judul/subjudul] → kartu → footer), gradien vertikal, kartu putih radius 24 + bayangan lembut, input terisi tanpa border, label tebal di atas, placeholder & label persis, "Lupa Kata Sandi?" biru tebal rata kanan, tombol pill biru penuh + panah, footer tautan silang di dasar layar, panah kembali kiri-atas (Register), judul Login rata kiri / judul Register rata tengah, Splash biru solid + wordmark putih sedikit di atas tengah.
Berbeda: lihat DEVIASI.

## DEVIASI DARI SPESIFIKASI / GAMBAR (semua menunggu keputusan Anda)
| # | Deviasi | Alasan | Cara mengembalikan |
|---|---|---|---|
| 1 | 🕓 **K-01** Ikon logo = ikon Material generik `sign_language` (bukan logo); "BISINDO" = teks Inter ExtraBold; Splash tanpa ikon tangan | Aset resmi belum ada; dilarang menggambar ulang logo | Taruh SVG di `assets/brand/`, ganti `brand_logo.dart` |
| 2 | 🕓 **K-02** Login memakai ikon mata, bukan switch | Konsisten dengan Register | `kLoginPasswordToggleStyle = PasswordToggleStyle.switchToggle` (`password_field.dart`) |
| 3 | 🕓 **K-03** Tombol Google/Facebook/Apple **dan** pembatas "Atau masuk/daftar dengan" disembunyikan | Tidak berfungsi di MVP; tanpa tombol palsu. Pembatas ikut disembunyikan karena tanpa tombol ia menggantung | `--dart-define=ENABLE_SOCIAL_AUTH=true` + isi `SocialButtonRow` setelah integrasi nyata |
| 4 | 🕓 A-4 Tinggi input 52dp, tombol utama 52dp (gambar ≈ 36–45 px) | Target sentuh, konsistensi | `AppSizes` di `tokens.dart` |
| 5 | 🕓 A-1 Placeholder #5A6A82 (gambar ≈ #929AA1) | Kontras 2,54 → 4,89:1 | `AppColors.textPlaceholder` |
| 6 | 🕓 A-2 Subjudul #475569 (gambar ≈ #59606C/#64748B) | Keterbacaan | `AppColors.textSecondary` |
| 7 | 🕓 I-4 Tombol "Masuk" = teks tebal + ikon panah (gambar Login: panah karakter teks biasa) | Disamakan dengan "Daftar →" | `AppButton(trailingArrow:)` |
| 8 | 🕓 A-7 Tautan footer & "Lupa Kata Sandi?" punya area sentuh 48dp | Aksesibilitas; visual sama | — |
| 9 | Font Inter (dibundel) | K-04 default | `kAppFontFamily` + pubspec |
| 10 | Gradien atas #E6EFFC (dokumen: #DCE8FF) | Mengikuti gambar (otoritas visual tertinggi) | `AppColors.bgGradientTop` |
| 11 | Elemen baru tanpa desain asli: banner error server, teks error (ikon + teks) di bawah field, tombol loading "Memproses…" | Disyaratkan AUTH spec §6–7 | — |
| 12 | "Lupa Kata Sandi?" menampilkan snackbar "belum tersedia — Fase 3"; submit sukses menampilkan snackbar "Mode pengembangan … repository palsu" (tanpa navigasi) | Fitur/halaman tujuan belum ada; tidak boleh disamarkan sebagai selesai | Diganti di P3/P4 |
| 13 | Ukuran logo: Login 56dp, Register 32dp, mengecil di layar pendek (clamp 0,75–1) | I-5 [KONFIRMASI] | `AppSizes.loginLogo/registerLogo` |

## HAMBATAN & KEPUTUSAN YANG SAYA BUTUHKAN
- Jalankan validasi (perintah di bawah) dan kirim keluarannya; saya perbaiki error yang muncul sebelum Fase 2.
- 🕓 K-01 (aset logo SVG/PNG), K-02, K-03, K-04 (hex & font resmi), K-05 (nama & applicationId), deviasi #4–#8 dan #13.

## RISIKO BARU
- **R-P1-1 (ditemukan & ditangani):** go_router 18 bergantung pada paket baru `material_ui` dan mendeteksi `MaterialApp` milik paket itu, bukan `package:flutter/material`. Tanpa penanganan, semua transisi halaman menjadi instan (`NoTransitionPage`). Ditangani dengan `pageBuilder: MaterialPage(...)` eksplisit. Alternatif: pin `go_router: ^17.5.0`. Juga menaikkan syarat Flutter ke ≥ 3.47.0.
- **R-P1-2 (ditangani):** tema global FilledButton sempat memaksa semua FilledButton lebar penuh & menimpa warna tonal → dipindah ke `AppButton`.
- **R-P1-3:** Menu konteks teks (Salin/Tempel) masih berbahasa Inggris karena `flutter_localizations` belum ditambahkan (perlu persetujuan dependensi; usul P3).
- **R-P1-4:** Tes golden gagal sampai baseline dibuat; golden bergantung OS.
- **R-P1-5:** `dart format --set-exit-if-changed` kemungkinan melaporkan perubahan (±26 baris > 80 kolom, format switch) → jalankan `dart format .` sekali.
- **R-P1-6:** Android 12+ selalu menampilkan ikon launcher di splash sistem (ikon Flutter default sampai K-01).

## PERINTAH UNTUK ANDA JALANKAN
```bash
flutter create . --project-name bisindo_app --org com.example --platforms android
git status                      # pastikan berkas lama tidak berubah
flutter pub get
dart format .                   # rapikan format (lihat R-P1-5)
flutter analyze
flutter test --exclude-tags golden
flutter test --update-goldens test/goldens   # buat baseline, periksa PNG-nya
cp env/example.json env/dev.json             # isi URL https apa pun bila belum punya Supabase
flutter build apk --debug --dart-define-from-file=env/dev.json
flutter run --dart-define-from-file=env/dev.json   # bandingkan dengan docs/design/reference/*.png
```
Email pemicu skenario palsu: `salah@contoh.com`, `belum@contoh.com`, `terdaftar@contoh.com`, `offline@contoh.com`.

## LANGKAH BERIKUTNYA (usulan, belum dimulai)
**Fase 2 — Backend baseline Supabase:** migrasi `0001_extensions_types.sql`, `0002_profiles_auth.sql`, bagian `profiles` dari 0007; `docs/SUPABASE_SETUP.md` (konfigurasi Auth, redirect `bisindo://auth-callback`, bootstrap admin). Karena saya tidak punya akses Supabase, keluaran P2 berupa berkas SQL + panduan manual berstatus "BELUM DITERAPKAN", kecuali Anda menjalankannya di SQL Editor proyek dev dan mengirim hasilnya. RLS-05/06/07 diuji dengan skrip SQL yang saya siapkan.
