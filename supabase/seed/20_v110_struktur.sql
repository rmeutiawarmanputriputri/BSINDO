-- Struktur v1.1.0 (NAMA saja, tanpa materi). Boleh dijalankan di produksi,
-- aman diulang (on conflict / not exists). Nama berasal dari brief pemilik.
-- Kategori yang sudah ada (mis. "Salam", "Sekolah") TIDAK diubah.

-- Kategori kosakata
insert into public.categories (slug, name, kind, sort_order)
select v.slug, v.name, 'sign', v.ord
from (values
  ('keluarga', 'Keluarga', 101), ('salam', 'Salam', 102), ('aktivitas', 'Aktivitas', 103),
  ('anggota-tubuh', 'Anggota Tubuh', 104), ('makanan-minuman', 'Makanan & Minuman', 105),
  ('hewan', 'Hewan', 106), ('warna', 'Warna', 107), ('sekolah', 'Sekolah', 108),
  ('profesi', 'Profesi', 109), ('tempat', 'Tempat', 110), ('emosi', 'Emosi', 111),
  ('kata-kerja', 'Kata Kerja', 112), ('kata-sifat', 'Kata Sifat', 113)
) v(slug, name, ord)
where not exists (select 1 from public.categories c
                  where c.slug = v.slug or (c.kind = 'sign' and lower(c.name) = lower(v.name)));

-- Topik percakapan bawaan: dibuat sebagai DRAFT kosong (isi kalimat & video dari pemilik).
-- Draft tidak tampil di aplikasi sampai dilengkapi dan dipublikasikan di CMS.
insert into public.conversation_modules (slug, title, sort_order, status)
select v.slug, v.title, v.ord, 'draft'
from (values
  ('menyapa', 'Menyapa', 1), ('memperkenalkan-diri', 'Memperkenalkan diri', 2),
  ('menanyakan-nama', 'Menanyakan nama', 3), ('menanyakan-kabar', 'Menanyakan kabar', 4),
  ('percakapan-sehari-hari', 'Percakapan sehari-hari', 5), ('percakapan-di-sekolah', 'Percakapan di sekolah', 6),
  ('percakapan-di-rumah', 'Percakapan di rumah', 7), ('berterima-kasih', 'Berterima kasih', 8),
  ('meminta-maaf', 'Meminta maaf', 9)
) v(slug, title, ord)
where not exists (select 1 from public.conversation_modules m
                  where m.slug = v.slug or lower(m.title) = lower(v.title));
