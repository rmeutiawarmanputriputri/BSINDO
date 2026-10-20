# Panduan Setup Supabase — BISINDO

Status migrasi: **diuji pada PostgreSQL 16 lokal dengan stub Supabase** (`supabase/tests/local/`), 29/29 uji RLS/Storage lulus.
**Belum diterapkan pada proyek Supabase sungguhan** — ikuti langkah berikut di proyek **DEV** dulu.

## 1. Buat proyek
1. https://supabase.com → New project → nama `bisindo-dev` (pisahkan dari prod, K-09).
2. Simpan *Project URL* dan *anon public key* (Settings → API). **Jangan** pernah memakai `service_role` key di aplikasi.

## 2. Terapkan skema (pilih salah satu)
**A. SQL Editor (paling mudah):** buka SQL Editor → New query → tempel seluruh isi `supabase/setup_all.sql` → Run. Lalu jalankan `supabase/seed/00_categories.sql`. Khusus proyek DEV, boleh juga `supabase/seed/10_dev_samples.sql` (data contoh berlabel, **DILARANG di produksi**).

**B. Supabase CLI:**
```bash
supabase link --project-ref <ref>
supabase db push          # menerapkan supabase/migrations/*
```

Verifikasi cepat:
```sql
select tablename, rowsecurity from pg_tables where schemaname = 'public' order by 1;  -- semua true
select id, public, file_size_limit from storage.buckets where id = 'bisindo-media';    -- public = false
```

## 3. Konfigurasi Auth (Dashboard → Authentication)
| Pengaturan | Nilai |
|---|---|
| Email provider | aktif; **Confirm email**: ON di prod (boleh OFF di dev) |
| Minimum password length | 8 |
| Site URL | `bisindo://auth-callback` |
| Redirect URLs | `bisindo://auth-callback` |
| Anonymous sign-ins | OFF |
| Google/Facebook/Apple | OFF (K-03) |
| SMTP | SMTP kustom sebelum uji pengguna nyata (SMTP bawaan sangat dibatasi, R-04) |
| Leaked password protection | ON bila tersedia di paket Anda |

Templat email (Authentication → Email Templates): tautan konfirmasi & reset memakai `{{ .ConfirmationURL }}` (bawaan) — aplikasi menangkap deep link `bisindo://auth-callback`.

## 4. Admin pertama
1. Daftar akun biasa lewat aplikasi.
2. SQL Editor:
```sql
update public.profiles set role = 'admin'
where id = (select id from auth.users where email = 'EMAIL_ADMIN_ANDA');
select id, role from public.profiles where role = 'admin';
```
3. Keluar lalu masuk lagi di aplikasi → menu **Admin** muncul di Profil.

## 5. Isi `env/dev.json`
```json
{ "SUPABASE_URL": "https://<ref>.supabase.co", "SUPABASE_ANON_KEY": "<anon key>" }
```

## 6. Uji RLS di proyek DEV (opsional, disarankan)
`supabase/tests/local/10_rls_tests.sql` dapat dijalankan di SQL Editor proyek DEV **setelah** migrasi (lewati `00_supabase_stub.sql`). Skrip membuat pengguna uji di `auth.users`, menampilkan tabel LULUS/GAGAL. Hapus data uji sesudahnya:
```sql
delete from auth.users where email like '%@test.local';
delete from public.signs where term in ('Terbit','Draf','Baru Admin');
delete from public.lessons where slug in ('uji','uji-draf');
delete from public.media_assets where path like 'signs/%/video-%.mp4';
delete from public.categories where slug = 'uji';
delete from storage.objects where name like 'signs/pub/%' or name like 'signs/draft/%';
drop schema t cascade;
```
> Catatan: menulis langsung ke `storage.objects` lewat SQL Editor mungkin dibatasi di versi Supabase terbaru — bila gagal, lewati baris ST-xx dan uji Storage dari aplikasi (unggah oleh admin, putar oleh pengguna).

## 7. Uji lokal (pengembang)
```bash
# PostgreSQL 16 lokal; stub meniru auth.uid(), role anon/authenticated, storage.objects
createdb bisindo_test
psql -d bisindo_test -f supabase/tests/local/00_supabase_stub.sql
for f in supabase/migrations/*.sql; do psql -v ON_ERROR_STOP=1 -d bisindo_test -f $f; done
psql -v ON_ERROR_STOP=1 -d bisindo_test -f supabase/tests/local/10_rls_tests.sql
```

## 8. Checklist pra-rilis
- `select count(*) from signs where validated_by like 'DEV-SAMPLE%';` → **0** di produksi.
- Confirm email ON, SMTP kustom, redirect URL benar.
- Tidak ada `service_role` di repo (`git grep -i service_role`).
- K-08 (Syarat & Privasi) dan K-10 (hapus akun) diputuskan.
