# Laporan Uji BISINDO v1.1.0

Status dokumen: final untuk sesi ini. Bagian yang butuh perangkat/SDK Android ditandai **Tidak bisa diuji** beserta alasannya.
Lingkungan uji: sesi cloud Linux, PostgreSQL 16.15 lokal + stub Supabase, Node 22, Chromium (Playwright). **Tidak ada** Flutter/Android SDK (diblokir), tidak ada akses ke proyek Supabase asli, dan tidak ada perangkat Android.

Bukti mentah ada di `docs/test-logs/`.

## 1. Teknis — Database (migrasi 0110–0120)

| # | Uji | Status | Bukti |
|---|---|---|---|
| D-1 | Migrasi 0001–0120 diterapkan berurutan ke DB baru | **Lulus** | `run_v110.sh` §1 |
| D-2 | Seed struktur `20_v110_struktur.sql` idempoten (27 kategori, 9 topik Draft) | **Lulus** | §1 |
| D-3 | Kompatibilitas aplikasi 1.0.0: uji RLS lama `10_rls_tests.sql` pada skema v1.1.0 | **Lulus 30/30** | `db_10_rls_legacy.txt` |
| D-4 | Uji v1.1.0 `20_v110_tests.sql` | **Lulus 80/80** | `db_20_v110.txt` |
| D-5 | Rollback 0120→0110 mengembalikan skema setara 0001–0010 | **Lulus** (selisih hanya 2 nilai enum, terdokumentasi) | `db_rollback.diff` |
| D-6 | Pemetaan event webhook RevenueCat | **Lulus 8/8** | `revenuecat_mapping.txt` |
| D-7 | Migrasi pada proyek Supabase asli | **Tidak bisa diuji** — proyek tidak terjangkau dari sesi; wajib dijalankan pemilik di DEV dulu | — |
| D-8 | Edge Function `revenuecat-webhook` di runtime Deno | **Tidak bisa diuji** — Deno/Supabase CLI tidak tersedia; logika murni diuji (D-6) | — |

Cakupan 80 uji v1.1.0 meliputi:
- status `inactive` dan publikasi;
- validasi publikasi alfabet/angka/kosakata/percakapan/soal;
- regresi (melepas video dari materi published ditolak);
- MIME/ukuran media dan batas yang dapat dikonfigurasi;
- `can_read_media` untuk audio/gambar/Premium/akun nonaktif, termasuk policy Storage;
- Premium: klien tidak bisa menulis, kedaluwarsa mencabut akses;
- 12 RPC admin ditolak untuk pengguna biasa; role tidak bisa dinaikkan sendiri;
- progres per materi dan isolasi antar akun;
- kuis: kunci tertutup, 6 jenis soal dinilai server, mode campuran/kelemahan, Premium;
- banner, pengumuman, FAQ, setting;
- pemakaian dan hapus aman media, ganti berkas;
- impor dry-run/nyata/error per baris;
- hapus akun mandiri (admin terakhir dilindungi);
- penolakan untuk anon.

## 2. CMS (E2E: Chromium → supabase-js 2.76.1 → emulator API lokal → PostgreSQL dengan migrasi asli)

**36/36 Lulus** (`cms_e2e.txt`, tangkapan layar di `cms_screenshots/`).

| Area | Uji | Status |
|---|---|---|
| Akses | Pengguna biasa ditolak masuk CMS; sandi salah; admin masuk | Lulus |
| Dashboard | Angka dari query nyata; berubah setelah aksi | Lulus |
| Media | Unggah video (progres), audio, gambar; format salah ditolak; batas ukuran dari Pengaturan; pratinjau (signed URL); ganti berkas (id tetap, berkas lama dihapus); hapus media terpakai → peringatan + daftar pemakaian; paksa hapus media wajib materi Published → ditolak server; hapus media tak terpakai | Lulus |
| Alfabet / Angka / Kosakata | CRUD; publish tanpa video/field wajib → daftar kekurangan; publish lengkap; ubah status cepat | Lulus |
| Percakapan | Topik + kalimat, ubah urutan, audio per kalimat, validasi & publish | Lulus |
| Kuis | Tebak huruf (MC + video), susun kata, cocokkan gambar; kunci tersimpan | Lulus |
| Impor | CSV titik koma + BOM + kutip; pratinjau; validasi tanpa menyimpan; impor → Draft; error per baris; template kosong | Lulus |
| Kategori | Tambah, slug otomatis, urutan, nonaktifkan | Lulus |
| Pengguna / Premium | Detail, set Premium manual, nonaktifkan akun, admin tidak bisa menonaktifkan diri; info paket | Lulus |
| Banner / Pengumuman / FAQ / Pengaturan | CRUD + validasi | Lulus |
| Keamanan | Token pengguna biasa ditolak di RPC admin, insert konten, baca kunci jawaban, unggah Storage (API langsung) | Lulus |
| Desain | Layar HP 390×844 tanpa scroll horizontal, menu lipat; konsol tanpa error JS | Lulus |
| CMS vs Supabase asli | **Tidak bisa diuji** di sesi ini — emulator meniru subset PostgREST/Auth/Storage. Uji manual singkat di proyek DEV dianjurkan (lihat CMS_SETUP §9) | — |

## 3. Aplikasi Flutter

Lingkungan analisis: Dart SDK 3.13.7 (conda-forge) + sumber **Flutter 3.47.9** (GitHub) + sumber paket dari GitHub sesuai versi `pubspec` (supabase_flutter 2.18.3, riverpod 3.4.3, go_router 18.1.x, video_player 2.14.1, speech_to_text 7.3.0, file_picker 11.0.3, dst.). Paket tidak diambil dari pub.dev (diblokir), sehingga versi patch bisa sedikit berbeda.

| # | Uji | Status | Bukti / alasan |
|---|---|---|---|
| F-1 | `dart format` | **Lulus** untuk semua berkas baru/diubah. Berkas lama tidak diformat ulang agar diff tetap bisa ditinjau; CI hanya memberi peringatan | `git diff` |
| F-2 | `dart analyze` (setara `flutter analyze`) | **0 error, 0 warning**, 2 info lama | `docs/test-logs/flutter_analyze.txt` |
| F-3 | Galat kompilasi di source lama | **Ditemukan & diperbaiki**: 2 galat parse `as String? :` di `conversation.dart` dan `learning.dart`. Kemungkinan inilah penyebab source ZIP gagal di-build | commit `f42252c` |
| F-4 | Tes unit logika baru (model kuis, jawaban, kunci, hasil, progres, riwayat, Sign v1.1.0 + kompatibilitas JSON lama, rute, konfigurasi kuis, kecepatan video, Premium) | **Lulus 26/26** (dijalankan dengan Dart VM + shim `flutter_test` lokal) | `docs/test-logs/flutter_unit_pure.txt` |
| F-5 | `flutter test` penuh (20 berkas lama + 4 baru, termasuk tes widget kuis & empty state) | **Tidak bisa diuji di sesi ini**: engine Flutter (flutter_tester) diblokir. Dijalankan otomatis oleh GitHub Actions / `tool\release.ps1` | — |
| F-6 | Semua halaman terbuka, navigasi, video/audio diputar, login/logout, progres setelah login ulang, isolasi akun | **Tidak bisa diuji di sesi ini** (tidak ada emulator/perangkat). Isolasi akun & penilaian kuis sudah diuji di tingkat database (D-4 V-24/V-25/V-30) | — |
| F-7 | Materi Published tampil, Draft tidak | Lulus di tingkat RLS (V-20). Uji UI menunggu perangkat. Kode aplikasi juga memfilter `status = published` | — |
| F-8 | Layar kecil & tablet | **Tidak bisa diuji** (tanpa engine). Desain memakai `ContentWidth`, grid `maxCrossAxisExtent`, teks `ellipsis`, dan pola layout bawaan proyek | — |
| F-9 | Uji perangkat (navigasi, video, audio, login, progres) | **Menunggu pemilik**. Daftar periksa ada di §5 | — |

## 4. Build APK

| # | Uji | Status |
|---|---|---|
| B-1 | `flutter build apk --release` | **Tidak bisa diuji di sesi ini** (Flutter SDK, Android SDK, Maven diblokir). Disiapkan 2 jalur: GitHub Actions (`.github/workflows/android.yml`) dan `tool\release.ps1` |
| B-2 | Logika signing Gradle (keystore ada / tidak ada / mode uji) | **Lulus**: logika Kotlin DSL yang sama dijalankan dengan Gradle 8.14.3 lokal di proyek uji tanpa plugin Android. Tanpa keystore → build release ditolak dengan pesan jelas; mode uji → lanjut; dengan `key.properties` → path & alias terbaca |
| B-3 | Versi | `pubspec.yaml` `1.1.0+2` → versionName 1.1.0, versionCode 2 (> 1 milik APK 1.0.0) |

## 5. Daftar periksa uji di HP (untuk pemilik)

1. Uninstall APK lama, lalu pasang APK 1.1.0 dan login dengan akun lama. Akun harus tetap ada.
2. **Beranda**: sapaan, banner (jika ada yang aktif di CMS), *Mulai Belajar*, kartu modul, ringkasan progres.
3. **Alfabet** dan **Angka**:
   - Saat materi belum ada, tampil "Materi belum tersedia".
   - Setelah 1 huruf dipublikasikan dari CMS, huruf tampil.
   - Video bisa diputar dengan kecepatan 0,5×, 0,75×, dan 1×.
   - Tombol *Tandai sudah dipelajari*, sebelumnya/berikutnya, dan mode belajar berfungsi.
4. **Kosakata**: cari kata, buka detail, tambah/hapus favorit, putar audio jika ada.
5. **Percakapan**: tampil terjemahan dan penjelasan, audio bisa diputar, *Mulai simulasi percakapan* berjalan.
6. **Belajar → Latihan & Kuis**: per kategori, campuran, *latihan yang belum dikuasai*, pembahasan, *ulangi soal yang salah*, dan riwayat kuis.
7. **Profil**:
   - Statistik dan riwayat belajar tampil.
   - Notifikasi, FAQ, dan Premium bisa dibuka.
   - Setelah logout lalu login lagi, progres masih ada.
8. **Akun kedua**: tidak boleh melihat progres akun pertama.
