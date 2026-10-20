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
