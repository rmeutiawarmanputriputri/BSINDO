# IMPLEMENTATION_ROADMAP — BISINDO

Satu fase pada satu waktu. Fase berikutnya dimulai hanya jika **kriteria selesai** fase sebelumnya terpenuhi dengan bukti dan pemilik proyek menyetujui laporan fase. Urutan di bawah disesuaikan dari saran awal dengan alasan teknis: **migrasi baseline (profiles + trigger) dipindah ke sebelum Login berfungsi**, dan **tabel favorit ikut fase Kamus**.

Konvensi laporan: lihat `CLAUDE_WORK_FIRST_PROMPT.md` §Pelaporan. Setiap fase: Git commit terpisah (cabang `phase/pX-nama`), pesan commit jelas.

## Ringkasan

| Fase | Nama | Bergantung pada |
|---|---|---|
| P0 | Audit lingkungan & fondasi proyek | — |
| P1 | Design system + UI Splash/Login/Register (tanpa backend) | P0 |
| P2 | Backend baseline Supabase (0001–0002, 0007 sebagian) + koneksi | P0 |
| P3 | Routing + autentikasi + profil | P1, P2 |
| P4 | Beranda + navigasi + tabel konten dasar | P3 |
| P5 | Kamus, pencarian, detail, video, favorit | P4 |
| P6 | Modul percakapan | P5 |
| P7 | Kosakata sulit + latihan ulang | P5 |
| P8 | Speech-to-text | P4 |
| P9 | Pelaporan konten | P5 |
| P10 | Pelajaran, kuis, progres | P5, P6 |
| P11 | Admin | P5–P10 |
| P12 | Keamanan & integrasi penuh | P11 |
| P13 | Pengujian akhir & build APK | P12 |

P7, P8, P9 dapat ditukar urutannya bila ada alasan; P8 tidak bergantung database.

---

## P0 — Audit lingkungan & fondasi
- **Tujuan:** ketahui apa yang dapat dijalankan; buat kerangka proyek bersih.
- **Langkah:** cek kemampuan (shell, Flutter, Dart, Android SDK, Java, Git, adb, akses jaringan/Supabase, kemampuan membaca gambar); `flutter doctor -v`; buat proyek Flutter (atau periksa yang ada); `git init`/periksa repo; susun folder §3 FLUTTER_ARCHITECTURE; salin dokumen ke `docs/`, gambar ke `docs/design/reference/`; tambahkan dependensi inti; `.gitignore` (env, keystore); `env/example.json`; `analysis_options.yaml`; halaman "Hello" yang mem-boot `ProviderScope`.
- **File:** `pubspec.yaml`, `analysis_options.yaml`, `.gitignore`, `lib/main.dart`, `lib/app/**`, `docs/**`, `env/example.json`, `README.md` (cara menjalankan).
- **Validasi:** `flutter doctor -v`, `flutter pub get`, `flutter analyze`, `flutter test` (tes dasar), `flutter build apk --debug` bila SDK ada.
- **Selesai bila:** laporan lingkungan jujur; proyek dapat dianalisis tanpa error; batasan lingkungan terdaftar.
- **Pemulihan:** jangan menimpa proyek yang ada; bila gagal, `git stash`/cabang baru; laporkan.

## P1 — Design system + UI Splash/Login/Register
- **Tujuan:** token, tema M3, komponen inti, tiga layar sesuai gambar (data dummy/tanpa Supabase).
- **File:** `lib/app/theme/*`, `lib/core/widgets/*`, `lib/features/auth/presentation/*`, `assets/brand/*` (menunggu K-01), font, `test/**` (validator, widget, golden).
- **Validasi:** analyze, test (validator + widget + golden 2 ukuran), pembandingan visual dengan gambar, uji 360×640 & skala teks 200%, (bila ada emulator) tangkapan layar.
- **Selesai bila:** AUTH spec §9 butir 1–5 terpenuhi atau deviasi dilaporkan; semua deviasi (K-02, K-03, ukuran) tercatat.
- **Pemulihan:** komponen dapat di-revert per commit; token berada di satu berkas.

## P2 — Backend baseline Supabase
- **Tujuan:** proyek dev siap: `profiles`, trigger, `is_admin`, RLS profil, konfigurasi auth.
- **Catatan:** bila Claude Work tak punya akses Supabase → hasilkan berkas migrasi + **panduan langkah manual** untuk pemilik, status "BELUM DITERAPKAN".
- **File:** `supabase/migrations/0001_*.sql`, `0002_*.sql`, (0007 untuk `profiles` bila dipecah), `docs/SUPABASE_SETUP.md`.
- **Validasi:** eksekusi pada dev/lokal; query bukti: tabel ada, trigger membuat profil untuk akun uji, `update profiles set role` oleh `authenticated` ditolak.
- **Selesai bila:** RLS-05/06/07 lulus (atau ditandai belum dijalankan).
- **Pemulihan:** migrasi bersifat berurutan; sediakan `down` manual (drop) atau reset proyek dev.

## P3 — Routing + autentikasi + profil
- **File:** `lib/app/router/*`, `lib/features/auth/data/*`, controllers, `lib/features/profile/*`, `AndroidManifest.xml` (deep link).
- **Validasi:** AUTH-01…AUTH-10; tes widget dengan repository palsu; uji nyata bila backend ada.
- **Selesai bila:** register/login/logout/pemulihan sesi/lupa sandi bekerja atau ditandai belum terverifikasi dengan alasan.
- **Pemulihan:** feature flag router; revert commit.

## P4 — Beranda & navigasi
- Migrasi 0003–0006 (tabel konten, fungsi) diterapkan di dev + RLS konten; `NavigationBar` 5 tab; Beranda dengan blok mandiri.
- **Validasi:** tes widget state per blok; NET-01.
- **Selesai bila:** navigasi stabil; data beranda dari DB atau empty state benar.

## P5 — Kamus, pencarian, video, favorit
- **File:** `features/dictionary`, `features/video`, `features/favorites`, repository, `SignedUrlCache`, migrasi bucket 0008.
- **Validasi:** DICT-*, VID-*, FAV-01, ST-01…05.
- **Selesai bila:** pencarian & detail & video bekerja dengan aset uji; placeholder/gagal ditangani.

## P6 — Modul percakapan
`features/conversation`; CONV-*; progres modul.

## P7 — Kosakata sulit
`features/difficult_vocab`; DIFF-*; blok Beranda.

## P8 — Speech-to-text
`features/transcription`; izin, state machine, privasi; STT-* di perangkat nyata. **Wajib** melaporkan hasil uji perangkat apa adanya; bila tidak ada perangkat → "BELUM TERUJI".

## P9 — Pelaporan
`features/reports`; REP-*; RLS-13…17.

## P10 — Pelajaran, kuis, progres
`features/learning`; RPC `submit_quiz_attempt`; QUIZ-*, PROG-*; RLS-08…10.

## P11 — Admin
`features/admin`; ADM-*; unggah media; alur validasi/publikasi; tinjau laporan.

## P12 — Keamanan & integrasi penuh
Jalankan seluruh RLS/ST; tinjau rahasia (`git grep`); audit `security definer`; periksa checklist pra-rilis (SAMPLE=0, K-08/K-10 diputuskan); perbaikan; dokumentasi `docs/KNOWN_ISSUES.md`.

## P13 — Pengujian akhir & build
Seluruh `TEST_PLAN`; `flutter build apk --debug`; instal & uji asap di perangkat; laporan akhir dengan bukti; daftar masalah terbuka.

---

## Template laporan akhir fase
```
FASE: Px — nama
STATUS: SELESAI / SEBAGIAN / DIBLOKIR
LINGKUNGAN: apa yang tersedia / tidak
FILE DIBUAT/DIUBAH: daftar path
PERINTAH DIJALANKAN: perintah + ringkasan hasil nyata
VALIDASI: ID tes → LULUS (dijalankan) / GAGAL / TIDAK DIJALANKAN (alasan)
DEVIASI DARI SPEC: (dan alasannya)
HAMBATAN & KEPUTUSAN DIBUTUHKAN: ...
RISIKO BARU: ...
LANGKAH BERIKUTNYA: ...
```
