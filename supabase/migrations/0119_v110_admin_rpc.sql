-- 0119_v110_admin_rpc.sql — BISINDO v1.1.0
-- RPC untuk CMS. Semua SECURITY DEFINER dan memeriksa is_admin() di awal,
-- sehingga pengguna biasa ditolak DI SERVER (bukan hanya disembunyikan di UI).

create or replace function public.assert_admin()
returns void language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_admin() or not public.is_active_user() then
    raise exception 'not_admin' using errcode = '42501';
  end if;
end $$;
revoke all on function public.assert_admin() from public, anon;
grant execute on function public.assert_admin() to authenticated;

-- ============================================================ dashboard
create or replace function public.admin_dashboard_stats()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  perform public.assert_admin();
  return jsonb_build_object(
    'users_total',    (select count(*) from public.profiles),
    'users_inactive', (select count(*) from public.profiles where not is_active),
    'users_new_7d',   (select count(*) from public.profiles where created_at > now() - interval '7 days'),
    'users_active_7d', (select count(distinct u) from (
        select user_id u from public.sign_progress where last_viewed_at > now() - interval '7 days'
        union select user_id from public.user_progress where last_accessed_at > now() - interval '7 days'
        union select user_id from public.quiz_sessions where submitted_at > now() - interval '7 days'
        union select user_id from public.quiz_attempts where submitted_at > now() - interval '7 days') a),
    'premium_users',  (select count(*) from public.subscriptions s where s.is_premium and s.status = 'active'
                         and (s.expires_at is null or s.expires_at > now())),
    'categories',     (select count(*) from public.categories),
    'signs_by_module', (select coalesce(jsonb_object_agg(content_module, n), '{}'::jsonb)
                          from (select content_module, count(*) n from public.signs group by 1) x),
    'signs_by_status', (select coalesce(jsonb_object_agg(status, n), '{}'::jsonb)
                          from (select status::text, count(*) n from public.signs group by 1) x),
    'materials_total', (select count(*) from public.signs) + (select count(*) from public.conversation_modules)
                       + (select count(*) from public.lessons),
    'materials_published', (select count(*) from public.signs where status = 'published')
                       + (select count(*) from public.conversation_modules where status = 'published')
                       + (select count(*) from public.lessons where status = 'published'),
    'drafts', (select count(*) from public.signs where status = 'draft')
            + (select count(*) from public.conversation_modules where status = 'draft')
            + (select count(*) from public.lessons where status = 'draft')
            + (select count(*) from public.questions where quiz_id is null and status = 'draft'),
    'conversation_topics', (select count(*) from public.conversation_modules),
    'conversation_sentences', (select count(*) from public.conversation_items),
    'lessons', (select count(*) from public.lessons),
    'videos', (select count(*) from public.media_assets where kind = 'video'),
    'audios', (select count(*) from public.media_assets where kind = 'audio'),
    'images', (select count(*) from public.media_assets where kind = 'image'),
    'media_bytes', (select coalesce(sum(size_bytes), 0) from public.media_assets),
    'quiz_questions', (select count(*) from public.questions),
    'quiz_questions_bank', (select count(*) from public.questions where quiz_id is null),
    'quiz_sessions_total', (select count(*) from public.quiz_sessions) + (select count(*) from public.quiz_attempts),
    'quiz_sessions_7d', (select count(*) from public.quiz_sessions where submitted_at > now() - interval '7 days')
                      + (select count(*) from public.quiz_attempts where submitted_at > now() - interval '7 days'),
    'open_reports', (select count(*) from public.content_reports where status in ('open', 'in_review')),
    'banners_active', (select count(*) from public.banners where is_active),
    'daily_active', (
      select coalesce(jsonb_agg(jsonb_build_object('day', d::date, 'users', coalesce(n, 0)) order by d), '[]'::jsonb)
      from generate_series(current_date - 13, current_date, interval '1 day') d
      left join (
        select z.dy, count(distinct z.u) n from (
          select last_viewed_at::date as dy, user_id as u from public.sign_progress
          union all select submitted_at::date, user_id from public.quiz_sessions
          union all select last_accessed_at::date, user_id from public.user_progress) z
        group by z.dy) a on a.dy = d::date),
    'recent_activity', (
      select coalesce(jsonb_agg(e order by (e ->> 'at') desc), '[]'::jsonb) from (
        (select jsonb_build_object('type', 'user_registered', 'at', p.created_at, 'name', p.full_name) e
           from public.profiles p order by p.created_at desc limit 8)
        union all
        (select jsonb_build_object('type', 'quiz_finished', 'at', q.submitted_at, 'name', p.full_name,
                                   'score', q.score_percent, 'mode', q.mode)
           from public.quiz_sessions q join public.profiles p on p.id = q.user_id
           order by q.submitted_at desc limit 8)
        union all
        (select jsonb_build_object('type', 'content_updated', 'at', s.updated_at, 'name', s.term,
                                   'status', s.status, 'module', s.content_module)
           from public.signs s order by s.updated_at desc limit 8)) x)
  );
end $$;
revoke all on function public.admin_dashboard_stats() from public, anon;
grant execute on function public.admin_dashboard_stats() to authenticated;

-- ============================================================ media
create or replace function public.media_usage(p_asset_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  perform public.assert_admin();
  return coalesce((select jsonb_agg(u) from (
      select jsonb_build_object('type', 'sign', 'module', s.content_module, 'id', s.id, 'title', s.term, 'status', s.status,
               'field', case p_asset_id when s.video_asset_id then 'video' when s.thumbnail_asset_id then 'thumbnail'
                                        when s.image_asset_id then 'image' else 'audio' end) u
        from public.signs s
        where p_asset_id in (s.video_asset_id, s.thumbnail_asset_id, s.image_asset_id, s.audio_asset_id)
      union all
      select jsonb_build_object('type', 'conversation', 'id', c.id, 'title', c.title, 'status', c.status, 'field', 'thumbnail')
        from public.conversation_modules c where c.thumbnail_asset_id = p_asset_id
      union all
      select jsonb_build_object('type', 'conversation_item', 'id', i.id, 'parent_id', c.id,
               'title', c.title || ' — kalimat ' || (i.position + 1), 'status', c.status,
               'field', case when i.video_asset_id = p_asset_id then 'video' else 'audio' end)
        from public.conversation_items i join public.conversation_modules c on c.id = i.module_id
        where p_asset_id in (i.video_asset_id, i.audio_asset_id)
      union all
      select jsonb_build_object('type', 'lesson', 'id', l.id, 'title', l.title, 'status', l.status, 'field', 'thumbnail')
        from public.lessons l where l.thumbnail_asset_id = p_asset_id
      union all
      select jsonb_build_object('type', 'category', 'id', c.id, 'title', c.name,
               'status', case when c.is_active then 'active' else 'inactive' end, 'field', 'image')
        from public.categories c where c.image_asset_id = p_asset_id
      union all
      select jsonb_build_object('type', 'banner', 'id', b.id, 'title', b.title,
               'status', case when b.is_active then 'active' else 'inactive' end, 'field', 'image')
        from public.banners b where b.image_asset_id = p_asset_id
      union all
      select jsonb_build_object('type', 'question', 'id', q.id, 'title', left(q.prompt, 80), 'status', q.status,
               'field', case when q.video_asset_id = p_asset_id then 'video' else 'image' end)
        from public.questions q where p_asset_id in (q.video_asset_id, q.image_asset_id)
      union all
      select jsonb_build_object('type', 'question_option', 'id', o.id, 'parent_id', o.question_id,
               'title', o.label, 'status', q.status, 'field', 'image')
        from public.question_options o join public.questions q on q.id = o.question_id
        where o.image_asset_id = p_asset_id) z), '[]'::jsonb);
end $$;
revoke all on function public.media_usage(uuid) from public, anon;
grant execute on function public.media_usage(uuid) to authenticated;

-- Hapus baris media. Mengembalikan {bucket, path} agar CMS menghapus berkas
-- lewat Storage API (Supabase melarang DELETE langsung pada storage.objects).
-- Ditolak bila masih dipakai, kecuali p_force; materi published yang akan
-- kehilangan media wajib tetap DITOLAK oleh trigger guard_publish.
create or replace function public.admin_delete_media(p_asset_id uuid, p_force boolean default false)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_usage jsonb;
  m public.media_assets;
begin
  perform public.assert_admin();
  select * into m from public.media_assets where id = p_asset_id;
  if not found then
    raise exception 'media_not_found' using errcode = 'P0002';
  end if;
  v_usage := public.media_usage(p_asset_id);
  if jsonb_array_length(v_usage) > 0 and not coalesce(p_force, false) then
    raise exception 'media_in_use: dipakai % materi', jsonb_array_length(v_usage)
      using errcode = '23503', detail = v_usage::text;
  end if;
  delete from public.media_assets where id = p_asset_id;
  return jsonb_build_object('bucket', m.bucket, 'path', m.path, 'unlinked', v_usage);
end $$;
revoke all on function public.admin_delete_media(uuid, boolean) from public, anon;
grant execute on function public.admin_delete_media(uuid, boolean) to authenticated;

-- Ganti berkas media (id tetap → semua materi yang memakainya ikut berganti).
-- Berkas baru sudah diunggah ke p_new_path. Mengembalikan path lama untuk dihapus.
create or replace function public.admin_replace_media_file(
  p_asset_id uuid, p_new_path text, p_mime_type text, p_size_bytes bigint,
  p_original_filename text default null, p_duration_ms int default null,
  p_width int default null, p_height int default null
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare m public.media_assets;
begin
  perform public.assert_admin();
  select * into m from public.media_assets where id = p_asset_id for update;
  if not found then
    raise exception 'media_not_found' using errcode = 'P0002';
  end if;
  update public.media_assets
     set path = p_new_path, mime_type = p_mime_type, size_bytes = p_size_bytes,
         original_filename = coalesce(p_original_filename, original_filename),
         duration_ms = p_duration_ms, width = p_width, height = p_height
   where id = p_asset_id;
  return jsonb_build_object('bucket', m.bucket, 'old_path', m.path, 'new_path', p_new_path);
end $$;
revoke all on function public.admin_replace_media_file(uuid, text, text, bigint, text, int, int, int) from public, anon;
grant execute on function public.admin_replace_media_file(uuid, text, text, bigint, text, int, int, int) to authenticated;

-- ============================================================ pengguna
-- p_filter: null | 'premium' | 'inactive' | 'admin'
create or replace function public.admin_list_users(
  p_search text default null, p_limit int default 50, p_offset int default 0, p_filter text default null
) returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_q text := nullif(btrim(coalesce(p_search, '')), '');
begin
  perform public.assert_admin();
  if p_filter is not null and p_filter not in ('premium', 'inactive', 'admin') then
    raise exception 'invalid_filter' using errcode = '22023';
  end if;
  return jsonb_build_object(
    'total', (select count(*) from public.profiles p join auth.users u on u.id = p.id
              where (v_q is null or p.full_name ilike '%' || v_q || '%' or u.email ilike '%' || v_q || '%')
                and (p_filter is null or (p_filter = 'premium' and public.has_premium(p.id))
                     or (p_filter = 'inactive' and not p.is_active) or (p_filter = 'admin' and p.role = 'admin'))),
    'rows', coalesce((select jsonb_agg(r order by r ->> 'created_at' desc) from (
      select jsonb_build_object(
        'id', p.id, 'full_name', p.full_name, 'email', u.email, 'role', p.role,
        'is_active', p.is_active, 'created_at', p.created_at, 'last_sign_in_at', u.last_sign_in_at,
        'is_premium', public.has_premium(p.id), 'plan', s.plan, 'premium_status', coalesce(s.status, 'none'),
        'premium_expires_at', s.expires_at) r
      from public.profiles p
      join auth.users u on u.id = p.id
      left join public.subscriptions s on s.user_id = p.id
      where (v_q is null or p.full_name ilike '%' || v_q || '%' or u.email ilike '%' || v_q || '%')
                and (p_filter is null or (p_filter = 'premium' and public.has_premium(p.id))
                     or (p_filter = 'inactive' and not p.is_active) or (p_filter = 'admin' and p.role = 'admin'))
      order by p.created_at desc
      limit greatest(1, least(coalesce(p_limit, 50), 200)) offset greatest(0, coalesce(p_offset, 0))) x), '[]'::jsonb));
end $$;
revoke all on function public.admin_list_users(text, int, int, text) from public, anon;
grant execute on function public.admin_list_users(text, int, int, text) to authenticated;

create or replace function public.admin_user_detail(p_user_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  perform public.assert_admin();
  return (
    select jsonb_build_object(
      'id', p.id, 'full_name', p.full_name, 'email', u.email, 'role', p.role, 'is_active', p.is_active,
      'created_at', p.created_at, 'last_sign_in_at', u.last_sign_in_at,
      'subscription', (select to_jsonb(s) from public.subscriptions s where s.user_id = p.id),
      'is_premium', public.has_premium(p.id),
      'progress', jsonb_build_object(
        'signs_learned', (select count(*) from public.sign_progress where user_id = p.id and learned_at is not null),
        'signs_viewed', (select count(*) from public.sign_progress where user_id = p.id),
        'learned_by_module', (select coalesce(jsonb_object_agg(module, n), '{}'::jsonb) from (
            select s.content_module module, count(*) n from public.sign_progress sp join public.signs s on s.id = sp.sign_id
            where sp.user_id = p.id and sp.learned_at is not null group by 1) x),
        'lessons_completed', (select count(*) from public.user_progress where user_id = p.id and lesson_id is not null and status = 'completed'),
        'conversations_completed', (select count(*) from public.user_progress where user_id = p.id and conversation_module_id is not null and status = 'completed'),
        'favorites', (select count(*) from public.favorites where user_id = p.id),
        'quiz_sessions', (select count(*) from public.quiz_sessions where user_id = p.id),
        'quiz_avg', (select round(avg(score_percent)) from public.quiz_sessions where user_id = p.id),
        'last_activity', (select max(t) from (
            select max(last_viewed_at) t from public.sign_progress where user_id = p.id
            union all select max(submitted_at) from public.quiz_sessions where user_id = p.id
            union all select max(last_accessed_at) from public.user_progress where user_id = p.id) z)))
    from public.profiles p join auth.users u on u.id = p.id
    where p.id = p_user_id);
end $$;
revoke all on function public.admin_user_detail(uuid) from public, anon;
grant execute on function public.admin_user_detail(uuid) to authenticated;

create or replace function public.admin_set_user_role(p_user_id uuid, p_role public.app_role)
returns void language plpgsql security definer set search_path = '' as $$
begin
  perform public.assert_admin();
  if p_user_id = auth.uid() and p_role <> 'admin' then
    raise exception 'cannot_demote_self' using errcode = '42501';
  end if;
  update public.profiles set role = p_role where id = p_user_id;
  if not found then raise exception 'user_not_found' using errcode = 'P0002'; end if;
end $$;
revoke all on function public.admin_set_user_role(uuid, public.app_role) from public, anon;
grant execute on function public.admin_set_user_role(uuid, public.app_role) to authenticated;

create or replace function public.admin_set_user_active(p_user_id uuid, p_active boolean)
returns void language plpgsql security definer set search_path = '' as $$
begin
  perform public.assert_admin();
  if p_user_id = auth.uid() and not p_active then
    raise exception 'cannot_deactivate_self' using errcode = '42501';
  end if;
  update public.profiles set is_active = p_active where id = p_user_id;
  if not found then raise exception 'user_not_found' using errcode = 'P0002'; end if;
end $$;
revoke all on function public.admin_set_user_active(uuid, boolean) from public, anon;
grant execute on function public.admin_set_user_active(uuid, boolean) to authenticated;

create or replace function public.admin_set_premium(
  p_user_id uuid, p_is_premium boolean, p_plan text default null,
  p_expires_at timestamptz default null, p_note text default null
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare r public.subscriptions;
begin
  perform public.assert_admin();
  if not exists (select 1 from public.profiles where id = p_user_id) then
    raise exception 'user_not_found' using errcode = 'P0002';
  end if;
  if p_is_premium and p_expires_at is not null and p_expires_at <= now() then
    raise exception 'expires_in_past' using errcode = '22023';
  end if;
  insert into public.subscriptions as s (user_id, is_premium, plan, source, status, started_at, expires_at, note, updated_by)
  values (p_user_id, p_is_premium, p_plan, 'manual',
          case when p_is_premium then 'active' else 'cancelled' end,
          case when p_is_premium then now() end, p_expires_at, p_note, auth.uid())
  on conflict (user_id) do update set
    is_premium = excluded.is_premium, plan = excluded.plan, source = 'manual',
    status = excluded.status,
    started_at = case when excluded.is_premium then coalesce(s.started_at, now()) else s.started_at end,
    expires_at = excluded.expires_at, note = excluded.note, updated_by = auth.uid()
  returning * into r;
  return to_jsonb(r);
end $$;
revoke all on function public.admin_set_premium(uuid, boolean, text, timestamptz, text) from public, anon;
grant execute on function public.admin_set_premium(uuid, boolean, text, timestamptz, text) to authenticated;

-- ============================================================ urutan
create or replace function public.admin_reorder(p_table text, p_ids uuid[])
returns void language plpgsql security definer set search_path = '' as $$
begin
  perform public.assert_admin();
  if p_table not in ('categories', 'signs', 'conversation_modules', 'lessons', 'banners', 'faqs', 'questions') then
    raise exception 'invalid_table' using errcode = '22023';
  end if;
  execute format(
    'update public.%I t set sort_order = x.ord - 1
       from unnest($1) with ordinality x(id, ord) where t.id = x.id', p_table)
  using p_ids;
end $$;
revoke all on function public.admin_reorder(text, uuid[]) from public, anon;
grant execute on function public.admin_reorder(text, uuid[]) to authenticated;

-- Simpan seluruh kalimat satu topik sekaligus (urutan = urutan array).
-- p_items: [{id?, speaker_label, text_id, translation, explanation, context_note,
--            sign_id, video_asset_id, audio_asset_id}]
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

-- ============================================================ soal
-- Simpan soal + pilihan + kunci secara atomik. Status target diterapkan
-- PALING AKHIR sehingga validasi publikasi melihat pilihan & kunci terbaru.
-- p: {id?, quiz_id?, module, category_id, question_type, prompt, difficulty,
--     sort_order, status, is_active, is_premium, sign_id, video_asset_id,
--     image_asset_id, explanation,
--     options: [{label, image_asset_id, side}],
--     correct_index (0-based, jenis pilihan tunggal) |
--     correct_sequence (array indeks opsi, arrange_word) |
--     pairs ([{left: idx, right: idx}], match_image)}
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
