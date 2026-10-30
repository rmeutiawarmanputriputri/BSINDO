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
