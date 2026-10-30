-- Rollback 0115. ⚠️ MENGHAPUS progres per materi (sign_progress) pengguna.
-- Cadangkan dulu: copy (select * from public.sign_progress) to ... / ekspor CSV.
drop function if exists public.my_progress_summary();
drop view if exists public.my_learning_history;
drop function if exists public.record_sign_view(uuid, boolean);
drop table if exists public.sign_progress;
