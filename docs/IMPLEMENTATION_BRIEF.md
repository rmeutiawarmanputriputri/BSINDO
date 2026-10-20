# IMPLEMENTATION_BRIEF — Aplikasi Belajar BISINDO (Flutter + Supabase)

**Versi:** 1.0 (paket perencanaan final)
**Status:** Siap diserahkan ke Claude Work. Dokumen ini adalah **sumber keputusan tertinggi**.

## 0. Hierarki dokumen (jika ada konflik)

1. Gambar referensi Splash/Login/Register → otoritas visual tertinggi untuk 3 layar tersebut (kecuali deviasi yang tercatat di `AUTH_UI_DESIGN_SPEC.md` dan disetujui pemilik proyek).
2. `IMPLEMENTATION_BRIEF.md` (dokumen ini).
3. `DATABASE_SCHEMA.md` dan `SUPABASE_SECURITY_PLAN.md` (data & keamanan).
4. `FLUTTER_ARCHITECTURE.md`.
5. `DESIGN_SYSTEM.md`, `AUTH_UI_DESIGN_SPEC.md`.
6. `UI_UX_SPECIFICATION.md`, `USER_FLOWS.md`.
7. `TEST_PLAN.md`, `IMPLEMENTATION_ROADMAP.md`.

Jika Claude Work menemukan konflik yang belum terselesaikan: **berhenti, laporkan, jangan menebak**.

---

## 1. Tujuan

Aplikasi Android untuk belajar Bahasa Isyarat Indonesia (BISINDO): kamus kosakata berbasis video, modul percakapan sehari-hari, pelajaran + kuis, daftar kosakata sulit pribadi, pelaporan konten keliru, dan transkripsi ucapan → teks (alat bantu komunikasi, **bukan** penerjemah isyarat).

Prinsip: video & komunikasi visual lebih dulu, pemula-friendly, mobile-first, aksesibel, fondasi bisa berkembang tanpa dibangun ulang.

## 2. Teknologi (tetap)

Flutter + Dart (Android), Material 3, Supabase (PostgreSQL, Auth, Storage), `supabase_flutter`, Git, Android SDK + Gradle. **Dilarang** mengganti dengan React Native/Next.js. Detail library: `FLUTTER_ARCHITECTURE.md`.

## 3. Cakupan MVP → layar → data → fase

| Fitur | Layar (ID) | Tabel/Objek utama | Fase |
|---|---|---|---|
| A. Auth & Profil | S01–S06, S24 | `profiles`, Supabase Auth | P0–P3 |
| B. Beranda | S07 | `user_progress`, `difficult_vocabulary` | P4 |
| C. Pencarian kata | S08, S09, S19 | `signs`, `categories`, `favorites` | P5 |
| D. Video demonstrasi | S09, S10 | `media_assets`, Storage `bisindo-media` | P5 |
| E. Modul percakapan | S11, S12 | `conversation_modules`, `conversation_items` | P6 |
| F. Speech-to-text | S13 | (tanpa tabel; tidak ada penyimpanan) | P8 |
| G. Kosakata sulit | S20, S21 | `difficult_vocabulary` | P7 |
| H. Pelaporan | S22, S23, S27 | `content_reports` | P9 |
| I. Belajar & kuis | S14–S18 | `lessons`, `lesson_items`, `quizzes`, `questions`, `question_options`, `question_answer_keys`, `quiz_attempts`, `user_progress` | P10 |
| J. Admin | S25–S27 | semua tabel konten + RLS admin | P11 |

## 4. Di luar cakupan MVP (non-goals)

- Mengenali/menerjemahkan gerakan isyarat → teks/suara (tidak ada ML kamera).
- Login sosial (Google/Facebook/Apple) — lihat K-03.
- Notifikasi push, mode offline penuh/unduh video, gamifikasi lanjutan, multi-bahasa UI, iOS/Web.
- Penyimpanan audio atau transkrip.
- Pembuatan konten BISINDO oleh pengembang/AI.

## 5. Keputusan final

| ID | Keputusan | Alasan singkat |
|---|---|---|
| D-01 | State management: **flutter_riverpod** tanpa code-generation | Testable (override provider), `AsyncValue` cocok untuk loading/error/empty, tanpa build_runner |
| D-02 | Routing: **go_router** dengan redirect berbasis sesi + role | Deep link auth (verifikasi email/reset sandi) dan guard admin |
| D-03 | Arsitektur **feature-first**, 3 lapis ringan: `data` (repository) / `domain` (model) / `presentation` | Memisahkan UI dari akses DB tanpa abstraksi berlebihan |
| D-04 | Tabel `phrases` **digabung** ke `signs` dengan kolom `entry_type` (`word`/`phrase`) | Satu video/validasi/favorit/kosakata-sulit; tanpa FK polimorfik |
| D-05 | Tabel tambahan `media_assets`; satu bucket **privat** `bisindo-media` + signed URL | Metadata file, penggantian video, kontrol akses draft |
| D-06 | Role di `profiles.role`; kolom tidak bisa diubah klien (column-level grant); admin pertama via SQL editor | Mencegah eskalasi role |
| D-07 | Kunci jawaban di tabel terpisah `question_answer_keys` (tanpa akses pengguna); penilaian lewat RPC `submit_quiz_attempt` | Kunci tak bocor, skor tak bisa dimanipulasi |
| D-08 | STT: paket `speech_to_text` (SpeechRecognizer Android), locale `id_ID`, tanpa menyimpan apa pun | Tanpa biaya/API key; lihat batasan di `FLUTTER_ARCHITECTURE.md` §9 |
| D-09 | Verifikasi email **ON** di produksi (boleh OFF di proyek dev); deep link `bisindo://auth-callback` | Keamanan akun; reset sandi butuh deep link |
| D-10 | Login sosial **keluar dari MVP**; widget disiapkan, disembunyikan feature flag | MVP A hanya mensyaratkan login/registrasi; Apple/Facebook di Android butuh setup besar |
| D-11 | Admin dashboard di dalam aplikasi (hanya tampil bila `role='admin'`), keamanan sejati di RLS; input massal lewat Supabase Studio | Sesuai spesifikasi J |
| D-12 | Status konten: `draft → in_review → verified → published` (+ `archived`); `verified/published` wajib punya `validated_by`, `verified_at`, `source_note` (CHECK constraint) | Menegakkan aturan "tidak ada konten tak terverifikasi" di DB |
| D-13 | Video: MP4 H.264 + AAC, ≤720p (target 480p), ≤ ~2 Mbps, **faststart**, ≤20 MB (target 2–5 MB), poster/thumbnail wajib | Streaming koneksi lambat |
| D-14 | Konfigurasi: `--dart-define-from-file=env/dev.json` (tidak di-commit); hanya `SUPABASE_URL` + anon key di klien | Service role key **tidak pernah** di klien |
| D-15 | Font **dibundel** di `assets/fonts` (bukan fetch runtime) — keluarga font menunggu K-04 | Konsisten dan jalan offline |
| D-16 | Progres belajar bersifat self-reported (tidak kritis keamanan); skor kuis dihitung server | Memisahkan data pribadi vs data yang harus dipercaya |

## 6. Keputusan yang perlu dikonfirmasi pemilik (K-xx)

Claude Work memakai **default sementara** dan wajib melaporkannya.

| ID | Pertanyaan | Default sementara |
|---|---|---|
| K-01 | File logo resmi (SVG/PNG): wordmark putih, ikon Login, ikon Register, ikon splash, ikon aplikasi. Ketiga gambar memuat **tiga versi ikon berbeda**. | Placeholder teks "BISINDO"; **jangan menggambar ulang logo**; tandai TODO |
| K-02 | Toggle sandi Login berbentuk **switch**, Register memakai **ikon mata**. Pakai yang mana? | Ikon mata di keduanya (konsisten, lebih mudah dipahami) |
| K-03 | Login sosial: dibutuhkan di MVP? | Disembunyikan (flag `enableSocialAuth=false`); rekomendasi: Google saja pada fase lanjutan |
| K-04 | Kode warna & font persis (dari file desain sumber/Figma) | Estimasi dari gambar di `DESIGN_SYSTEM.md`; font default Inter (dibundel) |
| K-05 | Nama aplikasi & `applicationId` | Nama "BISINDO"; applicationId sementara `com.example.bisindo` — **ganti sebelum rilis** |
| K-06 | Sumber materi BISINDO & siapa validator (komunitas Tuli/penutur asli/organisasi kompeten) | Tidak ada materi nyata; hanya seed dev berlabel |
| K-07 | Android minimum yang didukung | Default Flutter stabil; pastikan ≥ syarat plugin |
| K-08 | Teks persetujuan Syarat & Privasi saat registrasi (dokumen hukumnya belum ada) | Tidak ditambahkan; dicatat sebagai risiko rilis |
| K-09 | Proyek Supabase terpisah dev & prod? | Disarankan terpisah; minimal `env/dev.json` dan `env/prod.json` |
| K-10 | Penghapusan akun (wajib bila dirilis ke Google Play) | Di luar MVP debug; catat sebagai syarat rilis |

## 7. Asumsi & risiko (belum terverifikasi)

| ID | Risiko / asumsi | Mitigasi |
|---|---|---|
| R-01 | **Konten BISINDO terverifikasi belum tersedia** | Seed hanya draft/dev; UI menampilkan sumber & validator; tanpa validator tak bisa `published` (CHECK) |
| R-02 | STT Android: akurasi `id_ID` bervariasi; sering butuh internet (audio dikirim ke layanan pengenal perangkat); perangkat tanpa Google Speech Services (mis. beberapa HP tanpa GMS) tidak didukung | Uji di perangkat nyata; pesan jelas; catatan privasi sebelum pemakaian pertama |
| R-03 | Versi paket & perilaku API Supabase/Flutter bisa berubah sejak perencanaan ini | Claude Work memeriksa dokumentasi/versi terbaru; laporkan penyimpangan |
| R-04 | SMTP bawaan Supabase terbatas (laju rendah) | Konfigurasi SMTP kustom sebelum uji pengguna nyata |
| R-05 | Video besar/koneksi lambat | Spesifikasi D-13, poster, indikator buffering, tombol coba lagi |
| R-06 | Input konten massal sulit lewat aplikasi ponsel | Studio Supabase/CSV untuk teks; upload video via admin app |
| R-07 | Kuis dapat diulang sehingga kunci jawaban terlihat setelah submit | Diterima untuk MVP; opsi: batasi percobaan nanti |
| R-08 | Kontras desain asli (placeholder abu-abu, teks kecil) di bawah WCAG AA | Perbaikan diusulkan di `AUTH_UI_DESIGN_SPEC.md` §4 |
| R-09 | Tanpa penghapusan akun & kebijakan privasi, rilis Play Store terhambat | K-08, K-10 |

## 8. Aturan konten BISINDO

1. Tidak boleh mengarang gerakan, arti, atau deskripsi gerakan.
2. Hanya status `published` yang tampil ke pengguna; `published` mensyaratkan validator + tanggal + sumber (CHECK di DB).
3. UI detail kosakata menampilkan "Sumber" dan "Divalidasi oleh … (tanggal)".
4. Seed dev hanya di proyek dev, ditandai `validated_by = 'DEV-SAMPLE (BUKAN VERIFIKASI)'`; UI menampilkan lencana "Materi contoh" bila ada penanda itu. **Dilarang** dijalankan di produksi.
5. Deskripsi gerakan tidak boleh diisi AI; kosongkan jika belum ada.

## 9. Hasil audit konsistensi (konflik yang ditemukan dan penyelesaiannya)

| # | Temuan | Penyelesaian |
|---|---|---|
| 1 | Daftar entitas memuat `phrases` dan `signs` → duplikasi logika | D-04 (digabung) |
| 2 | Desain Login/Register memuat Google/Facebook/Apple; MVP hanya login/registrasi | D-10 / K-03 |
| 3 | Switch (Login) vs ikon mata (Register); logo berbeda; tinggi input/tombol berbeda antar gambar | K-01, K-02, ukuran distandarkan (`AUTH_UI_DESIGN_SPEC.md`) |
| 4 | Desain punya "Lupa Kata Sandi?" tetapi 21 layar tidak memuatnya | Ditambah S04, S05, S06 |
| 5 | Kuis "terlindungi dari manipulasi" vs penilaian di klien | D-07 |
| 6 | "Admin diverifikasi di backend" | `is_admin()` + RLS + column grant (D-06) |
| 7 | "Materi terakhir dipelajari" butuh timestamp | `user_progress.last_accessed_at` |
| 8 | Roadmap: auth butuh `profiles` + trigger lebih dulu | Fase P0/P2 menyertakan migrasi baseline |
| 9 | Penyimpanan video publik vs draft belum terverifikasi | Bucket privat + `can_read_media()` (D-05) |
| 10 | STT "tidak menyimpan" vs privasi perangkat pengenal | Dinyatakan jujur di UI & dokumen (R-02) |

## 10. Definisi selesai MVP

Semua kriteria di `TEST_PLAN.md` §10 terpenuhi **dengan bukti eksekusi** (log perintah, hasil tes, APK debug terpasang di perangkat/emulator, pengujian RLS berhasil). Tanpa bukti → status "belum terverifikasi".

## 11. Aturan kerja Claude Work (ringkas)

Baca semua dokumen → periksa lingkungan → laporkan batasan → satu fase per waktu → periksa file sebelum menimpa → validasi tiap fase → tidak ada klaim palsu → tidak ada placeholder yang disamarkan sebagai fitur selesai → rahasia tidak boleh di klien/Git. Detail: `CLAUDE_WORK_FIRST_PROMPT.md` dan `IMPLEMENTATION_ROADMAP.md`.
