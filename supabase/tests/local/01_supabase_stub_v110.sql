-- Tambahan stub untuk v1.1.0: kolom auth.users yang dibaca RPC admin.
-- HANYA untuk uji lokal.
alter table auth.users add column if not exists created_at timestamptz default now();
alter table auth.users add column if not exists last_sign_in_at timestamptz;
