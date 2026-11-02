-- ============================================================================
-- BISINDO v1.1.0 — PEMBARUAN DATABASE, LANGKAH 2 dari 2
-- Jalankan SETELAH Langkah 1 berhasil.
-- Cara pakai: Supabase → SQL Editor → New query → tempel SELURUH isi file ini → Run.
-- Hasil yang benar: tabel kecil "BISINDO v1.1.0 siap" di bagian bawah.
--
-- Isi: migrasi 0111–0121 (tabel/kolom/fungsi baru v1.1.0) + struktur kategori,
-- topik, dan kosakata contoh (status DRAFT, nama saja) dari daftar fitur pemilik.
-- * Semua dalam SATU transaksi: bila ada satu saja yang gagal, TIDAK ADA yang
--   berubah (database tetap seperti sebelumnya).
-- * Data lama (akun, progres, materi, favorit) TIDAK diubah atau dihapus.
-- * Bila sudah pernah dijalankan, file ini berhenti sendiri tanpa mengubah apa pun.
-- * Pembatalan (rollback) tersedia di supabase/rollback/.
-- ============================================================================
begin;

do $$
declare n int;
begin
  select count(*) into n from information_schema.tables where table_schema = 'public' and table_name in
    ('profiles','categories','media_assets','signs','conversation_modules','conversation_items','lessons','lesson_items',
     'quizzes','questions','question_options','question_answer_keys','quiz_attempts','user_progress','favorites',
     'difficult_vocabulary','content_reports');
  if n <> 17 then
    raise exception 'DIBATALKAN: tabel lama BISINDO tidak lengkap (% dari 17). Tidak ada yang diubah. Kirim pesan ini ke pengembang.', n;
  end if;
end $$;

do $$
begin
  if not exists (select 1 from pg_enum e join pg_type t on t.oid = e.enumtypid
                 where t.typname = 'content_status' and e.enumlabel = 'inactive') then
    raise exception 'DIBATALKAN: Langkah 1 belum dijalankan. Jalankan LANGKAH_1 dulu. Tidak ada yang diubah.';
  end if;
  if exists (select 1 from information_schema.tables where table_schema = 'public' and table_name = 'app_settings') then
    raise exception 'DIBATALKAN: database sudah versi 1.1.0 (tabel app_settings sudah ada). Tidak ada yang diubah.';
  end if;
end $$;


-- ############################################################ 0111_v110_settings_media.sql
-- 0111_v110_settings_media.sql — BISINDO v1.1.0
-- 1) app_settings: konfigurasi yang dapat diubah admin dari CMS (batas ukuran
--    media, info paket Premium). Tidak menyimpan rahasia.
-- 2) media_assets: dukung audio, metadata (judul, deskripsi, nama berkas
--    asli), status publikasi, batas ukuran dapat dikonfigurasi.
-- 3) Bucket bisindo-media: izinkan MIME audio, batas keras 50 MB.
-- Data lama: tidak diubah (kolom baru punya default).

-- ------------------------------------------------------------ app_settings
create table public.app_settings (
  key         text primary key check (key ~ '^[a-z0-9_]+$'),
  value       jsonb not null,
  is_public   boolean not null default false,   -- boleh dibaca aplikasi pengguna
  description text,
  updated_by  uuid references public.profiles (id) on delete set null default auth.uid(),
  updated_at  timestamptz not null default now()
);
create trigger set_updated_at before update on public.app_settings
  for each row execute function public.set_updated_at();

insert into public.app_settings (key, value, is_public, description) values
  ('media_limits', '{"video_max_mb": 50, "audio_max_mb": 20, "image_max_mb": 5}', true,
   'Batas ukuran unggah per jenis media (MB). Maksimum keras 50 MB (batas bucket).'),
  ('premium_info', '{"enabled": false, "title": null, "description": null, "plans": []}', true,
   'Informasi paket Premium yang ditampilkan di aplikasi. Diisi admin dari CMS.')
on conflict (key) do nothing;

alter table public.app_settings enable row level security;
grant select on public.app_settings to authenticated;
grant insert, update, delete on public.app_settings to authenticated;
create policy app_settings_read on public.app_settings for select to authenticated
  using (is_public or public.is_admin());
create policy app_settings_admin on public.app_settings for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- Pembaca batas media (dipakai trigger; security definer agar tidak bergantung RLS).
create or replace function public.media_limit_bytes(p_kind public.media_kind)
returns bigint language sql stable security definer set search_path = '' as $$
  select (least(50, greatest(1, coalesce(
            (select (s.value ->> (p_kind::text || '_max_mb'))::numeric
               from public.app_settings s where s.key = 'media_limits'),
            case p_kind::text when 'video' then 50 when 'audio' then 20 else 5 end)))
          * 1024 * 1024)::bigint;
$$;
revoke all on function public.media_limit_bytes(public.media_kind) from public, anon;
grant execute on function public.media_limit_bytes(public.media_kind) to authenticated;

-- ------------------------------------------------------------ media_assets
alter table public.media_assets
  add column title             text check (title is null or char_length(btrim(title)) between 1 and 160),
  add column description       text check (description is null or char_length(description) <= 1000),
  add column original_filename text check (original_filename is null or char_length(original_filename) <= 255),
  add column status            public.content_status not null default 'published',
  add column updated_at        timestamptz not null default now();

create trigger set_updated_at before update on public.media_assets
  for each row execute function public.set_updated_at();

create index media_assets_kind_created_idx on public.media_assets (kind, created_at desc);
create index media_assets_original_filename_idx on public.media_assets (lower(original_filename));

-- Batas lama 20 MB diganti batas keras 50 MB + batas per jenis dari app_settings.
alter table public.media_assets drop constraint if exists media_assets_size_bytes_check;
alter table public.media_assets add constraint media_size_hard_limit
  check (size_bytes > 0 and size_bytes <= 52428800);

alter table public.media_assets drop constraint if exists media_mime_matches_kind;
alter table public.media_assets add constraint media_mime_matches_kind check (
  (kind = 'video' and mime_type in ('video/mp4', 'video/webm')) or
  (kind = 'image' and mime_type in ('image/jpeg', 'image/png', 'image/webp')) or
  (kind = 'audio' and mime_type in ('audio/mpeg', 'audio/mp4', 'audio/aac', 'audio/x-m4a'))
);

create or replace function public.enforce_media_limit()
returns trigger language plpgsql set search_path = '' as $$
begin
  -- Hanya diperiksa saat ukuran/jenis berubah: data lama tidak ditolak.
  if tg_op = 'INSERT' or new.size_bytes is distinct from old.size_bytes or new.kind is distinct from old.kind then
    if new.size_bytes > public.media_limit_bytes(new.kind) then
      raise exception 'media_too_large: % MB melebihi batas % MB untuk %',
        round(new.size_bytes / 1048576.0, 1), public.media_limit_bytes(new.kind) / 1048576, new.kind
        using errcode = '22023';
    end if;
  end if;
  return new;
end $$;
create trigger media_assets_limit before insert or update on public.media_assets
  for each row execute function public.enforce_media_limit();

-- ------------------------------------------------------------ bucket
update storage.buckets
   set file_size_limit = 52428800,
       allowed_mime_types = array['video/mp4','video/webm','image/jpeg','image/png','image/webp',
                                  'audio/mpeg','audio/mp4','audio/aac','audio/x-m4a']
 where id = 'bisindo-media';


-- ############################################################ 0112_v110_content_extensions.sql
-- 0112_v110_content_extensions.sql — BISINDO v1.1.0
-- Alfabet & Angka memakai tabel `signs` yang sudah ada (bukan tabel baru),
-- sehingga favorit, kosakata sulit, laporan, pencarian, dan kebijakan media
-- langsung berlaku. Pembeda: kolom `content_module`.
--   vocabulary : kosakata (default, semua data lama)
--   alphabet   : huruf A–Z  (symbol = huruf)
--   number     : angka      (symbol = angka, number_group = kelompok)
-- `entry_type` lama (word/phrase) TIDAK diubah agar aplikasi 1.0.0 aman.

-- ------------------------------------------------------------ categories
alter table public.categories
  add column image_asset_id uuid references public.media_assets (id) on delete set null;

-- ------------------------------------------------------------ signs
alter table public.signs
  add column content_module text not null default 'vocabulary'
    check (content_module in ('vocabulary', 'alphabet', 'number')),
  add column symbol         text check (symbol is null or char_length(btrim(symbol)) between 1 and 16),
  add column number_group   text check (number_group is null or number_group in ('0-9', '10-20', 'tens', '100+')),
  add column sort_order     int not null default 0,
  add column image_asset_id uuid references public.media_assets (id) on delete set null,  -- panduan visual gerakan
  add column audio_asset_id uuid references public.media_assets (id) on delete set null,
  add column is_premium     boolean not null default false,
  add constraint signs_number_group_only_number check (number_group is null or content_module = 'number');

create index signs_module_status_order_idx on public.signs (content_module, status, sort_order, term_normalized);
create index signs_module_group_idx on public.signs (content_module, number_group, sort_order) where content_module = 'number';

-- ------------------------------------------------------------ percakapan
alter table public.conversation_modules
  add column is_premium boolean not null default false;

alter table public.conversation_items
  add column translation    text check (translation is null or char_length(translation) <= 500),
  add column explanation    text check (explanation is null or char_length(explanation) <= 2000),
  add column audio_asset_id uuid references public.media_assets (id) on delete set null;

-- ------------------------------------------------------------ pelajaran
alter table public.lessons
  add column is_premium boolean not null default false;


-- ############################################################ 0113_v110_accounts_premium.sql
-- 0113_v110_accounts_premium.sql — BISINDO v1.1.0
-- 1) Status akun (aktif/nonaktif) yang diatur admin.
-- 2) Langganan Premium. Status Premium TIDAK PERNAH ditulis klien:
--    hanya admin (RPC) atau webhook RevenueCat (service_role).
-- 3) Hapus akun mandiri (syarat Google Play).

-- ------------------------------------------------------------ profiles
alter table public.profiles
  add column is_active boolean not null default true;
-- Grant update tetap hanya (full_name) — is_active/role tidak bisa diubah klien.

create or replace function public.is_active_user()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.is_active
  );
$$;
revoke all on function public.is_active_user() from public, anon;
grant execute on function public.is_active_user() to authenticated;

-- ------------------------------------------------------------ subscriptions
create table public.subscriptions (
  user_id        uuid primary key references public.profiles (id) on delete cascade,
  is_premium     boolean not null default false,
  plan           text check (plan is null or char_length(plan) <= 80),
  source         text not null default 'manual' check (source in ('manual', 'revenuecat')),
  status         text not null default 'none' check (status in ('none', 'active', 'expired', 'cancelled', 'billing_issue')),
  started_at     timestamptz,
  expires_at     timestamptz,              -- null = tanpa batas waktu (manual)
  rc_app_user_id text,
  rc_product_id  text,
  rc_last_event  text,
  note           text check (note is null or char_length(note) <= 500),
  updated_by     uuid references public.profiles (id) on delete set null,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  constraint subscriptions_active_consistent check (not is_premium or status = 'active')
);
create trigger set_updated_at before update on public.subscriptions
  for each row execute function public.set_updated_at();
create index subscriptions_premium_idx on public.subscriptions (is_premium, expires_at);

alter table public.subscriptions enable row level security;
grant select on public.subscriptions to authenticated;          -- tulis hanya via RPC/service_role
create policy subscriptions_select on public.subscriptions for select to authenticated
  using (user_id = (select auth.uid()) or public.is_admin());

create or replace function public.has_premium(p_uid uuid default null)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.subscriptions s
    where s.user_id = coalesce(p_uid, (select auth.uid()))
      and s.is_premium and s.status = 'active'
      and (s.expires_at is null or s.expires_at > now())
  );
$$;
revoke all on function public.has_premium(uuid) from public, anon;
grant execute on function public.has_premium(uuid) to authenticated;

-- Status Premium milik sendiri (untuk aplikasi).
create or replace function public.my_premium_status()
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'is_premium', public.has_premium((select auth.uid())),
    'plan', s.plan, 'status', coalesce(s.status, 'none'), 'expires_at', s.expires_at, 'source', s.source)
  from (select 1) d
  left join public.subscriptions s on s.user_id = (select auth.uid());
$$;
revoke all on function public.my_premium_status() from public, anon;
grant execute on function public.my_premium_status() to authenticated;

-- ------------------------------------------------------------ hapus akun
-- Menghapus auth.users → cascade ke profiles & seluruh data pribadi.
-- Admin terakhir tidak bisa menghapus dirinya (CMS akan terkunci).
create or replace function public.delete_my_account()
returns void language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  if public.is_admin() and (select count(*) from public.profiles where role = 'admin' and is_active) <= 1 then
    raise exception 'last_admin_cannot_delete' using errcode = '42501';
  end if;
  delete from auth.users where id = v_uid;
end $$;
revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;


-- ############################################################ 0114_v110_quiz_bank.sql
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


-- ############################################################ 0115_v110_progress.sql
-- 0115_v110_progress.sql — BISINDO v1.1.0
-- Progres per materi (huruf, angka, kosakata) + riwayat belajar.
-- user_progress lama (pelajaran/modul percakapan) tidak diubah.

create table public.sign_progress (
  user_id         uuid not null references public.profiles (id) on delete cascade default auth.uid(),
  sign_id         uuid not null references public.signs (id) on delete cascade,
  view_count      int  not null default 1 check (view_count >= 0),
  first_viewed_at timestamptz not null default now(),
  last_viewed_at  timestamptz not null default now(),
  learned_at      timestamptz,           -- "sudah dipelajari" (ditandai pengguna / selesai mode belajar)
  primary key (user_id, sign_id)
);
create index sign_progress_recent_idx on public.sign_progress (user_id, last_viewed_at desc);

alter table public.sign_progress enable row level security;
grant select, insert, update, delete on public.sign_progress to authenticated;
create policy sign_progress_select_own on public.sign_progress for select to authenticated
  using (user_id = (select auth.uid()));
create policy sign_progress_insert_own on public.sign_progress for insert to authenticated
  with check (user_id = (select auth.uid())
              and exists (select 1 from public.signs s where s.id = sign_id and (s.status = 'published' or public.is_admin())));
create policy sign_progress_update_own on public.sign_progress for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy sign_progress_delete_own on public.sign_progress for delete to authenticated
  using (user_id = (select auth.uid()));

-- Catat materi dibuka; p_learned: true = tandai dipelajari, false = batalkan,
-- null = tidak mengubah status. SECURITY INVOKER → RLS tetap berlaku.
create or replace function public.record_sign_view(p_sign_id uuid, p_learned boolean default null)
returns jsonb language plpgsql security invoker set search_path = '' as $$
declare r public.sign_progress;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  insert into public.sign_progress as sp (user_id, sign_id, learned_at)
  values (auth.uid(), p_sign_id, case when p_learned then now() end)
  on conflict (user_id, sign_id) do update set
    view_count     = sp.view_count + case when p_learned is null then 1 else 0 end,
    last_viewed_at = now(),
    learned_at     = case when p_learned is null then sp.learned_at
                          when p_learned then coalesce(sp.learned_at, now())
                          else null end
  returning * into r;
  return jsonb_build_object('sign_id', r.sign_id, 'view_count', r.view_count,
                            'learned', r.learned_at is not null, 'learned_at', r.learned_at);
end $$;
revoke all on function public.record_sign_view(uuid, boolean) from public, anon;
grant execute on function public.record_sign_view(uuid, boolean) to authenticated;

-- Riwayat belajar milik pemanggil (RLS tabel dasar berlaku: security_invoker).
create view public.my_learning_history with (security_invoker = on) as
  select 'sign'::text as item_type, s.content_module as module, sp.sign_id as item_id,
         s.term as title, s.symbol, sp.last_viewed_at as last_accessed_at,
         (sp.learned_at is not null) as completed, sp.view_count
  from public.sign_progress sp
  join public.signs s on s.id = sp.sign_id
  where sp.user_id = (select auth.uid())
  union all
  select case when up.lesson_id is not null then 'lesson' else 'conversation' end,
         case when up.lesson_id is not null then 'lesson' else 'conversation' end,
         coalesce(up.lesson_id, up.conversation_module_id),
         coalesce(l.title, c.title), null, up.last_accessed_at,
         up.status = 'completed', null
  from public.user_progress up
  left join public.lessons l on l.id = up.lesson_id
  left join public.conversation_modules c on c.id = up.conversation_module_id
  where up.user_id = (select auth.uid());
grant select on public.my_learning_history to authenticated;

-- Ringkasan progres untuk Beranda/Profil. Hanya materi published yang dihitung.
create or replace function public.my_progress_summary()
returns jsonb language plpgsql stable security invoker set search_path = '' as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  return jsonb_build_object(
    'modules', (
      select coalesce(jsonb_object_agg(m.module, jsonb_build_object('total', m.total, 'learned', m.learned)), '{}'::jsonb)
      from (
        select s.content_module as module, count(*)::int as total,
               (count(*) filter (where sp.learned_at is not null))::int as learned
        from public.signs s
        left join public.sign_progress sp on sp.sign_id = s.id and sp.user_id = v_uid
        where s.status = 'published'
        group by s.content_module) m),
    'categories', (
      select coalesce(jsonb_agg(jsonb_build_object('category_id', c.id, 'name', c.name,
                                                   'total', c.total, 'learned', c.learned)
                                order by c.sort_order, c.name), '[]'::jsonb)
      from (
        select cat.id, cat.name, cat.sort_order, count(s.id)::int as total,
               (count(*) filter (where sp.learned_at is not null))::int as learned
        from public.categories cat
        join public.signs s on s.category_id = cat.id and s.status = 'published'
        left join public.sign_progress sp on sp.sign_id = s.id and sp.user_id = v_uid
        where cat.is_active
        group by cat.id) c),
    'conversations', (
      select jsonb_build_object(
        'total', (select count(*) from public.conversation_modules where status = 'published')::int,
        'completed', (select count(*) from public.user_progress up
                      join public.conversation_modules cm on cm.id = up.conversation_module_id
                      where up.user_id = v_uid and up.status = 'completed' and cm.status = 'published')::int)),
    'quizzes', (
      select jsonb_build_object(
        'sessions', count(*)::int,
        'average_score', coalesce(round(avg(score_percent))::int, 0),
        'best_score', coalesce(max(score_percent), 0),
        'last_at', max(submitted_at))
      from public.quiz_sessions where user_id = v_uid),
    'total_learned', (select count(*)::int from public.sign_progress sp
                      join public.signs s on s.id = sp.sign_id and s.status = 'published'
                      where sp.user_id = v_uid and sp.learned_at is not null)
  );
end $$;
revoke all on function public.my_progress_summary() from public, anon;
grant execute on function public.my_progress_summary() to authenticated;


-- ############################################################ 0116_v110_home_content.sql
-- 0116_v110_home_content.sql — BISINDO v1.1.0
-- Banner Beranda, pengumuman (notifikasi dalam aplikasi), FAQ.
-- Semua isi diketik admin di CMS; migrasi ini tidak mengisi data.

-- ------------------------------------------------------------ banners
create table public.banners (
  id             uuid primary key default gen_random_uuid(),
  title          text not null check (char_length(btrim(title)) between 1 and 120),
  description    text check (description is null or char_length(description) <= 300),
  image_asset_id uuid references public.media_assets (id) on delete set null,
  -- Tujuan saat diketuk. none | route (rute aplikasi, mis. /alphabet) | url (https) |
  -- sign | conversation | category (target_value = UUID)
  target_type    text not null default 'none'
    check (target_type in ('none', 'route', 'url', 'sign', 'conversation', 'category')),
  target_value   text check (target_value is null or char_length(target_value) <= 500),
  sort_order     int not null default 0,
  is_active      boolean not null default false,
  starts_at      timestamptz,
  ends_at        timestamptz,
  created_by     uuid references public.profiles (id) on delete set null default auth.uid(),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  constraint banners_target_value_needed check (target_type = 'none' or target_value is not null),
  constraint banners_url_https check (target_type <> 'url' or target_value ~ '^https://'),
  constraint banners_route_path check (target_type <> 'route' or target_value ~ '^/[a-z0-9/_-]*$'),
  constraint banners_period check (starts_at is null or ends_at is null or ends_at > starts_at),
  constraint banners_active_needs_image check (not is_active or image_asset_id is not null)
);
create trigger set_updated_at before update on public.banners
  for each row execute function public.set_updated_at();
create index banners_active_idx on public.banners (is_active, sort_order);

-- ------------------------------------------------------------ announcements
create table public.announcements (
  id           uuid primary key default gen_random_uuid(),
  title        text not null check (char_length(btrim(title)) between 1 and 120),
  body         text not null check (char_length(btrim(body)) between 1 and 2000),
  is_published boolean not null default false,
  published_at timestamptz,
  created_by   uuid references public.profiles (id) on delete set null default auth.uid(),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  constraint announcements_published_at check (not is_published or published_at is not null)
);
create trigger set_updated_at before update on public.announcements
  for each row execute function public.set_updated_at();
create index announcements_pub_idx on public.announcements (is_published, published_at desc);

create table public.announcement_reads (
  user_id         uuid not null references public.profiles (id) on delete cascade default auth.uid(),
  announcement_id uuid not null references public.announcements (id) on delete cascade,
  read_at         timestamptz not null default now(),
  primary key (user_id, announcement_id)
);

-- ------------------------------------------------------------ faqs
create table public.faqs (
  id         uuid primary key default gen_random_uuid(),
  question   text not null check (char_length(btrim(question)) between 1 and 300),
  answer     text not null check (char_length(btrim(answer)) between 1 and 3000),
  sort_order int not null default 0,
  is_active  boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger set_updated_at before update on public.faqs
  for each row execute function public.set_updated_at();

-- ------------------------------------------------------------ RLS
alter table public.banners            enable row level security;
alter table public.announcements      enable row level security;
alter table public.announcement_reads enable row level security;
alter table public.faqs               enable row level security;

grant select, insert, update, delete on public.banners, public.announcements, public.faqs to authenticated;
grant select, insert, delete on public.announcement_reads to authenticated;

create policy banners_read on public.banners for select to authenticated
  using (public.is_admin() or (is_active
         and (starts_at is null or starts_at <= now())
         and (ends_at is null or ends_at > now())));
create policy banners_admin on public.banners for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy announcements_read on public.announcements for select to authenticated
  using (public.is_admin() or (is_published and published_at <= now()));
create policy announcements_admin on public.announcements for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy announcement_reads_own_select on public.announcement_reads for select to authenticated
  using (user_id = (select auth.uid()));
create policy announcement_reads_own_insert on public.announcement_reads for insert to authenticated
  with check (user_id = (select auth.uid()));
create policy announcement_reads_own_delete on public.announcement_reads for delete to authenticated
  using (user_id = (select auth.uid()));

create policy faqs_read on public.faqs for select to authenticated
  using (is_active or public.is_admin());
create policy faqs_admin on public.faqs for all to authenticated
  using (public.is_admin()) with check (public.is_admin());


-- ############################################################ 0117_v110_access_rules.sql
-- 0117_v110_access_rules.sql — BISINDO v1.1.0
-- 1) can_read_media(): mencakup semua relasi media baru (gambar panduan,
--    audio, gambar kategori, banner, media soal & opsi), status media,
--    konten Premium (hanya pengguna Premium/admin), dan akun nonaktif.
--    Signature tetap → policy Storage 0008 otomatis memakai versi baru.
-- 2) Akun nonaktif tidak bisa membaca konten (policy RESTRICTIVE).
-- 3) Kalimat percakapan Premium hanya untuk pengguna Premium.

create or replace function public.can_read_media(p_path text)
returns boolean language sql stable security definer set search_path = '' as $$
  select public.is_admin() or (public.is_active_user() and exists (
    select 1 from public.media_assets m
    where m.path = p_path and m.status = 'published' and (
      exists (select 1 from public.signs s
              where s.status = 'published'
                and m.id in (s.video_asset_id, s.thumbnail_asset_id, s.image_asset_id, s.audio_asset_id)
                and (not s.is_premium or public.has_premium()))
      or exists (select 1 from public.conversation_modules c
                 where c.status = 'published' and c.thumbnail_asset_id = m.id
                   and (not c.is_premium or public.has_premium()))
      or exists (select 1 from public.conversation_items i
                 join public.conversation_modules c on c.id = i.module_id
                 where c.status = 'published' and m.id in (i.video_asset_id, i.audio_asset_id)
                   and (not c.is_premium or public.has_premium()))
      or exists (select 1 from public.lessons l
                 where l.status = 'published' and l.thumbnail_asset_id = m.id
                   and (not l.is_premium or public.has_premium()))
      or exists (select 1 from public.categories cat
                 where cat.is_active and cat.image_asset_id = m.id)
      or exists (select 1 from public.banners b
                 where b.is_active and b.image_asset_id = m.id
                   and (b.starts_at is null or b.starts_at <= now())
                   and (b.ends_at is null or b.ends_at > now()))
      or exists (select 1 from public.questions q
                 where m.id in (q.video_asset_id, q.image_asset_id)
                   and public.can_read_question(q.id))
      or exists (select 1 from public.question_options o
                 where o.image_asset_id = m.id and public.can_read_question(o.question_id))
    )
  ));
$$;

-- Kalimat percakapan: modul published + (gratis atau pengguna Premium).
drop policy conv_items_read on public.conversation_items;
create policy conv_items_read on public.conversation_items for select to authenticated
  using (public.is_admin() or exists (
    select 1 from public.conversation_modules m
    where m.id = module_id and m.status = 'published'
      and (not m.is_premium or public.has_premium())));

-- Akun nonaktif: semua bacaan konten ditolak (AND dengan policy lain).
do $$
declare t text;
begin
  foreach t in array array[
    'categories', 'media_assets', 'signs', 'conversation_modules', 'conversation_items',
    'lessons', 'lesson_items', 'quizzes', 'questions', 'question_options',
    'banners', 'announcements', 'faqs', 'app_settings'
  ] loop
    execute format(
      'create policy %I on public.%I as restrictive for select to authenticated
         using (public.is_active_user())', t || '_active_account_only', t);
  end loop;
end $$;


-- ############################################################ 0118_v110_publish_validation.sql
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


-- ############################################################ 0119_v110_admin_rpc.sql
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


-- ############################################################ 0120_v110_import.sql
-- 0120_v110_import.sql — BISINDO v1.1.0
-- Impor massal dari CMS (CSV/JSON yang sudah di-parse menjadi array objek).
-- SEMUA baris masuk sebagai DRAFT. Media dirujuk dengan nama berkas yang
-- SUDAH diunggah di menu Media (original_filename / judul / path).
-- p_dry_run = true → validasi saja, tidak ada yang disimpan (pratinjau).

create or replace function public.resolve_media(p_name text, p_kind public.media_kind)
returns uuid language sql stable security definer set search_path = '' as $$
  select m.id from public.media_assets m
  where nullif(btrim(p_name), '') is not null and m.kind = p_kind
    and (lower(m.original_filename) = lower(btrim(p_name)) or m.path = btrim(p_name)
         or lower(m.title) = lower(btrim(p_name)))
  order by m.created_at desc limit 1;
$$;
revoke all on function public.resolve_media(text, public.media_kind) from public, anon, authenticated;

create or replace function public.slugify(p text)
returns text language sql immutable set search_path = '' as $$
  select nullif(trim(both '-' from regexp_replace(lower(coalesce(p, '')), '[^a-z0-9]+', '-', 'g')), '');
$$;

create or replace function public.admin_import(p_kind text, p_rows jsonb, p_dry_run boolean default true)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  r        jsonb;
  n        int := 0;
  v_ok     int := 0;
  v_fail   int := 0;
  v_results jsonb := '[]'::jsonb;
  v_err    text[];
  v_warn   text[];
  v_id     uuid;
  v_cat    uuid;
  v_vid uuid; v_img uuid; v_aud uuid; v_thumb uuid;
  v_module uuid;
  v_slug   text;
  v_pos    int;
  v_opts   text[];
  v_correct text;
  v_cidx   int;
  v_q      jsonb;
  v_pairs  jsonb;
  v_left   text; v_right text;
  v_k      int;
  v_type   text;
  c_dry    constant text := 'BISINDO_DRY_RUN';
begin
  perform public.assert_admin();
  if p_kind not in ('vocabulary', 'alphabet', 'number', 'conversation', 'quiz') then
    raise exception 'invalid_kind' using errcode = '22023';
  end if;
  if jsonb_typeof(p_rows) <> 'array' or jsonb_array_length(p_rows) = 0 then
    raise exception 'invalid_rows' using errcode = '22023';
  end if;
  if jsonb_array_length(p_rows) > 2000 then
    raise exception 'too_many_rows: maksimum 2000 baris per impor' using errcode = '22023';
  end if;

  begin  -- blok luar: dibatalkan seluruhnya bila dry run
    for r in select * from jsonb_array_elements(p_rows) loop
      n := n + 1;
      v_err := '{}'; v_warn := '{}'; v_id := null;
      v_vid := null; v_img := null; v_aud := null; v_thumb := null; v_cat := null;

      begin  -- savepoint per baris
        if jsonb_typeof(r) <> 'object' then
          raise exception 'Baris bukan objek';
        end if;

        -- media (peringatan bila nama ada tetapi berkas belum diunggah)
        if nullif(btrim(r ->> 'video_file'), '') is not null then
          v_vid := public.resolve_media(r ->> 'video_file', 'video');
          if v_vid is null then v_warn := v_warn || format('Video "%s" belum ada di Media', r ->> 'video_file'); end if;
        end if;
        if nullif(btrim(r ->> 'image_file'), '') is not null then
          v_img := public.resolve_media(r ->> 'image_file', 'image');
          if v_img is null then v_warn := v_warn || format('Gambar "%s" belum ada di Media', r ->> 'image_file'); end if;
        end if;
        if nullif(btrim(r ->> 'audio_file'), '') is not null then
          v_aud := public.resolve_media(r ->> 'audio_file', 'audio');
          if v_aud is null then v_warn := v_warn || format('Audio "%s" belum ada di Media', r ->> 'audio_file'); end if;
        end if;
        if nullif(btrim(r ->> 'thumbnail_file'), '') is not null then
          v_thumb := public.resolve_media(r ->> 'thumbnail_file', 'image');
          if v_thumb is null then v_warn := v_warn || format('Thumbnail "%s" belum ada di Media', r ->> 'thumbnail_file'); end if;
        end if;

        if p_kind in ('vocabulary', 'alphabet', 'number') then
          if nullif(btrim(r ->> 'category'), '') is not null then
            select id into v_cat from public.categories
             where kind = 'sign' and (slug = lower(btrim(r ->> 'category')) or lower(name) = lower(btrim(r ->> 'category')))
             order by (slug = lower(btrim(r ->> 'category'))) desc limit 1;
            if v_cat is null then raise exception 'Kategori "%" tidak ditemukan', r ->> 'category'; end if;
          elsif p_kind = 'vocabulary' then
            raise exception 'Kolom category wajib diisi';
          end if;
          if p_kind = 'vocabulary' and nullif(btrim(r ->> 'term'), '') is null then
            raise exception 'Kolom term wajib diisi';
          end if;
          if p_kind in ('alphabet', 'number') and nullif(btrim(r ->> 'symbol'), '') is null then
            raise exception 'Kolom symbol wajib diisi';
          end if;
          if p_kind = 'number' and coalesce(r ->> 'number_group', '') not in ('0-9', '10-20', 'tens', '100+') then
            raise exception 'number_group harus salah satu: 0-9, 10-20, tens, 100+';
          end if;

          insert into public.signs (entry_type, content_module, category_id, term, symbol, number_group,
                                    meaning, movement_description, usage_example, video_asset_id,
                                    thumbnail_asset_id, image_asset_id, audio_asset_id, source_note,
                                    validated_by, verified_at, sort_order, is_premium, status)
          values (coalesce(nullif(r ->> 'entry_type', ''), 'word')::public.sign_entry_type, p_kind, v_cat,
                  btrim(coalesce(nullif(r ->> 'term', ''), r ->> 'symbol')),
                  case when p_kind <> 'vocabulary' then btrim(r ->> 'symbol') end,
                  case when p_kind = 'number' then r ->> 'number_group' end,
                  nullif(btrim(r ->> 'meaning'), ''), nullif(btrim(r ->> 'movement_description'), ''),
                  nullif(btrim(r ->> 'usage_example'), ''), v_vid, v_thumb, v_img, v_aud,
                  nullif(btrim(r ->> 'source_note'), ''), nullif(btrim(r ->> 'validated_by'), ''),
                  (nullif(btrim(r ->> 'verified_at'), ''))::date,
                  coalesce((nullif(r ->> 'sort_order', ''))::int, 0),
                  coalesce((nullif(lower(r ->> 'is_premium'), ''))::boolean, false), 'draft')
          returning id into v_id;

        elsif p_kind = 'conversation' then
          if nullif(btrim(r ->> 'topic'), '') is null then raise exception 'Kolom topic wajib diisi'; end if;
          if nullif(btrim(r ->> 'text'), '') is null then raise exception 'Kolom text wajib diisi'; end if;
          select id into v_module from public.conversation_modules
            where lower(title) = lower(btrim(r ->> 'topic')) order by created_at limit 1;
          if v_module is null then
            if nullif(btrim(r ->> 'category'), '') is not null then
              select id into v_cat from public.categories
               where kind = 'conversation' and (slug = lower(btrim(r ->> 'category')) or lower(name) = lower(btrim(r ->> 'category')))
               limit 1;
              if v_cat is null then raise exception 'Kategori percakapan "%" tidak ditemukan', r ->> 'category'; end if;
            end if;
            v_slug := coalesce(public.slugify(r ->> 'topic'), 'topik');
            if exists (select 1 from public.conversation_modules where slug = v_slug) then
              v_slug := v_slug || '-' || substr(md5(random()::text), 1, 6);
            end if;
            insert into public.conversation_modules (slug, category_id, title, description, status)
            values (v_slug, v_cat, btrim(r ->> 'topic'), nullif(btrim(r ->> 'topic_description'), ''), 'draft')
            returning id into v_module;
            v_warn := v_warn || format('Topik baru dibuat: %s', btrim(r ->> 'topic'));
          elsif (select status from public.conversation_modules where id = v_module) = 'published' then
            raise exception 'Topik "%" sudah Published; ubah ke Draft dulu sebelum menambah kalimat lewat impor', r ->> 'topic';
          end if;
          v_pos := coalesce((nullif(r ->> 'position', ''))::int - 1,
                            (select coalesce(max(position) + 1, 0) from public.conversation_items where module_id = v_module));
          if v_pos < 0 then raise exception 'position dimulai dari 1'; end if;
          if exists (select 1 from public.conversation_items where module_id = v_module and position = v_pos) then
            raise exception 'Posisi % sudah terisi di topik "%"', v_pos + 1, r ->> 'topic';
          end if;
          insert into public.conversation_items (module_id, position, speaker_label, text_id, translation,
                                                 explanation, video_asset_id, audio_asset_id)
          values (v_module, v_pos, coalesce(nullif(btrim(r ->> 'speaker'), ''), 'A'), btrim(r ->> 'text'),
                  nullif(btrim(r ->> 'translation'), ''), nullif(btrim(r ->> 'explanation'), ''), v_vid, v_aud)
          returning id into v_id;

        elsif p_kind = 'quiz' then
          v_type := coalesce(nullif(btrim(r ->> 'question_type'), ''), 'multiple_choice');
          if v_type not in ('multiple_choice', 'guess_letter', 'guess_number', 'guess_sign', 'match_image', 'arrange_word') then
            raise exception 'question_type tidak dikenal: %', v_type;
          end if;
          if coalesce(r ->> 'module', '') not in ('alphabet', 'number', 'vocabulary', 'conversation', 'general') then
            raise exception 'module harus salah satu: alphabet, number, vocabulary, conversation, general';
          end if;
          if nullif(btrim(r ->> 'prompt'), '') is null then raise exception 'Kolom prompt wajib diisi'; end if;
          if nullif(btrim(r ->> 'category'), '') is not null then
            select id into v_cat from public.categories
             where slug = lower(btrim(r ->> 'category')) or lower(name) = lower(btrim(r ->> 'category'))
             order by (slug = lower(btrim(r ->> 'category'))) desc limit 1;
            if v_cat is null then raise exception 'Kategori "%" tidak ditemukan', r ->> 'category'; end if;
          end if;

          v_q := jsonb_build_object('module', r ->> 'module', 'category_id', v_cat, 'question_type', v_type,
                   'prompt', btrim(r ->> 'prompt'), 'difficulty', coalesce(nullif(r ->> 'difficulty', ''), 'medium'),
                   'sort_order', coalesce((nullif(r ->> 'sort_order', ''))::int, 0),
                   'is_premium', coalesce((nullif(lower(r ->> 'is_premium'), ''))::boolean, false),
                   'video_asset_id', v_vid, 'image_asset_id', v_img,
                   'explanation', r ->> 'explanation', 'status', 'draft');

          if v_type = 'arrange_word' then
            -- correct: urutan benar dipisah "|" (mis. "M|A|K|A|N"). Ubin = isi urutan itu.
            v_opts := string_to_array(btrim(coalesce(r ->> 'correct', '')), '|');
            if cardinality(v_opts) < 2 then raise exception 'correct untuk arrange_word minimal 2 ubin dipisah "|"'; end if;
            v_q := v_q || jsonb_build_object(
              'options', (select jsonb_agg(jsonb_build_object('label', btrim(x)) order by o) from unnest(v_opts) with ordinality u(x, o)),
              'correct_sequence', (select jsonb_agg(o - 1 order by o) from unnest(v_opts) with ordinality u(x, o)));
          elsif v_type = 'match_image' then
            -- pairs: "gambar1.png=Arti 1|gambar2.png=Arti 2"
            v_opts := string_to_array(btrim(coalesce(r ->> 'pairs', '')), '|');
            if cardinality(v_opts) < 2 then raise exception 'pairs minimal 2 pasangan "berkas.png=Arti" dipisah "|"'; end if;
            v_pairs := '[]'::jsonb; v_q := v_q || jsonb_build_object('options', '[]'::jsonb);
            v_k := 0;
            foreach v_correct in array v_opts loop
              v_left := btrim(split_part(v_correct, '=', 1)); v_right := btrim(split_part(v_correct, '=', 2));
              if v_left = '' or v_right = '' then raise exception 'Format pasangan salah: "%"', v_correct; end if;
              v_img := public.resolve_media(v_left, 'image');
              if v_img is null then v_warn := v_warn || format('Gambar "%s" belum ada di Media', v_left); end if;
              v_q := jsonb_set(v_q, '{options}', (v_q -> 'options')
                       || jsonb_build_object('label', 'Gambar ' || (v_k + 1), 'side', 'left', 'image_asset_id', v_img)
                       || jsonb_build_object('label', v_right, 'side', 'right'));
              v_pairs := v_pairs || jsonb_build_object('left', v_k * 2, 'right', v_k * 2 + 1);
              v_k := v_k + 1;
            end loop;
            v_q := v_q || jsonb_build_object('pairs', v_pairs);
          else
            v_opts := string_to_array(btrim(coalesce(r ->> 'options', '')), '|');
            if cardinality(v_opts) < 2 then raise exception 'options minimal 2 pilihan dipisah "|"'; end if;
            v_correct := btrim(coalesce(r ->> 'correct', ''));
            v_cidx := null;
            if v_correct ~ '^[0-9]+$' and v_correct::int between 1 and cardinality(v_opts) then
              v_cidx := v_correct::int - 1;
            else
              select o - 1 into v_cidx from unnest(v_opts) with ordinality u(x, o) where lower(btrim(x)) = lower(v_correct) limit 1;
            end if;
            if v_cidx is null then raise exception 'correct "%" tidak cocok dengan pilihan mana pun', v_correct; end if;
            v_q := v_q || jsonb_build_object(
              'options', (select jsonb_agg(jsonb_build_object('label', btrim(x)) order by o) from unnest(v_opts) with ordinality u(x, o)),
              'correct_index', v_cidx);
          end if;
          v_id := public.admin_save_question(v_q);
        end if;

        v_ok := v_ok + 1;
        v_results := v_results || jsonb_build_object('row', n, 'ok', true, 'id', v_id, 'warnings', to_jsonb(v_warn));
      exception when others then
        v_fail := v_fail + 1;
        v_results := v_results || jsonb_build_object('row', n, 'ok', false,
                                                     'errors', to_jsonb(array[sqlerrm]), 'warnings', to_jsonb(v_warn));
      end;
    end loop;

    if p_dry_run then
      raise exception using message = c_dry;
    end if;
  exception when others then
    if sqlerrm <> c_dry then raise; end if;
  end;

  return jsonb_build_object('kind', p_kind, 'dry_run', p_dry_run, 'total', n,
                            'ok', v_ok, 'failed', v_fail, 'results', v_results);
end $$;
revoke all on function public.admin_import(text, jsonb, boolean) from public, anon;
grant execute on function public.admin_import(text, jsonb, boolean) to authenticated;


-- ############################################################ 0121_v110_feature_list.sql
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


-- ############################################################ seed/20_v110_struktur.sql
-- Struktur v1.1.0 sesuai DAFTAR FITUR pemilik (bagian D & E). Boleh dijalankan
-- di produksi, aman diulang (not exists). TIDAK berisi materi BISINDO:
--   * nama kategori dan topik persis dari daftar pemilik;
--   * kosakata contoh dari daftar pemilik dibuat sebagai DRAFT berisi NAMA saja
--     (tanpa arti, penjelasan, video). Draft tidak tampil di aplikasi sampai
--     dilengkapi dan dipublikasikan dari CMS.
-- Data yang sudah ada (kategori/topik/kosakata dengan nama sama) TIDAK diubah.

-- Kategori kosakata (D. Kategori awal 1–12)
insert into public.categories (slug, name, kind, sort_order)
select v.slug, v.name, 'sign', v.ord
from (values
  ('keluarga', 'Keluarga', 101), ('sapaan', 'Sapaan', 102), ('aktivitas', 'Aktivitas', 103),
  ('anggota-tubuh', 'Anggota Tubuh', 104), ('makanan-dan-minuman', 'Makanan dan Minuman', 105),
  ('hewan', 'Hewan', 106), ('warna', 'Warna', 107), ('sekolah', 'Sekolah', 108),
  ('profesi', 'Profesi', 109), ('tempat', 'Tempat', 110),
  ('perasaan-dan-emosi', 'Perasaan dan Emosi', 111),
  ('kata-kerja-dan-kata-sifat', 'Kata Kerja dan Kata Sifat', 112)
) v(slug, name, ord)
where not exists (select 1 from public.categories c
                  where c.slug = v.slug or (c.kind = 'sign' and lower(c.name) = lower(v.name)));

-- Kosakata contoh dari daftar pemilik → DRAFT, nama saja.
insert into public.signs (entry_type, category_id, term, content_module, status, sort_order)
select v.entry_type::public.sign_entry_type, c.id, v.term, 'vocabulary', 'draft', v.ord
from (values
  ('keluarga', 'Ayah', 'word', 1), ('keluarga', 'Ibu', 'word', 2), ('keluarga', 'Kakak', 'word', 3),
  ('keluarga', 'Adik', 'word', 4), ('keluarga', 'Saudara', 'word', 5),
  ('sapaan', 'Halo', 'word', 1), ('sapaan', 'Selamat pagi', 'phrase', 2), ('sapaan', 'Selamat malam', 'phrase', 3),
  ('aktivitas', 'Makan', 'word', 1), ('aktivitas', 'Minum', 'word', 2), ('aktivitas', 'Tidur', 'word', 3),
  ('aktivitas', 'Mandi', 'word', 4), ('aktivitas', 'Belajar', 'word', 5),
  ('anggota-tubuh', 'Kepala', 'word', 1), ('anggota-tubuh', 'Mata', 'word', 2), ('anggota-tubuh', 'Hidung', 'word', 3),
  ('anggota-tubuh', 'Tangan', 'word', 4), ('anggota-tubuh', 'Kaki', 'word', 5)
) v(cat_slug, term, entry_type, ord)
join lateral (
  select c.id from public.categories c
  where c.kind = 'sign' and (c.slug = v.cat_slug or lower(c.name) = lower(replace(v.cat_slug, '-', ' ')))
  order by (c.slug = v.cat_slug) desc limit 1
) c on true
where not exists (select 1 from public.signs s
                  where s.content_module = 'vocabulary' and s.term_normalized = lower(v.term));

-- Topik percakapan (E. Materi 1–8): DRAFT kosong, kalimat & video dari pemilik.
insert into public.conversation_modules (slug, title, sort_order, status)
select v.slug, v.title, v.ord, 'draft'
from (values
  ('perkenalan-diri', 'Perkenalan diri', 1), ('menanyakan-nama', 'Menanyakan nama', 2),
  ('menanyakan-kabar', 'Menanyakan kabar', 3), ('percakapan-sehari-hari', 'Percakapan sehari-hari', 4),
  ('percakapan-di-sekolah', 'Percakapan di sekolah', 5), ('percakapan-di-rumah', 'Percakapan di rumah', 6),
  ('terima-kasih-dan-maaf', 'Ungkapan terima kasih dan permintaan maaf', 7),
  ('kalimat-sederhana-lainnya', 'Kalimat sederhana lainnya', 8)
) v(slug, title, ord)
where not exists (select 1 from public.conversation_modules m
                  where m.slug = v.slug or lower(m.title) = lower(v.title));


commit;

select 'BISINDO v1.1.0 siap' as status,
       (select count(*) from public.app_settings) as pengaturan,
       (select count(*) from public.categories where kind = 'sign') as kategori_kosakata,
       (select count(*) from public.conversation_modules) as topik_percakapan,
       (select count(*) from public.signs where status = 'published') as materi_published,
       (select count(*) from public.profiles) as jumlah_akun;
