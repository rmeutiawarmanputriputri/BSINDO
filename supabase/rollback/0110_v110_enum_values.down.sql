-- Rollback 0110. PostgreSQL tidak bisa menghapus nilai enum tanpa membuat
-- ulang tipe. Nilai 'inactive' dan 'audio' DIBIARKAN (tidak berbahaya bagi
-- aplikasi 1.0.0). Pastikan tidak ada baris yang memakainya:
update public.signs set status = 'archived' where status = 'inactive';
update public.conversation_modules set status = 'archived' where status = 'inactive';
update public.lessons set status = 'archived' where status = 'inactive';
-- media audio dihapus pada rollback 0111.
