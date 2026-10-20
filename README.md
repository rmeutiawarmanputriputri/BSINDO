# BISINDO — Aplikasi Belajar Bahasa Isyarat Indonesia

Flutter + Dart (Android) · Material 3 · Supabase. Dokumen perencanaan ada di [`docs/`](docs/)
(sumber keputusan tertinggi: [`docs/IMPLEMENTATION_BRIEF.md`](docs/IMPLEMENTATION_BRIEF.md)).

> Status: **MVP lengkap (Fase 0–11) + persiapan uji (12–13).** Laporan: `docs/reports/FINAL_REPORT.md`,
> batasan: `docs/KNOWN_ISSUES.md`, setup backend: `docs/SUPABASE_SETUP.md`.

## Cara tercepat (Windows)
```powershell
cd bisindo_app
powershell -ExecutionPolicy Bypass -File tool\setup.ps1   # flutter create + pub get + env\dev.json
# isi env\dev.json (URL + anon key Supabase DEV), terapkan supabase\setup_all.sql
powershell -ExecutionPolicy Bypass -File tool\check.ps1   # analyze, test, golden, build APK → logs\
```
Error Gradle "Could not read workspace metadata" → `tool\fix_gradle.ps1`.
Tanpa Gradle lokal: push ke GitHub → Actions → unduh artifact **bisindo-debug-apk**.

## Prasyarat
- Flutter stable 3.47.x (Dart ≥ 3.12) — `flutter --version`
- Android SDK (compileSdk 36), JDK 17+
- Perangkat/emulator Android

## Menyiapkan proyek pertama kali
Folder `android/` dibuat dari template Flutter 3.47.7 tanpa menjalankan `flutter create`,
jadi berkas pendukung (gradle wrapper, `local.properties`) belum ada. Jalankan sekali:

```bash
flutter create . --project-name bisindo_app --org com.example --platforms android
```
Perintah ini **hanya menambah berkas yang belum ada**; berkas yang sudah ada tidak ditimpa.
Periksa `git status` sesudahnya — jika ada berkas lain yang berubah, kembalikan dengan `git checkout -- <berkas>`.

## Konfigurasi
```bash
cp env/example.json env/dev.json   # isi SUPABASE_URL + SUPABASE_ANON_KEY proyek DEV
```
`env/*.json` (kecuali `example.json`) di-*gitignore*. **Jangan pernah** memasukkan service role key.
Tanpa konfigurasi, aplikasi menampilkan layar "Konfigurasi aplikasi belum lengkap" (tidak crash).

## Menjalankan
```bash
flutter pub get
flutter run --dart-define-from-file=env/dev.json
```

## Validasi
```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test --exclude-tags golden
flutter test --update-goldens test/goldens   # sekali, membuat baseline golden (lalu `flutter test` penuh)
flutter build apk --debug --dart-define-from-file=env/dev.json
```

## Struktur
Feature-first (`lib/features/<fitur>/{data,domain,presentation}`), token desain di
`lib/app/theme/tokens.dart`, komponen bersama di `lib/core/widgets/`. Detail: `docs/FLUTTER_ARCHITECTURE.md`.

## Font
Inter 4.1 (SIL Open Font License 1.1) dibundel di `assets/fonts/` — lisensi di `assets/fonts/OFL.txt`.
