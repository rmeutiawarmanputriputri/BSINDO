-- 0009_defaults_hardening.sql — tambahan BISINDO-FIX di atas draf dokumen.
-- 1) Kolom pemilik terisi otomatis dari JWT, sehingga klien tidak perlu (dan
--    tidak bisa memalsukan, karena policy with check tetap memeriksa)
--    mengirim user_id.
-- 2) Opsi yang disarankan SUPABASE_SECURITY_PLAN §3 catatan: favorit/kosakata
--    sulit hanya untuk sign yang published (atau admin).

alter table public.favorites            alter column user_id     set default auth.uid();
alter table public.difficult_vocabulary alter column user_id     set default auth.uid();
alter table public.user_progress        alter column user_id     set default auth.uid();
alter table public.content_reports      alter column reporter_id set default auth.uid();
alter table public.media_assets         alter column uploaded_by set default auth.uid();
alter table public.signs                alter column created_by  set default auth.uid();
alter table public.conversation_modules alter column created_by  set default auth.uid();
alter table public.lessons              alter column created_by  set default auth.uid();

drop policy favorites_insert_own on public.favorites;
create policy favorites_insert_own on public.favorites for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and exists (select 1 from public.signs s
                where s.id = sign_id and (s.status = 'published' or public.is_admin())));

drop policy difficult_insert_own on public.difficult_vocabulary;
create policy difficult_insert_own on public.difficult_vocabulary for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and exists (select 1 from public.signs s
                where s.id = sign_id and (s.status = 'published' or public.is_admin())));

-- Ringkasan untuk dashboard admin (S25) dalam satu panggilan.
create or replace function public.admin_dashboard_counts()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_admin() then
    raise exception 'not_admin' using errcode = '42501';
  end if;
  return jsonb_build_object(
    'open_reports', (select count(*) from public.content_reports where status in ('open', 'in_review')),
    'in_review', (select count(*) from public.signs where status = 'in_review')
               + (select count(*) from public.conversation_modules where status = 'in_review')
               + (select count(*) from public.lessons where status = 'in_review'),
    'drafts', (select count(*) from public.signs where status = 'draft')
            + (select count(*) from public.conversation_modules where status = 'draft')
            + (select count(*) from public.lessons where status = 'draft')
  );
end $$;
revoke all on function public.admin_dashboard_counts() from public, anon;
grant execute on function public.admin_dashboard_counts() to authenticated;
