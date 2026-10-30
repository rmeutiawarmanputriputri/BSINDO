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
