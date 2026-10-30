-- Rollback 0120. Aman: hanya menghapus fungsi.
drop function if exists public.admin_import(text, jsonb, boolean);
drop function if exists public.slugify(text);
drop function if exists public.resolve_media(text, public.media_kind);
