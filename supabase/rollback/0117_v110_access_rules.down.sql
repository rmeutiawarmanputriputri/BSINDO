-- Rollback 0117: kembalikan can_read_media & policy kalimat versi 0006/0007,
-- hapus policy restrictive akun nonaktif.
do $$ declare t text; begin
  foreach t in array array['categories','media_assets','signs','conversation_modules','conversation_items',
    'lessons','lesson_items','quizzes','questions','question_options','banners','announcements','faqs','app_settings'] loop
    execute format('drop policy if exists %I on public.%I', t || '_active_account_only', t);
  end loop;
end $$;
drop policy if exists conv_items_read on public.conversation_items;
create policy conv_items_read on public.conversation_items for select to authenticated
  using (public.is_admin() or exists (
    select 1 from public.conversation_modules m where m.id = module_id and m.status = 'published'));
create or replace function public.can_read_media(p_path text)
returns boolean language sql stable security definer set search_path = '' as $$
  select public.is_admin() or exists (
    select 1 from public.media_assets m
    where m.path = p_path and (
      exists (select 1 from public.signs s
              where s.status = 'published' and m.id in (s.video_asset_id, s.thumbnail_asset_id))
      or exists (select 1 from public.conversation_modules c
                 where c.status = 'published' and c.thumbnail_asset_id = m.id)
      or exists (select 1 from public.conversation_items i
                 join public.conversation_modules c on c.id = i.module_id
                 where c.status = 'published' and i.video_asset_id = m.id)
      or exists (select 1 from public.lessons l
                 where l.status = 'published' and l.thumbnail_asset_id = m.id)
    )
  );
$$;
