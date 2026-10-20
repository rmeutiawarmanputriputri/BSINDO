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
