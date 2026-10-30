-- 0116_v110_home_content.sql — BISINDO v1.1.0
-- Banner Beranda, pengumuman (notifikasi dalam aplikasi), FAQ.
-- Semua isi diketik admin di CMS; migrasi ini tidak mengisi data.

-- ------------------------------------------------------------ banners
create table public.banners (
  id             uuid primary key default gen_random_uuid(),
  title          text not null check (char_length(btrim(title)) between 1 and 120),
  description    text check (description is null or char_length(description) <= 300),
  image_asset_id uuid references public.media_assets (id) on delete set null,
  -- Tujuan saat diketuk. none | route (rute aplikasi, mis. /alphabet) | url (https) |
  -- sign | conversation | category (target_value = UUID)
  target_type    text not null default 'none'
    check (target_type in ('none', 'route', 'url', 'sign', 'conversation', 'category')),
  target_value   text check (target_value is null or char_length(target_value) <= 500),
  sort_order     int not null default 0,
  is_active      boolean not null default false,
  starts_at      timestamptz,
  ends_at        timestamptz,
  created_by     uuid references public.profiles (id) on delete set null default auth.uid(),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  constraint banners_target_value_needed check (target_type = 'none' or target_value is not null),
  constraint banners_url_https check (target_type <> 'url' or target_value ~ '^https://'),
  constraint banners_route_path check (target_type <> 'route' or target_value ~ '^/[a-z0-9/_-]*$'),
  constraint banners_period check (starts_at is null or ends_at is null or ends_at > starts_at),
  constraint banners_active_needs_image check (not is_active or image_asset_id is not null)
);
create trigger set_updated_at before update on public.banners
  for each row execute function public.set_updated_at();
create index banners_active_idx on public.banners (is_active, sort_order);

-- ------------------------------------------------------------ announcements
create table public.announcements (
  id           uuid primary key default gen_random_uuid(),
  title        text not null check (char_length(btrim(title)) between 1 and 120),
  body         text not null check (char_length(btrim(body)) between 1 and 2000),
  is_published boolean not null default false,
  published_at timestamptz,
  created_by   uuid references public.profiles (id) on delete set null default auth.uid(),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  constraint announcements_published_at check (not is_published or published_at is not null)
);
create trigger set_updated_at before update on public.announcements
  for each row execute function public.set_updated_at();
create index announcements_pub_idx on public.announcements (is_published, published_at desc);

create table public.announcement_reads (
  user_id         uuid not null references public.profiles (id) on delete cascade default auth.uid(),
  announcement_id uuid not null references public.announcements (id) on delete cascade,
  read_at         timestamptz not null default now(),
  primary key (user_id, announcement_id)
);

-- ------------------------------------------------------------ faqs
create table public.faqs (
  id         uuid primary key default gen_random_uuid(),
  question   text not null check (char_length(btrim(question)) between 1 and 300),
  answer     text not null check (char_length(btrim(answer)) between 1 and 3000),
  sort_order int not null default 0,
  is_active  boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger set_updated_at before update on public.faqs
  for each row execute function public.set_updated_at();

-- ------------------------------------------------------------ RLS
alter table public.banners            enable row level security;
alter table public.announcements      enable row level security;
alter table public.announcement_reads enable row level security;
alter table public.faqs               enable row level security;

grant select, insert, update, delete on public.banners, public.announcements, public.faqs to authenticated;
grant select, insert, delete on public.announcement_reads to authenticated;

create policy banners_read on public.banners for select to authenticated
  using (public.is_admin() or (is_active
         and (starts_at is null or starts_at <= now())
         and (ends_at is null or ends_at > now())));
create policy banners_admin on public.banners for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy announcements_read on public.announcements for select to authenticated
  using (public.is_admin() or (is_published and published_at <= now()));
create policy announcements_admin on public.announcements for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy announcement_reads_own_select on public.announcement_reads for select to authenticated
  using (user_id = (select auth.uid()));
create policy announcement_reads_own_insert on public.announcement_reads for insert to authenticated
  with check (user_id = (select auth.uid()));
create policy announcement_reads_own_delete on public.announcement_reads for delete to authenticated
  using (user_id = (select auth.uid()));

create policy faqs_read on public.faqs for select to authenticated
  using (is_active or public.is_admin());
create policy faqs_admin on public.faqs for all to authenticated
  using (public.is_admin()) with check (public.is_admin());
