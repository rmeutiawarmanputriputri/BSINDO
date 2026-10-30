-- HANYA MEMBACA (tidak mengubah apa pun). Jalankan di SQL Editor proyek Supabase
-- SEBELUM menerapkan migrasi 0110–0120, lalu kirim hasilnya ke pengembang.
select 'tabel_lama (harus 17)' as cek, count(*)::text as hasil
  from information_schema.tables where table_schema = 'public' and table_name in
  ('profiles','categories','media_assets','signs','conversation_modules','conversation_items','lessons','lesson_items',
   'quizzes','questions','question_options','question_answer_keys','quiz_attempts','user_progress','favorites',
   'difficult_vocabulary','content_reports')
union all select 'fungsi touch_progress (harus 1)', count(*)::text from pg_proc where proname = 'touch_progress'
union all select 'tabel v1.1.0 yang SUDAH ada (harus -)', coalesce(string_agg(table_name::text, ', '), '-')
  from information_schema.tables where table_schema = 'public' and table_name in
  ('app_settings','subscriptions','quiz_sessions','sign_progress','banners','announcements','announcement_reads','faqs')
union all select 'kolom v1.1.0 yang SUDAH ada (harus -)', coalesce(string_agg(table_name::text || '.' || column_name::text, ', '), '-')
  from information_schema.columns where table_schema = 'public' and (table_name::text, column_name::text) in
  (('signs','content_module'),('signs','is_premium'),('profiles','is_active'),('media_assets','status'),
   ('questions','module'),('conversation_items','translation'),('categories','image_asset_id'))
union all select 'semua tabel public', string_agg(table_name::text, ', ' order by table_name::text)
  from information_schema.tables where table_schema = 'public'
union all select 'jumlah pengguna', count(*)::text from public.profiles
union all select 'akun admin', coalesce(string_agg(u.email, ', '), '-')
  from public.profiles p join auth.users u on u.id = p.id where p.role = 'admin'
union all select 'materi published', count(*)::text from public.signs where status = 'published'
union all select 'data contoh DEV-SAMPLE', count(*)::text from public.signs where validated_by like 'DEV-SAMPLE%'
union all select 'bucket media', coalesce(string_agg(id || ' (' || coalesce(file_size_limit::text, '-') || ' B)', ', '), '-')
  from storage.buckets;
