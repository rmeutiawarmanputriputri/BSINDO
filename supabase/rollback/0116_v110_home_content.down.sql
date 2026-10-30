-- Rollback 0116. ⚠️ MENGHAPUS banner, pengumuman, FAQ yang sudah diisi admin.
-- Jalankan 0117 rollback lebih dulu (can_read_media merujuk banners).
drop table if exists public.announcement_reads;
drop table if exists public.announcements;
drop table if exists public.banners;
drop table if exists public.faqs;
