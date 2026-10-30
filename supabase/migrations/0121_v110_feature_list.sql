-- 0121_v110_feature_list.sql — BISINDO v1.1.0 (penyesuaian daftar fitur A–L)
-- 1) Animasi GIF: media berjenis video (animasi gerakan) dan gambar boleh GIF.
-- 2) Alfabet & Angka wajib punya penjelasan gerakan sebelum dipublikasikan
--    (B.3, C, L.4). Hanya berlaku saat transisi ke published; data lama aman.
-- 3) Setiap media punya judul/identitas (J.9): bila kosong, diisi otomatis
--    dari nama berkas. Media lama tanpa judul tidak diubah sampai disunting.
-- 4) Pemecahan kalimat percakapan menjadi bagian/kosakata + arti tiap bagian
--    (E): tabel conversation_item_parts.
-- 5) Soal latihan per topik percakapan (E: latihan memahami percakapan):
--    questions.conversation_module_id + parameter baru get_quiz_questions.
-- 6) Pengaturan konten beranda (I.15): app_settings 'home_layout'.
-- Tidak ada data lama yang diubah atau dihapus.

-- ============================================================ 1) GIF
alter table public.media_assets drop constraint if exists media_mime_matches_kind;
alter table public.media_assets add constraint media_mime_matches_kind check (
  (kind = 'video' and mime_type in ('video/mp4', 'video/webm', 'image/gif')) or
  (kind = 'image' and mime_type in ('image/jpeg', 'image/png', 'image/webp', 'image/gif')) or
  (kind = 'audio' and mime_type in ('audio/mpeg', 'audio/mp4', 'audio/aac', 'audio/x-m4a'))
);

update storage.buckets
   set allowed_mime_types = array['video/mp4','video/webm','image/jpeg','image/png','image/webp','image/gif',
                                  'audio/mpeg','audio/mp4','audio/aac','audio/x-m4a']
 where id = 'bisindo-media';

-- ============================================================ 2) penjelasan wajib
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
    if coalesce(btrim(s.movement_description), '') = '' then v := array_append(v, 'Penjelasan gerakan wajib diisi'::text); end if;
  elsif s.content_module = 'number' then
    if coalesce(btrim(s.symbol), '') = '' then v := array_append(v, 'Angka wajib diisi'::text); end if;
    if s.number_group is null then v := array_append(v, 'Kelompok angka wajib dipilih'::text); end if;
    if coalesce(btrim(s.movement_description), '') = '' then v := array_append(v, 'Penjelasan gerakan wajib diisi'::text); end if;
  end if;
  return v;
end $$;
revoke all on function public.sign_publish_issues(public.signs) from public, anon, authenticated;

-- ============================================================ 3) identitas media
-- Media tanpa judul (mis. unggahan dari admin dalam aplikasi 1.0.0) otomatis
-- diberi identitas dari nama berkas asli / nama berkas di storage, sehingga
-- unggahan lama tetap berfungsi dan setiap media tetap punya identitas.
create or replace function public.media_default_title()
returns trigger language plpgsql set search_path = '' as $$
begin
  if coalesce(btrim(new.title), '') = '' then
    new.title := left(coalesce(nullif(btrim(new.original_filename), ''),
                               regexp_replace(new.path, '^.*/', '')), 160);
  end if;
  return new;
end $$;
create trigger media_default_title before insert or update on public.media_assets
  for each row execute function public.media_default_title();

-- ============================================================ 4) bagian kalimat
create table public.conversation_item_parts (
  id         uuid primary key default gen_random_uuid(),
  item_id    uuid not null references public.conversation_items (id) on delete cascade,
  position   int  not null check (position >= 0),
  part_text  text check (part_text is null or char_length(btrim(part_text)) between 1 and 120),
  meaning    text check (meaning is null or char_length(meaning) <= 500),
  sign_id    uuid references public.signs (id) on delete set null,
  created_at timestamptz not null default now(),
  constraint conv_parts_has_content check (sign_id is not null or part_text is not null),
  constraint conv_parts_position_uniq unique (item_id, position) deferrable initially deferred
);
create index conv_parts_item_idx on public.conversation_item_parts (item_id, position);
create index conv_parts_sign_idx on public.conversation_item_parts (sign_id);

alter table public.conversation_item_parts enable row level security;
grant select on public.conversation_item_parts to authenticated;
grant insert, update, delete on public.conversation_item_parts to authenticated;
-- Terlihat bila kalimatnya terlihat (RLS conversation_items berlaku di subquery).
create policy conv_parts_read on public.conversation_item_parts for select to authenticated
  using (public.is_admin() or exists (select 1 from public.conversation_items i where i.id = item_id));
create policy conv_parts_admin on public.conversation_item_parts for all to authenticated
  using (public.is_admin()) with check (public.is_admin());
create policy conversation_item_parts_active_account_only on public.conversation_item_parts
  as restrictive for select to authenticated using (public.is_active_user());

-- Simpan seluruh kalimat satu topik sekaligus (urutan = urutan array).
-- p_items: [{id?, speaker_label, text_id, translation, explanation, context_note,
--            sign_id, video_asset_id, audio_asset_id,
--            parts?: [{part_text, meaning, sign_id}]}]
-- Bila "parts" tidak dikirim, bagian kalimat yang ada tidak diubah.
create or replace function public.admin_save_conversation_items(p_module_id uuid, p_items jsonb)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_status public.content_status;
  v_issues text[];
  e        jsonb;
  ord      bigint;
  v_item   uuid;
begin
  perform public.assert_admin();
  if jsonb_typeof(p_items) <> 'array' then
    raise exception 'invalid_items' using errcode = '22023';
  end if;
  select status into v_status from public.conversation_modules where id = p_module_id for update;
  if not found then raise exception 'module_not_found' using errcode = 'P0002'; end if;

  set constraints public.conv_items_position_uniq deferred;
  set constraints public.conv_parts_position_uniq deferred;
  delete from public.conversation_items i
   where i.module_id = p_module_id
     and i.id not in (select (x ->> 'id')::uuid from jsonb_array_elements(p_items) x where x ->> 'id' is not null);

  for e, ord in select x, o from jsonb_array_elements(p_items) with ordinality t(x, o) loop
    v_item := coalesce((nullif(e ->> 'id', ''))::uuid, gen_random_uuid());
    insert into public.conversation_items as ci (id, module_id, position, speaker_label, text_id, translation,
                                                explanation, context_note, sign_id, video_asset_id, audio_asset_id)
    values (v_item, p_module_id, (ord - 1)::int,
            coalesce(nullif(btrim(e ->> 'speaker_label'), ''), 'A'), e ->> 'text_id',
            nullif(btrim(e ->> 'translation'), ''), nullif(btrim(e ->> 'explanation'), ''),
            nullif(btrim(e ->> 'context_note'), ''),
            (nullif(e ->> 'sign_id', ''))::uuid, (nullif(e ->> 'video_asset_id', ''))::uuid,
            (nullif(e ->> 'audio_asset_id', ''))::uuid)
    on conflict (id) do update set
      position = excluded.position, speaker_label = excluded.speaker_label, text_id = excluded.text_id,
      translation = excluded.translation, explanation = excluded.explanation, context_note = excluded.context_note,
      sign_id = excluded.sign_id, video_asset_id = excluded.video_asset_id, audio_asset_id = excluded.audio_asset_id
    where ci.module_id = p_module_id;
    if not found then
      raise exception 'item_belongs_to_other_module' using errcode = '42501';
    end if;

    if jsonb_typeof(e -> 'parts') = 'array' then
      delete from public.conversation_item_parts where item_id = v_item;
      insert into public.conversation_item_parts (item_id, position, part_text, meaning, sign_id)
      select v_item, (po - 1)::int, nullif(btrim(p ->> 'part_text'), ''), nullif(btrim(p ->> 'meaning'), ''),
             (nullif(p ->> 'sign_id', ''))::uuid
      from jsonb_array_elements(e -> 'parts') with ordinality pp(p, po)
      where nullif(btrim(p ->> 'part_text'), '') is not null or nullif(p ->> 'sign_id', '') is not null;
    end if;
  end loop;

  if v_status = 'published' then
    v_issues := public.module_publish_issues((select m from public.conversation_modules m where m.id = p_module_id));
    if cardinality(v_issues) > 0 then
      raise exception 'publish_blocked: %', array_to_string(v_issues, '; ') using errcode = '23514';
    end if;
  end if;
end $$;
revoke all on function public.admin_save_conversation_items(uuid, jsonb) from public, anon;
grant execute on function public.admin_save_conversation_items(uuid, jsonb) to authenticated;

-- ============================================================ 5) soal per topik percakapan
alter table public.questions
  add column conversation_module_id uuid references public.conversation_modules (id) on delete set null,
  add constraint questions_conv_module_needs_conv check (
    conversation_module_id is null or module = 'conversation');
create index questions_conv_module_idx on public.questions (conversation_module_id)
  where conversation_module_id is not null;

drop function public.get_quiz_questions(text, text, uuid, text, int);
create function public.get_quiz_questions(
  p_mode        text default 'category',
  p_module      text default null,
  p_category_id uuid default null,
  p_difficulty  text default null,
  p_limit       int  default 10,
  p_conversation_module_id uuid default null
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
                                    and (p_category_id is null or q.category_id = p_category_id)
                                    and (p_conversation_module_id is null
                                         or q.conversation_module_id = p_conversation_module_id)))
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
           'conversation_module_id', q.conversation_module_id,
           'difficulty', q.difficulty,
           'is_premium', q.is_premium,
           'video_path', coalesce(mv.path, sv.path),
           'video_mime', coalesce(mv.mime_type, sv.mime_type),
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
revoke all on function public.get_quiz_questions(text, text, uuid, text, int, uuid) from public, anon;
grant execute on function public.get_quiz_questions(text, text, uuid, text, int, uuid) to authenticated;

-- admin_save_question: sama seperti 0119, ditambah conversation_module_id.
create or replace function public.admin_save_question(p jsonb)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_id     uuid := (nullif(p ->> 'id', ''))::uuid;
  v_status public.content_status := coalesce((p ->> 'status')::public.content_status, 'draft');
  v_type   text := coalesce(p ->> 'question_type', 'multiple_choice');
  v_conv   uuid := (nullif(p ->> 'conversation_module_id', ''))::uuid;
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
    insert into public.questions (quiz_id, position, module, category_id, conversation_module_id, question_type,
                                  prompt, difficulty, sort_order, status, is_active, is_premium, sign_id,
                                  video_asset_id, image_asset_id)
    values ((nullif(p ->> 'quiz_id', ''))::uuid, coalesce((p ->> 'position')::int, 0), nullif(p ->> 'module', ''),
            (nullif(p ->> 'category_id', ''))::uuid, v_conv, v_type, p ->> 'prompt',
            coalesce(nullif(p ->> 'difficulty', ''), 'medium'), coalesce((p ->> 'sort_order')::int, 0), 'draft',
            coalesce((p ->> 'is_active')::boolean, true), coalesce((p ->> 'is_premium')::boolean, false),
            (nullif(p ->> 'sign_id', ''))::uuid, (nullif(p ->> 'video_asset_id', ''))::uuid,
            (nullif(p ->> 'image_asset_id', ''))::uuid)
    returning id into v_id;
  else
    update public.questions set
      module = nullif(p ->> 'module', ''), category_id = (nullif(p ->> 'category_id', ''))::uuid,
      conversation_module_id = v_conv,
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

-- ============================================================ 6) konten beranda
insert into public.app_settings (key, value, is_public, description) values
  ('home_layout',
   '{"intro_title": null, "intro_text": null,
     "sections": {"intro": true, "continue": true, "modules": true, "progress": true,
                  "recommendations": true, "premium": true}}',
   true,
   'Konten beranda aplikasi: teks banner perkenalan (kosong = teks bawaan aplikasi) dan bagian yang ditampilkan.')
on conflict (key) do nothing;
