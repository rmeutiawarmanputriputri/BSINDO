-- ROLLBACK 0121_v110_feature_list.sql
-- ⚠️ Menghapus bagian kalimat percakapan (conversation_item_parts) dan kaitan soal
--    ke topik percakapan (questions.conversation_module_id).
-- ⚠️ Media GIF harus dihapus/diganti dulu; bila masih ada, langkah constraint gagal
--    dan seluruh rollback dibatalkan (tidak ada yang berubah).
-- Fungsi dikembalikan persis ke versi 0114/0118/0119.

drop trigger if exists media_default_title on public.media_assets;
drop function if exists public.media_default_title();

drop table if exists public.conversation_item_parts;

create or replace function public.admin_save_conversation_items(p_module_id uuid, p_items jsonb)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_status public.content_status;
  v_issues text[];
begin
  perform public.assert_admin();
  if jsonb_typeof(p_items) <> 'array' then
    raise exception 'invalid_items' using errcode = '22023';
  end if;
  select status into v_status from public.conversation_modules where id = p_module_id for update;
  if not found then raise exception 'module_not_found' using errcode = 'P0002'; end if;

  set constraints public.conv_items_position_uniq deferred;
  delete from public.conversation_items i
   where i.module_id = p_module_id
     and i.id not in (select (e ->> 'id')::uuid from jsonb_array_elements(p_items) e where e ->> 'id' is not null);

  insert into public.conversation_items as ci (id, module_id, position, speaker_label, text_id, translation,
                                              explanation, context_note, sign_id, video_asset_id, audio_asset_id)
  select coalesce((e ->> 'id')::uuid, gen_random_uuid()), p_module_id, (ord - 1)::int,
         coalesce(nullif(btrim(e ->> 'speaker_label'), ''), 'A'), e ->> 'text_id',
         nullif(btrim(e ->> 'translation'), ''), nullif(btrim(e ->> 'explanation'), ''),
         nullif(btrim(e ->> 'context_note'), ''),
         (nullif(e ->> 'sign_id', ''))::uuid, (nullif(e ->> 'video_asset_id', ''))::uuid,
         (nullif(e ->> 'audio_asset_id', ''))::uuid
  from jsonb_array_elements(p_items) with ordinality x(e, ord)
  on conflict (id) do update set
    position = excluded.position, speaker_label = excluded.speaker_label, text_id = excluded.text_id,
    translation = excluded.translation, explanation = excluded.explanation, context_note = excluded.context_note,
    sign_id = excluded.sign_id, video_asset_id = excluded.video_asset_id, audio_asset_id = excluded.audio_asset_id
  where ci.module_id = p_module_id;

  -- Topik yang sudah published tidak boleh menjadi tidak valid.
  if v_status = 'published' then
    v_issues := public.module_publish_issues((select m from public.conversation_modules m where m.id = p_module_id));
    if cardinality(v_issues) > 0 then
      raise exception 'publish_blocked: %', array_to_string(v_issues, '; ') using errcode = '23514';
    end if;
  end if;
end $$;
revoke all on function public.admin_save_conversation_items(uuid, jsonb) from public, anon;
grant execute on function public.admin_save_conversation_items(uuid, jsonb) to authenticated;

drop function if exists public.get_quiz_questions(text, text, uuid, text, int, uuid);
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

create or replace function public.admin_save_question(p jsonb)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_id     uuid := (nullif(p ->> 'id', ''))::uuid;
  v_status public.content_status := coalesce((p ->> 'status')::public.content_status, 'draft');
  v_type   text := coalesce(p ->> 'question_type', 'multiple_choice');
  v_opt_ids uuid[] := '{}';
  v_oid    uuid;
  e        jsonb;
  i        int := 0;
  v_seq    uuid[];
  v_pairs  jsonb;
begin
  perform public.assert_admin();
  if jsonb_typeof(p -> 'options') is distinct from 'array' then
    raise exception 'invalid_options' using errcode = '22023';
  end if;

  if v_id is null then
    insert into public.questions (quiz_id, position, module, category_id, question_type, prompt, difficulty,
                                  sort_order, status, is_active, is_premium, sign_id, video_asset_id, image_asset_id)
    values ((nullif(p ->> 'quiz_id', ''))::uuid, coalesce((p ->> 'position')::int, 0), nullif(p ->> 'module', ''),
            (nullif(p ->> 'category_id', ''))::uuid, v_type, p ->> 'prompt',
            coalesce(nullif(p ->> 'difficulty', ''), 'medium'), coalesce((p ->> 'sort_order')::int, 0), 'draft',
            coalesce((p ->> 'is_active')::boolean, true), coalesce((p ->> 'is_premium')::boolean, false),
            (nullif(p ->> 'sign_id', ''))::uuid, (nullif(p ->> 'video_asset_id', ''))::uuid,
            (nullif(p ->> 'image_asset_id', ''))::uuid)
    returning id into v_id;
  else
    update public.questions set
      module = nullif(p ->> 'module', ''), category_id = (nullif(p ->> 'category_id', ''))::uuid,
      question_type = v_type, prompt = p ->> 'prompt',
      difficulty = coalesce(nullif(p ->> 'difficulty', ''), 'medium'),
      sort_order = coalesce((p ->> 'sort_order')::int, sort_order),
      status = 'draft',
      is_active = coalesce((p ->> 'is_active')::boolean, true),
      is_premium = coalesce((p ->> 'is_premium')::boolean, false),
      sign_id = (nullif(p ->> 'sign_id', ''))::uuid,
      video_asset_id = (nullif(p ->> 'video_asset_id', ''))::uuid,
      image_asset_id = (nullif(p ->> 'image_asset_id', ''))::uuid
    where id = v_id;
    if not found then raise exception 'question_not_found' using errcode = 'P0002'; end if;
    delete from public.question_answer_keys where question_id = v_id;
    delete from public.question_options where question_id = v_id;
  end if;

  for e in select * from jsonb_array_elements(p -> 'options') loop
    insert into public.question_options (question_id, position, label, image_asset_id, side)
    values (v_id, i, e ->> 'label', (nullif(e ->> 'image_asset_id', ''))::uuid, nullif(e ->> 'side', ''))
    returning id into v_oid;
    v_opt_ids := v_opt_ids || v_oid;
    i := i + 1;
  end loop;

  if v_type = 'arrange_word' then
    if jsonb_typeof(p -> 'correct_sequence') = 'array' then
      select array_agg(v_opt_ids[(x::int) + 1] order by o) into v_seq
        from jsonb_array_elements_text(p -> 'correct_sequence') with ordinality s(x, o);
    end if;
    if v_seq is not null then
      insert into public.question_answer_keys (question_id, correct_sequence, explanation)
      values (v_id, v_seq, nullif(btrim(p ->> 'explanation'), ''));
    end if;
  elsif v_type = 'match_image' then
    if jsonb_typeof(p -> 'pairs') = 'array' and jsonb_array_length(p -> 'pairs') > 0 then
      select jsonb_agg(jsonb_build_object('left', v_opt_ids[(x ->> 'left')::int + 1],
                                          'right', v_opt_ids[(x ->> 'right')::int + 1]))
        into v_pairs from jsonb_array_elements(p -> 'pairs') x;
      insert into public.question_answer_keys (question_id, pairs, explanation)
      values (v_id, v_pairs, nullif(btrim(p ->> 'explanation'), ''));
    end if;
  elsif p ->> 'correct_index' is not null then
    insert into public.question_answer_keys (question_id, correct_option_id, explanation)
    values (v_id, v_opt_ids[(p ->> 'correct_index')::int + 1], nullif(btrim(p ->> 'explanation'), ''));
  end if;

  if v_status <> 'draft' then
    update public.questions set status = v_status where id = v_id;   -- guard_publish memvalidasi di sini
  end if;
  return v_id;
end $$;
revoke all on function public.admin_save_question(jsonb) from public, anon;
grant execute on function public.admin_save_question(jsonb) to authenticated;

alter table public.questions drop column if exists conversation_module_id;

create or replace function public.sign_publish_issues(s public.signs)
returns text[] language plpgsql stable security definer set search_path = '' as $$
declare
  v text[] := '{}';
  v_media_status public.content_status;
begin
  if s.term is null or btrim(s.term) = '' then v := array_append(v, 'Judul/istilah wajib diisi'::text); end if;
  if s.video_asset_id is null then
    v := array_append(v, 'Video gerakan wajib diunggah'::text);
  else
    select status into v_media_status from public.media_assets where id = s.video_asset_id;
    if v_media_status is distinct from 'published' then v := array_append(v, 'Video belum berstatus Published di Media'::text); end if;
  end if;
  if coalesce(btrim(s.validated_by), '') = '' then v := array_append(v, 'Nama validator wajib diisi'::text); end if;
  if coalesce(btrim(s.source_note), '') = '' then v := array_append(v, 'Sumber materi wajib diisi'::text); end if;
  if s.verified_at is null then v := array_append(v, 'Tanggal verifikasi wajib diisi'::text); end if;
  if s.content_module = 'vocabulary' then
    if s.category_id is null then v := array_append(v, 'Kategori wajib dipilih'::text); end if;
    if coalesce(btrim(s.meaning), '') = '' then v := array_append(v, 'Arti wajib diisi'::text); end if;
  elsif s.content_module = 'alphabet' then
    if coalesce(btrim(s.symbol), '') = '' then v := array_append(v, 'Huruf wajib diisi'::text); end if;
  elsif s.content_module = 'number' then
    if coalesce(btrim(s.symbol), '') = '' then v := array_append(v, 'Angka wajib diisi'::text); end if;
    if s.number_group is null then v := array_append(v, 'Kelompok angka wajib dipilih'::text); end if;
  end if;
  return v;
end $$;
revoke all on function public.sign_publish_issues(public.signs) from public, anon, authenticated;

alter table public.media_assets drop constraint if exists media_mime_matches_kind;
alter table public.media_assets add constraint media_mime_matches_kind check (
  (kind = 'video' and mime_type in ('video/mp4', 'video/webm')) or
  (kind = 'image' and mime_type in ('image/jpeg', 'image/png', 'image/webp')) or
  (kind = 'audio' and mime_type in ('audio/mpeg', 'audio/mp4', 'audio/aac', 'audio/x-m4a'))
);
update storage.buckets
   set allowed_mime_types = array['video/mp4','video/webm','image/jpeg','image/png','image/webp',
                                  'audio/mpeg','audio/mp4','audio/aac','audio/x-m4a']
 where id = 'bisindo-media';

delete from public.app_settings where key = 'home_layout';
