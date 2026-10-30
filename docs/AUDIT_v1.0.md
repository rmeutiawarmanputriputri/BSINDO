# Audit Source & APK Lama — BISINDO (sebelum v1.1.0)

Tanggal audit: 2026-10-30 · Auditor: Claude (sesi cloud) · Cabang kerja: `release/1.1.0-wip`

Bahan yang diaudit:
1. `bisindo_app_lengkap.zip` → repo git `bisindo_app` (cabang `phase/p3-p11-features`, commit `08cf1cb`), diberi tag `baseline-zip-v0.1.0`.
2. `BISINDO.apk` (28,5 MB) yang dibangun dan dipasang di HP pengguna.

---

## 0. TEMUAN KRITIS — APK dibangun dari source yang berbeda dari ZIP

| Bukti | ZIP | APK |
|---|---|---|
| Versi | `pubspec.yaml`: `0.1.0+1` | `versionName 1.0.0`, `versionCode 1` |
| Berkas Dart | 129 berkas | Ada berkas yang **tidak ada di ZIP**, dibaca dari tabel simbol `libapp.so` (lihat di bawah) |
| Beranda | `features/home/home_screen.dart` | **tidak ada**, digantikan fitur `communication` |
| Paket | `file_picker`, `permission_handler` | **tidak dipakai**; ada `shared_preferences`, `url_launcher`, `app_links`, `jni` |
| Logo | `assets/brand/` kosong (.gitkeep) | `logo_splash.svg`, `logo_login.svg`, `logo_register.svg` |

Berkas yang hanya ada di APK: `app/shell/help_sheet.dart`, `core/supabase/safe_session_storage.dart`, `core/widgets/main_top_bar.dart`, `features/admin/data/media_picker.dart`, `features/communication/{domain/quick_phrases, presentation/communication_controller, communication_screen, fullscreen_message_screen}.dart`, `features/dictionary/presentation/sign_visuals.dart`, `features/transcription/presentation/listen_panel.dart`.

**Konsekuensi:** kode Dart tidak dapat dipulihkan dari APK (AOT). Membangun v1.1.0 dari ZIP akan **menghilangkan fitur** yang sedang dipakai pengguna (melanggar aturan 6). Pengguna sudah diminta mengunggah source terbaru. Pekerjaan database, CMS, dan dokumen tetap berjalan karena tidak bergantung pada kode Flutter.

## 1. Informasi APK 1.0.0 (androguard)

| Item | Nilai |
|---|---|
| Package / applicationId | `com.example.bisindo` (sementara; Play Store menolak `com.example.*`) |
| versionName / versionCode | 1.0.0 / 1 |
| minSdk / targetSdk | 24 / 36 |
| **Tanda tangan** | **APK Signature v2, sertifikat `CN=Android Debug`** (SHA-256 `9353E79D…A83BC2`) → bukan keystore release |
| ABI | `libapp.so` & `libflutter.so` hanya `arm64-v8a` |
| Izin | INTERNET, ACCESS_NETWORK_STATE, WAKE_LOCK, RECORD_AUDIO |
| Supabase URL tertanam | `https://rwbqlhdpogeasmcmehif.supabase.co` (kunci *publishable*, bukan secret) |
| Secret di APK | `service_role` / `sb_secret` / JWT service: **tidak ditemukan** |

Dampak signing: update di HP pengguna hanya mungkin dengan kunci debug yang sama (ada di `~/.android/debug.keystore` pada komputer yang membangun 1.0.0). Keputusan v1.1.0: keystore release baru (lihat PLAN §4).

## 2. Lingkungan kerja sesi ini

| Alat | Status |
|---|---|
| Flutter / Dart SDK | ❌ tidak ada; unduhan `storage.googleapis.com`, `pub.dev` diblokir proxy (403) |
| Android SDK / Gradle Maven repo | ❌ `dl.google.com`, `maven.google.com`, `repo.maven.apache.org` diblokir |
| JDK | ✅ OpenJDK 21 |
| PostgreSQL | ✅ 16.15 (dipakai untuk uji migrasi & RLS) |
| PostgREST, Supabase CLI, Docker image | ❌ GitHub release & Docker registry diblokir |
| Node 22 + npm registry | ✅ (untuk CMS & Playwright) |
| PHP 8 / Composer | ✅ terpasang, packagist diblokir (tidak dibutuhkan; CMS memakai Supabase) |
| Proyek Supabase pengguna | ❌ tidak dapat dijangkau dari sesi ini (dan memang tidak boleh disentuh langsung) |
| Komputer/HP pengguna | ❌ sesi tidak tertaut ke komputer pengguna |

→ `flutter analyze`, `flutter test`, dan `flutter build apk` pada kode lama **tidak dapat dijalankan di sini** (status: *Tidak bisa diuji — SDK diblokir*). Laporan lama (`docs/reports/FINAL_REPORT.md`) juga menyatakan hal yang sama, tetapi APK 1.0.0 terbukti berhasil dibangun di komputer pengguna.

## 3. Struktur proyek (ZIP)

- Flutter `>=3.47`, Dart `^3.12`; arsitektur *feature-first* (`lib/app`, `lib/core`, `lib/features/*/{data,domain,presentation}`).
- State: **flutter_riverpod 3.4** tanpa codegen. Router: **go_router 18** (`StatefulShellRoute`, 5 tab: Beranda, Kamus, Percakapan, Belajar, Profil). Konfigurasi lewat `--dart-define-from-file=env/dev.json`.
- Dependency: `supabase_flutter 2.18.3`, `video_player 2.14.1`, `speech_to_text 7.3.0`, `permission_handler 13.0.2`, `file_picker 11.0.3`, `flutter_svg`, `intl`. Catatan pubspec: "BELUM TERVERIFIKASI dengan flutter pub get".
- Tes: 20 berkas tes Flutter (unit + widget + golden), 30 uji RLS SQL, 47 uji query PostgREST.
- CI: `.github/workflows/android.yml` (analyze, test, build APK debug). Skrip Windows: `tool/setup.ps1`, `check.ps1`, `fix_gradle.ps1`.
- Android: Kotlin DSL; `release` ditandatangani `signingConfigs.debug`; deep link `bisindo://auth-callback`.
- `.gitignore` sudah mengecualikan `env/*.json`, `.env*`, `*.jks`, `*.keystore`, `key.properties`.

## 4. Backend / CMS

- **Tidak ada backend PHP / CMS web.** Pengelolaan konten dilakukan oleh **Admin di dalam aplikasi Flutter** (`features/admin`): dashboard, CRUD kosakata/kategori/modul percakapan/pelajaran/kuis, unggah media, tinjau laporan. Guard admin di router + RLS `is_admin()` di database.
- Satu sistem login: **Supabase Auth** (email + sandi, verifikasi email, reset sandi).

## 5. Database Supabase (migrasi 0001–0010)

| Tabel | Fungsi |
|---|---|
| `profiles` (role `user`/`admin`) | profil; dibuat trigger, role tidak bisa diubah klien |
| `categories` (`kind` sign/conversation) | kategori kamus & percakapan |
| `media_assets` (video/gambar, ≤20 MB) | metadata media; berkas di bucket privat `bisindo-media` |
| `signs` | kosakata/frasa (term, arti, deskripsi gerakan, contoh, video, thumbnail, sumber & validator) |
| `conversation_modules`, `conversation_items` | modul percakapan & kalimat berurutan |
| `lessons`, `lesson_items`, `quizzes`, `questions`, `question_options`, `question_answer_keys` | pelajaran + kuis pilihan ganda (kunci jawaban tertutup) |
| `quiz_attempts` | riwayat kuis (ditulis RPC `submit_quiz_attempt`, dinilai server) |
| `user_progress` | progres per pelajaran/modul |
| `favorites`, `difficult_vocabulary`, `content_reports` | data pribadi pengguna |

- Status konten: enum `draft, in_review, verified, published, archived`. Publikasi wajib `validated_by`, `verified_at`, `source_note` (CHECK).
- RLS aktif di **semua** tabel, default deny, pengguna hanya membaca data miliknya; admin melalui `is_admin()` (membaca tabel `profiles`, bukan JWT).
- Storage: bucket privat, baca via `can_read_media()` (hanya media konten published), tulis hanya admin.
- RPC: `submit_quiz_attempt`, `touch_progress`, `admin_dashboard_counts`.
- Seed: `00_categories.sql` (16 kategori struktural), `10_dev_samples.sql` (**khusus DEV**, "Contoh 1–5" berlabel `DEV-SAMPLE`).

**Verifikasi ulang di sesi ini:** migrasi 0001–0010 diterapkan ke PostgreSQL 16 + stub Supabase → **berhasil**; `10_rls_tests.sql` → **30/30 LULUS**.

## 6. Status fitur (berdasarkan source ZIP; APK berbeda — lihat §0)

| Fitur | Status | Catatan |
|---|---|---|
| Login/daftar/lupa sandi/verifikasi email | Berfungsi (terbukti di APK) | |
| Kamus kosakata + pencarian + filter kategori | Berfungsi | |
| Detail isyarat + video (0,5×, loop, layar penuh) | Berfungsi | kecepatan hanya 0,5×/1× |
| Favorit, kosakata sulit | Berfungsi | |
| Percakapan (modul + kalimat) | Berfungsi | tanpa audio, tanpa terjemahan/penjelasan per kalimat |
| Pelajaran + kuis pilihan ganda | Berfungsi | hanya MC, terikat pelajaran |
| Transkripsi suara → teks | Berfungsi (bergantung layanan perangkat) | |
| Laporan konten | Berfungsi | |
| Admin dalam aplikasi | Berfungsi | tanpa audio, tanpa impor massal, tanpa banner/premium |
| Beranda | Ada di ZIP, **diganti "Komunikasi" di APK** | |
| Alfabet A–Z, Angka | **Belum ada** | |
| Kuis per kategori/campuran/latihan kelemahan, jenis soal lain | **Belum ada** | |
| Audio/voice | **Belum ada** (media_kind hanya video/image) | |
| Banner beranda, Premium, notifikasi, FAQ | **Belum ada** | |
| Progres per materi (huruf/kosakata dipelajari), riwayat belajar | **Belum ada** (hanya per pelajaran/modul) | |
| Status `inactive` | **Belum ada** | |
| CMS web | **Belum ada** | |
| Hapus akun (wajib Play Store) | **Belum ada** | KNOWN_ISSUES K-10 |

## 7. Hasil `flutter analyze` / `flutter build apk --debug` pada kode lama

**Tidak bisa diuji di sesi ini** (SDK diblokir, lihat §2). Untuk APK 1.0.0, build terbukti berhasil di komputer pengguna.

## 8. Daftar risiko

| # | Risiko | Dampak | Mitigasi |
|---|---|---|---|
| R1 | Source ZIP ≠ source APK | Fitur pengguna hilang | Tunggu source terbaru; pekerjaan Flutter ditunda |
| R2 | APK lama ditandatangani debug key | Update butuh uninstall jika ganti kunci | Keystore release baru + komunikasi ke pengguna; progres aman di server |
| R3 | `com.example.bisindo` | Ditolak Play Store | Perlu keputusan pengguna (ganti applicationId = aplikasi baru) |
| R4 | Aplikasi 1.0.0 tetap dipakai setelah migrasi | Perubahan skema bisa merusak aplikasi lama | Semua migrasi v1.1.0 **aditif**; tidak ada kolom yang dihapus/diganti nama; kuis bank & riwayat sesi memakai tabel/kolom baru yang tidak dibaca 1.0.0 |
| R5 | Tidak ada Flutter SDK di sesi | Kode Flutter tidak bisa dikompilasi di sini | Build & uji di komputer pengguna / GitHub Actions; laporan jujur |
| R6 | Tidak ada PostgREST/Supabase lokal | Uji API end-to-end terbatas | Uji SQL dengan peran & klaim JWT asli (`set role authenticated`), uji UI CMS dengan Playwright |
| R7 | Batas unggah 20 MB | Video panjang gagal | Batas dapat dikonfigurasi (tabel `app_settings`, bucket ≤ 50 MB) |
| R8 | Belum ada hapus akun & kebijakan privasi | Syarat Play Store | Dicatat di laporan akhir |
| R9 | Seed `10_dev_samples.sql` tidak boleh ke produksi | Data contoh tampil | Pemeriksaan pra-rilis di CMS_SETUP |
