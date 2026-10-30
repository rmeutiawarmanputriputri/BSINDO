-- Uji v1.1.0 (migrasi 0110–0120). Jalankan sebagai postgres pada DB yang
-- sudah menerapkan stub + seluruh migrasi + seed/00_categories.sql:
--   DB=bisindo_v110 bash tests/local/apply.sh && psql -d bisindo_v110 -f tests/local/20_v110_tests.sql
-- Semua data uji berawalan TEST_ / UUID uji dan TIDAK berisi materi BISINDO.
\set ON_ERROR_STOP 1
set client_min_messages = warning;

drop schema if exists t cascade;
create schema t;
create table t.results (id text primary key, ok boolean not null, detail text);
grant usage on schema t to anon, authenticated;
grant insert, select on t.results to anon, authenticated;
create table t.ctx (k text primary key, v uuid);
grant select, insert, update on t.ctx to authenticated;
create function t.pass(p_id text, p_detail text default '') returns void language sql security definer as
  $$ insert into t.results values (p_id, true, p_detail) on conflict (id) do update set ok = excluded.ok, detail = excluded.detail $$;
create function t.fail(p_id text, p_detail text default '') returns void language sql security definer as
  $$ insert into t.results values (p_id, false, p_detail) on conflict (id) do update set ok = excluded.ok, detail = excluded.detail $$;
create function t.check(p_id text, p_cond boolean, p_detail text default '') returns void language plpgsql security definer as
  $$ begin if coalesce(p_cond, false) then perform t.pass(p_id, p_detail); else perform t.fail(p_id, p_detail); end if; end $$;
create function t.get(p_k text) returns uuid language sql security definer as $$ select v from t.ctx where k = p_k $$;
create function t.put(p_k text, p_v uuid) returns void language sql security definer as
  $$ insert into t.ctx values (p_k, p_v) on conflict (k) do update set v = excluded.v $$;
grant execute on all functions in schema t to anon, authenticated;

-- ================================================================ fixture
-- A = pengguna gratis, B = pengguna lain, P = pengguna Premium, C = admin, X = akan dinonaktifkan
insert into auth.users (id, email, raw_user_meta_data) values
  ('aaaaaaaa-0000-0000-0000-00000000000a', 'test.a@test.local', '{"full_name":"TEST A"}'),
  ('bbbbbbbb-0000-0000-0000-00000000000b', 'test.b@test.local', '{"full_name":"TEST B"}'),
  ('dddddddd-0000-0000-0000-00000000000d', 'test.p@test.local', '{"full_name":"TEST Premium"}'),
  ('cccccccc-0000-0000-0000-00000000000c', 'test.admin@test.local', '{"full_name":"TEST Admin"}'),
  ('eeeeeeee-0000-0000-0000-00000000000e', 'test.x@test.local', '{"full_name":"TEST X"}');
update public.profiles set role = 'admin' where id = 'cccccccc-0000-0000-0000-00000000000c';
insert into storage.buckets (id, name) values ('bisindo-media', 'bisindo-media') on conflict do nothing;

-- Media uji (berkas fiktif berlabel TEST_; bukan rekaman BISINDO)
insert into public.media_assets (id, kind, path, mime_type, size_bytes, original_filename) values
  ('f0000000-0000-0000-0000-000000000001', 'video', 'test/TEST_v1.mp4', 'video/mp4', 1000, 'TEST_v1.mp4'),
  ('f0000000-0000-0000-0000-000000000002', 'video', 'test/TEST_v2.mp4', 'video/mp4', 1000, 'TEST_v2.mp4'),
  ('f0000000-0000-0000-0000-000000000003', 'audio', 'test/TEST_a1.mp3', 'audio/mpeg', 1000, 'TEST_a1.mp3'),
  ('f0000000-0000-0000-0000-000000000004', 'image', 'test/TEST_i1.png', 'image/png', 1000, 'TEST_i1.png'),
  ('f0000000-0000-0000-0000-000000000005', 'image', 'test/TEST_i2.png', 'image/png', 1000, 'TEST_i2.png'),
  ('f0000000-0000-0000-0000-000000000006', 'video', 'test/TEST_unused.mp4', 'video/mp4', 1000, 'TEST_unused.mp4'),
  ('f0000000-0000-0000-0000-000000000007', 'video', 'test/TEST_premium.mp4', 'video/mp4', 1000, 'TEST_premium.mp4');
insert into storage.objects (bucket_id, name)
  select 'bisindo-media', path from public.media_assets where path like 'test/%';

-- ================================================================ V-01..V-05 skema & media (sebagai postgres)
do $$ begin
  perform t.check('V-01', exists (select 1 from pg_enum e join pg_type ty on ty.oid = e.enumtypid
                                  where ty.typname = 'content_status' and e.enumlabel = 'inactive')
                          and exists (select 1 from pg_enum e join pg_type ty on ty.oid = e.enumtypid
                                  where ty.typname = 'media_kind' and e.enumlabel = 'audio'),
                  'enum inactive & audio tersedia');
  -- MIME salah ditolak
  begin
    insert into public.media_assets (kind, path, mime_type, size_bytes) values ('audio', 'test/x.wav', 'audio/wav', 10);
    perform t.fail('V-02', 'audio/wav diterima');
  exception when check_violation then perform t.pass('V-02', 'MIME di luar daftar ditolak');
  end;
  -- Melebihi batas per jenis (audio 20 MB) ditolak; setelah batas diubah diterima
  begin
    insert into public.media_assets (kind, path, mime_type, size_bytes) values ('audio', 'test/big.mp3', 'audio/mpeg', 25 * 1048576);
    perform t.fail('V-03', 'audio 25 MB diterima');
  exception when invalid_parameter_value then
    update public.app_settings set value = jsonb_set(value, '{audio_max_mb}', '30') where key = 'media_limits';
    insert into public.media_assets (kind, path, mime_type, size_bytes) values ('audio', 'test/big.mp3', 'audio/mpeg', 25 * 1048576);
    delete from public.media_assets where path = 'test/big.mp3';
    update public.app_settings set value = jsonb_set(value, '{audio_max_mb}', '20') where key = 'media_limits';
    perform t.pass('V-03', 'batas audio 20 MB menolak 25 MB; batas 30 MB menerima');
  end;
  -- Batas keras 50 MB tetap berlaku meski app_settings diisi lebih besar
  update public.app_settings set value = jsonb_set(value, '{video_max_mb}', '500') where key = 'media_limits';
  begin
    insert into public.media_assets (kind, path, mime_type, size_bytes) values ('video', 'test/huge.mp4', 'video/mp4', 60 * 1048576);
    perform t.fail('V-04', '60 MB diterima');
  exception when invalid_parameter_value or check_violation then perform t.pass('V-04', 'batas keras 50 MB');
  end;
  update public.app_settings set value = jsonb_set(value, '{video_max_mb}', '50') where key = 'media_limits';
  perform t.check('V-05', (select file_size_limit from storage.buckets where id = 'bisindo-media') = 52428800
                     and 'audio/mpeg' = any (select unnest(allowed_mime_types) from storage.buckets where id = 'bisindo-media'),
                  'bucket 50 MB + MIME audio');
end $$;

-- ================================================================ admin membuat konten
begin;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"cccccccc-0000-0000-0000-00000000000c","role":"authenticated"}', true);
do $$
declare v uuid; r jsonb; v_cat uuid;
begin
  select id into v_cat from public.categories where slug = 'salam';
  perform t.put('cat', v_cat);

  -- V-10 publish alfabet tanpa huruf/video → ditolak dengan daftar kekurangan
  insert into public.signs (content_module, term, status) values ('alphabet', 'TEST_HURUF', 'draft') returning id into v;
  perform t.put('alpha', v);
  r := public.publish_issues('sign', v);
  perform t.check('V-10a', r ? 'Huruf wajib diisi' and r ? 'Video gerakan wajib diunggah', r::text);
  begin
    update public.signs set status = 'published' where id = v;
    perform t.fail('V-10b', 'publish tanpa video diterima');
  exception when check_violation then perform t.pass('V-10b', 'publish ditolak: ' || sqlerrm);
  end;
  update public.signs set symbol = 'Z', video_asset_id = 'f0000000-0000-0000-0000-000000000001',
         image_asset_id = 'f0000000-0000-0000-0000-000000000004', audio_asset_id = 'f0000000-0000-0000-0000-000000000003',
         validated_by = 'TEST validator', source_note = 'TEST sumber', verified_at = now(), status = 'published'
   where id = v;
  perform t.check('V-10c', (select status from public.signs where id = v) = 'published', 'lengkap → published');

  -- angka: number_group wajib
  insert into public.signs (content_module, term, symbol, status, video_asset_id, validated_by, source_note, verified_at)
  values ('number', 'TEST_ANGKA', '7', 'draft', 'f0000000-0000-0000-0000-000000000002', 'TEST', 'TEST', now()) returning id into v;
  perform t.put('num', v);
  begin
    update public.signs set status = 'published' where id = v;
    perform t.fail('V-11', 'angka tanpa kelompok diterima');
  exception when check_violation then
    update public.signs set number_group = '0-9', status = 'published' where id = v;
    perform t.pass('V-11', 'kelompok angka wajib, lalu publish berhasil');
  end;
  -- number_group hanya untuk modul number
  begin
    update public.signs set number_group = '0-9' where id = t.get('alpha');
    perform t.fail('V-11b', 'number_group di alfabet diterima');
  exception when check_violation then perform t.pass('V-11b', 'number_group hanya untuk angka');
  end;

  -- kosakata Premium + kosakata draft + kosakata inactive
  insert into public.signs (content_module, category_id, term, meaning, status, video_asset_id, validated_by, source_note, verified_at, is_premium)
  values ('vocabulary', v_cat, 'TEST_PREMIUM', 'TEST arti', 'published', 'f0000000-0000-0000-0000-000000000007', 'TEST', 'TEST', now(), true)
  returning id into v; perform t.put('prem', v);
  insert into public.signs (content_module, category_id, term, status) values ('vocabulary', v_cat, 'TEST_DRAFT', 'draft') returning id into v;
  perform t.put('draft', v);
  insert into public.signs (content_module, category_id, term, meaning, status, video_asset_id, validated_by, source_note, verified_at)
  values ('vocabulary', v_cat, 'TEST_INACTIVE', 'TEST arti', 'published', 'f0000000-0000-0000-0000-000000000002', 'TEST', 'TEST', now())
  returning id into v;
  update public.signs set status = 'inactive' where id = v;
  perform t.put('inactive', v);

  -- V-12 regresi: sign published tidak boleh kehilangan video
  begin
    update public.signs set video_asset_id = null where id = t.get('alpha');
    perform t.fail('V-12', 'video dilepas dari materi published');
  exception when check_violation then perform t.pass('V-12', 'melepas video dari materi published ditolak');
  end;

  -- V-13 soal bank pilihan ganda (published) + soal tebak gerakan + susun kata + cocokkan gambar
  v := public.admin_save_question(jsonb_build_object(
        'module', 'alphabet', 'question_type', 'guess_letter', 'prompt', 'TEST soal 1',
        'video_asset_id', 'f0000000-0000-0000-0000-000000000001', 'difficulty', 'easy', 'status', 'published',
        'options', jsonb_build_array(jsonb_build_object('label', 'TEST_X'), jsonb_build_object('label', 'TEST_Y')),
        'correct_index', 1, 'explanation', 'TEST pembahasan'));
  perform t.put('q_mc', v);
  perform t.check('V-13a', (select status from public.questions where id = v) = 'published'
                       and (select count(*) from public.question_options where question_id = v) = 2, 'MC tersimpan & published');
  -- simpan ulang (edit) tetap konsisten
  v := public.admin_save_question(jsonb_build_object('id', v,
        'module', 'alphabet', 'question_type', 'guess_letter', 'prompt', 'TEST soal 1 (edit)',
        'video_asset_id', 'f0000000-0000-0000-0000-000000000001', 'difficulty', 'easy', 'status', 'published',
        'options', jsonb_build_array(jsonb_build_object('label', 'TEST_X'), jsonb_build_object('label', 'TEST_Y'), jsonb_build_object('label', 'TEST_Z')),
        'correct_index', 1, 'explanation', 'TEST pembahasan'));
  perform t.check('V-13b', (select count(*) from public.question_options where question_id = v) = 3
                       and (select o.label from public.question_answer_keys k join public.question_options o on o.id = k.correct_option_id
                            where k.question_id = v) = 'TEST_Y', 'edit soal mengganti pilihan & kunci');
  -- tanpa video → publish ditolak
  begin
    perform public.admin_save_question(jsonb_build_object('module', 'vocabulary', 'question_type', 'guess_sign',
      'prompt', 'TEST tanpa video', 'status', 'published',
      'options', jsonb_build_array(jsonb_build_object('label', 'A'), jsonb_build_object('label', 'B')), 'correct_index', 0));
    perform t.fail('V-13c', 'guess_sign tanpa video diterima');
  exception when check_violation then perform t.pass('V-13c', 'guess_sign tanpa video ditolak');
  end;
  -- susun kata dengan huruf ganda
  v := public.admin_save_question(jsonb_build_object('module', 'vocabulary', 'question_type', 'arrange_word',
        'prompt', 'TEST susun', 'status', 'published',
        'options', jsonb_build_array(jsonb_build_object('label', 'M'), jsonb_build_object('label', 'A'),
                                     jsonb_build_object('label', 'M'), jsonb_build_object('label', 'A')),
        'correct_sequence', jsonb_build_array(0, 1, 2, 3)));
  perform t.put('q_arr', v);
  -- cocokkan gambar
  v := public.admin_save_question(jsonb_build_object('module', 'vocabulary', 'question_type', 'match_image',
        'prompt', 'TEST cocokkan', 'status', 'published',
        'options', jsonb_build_array(
            jsonb_build_object('label', 'Gambar 1', 'side', 'left', 'image_asset_id', 'f0000000-0000-0000-0000-000000000004'),
            jsonb_build_object('label', 'TEST arti 1', 'side', 'right'),
            jsonb_build_object('label', 'Gambar 2', 'side', 'left', 'image_asset_id', 'f0000000-0000-0000-0000-000000000005'),
            jsonb_build_object('label', 'TEST arti 2', 'side', 'right')),
        'pairs', jsonb_build_array(jsonb_build_object('left', 0, 'right', 1), jsonb_build_object('left', 2, 'right', 3))));
  perform t.put('q_match', v);
  -- soal draft (tidak boleh terlihat)
  v := public.admin_save_question(jsonb_build_object('module', 'alphabet', 'question_type', 'multiple_choice',
        'prompt', 'TEST draft', 'status', 'draft',
        'options', jsonb_build_array(jsonb_build_object('label', 'A'), jsonb_build_object('label', 'B')), 'correct_index', 0));
  perform t.put('q_draft', v);
  -- soal Premium
  v := public.admin_save_question(jsonb_build_object('module', 'alphabet', 'question_type', 'multiple_choice',
        'prompt', 'TEST premium', 'status', 'published', 'is_premium', true,
        'options', jsonb_build_array(jsonb_build_object('label', 'A'), jsonb_build_object('label', 'B')), 'correct_index', 0));
  perform t.put('q_prem', v);
  perform t.check('V-13d', (select count(*) from public.questions where quiz_id is null and prompt like 'TEST%') = 5, '5 soal bank tersimpan');

  -- V-14 soal pelajaran wajib pilihan ganda
  begin
    insert into public.lessons (slug, title) values ('test-lesson', 'TEST pelajaran') returning id into v;
    insert into public.quizzes (lesson_id, title) values (v, 'TEST kuis') returning id into v;
    insert into public.questions (quiz_id, position, prompt, question_type) values (v, 0, 'TEST', 'arrange_word');
    perform t.fail('V-14', 'soal pelajaran non-MC diterima');
  exception when check_violation then perform t.pass('V-14', 'soal pelajaran non-MC ditolak');
  end;

  -- V-15 percakapan: simpan kalimat, urutan, validasi publish
  insert into public.conversation_modules (slug, title, status) values ('test-topik', 'TEST Topik', 'draft') returning id into v;
  perform t.put('conv', v);
  perform public.admin_save_conversation_items(v, jsonb_build_array(
    jsonb_build_object('speaker_label', 'A', 'text_id', 'TEST kalimat 1', 'translation', 'TEST terjemahan',
                       'video_asset_id', 'f0000000-0000-0000-0000-000000000002', 'audio_asset_id', 'f0000000-0000-0000-0000-000000000003'),
    jsonb_build_object('speaker_label', 'B', 'text_id', 'TEST kalimat 2')));
  r := public.publish_issues('conversation', v);
  perform t.check('V-15a', r ? 'Kalimat ke-2 belum memiliki video' and r ? 'Nama validator wajib diisi', r::text);
  -- tukar urutan (kalimat 2 jadi pertama) + beri video
  perform public.admin_save_conversation_items(v, (
    select jsonb_agg(x order by ord desc) from (
      select jsonb_build_object('id', id, 'speaker_label', speaker_label, 'text_id', text_id,
                                'video_asset_id', 'f0000000-0000-0000-0000-000000000002',
                                'audio_asset_id', audio_asset_id) x, position ord
      from public.conversation_items where module_id = v) z));
  perform t.check('V-15b', (select text_id from public.conversation_items where module_id = v and position = 0) = 'TEST kalimat 2'
                       and (select count(*) from public.conversation_items where module_id = v) = 2, 'urutan kalimat ditukar');
  update public.conversation_modules set validated_by = 'TEST', source_note = 'TEST', verified_at = now(), status = 'published' where id = v;
  begin
    perform public.admin_save_conversation_items(v, jsonb_build_array(jsonb_build_object('text_id', 'TEST tanpa video')));
    perform t.fail('V-15c', 'topik published menjadi tanpa video');
  exception when check_violation then perform t.pass('V-15c', 'topik published tetap valid');
  end;

  -- V-16 banner: aktif wajib gambar, rute & URL tervalidasi
  begin
    insert into public.banners (title, is_active) values ('TEST banner', true);
    perform t.fail('V-16a', 'banner aktif tanpa gambar');
  exception when check_violation then perform t.pass('V-16a', 'banner aktif wajib gambar');
  end;
  begin
    insert into public.banners (title, target_type, target_value) values ('TEST', 'url', 'http://tidak-aman');
    perform t.fail('V-16b', 'URL http diterima');
  exception when check_violation then perform t.pass('V-16b', 'URL harus https');
  end;
  insert into public.banners (title, image_asset_id, is_active, target_type, target_value)
    values ('TEST aktif', 'f0000000-0000-0000-0000-000000000005', true, 'route', '/alphabet');
  insert into public.banners (title, is_active) values ('TEST nonaktif', false);
  insert into public.announcements (title, body, is_published, published_at) values ('TEST pengumuman', 'TEST isi', true, now());
  insert into public.announcements (title, body) values ('TEST draf', 'TEST isi');
  insert into public.faqs (question, answer, is_active) values ('TEST tanya?', 'TEST jawab', true);

  -- Premium manual untuk P
  r := public.admin_set_premium('dddddddd-0000-0000-0000-00000000000d', true, 'TEST plan', null, 'uji');
  perform t.check('V-17a', r ->> 'status' = 'active' and public.has_premium('dddddddd-0000-0000-0000-00000000000d'), r::text);
  begin
    perform public.admin_set_premium('aaaaaaaa-0000-0000-0000-00000000000a', true, null, now() - interval '1 day');
    perform t.fail('V-17b', 'kedaluwarsa masa lalu diterima');
  exception when invalid_parameter_value then perform t.pass('V-17b', 'tanggal kedaluwarsa masa lalu ditolak');
  end;

  -- V-18 admin tidak bisa menurunkan/menonaktifkan diri sendiri; admin terakhir tidak bisa hapus akun
  begin perform public.admin_set_user_role(auth.uid(), 'user'); perform t.fail('V-18a');
  exception when insufficient_privilege then perform t.pass('V-18a', 'tidak bisa menurunkan diri sendiri'); end;
  begin perform public.admin_set_user_active(auth.uid(), false); perform t.fail('V-18b');
  exception when insufficient_privilege then perform t.pass('V-18b', 'tidak bisa menonaktifkan diri sendiri'); end;
  begin perform public.delete_my_account(); perform t.fail('V-18c');
  exception when insufficient_privilege then perform t.pass('V-18c', 'admin terakhir tidak bisa hapus akun'); end;

  perform public.admin_set_user_active('eeeeeeee-0000-0000-0000-00000000000e', false);

  -- V-19 dashboard & daftar pengguna (angka nyata)
  r := public.admin_dashboard_stats();
  perform t.check('V-19a', (r ->> 'users_total')::int = 5 and (r ->> 'premium_users')::int = 1
                       and (r ->> 'audios')::int = 1 and (r -> 'signs_by_module' ->> 'alphabet')::int = 1, left(r::text, 300));
  r := public.admin_list_users('test.p', 10, 0);
  perform t.check('V-19b', (r ->> 'total')::int = 1 and (r -> 'rows' -> 0 ->> 'is_premium')::boolean, r::text);
  r := public.admin_user_detail('dddddddd-0000-0000-0000-00000000000d');
  perform t.check('V-19c', r ->> 'email' = 'test.p@test.local', left(r::text, 200));
end $$;
commit;

-- ================================================================ pengguna A (gratis)
begin;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-00000000000a","role":"authenticated"}', true);
do $$
declare r jsonb; n int; v uuid;
begin
  -- V-20 hanya published yang terlihat (draft & inactive tidak)
  perform t.check('V-20', exists (select 1 from public.signs where id = t.get('alpha'))
                     and not exists (select 1 from public.signs where id = t.get('draft'))
                     and not exists (select 1 from public.signs where id = t.get('inactive')),
                  'published terlihat; draft & inactive tidak');
  -- V-21 media: audio/gambar materi published terbaca; media Premium tidak
  perform t.check('V-21', public.can_read_media('test/TEST_a1.mp3') and public.can_read_media('test/TEST_i1.png')
                     and not public.can_read_media('test/TEST_premium.mp4')
                     and not public.can_read_media('test/TEST_unused.mp4'),
                  'audio/gambar published terbaca; Premium & tak terpakai tidak');
  perform t.check('V-21b', exists (select 1 from storage.objects where name = 'test/TEST_a1.mp3')
                      and not exists (select 1 from storage.objects where name = 'test/TEST_premium.mp4'),
                  'policy Storage mengikuti can_read_media');
  -- V-22 Premium tidak bisa ditulis klien
  begin
    insert into public.subscriptions (user_id, is_premium, status) values (auth.uid(), true, 'active');
    perform t.fail('V-22a', 'klien menulis subscriptions');
  exception when insufficient_privilege then perform t.pass('V-22a', 'insert subscriptions ditolak');
  end;
  begin
    perform public.admin_set_premium(auth.uid(), true);
    perform t.fail('V-22b', 'non-admin set premium');
  exception when insufficient_privilege then perform t.pass('V-22b', 'admin_set_premium ditolak untuk non-admin');
  end;
  perform t.check('V-22c', not (public.my_premium_status() ->> 'is_premium')::boolean, public.my_premium_status()::text);

  -- V-23 semua RPC admin ditolak untuk pengguna biasa
  n := 0;
  begin perform public.admin_dashboard_stats(); exception when insufficient_privilege then n := n + 1; end;
  begin perform public.admin_list_users(); exception when insufficient_privilege then n := n + 1; end;
  begin perform public.admin_set_user_role(auth.uid(), 'admin'); exception when insufficient_privilege then n := n + 1; end;
  begin perform public.admin_set_user_active('bbbbbbbb-0000-0000-0000-00000000000b', false); exception when insufficient_privilege then n := n + 1; end;
  begin perform public.admin_import('vocabulary', '[{"term":"x"}]', true); exception when insufficient_privilege then n := n + 1; end;
  begin perform public.admin_save_question('{"options":[]}'); exception when insufficient_privilege then n := n + 1; end;
  begin perform public.admin_delete_media('f0000000-0000-0000-0000-000000000006'); exception when insufficient_privilege then n := n + 1; end;
  begin perform public.admin_reorder('signs', array[t.get('alpha')]); exception when insufficient_privilege then n := n + 1; end;
  begin perform public.media_usage('f0000000-0000-0000-0000-000000000001'); exception when insufficient_privilege then n := n + 1; end;
  begin perform public.publish_issues('sign', t.get('alpha')); exception when insufficient_privilege then n := n + 1; end;
  begin perform public.admin_user_detail(auth.uid()); exception when insufficient_privilege then n := n + 1; end;
  begin perform public.admin_save_conversation_items(t.get('conv'), '[]'); exception when insufficient_privilege then n := n + 1; end;
  perform t.check('V-23', n = 12, n || '/12 RPC admin ditolak');
  -- tulis konten langsung ditolak RLS
  begin
    update public.signs set term = 'HACK' where id = t.get('alpha');
    get diagnostics n = row_count;
    perform t.check('V-23b', n = 0, 'update konten oleh user: ' || n || ' baris');
  end;
  -- role tidak bisa dinaikkan sendiri
  begin
    update public.profiles set role = 'admin' where id = auth.uid();
    perform t.fail('V-23c', 'role diubah');
  exception when insufficient_privilege then perform t.pass('V-23c', 'kolom role tidak bisa diubah klien');
  end;

  -- V-24 progres per materi
  r := public.record_sign_view(t.get('alpha'));
  r := public.record_sign_view(t.get('alpha'));
  r := public.record_sign_view(t.get('alpha'), true);
  perform t.check('V-24a', (r ->> 'view_count')::int = 2 and (r ->> 'learned')::boolean, r::text);
  begin
    perform public.record_sign_view(t.get('draft'));
    perform t.fail('V-24b', 'progres untuk draft diterima');
  exception when insufficient_privilege then perform t.pass('V-24b', 'progres materi draft ditolak RLS');
  end;
  r := public.my_progress_summary();
  perform t.check('V-24c', (r -> 'modules' -> 'alphabet' ->> 'learned')::int = 1
                       and (r -> 'modules' -> 'alphabet' ->> 'total')::int = 1 and (r ->> 'total_learned')::int = 1, r::text);
  perform t.check('V-24d', (select count(*) from public.my_learning_history) = 1, 'riwayat belajar milik sendiri');

  -- V-25 kuis bank
  r := public.get_quiz_questions('category', 'alphabet', null, null, 10);
  perform t.check('V-25a', jsonb_array_length(r) = 1 and r -> 0 ->> 'id' = t.get('q_mc')::text
                       and r -> 0 ->> 'video_path' = 'test/TEST_v1.mp4'
                       and not (r::text like '%correct%') and not (r::text like '%pembahasan%'),
                  'hanya soal published non-premium; tanpa kunci: ' || left(r::text, 200));
  perform t.check('V-25b', not exists (select 1 from public.question_answer_keys), 'kunci jawaban tertutup');
  select o.id into v from public.question_options o where o.question_id = t.get('q_mc') and o.label = 'TEST_Y';
  r := public.check_quiz_answer(t.get('q_mc'), jsonb_build_object('option_id', v));
  perform t.check('V-25c', (r ->> 'is_correct')::boolean and r ->> 'explanation' = 'TEST pembahasan', r::text);
  begin
    perform public.check_quiz_answer(t.get('q_draft'), '{}');
    perform t.fail('V-25d', 'cek soal draft');
  exception when no_data_found then perform t.pass('V-25d', 'soal draft tidak bisa dicek');
  end;
  begin
    perform public.check_quiz_answer(t.get('q_prem'), '{}');
    perform t.fail('V-25e', 'cek soal premium oleh gratis');
  exception when no_data_found then perform t.pass('V-25e', 'soal Premium tertutup untuk pengguna gratis');
  end;
  -- susun kata: ubin M kedua dipakai lebih dulu tetap benar (dibandingkan per label)
  r := public.submit_quiz_session('mixed', (
      select jsonb_build_array(
        jsonb_build_object('question_id', t.get('q_arr'), 'answer', jsonb_build_object('sequence',
          (select jsonb_agg(id order by case position when 2 then 0 when 1 then 1 when 0 then 2 else 3 end)
             from public.question_options where question_id = t.get('q_arr')))),
        jsonb_build_object('question_id', t.get('q_match'), 'answer', jsonb_build_object('pairs',
          (select jsonb_agg(jsonb_build_object('left', l.id, 'right', rr.id))
             from public.question_options l join public.question_options rr
               on rr.question_id = l.question_id and rr.position = l.position + 1
            where l.question_id = t.get('q_match') and l.side = 'left'))),
        jsonb_build_object('question_id', t.get('q_mc'), 'answer', jsonb_build_object('option_id', 'not-a-uuid'))
      )));
  perform t.check('V-25f', (r ->> 'correct_count')::int = 2 and (r ->> 'total_count')::int = 3
                       and (r ->> 'score_percent')::int = 67, left(r::text, 300));
  perform t.check('V-25g', (select count(*) from public.quiz_sessions where user_id = auth.uid()) = 1, 'riwayat sesi tercatat');
  r := public.get_quiz_questions('weak');
  perform t.check('V-25h', jsonb_array_length(r) = 1 and r -> 0 ->> 'id' = t.get('q_mc')::text, 'mode kelemahan: ' || left(r::text, 120));
  begin
    insert into public.quiz_sessions (mode, score_percent, correct_count, total_count, answers)
      values ('mixed', 100, 1, 1, '[]');
    perform t.fail('V-25i', 'klien menulis skor sendiri');
  exception when insufficient_privilege then perform t.pass('V-25i', 'skor hanya lewat RPC (dinilai server)');
  end;
  begin
    perform public.submit_quiz_session('mixed', jsonb_build_array(jsonb_build_object('question_id', t.get('q_draft'), 'answer', '{}'::jsonb)));
    perform t.fail('V-25j', 'submit soal draft');
  exception when no_data_found then perform t.pass('V-25j', 'submit soal draft ditolak');
  end;

  -- V-26 konten rumah
  perform t.check('V-26a', (select count(*) from public.banners) = 1 and public.can_read_media('test/TEST_i2.png'),
                  'banner aktif saja + gambarnya terbaca');
  perform t.check('V-26b', (select count(*) from public.announcements) = 1 and (select count(*) from public.faqs) = 1,
                  'pengumuman & FAQ published saja');
  perform t.check('V-26c', not exists (select 1 from public.app_settings where not is_public), 'setting non-publik tertutup');
  begin
    update public.app_settings set value = '{}' where key = 'media_limits';
    get diagnostics n = row_count;
    perform t.check('V-26d', n = 0, 'user mengubah setting: ' || n);
  end;
  insert into public.announcement_reads (announcement_id) select id from public.announcements;
  perform t.check('V-26e', (select count(*) from public.announcement_reads) = 1, 'tanda baca tersimpan');

  -- V-27 percakapan premium & gratis
  perform t.check('V-27', (select count(*) from public.conversation_items where module_id = t.get('conv')) = 2,
                  'kalimat topik published gratis terbaca');
end $$;
commit;

-- ================================================================ pengguna B: isolasi data
begin;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-00000000000b","role":"authenticated"}', true);
do $$ begin
  perform t.check('V-30', not exists (select 1 from public.sign_progress)
                     and not exists (select 1 from public.quiz_sessions)
                     and not exists (select 1 from public.my_learning_history)
                     and not exists (select 1 from public.subscriptions)
                     and not exists (select 1 from public.announcement_reads)
                     and (public.my_progress_summary() ->> 'total_learned')::int = 0,
                  'B tidak melihat progres/riwayat/kuis/langganan A');
  update public.sign_progress set learned_at = null where user_id = 'aaaaaaaa-0000-0000-0000-00000000000a';
  perform t.check('V-30b', (select learned_at is not null from public.sign_progress) is null, 'B tidak bisa mengubah progres A');
end $$;
commit;
do $$ begin
  perform t.check('V-30c', (select learned_at is not null from public.sign_progress
                            where user_id = 'aaaaaaaa-0000-0000-0000-00000000000a'), 'progres A tetap utuh');
end $$;

-- ================================================================ pengguna Premium
begin;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"dddddddd-0000-0000-0000-00000000000d","role":"authenticated"}', true);
do $$ declare r jsonb; begin
  perform t.check('V-31a', public.can_read_media('test/TEST_premium.mp4'), 'Premium membaca media Premium');
  r := public.get_quiz_questions('category', 'alphabet');
  perform t.check('V-31b', jsonb_array_length(r) = 2, 'Premium mendapat soal Premium: ' || jsonb_array_length(r));
  perform t.check('V-31c', (public.my_premium_status() ->> 'is_premium')::boolean, public.my_premium_status()::text);
end $$;
commit;
-- Premium kedaluwarsa → akses hilang
update public.subscriptions set expires_at = now() - interval '1 minute' where user_id = 'dddddddd-0000-0000-0000-00000000000d';
begin;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"dddddddd-0000-0000-0000-00000000000d","role":"authenticated"}', true);
do $$ begin
  perform t.check('V-31d', not public.can_read_media('test/TEST_premium.mp4'), 'Premium kedaluwarsa → media tertutup');
end $$;
commit;

-- ================================================================ akun nonaktif
begin;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"eeeeeeee-0000-0000-0000-00000000000e","role":"authenticated"}', true);
do $$ begin
  perform t.check('V-32', not exists (select 1 from public.signs) and not exists (select 1 from public.categories)
                     and not public.can_read_media('test/TEST_a1.mp3')
                     and exists (select 1 from public.profiles where id = auth.uid() and not is_active),
                  'akun nonaktif tidak membaca konten, tetapi melihat status profilnya');
end $$;
commit;

-- ================================================================ media: pemakaian & hapus aman (admin)
begin;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"cccccccc-0000-0000-0000-00000000000c","role":"authenticated"}', true);
do $$ declare r jsonb; begin
  r := public.media_usage('f0000000-0000-0000-0000-000000000002');
  perform t.check('V-40a', jsonb_array_length(r) >= 3, 'media dipakai: ' || left(r::text, 200));
  begin
    perform public.admin_delete_media('f0000000-0000-0000-0000-000000000002');
    perform t.fail('V-40b', 'media terpakai terhapus');
  exception when foreign_key_violation then perform t.pass('V-40b', 'hapus media terpakai ditolak');
  end;
  begin
    perform public.admin_delete_media('f0000000-0000-0000-0000-000000000002', true);
    perform t.fail('V-40c', 'paksa hapus video materi published');
  exception when check_violation then perform t.pass('V-40c', 'paksa hapus tetap ditolak bila merusak materi published');
  end;
  r := public.admin_delete_media('f0000000-0000-0000-0000-000000000006');
  perform t.check('V-40d', r ->> 'path' = 'test/TEST_unused.mp4'
                       and not exists (select 1 from public.media_assets where id = 'f0000000-0000-0000-0000-000000000006'), r::text);
  r := public.admin_replace_media_file('f0000000-0000-0000-0000-000000000001', 'test/TEST_v1_new.mp4', 'video/mp4', 2000, 'TEST_v1_new.mp4');
  perform t.check('V-40e', r ->> 'old_path' = 'test/TEST_v1.mp4'
                       and (select video_asset_id from public.signs where id = t.get('alpha')) = 'f0000000-0000-0000-0000-000000000001',
                  'ganti berkas: id tetap, path lama dikembalikan');

  -- V-41 impor: dry run tidak menyimpan; impor nyata → Draft; error per baris
  r := public.admin_import('vocabulary', jsonb_build_array(
        jsonb_build_object('term', 'TEST_IMPOR_1', 'category', 'salam', 'meaning', 'TEST', 'video_file', 'TEST_v2.mp4'),
        jsonb_build_object('term', 'TEST_IMPOR_2', 'category', 'tidak-ada'),
        jsonb_build_object('term', 'TEST_IMPOR_3', 'category', 'Salam', 'video_file', 'belum-diunggah.mp4')), true);
  perform t.check('V-41a', (r ->> 'ok')::int = 2 and (r ->> 'failed')::int = 1
                       and not exists (select 1 from public.signs where term like 'TEST_IMPOR%'), left(r::text, 400));
  r := public.admin_import('vocabulary', jsonb_build_array(
        jsonb_build_object('term', 'TEST_IMPOR_1', 'category', 'salam', 'meaning', 'TEST', 'video_file', 'TEST_v2.mp4')), false);
  perform t.check('V-41b', (select status from public.signs where term = 'TEST_IMPOR_1') = 'draft'
                       and (select video_asset_id from public.signs where term = 'TEST_IMPOR_1') = 'f0000000-0000-0000-0000-000000000002',
                  'impor → Draft, media terhubung');
  r := public.admin_import('number', jsonb_build_array(jsonb_build_object('symbol', '8', 'number_group', '0-9'),
                                                      jsonb_build_object('symbol', '9', 'number_group', 'salah')), false);
  perform t.check('V-41c', (r ->> 'ok')::int = 1 and (r ->> 'failed')::int = 1, left(r::text, 300));
  r := public.admin_import('conversation', jsonb_build_array(
        jsonb_build_object('topic', 'TEST Topik Impor', 'text', 'TEST k1', 'speaker', 'A'),
        jsonb_build_object('topic', 'TEST Topik Impor', 'text', 'TEST k2', 'speaker', 'B', 'audio_file', 'TEST_a1.mp3')), false);
  perform t.check('V-41d', (r ->> 'ok')::int = 2 and (select count(*) from public.conversation_items i
                       join public.conversation_modules m on m.id = i.module_id where m.title = 'TEST Topik Impor') = 2
                       and (select status from public.conversation_modules where title = 'TEST Topik Impor') = 'draft', left(r::text, 300));
  r := public.admin_import('quiz', jsonb_build_array(
        jsonb_build_object('module', 'vocabulary', 'question_type', 'multiple_choice', 'prompt', 'TEST impor soal',
                           'options', 'TEST a|TEST b|TEST c', 'correct', 'TEST b', 'explanation', 'TEST'),
        jsonb_build_object('module', 'vocabulary', 'question_type', 'arrange_word', 'prompt', 'TEST susun impor', 'correct', 'A|B|C'),
        jsonb_build_object('module', 'vocabulary', 'question_type', 'match_image', 'prompt', 'TEST cocok impor',
                           'pairs', 'TEST_i1.png=TEST satu|TEST_i2.png=TEST dua'),
        jsonb_build_object('module', 'vocabulary', 'question_type', 'multiple_choice', 'prompt', 'TEST salah',
                           'options', 'x|y', 'correct', 'z')), false);
  perform t.check('V-41e', (r ->> 'ok')::int = 3 and (r ->> 'failed')::int = 1
                       and (select count(*) from public.questions where prompt in ('TEST impor soal', 'TEST susun impor', 'TEST cocok impor') and status = 'draft') = 3,
                  left(r::text, 400));
  -- soal impor match_image bisa dipublikasikan (kunci & gambar lengkap)
  update public.questions set status = 'published' where prompt = 'TEST cocok impor';
  perform t.pass('V-41f', 'soal cocokkan hasil impor lolos validasi publikasi');

  -- V-42 urutan
  perform public.admin_reorder('signs', array[t.get('num'), t.get('alpha')]);
  perform t.check('V-42', (select sort_order from public.signs where id = t.get('alpha')) = 1
                     and (select sort_order from public.signs where id = t.get('num')) = 0, 'urutan diperbarui');
end $$;
commit;

-- ================================================================ hapus akun mandiri (B)
begin;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-00000000000b","role":"authenticated"}', true);
select public.record_sign_view((select id from public.signs where term = 'TEST_HURUF'));
select public.delete_my_account();
commit;
do $$ begin
  perform t.check('V-50', not exists (select 1 from public.profiles where id = 'bbbbbbbb-0000-0000-0000-00000000000b')
                     and not exists (select 1 from public.sign_progress where user_id = 'bbbbbbbb-0000-0000-0000-00000000000b')
                     and exists (select 1 from public.sign_progress where user_id = 'aaaaaaaa-0000-0000-0000-00000000000a'),
                  'akun B & datanya terhapus; data A utuh');
end $$;

-- ================================================================ anon
begin;
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
do $$ declare n int := 0; begin
  begin perform 1 from public.banners; exception when insufficient_privilege then n := n + 1; end;
  begin perform 1 from public.app_settings; exception when insufficient_privilege then n := n + 1; end;
  begin perform public.get_quiz_questions(); exception when insufficient_privilege then n := n + 1; end;
  begin perform public.admin_dashboard_stats(); exception when insufficient_privilege then n := n + 1; end;
  perform t.check('V-60', n = 4, 'anon ditolak: ' || n || '/4');
end $$;
commit;

-- ---------------------------------------------------------------- ringkasan
select id, case when ok then 'LULUS' else 'GAGAL' end as hasil, left(detail, 140) as detail from t.results order by id;
do $$ declare n int; m int; begin
  select count(*) filter (where not ok), count(*) into n, m from t.results;
  raise notice 'TOTAL % uji, % gagal', m, n;
  if n > 0 then raise exception '% uji GAGAL', n; end if;
end $$;
