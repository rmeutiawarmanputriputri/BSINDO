# Rencana BISINDO v1.1.0

Dasar: `docs/AUDIT_v1.0.md`. Prinsip: **aditif**, tidak membangun ulang, aplikasi 1.0.0 yang masih terpasang tetap berfungsi setelah migrasi diterapkan.

## 1. Keputusan yang sudah disetujui pengguna (2026-10-30)

| # | Keputusan | Jawaban |
|---|---|---|
| D-1 | Source dasar Flutter | **Source terbaru akan diunggah pengguna** (ZIP ≠ APK). Pekerjaan Flutter menunggu source tersebut |
| D-2 | Signing | "Rekomendasi terbaik" → **keystore release baru**, dibuat di komputer pengguna dengan `tool/create_keystore.ps1`; disimpan di luar repo; `key.properties` di-*ignore* |
| D-3 | CMS | **Web CMS statis (HTML/JS) + Supabase** — login Supabase Auth yang sama, keamanan ditegakkan di database (RLS + RPC `security definer` yang memeriksa `is_admin()`). Admin di dalam aplikasi **tetap dipertahankan** |
| D-4 | Premium | **Struktur + diatur manual di CMS**; webhook RevenueCat disiapkan (Edge Function) tetapi nonaktif sampai kredensial ada |

## 2. Keputusan yang masih menunggu pengguna

| # | Hal | Rekomendasi | Dampak bila tidak diputuskan |
|---|---|---|---|
| P-1 | `applicationId` `com.example.bisindo` | Ganti (mis. `id.idemusistemsinergi.bisindo`) **bersamaan** dengan ganti keystore, karena pengguna toh harus uninstall | Tidak bisa rilis di Play Store; build sideload tetap jalan |
| P-2 | Kategori bawaan kosakata vs kategori lama ("Keluarga & Teman" vs "Keluarga") | Tambahkan kategori baru sesuai daftar; kategori lama tidak diubah/dihapus | Ada dua kategori mirip; admin bisa menonaktifkan salah satunya di CMS |
| P-3 | Proyek Supabase `rwbqlhdpogeasmcmehif` = DEV atau PRODUKSI? | Uji migrasi di proyek DEV terpisah dulu | Migrasi tetap harus ditinjau sebelum dijalankan |

## 3. Pekerjaan per fase (prioritas: P1 tinggi → P3 rendah)

### Fase 3 — Database (dapat dikerjakan sekarang)
| Prioritas | Pekerjaan |
|---|---|
| P1 | Status `inactive` (enum) |
| P1 | `signs` diperluas untuk **Alfabet & Angka** tanpa tabel baru: `content_module` (`vocabulary`/`alphabet`/`number`), `symbol`, `number_group` (`0-9`, `10-20`, `tens`, `100+`), `sort_order`, `image_asset_id` (panduan visual gerakan), `audio_asset_id`, `is_premium` |
| P1 | Media audio: `media_kind` + `audio`, MIME `audio/mpeg`, `audio/mp4`, `audio/aac`, `audio/x-m4a`; kolom `title`, `description`, `status`, `original_filename`; batas ukuran per jenis dari `app_settings` (validasi trigger) |
| P1 | Pemeriksaan pemakaian media (`media_usage`) + hapus aman (`admin_delete_media`, menolak bila masih dipakai kecuali dikonfirmasi) |
| P1 | Validasi publikasi di server: `publish_issues(tipe, id)` + trigger yang menolak status `published` bila field/media wajib kosong |
| P1 | Percakapan: kalimat ditambah `translation`, `explanation`, `audio_asset_id`; modul `is_premium` |
| P1 | **Bank soal**: `questions.quiz_id` boleh NULL (soal bank), `module`, `category_id`, `difficulty`, `status`, `is_active`, `is_premium`, `video_asset_id`, `image_asset_id`; jenis soal `guess_letter`, `guess_number`, `guess_sign`, `multiple_choice`, `match_image`, `arrange_word`; `question_options` + `image_asset_id`, `side`; kunci: `correct_sequence`, `pairs`. Soal yang terikat pelajaran tetap **pilihan ganda saja** (aplikasi 1.0.0 hanya mengenal MC) |
| P1 | RPC kuis: `get_quiz_questions` (kategori / campuran / soal salah / materi sulit), `check_quiz_answer`, `submit_quiz_session` (dinilai server), tabel `quiz_sessions` (riwayat kuis baru; `quiz_attempts` lama tidak diubah) |
| P1 | Progres per materi: `sign_progress` (dipelajari, jumlah dibuka, terakhir dibuka) + RPC `mark_sign_viewed`/`set_sign_learned`; view `my_learning_history` dan `my_progress_by_category` |
| P1 | Premium: `subscriptions` (sumber `manual`/`revenuecat`), `has_premium()`, media konten Premium hanya bisa dibaca pengguna Premium/admin |
| P2 | Akun: `profiles.is_active`; kebijakan *restrictive* menolak akun nonaktif membaca konten; RPC admin `admin_list_users`, `admin_set_user_role`, `admin_set_user_active`, `admin_set_premium` |
| P2 | `banners`, `announcements` (notifikasi dalam aplikasi), `faqs`, `app_settings` |
| P2 | `admin_dashboard_stats()` (angka nyata), `admin_import` (impor massal → Draft, laporan per baris) |
| P2 | `delete_my_account()` (hapus akun mandiri — syarat Play Store) |
| P3 | Edge Function `revenuecat-webhook` (nonaktif sampai secret diisi) |

Semua dalam `supabase/migrations/0110_*.sql …` + `supabase/rollback/*.sql`, diuji di PostgreSQL 16 lokal dengan peran `anon`/`authenticated`/admin.

**Dampak ke data lama:** tidak ada data yang diubah/dihapus. Kolom baru punya default (`content_module='vocabulary'`, `is_premium=false`, `status` media `published`, `is_active=true`). Konten lama yang sudah `published` tetap tampil. Validasi publikasi hanya berlaku saat **transisi ke** `published` (data lama tidak ditolak).

### Fase 4 — Web CMS (dapat dikerjakan sekarang)
Folder `cms/`: HTML/CSS/JS tanpa *build step*, `supabase-js` di-*vendor* (tanpa CDN). Modul A–L sesuai brief. Template impor kosong di `templates/import/`. Uji: Playwright terhadap klien Supabase tiruan (UI) + uji SQL untuk semua RPC yang dipanggil CMS.

### Fase 5 — Flutter (menunggu source terbaru)
Home (banner, lanjutkan belajar, progres, rekomendasi), Alfabet (mode belajar A–Z), Angka (4 kelompok), Kosakata (kategori + cari + favorit), Percakapan (kalimat per bagian, audio, simulasi), Kuis (6 jenis, per kategori/campuran/kelemahan, riwayat), Profil & progres, pencarian global, kecepatan video 0,5/0,75/1×, cache media, notifikasi dalam aplikasi, FAQ, kunci Premium. State management & router tetap (Riverpod + go_router).

### Fase 6–8 — Uji & build
`dart format`, `flutter analyze`, `flutter test` dan `flutter build apk --release` dijalankan di komputer pengguna lewat `tool/release.ps1` (atau GitHub Actions). Versi: **`1.1.0+2`** (build 1.0.0 = versionCode 1, sesuai riwayat).

## 4. Signing (D-2)
1. `tool/create_keystore.ps1` → `%USERPROFILE%\.bisindo\bisindo-release.jks` + `android/key.properties` (di-*ignore*).
2. `build.gradle.kts`: `release` memakai `key.properties` bila ada; bila tidak ada, build release **gagal dengan pesan jelas** (tidak diam-diam memakai debug key).
3. Cadangkan `.jks` + password di 2 tempat aman. Kehilangan keystore = tidak bisa update aplikasi selamanya.

## 5. Yang tidak akan dilakukan
Mengarang materi/soal/arti BISINDO; membuat video/audio AI; seed materi palsu; menghapus fitur lama; menjalankan migrasi di produksi; menaruh service-role key di aplikasi/CMS.
