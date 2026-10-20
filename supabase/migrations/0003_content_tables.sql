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
