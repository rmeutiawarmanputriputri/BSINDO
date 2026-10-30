-- 0118_v110_publish_validation.sql — BISINDO v1.1.0
-- Validasi publikasi DI SERVER. Materi tidak bisa berstatus `published` bila
-- field atau media wajib belum ada. CMS memanggil publish_issues() untuk
-- menampilkan apa yang kurang sebelum menekan "Publikasikan".
--
-- Kompatibilitas data lama: pada baris yang SUDAH published, perubahan hanya
-- ditolak bila menimbulkan kekurangan BARU (mis. video dilepas). Kekurangan
-- lama tidak memblokir penyuntingan.

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

create or replace function public.module_publish_issues(m public.conversation_modules)
returns text[] language plpgsql stable security definer set search_path = '' as $$
declare
  v text[] := '{}';
  r record;
begin
  if m.title is null or btrim(m.title) = '' then v := array_append(v, 'Judul topik wajib diisi'::text); end if;
  if coalesce(btrim(m.validated_by), '') = '' then v := array_append(v, 'Nama validator wajib diisi'::text); end if;
  if coalesce(btrim(m.source_note), '') = '' then v := array_append(v, 'Sumber materi wajib diisi'::text); end if;
  if m.verified_at is null then v := array_append(v, 'Tanggal verifikasi wajib diisi'::text); end if;
  if not exists (select 1 from public.conversation_items where module_id = m.id) then
    v := array_append(v, 'Topik belum memiliki kalimat'::text);
  end if;
  for r in
    select i.position, i.video_asset_id, s.video_asset_id as sign_video
    from public.conversation_items i
    left join public.signs s on s.id = i.sign_id
    where i.module_id = m.id order by i.position
  loop
    if r.video_asset_id is null and r.sign_video is null then
      v := v || format('Kalimat ke-%s belum memiliki video', r.position + 1);
    end if;
  end loop;
  return v;
end $$;

create or replace function public.lesson_publish_issues(l public.lessons)
returns text[] language plpgsql stable security definer set search_path = '' as $$
declare v text[] := '{}';
begin
  if l.title is null or btrim(l.title) = '' then v := array_append(v, 'Judul pelajaran wajib diisi'::text); end if;
  if coalesce(btrim(l.validated_by), '') = '' then v := array_append(v, 'Nama validator wajib diisi'::text); end if;
  if coalesce(btrim(l.source_note), '') = '' then v := array_append(v, 'Sumber materi wajib diisi'::text); end if;
  if l.verified_at is null then v := array_append(v, 'Tanggal verifikasi wajib diisi'::text); end if;
  if not exists (select 1 from public.lesson_items where lesson_id = l.id) then
    v := array_append(v, 'Pelajaran belum memiliki isi'::text);
  end if;
  return v;
end $$;

create or replace function public.question_publish_issues(q public.questions)
returns text[] language plpgsql stable security definer set search_path = '' as $$
declare
  v text[] := '{}';
  k public.question_answer_keys;
  n_opt int; n_left int; n_left_img int; n_right int;
  v_sign_video uuid;
begin
  if q.quiz_id is not null then
    return v;    -- soal pelajaran mengikuti status pelajaran
  end if;
  if q.prompt is null or btrim(q.prompt) = '' then v := array_append(v, 'Pertanyaan wajib diisi'::text); end if;
  select * into k from public.question_answer_keys where question_id = q.id;
  select count(*), count(*) filter (where side = 'left'),
         count(*) filter (where side = 'left' and image_asset_id is not null),
         count(*) filter (where side = 'right')
    into n_opt, n_left, n_left_img, n_right
    from public.question_options where question_id = q.id;
  select s.video_asset_id into v_sign_video from public.signs s where s.id = q.sign_id;

  if q.question_type in ('multiple_choice', 'guess_letter', 'guess_number', 'guess_sign') then
    if n_opt < 2 then v := array_append(v, 'Minimal 2 pilihan jawaban'::text); end if;
    if k.correct_option_id is null then v := array_append(v, 'Jawaban benar belum dipilih'::text); end if;
    if q.question_type = 'guess_sign' and q.video_asset_id is null and v_sign_video is null then
      v := array_append(v, 'Soal tebak gerakan wajib memiliki video'::text);
    end if;
    if q.question_type in ('guess_letter', 'guess_number')
       and q.video_asset_id is null and q.image_asset_id is null and v_sign_video is null then
      v := array_append(v, 'Soal tebak huruf/angka wajib memiliki video atau gambar'::text);
    end if;
  elsif q.question_type = 'arrange_word' then
    if n_opt < 2 then v := array_append(v, 'Minimal 2 ubin huruf/kata'::text); end if;
    if k.correct_sequence is null then v := array_append(v, 'Urutan benar belum diisi'::text); end if;
  elsif q.question_type = 'match_image' then
    if n_left < 2 or n_right < 2 then v := array_append(v, 'Minimal 2 pasangan gambar–arti'::text); end if;
    if n_left_img < n_left then v := array_append(v, 'Setiap pilihan sisi gambar wajib memiliki gambar'::text); end if;
    if k.pairs is null then v := array_append(v, 'Pasangan benar belum diisi'::text); end if;
  end if;
  return v;
end $$;

-- Untuk CMS: daftar kekurangan sebelum publish. p_type: sign|conversation|lesson|question
create or replace function public.publish_issues(p_type text, p_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v text[];
  s public.signs; m public.conversation_modules; l public.lessons; q public.questions;
begin
  if not public.is_admin() then
    raise exception 'not_admin' using errcode = '42501';
  end if;
  case p_type
    when 'sign' then select * into s from public.signs where id = p_id; v := public.sign_publish_issues(s);
    when 'conversation' then select * into m from public.conversation_modules where id = p_id; v := public.module_publish_issues(m);
    when 'lesson' then select * into l from public.lessons where id = p_id; v := public.lesson_publish_issues(l);
    when 'question' then select * into q from public.questions where id = p_id; v := public.question_publish_issues(q);
    else raise exception 'invalid_type' using errcode = '22023';
  end case;
  return to_jsonb(coalesce(v, '{}'));
end $$;
revoke all on function public.publish_issues(text, uuid) from public, anon;
grant execute on function public.publish_issues(text, uuid) to authenticated;

do $$
declare f text;
begin
  foreach f in array array['sign_publish_issues(public.signs)', 'module_publish_issues(public.conversation_modules)',
                           'lesson_publish_issues(public.lessons)', 'question_publish_issues(public.questions)'] loop
    execute 'revoke all on function public.' || f || ' from public, anon, authenticated';
  end loop;
end $$;

-- Trigger penjaga
-- SECURITY DEFINER: fungsi *_publish_issues tidak di-grant ke klien.
create or replace function public.guard_publish()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_new text[];
  v_old text[] := '{}';
  v_add text[];
begin
  if new.status <> 'published' then
    return new;
  end if;
  case tg_table_name
    when 'signs' then
      v_new := public.sign_publish_issues(new::public.signs);
      if tg_op = 'UPDATE' and old.status = 'published' then v_old := public.sign_publish_issues(old::public.signs); end if;
    when 'conversation_modules' then
      v_new := public.module_publish_issues(new::public.conversation_modules);
      if tg_op = 'UPDATE' and old.status = 'published' then v_old := public.module_publish_issues(old::public.conversation_modules); end if;
    when 'lessons' then
      v_new := public.lesson_publish_issues(new::public.lessons);
      if tg_op = 'UPDATE' and old.status = 'published' then v_old := public.lesson_publish_issues(old::public.lessons); end if;
    when 'questions' then
      v_new := public.question_publish_issues(new::public.questions);
      if tg_op = 'UPDATE' and old.status = 'published' then v_old := public.question_publish_issues(old::public.questions); end if;
  end case;
  select coalesce(array_agg(x), '{}') into v_add from unnest(v_new) x where not (x = any (v_old));
  if cardinality(v_add) > 0 then
    raise exception 'publish_blocked: %', array_to_string(v_add, '; ')
      using errcode = '23514', hint = 'Lengkapi data lalu publikasikan lagi.';
  end if;
  return new;
end $$;

create trigger guard_publish before insert or update on public.signs
  for each row execute function public.guard_publish();
create trigger guard_publish before insert or update on public.conversation_modules
  for each row execute function public.guard_publish();
create trigger guard_publish before insert or update on public.lessons
  for each row execute function public.guard_publish();
create trigger guard_publish before insert or update on public.questions
  for each row execute function public.guard_publish();
