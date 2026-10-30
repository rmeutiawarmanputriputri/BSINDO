# CMS BISINDO v1.1.0 — Instalasi & Deploy

CMS adalah **web statis** (HTML/CSS/JS, tanpa *build step*, tanpa server PHP) di folder `cms/`.
CMS memakai **database, Storage, dan login Supabase yang SAMA** dengan aplikasi Android. Tidak ada database kedua atau sistem login kedua.

Keamanan ditegakkan **di database**, bukan di tampilan:
- Login memakai Supabase Auth. Setelah login, CMS memanggil RPC `assert_admin()`. Akun yang bukan admin aktif langsung dikeluarkan.
- Setiap penulisan konten dibatasi RLS `is_admin()`. Setiap RPC admin (`admin_*`, `media_usage`, `publish_issues`) memeriksa `is_admin()` di awal.
- Hasilnya, pengguna biasa yang memanggil API langsung (tanpa CMS) tetap ditolak. Ini sudah diuji: `20_v110_tests.sql` V-23 dan E2E CMS-99.
- CMS **hanya** berisi URL proyek dan anon/publishable key (kunci publik). **Service role key tidak pernah dipakai di CMS.**

---

## 1. Terapkan migrasi database (sekali)

> ⚠️ Jangan langsung ke produksi. Terapkan dulu di proyek **DEV/staging**, uji, cadangkan produksi, baru terapkan ke produksi.

Urutan file (masing-masing dijalankan **terpisah**; 0110 wajib berdiri sendiri karena menambah nilai enum):

```
supabase/migrations/0110_v110_enum_values.sql
supabase/migrations/0111_v110_settings_media.sql
supabase/migrations/0112_v110_content_extensions.sql
supabase/migrations/0113_v110_accounts_premium.sql
supabase/migrations/0114_v110_quiz_bank.sql
supabase/migrations/0115_v110_progress.sql
supabase/migrations/0116_v110_home_content.sql
supabase/migrations/0117_v110_access_rules.sql
supabase/migrations/0118_v110_publish_validation.sql
supabase/migrations/0119_v110_admin_rpc.sql
supabase/migrations/0120_v110_import.sql
```

Cara A (disarankan): Supabase CLI.
`supabase link --project-ref <ref>` lalu `supabase db push`. CLI hanya menjalankan migrasi yang belum tercatat.

Cara B: Dashboard → **SQL Editor**. Tempel isi tiap file sesuai urutan, lalu **Run** per file.

Opsional (struktur saja, tanpa materi): `supabase/seed/20_v110_struktur.sql`. File ini menambah kategori kosakata bawaan dan 9 topik percakapan bawaan sebagai **Draft kosong**. Aman dijalankan ulang.

Pemeriksaan setelah migrasi:
```sql
select count(*) from public.app_settings;                         -- 2
select public.can_read_media('x');                                -- false (fungsi ada)
select count(*) from public.signs where validated_by like 'DEV-SAMPLE%';  -- harus 0 di produksi
```

Rollback per file tersedia di `supabase/rollback/` (lihat README di folder itu).

## 2. Jadikan akun Anda admin (sekali)

1. Daftar/masuk sekali lewat aplikasi agar akun dan profil terbentuk.
2. Di SQL Editor (sebagai pemilik proyek):
```sql
update public.profiles set role = 'admin'
where id = (select id from auth.users where email = 'email-admin@domain-anda');
```
Admin berikutnya bisa ditambahkan dari CMS → **Pengguna → Detail → Jadikan admin**.

## 3. Konfigurasi CMS

```
cp cms/config.example.js cms/config.js
```
Isi `SUPABASE_URL` dan `SUPABASE_ANON_KEY` (nilai yang sama dengan `env/*.json` aplikasi). `config.js` sudah masuk `.gitignore`.

## 4. Menjalankan di komputer (lokal)

Pilih salah satu dari folder `cms/`:
```
python -m http.server 8080
npx serve -l 8080 .
```
Lalu buka `http://localhost:8080`. Jangan membuka `index.html` langsung lewat `file://`, karena ES module tidak jalan di sana.

## 5. Deploy ke hosting

CMS bisa di-host di hosting statis mana pun. Unggah **hanya** file berikut:
```
index.html  config.js  css/  js/  vendor/  assets/  (_headers atau .htaccess)
```
**Jangan** unggah `tests/`, `node_modules/`, `package*.json`.

| Hosting | Langkah |
|---|---|
| Netlify / Cloudflare Pages | Folder publikasi `cms`. `_headers` sudah berisi header keamanan (CSP, X-Frame-Options, noindex) |
| cPanel / Apache | Unggah ke subfolder, misalnya `public_html/cms-bisindo/`. `.htaccess` menolak listing folder dan berkas sensitif |
| Nginx | Sajikan folder statis, lalu salin header dari `_headers` ke blok `add_header` |

Wajib **HTTPS**. Disarankan juga membatasi akses URL CMS (Basic Auth hosting / IP allowlist) sebagai lapisan tambahan. Lapisan utama tetap RLS.

## 6. Media (video & audio)

- Bucket `bisindo-media` bersifat **privat**. Aplikasi dan CMS memutar media lewat *signed URL* yang berlaku 1 jam.
- Format untuk Android: **MP4 (H.264 + AAC)** atau WebM untuk video, **MP3 / M4A / AAC** untuk audio, JPG / PNG / WebP untuk gambar.
- Batas ukuran per jenis diatur di CMS → **Pengaturan** (default video 50 MB, audio 20 MB, gambar 5 MB). Batas keras bucket 50 MB. Paket gratis Supabase juga membatasi 50 MB per berkas.
- Saran kompresi video sebelum unggah: `ffmpeg -i in.mov -vf scale=-2:720 -c:v libx264 -crf 26 -preset slow -c:a aac -b:a 96k -movflags +faststart out.mp4`
- Hapus media: CMS menampilkan daftar materi yang memakainya. Materi Published yang mewajibkan media itu **tidak bisa** dilepas; server menolak.
- Ganti berkas: id media tetap sama, sehingga semua materi yang memakainya ikut berganti. Berkas lama dihapus otomatis.

## 7. Alur kerja konten

1. **Media** → unggah video/audio/gambar Anda.
2. **Alfabet / Angka / Kosakata / Percakapan / Kuis** → buat materi (bisa juga lewat **Impor massal** dari CSV/JSON, hasilnya masuk sebagai Draft).
3. Lengkapi sumber, validator, dan tanggal verifikasi, lalu **Simpan & Publikasikan**. Jika masih ada yang kurang, CMS menampilkan daftarnya dan materi tetap Draft.
4. Hanya status **Published** yang tampil di aplikasi. Status Draft, Archived, dan Inactive tidak tampil.

## 8. Premium

- Saat ini **manual**: CMS → Pengguna → Detail → *Premium aktif* (paket, tanggal berakhir).
- Tandai konten Premium lewat centang di form materi. Media konten Premium hanya bisa diputar pengguna Premium (ditegakkan oleh `can_read_media()`).
- Informasi paket (judul, deskripsi, harga tampil) diisi di CMS → **Premium**.
- **RevenueCat** (nanti), dalam keadaan nonaktif sampai langkah berikut dijalankan:
  ```
  supabase secrets set REVENUECAT_WEBHOOK_SECRET=<acak-panjang> REVENUECAT_ENTITLEMENT=premium
  supabase functions deploy revenuecat-webhook --no-verify-jwt
  ```
  Di RevenueCat → Integrations → Webhooks, isi URL `https://<ref>.supabase.co/functions/v1/revenuecat-webhook` dan header `Authorization: Bearer <secret>`. Aplikasi wajib memanggil `Purchases.logIn(<supabase user id>)`.

## 9. Pengujian lokal (untuk pengembang)

```
# Database: migrasi + 30 uji lama + 80 uji v1.1.0 + uji rollback
PGHOST=... PGPORT=... PGUSER=postgres bash supabase/tests/local/run_v110.sh

# CMS E2E (Chromium → supabase-js → emulator API lokal → PostgreSQL dengan migrasi asli)
cd cms && npm install && PGHOST=... PGPORT=... PGUSER=postgres bash tests/e2e/run_all.sh
```
Emulator di `cms/tests/shim/` **hanya untuk uji**. Emulator ini meniru subset PostgREST/Auth/Storage karena Docker/Supabase lokal tidak tersedia di lingkungan pembuatan. Pastikan juga ada uji manual sekali di proyek Supabase DEV.

## 10. Masalah umum

| Gejala | Penyebab / solusi |
|---|---|
| "Konfigurasi belum diisi" | `config.js` belum dibuat / masih contoh |
| "Akun ini bukan admin aktif" | Jalankan langkah 2, atau akun dinonaktifkan |
| Unggah gagal 413 | Berkas > batas bucket/paket. Kompres video |
| Unggah gagal "format ditolak" | MIME tidak diizinkan bucket. Pastikan migrasi 0111 sudah diterapkan |
| "Belum bisa dipublikasikan: …" | Lengkapi daftar yang ditampilkan (video, arti, validator, dsb.) |
| Video tidak bisa diputar di Android | Gunakan H.264 + AAC dan `-movflags +faststart` |
