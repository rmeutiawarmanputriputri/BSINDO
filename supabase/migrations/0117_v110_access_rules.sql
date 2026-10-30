-- 0117_v110_access_rules.sql — BISINDO v1.1.0
-- 1) can_read_media(): mencakup semua relasi media baru (gambar panduan,
--    audio, gambar kategori, banner, media soal & opsi), status media,
--    konten Premium (hanya pengguna Premium/admin), dan akun nonaktif.
--    Signature tetap → policy Storage 0008 otomatis memakai versi baru.
-- 2) Akun nonaktif tidak bisa membaca konten (policy RESTRICTIVE).
-- 3) Kalimat percakapan Premium hanya untuk pengguna Premium.

create or replace function public.can_read_media(p_path text)
returns boolean language sql stable security definer set search_path = '' as $$
  select public.is_admin() or (public.is_active_user() and exists (
    select 1 from public.media_assets m
    where m.path = p_path and m.status = 'published' and (
      exists (select 1 from public.signs s
              where s.status = 'published'
                and m.id in (s.video_asset_id, s.thumbnail_asset_id, s.image_asset_id, s.audio_asset_id)
                and (not s.is_premium or public.has_premium()))
      or exists (select 1 from public.conversation_modules c
                 where c.status = 'published' and c.thumbnail_asset_id = m.id
                   and (not c.is_premium or public.has_premium()))
      or exists (select 1 from public.conversation_items i
                 join public.conversation_modules c on c.id = i.module_id
                 where c.status = 'published' and m.id in (i.video_asset_id, i.audio_asset_id)
                   and (not c.is_premium or public.has_premium()))
      or exists (select 1 from public.lessons l
                 where l.status = 'published' and l.thumbnail_asset_id = m.id
                   and (not l.is_premium or public.has_premium()))
      or exists (select 1 from public.categories cat
                 where cat.is_active and cat.image_asset_id = m.id)
      or exists (select 1 from public.banners b
                 where b.is_active and b.image_asset_id = m.id
                   and (b.starts_at is null or b.starts_at <= now())
                   and (b.ends_at is null or b.ends_at > now()))
      or exists (select 1 from public.questions q
                 where m.id in (q.video_asset_id, q.image_asset_id)
                   and public.can_read_question(q.id))
      or exists (select 1 from public.question_options o
                 where o.image_asset_id = m.id and public.can_read_question(o.question_id))
    )
  ));
$$;

-- Kalimat percakapan: modul published + (gratis atau pengguna Premium).
drop policy conv_items_read on public.conversation_items;
create policy conv_items_read on public.conversation_items for select to authenticated
  using (public.is_admin() or exists (
    select 1 from public.conversation_modules m
    where m.id = module_id and m.status = 'published'
      and (not m.is_premium or public.has_premium())));

-- Akun nonaktif: semua bacaan konten ditolak (AND dengan policy lain).
do $$
declare t text;
begin
  foreach t in array array[
    'categories', 'media_assets', 'signs', 'conversation_modules', 'conversation_items',
    'lessons', 'lesson_items', 'quizzes', 'questions', 'question_options',
    'banners', 'announcements', 'faqs', 'app_settings'
  ] loop
    execute format(
      'create policy %I on public.%I as restrictive for select to authenticated
         using (public.is_active_user())', t || '_active_account_only', t);
  end loop;
end $$;
