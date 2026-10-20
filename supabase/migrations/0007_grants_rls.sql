-- 0007_grants_rls.sql — sumber: docs/SUPABASE_SECURITY_PLAN.md §3
-- 3.1 Default deny
revoke all on all tables    in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;
alter default privileges in schema public revoke all on tables from anon, authenticated;

-- 3.2 Aktifkan RLS
alter table public.profiles             enable row level security;
alter table public.categories           enable row level security;
alter table public.media_assets         enable row level security;
alter table public.signs                enable row level security;
alter table public.conversation_modules enable row level security;
alter table public.conversation_items   enable row level security;
alter table public.lessons              enable row level security;
alter table public.lesson_items         enable row level security;
alter table public.quizzes              enable row level security;
alter table public.questions            enable row level security;
alter table public.question_options     enable row level security;
alter table public.question_answer_keys enable row level security;
alter table public.quiz_attempts        enable row level security;
alter table public.user_progress        enable row level security;
alter table public.favorites            enable row level security;
alter table public.difficult_vocabulary enable row level security;
alter table public.content_reports      enable row level security;

-- 3.3 Grants (RLS tetap membatasi baris)
-- Profil: baca; ubah HANYA full_name (role tidak bisa diubah klien)
grant select on public.profiles to authenticated;
grant update (full_name) on public.profiles to authenticated;

-- Konten: pengguna membaca; admin menulis (dibatasi policy)
grant select, insert, update, delete on
  public.categories, public.media_assets, public.signs,
  public.conversation_modules, public.conversation_items,
  public.lessons, public.lesson_items, public.quizzes,
  public.questions, public.question_options, public.question_answer_keys
to authenticated;

-- Data pribadi
grant select on public.quiz_attempts to authenticated;          -- insert hanya via RPC
grant select, insert, update on public.user_progress to authenticated;
grant select, insert, delete on public.favorites to authenticated;
grant select, insert, update, delete on public.difficult_vocabulary to authenticated;
grant select, insert, update on public.content_reports to authenticated; -- update dibatasi policy admin

-- profiles
create policy profiles_select on public.profiles for select to authenticated
  using (id = (select auth.uid()) or public.is_admin());
create policy profiles_update_own on public.profiles for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));
-- Tidak ada policy insert/delete: profil dibuat trigger, dihapus via cascade.
-- Hanya kolom full_name yang diberi grant update -> role tidak dapat dinaikkan klien.

-- Konten: baca (published / aktif), admin kelola
create policy categories_read on public.categories for select to authenticated
  using (is_active or public.is_admin());
create policy categories_admin on public.categories for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy signs_read on public.signs for select to authenticated
  using (status = 'published' or public.is_admin());
create policy signs_admin on public.signs for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy conv_modules_read on public.conversation_modules for select to authenticated
  using (status = 'published' or public.is_admin());
create policy conv_modules_admin on public.conversation_modules for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy conv_items_read on public.conversation_items for select to authenticated
  using (public.is_admin() or exists (
    select 1 from public.conversation_modules m
    where m.id = module_id and m.status = 'published'));
create policy conv_items_admin on public.conversation_items for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy lessons_read on public.lessons for select to authenticated
  using (status = 'published' or public.is_admin());
create policy lessons_admin on public.lessons for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy lesson_items_read on public.lesson_items for select to authenticated
  using (public.is_admin() or exists (
    select 1 from public.lessons l where l.id = lesson_id and l.status = 'published'));
create policy lesson_items_admin on public.lesson_items for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy quizzes_read on public.quizzes for select to authenticated
  using (public.is_admin() or (is_active and exists (
    select 1 from public.lessons l where l.id = lesson_id and l.status = 'published')));
create policy quizzes_admin on public.quizzes for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy questions_read on public.questions for select to authenticated
  using (public.is_admin() or exists (
    select 1 from public.quizzes z join public.lessons l on l.id = z.lesson_id
    where z.id = quiz_id and z.is_active and l.status = 'published'));
create policy questions_admin on public.questions for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy options_read on public.question_options for select to authenticated
  using (public.is_admin() or exists (
    select 1 from public.questions q
    join public.quizzes z on z.id = q.quiz_id
    join public.lessons l on l.id = z.lesson_id
    where q.id = question_id and z.is_active and l.status = 'published'));
create policy options_admin on public.question_options for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- Kunci jawaban: TIDAK ada policy untuk pengguna biasa -> tertutup. Hanya admin.
create policy answer_keys_admin on public.question_answer_keys for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy media_read on public.media_assets for select to authenticated
  using (public.can_read_media(path));
create policy media_admin on public.media_assets for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- Data pribadi
create policy attempts_select_own on public.quiz_attempts for select to authenticated
  using (user_id = (select auth.uid()) or public.is_admin());
-- (tanpa policy insert/update/delete: hanya RPC security definer yang menulis)

create policy progress_select_own on public.user_progress for select to authenticated
  using (user_id = (select auth.uid()));
create policy progress_insert_own on public.user_progress for insert to authenticated
  with check (user_id = (select auth.uid()));
create policy progress_update_own on public.user_progress for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

create policy favorites_select_own on public.favorites for select to authenticated
  using (user_id = (select auth.uid()));
create policy favorites_insert_own on public.favorites for insert to authenticated
  with check (user_id = (select auth.uid()));
create policy favorites_delete_own on public.favorites for delete to authenticated
  using (user_id = (select auth.uid()));

create policy difficult_select_own on public.difficult_vocabulary for select to authenticated
  using (user_id = (select auth.uid()));
create policy difficult_insert_own on public.difficult_vocabulary for insert to authenticated
  with check (user_id = (select auth.uid()));
create policy difficult_update_own on public.difficult_vocabulary for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy difficult_delete_own on public.difficult_vocabulary for delete to authenticated
  using (user_id = (select auth.uid()));

-- Laporan
create policy reports_select on public.content_reports for select to authenticated
  using (reporter_id = (select auth.uid()) or public.is_admin());
create policy reports_insert_own on public.content_reports for insert to authenticated
  with check (
    reporter_id = (select auth.uid())
    and status = 'open'
    and resolution_message is null and resolved_by is null and resolved_at is null);
create policy reports_update_admin on public.content_reports for update to authenticated
  using (public.is_admin()) with check (public.is_admin());
-- Pengguna biasa: tidak ada policy update/delete -> tidak dapat mengubah status/pesan.
