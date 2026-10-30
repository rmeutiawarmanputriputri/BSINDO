# Laporan Akhir BISINDO v1.1.0

Tanggal: 2026-10-30 · Cabang: `release/1.1.0-wip` (commit per fase) · Versi aplikasi: **1.1.0** (versionCode **2**)

## 1. Ringkasan audit source lama
Rincian ada di `docs/AUDIT_v1.0.md`. Poin utama:
- APK 1.0.0 di HP pengguna dibangun dari source yang berbeda dari ZIP. Pemilik **memilih source ZIP** sebagai dasar karena desainnya sesuai dengan desain miliknya. Konsekuensinya, fitur *Komunikasi* dari APK 1.0.0 tidak ikut.
- APK 1.0.0 ditandatangani **debug key** dan memakai paket `com.example.bisindo`.
- Source ZIP ternyata **tidak dapat dikompilasi**: ada 2 galat parse. Keduanya sudah diperbaiki.
- Database lama sudah rapi: RLS di semua tabel dan kunci jawaban kuis tertutup. Uji lama 30/30 tetap lulus pada skema baru.

## 2. Perbaikan
| Masalah | Perbaikan |
|---|---|
| 2 galat kompilasi `x as String? : null` (`conversation.dart`, `learning.dart`) | Ekspresi diberi kurung; `dart analyze` kini 0 error |
| Release ditandatangani debug key | Signing release memakai `key.properties`. Build release tanpa keystore ditolak dengan pesan jelas, kecuali mode uji |
| Batas unggah media 20 MB tetap | Batas per jenis bisa diatur dari CMS, dengan batas keras 50 MB |
| Belum ada hapus akun (syarat Play Store) | RPC `delete_my_account` + tombol di Profil (admin terakhir dilindungi) |
| Kecepatan video hanya 0,5×/1× | 0,5× / 0,75× / 1× |

## 3. Fitur baru aplikasi
- **Beranda**:
  - sapaan dan banner dari CMS;
  - *Mulai Belajar* / materi terakhir dari riwayat lintas modul;
  - kartu modul dengan progres;
  - ringkasan progres (materi, kuis, percakapan, kosakata sulit);
  - rekomendasi materi berikutnya;
  - info Premium;
  - ikon pencarian dan notifikasi (dengan badge belum dibaca).
- **Alfabet & Angka**:
  - grid dari database; angka dikelompokkan 0–9, 10–20, puluhan, 100+;
  - penanda sudah dipelajari dan progres;
  - **mode belajar berurutan** (*Sudah paham, lanjut*);
  - kuis per modul;
  - *Materi belum tersedia* bila kosong.
- **Detail materi terpadu** (huruf/angka/kosakata):
  - video 0,5/0,75/1× dan panduan visual gerakan (gambar);
  - audio/voice dan tanda dipelajari;
  - navigasi sebelumnya/berikutnya (kosakata: dalam kategori yang sama);
  - favorit, kosakata sulit, laporan;
  - kunci Premium.
- **Kosakata**: hanya modul kosakata; penanda dipelajari/Premium di daftar. Tab diberi label *Kosakata*.
- **Percakapan**: terjemahan dan penjelasan per kalimat, audio, **simulasi percakapan** bertahap sesuai urutan dari CMS, dan kunci Premium.
- **Latihan & Kuis** (bank soal):
  - 6 jenis soal: tebak huruf, tebak angka, tebak gerakan, pilihan ganda, cocokkan gambar–arti, susun kosakata;
  - mode per kategori, campuran, dan *latihan yang belum dikuasai*; tingkat kesulitan dan jumlah soal;
  - umpan balik langsung beserta pembahasan; skor **dinilai server**;
  - *ulangi soal yang salah*; riwayat kuis (gabungan dengan kuis pelajaran lama).
- **Profil**:
  - statistik keseluruhan, per modul, dan per kategori;
  - riwayat belajar dan riwayat kuis;
  - notifikasi, FAQ, Premium;
  - hapus akun; versi 1.1.0.
- **Pendukung**:
  - pencarian global (huruf/angka/kosakata);
  - cache sesi materi (daftar yang sudah dibuka tetap ada selama aplikasi berjalan);
  - banner bertaut (rute aplikasi / https);
  - pesan *akun dinonaktifkan*.
- Fitur lama tetap ada: transkripsi, pelajaran + kuis pelajaran, laporan, admin dalam aplikasi, favorit, kosakata sulit.

## 4. CMS (Web, `cms/`) — modul A–L
Dashboard (angka nyata), Kategori, Alfabet, Angka, Kosakata, Percakapan, **Media** (unggah dengan progres, pratinjau, ganti berkas, hapus aman beserta daftar pemakaian, validasi format/ukuran), Kuis (6 jenis), Pengguna, Premium, Banner, Pengumuman, FAQ, Laporan konten, Pengaturan, dan **Impor massal** CSV/JSON (hasilnya Draft, template kosong).
Validasi publikasi menampilkan daftar kekurangan.

Akses hanya untuk admin. Pembatasan ini ditegakkan di database, bukan hanya disembunyikan di tampilan. Setup ada di `docs/CMS_SETUP.md`.

## 5. Database & migrasi
- `supabase/migrations/0110–0120` (aditif) beserta `supabase/rollback/*.down.sql`. Seed struktur ada di `supabase/seed/20_v110_struktur.sql` (nama kategori dan 9 topik Draft kosong, tanpa materi).
- Isi utama:
  - status `inactive`;
  - Alfabet/Angka di tabel `signs` (`content_module`, `symbol`, `number_group`);
  - media audio dan metadata;
  - bank soal dan `quiz_sessions`;
  - `sign_progress`, view riwayat, ringkasan progres;
  - `subscriptions` (Premium) dan status akun;
  - banner/pengumuman/FAQ/`app_settings`;
  - `can_read_media` (Premium & akun nonaktif);
  - validasi publikasi di server;
  - RPC admin dan impor.
- Kunci jawaban dan skor tidak pernah ditentukan klien.
- Webhook RevenueCat (`supabase/functions/revenuecat-webhook`) **nonaktif** sampai secret diisi.

## 6. Video & audio
Media berbentuk berkas di bucket privat. Database hanya menyimpan path dan metadata, tanpa Base64. Aplikasi memutar media lewat signed URL:
- video memakai `video_player` (kecepatan 0,5/0,75/1×, ulangi, layar penuh);
- audio juga memakai `video_player` (ExoPlayer, tanpa dependensi baru);
- gambar panduan via `SignedImage`.

Format yang didukung: MP4/WebM, MP3/M4A/AAC, JPG/PNG/WebP. **Tidak ada media AI**; semua media diunggah pemilik.

## 7. Pengujian
Rincian ada di `docs/TEST_REPORT_v1.1.0.md`, log di `docs/test-logs/`.

| Area | Hasil |
|---|---|
| Uji database lama (kompatibilitas 1.0.0) | 30/30 lulus |
| Uji database v1.1.0 | 80/80 lulus |
| Rollback | lulus |
| CMS E2E (Chromium) | 36/36 lulus |
| RevenueCat (logika pemetaan) | 8/8 lulus |
| `dart analyze` Flutter | 0 error, 0 warning |
| Tes unit logika baru | 26/26 lulus |
| Signing Gradle | lulus |

**Tidak bisa diuji di sesi ini** karena Flutter/Android SDK diblokir dan tidak ada perangkat:
- `flutter test` penuh dan `flutter build apk`;
- uji UI di HP;
- migrasi di Supabase asli.

Ketiganya dijalankan lewat GitHub Actions atau `tool\release.ps1`, dan daftar periksa HP ada di TEST_REPORT §5.

## 8. Yang belum selesai / butuh dari Anda
1. **Jalankan kueri cek lalu migrasi 0110–0120** di Supabase, sesuai urutan di CMS_SETUP §1. Aplikasi 1.1.0 membutuhkan migrasi ini. Kirim dulu hasil kueri cek `supabase/checks/00_cek_sebelum_migrasi_v110.sql`.
2. **Push source ini ke GitHub** dan isi secret `SUPABASE_URL` + `SUPABASE_ANON_KEY` agar APK ter-build (`docs/BUILD_APK.md`).
3. **Keystore release**: jalankan `tool\create_keystore.ps1` dan cadangkan. Isi secret `KEYSTORE_BASE64`/`KEYSTORE_PASSWORD` untuk APK resmi. Tanpa keystore, APK berlabel *debug-uji*.
4. **Keputusan `applicationId`**: `com.example.bisindo` ditolak Play Store. Bila ingin diganti, sebaiknya dilakukan sekarang (pengguna toh harus uninstall sekali).
5. **Materi BISINDO**: huruf, angka, kosakata, kalimat percakapan, soal, video, audio, gambar, dan teks FAQ/Premium. Isi lewat CMS atau impor CSV. Saat ini semua halaman menampilkan *Materi belum tersedia*.
6. **Akun admin**: jalankan langkah 2 di CMS_SETUP bila akun Anda belum berperan admin.
7. **RevenueCat**: kredensial dan product ID bila ingin pembayaran otomatis. Saat ini Premium diatur manual di CMS.
8. Push notification (FCM) **tidak** dibuat; notifikasi hanya dalam aplikasi (pengumuman). Cache video offline tidak dibuat (butuh paket tambahan); yang ada adalah cache daftar materi selama sesi.
9. Kebijakan privasi dan halaman syarat (syarat Play Store) masih dari pemilik.

## 9. Lokasi hasil
- **APK**: dibuat oleh GitHub Actions (tab Actions → Artifacts `bisindo-apk`) atau `build\app\outputs\flutter-apk\app-release.apk` bila build lokal. *APK tidak dapat dibuat di sesi cloud ini.*
- Source dengan riwayat commit: ZIP/bundle yang dikirim bersama laporan ini.
- Migrasi: `supabase/migrations/0110…0120`, rollback di `supabase/rollback/`.
- CMS: `cms/` beserta petunjuk `docs/CMS_SETUP.md`.
- Template impor kosong: `templates/import/`.

## 10. Langkah Anda berikutnya
Kueri cek → migrasi → push ke GitHub dan isi secrets → unduh APK dari Actions → uninstall APK lama → pasang dan uji sesuai TEST_REPORT §5 → isi materi lewat CMS.
