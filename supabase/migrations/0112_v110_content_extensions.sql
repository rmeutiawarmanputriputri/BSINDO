-- 0112_v110_content_extensions.sql — BISINDO v1.1.0
-- Alfabet & Angka memakai tabel `signs` yang sudah ada (bukan tabel baru),
-- sehingga favorit, kosakata sulit, laporan, pencarian, dan kebijakan media
-- langsung berlaku. Pembeda: kolom `content_module`.
--   vocabulary : kosakata (default, semua data lama)
--   alphabet   : huruf A–Z  (symbol = huruf)
--   number     : angka      (symbol = angka, number_group = kelompok)
-- `entry_type` lama (word/phrase) TIDAK diubah agar aplikasi 1.0.0 aman.

-- ------------------------------------------------------------ categories
alter table public.categories
  add column image_asset_id uuid references public.media_assets (id) on delete set null;

-- ------------------------------------------------------------ signs
alter table public.signs
  add column content_module text not null default 'vocabulary'
    check (content_module in ('vocabulary', 'alphabet', 'number')),
  add column symbol         text check (symbol is null or char_length(btrim(symbol)) between 1 and 16),
  add column number_group   text check (number_group is null or number_group in ('0-9', '10-20', 'tens', '100+')),
  add column sort_order     int not null default 0,
  add column image_asset_id uuid references public.media_assets (id) on delete set null,  -- panduan visual gerakan
  add column audio_asset_id uuid references public.media_assets (id) on delete set null,
  add column is_premium     boolean not null default false,
  add constraint signs_number_group_only_number check (number_group is null or content_module = 'number');

create index signs_module_status_order_idx on public.signs (content_module, status, sort_order, term_normalized);
create index signs_module_group_idx on public.signs (content_module, number_group, sort_order) where content_module = 'number';

-- ------------------------------------------------------------ percakapan
alter table public.conversation_modules
  add column is_premium boolean not null default false;

alter table public.conversation_items
  add column translation    text check (translation is null or char_length(translation) <= 500),
  add column explanation    text check (explanation is null or char_length(explanation) <= 2000),
  add column audio_asset_id uuid references public.media_assets (id) on delete set null;

-- ------------------------------------------------------------ pelajaran
alter table public.lessons
  add column is_premium boolean not null default false;
