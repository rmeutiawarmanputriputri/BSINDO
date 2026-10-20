# BISINDO — Aplikasi Belajar Bahasa Isyarat Indonesia

Flutter + Dart (Android) · Material 3 · Supabase. Dokumen perencanaan ada di [`docs/`](docs/)
(sumber keputusan tertinggi: [`docs/IMPLEMENTATION_BRIEF.md`](docs/IMPLEMENTATION_BRIEF.md)).

> Status: **Fase 0–1** (fondasi + UI Splash/Login/Register dengan repository palsu).
> Belum terhubung ke Supabase. Lihat `docs/reports/` untuk laporan fase.

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
