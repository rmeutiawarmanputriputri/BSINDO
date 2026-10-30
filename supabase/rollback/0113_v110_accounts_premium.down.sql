-- Rollback 0113. ⚠️ MENGHAPUS data langganan Premium & status aktif akun.
-- Jalankan rollback 0114–0120 lebih dulu (fungsi lain merujuk has_premium/is_active_user).
drop function if exists public.delete_my_account();
drop function if exists public.my_premium_status();
drop function if exists public.has_premium(uuid);
drop table if exists public.subscriptions;
drop function if exists public.is_active_user();
alter table public.profiles drop column if exists is_active;
