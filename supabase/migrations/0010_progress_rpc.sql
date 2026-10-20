-- 0010_progress_rpc.sql — BISINDO-FIX
-- PostgREST tidak dapat melakukan upsert pada indeks unik PARSIAL
-- (user_progress_lesson_uniq / user_progress_module_uniq) karena ON CONFLICT
-- membutuhkan predikat WHERE. RPC ini (SECURITY INVOKER → RLS tetap berlaku)
-- mencatat progres dan "materi terakhir dipelajari".
create or replace function public.touch_progress(
  p_lesson_id uuid default null,
  p_module_id uuid default null,
  p_progress_percent int default null,
  p_last_position int default null,
  p_completed boolean default false
) returns void language plpgsql security invoker set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  if num_nonnulls(p_lesson_id, p_module_id) <> 1 then
    raise exception 'invalid_target' using errcode = '22023';
  end if;

  if p_lesson_id is not null then
    insert into public.user_progress as up (user_id, lesson_id, status, progress_percent, last_position,
                                     completed_at, last_accessed_at)
    values (v_uid, p_lesson_id,
            case when p_completed then 'completed'::public.progress_status else 'in_progress' end,
            case when p_completed then 100 else greatest(0, least(100, coalesce(p_progress_percent, 0))) end,
            greatest(0, coalesce(p_last_position, 0)),
            case when p_completed then now() end, now())
    on conflict (user_id, lesson_id) where lesson_id is not null do update set
      status = case when p_completed or up.status = 'completed'
                    then 'completed'::public.progress_status else 'in_progress' end,
      progress_percent = case when p_completed or up.status = 'completed' then 100
                              else greatest(up.progress_percent, least(100, coalesce(p_progress_percent, up.progress_percent))) end,
      last_position = coalesce(p_last_position, up.last_position),
      completed_at = case when p_completed or up.status = 'completed' then coalesce(up.completed_at, now()) end,
      last_accessed_at = now();
  else
    insert into public.user_progress as up (user_id, conversation_module_id, status, progress_percent, last_position,
                                     completed_at, last_accessed_at)
    values (v_uid, p_module_id,
            case when p_completed then 'completed'::public.progress_status else 'in_progress' end,
            case when p_completed then 100 else greatest(0, least(100, coalesce(p_progress_percent, 0))) end,
            greatest(0, coalesce(p_last_position, 0)),
            case when p_completed then now() end, now())
    on conflict (user_id, conversation_module_id) where conversation_module_id is not null do update set
      status = case when p_completed or up.status = 'completed'
                    then 'completed'::public.progress_status else 'in_progress' end,
      progress_percent = case when p_completed or up.status = 'completed' then 100
                              else greatest(up.progress_percent, least(100, coalesce(p_progress_percent, up.progress_percent))) end,
      last_position = coalesce(p_last_position, up.last_position),
      completed_at = case when p_completed or up.status = 'completed' then coalesce(up.completed_at, now()) end,
      last_accessed_at = now();
  end if;
end $$;
revoke all on function public.touch_progress(uuid, uuid, int, int, boolean) from public, anon;
grant execute on function public.touch_progress(uuid, uuid, int, int, boolean) to authenticated;
