#!/usr/bin/env bash
# Uji database v1.1.0 lengkap (PostgreSQL 16 lokal + stub Supabase):
#  1) migrasi 0001–0120 + seed struktur
#  2) uji lama 10_rls_tests.sql (kompatibilitas aplikasi 1.0.0)
#  3) uji baru 20_v110_tests.sql
#  4) rollback 0120→0110 lalu bandingkan skema dengan 0001–0010
# Prasyarat: psql di PATH; PGHOST/PGPORT/PGUSER menunjuk server lokal (superuser).
set -euo pipefail
cd "$(dirname "$0")/../.."
P="psql -v ON_ERROR_STOP=1 -q"
OUT=${OUT:-/tmp/bisindo_v110_tests}; mkdir -p "$OUT"

echo "== 1. migrasi"
DB=v110_legacy bash tests/local/apply.sh
$P -d v110_legacy -f seed/20_v110_struktur.sql
$P -d v110_legacy -f seed/20_v110_struktur.sql   # idempoten
echo "   kategori: $($P -At -d v110_legacy -c 'select count(*) from categories')  topik draft: $($P -At -d v110_legacy -c "select count(*) from conversation_modules where status='draft'")"

echo "== 2. uji lama (10_rls_tests)"
$P -d v110_legacy -f tests/local/10_rls_tests.sql > "$OUT/10_rls.txt" 2>&1
echo "   $(grep -c '| LULUS' "$OUT/10_rls.txt") LULUS, $(grep -c '| GAGAL' "$OUT/10_rls.txt" || true) GAGAL"

echo "== 3. uji v1.1.0 (20_v110_tests)"
DB=v110_new bash tests/local/apply.sh
$P -d v110_new -f tests/local/20_v110_tests.sql > "$OUT/20_v110.txt" 2>&1
echo "   $(grep -c '| LULUS' "$OUT/20_v110.txt") LULUS, $(grep -c '| GAGAL' "$OUT/20_v110.txt" || true) GAGAL"

echo "== 4. rollback"
$P -d postgres -c "drop database if exists v110_base" -c "create database v110_base" >/dev/null
$P -d v110_base -f tests/local/00_supabase_stub.sql -f tests/local/01_supabase_stub_v110.sql
for f in migrations/*.sql; do case "$f" in *01[12][0-9]_*) ;; *) $P -d v110_base -f "$f";; esac; done
$P -d v110_new -c "drop schema t cascade; delete from public.media_assets where kind = 'audio' or size_bytes > 20971520" >/dev/null 2>&1
for f in $(ls rollback/*.down.sql | sort -r); do $P -d v110_new -f "$f"; done
dump() { pg_dump -s -d "$1" --no-owner | grep -vE '^(--|\\restrict|\\unrestrict)' | sed '/^$/d'; }
dump v110_base > "$OUT/schema_base.sql"; dump v110_new > "$OUT/schema_rolled_back.sql"
if diff "$OUT/schema_base.sql" "$OUT/schema_rolled_back.sql" > "$OUT/rollback.diff"; then
  echo "   skema identik"
else
  echo "   selisih (diharapkan hanya nilai enum 'inactive'/'audio'):"; grep -E '^[<>]' "$OUT/rollback.diff"
fi
