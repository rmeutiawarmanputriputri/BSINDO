-- 0115_v110_progress.sql — BISINDO v1.1.0
-- Progres per materi (huruf, angka, kosakata) + riwayat belajar.
-- user_progress lama (pelajaran/modul percakapan) tidak diubah.

create table public.sign_progress (
  user_id         uuid not null references public.profiles (id) on delete cascade default auth.uid(),
  sign_id         uuid not null references public.signs (id) on delete cascade,
  view_count      int  not null default 1 check (view_count >= 0),
  first_viewed_at timestamptz not null default now(),
  last_viewed_at  timestamptz not null default now(),
  learned_at      timestamptz,           -- "sudah dipelajari" (ditandai pengguna / selesai mode belajar)
  primary key (user_id, sign_id)
);
create index sign_progress_recent_idx on public.sign_progress (user_id, last_viewed_at desc);

alter table public.sign_progress enable row level security;
grant select, insert, update, delete on public.sign_progress to authenticated;
create policy sign_progress_select_own on public.sign_progress for select to authenticated
  using (user_id = (select auth.uid()));
create policy sign_progress_insert_own on public.sign_progress for insert to authenticated
  with check (user_id = (select auth.uid())
              and exists (select 1 from public.signs s where s.id = sign_id and (s.status = 'published' or public.is_admin())));
create policy sign_progress_update_own on public.sign_progress for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy sign_progress_delete_own on public.sign_progress for delete to authenticated
  using (user_id = (select auth.uid()));

-- Catat materi dibuka; p_learned: true = tandai dipelajari, false = batalkan,
-- null = tidak mengubah status. SECURITY INVOKER → RLS tetap berlaku.
create or replace function public.record_sign_view(p_sign_id uuid, p_learned boolean default null)
returns jsonb language plpgsql security invoker set search_path = '' as $$
declare r public.sign_progress;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  insert into public.sign_progress as sp (user_id, sign_id, learned_at)
  values (auth.uid(), p_sign_id, case when p_learned then now() end)
  on conflict (user_id, sign_id) do update set
    view_count     = sp.view_count + case when p_learned is null then 1 else 0 end,
    last_viewed_at = now(),
    learned_at     = case when p_learned is null then sp.learned_at
                          when p_learned then coalesce(sp.learned_at, now())
                          else null end
  returning * into r;
  return jsonb_build_object('sign_id', r.sign_id, 'view_count', r.view_count,
                            'learned', r.learned_at is not null, 'learned_at', r.learned_at);
end $$;
revoke all on function public.record_sign_view(uuid, boolean) from public, anon;
grant execute on function public.record_sign_view(uuid, boolean) to authenticated;

-- Riwayat belajar milik pemanggil (RLS tabel dasar berlaku: security_invoker).
create view public.my_learning_history with (security_invoker = on) as
  select 'sign'::text as item_type, s.content_module as module, sp.sign_id as item_id,
         s.term as title, s.symbol, sp.last_viewed_at as last_accessed_at,
         (sp.learned_at is not null) as completed, sp.view_count
  from public.sign_progress sp
  join public.signs s on s.id = sp.sign_id
  where sp.user_id = (select auth.uid())
  union all
  select case when up.lesson_id is not null then 'lesson' else 'conversation' end,
         case when up.lesson_id is not null then 'lesson' else 'conversation' end,
         coalesce(up.lesson_id, up.conversation_module_id),
         coalesce(l.title, c.title), null, up.last_accessed_at,
         up.status = 'completed', null
  from public.user_progress up
  left join public.lessons l on l.id = up.lesson_id
  left join public.conversation_modules c on c.id = up.conversation_module_id
  where up.user_id = (select auth.uid());
grant select on public.my_learning_history to authenticated;

-- Ringkasan progres untuk Beranda/Profil. Hanya materi published yang dihitung.
create or replace function public.my_progress_summary()
returns jsonb language plpgsql stable security invoker set search_path = '' as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  return jsonb_build_object(
    'modules', (
      select coalesce(jsonb_object_agg(m.module, jsonb_build_object('total', m.total, 'learned', m.learned)), '{}'::jsonb)
      from (
        select s.content_module as module, count(*)::int as total,
               (count(*) filter (where sp.learned_at is not null))::int as learned
        from public.signs s
        left join public.sign_progress sp on sp.sign_id = s.id and sp.user_id = v_uid
        where s.status = 'published'
        group by s.content_module) m),
    'categories', (
      select coalesce(jsonb_agg(jsonb_build_object('category_id', c.id, 'name', c.name,
                                                   'total', c.total, 'learned', c.learned)
                                order by c.sort_order, c.name), '[]'::jsonb)
      from (
        select cat.id, cat.name, cat.sort_order, count(s.id)::int as total,
               (count(*) filter (where sp.learned_at is not null))::int as learned
        from public.categories cat
        join public.signs s on s.category_id = cat.id and s.status = 'published'
        left join public.sign_progress sp on sp.sign_id = s.id and sp.user_id = v_uid
        where cat.is_active
        group by cat.id) c),
    'conversations', (
      select jsonb_build_object(
        'total', (select count(*) from public.conversation_modules where status = 'published')::int,
        'completed', (select count(*) from public.user_progress up
                      join public.conversation_modules cm on cm.id = up.conversation_module_id
                      where up.user_id = v_uid and up.status = 'completed' and cm.status = 'published')::int)),
    'quizzes', (
      select jsonb_build_object(
        'sessions', count(*)::int,
        'average_score', coalesce(round(avg(score_percent))::int, 0),
        'best_score', coalesce(max(score_percent), 0),
        'last_at', max(submitted_at))
      from public.quiz_sessions where user_id = v_uid),
    'total_learned', (select count(*)::int from public.sign_progress sp
                      join public.signs s on s.id = sp.sign_id and s.status = 'published'
                      where sp.user_id = v_uid and sp.learned_at is not null)
  );
end $$;
revoke all on function public.my_progress_summary() from public, anon;
grant execute on function public.my_progress_summary() to authenticated;
