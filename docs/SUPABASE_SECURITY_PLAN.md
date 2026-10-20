# SUPABASE_SECURITY_PLAN — BISINDO

> **STATUS: DRAF UNTUK DITINJAU.** SQL belum dieksekusi/diverifikasi. Perilaku Supabase (nama kode error, default grant, kebijakan Storage, batas SMTP) harus dicek terhadap dokumentasi dan proyek nyata saat implementasi.
> Melanjutkan migrasi `DATABASE_SCHEMA.md` (0001–0006).

## 1. Prinsip

1. **Default deny:** cabut semua hak, lalu beri hak minimum per tabel; RLS aktif di semua tabel `public`.
2. Klien hanya memegang **anon key** (publik by design). **Service role key tidak pernah** masuk Flutter, Git, log, atau dokumen.
3. Otorisasi admin = `public.is_admin()` yang membaca `profiles.role` di DB. **Jangan** memakai `user_metadata` atau klaim yang dapat diubah pengguna.
4. Semua input klien divalidasi ulang oleh constraint DB (panjang, enum, CHECK).
5. Operasi yang harus dipercaya (skor kuis) dijalankan server-side (RPC `security definer` dengan `search_path = ''`).
6. Tidak menyimpan audio/transkrip.

## 2. Konfigurasi Auth (dashboard — verifikasi manual)

| Pengaturan | Nilai |
|---|---|
| Sign-ups | aktif |
| Email confirmation | **aktif** di prod (boleh nonaktif di dev) |
| Min. panjang sandi | 8 (selaras UI) |
| Site URL / Redirect URLs | tambahkan `bisindo://auth-callback` (+ URL dev bila perlu) |
| Anonymous sign-ins | nonaktif |
| Provider sosial | nonaktif (K-03) |
| SMTP | SMTP kustom sebelum uji pengguna nyata (SMTP bawaan terbatas; R-04) |
| Proteksi kata sandi bocor / CAPTCHA | aktifkan bila paket mendukung |
| Rate limit | tinjau default |

Android: `AndroidManifest.xml` perlu intent-filter skema `bisindo`, host `auth-callback` (lihat FLUTTER_ARCHITECTURE §10).

## 3. Migrasi 0007 — Grants + RLS

```sql
-- 3.1 Default deny
revoke all on all tables    in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;
alter default privileges in schema public revoke all on tables from anon, authenticated;

-- 3.2 Aktifkan RLS
alter table public.profiles             enable row level security;
alter table public.categories           enable row level security;
alter table public.media_assets         enable row level security;
alter table public.signs                enable row level security;
alter table public.conversation_modules enable row level security;
alter table public.conversation_items   enable row level security;
alter table public.lessons              enable row level security;
alter table public.lesson_items         enable row level security;
alter table public.quizzes              enable row level security;
alter table public.questions            enable row level security;
alter table public.question_options     enable row level security;
alter table public.question_answer_keys enable row level security;
alter table public.quiz_attempts        enable row level security;
alter table public.user_progress        enable row level security;
alter table public.favorites            enable row level security;
alter table public.difficult_vocabulary enable row level security;
alter table public.content_reports      enable row level security;

-- 3.3 Grants (RLS tetap membatasi baris)
-- Profil: baca; ubah HANYA full_name (role tidak bisa diubah klien)
grant select on public.profiles to authenticated;
grant update (full_name) on public.profiles to authenticated;

-- Konten: pengguna membaca; admin menulis (dibatasi policy)
grant select, insert, update, delete on
  public.categories, public.media_assets, public.signs,
  public.conversation_modules, public.conversation_items,
  public.lessons, public.lesson_items, public.quizzes,
  public.questions, public.question_options, public.question_answer_keys
to authenticated;

-- Data pribadi
grant select on public.quiz_attempts to authenticated;          -- insert hanya via RPC
grant select, insert, update on public.user_progress to authenticated;
grant select, insert, delete on public.favorites to authenticated;
grant select, insert, update, delete on public.difficult_vocabulary to authenticated;
grant select, insert, update on public.content_reports to authenticated; -- update dibatasi policy admin
```

### 3.4 Policy

```sql
-- profiles
create policy profiles_select on public.profiles for select to authenticated
  using (id = (select auth.uid()) or public.is_admin());
create policy profiles_update_own on public.profiles for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));
-- Tidak ada policy insert/delete: profil dibuat trigger, dihapus via cascade.
-- Hanya kolom full_name yang diberi grant update -> role tidak dapat dinaikkan klien.

-- Konten: baca (published / aktif), admin kelola
create policy categories_read on public.categories for select to authenticated
  using (is_active or public.is_admin());
create policy categories_admin on public.categories for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy signs_read on public.signs for select to authenticated
  using (status = 'published' or public.is_admin());
create policy signs_admin on public.signs for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy conv_modules_read on public.conversation_modules for select to authenticated
  using (status = 'published' or public.is_admin());
create policy conv_modules_admin on public.conversation_modules for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy conv_items_read on public.conversation_items for select to authenticated
  using (public.is_admin() or exists (
    select 1 from public.conversation_modules m
    where m.id = module_id and m.status = 'published'));
create policy conv_items_admin on public.conversation_items for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy lessons_read on public.lessons for select to authenticated
  using (status = 'published' or public.is_admin());
create policy lessons_admin on public.lessons for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy lesson_items_read on public.lesson_items for select to authenticated
  using (public.is_admin() or exists (
    select 1 from public.lessons l where l.id = lesson_id and l.status = 'published'));
create policy lesson_items_admin on public.lesson_items for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy quizzes_read on public.quizzes for select to authenticated
  using (public.is_admin() or (is_active and exists (
    select 1 from public.lessons l where l.id = lesson_id and l.status = 'published')));
create policy quizzes_admin on public.quizzes for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy questions_read on public.questions for select to authenticated
  using (public.is_admin() or exists (
    select 1 from public.quizzes z join public.lessons l on l.id = z.lesson_id
    where z.id = quiz_id and z.is_active and l.status = 'published'));
create policy questions_admin on public.questions for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy options_read on public.question_options for select to authenticated
  using (public.is_admin() or exists (
    select 1 from public.questions q
    join public.quizzes z on z.id = q.quiz_id
    join public.lessons l on l.id = z.lesson_id
    where q.id = question_id and z.is_active and l.status = 'published'));
create policy options_admin on public.question_options for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- Kunci jawaban: TIDAK ada policy untuk pengguna biasa -> tertutup. Hanya admin.
create policy answer_keys_admin on public.question_answer_keys for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy media_read on public.media_assets for select to authenticated
  using (public.can_read_media(path));
create policy media_admin on public.media_assets for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- Data pribadi
create policy attempts_select_own on public.quiz_attempts for select to authenticated
  using (user_id = (select auth.uid()) or public.is_admin());
-- (tanpa policy insert/update/delete: hanya RPC security definer yang menulis)

create policy progress_select_own on public.user_progress for select to authenticated
  using (user_id = (select auth.uid()));
create policy progress_insert_own on public.user_progress for insert to authenticated
  with check (user_id = (select auth.uid()));
create policy progress_update_own on public.user_progress for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

create policy favorites_select_own on public.favorites for select to authenticated
  using (user_id = (select auth.uid()));
create policy favorites_insert_own on public.favorites for insert to authenticated
  with check (user_id = (select auth.uid()));
create policy favorites_delete_own on public.favorites for delete to authenticated
  using (user_id = (select auth.uid()));

create policy difficult_select_own on public.difficult_vocabulary for select to authenticated
  using (user_id = (select auth.uid()));
create policy difficult_insert_own on public.difficult_vocabulary for insert to authenticated
  with check (user_id = (select auth.uid()));
create policy difficult_update_own on public.difficult_vocabulary for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy difficult_delete_own on public.difficult_vocabulary for delete to authenticated
  using (user_id = (select auth.uid()));

-- Laporan
create policy reports_select on public.content_reports for select to authenticated
  using (reporter_id = (select auth.uid()) or public.is_admin());
create policy reports_insert_own on public.content_reports for insert to authenticated
  with check (
    reporter_id = (select auth.uid())
    and status = 'open'
    and resolution_message is null and resolved_by is null and resolved_at is null);
create policy reports_update_admin on public.content_reports for update to authenticated
  using (public.is_admin()) with check (public.is_admin());
-- Pengguna biasa: tidak ada policy update/delete -> tidak dapat mengubah status/pesan.
```

Catatan: pengguna dapat mengunggah `favorites`/`difficult_vocabulary` untuk `sign_id` yang tidak published (FK saja yang memeriksa keberadaan). Dampak rendah (hanya baris milik sendiri, tidak membuka konten karena SELECT `signs` tetap difilter RLS). Opsional: tambahkan `exists(... published)` pada `with check`.

## 4. Migrasi 0008 — Storage

```sql
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('bisindo-media', 'bisindo-media', false, 20971520,
        array['video/mp4','video/webm','image/jpeg','image/png','image/webp'])
on conflict (id) do update
  set public = false,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- Pengguna login membaca hanya berkas yang dipakai konten published (atau admin)
create policy "bisindo_media_read" on storage.objects for select to authenticated
  using (bucket_id = 'bisindo-media' and public.can_read_media(name));

create policy "bisindo_media_admin_insert" on storage.objects for insert to authenticated
  with check (bucket_id = 'bisindo-media' and public.is_admin());
create policy "bisindo_media_admin_update" on storage.objects for update to authenticated
  using (bucket_id = 'bisindo-media' and public.is_admin())
  with check (bucket_id = 'bisindo-media' and public.is_admin());
create policy "bisindo_media_admin_delete" on storage.objects for delete to authenticated
  using (bucket_id = 'bisindo-media' and public.is_admin());
```

**Keputusan bucket:** privat + signed URL (TTL 2 jam) karena draft/belum tervalidasi tidak boleh dapat diakses publik. Konsekuensi: tidak ada cache CDN publik, perlu panggilan `createSignedUrl` per video. Jika performa/biaya bermasalah, alternatifnya: bucket publik terpisah `bisindo-published` hanya untuk aset yang sudah `published` (disalin saat publikasi). Jangan beralih tanpa keputusan.

### Penamaan & struktur
```
bisindo-media/
  signs/{sign_id}/video-{asset_id}.mp4
  signs/{sign_id}/thumb-{asset_id}.webp
  conversations/{module_id}/cover-{asset_id}.webp
  conversations/{module_id}/items/{item_id}-{asset_id}.mp4
  lessons/{lesson_id}/cover-{asset_id}.webp
```
Huruf kecil, tanpa spasi, ekstensi sesuai MIME. `asset_id` = UUID `media_assets.id` (path tak dapat ditebak, dan mudah diganti).

## 5. Bootstrap admin pertama (aman)

1. Daftar akun biasa lewat aplikasi (role otomatis `user`).
2. Di Supabase **SQL Editor** (dijalankan sebagai pemilik, bukan oleh klien):
```sql
update public.profiles
set role = 'admin'
where id = (select id from auth.users where email = 'EMAIL_ADMIN@contoh.com');
```
3. Verifikasi: `select id, role from public.profiles where role = 'admin';`
4. Tidak ada endpoint/RPC publik untuk menjadi admin. Penambahan admin berikutnya dengan cara yang sama. Admin minimal (1–2 akun), email terverifikasi, sandi kuat.
5. Karena klien tidak punya grant `update(role)` dan tidak ada policy insert profil, percobaan eskalasi lewat API harus gagal (diuji di §9).

## 6. Unggah, penggantian, dan berkas hilang

**Unggah (admin):** validasi klien (ekstensi, MIME, ukuran ≤ 20 MB, durasi bila terbaca) → buat `asset_id` (UUID) → upload ke path §4 dengan `upsert:false` → insert `media_assets` (path, mime, size, durasi) → update baris konten (`video_asset_id`). Jika langkah DB gagal setelah upload → hapus objek yang baru diunggah (best-effort) dan laporkan.
**Penggantian:** unggah aset **baru** → tautkan → setelah sukses, hapus baris `media_assets` lama + objeknya. Pengguna yang sedang memutar tidak rusak seketika (signed URL lama tetap hidup sampai kedaluwarsa).
**Berkas hilang (404/signed URL gagal):** UI menampilkan "Video tidak ditemukan" + opsi Laporkan; admin dapat memindai `media_assets` yatim dengan skrip/daftar objek (di luar MVP otomatis).
**Spesifikasi video (D-13):** MP4 H.264/AAC (audio boleh dihilangkan), ≤720p (target 480p), ~1–2 Mbps, **`-movflags +faststart`**, durasi pendek per gerakan; thumbnail WebP/JPEG ≤ 150 KB. Contoh perintah ffmpeg disimpan di `docs/media_guidelines.md` oleh Claude Work (tidak dijalankan otomatis).
**Slow network:** poster dulu, tanpa autoplay, indikator buffering, tombol coba lagi, signed URL baru saat kegagalan.

## 7. Pengelolaan kunci & konfigurasi

- Flutter: hanya `SUPABASE_URL` dan `SUPABASE_ANON_KEY` lewat `--dart-define-from-file=env/dev.json`.
- `.gitignore`: `env/*.json` (kecuali `env/example.json`), `*.keystore`, `key.properties`, `.env*`.
- Service role key hanya untuk skrip server/Edge Function di mesin terpercaya; Claude Work tidak boleh meminta atau menuliskannya ke repo/chat.
- Jika ada kunci yang bocor ke Git: anggap kompromi, rotasi di dashboard.

## 8. Model ancaman ringkas

| Ancaman | Kontrol |
|---|---|
| Pengguna menaikkan role sendiri | Tidak ada grant `update(role)`; tidak ada policy insert profil; trigger memaksa `user` |
| Pengguna membaca/mengubah data pengguna lain | RLS `user_id = auth.uid()` |
| Pengguna membaca kunci jawaban | Tabel kunci tanpa policy pengguna; hasil jawaban hanya dari RPC setelah submit |
| Manipulasi skor kuis | Tidak ada insert langsung ke `quiz_attempts`; RPC menghitung |
| Pengguna menerbitkan/mengubah konten | Policy tulis hanya `is_admin()` |
| Akses draft/video belum tervalidasi | RLS `status='published'`; bucket privat + `can_read_media` |
| Spam laporan | Unik laporan terbuka + batas 10/24 jam + panjang teks dibatasi |
| Eskalasi via `SECURITY DEFINER` | `search_path=''`, `revoke ... from public`, grant hanya ke `authenticated` |
| Kebocoran kunci | §7 |
| Enumerasi email | Pesan reset sandi netral; pesan login generik |
| Unggahan berbahaya | Batas ukuran + MIME bucket + validasi klien; hanya admin |
| Penyimpanan audio/transkrip | Tidak ada tabel/endpoint; tidak ada log teks |

## 9. Matriks uji RLS (dijalankan di dev; bukti wajib)

Peran uji: `anon`, `user A`, `user B`, `admin`. Metode: pgTAP (`supabase test db`) atau skrip SQL dengan `set local role authenticated; set local request.jwt.claims = '{"sub":"<uuid>","role":"authenticated"}'`, atau skrip klien Dart/curl dengan JWT sungguhan.

| ID | Skenario | Hasil yang diharapkan |
|---|---|---|
| RLS-01 | `anon` select `signs` | 0 baris / ditolak |
| RLS-02 | user A select `signs` | hanya `published` |
| RLS-03 | user A insert/update/delete `signs` | ditolak |
| RLS-04 | admin insert sign `draft`, lalu set `published` tanpa validator | ditolak CHECK; dengan validator berhasil |
| RLS-05 | user A `update profiles set role='admin'` | ditolak (privilege) |
| RLS-06 | user A insert ke `profiles` | ditolak |
| RLS-07 | user A update `full_name` miliknya | berhasil; milik B → 0 baris |
| RLS-08 | user A select `question_answer_keys` | 0 baris/ditolak |
| RLS-09 | user A insert langsung `quiz_attempts` | ditolak |
| RLS-10 | `submit_quiz_attempt` dengan jawaban benar/salah/kosong/option asing | skor benar; tidak error; tidak membocorkan pada kuis tak aktif |
| RLS-11 | user A select `favorites`/`difficult_vocabulary`/`user_progress` milik B | 0 baris |
| RLS-12 | insert duplikat `difficult_vocabulary` (A, sign X) dua kali | kedua: unik menolak / upsert tanpa duplikat |
| RLS-13 | user A insert `content_reports` dengan `status='resolved'` atau `reporter_id` B | ditolak |
| RLS-14 | user A update status laporannya | ditolak |
| RLS-15 | laporan ke-11 dalam 24 jam | ditolak (`report_rate_limited`) |
| RLS-16 | laporan terbuka ganda (kategori+target sama) | ditolak |
| RLS-17 | admin update laporan + `resolution_message` | berhasil |
| ST-01 | user A createSignedUrl untuk video milik sign `draft` | ditolak |
| ST-02 | user A createSignedUrl video sign `published` | berhasil |
| ST-03 | user A upload/delete di bucket | ditolak |
| ST-04 | admin upload MIME/ukuran di luar batas | ditolak bucket |
| ST-05 | `anon` list/baca objek | ditolak |
