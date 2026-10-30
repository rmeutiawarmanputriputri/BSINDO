#!/usr/bin/env bash
# Menjalankan uji E2E CMS dari nol (DB baru, berkas Storage uji baru).
# Prasyarat: PostgreSQL lokal (PGHOST/PGPORT/PGUSER), Node 20+, npm i (pg), Playwright+Chromium.
set -uo pipefail
cd "$(dirname "$0")/../.."
for p in $(ps -eo pid,args | grep -E "node tests/(e2e/run|shim/server)\.mjs" | grep -v grep | awk '{print $1}'); do kill "$p" 2>/dev/null; done
sleep 1
bash tests/e2e/setup.sh >/dev/null
rm -rf tests/e2e/out
node tests/e2e/run.mjs
