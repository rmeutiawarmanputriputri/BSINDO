-- Kategori struktural (nama saja). Boleh dijalankan di produksi.
insert into public.categories (slug, name, kind, sort_order) values
  ('salam',                       'Salam',            'sign', 1),
  ('perkenalan',                  'Perkenalan',       'sign', 2),
  ('keluarga-teman',              'Keluarga & Teman', 'sign', 3),
  ('sekolah',                     'Sekolah',          'sign', 4),
  ('berbelanja',                  'Berbelanja',       'sign', 5),
  ('meminta-bantuan',             'Meminta Bantuan',  'sign', 6),
  ('bertanya-arah',               'Bertanya Arah',    'sign', 7),
  ('lainnya',                     'Lainnya',          'sign', 8),
  ('percakapan-salam',            'Salam',            'conversation', 1),
  ('percakapan-perkenalan',       'Perkenalan',       'conversation', 2),
  ('percakapan-keluarga-teman',   'Keluarga & Teman', 'conversation', 3),
  ('percakapan-sekolah',          'Sekolah',          'conversation', 4),
  ('percakapan-berbelanja',       'Berbelanja',       'conversation', 5),
  ('percakapan-meminta-bantuan',  'Meminta Bantuan',  'conversation', 6),
  ('percakapan-bertanya-arah',    'Bertanya Arah',    'conversation', 7),
  ('percakapan-lainnya',          'Lainnya',          'conversation', 8)
on conflict (slug) do nothing;
