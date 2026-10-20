# Laporan Fase 0 — Fondasi proyek

**FASE:** P0 — Audit lingkungan & fondasi
**STATUS:** SEBAGIAN — kode & struktur selesai; validasi Flutter **BELUM TERVERIFIKASI** (SDK tidak dapat dipasang).
**Tanggal:** 2026-10-20 · **Cabang:** `phase/p0-foundation` (commit `463f373`)

## LINGKUNGAN (bukti dari perintah yang benar-benar dijalankan)

| Item | Status | Bukti |
|---|---|---|
| Shell & baca/tulis file | ✅ tersedia | sandbox Linux x86_64, 2 CPU, 7,8 GB RAM |
| Flutter SDK / Dart | ❌ tidak ada | `which flutter dart` → kosong |
| Unduh Flutter/Dart SDK | ❌ diblokir | proxy: `403 CONNECT storage.googleapis.com` (tempat Dart SDK diunduh) |
| pub.dev | ❌ diblokir | `403 CONNECT pub.dev` → `flutter pub get` mustahil |
| Android SDK | ❌ tidak ada, unduhan diblokir | `ANDROID_HOME` kosong; `403 CONNECT dl.google.com` |
| JDK | ✅ OpenJDK 21.0.12 | `java -version` |
| Gradle | ✅ 8.14.3 (template Android butuh 9.3.1 via wrapper) | `gradle --version` |
| Git | ✅ 2.43.0 | `git --version` |
| adb / emulator / perangkat | ❌ tidak ada | `which adb emulator` → kosong |
| GitHub (baca) | ✅ | `git ls-remote` berhasil; dipakai untuk versi paket & template Flutter |
| Supabase (CLI/MCP/URL) | ❌ tidak ada | `which supabase` kosong; `403 CONNECT supabase.com`; tidak ada URL/anon key diberikan |
| Gambar desain | ✅ terbaca (3 gambar unik) | splash 434×819, register 440×896, login 466×923 px |
| Folder proyek lama | — tidak ada | tidak ada folder yang diberikan/terhubung; proyek dibuat baru |

Flutter stable terbaru menurut tag GitHub: **3.47.7** (`refs/heads/stable` = `refs/tags/3.47.7`).

## FILE DIBUAT/DIUBAH
- `pubspec.yaml`, `analysis_options.yaml`, `.gitignore`, `env/example.json`, `README.md`
- `lib/main.dart`, `lib/app/app.dart`, `lib/app/config/env.dart`, `lib/app/config/config_error_screen.dart`
- `test/app/config/env_test.dart`, `test/app/app_boot_test.dart`
- `android/**` — dirender dari template resmi Flutter 3.47.7 (`packages/flutter_tools/templates/app`): AGP 9.1.0, Kotlin 2.4.0, Gradle 9.3.1, `applicationId = com.example.bisindo` (TODO K-05), label "BISINDO", izin INTERNET
- `docs/*.md` (10 dokumen), `docs/design/reference/{splash,register,login}.png`
- Folder kosong sesuai arsitektur §3 (berisi `.gitkeep`)

## VERSI DEPENDENSI (dari tag rilis GitHub; pub.dev tak terjangkau)
| Paket | Versi | Catatan |
|---|---|---|
| supabase_flutter | ^2.18.3 | 3.0.0 masih `-dev` → tidak dipakai |
| flutter_riverpod | ^3.4.3 | Riverpod 3: `StateProvider` pindah ke `legacy.dart`; kode memakai `Notifier` |
| go_router | ^18.1.0 | butuh Flutter ≥ 3.44, Dart ^3.12 |
| flutter_svg | ^2.3.0 | |
| intl | ^0.20.2 | |
| flutter_lints (dev) | ^6.0.0 | |
| mocktail (dev) | ^1.0.4 | |
| flutter_native_splash (dev) | ^2.4.7 | |

## PERINTAH DIJALANKAN & VALIDASI
| Kriteria | Status | Keterangan |
|---|---|---|
| `flutter doctor -v` | ⚠️ TIDAK DIJALANKAN | SDK tidak ada |
| `flutter pub get` | ⚠️ TIDAK DIJALANKAN | pub.dev diblokir |
| `flutter analyze` | ⚠️ TIDAK DIJALANKAN | SDK tidak ada |
| `flutter test` (2 berkas, 6 tes) | ⚠️ TIDAK DIJALANKAN | SDK tidak ada |
| `flutter build apk --debug` | ⚠️ TIDAK DIJALANKAN | SDK + Android SDK tidak ada |
| Cek sintaks Dart (tree-sitter-dart, **bukan** analyzer) | ✅ DIJALANKAN & LULUS | `6 berkas diperiksa, 0 dengan kesalahan parse` — pemeriksa terbukti mendeteksi berkas rusak (uji negatif) |
| YAML/JSON valid | ✅ DIJALANKAN & LULUS | `pubspec.yaml`, `analysis_options.yaml`, `env/example.json` |
| AndroidManifest XML valid | ✅ DIJALANKAN & LULUS | `xmllint --noout` |
| `.gitignore` menutup `env/dev.json` | ✅ DIJALANKAN & LULUS | `git check-ignore` → `.gitignore:44:env/*.json` |
| Pemindaian rahasia (BLD-05) | ✅ DIJALANKAN & LULUS | `git grep service_role|eyJhbGci|sb_secret` → 0 temuan di luar `docs/` |
| Git: commit awal + cabang `phase/p0-foundation` | ✅ | `06667af`, `463f373` |

## DEVIASI DARI SPESIFIKASI
1. `flutter create` tidak dijalankan → `android/` dirender manual dari template resmi 3.47.7. Gradle wrapper (`gradlew`, `.jar`) belum ada; README menginstruksikan `flutter create . --platforms android` (hanya menambah berkas yang hilang).
2. `RECORD_AUDIO`, `<queries>` RecognitionService, dan deep link belum ditambahkan ke manifest (sesuai roadmap: P3/P8). Ditandai TODO di manifest.

## HAMBATAN & KEPUTUSAN YANG SAYA BUTUHKAN
- **Validasi Flutter**: harus dijalankan oleh Anda (perintah di bawah) **atau** sesi ini ditautkan ke komputer Anda yang punya Flutter.
- K-01…K-05: default dipakai (lihat laporan Fase 1).

## RISIKO BARU
- R-P0-1: Versi paket dipilih dari tag GitHub tanpa resolusi pub; ada kemungkinan konflik versi → jalankan `flutter pub get`; bila gagal, `flutter pub upgrade --major-versions` dan laporkan.
- R-P0-2: Kode belum pernah dikompilasi; kesalahan tipe/API hanya akan terlihat saat `flutter analyze`.

## PERINTAH UNTUK ANDA JALANKAN (bukti P0)
```bash
flutter --version && flutter doctor -v
flutter create . --project-name bisindo_app --org com.example --platforms android
git status   # pastikan berkas yang sudah ada tidak berubah
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter build apk --debug
```
