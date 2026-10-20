-- GABUNGAN migrations/0001–0010 untuk ditempel sekali di Supabase SQL Editor (proyek DEV dulu).
-- Dibuat otomatis dari supabase/migrations/. Jangan diedit manual.

-- ===================== supabase/migrations/0001_extensions_types.sql
-- 0001_extensions_types.sql — sumber: docs/DATABASE_SCHEMA.md (disesuaikan, lihat komentar 'BISINDO-FIX')
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

-- ===================== supabase/migrations/0002_profiles_auth.sql
-- 0002_profiles_auth.sql — sumber: docs/DATABASE_SCHEMA.md (disesuaikan, lihat komentar 'BISINDO-FIX')
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

-- ===================== supabase/migrations/0003_content_tables.sql
-- 0003_content_tables.sql — sumber: docs/DATABASE_SCHEMA.md (disesuaikan, lihat komentar 'BISINDO-FIX')
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

-- ===================== supabase/migrations/0004_learning_tables.sql
-- 0004_learning_tables.sql — sumber: docs/DATABASE_SCHEMA.md (disesuaikan, lihat komentar 'BISINDO-FIX')
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

-- ===================== supabase/migrations/0005_user_data_tables.sql
-- 0005_user_data_tables.sql — sumber: docs/DATABASE_SCHEMA.md (disesuaikan, lihat komentar 'BISINDO-FIX')
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

-- ===================== supabase/migrations/0006_functions.sql
-- 0006_functions.sql — sumber: docs/DATABASE_SCHEMA.md (disesuaikan, lihat komentar 'BISINDO-FIX')
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

-- ===================== supabase/migrations/0007_grants_rls.sql
-- 0007_grants_rls.sql — sumber: docs/SUPABASE_SECURITY_PLAN.md §3
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

-- ===================== supabase/migrations/0008_storage.sql
-- 0008_storage.sql — sumber: docs/SUPABASE_SECURITY_PLAN.md §4
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

-- ===================== supabase/migrations/0009_defaults_hardening.sql
-- 0009_defaults_hardening.sql — tambahan BISINDO-FIX di atas draf dokumen.
-- 1) Kolom pemilik terisi otomatis dari JWT, sehingga klien tidak perlu (dan
--    tidak bisa memalsukan, karena policy with check tetap memeriksa)
--    mengirim user_id.
-- 2) Opsi yang disarankan SUPABASE_SECURITY_PLAN §3 catatan: favorit/kosakata
--    sulit hanya untuk sign yang published (atau admin).

alter table public.favorites            alter column user_id     set default auth.uid();
alter table public.difficult_vocabulary alter column user_id     set default auth.uid();
alter table public.user_progress        alter column user_id     set default auth.uid();
alter table public.content_reports      alter column reporter_id set default auth.uid();
alter table public.media_assets         alter column uploaded_by set default auth.uid();
alter table public.signs                alter column created_by  set default auth.uid();
alter table public.conversation_modules alter column created_by  set default auth.uid();
alter table public.lessons              alter column created_by  set default auth.uid();

drop policy favorites_insert_own on public.favorites;
create policy favorites_insert_own on public.favorites for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and exists (select 1 from public.signs s
                where s.id = sign_id and (s.status = 'published' or public.is_admin())));

drop policy difficult_insert_own on public.difficult_vocabulary;
create policy difficult_insert_own on public.difficult_vocabulary for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and exists (select 1 from public.signs s
                where s.id = sign_id and (s.status = 'published' or public.is_admin())));

-- Ringkasan untuk dashboard admin (S25) dalam satu panggilan.
create or replace function public.admin_dashboard_counts()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_admin() then
    raise exception 'not_admin' using errcode = '42501';
  end if;
  return jsonb_build_object(
    'open_reports', (select count(*) from public.content_reports where status in ('open', 'in_review')),
    'in_review', (select count(*) from public.signs where status = 'in_review')
               + (select count(*) from public.conversation_modules where status = 'in_review')
               + (select count(*) from public.lessons where status = 'in_review'),
    'drafts', (select count(*) from public.signs where status = 'draft')
            + (select count(*) from public.conversation_modules where status = 'draft')
            + (select count(*) from public.lessons where status = 'draft')
  );
end $$;
revoke all on function public.admin_dashboard_counts() from public, anon;
grant execute on function public.admin_dashboard_counts() to authenticated;

-- ===================== supabase/migrations/0010_progress_rpc.sql
-- 0010_progress_rpc.sql — BISINDO-FIX
-- PostgREST tidak dapat melakukan upsert pada indeks unik PARSIAL
-- (user_progress_lesson_uniq / user_progress_module_uniq) karena ON CONFLICT
-- membutuhkan predikat WHERE. RPC ini (SECURITY INVOKER → RLS tetap berlaku)
-- mencatat progres dan "materi terakhir dipelajari".
create or replace function public.touch_progress(
  p_lesson_id uuid default null,
  p_module_id uuid default null,
  p_progress_percent int default null,
  p_last_position int default null,
  p_completed boolean default false
) returns void language plpgsql security invoker set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  if num_nonnulls(p_lesson_id, p_module_id) <> 1 then
    raise exception 'invalid_target' using errcode = '22023';
  end if;

  if p_lesson_id is not null then
    insert into public.user_progress as up (user_id, lesson_id, status, progress_percent, last_position,
                                     completed_at, last_accessed_at)
    values (v_uid, p_lesson_id,
            case when p_completed then 'completed'::public.progress_status else 'in_progress' end,
            case when p_completed then 100 else greatest(0, least(100, coalesce(p_progress_percent, 0))) end,
            greatest(0, coalesce(p_last_position, 0)),
            case when p_completed then now() end, now())
    on conflict (user_id, lesson_id) where lesson_id is not null do update set
      status = case when p_completed or up.status = 'completed'
                    then 'completed'::public.progress_status else 'in_progress' end,
      progress_percent = case when p_completed or up.status = 'completed' then 100
                              else greatest(up.progress_percent, least(100, coalesce(p_progress_percent, up.progress_percent))) end,
      last_position = coalesce(p_last_position, up.last_position),
      completed_at = case when p_completed or up.status = 'completed' then coalesce(up.completed_at, now()) end,
      last_accessed_at = now();
  else
    insert into public.user_progress as up (user_id, conversation_module_id, status, progress_percent, last_position,
                                     completed_at, last_accessed_at)
    values (v_uid, p_module_id,
            case when p_completed then 'completed'::public.progress_status else 'in_progress' end,
            case when p_completed then 100 else greatest(0, least(100, coalesce(p_progress_percent, 0))) end,
            greatest(0, coalesce(p_last_position, 0)),
            case when p_completed then now() end, now())
    on conflict (user_id, conversation_module_id) where conversation_module_id is not null do update set
      status = case when p_completed or up.status = 'completed'
                    then 'completed'::public.progress_status else 'in_progress' end,
      progress_percent = case when p_completed or up.status = 'completed' then 100
                              else greatest(up.progress_percent, least(100, coalesce(p_progress_percent, up.progress_percent))) end,
      last_position = coalesce(p_last_position, up.last_position),
      completed_at = case when p_completed or up.status = 'completed' then coalesce(up.completed_at, now()) end,
      last_accessed_at = now();
  end if;
end $$;
revoke all on function public.touch_progress(uuid, uuid, int, int, boolean) from public, anon;
grant execute on function public.touch_progress(uuid, uuid, int, int, boolean) to authenticated;
