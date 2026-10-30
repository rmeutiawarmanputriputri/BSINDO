-- Struktur v1.1.0 sesuai DAFTAR FITUR pemilik (bagian D & E). Boleh dijalankan
-- di produksi, aman diulang (not exists). TIDAK berisi materi BISINDO:
--   * nama kategori dan topik persis dari daftar pemilik;
--   * kosakata contoh dari daftar pemilik dibuat sebagai DRAFT berisi NAMA saja
--     (tanpa arti, penjelasan, video). Draft tidak tampil di aplikasi sampai
--     dilengkapi dan dipublikasikan dari CMS.
-- Data yang sudah ada (kategori/topik/kosakata dengan nama sama) TIDAK diubah.

-- Kategori kosakata (D. Kategori awal 1–12)
insert into public.categories (slug, name, kind, sort_order)
select v.slug, v.name, 'sign', v.ord
from (values
  ('keluarga', 'Keluarga', 101), ('sapaan', 'Sapaan', 102), ('aktivitas', 'Aktivitas', 103),
  ('anggota-tubuh', 'Anggota Tubuh', 104), ('makanan-dan-minuman', 'Makanan dan Minuman', 105),
  ('hewan', 'Hewan', 106), ('warna', 'Warna', 107), ('sekolah', 'Sekolah', 108),
  ('profesi', 'Profesi', 109), ('tempat', 'Tempat', 110),
  ('perasaan-dan-emosi', 'Perasaan dan Emosi', 111),
  ('kata-kerja-dan-kata-sifat', 'Kata Kerja dan Kata Sifat', 112)
) v(slug, name, ord)
where not exists (select 1 from public.categories c
                  where c.slug = v.slug or (c.kind = 'sign' and lower(c.name) = lower(v.name)));

-- Kosakata contoh dari daftar pemilik → DRAFT, nama saja.
insert into public.signs (entry_type, category_id, term, content_module, status, sort_order)
select v.entry_type::public.sign_entry_type, c.id, v.term, 'vocabulary', 'draft', v.ord
from (values
  ('keluarga', 'Ayah', 'word', 1), ('keluarga', 'Ibu', 'word', 2), ('keluarga', 'Kakak', 'word', 3),
  ('keluarga', 'Adik', 'word', 4), ('keluarga', 'Saudara', 'word', 5),
  ('sapaan', 'Halo', 'word', 1), ('sapaan', 'Selamat pagi', 'phrase', 2), ('sapaan', 'Selamat malam', 'phrase', 3),
  ('aktivitas', 'Makan', 'word', 1), ('aktivitas', 'Minum', 'word', 2), ('aktivitas', 'Tidur', 'word', 3),
  ('aktivitas', 'Mandi', 'word', 4), ('aktivitas', 'Belajar', 'word', 5),
  ('anggota-tubuh', 'Kepala', 'word', 1), ('anggota-tubuh', 'Mata', 'word', 2), ('anggota-tubuh', 'Hidung', 'word', 3),
  ('anggota-tubuh', 'Tangan', 'word', 4), ('anggota-tubuh', 'Kaki', 'word', 5)
) v(cat_slug, term, entry_type, ord)
join lateral (
  select c.id from public.categories c
  where c.kind = 'sign' and (c.slug = v.cat_slug or lower(c.name) = lower(replace(v.cat_slug, '-', ' ')))
  order by (c.slug = v.cat_slug) desc limit 1
) c on true
where not exists (select 1 from public.signs s
                  where s.content_module = 'vocabulary' and s.term_normalized = lower(v.term));

-- Topik percakapan (E. Materi 1–8): DRAFT kosong, kalimat & video dari pemilik.
insert into public.conversation_modules (slug, title, sort_order, status)
select v.slug, v.title, v.ord, 'draft'
from (values
  ('perkenalan-diri', 'Perkenalan diri', 1), ('menanyakan-nama', 'Menanyakan nama', 2),
  ('menanyakan-kabar', 'Menanyakan kabar', 3), ('percakapan-sehari-hari', 'Percakapan sehari-hari', 4),
  ('percakapan-di-sekolah', 'Percakapan di sekolah', 5), ('percakapan-di-rumah', 'Percakapan di rumah', 6),
  ('terima-kasih-dan-maaf', 'Ungkapan terima kasih dan permintaan maaf', 7),
  ('kalimat-sederhana-lainnya', 'Kalimat sederhana lainnya', 8)
) v(slug, title, ord)
where not exists (select 1 from public.conversation_modules m
                  where m.slug = v.slug or lower(m.title) = lower(v.title));
