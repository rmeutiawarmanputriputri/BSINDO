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
