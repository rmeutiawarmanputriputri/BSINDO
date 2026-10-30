-- Uji migrasi 0121 (penyesuaian daftar fitur A–L) + seed struktur 20_v110_struktur.sql.
-- Jalankan pada DB baru: stub + migrasi 0001–0121 + seed/00_categories.sql + seed/20_v110_struktur.sql.
-- Data uji berawalan TEST_ dan TIDAK berisi materi BISINDO.
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

insert into auth.users (id, email, raw_user_meta_data) values
  ('aaaaaaaa-0000-0000-0000-00000000000a', 'test.a@test.local', '{"full_name":"TEST A"}'),
  ('cccccccc-0000-0000-0000-00000000000c', 'test.admin@test.local', '{"full_name":"TEST Admin"}');
update public.profiles set role = 'admin' where id = 'cccccccc-0000-0000-0000-00000000000c';
insert into storage.buckets (id, name) values ('bisindo-media', 'bisindo-media') on conflict do nothing;

-- ================================================================ F-01..F-06 seed & media (postgres)
do $$
declare v uuid;
begin
  perform t.check('F-01', (select count(*) from public.categories where kind = 'sign' and name in
      ('Keluarga', 'Sapaan', 'Aktivitas', 'Anggota Tubuh', 'Makanan dan Minuman', 'Hewan', 'Warna', 'Sekolah',
       'Profesi', 'Tempat', 'Perasaan dan Emosi', 'Kata Kerja dan Kata Sifat')) = 12,
    '12 kategori sesuai daftar pemilik');
  perform t.check('F-02', (select count(*) from public.signs where content_module = 'vocabulary' and status = 'draft'
                             and term in ('Ayah','Ibu','Kakak','Adik','Saudara','Halo','Selamat pagi','Selamat malam',
                                          'Makan','Minum','Tidur','Mandi','Belajar','Kepala','Mata','Hidung','Tangan','Kaki')
                             and meaning is null and movement_description is null and video_asset_id is null) = 18
                     and not exists (select 1 from public.signs s join public.categories c on c.id = s.category_id
                                     where s.term = 'Ayah' and c.name <> 'Keluarga'),
    '18 kosakata Draft, nama saja (tanpa arti/penjelasan/video), kategori benar');
  perform t.check('F-03', (select count(*) from public.conversation_modules where status = 'draft' and title in
      ('Perkenalan diri', 'Menanyakan nama', 'Menanyakan kabar', 'Percakapan sehari-hari', 'Percakapan di sekolah',
       'Percakapan di rumah', 'Ungkapan terima kasih dan permintaan maaf', 'Kalimat sederhana lainnya')) = 8,
    '8 topik percakapan Draft sesuai daftar');

  -- GIF diterima untuk animasi (video) & gambar; bucket mengizinkan image/gif
  insert into public.media_assets (id, kind, path, mime_type, size_bytes, original_filename) values
    ('f0000000-0000-0000-0000-0000000000a1', 'video', 'test/TEST_anim.gif', 'image/gif', 1000, 'TEST_anim.gif'),
    ('f0000000-0000-0000-0000-0000000000a2', 'image', 'test/TEST_pic.gif', 'image/gif', 1000, null),
    ('f0000000-0000-0000-0000-0000000000a3', 'video', 'test/TEST_v.mp4', 'video/mp4', 1000, 'TEST_v.mp4');
  perform t.check('F-04', 'image/gif' = any ((select allowed_mime_types from storage.buckets where id = 'bisindo-media')::text[]),
                  'GIF diterima (video & gambar); bucket mengizinkan image/gif');
  begin
    insert into public.media_assets (kind, path, mime_type, size_bytes) values ('audio', 'test/x.gif', 'image/gif', 10);
    perform t.fail('F-05', 'GIF sebagai audio diterima');
  exception when check_violation then perform t.pass('F-05', 'GIF sebagai audio ditolak');
  end;
  perform t.check('F-06', (select title from public.media_assets where id = 'f0000000-0000-0000-0000-0000000000a1') = 'TEST_anim.gif'
                     and (select title from public.media_assets where id = 'f0000000-0000-0000-0000-0000000000a2') = 'TEST_pic.gif',
                  'media tanpa judul diberi identitas dari nama berkas');
  update public.media_assets set title = 'TEST Judul manual' where id = 'f0000000-0000-0000-0000-0000000000a1';
  perform t.check('F-06b', (select title from public.media_assets where id = 'f0000000-0000-0000-0000-0000000000a1') = 'TEST Judul manual',
                  'judul manual tidak ditimpa');
end $$;
insert into storage.objects (bucket_id, name) select 'bisindo-media', path from public.media_assets where path like 'test/%';

-- ================================================================ admin
begin;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"cccccccc-0000-0000-0000-00000000000c","role":"authenticated"}', true);
do $$
declare v uuid; v_w uuid; v_m uuid; v_i1 uuid; r jsonb; v_cat uuid;
begin
  select id into v_cat from public.categories where slug = 'sapaan';
  -- F-10 alfabet dengan animasi GIF: tanpa penjelasan gerakan ditolak, lengkap diterima
  insert into public.signs (content_module, term, symbol, status, video_asset_id, validated_by, source_note, verified_at)
  values ('alphabet', 'TEST_HURUF_GIF', 'Q', 'draft', 'f0000000-0000-0000-0000-0000000000a1', 'TEST', 'TEST', now())
  returning id into v;
  r := public.publish_issues('sign', v);
  perform t.check('F-10a', r = '["Penjelasan gerakan wajib diisi"]'::jsonb, r::text);
  begin
    update public.signs set status = 'published' where id = v;
    perform t.fail('F-10b', 'alfabet tanpa penjelasan dipublikasikan');
  exception when check_violation then perform t.pass('F-10b', 'ditolak: ' || sqlerrm);
  end;
  update public.signs set movement_description = 'TEST penjelasan', status = 'published' where id = v;
  perform t.check('F-10c', (select status from public.signs where id = v) = 'published', 'GIF + penjelasan → published');
  perform t.put('gif_sign', v);

  -- kosakata uji published (untuk bagian kalimat)
  insert into public.signs (content_module, category_id, term, meaning, status, video_asset_id, validated_by, source_note, verified_at)
  values ('vocabulary', v_cat, 'TEST_KATA', 'TEST arti', 'published', 'f0000000-0000-0000-0000-0000000000a3', 'TEST', 'TEST', now())
  returning id into v_w;
  perform t.put('word', v_w);

  -- F-11 topik + kalimat + bagian kalimat
  insert into public.conversation_modules (slug, title, status) values ('test-topik', 'TEST Topik', 'draft') returning id into v_m;
  perform t.put('mod', v_m);
  perform public.admin_save_conversation_items(v_m, jsonb_build_array(
    jsonb_build_object('text_id', 'TEST kalimat 1', 'video_asset_id', 'f0000000-0000-0000-0000-0000000000a3',
      'parts', jsonb_build_array(
        jsonb_build_object('sign_id', v_w),
        jsonb_build_object('part_text', 'TEST bagian', 'meaning', 'TEST arti bagian'),
        jsonb_build_object('part_text', '  ', 'sign_id', ''))),
    jsonb_build_object('text_id', 'TEST kalimat 2', 'video_asset_id', 'f0000000-0000-0000-0000-0000000000a3')));
  select id into v_i1 from public.conversation_items where module_id = v_m and position = 0;
  perform t.put('item1', v_i1);
  perform t.check('F-11a', (select count(*) from public.conversation_item_parts where item_id = v_i1) = 2
                      and (select sign_id from public.conversation_item_parts where item_id = v_i1 and position = 0) = v_w
                      and (select meaning from public.conversation_item_parts where item_id = v_i1 and position = 1) = 'TEST arti bagian',
                  'bagian kalimat tersimpan berurutan; baris kosong diabaikan');
  -- simpan ulang tanpa "parts" → bagian tetap; dengan id → kalimat sama
  perform public.admin_save_conversation_items(v_m, jsonb_build_array(
    jsonb_build_object('id', v_i1, 'text_id', 'TEST kalimat 1 (edit)', 'video_asset_id', 'f0000000-0000-0000-0000-0000000000a3'),
    jsonb_build_object('text_id', 'TEST kalimat 2', 'video_asset_id', 'f0000000-0000-0000-0000-0000000000a3')));
  perform t.check('F-11b', (select count(*) from public.conversation_item_parts where item_id = v_i1) = 2
                      and (select text_id from public.conversation_items where id = v_i1) = 'TEST kalimat 1 (edit)',
                  'tanpa "parts" bagian tidak berubah');
  -- urutan bagian dibalik
  perform public.admin_save_conversation_items(v_m, jsonb_build_array(
    jsonb_build_object('id', v_i1, 'text_id', 'TEST kalimat 1 (edit)', 'video_asset_id', 'f0000000-0000-0000-0000-0000000000a3',
      'parts', jsonb_build_array(jsonb_build_object('part_text', 'TEST bagian', 'meaning', 'TEST arti bagian'),
                                 jsonb_build_object('sign_id', v_w)))));
  perform t.check('F-11c', (select sign_id from public.conversation_item_parts where item_id = v_i1 and position = 1) = v_w
                      and (select count(*) from public.conversation_items where module_id = v_m) = 1,
                  'urutan bagian diperbarui; kalimat yang tidak dikirim terhapus');
  update public.conversation_modules set validated_by = 'TEST', source_note = 'TEST', verified_at = now(), status = 'published'
   where id = v_m;

  -- F-12 soal per topik percakapan
  begin
    perform public.admin_save_question(jsonb_build_object('module', 'vocabulary', 'conversation_module_id', v_m,
      'question_type', 'multiple_choice', 'prompt', 'TEST salah modul', 'options', jsonb_build_array(
        jsonb_build_object('label', 'TEST a'), jsonb_build_object('label', 'TEST b')), 'correct_index', 0));
    perform t.fail('F-12a', 'soal kosakata dengan topik percakapan diterima');
  exception when check_violation then perform t.pass('F-12a', 'topik percakapan hanya untuk modul percakapan');
  end;
  v := public.admin_save_question(jsonb_build_object('module', 'conversation', 'conversation_module_id', v_m,
      'question_type', 'multiple_choice', 'prompt', 'TEST soal topik', 'status', 'published',
      'options', jsonb_build_array(jsonb_build_object('label', 'TEST a'), jsonb_build_object('label', 'TEST b')),
      'correct_index', 1, 'explanation', 'TEST pembahasan'));
  perform t.put('q_conv', v);
  perform public.admin_save_question(jsonb_build_object('module', 'conversation',
      'question_type', 'multiple_choice', 'prompt', 'TEST soal percakapan umum', 'status', 'published',
      'options', jsonb_build_array(jsonb_build_object('label', 'TEST a'), jsonb_build_object('label', 'TEST b')),
      'correct_index', 0));
  perform t.check('F-12b', (select conversation_module_id from public.questions where id = v) = v_m
                      and (select status from public.questions where id = v) = 'published', 'soal tersimpan + terkait topik');
end $$;
commit;

-- ================================================================ pengguna biasa
begin;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-00000000000a","role":"authenticated"}', true);
do $$
declare r jsonb; n int;
begin
  perform t.check('F-20', not exists (select 1 from public.signs where term in ('Ayah', 'Halo', 'Kaki'))
                     and not exists (select 1 from public.conversation_modules where title = 'Perkenalan diri'),
                  'Draft dari seed tidak terlihat pengguna');
  select count(*) into n from public.conversation_item_parts where item_id = t.get('item1');
  perform t.check('F-21', n = 2, 'bagian kalimat topik published terlihat: ' || n);
  begin
    insert into public.conversation_item_parts (item_id, position, part_text) values (t.get('item1'), 9, 'TEST hack');
    perform t.fail('F-22', 'pengguna bisa menambah bagian');
  exception when insufficient_privilege or check_violation then perform t.pass('F-22', 'pengguna tidak bisa menulis bagian');
  end;
  r := public.get_quiz_questions('category', 'conversation', null, null, 10, t.get('mod'));
  perform t.check('F-23', jsonb_array_length(r) = 1 and r -> 0 ->> 'id' = t.get('q_conv')::text
                     and not (r -> 0 ? 'correct_option_id'), 'filter soal per topik percakapan; tanpa kunci');
  r := public.get_quiz_questions('category', 'conversation', null, null, 10);
  perform t.check('F-24', jsonb_array_length(r) = 2, 'tanpa topik → semua soal percakapan: ' || jsonb_array_length(r));
  r := public.get_quiz_questions('category', 'alphabet');
  perform t.check('F-25', jsonb_array_length(r) = 0, 'kompatibel pemanggilan 2 argumen');
  perform t.check('F-26', (select value -> 'sections' ->> 'intro' from public.app_settings where key = 'home_layout') = 'true',
                  'home_layout terbaca aplikasi');
  perform t.check('F-27', public.can_read_media('test/TEST_anim.gif'), 'animasi GIF materi published bisa diputar');
  begin
    update public.app_settings set value = '{}' where key = 'home_layout';
    get diagnostics n = row_count;
    perform t.check('F-28', n = 0, 'pengguna tidak bisa mengubah home_layout');
  exception when insufficient_privilege then perform t.pass('F-28', 'pengguna tidak bisa mengubah home_layout');
  end;
end $$;
commit;

-- ================================================================ hapus kalimat → bagian ikut terhapus
do $$ begin
  delete from public.conversation_items where id = t.get('item1');
  perform t.check('F-30', not exists (select 1 from public.conversation_item_parts where item_id = t.get('item1')),
                  'bagian ikut terhapus bersama kalimat');
end $$;

-- ---------------------------------------------------------------- ringkasan
select id, case when ok then 'LULUS' else 'GAGAL' end as hasil, left(detail, 140) as detail from t.results order by id;
do $$ declare n int; m int; begin
  select count(*) filter (where not ok), count(*) into n, m from t.results;
  raise notice 'TOTAL % uji, % gagal', m, n;
  if n > 0 then raise exception '% uji GAGAL', n; end if;
end $$;
