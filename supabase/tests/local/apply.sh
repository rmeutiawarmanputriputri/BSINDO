#!/usr/bin/env bash
# Membuat DB uji baru lalu menerapkan stub + seluruh migrasi + seed kategori.
# Pemakaian: DB=nama bash tests/local/apply.sh
set -euo pipefail
cd "$(dirname "$0")/../.."
P="psql -v ON_ERROR_STOP=1 -q"
DB=${DB:-bisindo_v110}
$P -d postgres -c "drop database if exists $DB" -c "create database $DB" >/dev/null
$P -d $DB -f tests/local/00_supabase_stub.sql -f tests/local/01_supabase_stub_v110.sql
for f in migrations/*.sql; do $P -d $DB -f "$f"; done
$P -d $DB -f seed/00_categories.sql
echo "OK: $DB"
