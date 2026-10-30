-- Rollback 0118. Aman: menghapus trigger & fungsi validasi publikasi.
drop trigger if exists guard_publish on public.signs;
drop trigger if exists guard_publish on public.conversation_modules;
drop trigger if exists guard_publish on public.lessons;
drop trigger if exists guard_publish on public.questions;
drop function if exists public.guard_publish();
drop function if exists public.publish_issues(text, uuid);
drop function if exists public.question_publish_issues(public.questions);
drop function if exists public.lesson_publish_issues(public.lessons);
drop function if exists public.module_publish_issues(public.conversation_modules);
drop function if exists public.sign_publish_issues(public.signs);
