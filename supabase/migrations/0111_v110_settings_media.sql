-- 0111_v110_settings_media.sql — BISINDO v1.1.0
-- 1) app_settings: konfigurasi yang dapat diubah admin dari CMS (batas ukuran
--    media, info paket Premium). Tidak menyimpan rahasia.
-- 2) media_assets: dukung audio, metadata (judul, deskripsi, nama berkas
--    asli), status publikasi, batas ukuran dapat dikonfigurasi.
-- 3) Bucket bisindo-media: izinkan MIME audio, batas keras 50 MB.
-- Data lama: tidak diubah (kolom baru punya default).

-- ------------------------------------------------------------ app_settings
create table public.app_settings (
  key         text primary key check (key ~ '^[a-z0-9_]+$'),
  value       jsonb not null,
  is_public   boolean not null default false,   -- boleh dibaca aplikasi pengguna
  description text,
  updated_by  uuid references public.profiles (id) on delete set null default auth.uid(),
  updated_at  timestamptz not null default now()
);
create trigger set_updated_at before update on public.app_settings
  for each row execute function public.set_updated_at();

insert into public.app_settings (key, value, is_public, description) values
  ('media_limits', '{"video_max_mb": 50, "audio_max_mb": 20, "image_max_mb": 5}', true,
   'Batas ukuran unggah per jenis media (MB). Maksimum keras 50 MB (batas bucket).'),
  ('premium_info', '{"enabled": false, "title": null, "description": null, "plans": []}', true,
   'Informasi paket Premium yang ditampilkan di aplikasi. Diisi admin dari CMS.')
on conflict (key) do nothing;

alter table public.app_settings enable row level security;
grant select on public.app_settings to authenticated;
grant insert, update, delete on public.app_settings to authenticated;
create policy app_settings_read on public.app_settings for select to authenticated
  using (is_public or public.is_admin());
create policy app_settings_admin on public.app_settings for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- Pembaca batas media (dipakai trigger; security definer agar tidak bergantung RLS).
create or replace function public.media_limit_bytes(p_kind public.media_kind)
returns bigint language sql stable security definer set search_path = '' as $$
  select (least(50, greatest(1, coalesce(
            (select (s.value ->> (p_kind::text || '_max_mb'))::numeric
               from public.app_settings s where s.key = 'media_limits'),
            case p_kind::text when 'video' then 50 when 'audio' then 20 else 5 end)))
          * 1024 * 1024)::bigint;
$$;
revoke all on function public.media_limit_bytes(public.media_kind) from public, anon;
grant execute on function public.media_limit_bytes(public.media_kind) to authenticated;

-- ------------------------------------------------------------ media_assets
alter table public.media_assets
  add column title             text check (title is null or char_length(btrim(title)) between 1 and 160),
  add column description       text check (description is null or char_length(description) <= 1000),
  add column original_filename text check (original_filename is null or char_length(original_filename) <= 255),
  add column status            public.content_status not null default 'published',
  add column updated_at        timestamptz not null default now();

create trigger set_updated_at before update on public.media_assets
  for each row execute function public.set_updated_at();

create index media_assets_kind_created_idx on public.media_assets (kind, created_at desc);
create index media_assets_original_filename_idx on public.media_assets (lower(original_filename));

-- Batas lama 20 MB diganti batas keras 50 MB + batas per jenis dari app_settings.
alter table public.media_assets drop constraint if exists media_assets_size_bytes_check;
alter table public.media_assets add constraint media_size_hard_limit
  check (size_bytes > 0 and size_bytes <= 52428800);

alter table public.media_assets drop constraint if exists media_mime_matches_kind;
alter table public.media_assets add constraint media_mime_matches_kind check (
  (kind = 'video' and mime_type in ('video/mp4', 'video/webm')) or
  (kind = 'image' and mime_type in ('image/jpeg', 'image/png', 'image/webp')) or
  (kind = 'audio' and mime_type in ('audio/mpeg', 'audio/mp4', 'audio/aac', 'audio/x-m4a'))
);

create or replace function public.enforce_media_limit()
returns trigger language plpgsql set search_path = '' as $$
begin
  -- Hanya diperiksa saat ukuran/jenis berubah: data lama tidak ditolak.
  if tg_op = 'INSERT' or new.size_bytes is distinct from old.size_bytes or new.kind is distinct from old.kind then
    if new.size_bytes > public.media_limit_bytes(new.kind) then
      raise exception 'media_too_large: % MB melebihi batas % MB untuk %',
        round(new.size_bytes / 1048576.0, 1), public.media_limit_bytes(new.kind) / 1048576, new.kind
        using errcode = '22023';
    end if;
  end if;
  return new;
end $$;
create trigger media_assets_limit before insert or update on public.media_assets
  for each row execute function public.enforce_media_limit();

-- ------------------------------------------------------------ bucket
update storage.buckets
   set file_size_limit = 52428800,
       allowed_mime_types = array['video/mp4','video/webm','image/jpeg','image/png','image/webp',
                                  'audio/mpeg','audio/mp4','audio/aac','audio/x-m4a']
 where id = 'bisindo-media';
