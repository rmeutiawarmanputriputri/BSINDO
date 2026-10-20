#!/usr/bin/env bash
# Menjalankan seluruh uji database lokal:
#  1) migrasi + 30 uji RLS/Storage (10_rls_tests.sql)
#  2) seed + 47 uji string query repository Dart terhadap PostgREST asli
# Prasyarat: PostgreSQL 16 (psql di PATH, DB lokal dapat dibuat), biner postgrest (v13)
#   PGHOST/PGPORT/PGUSER sesuai lokal; POSTGREST_BIN=path/ke/postgrest
set -euo pipefail
cd "$(dirname "$0")/../.."
PSQL="psql -v ON_ERROR_STOP=1 -q"
DB=${DB:-bisindo_test}
$PSQL -d postgres -c "drop database if exists $DB" -c "create database $DB"
$PSQL -d $DB -f tests/local/00_supabase_stub.sql
for f in migrations/*.sql; do $PSQL -d $DB -f "$f"; done
$PSQL -d $DB -f tests/local/10_rls_tests.sql | grep -E 'LULUS|GAGAL'

# --- PostgREST
$PSQL -d postgres -c "drop database if exists ${DB}_api" -c "create database ${DB}_api"
$PSQL -d ${DB}_api -f tests/local/00_supabase_stub.sql
for f in migrations/*.sql; do $PSQL -d ${DB}_api -f "$f"; done
$PSQL -d ${DB}_api -f seed/00_categories.sql -f seed/10_dev_samples.sql
$PSQL -d ${DB}_api -c "do \$\$ begin if not exists (select 1 from pg_roles where rolname='authenticator') then create role authenticator login noinherit; end if; end \$\$; grant anon, authenticated to authenticator;"
$PSQL -d ${DB}_api -c "insert into auth.users (id,email,raw_user_meta_data) values ('aaaaaaaa-0000-0000-0000-00000000000a','a@test.local','{\"full_name\":\"Uji A\"}'),('cccccccc-0000-0000-0000-00000000000c','adm@test.local','{\"full_name\":\"Admin\"}'); update profiles set role='admin' where id='cccccccc-0000-0000-0000-00000000000c';"
CONF=$(mktemp)
cat > "$CONF" <<CFG
db-uri = "${PGRST_DB_URI:-postgres://authenticator@/${DB}_api}"
db-schemas = "public"
db-anon-role = "anon"
jwt-secret = "${PGRST_JWT_SECRET:-uji-rahasia-lokal-yang-panjang-sekali-32b}"
server-port = 3999
CFG
"${POSTGREST_BIN:-postgrest}" "$CONF" > /tmp/postgrest.log 2>&1 &
PID=$!
trap 'kill $PID 2>/dev/null || true' EXIT
sleep 3
python3 tests/local/postgrest_queries.py
