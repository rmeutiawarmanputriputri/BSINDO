-- Rollback 0114. ⚠️ MENGHAPUS soal bank (quiz_id IS NULL) beserta pilihannya
-- dan riwayat quiz_sessions. Soal pelajaran & quiz_attempts lama tidak disentuh.
-- Jalankan rollback 0117–0120 lebih dulu.
drop function if exists public.submit_quiz_session(text, jsonb, text, uuid, text, timestamptz);
drop function if exists public.get_quiz_questions(text, text, uuid, text, int);
drop function if exists public.check_quiz_answer(uuid, jsonb);
drop function if exists public.answer_reveal(uuid);
drop function if exists public.grade_question(uuid, jsonb);
drop function if exists public.can_read_question(uuid);
drop policy if exists options_bank_read on public.question_options;
drop policy if exists questions_bank_read on public.questions;
drop table if exists public.quiz_sessions;
drop trigger if exists question_answer_keys_validate on public.question_answer_keys;
drop function if exists public.validate_answer_key();
delete from public.questions where quiz_id is null;
alter table public.question_answer_keys drop constraint if exists answer_key_has_answer,
  drop column if exists pairs, drop column if exists correct_sequence;
alter table public.question_answer_keys alter column correct_option_id set not null;
alter table public.question_options drop column if exists side, drop column if exists image_asset_id;
drop index if exists public.questions_bank_idx;
alter table public.questions
  drop constraint if exists questions_bank_needs_module, drop constraint if exists questions_lesson_mc_only,
  drop constraint if exists questions_type_valid,
  drop column if exists created_by, drop column if exists image_asset_id, drop column if exists video_asset_id,
  drop column if exists sort_order, drop column if exists is_premium, drop column if exists is_active,
  drop column if exists status, drop column if exists difficulty, drop column if exists category_id,
  drop column if exists module;
alter table public.questions add constraint questions_question_type_check check (question_type = 'multiple_choice');
alter table public.questions alter column quiz_id set not null;
