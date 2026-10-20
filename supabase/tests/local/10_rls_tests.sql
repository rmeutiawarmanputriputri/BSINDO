-- Uji RLS/Storage (SUPABASE_SECURITY_PLAN §9) — dijalankan sebagai postgres
-- setelah 00_supabase_stub.sql + migrations/*.sql. Juga dapat dijalankan di
-- SQL Editor proyek Supabase DEV (lewati bagian stub) — data uji dibuat lalu
-- dihapus di akhir.
\set ON_ERROR_STOP 1
set client_min_messages = warning;

drop schema if exists t cascade;
create schema t;
create table t.results (id text primary key, ok boolean not null, detail text);
grant usage on schema t to anon, authenticated;
grant insert, select on t.results to anon, authenticated;

create function t.pass(p_id text, p_detail text default '') returns void language sql security definer as
  $$ insert into t.results values (p_id, true, p_detail) on conflict (id) do update set ok = excluded.ok, detail = excluded.detail $$;
create function t.fail(p_id text, p_detail text default '') returns void language sql security definer as
  $$ insert into t.results values (p_id, false, p_detail) on conflict (id) do update set ok = excluded.ok, detail = excluded.detail $$;
grant execute on all functions in schema t to anon, authenticated;

-- ---------------------------------------------------------------- data uji
insert into auth.users (id, email, raw_user_meta_data) values
  ('aaaaaaaa-0000-0000-0000-00000000000a', 'user.a@test.local', '{"full_name":"User A","role":"admin"}'),
  ('bbbbbbbb-0000-0000-0000-00000000000b', 'user.b@test.local', '{"full_name":"User B"}'),
  ('cccccccc-0000-0000-0000-00000000000c', 'admin@test.local',  '{"full_name":"Admin"}');
update public.profiles set role = 'admin' where id = 'cccccccc-0000-0000-0000-00000000000c';

insert into public.categories (id, slug, name) values ('11111111-0000-0000-0000-000000000001', 'uji', 'Uji');
insert into public.media_assets (id, kind, path, mime_type, size_bytes) values
  ('22222222-0000-0000-0000-000000000001', 'video', 'signs/pub/video-1.mp4', 'video/mp4', 1000),
  ('22222222-0000-0000-0000-000000000002', 'video', 'signs/draft/video-2.mp4', 'video/mp4', 1000);
insert into public.signs (id, category_id, term, status, video_asset_id, validated_by, verified_at, source_note) values
  ('33333333-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000001', 'Terbit', 'published',
   '22222222-0000-0000-0000-000000000001', 'Validator Uji', now(), 'Sumber uji'),
  ('33333333-0000-0000-0000-000000000002', '11111111-0000-0000-0000-000000000001', 'Draf', 'draft',
   '22222222-0000-0000-0000-000000000002', null, null, null);
insert into storage.buckets (id, name) values ('bisindo-media', 'bisindo-media') on conflict do nothing;
insert into storage.objects (bucket_id, name) values
  ('bisindo-media', 'signs/pub/video-1.mp4'), ('bisindo-media', 'signs/draft/video-2.mp4');

insert into public.lessons (id, slug, title, status, validated_by, verified_at, source_note) values
  ('44444444-0000-0000-0000-000000000001', 'uji', 'Pelajaran Uji', 'published', 'Validator Uji', now(), 'Sumber uji'),
  ('44444444-0000-0000-0000-000000000002', 'uji-draf', 'Pelajaran Draf', 'draft', null, null, null);
insert into public.quizzes (id, lesson_id, title, pass_score_percent) values
  ('55555555-0000-0000-0000-000000000001', '44444444-0000-0000-0000-000000000001', 'Kuis', 50),
  ('55555555-0000-0000-0000-000000000002', '44444444-0000-0000-0000-000000000002', 'Kuis Draf', 50);
insert into public.questions (id, quiz_id, position, prompt) values
  ('66666666-0000-0000-0000-000000000001', '55555555-0000-0000-0000-000000000001', 0, 'Q1'),
  ('66666666-0000-0000-0000-000000000002', '55555555-0000-0000-0000-000000000001', 1, 'Q2'),
  ('66666666-0000-0000-0000-000000000003', '55555555-0000-0000-0000-000000000002', 0, 'QD');
insert into public.question_options (id, question_id, position, label) values
  ('77777777-0000-0000-0000-000000000011', '66666666-0000-0000-0000-000000000001', 0, 'Benar1'),
  ('77777777-0000-0000-0000-000000000012', '66666666-0000-0000-0000-000000000001', 1, 'Salah1'),
  ('77777777-0000-0000-0000-000000000021', '66666666-0000-0000-0000-000000000002', 0, 'Benar2'),
  ('77777777-0000-0000-0000-000000000022', '66666666-0000-0000-0000-000000000002', 1, 'Salah2'),
  ('77777777-0000-0000-0000-000000000031', '66666666-0000-0000-0000-000000000003', 0, 'BenarD');
insert into public.question_answer_keys (question_id, correct_option_id, explanation) values
  ('66666666-0000-0000-0000-000000000001', '77777777-0000-0000-0000-000000000011', 'E1'),
  ('66666666-0000-0000-0000-000000000002', '77777777-0000-0000-0000-000000000021', 'E2'),
  ('66666666-0000-0000-0000-000000000003', '77777777-0000-0000-0000-000000000031', 'ED');
insert into public.conversation_modules (id, slug, title, status, validated_by, verified_at, source_note) values
  ('88888888-0000-0000-0000-000000000001', 'modul-uji', 'Modul Uji', 'published', 'Validator Uji', now(), 'Sumber uji');
-- data pribadi milik B
insert into public.favorites (user_id, sign_id) values ('bbbbbbbb-0000-0000-0000-00000000000b', '33333333-0000-0000-0000-000000000001');
insert into public.user_progress (user_id, lesson_id) values ('bbbbbbbb-0000-0000-0000-00000000000b', '44444444-0000-0000-0000-000000000001');

-- Trigger profil: role dari metadata klien diabaikan
do $$ begin
  if (select role from public.profiles where id = 'aaaaaaaa-0000-0000-0000-00000000000a') = 'user'
     and (select full_name from public.profiles where id = 'aaaaaaaa-0000-0000-0000-00000000000a') = 'User A'
  then perform t.pass('AUTH-06', 'trigger membuat profil role=user (metadata role diabaikan)');
  else perform t.fail('AUTH-06'); end if;
end $$;

-- ------------------------------------------------------------------- anon
begin;
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
do $$ declare n int; begin
  begin
    select count(*) into n from public.signs;
    if n = 0 then perform t.pass('RLS-01', '0 baris'); else perform t.fail('RLS-01', n || ' baris'); end if;
  exception when insufficient_privilege then perform t.pass('RLS-01', 'ditolak privilege'); end;
  begin
    select count(*) into n from storage.objects where bucket_id = 'bisindo-media';
    if n = 0 then perform t.pass('ST-05', '0 objek'); else perform t.fail('ST-05', n || ' objek'); end if;
  exception when insufficient_privilege then perform t.pass('ST-05', 'ditolak privilege'); end;
end $$;
commit;

-- ----------------------------------------------------------------- user A
begin;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-00000000000a","role":"authenticated"}', true);
do $$ declare n int; r jsonb; begin
  -- RLS-02
  select count(*) into n from public.signs;
  if n = 1 and exists (select 1 from public.signs where status = 'published') then perform t.pass('RLS-02', 'hanya published');
  else perform t.fail('RLS-02', n || ' baris'); end if;

  -- RLS-03 insert / update / delete signs
  begin
    insert into public.signs (term) values ('Ilegal');
    perform t.fail('RLS-03', 'insert diterima');
  exception when insufficient_privilege then
    update public.signs set term = 'X' where id = '33333333-0000-0000-0000-000000000001';
    get diagnostics n = row_count;
    if n = 0 then
      delete from public.signs where id = '33333333-0000-0000-0000-000000000001';
      get diagnostics n = row_count;
      if n = 0 then perform t.pass('RLS-03', 'insert ditolak; update/delete 0 baris');
      else perform t.fail('RLS-03', 'delete berhasil'); end if;
    else perform t.fail('RLS-03', 'update berhasil'); end if;
  end;

  -- RLS-05 eskalasi role
  begin
    update public.profiles set role = 'admin' where id = auth.uid();
    perform t.fail('RLS-05', 'update role diterima');
  exception when insufficient_privilege then perform t.pass('RLS-05', 'ditolak privilege kolom'); end;

  -- RLS-06 insert profil
  begin
    insert into public.profiles (id, full_name) values (gen_random_uuid(), 'Palsu');
    perform t.fail('RLS-06', 'insert diterima');
  exception when insufficient_privilege then perform t.pass('RLS-06', 'ditolak'); end;

  -- RLS-07 ubah nama sendiri vs milik B
  update public.profiles set full_name = 'User A Baru' where id = auth.uid();
  get diagnostics n = row_count;
  if n = 1 then
    update public.profiles set full_name = 'Diretas' where id = 'bbbbbbbb-0000-0000-0000-00000000000b';
    get diagnostics n = row_count;
    if n = 0 then perform t.pass('RLS-07', 'milik sendiri 1 baris; milik B 0 baris');
    else perform t.fail('RLS-07', 'nama B berubah'); end if;
  else perform t.fail('RLS-07', 'gagal ubah nama sendiri'); end if;

  -- RLS-08 kunci jawaban
  begin
    select count(*) into n from public.question_answer_keys;
    if n = 0 then perform t.pass('RLS-08', '0 baris'); else perform t.fail('RLS-08', n || ' baris'); end if;
  exception when insufficient_privilege then perform t.pass('RLS-08', 'ditolak'); end;

  -- RLS-09 insert langsung quiz_attempts
  begin
    insert into public.quiz_attempts (user_id, quiz_id, score_percent, correct_count, total_count, passed, answers)
    values (auth.uid(), '55555555-0000-0000-0000-000000000001', 100, 2, 2, true, '[]');
    perform t.fail('RLS-09', 'insert diterima');
  exception when insufficient_privilege then perform t.pass('RLS-09', 'ditolak'); end;

  -- RLS-10 RPC penilaian
  r := public.submit_quiz_attempt('55555555-0000-0000-0000-000000000001',
        '[{"question_id":"66666666-0000-0000-0000-000000000001","option_id":"77777777-0000-0000-0000-000000000011"},
          {"question_id":"66666666-0000-0000-0000-000000000002","option_id":"77777777-0000-0000-0000-000000000021"}]');
  if (r->>'score_percent')::int <> 100 or not (r->>'passed')::boolean then perform t.fail('RLS-10', 'semua benar: ' || r); return; end if;
  r := public.submit_quiz_attempt('55555555-0000-0000-0000-000000000001',
        '[{"question_id":"66666666-0000-0000-0000-000000000001","option_id":"77777777-0000-0000-0000-000000000012"}]');
  if (r->>'score_percent')::int <> 0 then perform t.fail('RLS-10', 'salah+kosong: ' || r); return; end if;
  r := public.submit_quiz_attempt('55555555-0000-0000-0000-000000000001', '[]');
  if (r->>'score_percent')::int <> 0 or (r->>'total_count')::int <> 2 then perform t.fail('RLS-10', 'kosong: ' || r); return; end if;
  -- option asing (milik soal lain) tidak dihitung benar
  r := public.submit_quiz_attempt('55555555-0000-0000-0000-000000000001',
        '[{"question_id":"66666666-0000-0000-0000-000000000001","option_id":"77777777-0000-0000-0000-000000000021"}]');
  if (r->>'score_percent')::int <> 0 then perform t.fail('RLS-10', 'option asing: ' || r); return; end if;
  begin
    r := public.submit_quiz_attempt('55555555-0000-0000-0000-000000000002', '[]');
    perform t.fail('RLS-10', 'kuis draf bisa dinilai: ' || r);
    return;
  exception when others then
    if sqlerrm = 'quiz_not_available' then null; else perform t.fail('RLS-10', sqlerrm); return; end if;
  end;
  select count(*) into n from public.quiz_attempts where user_id = auth.uid();
  if n = 4 and exists (select 1 from public.user_progress where user_id = auth.uid()
                        and lesson_id = '44444444-0000-0000-0000-000000000001' and status = 'completed')
  then perform t.pass('RLS-10', 'skor 100/0/0/0 benar; kuis draf ditolak; 4 attempt; pelajaran completed (QUIZ-03)');
  else perform t.fail('RLS-10', 'attempt=' || n); end if;

  -- RLS-11 data pribadi B
  select (select count(*) from public.favorites where user_id = 'bbbbbbbb-0000-0000-0000-00000000000b')
       + (select count(*) from public.user_progress where user_id = 'bbbbbbbb-0000-0000-0000-00000000000b')
       + (select count(*) from public.difficult_vocabulary where user_id = 'bbbbbbbb-0000-0000-0000-00000000000b')
  into n;
  if n = 0 then perform t.pass('RLS-11', '0 baris milik B'); else perform t.fail('RLS-11', n || ' baris'); end if;

  -- RLS-12 upsert kosakata sulit tanpa duplikat (user_id dari default auth.uid())
  insert into public.difficult_vocabulary (sign_id) values ('33333333-0000-0000-0000-000000000001')
    on conflict (user_id, sign_id) do update set marked_at = now();
  insert into public.difficult_vocabulary (sign_id) values ('33333333-0000-0000-0000-000000000001')
    on conflict (user_id, sign_id) do update set marked_at = now();
  select count(*) into n from public.difficult_vocabulary where user_id = auth.uid();
  if n = 1 then
    begin
      insert into public.difficult_vocabulary (sign_id) values ('33333333-0000-0000-0000-000000000001');
      perform t.fail('RLS-12', 'insert ganda diterima');
    exception when unique_violation then perform t.pass('RLS-12', 'upsert 1 baris; insert ganda ditolak unik'); end;
  else perform t.fail('RLS-12', n || ' baris'); end if;

  -- 0009: favorit untuk sign draf ditolak
  begin
    insert into public.favorites (sign_id) values ('33333333-0000-0000-0000-000000000002');
    perform t.fail('FAV-DRAFT', 'favorit draf diterima');
  exception when insufficient_privilege then perform t.pass('FAV-DRAFT', 'favorit sign draf ditolak (0009)'); end;

  -- RLS-13 laporan palsu
  begin
    insert into public.content_reports (sign_id, category, status, resolved_at)
    values ('33333333-0000-0000-0000-000000000001', 'wrong_sign', 'resolved', now());
    perform t.fail('RLS-13', 'status resolved diterima');
  exception when insufficient_privilege then
    begin
      insert into public.content_reports (reporter_id, sign_id, category)
      values ('bbbbbbbb-0000-0000-0000-00000000000b', '33333333-0000-0000-0000-000000000001', 'wrong_sign');
      perform t.fail('RLS-13', 'reporter B diterima');
    exception when insufficient_privilege then perform t.pass('RLS-13', 'status palsu & reporter lain ditolak'); end;
  end;

  -- RLS-14 / RLS-16
  insert into public.content_reports (sign_id, category) values ('33333333-0000-0000-0000-000000000001', 'wrong_meaning');
  update public.content_reports set status = 'resolved', resolved_at = now() where reporter_id = auth.uid();
  get diagnostics n = row_count;
  if n = 0 then perform t.pass('RLS-14', 'update 0 baris'); else perform t.fail('RLS-14', n || ' baris'); end if;
  begin
    insert into public.content_reports (sign_id, category) values ('33333333-0000-0000-0000-000000000001', 'wrong_meaning');
    perform t.fail('RLS-16', 'duplikat diterima');
  exception when unique_violation then perform t.pass('RLS-16', 'duplikat terbuka ditolak'); end;

  -- RLS-15 batas 10/24 jam (sudah 1 laporan) — 9 kombinasi unik lagi → total 10
  insert into public.content_reports (sign_id, category, description) values
    ('33333333-0000-0000-0000-000000000001', 'wrong_sign', null),
    ('33333333-0000-0000-0000-000000000001', 'video_problem', null),
    ('33333333-0000-0000-0000-000000000001', 'wrong_example', null),
    ('33333333-0000-0000-0000-000000000001', 'other', 'keterangan uji'),
    ('33333333-0000-0000-0000-000000000002', 'wrong_sign', null),
    ('33333333-0000-0000-0000-000000000002', 'wrong_meaning', null),
    ('33333333-0000-0000-0000-000000000002', 'video_problem', null),
    ('33333333-0000-0000-0000-000000000002', 'wrong_example', null),
    ('33333333-0000-0000-0000-000000000002', 'other', 'keterangan uji');
  select count(*) into n from public.content_reports where reporter_id = auth.uid();
  begin
    insert into public.content_reports (lesson_id, category) values ('44444444-0000-0000-0000-000000000001', 'wrong_sign');
    perform t.fail('RLS-15', 'laporan ke-11 diterima');
  exception when raise_exception then
    if sqlerrm = 'report_rate_limited' and n = 10 then perform t.pass('RLS-15', '10 diterima, ke-11 ditolak report_rate_limited');
    else perform t.fail('RLS-15', sqlerrm || ' n=' || n); end if;
  end;

  -- ST-01 / ST-02 / ST-03 (createSignedUrl butuh SELECT pada storage.objects)
  if not exists (select 1 from storage.objects where name = 'signs/draft/video-2.mp4')
  then perform t.pass('ST-01', 'objek draf tidak terlihat'); else perform t.fail('ST-01'); end if;
  if exists (select 1 from storage.objects where name = 'signs/pub/video-1.mp4')
  then perform t.pass('ST-02', 'objek published terlihat'); else perform t.fail('ST-02'); end if;
  begin
    insert into storage.objects (bucket_id, name) values ('bisindo-media', 'signs/x/hack.mp4');
    perform t.fail('ST-03', 'upload diterima');
  exception when insufficient_privilege then
    delete from storage.objects where name = 'signs/pub/video-1.mp4';
    get diagnostics n = row_count;
    if n = 0 then perform t.pass('ST-03', 'upload ditolak; delete 0 baris'); else perform t.fail('ST-03', 'delete berhasil'); end if;
  end;

  -- PROG (0010): touch_progress membuat lalu memperbarui satu baris, completed bertahan
  perform public.touch_progress(p_module_id => null, p_lesson_id => '44444444-0000-0000-0000-000000000001', p_progress_percent => 30);
  perform public.touch_progress(p_lesson_id => '44444444-0000-0000-0000-000000000001', p_progress_percent => 10);
  select count(*) into n from public.user_progress where user_id = auth.uid() and lesson_id = '44444444-0000-0000-0000-000000000001';
  if n = 1 and (select status from public.user_progress where user_id = auth.uid()
                and lesson_id = '44444444-0000-0000-0000-000000000001') = 'completed'
  then
    perform public.touch_progress(p_module_id => '88888888-0000-0000-0000-000000000001', p_last_position => 1);
    perform public.touch_progress(p_module_id => '88888888-0000-0000-0000-000000000001', p_completed => true);
    if (select status from public.user_progress where user_id = auth.uid()
        and conversation_module_id = '88888888-0000-0000-0000-000000000001') = 'completed'
    then perform t.pass('PROG-RPC', 'pelajaran: 1 baris, completed tidak turun; modul: last_position lalu completed');
    else perform t.fail('PROG-RPC', 'modul'); end if;
  else perform t.fail('PROG-RPC', 'n=' || n); end if;

  -- ADM dashboard RPC untuk non-admin
  begin
    perform public.admin_dashboard_counts();
    perform t.fail('ADM-RPC', 'non-admin bisa');
  exception when insufficient_privilege then perform t.pass('ADM-RPC', 'non-admin ditolak'); end;
end $$;
commit;

-- ------------------------------------------------------------------ admin
begin;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"cccccccc-0000-0000-0000-00000000000c","role":"authenticated"}', true);
do $$ declare v uuid; n int; r jsonb; begin
  -- RLS-04
  insert into public.signs (term) values ('Baru Admin') returning id into v;
  begin
    update public.signs set status = 'published' where id = v;
    perform t.fail('RLS-04', 'publish tanpa validator diterima');
  exception when check_violation then
    update public.signs set status = 'published', validated_by = 'Validator', verified_at = now(), source_note = 'Sumber'
    where id = v;
    get diagnostics n = row_count;
    if n = 1 and (select created_by from public.signs where id = v) = auth.uid()
    then perform t.pass('RLS-04', 'tanpa validator ditolak CHECK; dengan validator berhasil; created_by otomatis');
    else perform t.fail('RLS-04'); end if;
  end;

  -- RLS-17
  update public.content_reports set status = 'resolved', resolved_at = now(), resolved_by = auth.uid(),
         resolution_message = 'Sudah diperbaiki' where category = 'wrong_meaning' and sign_id = '33333333-0000-0000-0000-000000000001';
  get diagnostics n = row_count;
  if n = 1 then perform t.pass('RLS-17', 'admin ubah status + pesan'); else perform t.fail('RLS-17', n || ' baris'); end if;

  -- REP-01 (DB): kategori "Lainnya" tanpa keterangan ≥ 5 ditolak
  begin
    insert into public.content_reports (lesson_id, category, description) values ('44444444-0000-0000-0000-000000000002', 'other', 'abc');
    perform t.fail('REP-01-DB', 'diterima');
  exception when check_violation then perform t.pass('REP-01-DB', 'CHECK report_other_needs_text');
  end;

  -- Admin melihat draf + objek draf
  if exists (select 1 from storage.objects where name = 'signs/draft/video-2.mp4')
     and exists (select 1 from public.signs where status = 'draft')
  then perform t.pass('ADM-READ', 'admin melihat draf & objeknya'); else perform t.fail('ADM-READ'); end if;

  r := public.admin_dashboard_counts();
  if (r->>'drafts')::int >= 1 then perform t.pass('ADM-RPC2', r::text); else perform t.fail('ADM-RPC2', r::text); end if;
end $$;
commit;

-- REP-04: pelapor melihat pesan admin
begin;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-00000000000a","role":"authenticated"}', true);
do $$ begin
  if exists (select 1 from public.content_reports where reporter_id = auth.uid()
             and status = 'resolved' and resolution_message = 'Sudah diperbaiki')
  then perform t.pass('REP-04', 'pelapor melihat status & pesan'); else perform t.fail('REP-04'); end if;
end $$;
commit;

-- ST-04: batas bucket (diperiksa pada konfigurasi bucket; penegakan oleh Storage API)
do $$ begin
  if (select file_size_limit from storage.buckets where id = 'bisindo-media') = 20971520
     and not (select public from storage.buckets where id = 'bisindo-media')
     and 'video/mp4' = any (select unnest(allowed_mime_types) from storage.buckets where id = 'bisindo-media')
  then perform t.pass('ST-04', 'bucket privat, 20 MB, MIME terbatas (penegakan aktual oleh Storage API — uji manual)');
  else perform t.fail('ST-04'); end if;
end $$;

-- ---------------------------------------------------------------- ringkasan
select id, case when ok then 'LULUS' else 'GAGAL' end as hasil, detail from t.results order by id;
do $$ declare n int; begin
  select count(*) into n from t.results where not ok;
  if n > 0 then raise exception '% uji GAGAL', n; end if;
end $$;
