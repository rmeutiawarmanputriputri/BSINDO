#!/usr/bin/env bash
# Menyiapkan DB uji CMS (cms_e2e) + berkas media uji sintetis berlabel TEST_
# (warna/nada buatan ffmpeg — BUKAN rekaman BISINDO).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/../../.."
P="psql -v ON_ERROR_STOP=1 -q"
DB=${PGDATABASE:-cms_e2e}
(cd "$ROOT/supabase" && DB=$DB bash tests/local/apply.sh >/dev/null)
$P -d $DB -f "$ROOT/supabase/seed/20_v110_struktur.sql"
$P -d $DB <<'SQL'
create schema if not exists t_auth;
create table if not exists t_auth.creds (user_id uuid primary key references auth.users(id) on delete cascade, password text not null);
insert into auth.users (id, email, raw_user_meta_data) values
  ('a0000000-0000-4000-8000-0000000000ad', 'cms.admin@test.local', '{"full_name":"TEST Admin CMS"}'),
  ('a0000000-0000-4000-8000-0000000000b1', 'cms.user@test.local',  '{"full_name":"TEST Pengguna"}');
update public.profiles set role = 'admin' where id = 'a0000000-0000-4000-8000-0000000000ad';
insert into t_auth.creds values ('a0000000-0000-4000-8000-0000000000ad', 'Admin#12345'), ('a0000000-0000-4000-8000-0000000000b1', 'User#12345');
SQL
M="$HERE/media"; mkdir -p "$M"
if [ ! -f "$M/TEST_video_a.mp4" ]; then
  ffmpeg -loglevel error -y -f lavfi -i testsrc=size=320x240:rate=15 -f lavfi -i sine=frequency=440 -t 2 -c:v libx264 -pix_fmt yuv420p -c:a aac -shortest "$M/TEST_video_a.mp4"
  ffmpeg -loglevel error -y -f lavfi -i smptebars=size=320x240:rate=15 -t 2 -c:v libx264 -pix_fmt yuv420p "$M/TEST_video_b.mp4"
  ffmpeg -loglevel error -y -f lavfi -i sine=frequency=660 -t 1 -c:a libmp3lame "$M/TEST_audio.mp3"
  ffmpeg -loglevel error -y -f lavfi -i sine=frequency=550 -t 1 "$M/TEST_audio.wav"
  ffmpeg -loglevel error -y -f lavfi -i color=c=orange:size=320x180 -frames:v 1 "$M/TEST_image_1.png"
  ffmpeg -loglevel error -y -f lavfi -i color=c=teal:size=320x180 -frames:v 1 "$M/TEST_image_2.png"
fi
echo "OK $DB"; ls -la "$M"
