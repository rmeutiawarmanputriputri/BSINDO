# DATABASE_SCHEMA — BISINDO (PostgreSQL / Supabase)

> **STATUS: DRAF UNTUK DITINJAU. SQL di bawah BELUM dieksekusi dan BELUM diverifikasi pada database mana pun.** Claude Work wajib menjalankannya pada proyek **dev** (atau Supabase lokal), memperbaiki kesalahan sintaks, dan melaporkan hasil sebenarnya. Jangan klaim "migrasi berhasil" tanpa output eksekusi.
> Migrasi 0007 (grants + RLS) dan 0008 (storage) ada di `SUPABASE_SECURITY_PLAN.md`. Urutan: 0001 → 0008.

## 1. Ringkasan entitas

| Tabel | Fungsi | Catatan keputusan |
|---|---|---|
| `profiles` | 1:1 dengan `auth.users`; nama + role | Dibuat trigger; role tidak bisa diubah klien |
| `categories` | Kategori kosakata & percakapan | `is_active` |
| `media_assets` | Metadata berkas di Storage | D-05 |
| `signs` | Kosakata **dan frasa** (`entry_type`) | `phrases` digabung (D-04) |
| `conversation_modules`, `conversation_items` | Modul & dialog | item bisa memakai video milik `signs` atau videonya sendiri |
| `lessons`, `lesson_items` | Pelajaran & isinya | item = sign / modul percakapan / teks |
| `quizzes`, `questions`, `question_options`, `question_answer_keys` | Kuis; kunci terpisah | D-07 |
| `quiz_attempts` | Riwayat percobaan | hanya dibuat oleh RPC |
| `user_progress` | Progres pelajaran/modul + materi terakhir | D-16 |
| `favorites` | Favorit | PK komposit |
| `difficult_vocabulary` | Kosakata sulit pribadi | unik `(user_id, sign_id)` |
| `content_reports` | Laporan konten | tanpa catatan internal (hanya `resolution_message` yang terlihat pengguna) |

Tidak ada tabel untuk transkripsi/audio (sengaja).

### Relasi inti
`auth.users 1—1 profiles` · `categories 1—* signs / conversation_modules` · `media_assets 1—* signs/items` · `conversation_modules 1—* conversation_items *—0..1 signs` · `lessons 1—* lesson_items`, `lessons 1—0..1 quizzes 1—* questions 1—* question_options`, `questions 1—1 question_answer_keys` · `profiles 1—* user_progress/favorites/difficult_vocabulary/quiz_attempts/content_reports`.

### Aturan penghapusan
- Data pribadi pengguna: `ON DELETE CASCADE` dari `profiles` (dan `profiles` dari `auth.users`).
- `content_reports.reporter_id`: `SET NULL` (riwayat moderasi tetap, anonim).
- Referensi media: `SET NULL` (konten tetap ada, video menjadi "belum tersedia").
- `categories`: `RESTRICT` (tidak bisa dihapus bila dipakai).
- Konten utama sebaiknya **diarsipkan** (`archived`), bukan dihapus; penghapusan konten induk men-cascade item/pertanyaan.

## 2. Migrasi

### 0001_extensions_types.sql

```sql
create extension if not exists pg_trgm with schema extensions;

create type public.app_role         as enum ('user', 'admin');
create type public.content_status   as enum ('draft', 'in_review', 'verified', 'published', 'archived');
create type public.sign_entry_type  as enum ('word', 'phrase');
create type public.media_kind       as enum ('video', 'image');
create type public.progress_status  as enum ('in_progress', 'completed');
create type public.difficult_status as enum ('learning', 'relearned');
create type public.report_category  as enum ('wrong_sign', 'wrong_meaning', 'video_problem', 'wrong_example', 'other');
create type public.report_status    as enum ('open', 'in_review', 'resolved', 'rejected');

create or replace function public.set_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.updated_at = now();
  return new;
end $$;
```

### 0002_profiles_auth.sql

```sql
create table public.profiles (
  id         uuid primary key references auth.users (id) on delete cascade,
  full_name  text not null check (char_length(btrim(full_name)) between 2 and 80),
  role       public.app_role not null default 'user',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Profil dibuat otomatis. Role SELALU 'user' (tidak pernah dibaca dari metadata klien).
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_name text;
begin
  v_name := btrim(coalesce(new.raw_user_meta_data ->> 'full_name', ''));
  if char_length(v_name) < 2 then v_name := 'Pengguna'; end if;
  v_name := left(v_name, 80);
  insert into public.profiles (id, full_name) values (new.id, v_name);
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

revoke all on function public.handle_new_user() from public, anon, authenticated;

-- Pemeriksaan admin di backend. Tidak membaca JWT/user_metadata (bisa dimanipulasi).
create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.role = 'admin'
  );
$$;
revoke all on function public.is_admin() from public, anon;
grant execute on function public.is_admin() to authenticated;
```

### 0003_content_tables.sql

```sql
create table public.categories (
  id          uuid primary key default gen_random_uuid(),
  slug        text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  name        text not null check (char_length(btrim(name)) between 1 and 80),
  kind        text not null default 'sign' check (kind in ('sign', 'conversation')),
  description text,
  icon_key    text,
  sort_order  int  not null default 0,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table public.media_assets (
  id          uuid primary key default gen_random_uuid(),
  kind        public.media_kind not null,
  bucket      text not null default 'bisindo-media',
  path        text not null unique,
  mime_type   text not null,
  size_bytes  bigint not null check (size_bytes > 0 and size_bytes <= 20971520),
  duration_ms int check (duration_ms is null or duration_ms > 0),
  width       int check (width  is null or width  > 0),
  height      int check (height is null or height > 0),
  uploaded_by uuid references public.profiles (id) on delete set null,
  created_at  timestamptz not null default now(),
  constraint media_mime_matches_kind check (
    (kind = 'video' and mime_type in ('video/mp4', 'video/webm')) or
    (kind = 'image' and mime_type in ('image/jpeg', 'image/png', 'image/webp'))
  )
);

create table public.signs (
  id                  uuid primary key default gen_random_uuid(),
  entry_type          public.sign_entry_type not null default 'word',
  category_id         uuid references public.categories (id) on delete restrict,
  term                text not null check (char_length(btrim(term)) between 1 and 120),
  term_normalized     text generated always as (lower(btrim(term))) stored,
  meaning             text check (char_length(meaning) <= 1000),
  movement_description text check (char_length(movement_description) <= 2000),
  usage_example       text check (char_length(usage_example) <= 500),
  video_asset_id      uuid references public.media_assets (id) on delete set null,
  thumbnail_asset_id  uuid references public.media_assets (id) on delete set null,
  source_note         text,
  validated_by        text,
  verified_at         timestamptz,
  status              public.content_status not null default 'draft',
  created_by          uuid references public.profiles (id) on delete set null,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  constraint signs_validation_required check (
    status not in ('verified', 'published')
    or (validated_by is not null and btrim(validated_by) <> ''
        and verified_at is not null
        and source_note is not null and btrim(source_note) <> '')
  )
);
create index signs_status_category_idx on public.signs (status, category_id);
create index signs_term_trgm_idx on public.signs using gin (term_normalized extensions.gin_trgm_ops);

create table public.conversation_modules (
  id                 uuid primary key default gen_random_uuid(),
  slug               text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  category_id        uuid references public.categories (id) on delete restrict,
  title              text not null check (char_length(btrim(title)) between 1 and 120),
  description        text,
  context_note       text,                       -- konteks penggunaan
  thumbnail_asset_id uuid references public.media_assets (id) on delete set null,
  sort_order         int not null default 0,
  source_note        text,
  validated_by       text,
  verified_at        timestamptz,
  status             public.content_status not null default 'draft',
  created_by         uuid references public.profiles (id) on delete set null,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  constraint conv_validation_required check (
    status not in ('verified', 'published')
    or (validated_by is not null and btrim(validated_by) <> ''
        and verified_at is not null
        and source_note is not null and btrim(source_note) <> '')
  )
);
create index conv_modules_status_idx on public.conversation_modules (status, category_id, sort_order);

create table public.conversation_items (
  id             uuid primary key default gen_random_uuid(),
  module_id      uuid not null references public.conversation_modules (id) on delete cascade,
  position       int  not null check (position >= 0),
  speaker_label  text not null default 'A' check (char_length(speaker_label) <= 30),
  text_id        text not null check (char_length(btrim(text_id)) between 1 and 500),  -- kalimat Indonesia
  sign_id        uuid references public.signs (id) on delete set null,
  video_asset_id uuid references public.media_assets (id) on delete set null,
  context_note   text,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  constraint conv_items_position_uniq unique (module_id, position) deferrable initially deferred
);
```

### 0004_learning_tables.sql

```sql
create table public.lessons (
  id                 uuid primary key default gen_random_uuid(),
  slug               text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  title              text not null check (char_length(btrim(title)) between 1 and 120),
  description        text,
  thumbnail_asset_id uuid references public.media_assets (id) on delete set null,
  sort_order         int not null default 0,
  source_note        text,
  validated_by       text,
  verified_at        timestamptz,
  status             public.content_status not null default 'draft',
  created_by         uuid references public.profiles (id) on delete set null,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  constraint lessons_validation_required check (
    status not in ('verified', 'published')
    or (validated_by is not null and btrim(validated_by) <> ''
        and verified_at is not null
        and source_note is not null and btrim(source_note) <> '')
  )
);
create index lessons_status_idx on public.lessons (status, sort_order);

create table public.lesson_items (
  id                     uuid primary key default gen_random_uuid(),
  lesson_id              uuid not null references public.lessons (id) on delete cascade,
  position               int  not null check (position >= 0),
  item_type              text not null check (item_type in ('sign', 'conversation_module', 'text')),
  sign_id                uuid references public.signs (id) on delete cascade,
  conversation_module_id uuid references public.conversation_modules (id) on delete cascade,
  body_text              text,
  constraint lesson_items_position_uniq unique (lesson_id, position) deferrable initially deferred,
  constraint lesson_items_shape check (
    (item_type = 'sign'                and sign_id is not null and conversation_module_id is null and body_text is null) or
    (item_type = 'conversation_module' and conversation_module_id is not null and sign_id is null and body_text is null) or
    (item_type = 'text'                and body_text is not null and sign_id is null and conversation_module_id is null)
  )
);

create table public.quizzes (
  id                 uuid primary key default gen_random_uuid(),
  lesson_id          uuid not null unique references public.lessons (id) on delete cascade,
  title              text not null check (char_length(btrim(title)) between 1 and 120),
  pass_score_percent int  not null default 70 check (pass_score_percent between 1 and 100),
  is_active          boolean not null default true,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

create table public.questions (
  id            uuid primary key default gen_random_uuid(),
  quiz_id       uuid not null references public.quizzes (id) on delete cascade,
  position      int  not null check (position >= 0),
  prompt        text not null check (char_length(btrim(prompt)) between 1 and 500),
  question_type text not null default 'multiple_choice' check (question_type = 'multiple_choice'),
  sign_id       uuid references public.signs (id) on delete set null,   -- soal berbasis video
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  constraint questions_position_uniq unique (quiz_id, position) deferrable initially deferred
);

create table public.question_options (
  id          uuid primary key default gen_random_uuid(),
  question_id uuid not null references public.questions (id) on delete cascade,
  position    int  not null check (position >= 0),
  label       text not null check (char_length(btrim(label)) between 1 and 200),
  constraint options_position_uniq unique (question_id, position) deferrable initially deferred,
  constraint options_id_question_uniq unique (id, question_id)
);

-- Kunci jawaban: TIDAK dapat dibaca pengguna biasa (lihat 0007).
create table public.question_answer_keys (
  question_id       uuid primary key references public.questions (id) on delete cascade,
  correct_option_id uuid not null,
  explanation       text,
  constraint answer_key_option_belongs foreign key (correct_option_id, question_id)
    references public.question_options (id, question_id)
);

create table public.quiz_attempts (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.profiles (id) on delete cascade,
  quiz_id       uuid not null references public.quizzes (id) on delete cascade,
  score_percent int  not null check (score_percent between 0 and 100),
  correct_count int  not null check (correct_count >= 0),
  total_count   int  not null check (total_count > 0),
  passed        boolean not null,
  answers       jsonb not null,       -- [{question_id, selected_option_id, is_correct}]
  submitted_at  timestamptz not null default now()
);
create index quiz_attempts_user_quiz_idx on public.quiz_attempts (user_id, quiz_id, submitted_at desc);

create table public.user_progress (
  id                     uuid primary key default gen_random_uuid(),
  user_id                uuid not null references public.profiles (id) on delete cascade,
  lesson_id              uuid references public.lessons (id) on delete cascade,
  conversation_module_id uuid references public.conversation_modules (id) on delete cascade,
  status                 public.progress_status not null default 'in_progress',
  progress_percent       int  not null default 0 check (progress_percent between 0 and 100),
  last_position          int  not null default 0 check (last_position >= 0),
  completed_at           timestamptz,
  last_accessed_at       timestamptz not null default now(),
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now(),
  constraint progress_one_target check (num_nonnulls(lesson_id, conversation_module_id) = 1),
  constraint progress_completed_consistent check ((status = 'completed') = (completed_at is not null))
);
create unique index user_progress_lesson_uniq
  on public.user_progress (user_id, lesson_id) where lesson_id is not null;
create unique index user_progress_module_uniq
  on public.user_progress (user_id, conversation_module_id) where conversation_module_id is not null;
create index user_progress_recent_idx on public.user_progress (user_id, last_accessed_at desc);
```

### 0005_user_data_tables.sql

```sql
create table public.favorites (
  user_id    uuid not null references public.profiles (id) on delete cascade,
  sign_id    uuid not null references public.signs (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, sign_id)
);
create index favorites_user_recent_idx on public.favorites (user_id, created_at desc);

create table public.difficult_vocabulary (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references public.profiles (id) on delete cascade,
  sign_id          uuid not null references public.signs (id) on delete cascade,
  status           public.difficult_status not null default 'learning',
  note             text check (char_length(note) <= 200),
  review_count     int not null default 0 check (review_count >= 0),
  marked_at        timestamptz not null default now(),
  last_reviewed_at timestamptz,
  relearned_at     timestamptz,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  constraint difficult_unique_per_user unique (user_id, sign_id),
  constraint difficult_relearned_consistent check (status = 'learning' or relearned_at is not null)
);
create index difficult_user_status_idx on public.difficult_vocabulary (user_id, status, last_reviewed_at nulls first);

create table public.content_reports (
  id                     uuid primary key default gen_random_uuid(),
  reporter_id            uuid references public.profiles (id) on delete set null,
  sign_id                uuid references public.signs (id) on delete cascade,
  conversation_module_id uuid references public.conversation_modules (id) on delete cascade,
  lesson_id              uuid references public.lessons (id) on delete cascade,
  category               public.report_category not null,
  description            text check (char_length(description) <= 1000),
  status                 public.report_status not null default 'open',
  resolution_message     text check (char_length(resolution_message) <= 500),  -- TERLIHAT oleh pelapor
  resolved_by            uuid references public.profiles (id) on delete set null,
  resolved_at            timestamptz,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now(),
  constraint report_one_target check (num_nonnulls(sign_id, conversation_module_id, lesson_id) = 1),
  constraint report_other_needs_text check (
    category <> 'other' or char_length(btrim(coalesce(description, ''))) >= 5
  ),
  constraint report_closed_has_resolved_at check (
    status not in ('resolved', 'rejected') or resolved_at is not null
  )
);
create index content_reports_reporter_idx on public.content_reports (reporter_id, created_at desc);
create index content_reports_status_idx   on public.content_reports (status, created_at desc);
-- Satu laporan terbuka per (pelapor, kategori, target)
create unique index content_reports_open_unique
  on public.content_reports (reporter_id, category, coalesce(sign_id, conversation_module_id, lesson_id))
  where status in ('open', 'in_review');

-- Batas 10 laporan per 24 jam per pengguna
create or replace function public.limit_report_rate()
returns trigger language plpgsql set search_path = '' as $$
begin
  if (select count(*) from public.content_reports
        where reporter_id = new.reporter_id
          and created_at > now() - interval '24 hours') >= 10 then
    raise exception 'report_rate_limited' using errcode = 'P0001';
  end if;
  return new;
end $$;
create trigger content_reports_rate_limit
  before insert on public.content_reports
  for each row execute function public.limit_report_rate();

-- Trigger updated_at
do $$
declare t text;
begin
  foreach t in array array[
    'profiles','categories','signs','conversation_modules','conversation_items',
    'lessons','quizzes','questions','user_progress','difficult_vocabulary','content_reports'
  ] loop
    execute format(
      'create trigger set_updated_at before update on public.%I
         for each row execute function public.set_updated_at()', t);
  end loop;
end $$;
```

### 0006_functions.sql

```sql
-- Apakah berkas Storage boleh dibaca pengguna? (admin, atau dipakai konten published)
create or replace function public.can_read_media(p_path text)
returns boolean language sql stable security definer set search_path = '' as $$
  select public.is_admin() or exists (
    select 1 from public.media_assets m
    where m.path = p_path and (
      exists (select 1 from public.signs s
              where s.status = 'published' and m.id in (s.video_asset_id, s.thumbnail_asset_id))
      or exists (select 1 from public.conversation_modules c
                 where c.status = 'published' and c.thumbnail_asset_id = m.id)
      or exists (select 1 from public.conversation_items i
                 join public.conversation_modules c on c.id = i.module_id
                 where c.status = 'published' and i.video_asset_id = m.id)
      or exists (select 1 from public.lessons l
                 where l.status = 'published' and l.thumbnail_asset_id = m.id)
    )
  );
$$;
revoke all on function public.can_read_media(text) from public, anon;
grant execute on function public.can_read_media(text) to authenticated;

-- Penilaian kuis di server
create or replace function public.submit_quiz_attempt(p_quiz_id uuid, p_answers jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_uid     uuid := auth.uid();
  v_pass    int;
  v_lesson  uuid;
  v_total   int;
  v_correct int;
  v_score   int;
  v_passed  boolean;
  v_detail  jsonb;
  v_attempt uuid;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  if p_answers is null or jsonb_typeof(p_answers) <> 'array' or jsonb_array_length(p_answers) > 100 then
    raise exception 'invalid_answers' using errcode = '22023';
  end if;

  select z.pass_score_percent, z.lesson_id into v_pass, v_lesson
  from public.quizzes z
  join public.lessons l on l.id = z.lesson_id
  where z.id = p_quiz_id and z.is_active and l.status = 'published';
  if not found then
    raise exception 'quiz_not_available' using errcode = 'P0002';
  end if;

  with given as (
    select distinct on (question_id) question_id, option_id
    from (
      select (a ->> 'question_id')::uuid as question_id,
             (a ->> 'option_id')::uuid   as option_id
      from jsonb_array_elements(p_answers) a
    ) x
    order by question_id
  ), graded as (
    select qu.id as question_id, qu.position, g.option_id,
           k.correct_option_id, k.explanation,
           (g.option_id is not null and g.option_id = k.correct_option_id) as is_correct
    from public.questions qu
    join public.question_answer_keys k on k.question_id = qu.id
    left join given g on g.question_id = qu.id
    where qu.quiz_id = p_quiz_id
  )
  select count(*)::int,
         (count(*) filter (where is_correct))::int,
         jsonb_agg(jsonb_build_object(
           'question_id', question_id,
           'selected_option_id', option_id,
           'correct_option_id', correct_option_id,
           'is_correct', is_correct,
           'explanation', explanation) order by position)
  into v_total, v_correct, v_detail
  from graded;

  if v_total is null or v_total = 0 then
    raise exception 'quiz_empty' using errcode = 'P0002';
  end if;

  v_score  := round(100.0 * v_correct / v_total)::int;
  v_passed := v_score >= v_pass;

  insert into public.quiz_attempts (user_id, quiz_id, score_percent, correct_count, total_count, passed, answers)
  values (v_uid, p_quiz_id, v_score, v_correct, v_total, v_passed,
          (select jsonb_agg(jsonb_build_object(
                    'question_id', d ->> 'question_id',
                    'selected_option_id', d -> 'selected_option_id',
                    'is_correct', d -> 'is_correct'))
           from jsonb_array_elements(v_detail) d))
  returning id into v_attempt;

  if v_passed then
    insert into public.user_progress
      (user_id, lesson_id, status, progress_percent, completed_at, last_accessed_at)
    values (v_uid, v_lesson, 'completed', 100, now(), now())
    on conflict (user_id, lesson_id) where lesson_id is not null
    do update set status = 'completed', progress_percent = 100,
                  completed_at = coalesce(public.user_progress.completed_at, now()),
                  last_accessed_at = now();
  end if;

  return jsonb_build_object(
    'attempt_id', v_attempt, 'score_percent', v_score,
    'correct_count', v_correct, 'total_count', v_total,
    'passed', v_passed, 'details', v_detail);
end $$;
revoke all on function public.submit_quiz_attempt(uuid, jsonb) from public, anon;
grant execute on function public.submit_quiz_attempt(uuid, jsonb) to authenticated;
```

## 3. Catatan desain & hal yang harus diverifikasi saat eksekusi

1. `generated always as (lower(btrim(term)))` harus diterima Postgres (fungsi immutable); jika ditolak, ganti dengan kolom biasa + trigger.
2. `on conflict (user_id, lesson_id) where lesson_id is not null` harus cocok dengan indeks unik parsial; verifikasi.
3. Operator class `extensions.gin_trgm_ops` bergantung pada schema `extensions` Supabase; sesuaikan bila proyek berbeda.
4. `can_read_media` dipanggil pada pembuatan signed URL dan pada select `media_assets`; ukur performa dengan data nyata.
5. Pencarian: gunakan `ilike` pada `term_normalized` (escape `%` `_`); pencarian pada `meaning` tidak terindeks (di luar MVP).
6. Pengurutan ulang item: karena unique `deferrable initially deferred`, pembaruan posisi dalam satu transaksi aman.
7. Hapus akun (K-10): perlu Edge Function dengan service role di sisi server; belum dirancang di MVP.
8. Validasi duplikat `signs` (kata sama) dilakukan UI admin (peringatan), bukan constraint, karena homonim mungkin sah.

## 4. Data awal (seed)

| Berkas | Isi | Boleh di produksi? |
|---|---|---|
| `supabase/seed/00_categories.sql` | Kategori struktural (Salam, Perkenalan, Keluarga & Teman, Sekolah, Berbelanja, Meminta Bantuan, Bertanya Arah, Lainnya) — **nama kategori saja** | Ya |
| `supabase/seed/10_dev_samples.sql` | Beberapa entri dummy: `term` generik, **tanpa** deskripsi gerakan/video karangan, `validated_by = 'DEV-SAMPLE (BUKAN VERIFIKASI)'`, dan `source_note = 'Contoh pengembangan'` | **TIDAK** (hanya proyek dev) |
| Konten nyata | Diimpor setelah validator menyetujui (CSV/Studio) | Ya, setelah K-06 |

Aplikasi menampilkan lencana "Materi contoh" untuk `validated_by` yang diawali `DEV-SAMPLE`. Pengecekan pra-rilis: query `select count(*) from signs where validated_by like 'DEV-SAMPLE%'` harus 0 di produksi (tambahkan ke checklist rilis).
