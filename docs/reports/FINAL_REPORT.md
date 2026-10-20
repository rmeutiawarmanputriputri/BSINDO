# Laporan Fase 2–13 — BISINDO

**STATUS:** Kode SELESAI untuk P2–P11, bagian P12–P13 yang dapat dikerjakan tanpa SDK/perangkat SELESAI. Validasi Flutter (analyze/test/build) **belum dijalankan di lingkungan pembuatan** → jalankan `tool\check.ps1` atau GitHub Actions.
**Cabang:** `phase/p2-supabase` → `phase/p3-p11-features` · **Default K-xx dipakai** (lihat `KNOWN_ISSUES.md` §B).

## Lingkungan pembuatan
Shell Linux, PostgreSQL 16.15 lokal, PostgREST 13.0.8 (biner resmi GitHub), gcc, Node. **Tidak ada** Flutter/Dart/Android SDK (unduhan diblokir). Sumber asli paket di-clone dari GitHub untuk verifikasi API: Flutter 3.47.7, flutter_riverpod 3.4.3, go_router 18.1.0, supabase_flutter 2.18.3, video_player 2.14.1, speech_to_text 7.3.0, permission_handler 13.0.2, file_picker 11.0.3.

## Yang dibuat per fase
| Fase | Isi | Berkas utama |
|---|---|---|
| P2 | Migrasi 0001–0008 dari dokumen + **0009** (default `auth.uid()`, favorit/sulit hanya sign published, RPC dashboard admin) + **0010** (RPC `touch_progress`: PostgREST tidak bisa upsert ke indeks unik parsial) · seed kategori & dev · panduan | `supabase/migrations/*`, `supabase/setup_all.sql`, `supabase/seed/*`, `docs/SUPABASE_SETUP.md`, `docs/media_guidelines.md` |
| P3 | `Supabase.initialize` (publishableKey), repository auth Supabase + fake, redirect router (sesi, pemulihan sandi), Lupa/Atur/Verifikasi sandi (S04–S06), deep link, profil | `lib/app/bootstrap.dart`, `lib/app/router/*`, `lib/features/auth/**`, `lib/features/profile/**`, `AndroidManifest.xml` |
| P4 | Shell 5 tab (`StatefulShellRoute`), Beranda dengan blok mandiri | `lib/app/shell/app_shell.dart`, `lib/features/home/**` |
| P5 | Kamus + pencarian (debounce, escape wildcard, filter, pagination 20), detail + sumber/validasi + lencana materi contoh, pemutar video (poster, buffering, loop, 0,5×, layar penuh, retry signed URL), favorit optimistik | `lib/features/dictionary/**`, `video/**`, `favorites/**`, `core/supabase/signed_url_cache.dart` |
| P6 | Modul percakapan + progres `last_position` | `lib/features/conversation/**` |
| P7 | Kosakata sulit (tab, upsert tanpa duplikat), latihan ulang | `lib/features/difficult_vocab/**` |
| P8 | Transkripsi: izin + dialog privasi, mesin status, fallback bahasa atas persetujuan, salin/edit/hapus, berhenti saat ke latar, tanpa penyimpanan | `lib/features/transcription/**` |
| P9 | Form laporan (validasi "Lainnya" ≥ 5), duplikat/batas harian, riwayat | `lib/features/reports/**` |
| P10 | Pelajaran, detail, kuis (RPC server), hasil + tinjauan, progres | `lib/features/learning/**` |
| P11 | Admin: guard, dashboard, CRUD kosakata/kategori/modul (+dialog)/pelajaran (+materi +kuis +kunci jawaban), unggah/ganti media aman, tinjau laporan | `lib/features/admin/**` |
| P12 | Audit rahasia, `KNOWN_ISSUES.md`, review statis independen 3 area | `docs/KNOWN_ISSUES.md` |
| P13 | CI GitHub Actions (APK sebagai artifact), skrip Windows `setup/check/fix_gradle` | `.github/workflows/android.yml`, `tool/*.ps1` |

## Validasi yang BENAR-BENAR dijalankan
| Kriteria | Status | Bukti |
|---|---|---|
| Migrasi 0001–0010 diterapkan berurutan | ✅ DIJALANKAN & LULUS | PostgreSQL 16 + stub Supabase (`supabase/tests/local/00_supabase_stub.sql`) |
| RLS-01…17, ST-01…05, AUTH-06, QUIZ-01/03, REP-01(DB)/04, PROG, ADM | ✅ **30/30 LULUS** | `supabase/tests/local/10_rls_tests.sql` |
| String query repository Dart vs PostgREST asli (embed, filter, upsert, RPC, count, single, CHECK → pesan) | ✅ **47/47 LULUS** | `supabase/tests/local/postgrest_queries.py` (membaca konstanta select langsung dari berkas Dart) |
| Seed kategori + dev | ✅ | 16 kategori, 5 sign contoh, 1 modul, 1 pelajaran + kuis |
| Sintaks Dart semua berkas | ✅ 129 berkas, 0 kesalahan parse | tree-sitter-dart terbaru (native) |
| Review statis independen (3 agen, terhadap source paket asli) | ✅ | 1 compile error null-safety + 1 lint + ±20 risiko runtime (ref setelah unmount, controller video bocor, listener STT, toggle saat loading) — **sudah diperbaiki** |
| Pemindaian rahasia | ✅ 0 temuan | `git grep service_role|eyJhbGci|sb_secret` |
| `flutter analyze` / `flutter test` / build APK | ⚠️ TIDAK DIJALANKAN | tanpa SDK — jalankan `tool\check.ps1` / CI |
| Uji perangkat (STT, video, TalkBack, deep link) | ⚠️ TIDAK DIJALANKAN | butuh perangkat |

Tes Flutter yang ditulis: 21 berkas (unit: validator, mapper error, sanitasi, uuid, tanggal, signed URL cache, media, laporan, controller kamus, controller transkripsi, redirect router; widget: Login, Register, Splash, boot app, responsif 360×640 @200% + guideline a11y, golden).

## Deviasi dari dokumen (dengan alasan)
1. **0009/0010** ditambahkan (lihat atas). 2. `publishableKey` dipakai karena `anonKey` deprecated di supabase_flutter 2.18.3 (nilai anon key tetap sama). 3. `file_picker` ditahan di 11.x (v12 mengubah API). 4. `permission_handler` ditambahkan (alasan: "Buka Pengaturan" S13). 5. `flutter_localizations` ditambahkan (menu teks Indonesia). 6. `cached_network_image`/`shared_preferences` tidak ditambahkan (tidak diperlukan). 7. Path objek item percakapan: `conversations/{module}/items/{item}/video-{asset}.mp4`. 8. Hasil kuis ditampilkan di layar kuis yang sama (S17), bukan rute terpisah. 9. G-2: jarak tepi auth 20dp (mengikuti gambar).

## Langkah Anda
1. Ekstrak zip ke folder BARU → `cd bisindo_app` → `powershell -ExecutionPolicy Bypass -File tool\setup.ps1`
2. Isi `env\dev.json` (URL + anon key proyek Supabase DEV) dan terapkan `supabase/setup_all.sql` (lihat `docs/SUPABASE_SETUP.md`).
3. `powershell -ExecutionPolicy Bypass -File tool\check.ps1` → kirim folder `logs\` bila ada yang GAGAL; saya perbaiki.
4. Alternatif tanpa Gradle lokal: push ke GitHub → tab Actions → unduh artifact `bisindo-debug-apk`.
