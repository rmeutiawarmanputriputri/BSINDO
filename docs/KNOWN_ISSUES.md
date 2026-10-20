# Masalah Terbuka & Batasan (jujur) — BISINDO

Diperbarui: 2026-10-20 · Cabang `phase/p3-p11-features`

## A. Belum terverifikasi oleh lingkungan pembuatan
| # | Hal | Status | Cara memverifikasi |
|---|---|---|---|
| A-1 | `flutter analyze` / `flutter test` untuk kode Fase 2–11 | ⚠️ belum dijalankan (tidak ada Flutter SDK di sesi pembuatan) | `tool\check.ps1` atau GitHub Actions |
| A-2 | Build APK | ⚠️ belum | sama |
| A-3 | Migrasi pada proyek Supabase sungguhan | ⚠️ belum (diuji di PostgreSQL 16 + stub + PostgREST 13 lokal) | `docs/SUPABASE_SETUP.md` |
| A-4 | Uji manual perangkat: STT (STT-02…09), video (VID-03/04/06), TalkBack (A11Y-01), keyboard (RESP-02), deep link (AUTH-10) | ⚠️ butuh perangkat Android nyata | `TEST_PLAN.md` |
| A-5 | Golden baseline | ⚠️ dibuat di mesin Anda (`--update-goldens`); dilewati otomatis bila belum ada | — |

## B. Keputusan default yang menunggu pemilik (K-xx)
K-01 logo (placeholder ikon Material `sign_language` + teks "BISINDO") · K-02 ikon mata di Login · K-03 login sosial disembunyikan · K-04 warna/font estimasi + Inter · K-05 `com.example.bisindo` (**ganti sebelum rilis**) · K-06 sumber & validator materi · K-07 minSdk default Flutter (24) · K-08 teks Syarat & Privasi belum ada · K-09 proyek dev/prod terpisah · K-10 hapus akun belum ada (**wajib untuk Google Play**).

## C. Batasan fungsional yang diketahui
1. **Tidak ada materi BISINDO asli.** Seed dev hanya "Contoh 1–5" berlabel *Materi contoh*. Konten wajib diisi validator lewat Admin.
2. **STT** bergantung layanan pengenal ucapan perangkat (umumnya Google, sering butuh internet); akurasi `id_ID` bervariasi; perangkat tanpa layanan tidak didukung. Status `inactive` (mis. tarik notifikasi) menghentikan rekaman (disengaja).
3. **Supabase menyamarkan email terdaftar** saat konfirmasi email aktif: pendaftaran ulang email yang sama tampil sebagai "cek email" (perlindungan enumerasi), bukan "Email sudah terdaftar".
4. **Progres** bersifat self-reported (D-16); skor kuis dihitung server.
5. **Penandaan "sudah dibuka"** item pelajaran disimpan sebagai posisi terakhir (bukan per item).
6. **Kunci jawaban** terlihat setelah submit dan kuis dapat diulang (R-07, diterima MVP).
7. **Pull-to-refresh** pada Riwayat Laporan hanya saat ada data.
8. **Video**: thumbnail memakai `Image.network` tanpa cache disk (paket `cached_network_image` tidak ditambahkan); keluar layar penuh mengunci portrait.
9. **Admin**: urutan item ditukar dengan 3 panggilan REST (posisi sementara); edit soal mengganti seluruh pilihan (riwayat percobaan lama menyimpan id pilihan lama di JSON — tidak memengaruhi skor tersimpan).
10. **Objek Storage yatim** (unggah sukses, simpan DB gagal) dibersihkan best-effort; tidak ada pembersihan terjadwal.
11. Menu konteks teks berbahasa Indonesia via `flutter_localizations`; teks aplikasi belum memakai ARB (di luar MVP).

## D. Checklist pra-rilis (belum)
- `select count(*) from signs where validated_by like 'DEV-SAMPLE%'` = 0 di produksi.
- applicationId final, keystore rilis, ikon launcher resmi (K-01/K-05).
- Confirm email ON + SMTP kustom + redirect `bisindo://auth-callback`.
- Kebijakan privasi (termasuk pemrosesan suara oleh layanan perangkat) + hapus akun (K-08/K-10).
- `git grep -i service_role` = 0.
