-- Rollback 0111. ⚠️ Baris media audio & media > 20 MB HARUS dihapus dulu
-- (beserta berkasnya di Storage) karena constraint lama tidak mengizinkannya:
--   select id, path from public.media_assets where kind = 'audio' or size_bytes > 20971520;
update storage.buckets set file_size_limit = 20971520,
  allowed_mime_types = array['video/mp4','video/webm','image/jpeg','image/png','image/webp']
 where id = 'bisindo-media';
drop trigger if exists media_assets_limit on public.media_assets;
drop function if exists public.enforce_media_limit();
alter table public.media_assets drop constraint if exists media_mime_matches_kind;
alter table public.media_assets add constraint media_mime_matches_kind check (
  (kind = 'video' and mime_type in ('video/mp4', 'video/webm')) or
  (kind = 'image' and mime_type in ('image/jpeg', 'image/png', 'image/webp')));
alter table public.media_assets drop constraint if exists media_size_hard_limit;
alter table public.media_assets add constraint media_assets_size_bytes_check check (size_bytes > 0 and size_bytes <= 20971520);
drop index if exists public.media_assets_original_filename_idx;
drop index if exists public.media_assets_kind_created_idx;
drop trigger if exists set_updated_at on public.media_assets;
alter table public.media_assets drop column if exists updated_at, drop column if exists status,
  drop column if exists original_filename, drop column if exists description, drop column if exists title;
drop function if exists public.media_limit_bytes(public.media_kind);
drop table if exists public.app_settings;
