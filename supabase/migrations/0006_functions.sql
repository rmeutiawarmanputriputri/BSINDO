-- 0006_functions.sql — sumber: docs/DATABASE_SCHEMA.md (disesuaikan, lihat komentar 'BISINDO-FIX')
-- Apakah berkas Storage boleh dibaca pengguna? (admin, atau dipakai konten published)
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
revoke all on function public.can_read_media(text) from public, anon;
grant execute on function public.can_read_media(text) to authenticated;

-- Penilaian kuis di server
create or replace function public.submit_quiz_attempt(p_quiz_id uuid, p_answers jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_uid     uuid := auth.uid();
  v_pass    int;
  v_lesson  uuid;
  v_total   int;
  v_correct int;
  v_score   int;
  v_passed  boolean;
  v_detail  jsonb;
  v_attempt uuid;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  if p_answers is null or jsonb_typeof(p_answers) <> 'array' or jsonb_array_length(p_answers) > 100 then
    raise exception 'invalid_answers' using errcode = '22023';
  end if;

  select z.pass_score_percent, z.lesson_id into v_pass, v_lesson
  from public.quizzes z
  join public.lessons l on l.id = z.lesson_id
  where z.id = p_quiz_id and z.is_active and l.status = 'published';
  if not found then
    raise exception 'quiz_not_available' using errcode = 'P0002';
  end if;

  with given as (
    select distinct on (question_id) question_id, option_id
    from (
      select (a ->> 'question_id')::uuid as question_id,
             (a ->> 'option_id')::uuid   as option_id
      from jsonb_array_elements(p_answers) a
    ) x
    order by question_id
  ), graded as (
    select qu.id as question_id, qu.position, g.option_id,
           k.correct_option_id, k.explanation,
           (g.option_id is not null and g.option_id = k.correct_option_id) as is_correct
    from public.questions qu
    join public.question_answer_keys k on k.question_id = qu.id
    left join given g on g.question_id = qu.id
    where qu.quiz_id = p_quiz_id
  )
  select count(*)::int,
         (count(*) filter (where is_correct))::int,
         jsonb_agg(jsonb_build_object(
           'question_id', question_id,
           'selected_option_id', option_id,
           'correct_option_id', correct_option_id,
           'is_correct', is_correct,
           'explanation', explanation) order by position)
  into v_total, v_correct, v_detail
  from graded;

  if v_total is null or v_total = 0 then
    raise exception 'quiz_empty' using errcode = 'P0002';
  end if;

  v_score  := round(100.0 * v_correct / v_total)::int;
  v_passed := v_score >= v_pass;

  insert into public.quiz_attempts (user_id, quiz_id, score_percent, correct_count, total_count, passed, answers)
  values (v_uid, p_quiz_id, v_score, v_correct, v_total, v_passed,
          (select jsonb_agg(jsonb_build_object(
                    'question_id', d ->> 'question_id',
                    'selected_option_id', d -> 'selected_option_id',
                    'is_correct', d -> 'is_correct'))
           from jsonb_array_elements(v_detail) d))
  returning id into v_attempt;

  if v_passed then
    insert into public.user_progress
      (user_id, lesson_id, status, progress_percent, completed_at, last_accessed_at)
    values (v_uid, v_lesson, 'completed', 100, now(), now())
    on conflict (user_id, lesson_id) where lesson_id is not null
    do update set status = 'completed', progress_percent = 100,
                  completed_at = coalesce(public.user_progress.completed_at, now()),
                  last_accessed_at = now();
  end if;

  return jsonb_build_object(
    'attempt_id', v_attempt, 'score_percent', v_score,
    'correct_count', v_correct, 'total_count', v_total,
    'passed', v_passed, 'details', v_detail);
end $$;
revoke all on function public.submit_quiz_attempt(uuid, jsonb) from public, anon;
grant execute on function public.submit_quiz_attempt(uuid, jsonb) to authenticated;
