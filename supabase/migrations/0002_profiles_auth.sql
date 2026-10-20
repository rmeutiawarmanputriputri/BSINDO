-- 0002_profiles_auth.sql — sumber: docs/DATABASE_SCHEMA.md (disesuaikan, lihat komentar 'BISINDO-FIX')
create table public.profiles (
  id         uuid primary key references auth.users (id) on delete cascade,
  full_name  text not null check (char_length(btrim(full_name)) between 2 and 80),
  role       public.app_role not null default 'user',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Profil dibuat otomatis. Role SELALU 'user' (tidak pernah dibaca dari metadata klien).
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_name text;
begin
  v_name := btrim(coalesce(new.raw_user_meta_data ->> 'full_name', ''));
  if char_length(v_name) < 2 then v_name := 'Pengguna'; end if;
  v_name := left(v_name, 80);
  insert into public.profiles (id, full_name) values (new.id, v_name);
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

revoke all on function public.handle_new_user() from public, anon, authenticated;

-- Pemeriksaan admin di backend. Tidak membaca JWT/user_metadata (bisa dimanipulasi).
create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.role = 'admin'
  );
$$;
revoke all on function public.is_admin() from public, anon;
grant execute on function public.is_admin() to authenticated;
