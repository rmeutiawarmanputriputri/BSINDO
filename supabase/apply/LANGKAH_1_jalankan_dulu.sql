-- ============================================================================
-- BISINDO v1.1.0 — PEMBARUAN DATABASE, LANGKAH 1 dari 2
-- Cara pakai: Supabase → SQL Editor → New query → tempel SELURUH isi file ini → Run.
-- Hasil yang benar: "Success. No rows returned".
-- Isi: menambah 2 nilai pilihan baru (status 'inactive', jenis media 'audio').
-- Tidak mengubah/menghapus data apa pun. Aman dijalankan ulang.
-- ============================================================================

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

-- 0110_v110_enum_values.sql — BISINDO v1.1.0
-- Nilai enum baru. Sengaja dipisah dari migrasi lain: PostgreSQL tidak
-- mengizinkan nilai enum baru DIPAKAI dalam transaksi yang sama dengan
-- ALTER TYPE ... ADD VALUE. Jalankan file ini sendiri (Supabase CLI
-- menjalankan tiap file dalam transaksinya masing-masing).
--
-- Aman untuk aplikasi 1.0.0: nilai lama tidak berubah.
-- Rollback: lihat supabase/rollback/0110_v110_enum_values.down.sql

alter type public.content_status add value if not exists 'inactive';
alter type public.media_kind     add value if not exists 'audio';
