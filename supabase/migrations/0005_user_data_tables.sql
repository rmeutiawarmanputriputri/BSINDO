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
