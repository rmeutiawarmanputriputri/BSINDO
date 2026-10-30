-- 0114_v110_quiz_bank.sql — BISINDO v1.1.0
-- Bank soal kuis memakai tabel `questions` yang sudah ada:
--   quiz_id IS NOT NULL → soal pelajaran (lama). Tetap PILIHAN GANDA saja,
--                          karena aplikasi 1.0.0 hanya mengenal MC.
--   quiz_id IS NULL     → soal bank (baru): per modul/kategori, 6 jenis soal,
--                          tingkat kesulitan, status publikasi, Premium.
-- Kunci jawaban tetap di question_answer_keys (tertutup bagi pengguna).
-- Riwayat kuis bank disimpan di tabel baru quiz_sessions; quiz_attempts lama
-- tidak diubah (aplikasi 1.0.0 membacanya dengan embed quizzes(title)).
--
-- Jenis soal:
--   guess_letter / guess_number / guess_sign / multiple_choice
--        → satu pilihan benar (correct_option_id)
--   arrange_word  → urutan ubin benar (correct_sequence, dibandingkan per LABEL
--                   sehingga ubin berhuruf sama boleh tertukar)
--   match_image   → pasangan gambar (side=left) ↔ arti (side=right) (pairs)

-- ------------------------------------------------------------ questions
alter table public.questions alter column quiz_id drop not null;
alter table public.questions drop constraint if exists questions_question_type_check;
alter table public.questions
  add column module         text check (module is null or module in ('alphabet', 'number', 'vocabulary', 'conversation', 'general')),
  add column category_id    uuid references public.categories (id) on delete set null,
  add column difficulty     text not null default 'medium' check (difficulty in ('easy', 'medium', 'hard')),
  add column status         public.content_status not null default 'published',  -- data lama
  add column is_active      boolean not null default true,
  add column is_premium     boolean not null default false,
  add column sort_order     int not null default 0,
  add column video_asset_id uuid references public.media_assets (id) on delete set null,
  add column image_asset_id uuid references public.media_assets (id) on delete set null,
  add column created_by     uuid references public.profiles (id) on delete set null default auth.uid(),
  add constraint questions_type_valid check (question_type in
    ('multiple_choice', 'guess_letter', 'guess_number', 'guess_sign', 'match_image', 'arrange_word')),
  add constraint questions_lesson_mc_only check (quiz_id is null or question_type = 'multiple_choice'),
  add constraint questions_bank_needs_module check (quiz_id is not null or module is not null);
alter table public.questions alter column status set default 'draft';   -- soal baru mulai Draft

create index questions_bank_idx on public.questions (module, category_id, status, difficulty, sort_order)
  where quiz_id is null;

-- ------------------------------------------------------------ options
alter table public.question_options
  add column image_asset_id uuid references public.media_assets (id) on delete set null,
  add column side text check (side is null or side in ('left', 'right'));

-- ------------------------------------------------------------ answer keys
alter table public.question_answer_keys alter column correct_option_id drop not null;
alter table public.question_answer_keys
  add column correct_sequence uuid[],
  add column pairs jsonb check (pairs is null or jsonb_typeof(pairs) = 'array'),
  add constraint answer_key_has_answer check (
    correct_option_id is not null or correct_sequence is not null or pairs is not null);

-- Kunci harus cocok dengan jenis soal dan merujuk opsi milik soal itu sendiri.
create or replace function public.validate_answer_key()
returns trigger language plpgsql set search_path = '' as $$
declare
  v_type text;
  v_bad  int;
begin
  select question_type into v_type from public.questions where id = new.question_id;
  if v_type in ('multiple_choice', 'guess_letter', 'guess_number', 'guess_sign') then
    if new.correct_option_id is null then
      raise exception 'answer_key_invalid: jawaban benar wajib dipilih' using errcode = '23514';
    end if;
    new.correct_sequence := null; new.pairs := null;
  elsif v_type = 'arrange_word' then
    if new.correct_sequence is null or cardinality(new.correct_sequence) < 1 then
      raise exception 'answer_key_invalid: urutan benar wajib diisi' using errcode = '23514';
    end if;
    select count(*) into v_bad from unnest(new.correct_sequence) x
      where not exists (select 1 from public.question_options o where o.id = x and o.question_id = new.question_id);
    if v_bad > 0 then
      raise exception 'answer_key_invalid: urutan merujuk pilihan soal lain' using errcode = '23514';
    end if;
    new.correct_option_id := null; new.pairs := null;
  elsif v_type = 'match_image' then
    if new.pairs is null or jsonb_array_length(new.pairs) < 1 then
      raise exception 'answer_key_invalid: pasangan wajib diisi' using errcode = '23514';
    end if;
    select count(*) into v_bad from jsonb_array_elements(new.pairs) p
      where not exists (select 1 from public.question_options o
                        where o.question_id = new.question_id and o.side = 'left'
                          and o.id::text = p ->> 'left')
         or not exists (select 1 from public.question_options o
                        where o.question_id = new.question_id and o.side = 'right'
                          and o.id::text = p ->> 'right');
    if v_bad > 0 then
      raise exception 'answer_key_invalid: pasangan tidak valid' using errcode = '23514';
    end if;
    new.correct_option_id := null; new.correct_sequence := null;
  end if;
  return new;
end $$;
create trigger question_answer_keys_validate before insert or update on public.question_answer_keys
  for each row execute function public.validate_answer_key();

-- ------------------------------------------------------------ quiz_sessions
create table public.quiz_sessions (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.profiles (id) on delete cascade default auth.uid(),
  mode          text not null check (mode in ('category', 'mixed', 'weak')),
  module        text check (module is null or module in ('alphabet', 'number', 'vocabulary', 'conversation', 'general')),
  category_id   uuid references public.categories (id) on delete set null,
  difficulty    text check (difficulty is null or difficulty in ('easy', 'medium', 'hard')),
  score_percent int not null check (score_percent between 0 and 100),
  correct_count int not null check (correct_count >= 0),
  total_count   int not null check (total_count > 0),
  answers       jsonb not null,     -- [{question_id, is_correct}]
  started_at    timestamptz,
  submitted_at  timestamptz not null default now()
);
create index quiz_sessions_user_idx on public.quiz_sessions (user_id, submitted_at desc);

alter table public.quiz_sessions enable row level security;
grant select on public.quiz_sessions to authenticated;          -- insert hanya via RPC
create policy quiz_sessions_select on public.quiz_sessions for select to authenticated
  using (user_id = (select auth.uid()) or public.is_admin());

-- ------------------------------------------------------------ RLS bank soal
create policy questions_bank_read on public.questions for select to authenticated
  using (quiz_id is null and status = 'published' and is_active
         and (not is_premium or public.has_premium()));

create policy options_bank_read on public.question_options for select to authenticated
  using (exists (
    select 1 from public.questions q
    where q.id = question_id and q.quiz_id is null and q.status = 'published' and q.is_active
      and (not q.is_premium or public.has_premium())));

-- Soal bisa dibaca pemanggil? (bank published/aktif/premium, atau soal pelajaran published)
create or replace function public.can_read_question(p_question_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select public.is_admin() or (public.is_active_user() and exists (
    select 1 from public.questions q
    where q.id = p_question_id and (
      (q.quiz_id is null and q.status = 'published' and q.is_active
         and (not q.is_premium or public.has_premium()))
      or exists (select 1 from public.quizzes z join public.lessons l on l.id = z.lesson_id
                 where z.id = q.quiz_id and z.is_active and l.status = 'published'
                   and (not l.is_premium or public.has_premium())))));
$$;
revoke all on function public.can_read_question(uuid) from public, anon;
grant execute on function public.can_read_question(uuid) to authenticated;

-- ------------------------------------------------------------ penilaian
-- Internal (tidak di-grant ke klien). p_answer:
--   {"option_id": uuid} | {"sequence": [uuid,...]} | {"pairs": [{"left":uuid,"right":uuid}]}
create or replace function public.grade_question(p_question_id uuid, p_answer jsonb)
returns boolean language plpgsql stable security definer set search_path = '' as $$
declare
  v_type text;
  k      public.question_answer_keys;
  v_given text[];
  v_want  text[];
begin
  select question_type into v_type from public.questions where id = p_question_id;
  select * into k from public.question_answer_keys where question_id = p_question_id;
  if v_type is null or k.question_id is null or p_answer is null or jsonb_typeof(p_answer) <> 'object' then
    return false;
  end if;

  begin
    if v_type in ('multiple_choice', 'guess_letter', 'guess_number', 'guess_sign') then
      return (p_answer ->> 'option_id')::uuid = k.correct_option_id;
    elsif v_type = 'arrange_word' then
      if jsonb_typeof(p_answer -> 'sequence') <> 'array' then return false; end if;
      select array_agg(o.label order by s.ord) into v_given
        from jsonb_array_elements_text(p_answer -> 'sequence') with ordinality s(id, ord)
        join public.question_options o on o.id = s.id::uuid and o.question_id = p_question_id;
      select array_agg(o.label order by s.ord) into v_want
        from unnest(k.correct_sequence) with ordinality s(id, ord)
        join public.question_options o on o.id = s.id;
      return v_given is not null
         and jsonb_array_length(p_answer -> 'sequence') = cardinality(k.correct_sequence)
         and v_given = v_want;
    elsif v_type = 'match_image' then
      if jsonb_typeof(p_answer -> 'pairs') <> 'array' then return false; end if;
      select array_agg(x order by x) into v_given
        from (select (p ->> 'left') || '>' || (p ->> 'right') as x
                from jsonb_array_elements(p_answer -> 'pairs') p) g;
      select array_agg(x order by x) into v_want
        from (select (p ->> 'left') || '>' || (p ->> 'right') as x
                from jsonb_array_elements(k.pairs) p) w;
      return v_given = v_want;
    end if;
  exception when invalid_text_representation then
    return false;
  end;
  return false;
end $$;
revoke all on function public.grade_question(uuid, jsonb) from public, anon, authenticated;

create or replace function public.answer_reveal(p_question_id uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'correct_option_id', k.correct_option_id,
    'correct_sequence', to_jsonb(k.correct_sequence),
    'pairs', k.pairs,
    'explanation', k.explanation)
  from public.question_answer_keys k where k.question_id = p_question_id;
$$;
revoke all on function public.answer_reveal(uuid) from public, anon, authenticated;

-- Cek satu jawaban (umpan balik langsung). Tidak mencatat apa pun.
create or replace function public.check_quiz_answer(p_question_id uuid, p_answer jsonb)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  if not public.can_read_question(p_question_id) then
    raise exception 'question_not_available' using errcode = 'P0002';
  end if;
  return jsonb_build_object('question_id', p_question_id,
                            'is_correct', public.grade_question(p_question_id, p_answer))
         || coalesce(public.answer_reveal(p_question_id), '{}'::jsonb);
end $$;
revoke all on function public.check_quiz_answer(uuid, jsonb) from public, anon;
grant execute on function public.check_quiz_answer(uuid, jsonb) to authenticated;

-- ------------------------------------------------------------ ambil soal
-- SECURITY INVOKER: RLS menentukan soal/opsi/media yang terlihat.
-- p_mode: 'category' (module [+ category]), 'mixed' (acak lintas modul),
--         'weak' (soal yang terakhir dijawab salah + soal untuk kosakata sulit).
create or replace function public.get_quiz_questions(
  p_mode        text default 'category',
  p_module      text default null,
  p_category_id uuid default null,
  p_difficulty  text default null,
  p_limit       int  default 10
) returns jsonb language plpgsql stable security invoker set search_path = '' as $$
declare
  v_uid   uuid := auth.uid();
  v_limit int  := greatest(1, least(coalesce(p_limit, 10), 50));
  v_out   jsonb;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  if p_mode not in ('category', 'mixed', 'weak') then
    raise exception 'invalid_mode' using errcode = '22023';
  end if;

  with last_answers as (
    select distinct on ((a ->> 'question_id')) (a ->> 'question_id')::uuid as question_id,
           (a ->> 'is_correct')::boolean as is_correct
    from public.quiz_sessions s, jsonb_array_elements(s.answers) a
    where s.user_id = v_uid
    order by (a ->> 'question_id'), s.submitted_at desc
  ), pool as (
    select q.* from public.questions q
    where q.quiz_id is null and q.status = 'published' and q.is_active
      and (p_difficulty is null or q.difficulty = p_difficulty)
      and (p_mode <> 'category' or ((p_module is null or q.module = p_module)
                                    and (p_category_id is null or q.category_id = p_category_id)))
      and (p_mode <> 'weak' or (
            exists (select 1 from last_answers la where la.question_id = q.id and not la.is_correct)
         or exists (select 1 from public.difficult_vocabulary d
                    where d.user_id = v_uid and d.status = 'learning' and d.sign_id = q.sign_id)))
      and (p_mode = 'category' or p_module is null or q.module = p_module)
    order by random()
    limit v_limit
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', q.id,
           'question_type', q.question_type,
           'prompt', q.prompt,
           'module', q.module,
           'category_id', q.category_id,
           'difficulty', q.difficulty,
           'is_premium', q.is_premium,
           'video_path', coalesce(mv.path, sv.path),
           'image_path', mi.path,
           'options', (
             select coalesce(jsonb_agg(jsonb_build_object(
                      'id', o.id, 'label', o.label, 'side', o.side, 'image_path', oi.path)
                    order by random()), '[]'::jsonb)
             from public.question_options o
             left join public.media_assets oi on oi.id = o.image_asset_id
             where o.question_id = q.id))), '[]'::jsonb)
    into v_out
  from pool q
  left join public.media_assets mv on mv.id = q.video_asset_id
  left join public.signs sg on sg.id = q.sign_id
  left join public.media_assets sv on sv.id = sg.video_asset_id
  left join public.media_assets mi on mi.id = q.image_asset_id;

  return v_out;
end $$;
revoke all on function public.get_quiz_questions(text, text, uuid, text, int) from public, anon;
grant execute on function public.get_quiz_questions(text, text, uuid, text, int) to authenticated;

-- ------------------------------------------------------------ kirim sesi
create or replace function public.submit_quiz_session(
  p_mode        text,
  p_answers     jsonb,               -- [{"question_id": uuid, "answer": {...}|null}]
  p_module      text default null,
  p_category_id uuid default null,
  p_difficulty  text default null,
  p_started_at  timestamptz default null
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_uid     uuid := auth.uid();
  v_item    jsonb;
  v_qid     uuid;
  v_ok      boolean;
  v_total   int := 0;
  v_correct int := 0;
  v_detail  jsonb := '[]'::jsonb;
  v_store   jsonb := '[]'::jsonb;
  v_seen    uuid[] := '{}';
  v_id      uuid;
  v_score   int;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  if p_mode not in ('category', 'mixed', 'weak') then
    raise exception 'invalid_mode' using errcode = '22023';
  end if;
  if p_answers is null or jsonb_typeof(p_answers) <> 'array'
     or jsonb_array_length(p_answers) = 0 or jsonb_array_length(p_answers) > 50 then
    raise exception 'invalid_answers' using errcode = '22023';
  end if;

  for v_item in select * from jsonb_array_elements(p_answers) loop
    begin
      v_qid := (v_item ->> 'question_id')::uuid;
    exception when invalid_text_representation then
      raise exception 'invalid_answers' using errcode = '22023';
    end;
    if v_qid is null or v_qid = any (v_seen) then
      continue;   -- duplikat diabaikan
    end if;
    v_seen := v_seen || v_qid;
    if not exists (select 1 from public.questions where id = v_qid and quiz_id is null)
       or not public.can_read_question(v_qid) then
      raise exception 'question_not_available' using errcode = 'P0002';
    end if;
    v_ok := public.grade_question(v_qid, v_item -> 'answer');
    v_total := v_total + 1;
    if v_ok then v_correct := v_correct + 1; end if;
    v_store  := v_store  || jsonb_build_object('question_id', v_qid, 'is_correct', v_ok);
    v_detail := v_detail || (jsonb_build_object('question_id', v_qid, 'is_correct', v_ok,
                                                'given', v_item -> 'answer')
                             || coalesce(public.answer_reveal(v_qid), '{}'::jsonb));
  end loop;

  if v_total = 0 then
    raise exception 'invalid_answers' using errcode = '22023';
  end if;
  v_score := round(100.0 * v_correct / v_total)::int;
  insert into public.quiz_sessions (user_id, mode, module, category_id, difficulty,
                                    score_percent, correct_count, total_count, answers, started_at)
  values (v_uid, p_mode, p_module, p_category_id, p_difficulty,
          v_score, v_correct, v_total, v_store, p_started_at)
  returning id into v_id;

  return jsonb_build_object('session_id', v_id, 'score_percent', v_score,
                            'correct_count', v_correct, 'total_count', v_total,
                            'details', v_detail);
end $$;
revoke all on function public.submit_quiz_session(text, jsonb, text, uuid, text, timestamptz) from public, anon;
grant execute on function public.submit_quiz_session(text, jsonb, text, uuid, text, timestamptz) to authenticated;
