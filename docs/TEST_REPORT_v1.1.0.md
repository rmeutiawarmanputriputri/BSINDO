# Laporan Uji BISINDO v1.1.0 (SEMENTARA)

Status dokumen: **sementara**. Bagian Database dan CMS sudah final. Bagian Aplikasi Flutter dan Build menunggu source Flutter terbaru dari pemilik.
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

## 3. Aplikasi Flutter — MENUNGGU source terbaru

Belum diuji. Akan diisi setelah source yang dipakai membangun APK 1.0.0 diterima.

## 4. Build APK — MENUNGGU

`flutter build apk --release` tidak dapat dijalankan di sesi ini (Flutter SDK, pub.dev, Android SDK, Maven diblokir). Build akan dilakukan di komputer pemilik dengan `tool/release.ps1`.
