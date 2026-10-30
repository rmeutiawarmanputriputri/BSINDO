-- Rollback 0112. ⚠️ MENGHAPUS materi Alfabet & Angka (signs.content_module <> 'vocabulary')
-- serta kolom baru (gambar panduan, audio, terjemahan, penjelasan, Premium).
-- Cadangkan tabel signs & conversation_items sebelum menjalankan.
delete from public.signs where content_module <> 'vocabulary';
alter table public.lessons drop column if exists is_premium;
alter table public.conversation_items drop column if exists audio_asset_id,
  drop column if exists explanation, drop column if exists translation;
alter table public.conversation_modules drop column if exists is_premium;
drop index if exists public.signs_module_group_idx;
drop index if exists public.signs_module_status_order_idx;
alter table public.signs drop constraint if exists signs_number_group_only_number,
  drop column if exists is_premium, drop column if exists audio_asset_id, drop column if exists image_asset_id,
  drop column if exists sort_order, drop column if exists number_group, drop column if exists symbol,
  drop column if exists content_module;
alter table public.categories drop column if exists image_asset_id;
