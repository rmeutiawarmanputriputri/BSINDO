// Uji E2E CMS: Chromium (Playwright) → supabase-js asli → emulator API → PostgreSQL
// dengan migrasi produksi (RLS/trigger/RPC asli).
//   PGHOST=/tmp PGPORT=5433 PGUSER=postgres bash tests/e2e/setup.sh
//   PGHOST=/tmp PGPORT=5433 PGUSER=postgres node tests/e2e/run.mjs
import { spawn } from 'node:child_process';
import path from 'node:path';
import fs from 'node:fs';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';
import pg from 'pg';

const require = createRequire(import.meta.url);
const { chromium } = require('playwright');
const HERE = path.dirname(fileURLToPath(import.meta.url));
const CMS = path.resolve(HERE, '../..');
const MEDIA = path.join(HERE, 'media');
const OUT = process.env.OUT || path.join(HERE, 'out');
fs.mkdirSync(OUT, { recursive: true });
const BASE = 'http://127.0.0.1:8088';
const db = new pg.Client({ host: process.env.PGHOST || '/tmp', port: Number(process.env.PGPORT || 5433), user: process.env.PGUSER || 'postgres', database: 'cms_e2e' });

const results = [];
async function step(id, name, fn) {
  const t0 = Date.now();
  // Tutup modal sisa langkah sebelumnya agar kegagalan tidak berantai.
  for (let i = 0; i < 3 && page && await page.locator('.modal-backdrop').count(); i++) await page.keyboard.press('Escape');
  try { await fn(); results.push({ id, name, ok: true, ms: Date.now() - t0 }); console.log(`LULUS ${id} ${name}`); }
  catch (e) {
    results.push({ id, name, ok: false, error: e.message.split('\n')[0] }); console.log(`GAGAL ${id} ${name}: ${e.message.split('\n')[0]}`);
    await page?.screenshot({ path: path.join(OUT, `FAIL_${id}.png`), fullPage: true }).catch(() => {});
  }
}
const assert = (c, m) => { if (!c) throw new Error(m); };
const q1 = async (sql, p = []) => (await db.query(sql, p)).rows[0];

let page;
const shim = spawn(process.execPath, [path.join(CMS, 'tests/shim/server.mjs')], {
  env: { ...process.env, STATIC_DIR: CMS, PGDATABASE: 'cms_e2e', FILES_DIR: path.join(OUT, 'files') }, stdio: ['ignore', 'pipe', 'pipe'],
});
shim.stderr.on('data', (d) => fs.appendFileSync(path.join(OUT, 'shim.err.log'), d));
await new Promise((r) => setTimeout(r, 1200));
await db.connect();

const browser = await chromium.launch();
const ctx = await browser.newContext({ viewport: { width: 1360, height: 900 }, acceptDownloads: true });
page = await ctx.newPage();
page.setDefaultTimeout(8000);
const consoleErrors = [];
page.on('console', (m) => { if (m.type() === 'error') consoleErrors.push(m.text()); });
page.on('pageerror', (e) => consoleErrors.push('pageerror: ' + e.message));
page.on('dialog', (d) => d.dismiss());

async function login(email, pass) {
  await page.goto(BASE + '/');
  await page.getByLabel('Email').fill(email);
  await page.getByLabel('Kata sandi').fill(pass);
  await page.getByRole('button', { name: 'Masuk' }).click();
}
const go = async (hash) => { await page.goto(`${BASE}/#/${hash}`); await page.waitForLoadState('networkidle'); };
const toastText = async () => (await page.locator('#toasts').innerText()).trim();
const modalEl = () => page.locator('.modal').last();

async function uploadVia(kindButtonText, file, title) {
  await page.getByRole('button', { name: kindButtonText }).click();
  await modalEl().locator('input[type=file]').setInputFiles(file);
  if (title) await modalEl().getByLabel(/Judul/).fill(title);
  await modalEl().getByRole('button', { name: 'Unggah & Simpan' }).click();
}

try {
  // -------------------------------------------------------------- akses
  await step('CMS-01', 'Pengguna biasa ditolak masuk CMS', async () => {
    await login('cms.user@test.local', 'User#12345');
    await page.getByText('Akun ini bukan admin aktif').waitFor({ timeout: 8000 });
  });
  await step('CMS-02', 'Kata sandi salah → pesan jelas', async () => {
    await login('cms.admin@test.local', 'salah');
    await page.getByText('Email atau kata sandi salah.').waitFor();
  });
  await step('CMS-03', 'Admin masuk → Dashboard dengan angka nyata', async () => {
    await login('cms.admin@test.local', 'Admin#12345');
    await page.getByRole('heading', { name: 'Dashboard' }).waitFor();
    const card = page.locator('.stat', { hasText: 'Total pengguna' });
    assert((await card.locator('.num').innerText()) === '2', 'total pengguna bukan 2');
    await page.screenshot({ path: path.join(OUT, '01_dashboard.png'), fullPage: true });
  });

  // -------------------------------------------------------------- media
  await step('CMS-10', 'Unggah video dengan progres + tersimpan di DB & Storage', async () => {
    await go('media');
    await uploadVia('+ Video', path.join(MEDIA, 'TEST_video_a.mp4'), 'TEST video A');
    await page.locator('#toasts', { hasText: 'Media berhasil diunggah' }).waitFor();
    const r = await q1(`select count(*)::int n, max(original_filename) f from media_assets where title = 'TEST video A'`);
    assert(r.n === 1 && r.f === 'TEST_video_a.mp4', 'baris media tidak ada');
    const o = await q1(`select count(*)::int n from storage.objects where name in (select path from media_assets where title = 'TEST video A')`);
    assert(o.n === 1, 'objek storage tidak ada');
  });
  await step('CMS-11', 'Unggah audio MP3 & dua gambar', async () => {
    await uploadVia('+ Audio', path.join(MEDIA, 'TEST_audio.mp3'), 'TEST audio');
    await page.locator('#toasts', { hasText: 'Media berhasil diunggah' }).last().waitFor();
    await page.waitForTimeout(300);
    await uploadVia('+ Gambar', path.join(MEDIA, 'TEST_image_1.png'), 'TEST gambar 1');
    await page.waitForTimeout(500);
    await uploadVia('+ Gambar', path.join(MEDIA, 'TEST_image_2.png'), 'TEST gambar 2');
    await page.waitForTimeout(800);
    const r = await q1(`select count(*) filter (where kind='audio')::int a, count(*) filter (where kind='image')::int i from media_assets`);
    assert(r.a === 1 && r.i === 2, `audio=${r.a} gambar=${r.i}`);
  });
  await step('CMS-12', 'Format tidak didukung (WAV) ditolak dengan pesan jelas', async () => {
    await page.getByRole('button', { name: '+ Audio' }).click();
    await modalEl().locator('input[type=file]').setInputFiles(path.join(MEDIA, 'TEST_audio.wav'));
    await modalEl().getByText('Format tidak didukung').waitFor();
    await modalEl().getByRole('button', { name: 'Batal' }).click();
  });
  await step('CMS-13', 'Batas ukuran dari Pengaturan ditegakkan (gambar 0 MB → tolak)', async () => {
    await db.query(`update app_settings set value = jsonb_set(value, '{image_max_mb}', '0.0001') where key = 'media_limits'`);
    await page.reload(); await page.waitForLoadState('networkidle');
    await page.getByRole('button', { name: '+ Gambar' }).click();
    await modalEl().locator('input[type=file]').setInputFiles(path.join(MEDIA, 'TEST_image_1.png'));
    await modalEl().getByText(/melebihi batas/).waitFor();
    await modalEl().getByRole('button', { name: 'Batal' }).click();
    await db.query(`update app_settings set value = jsonb_set(value, '{image_max_mb}', '5') where key = 'media_limits'`);
    await page.reload(); await page.waitForLoadState('networkidle');
  });

  // -------------------------------------------------------------- alfabet
  await step('CMS-20', 'Alfabet: publish tanpa video ditolak, kekurangan ditampilkan', async () => {
    await go('alphabet/new');
    await page.getByLabel('Huruf').fill('Q');
    await page.getByRole('button', { name: 'Simpan & Publikasikan' }).click();
    await page.getByText('Video gerakan wajib diunggah').waitFor();
    await page.getByText('Nama validator wajib diisi').waitFor();
    const r = await q1(`select status::text s from signs where symbol = 'Q'`);
    assert(r.s === 'draft', 'harus tersimpan draft');
    await page.screenshot({ path: path.join(OUT, '02_publish_blocked.png'), fullPage: true });
  });
  await step('CMS-21', 'Alfabet: pilih video dari Media + lengkapi → Published', async () => {
    const vid = page.locator('label.field', { hasText: 'Video gerakan' });
    await vid.getByRole('button', { name: 'Pilih' }).click();
    await modalEl().locator('.media-card', { hasText: 'TEST video A' }).click();
    await page.getByLabel('Sumber materi').fill('TEST sumber');
    await page.getByLabel('Divalidasi oleh').fill('TEST validator');
    await page.getByLabel('Tanggal verifikasi').fill('2026-10-30');
    await page.getByRole('button', { name: 'Simpan & Publikasikan' }).click();
    await page.getByRole('heading', { name: 'Alfabet', exact: true }).waitFor();
    const r = await q1(`select status::text s, video_asset_id is not null v from signs where symbol = 'Q'`);
    assert(r.s === 'published' && r.v, JSON.stringify(r));
    await page.screenshot({ path: path.join(OUT, '03_alphabet_list.png'), fullPage: true });
  });

  // -------------------------------------------------------------- kosakata
  await step('CMS-22', 'Kosakata: tambah dengan kategori, gambar panduan, audio', async () => {
    await go('vocabulary/new');
    await page.getByLabel('Nama materi / kosakata').fill('TEST_KATA');
    await page.getByLabel(/^Kategori/).selectOption({ label: 'Keluarga' });
    await page.getByLabel(/^Arti/).fill('TEST arti');
    for (const [label, title] of [['Video gerakan', 'TEST video A'], ['Gambar panduan visual gerakan', 'TEST gambar 1'], ['Audio / voice', 'TEST audio']]) {
      await page.locator('label.field', { hasText: label }).getByRole('button', { name: 'Pilih' }).click();
      await modalEl().locator('.media-card', { hasText: title }).click();
    }
    await page.getByLabel('Sumber materi').fill('TEST'); await page.getByLabel('Divalidasi oleh').fill('TEST');
    await page.getByLabel('Tanggal verifikasi').fill('2026-10-30');
    await page.getByRole('button', { name: 'Simpan & Publikasikan' }).click();
    await page.getByRole('heading', { name: 'Kosakata', exact: true }).waitFor();
    const r = await q1(`select s.status::text st, c.name, s.audio_asset_id is not null a, s.image_asset_id is not null i
                        from signs s join categories c on c.id = s.category_id where s.term = 'TEST_KATA'`);
    assert(r.st === 'published' && r.name === 'Keluarga' && r.a && r.i, JSON.stringify(r));
  });
  await step('CMS-23', 'Ubah status cepat dari daftar (Published → Archived)', async () => {
    const row = page.locator('tr', { hasText: 'TEST_KATA' });
    await row.getByLabel('Ubah status').selectOption('archived');
    await page.locator('#toasts', { hasText: 'Status diubah' }).waitFor();
    assert((await q1(`select status::text s from signs where term='TEST_KATA'`)).s === 'archived', 'status');
    await row.getByLabel('Ubah status').selectOption('published');
    await page.waitForTimeout(600);
  });

  // -------------------------------------------------------------- angka
  await step('CMS-24', 'Angka: tanpa kelompok → kekurangan ditampilkan', async () => {
    await go('numbers/new');
    await page.getByLabel(/^Angka/).fill('7');
    await page.getByRole('button', { name: 'Simpan & Publikasikan' }).click();
    await page.getByText('Kelompok angka wajib dipilih').waitFor();
  });

  // -------------------------------------------------------------- percakapan
  await step('CMS-30', 'Percakapan: topik + 2 kalimat, urutan ditukar, tersimpan', async () => {
    await go('conversations/new');
    await page.getByLabel('Judul topik').fill('TEST Topik');
    await page.getByRole('button', { name: '+ Tambah kalimat' }).click();
    await page.getByRole('button', { name: '+ Tambah kalimat' }).click();
    const items = page.locator('.list-editor .item');
    await items.nth(0).getByLabel('Kalimat (bahasa Indonesia)').fill('TEST kalimat satu');
    await items.nth(1).getByLabel('Kalimat (bahasa Indonesia)').fill('TEST kalimat dua');
    await items.nth(1).getByLabel('Pembicara').fill('B');
    await items.nth(1).getByRole('button', { name: 'Naikkan' }).click();
    for (const i of [0, 1]) {
      await page.locator('.list-editor .item').nth(i).locator('label.field', { hasText: 'Video kalimat' }).getByRole('button', { name: 'Pilih' }).click();
      await modalEl().locator('.media-card', { hasText: 'TEST video A' }).click();
    }
    await page.locator('.list-editor .item').nth(0).locator('label.field', { hasText: 'Audio' }).getByRole('button', { name: 'Pilih' }).click();
    await modalEl().locator('.media-card', { hasText: 'TEST audio' }).click();
    await page.getByRole('button', { name: 'Simpan & Publikasikan' }).click();
    await page.getByText('Nama validator wajib diisi').waitFor();
    const rows = (await db.query(`select i.position, i.text_id, i.speaker_label, i.audio_asset_id is not null a from conversation_items i
                                  join conversation_modules m on m.id = i.module_id where m.title = 'TEST Topik' order by position`)).rows;
    assert(rows.length === 2 && rows[0].text_id === 'TEST kalimat dua' && rows[0].speaker_label === 'B' && rows[0].a, JSON.stringify(rows));
    await page.screenshot({ path: path.join(OUT, '04_conversation.png'), fullPage: true });
  });
  await step('CMS-31', 'Percakapan: lengkapi validasi → Published', async () => {
    await page.getByLabel('Sumber materi').fill('TEST'); await page.getByLabel('Divalidasi oleh').fill('TEST');
    await page.getByLabel('Tanggal verifikasi').fill('2026-10-30');
    await page.getByRole('button', { name: 'Simpan & Publikasikan' }).click();
    await page.getByRole('heading', { name: 'Percakapan', exact: true }).waitFor();
    assert((await q1(`select status::text s from conversation_modules where title='TEST Topik'`)).s === 'published', 'status');
  });

  // -------------------------------------------------------------- kuis
  await step('CMS-40', 'Kuis: pilihan ganda tebak huruf → Published, kunci tersimpan', async () => {
    await go('quiz/new');
    await page.getByLabel('Jenis soal').selectOption('guess_letter');
    await page.getByLabel('Modul').selectOption('alphabet');
    await page.getByLabel('Pertanyaan').fill('TEST huruf apa ini?');
    await page.locator('label.field', { hasText: 'Video soal' }).getByRole('button', { name: 'Pilih' }).click();
    await modalEl().locator('.media-card', { hasText: 'TEST video A' }).click();
    await page.getByLabel('Pilihan 1').fill('TEST_P'); await page.getByLabel('Pilihan 2').fill('TEST_Q');
    await page.locator('.list-editor .item').nth(1).getByLabel('Jawaban benar').check();
    await page.getByLabel('Pembahasan').fill('TEST pembahasan');
    await page.getByRole('button', { name: 'Simpan & Publikasikan' }).click();
    await page.getByRole('heading', { name: 'Kuis', exact: true }).waitFor();
    const r = await q1(`select q.status::text s, o.label from questions q join question_answer_keys k on k.question_id = q.id
                        join question_options o on o.id = k.correct_option_id where q.prompt = 'TEST huruf apa ini?'`);
    assert(r && r.s === 'published' && r.label === 'TEST_Q', JSON.stringify(r));
  });
  await step('CMS-41', 'Kuis: susun kata & cocokkan gambar tersimpan', async () => {
    await go('quiz/new');
    await page.getByLabel('Jenis soal').selectOption('arrange_word');
    await page.getByLabel('Pertanyaan').fill('TEST susun');
    await page.getByLabel('Ubin 1', { exact: true }).fill('M'); await page.getByLabel('Ubin 2', { exact: true }).fill('A');
    await page.getByRole('button', { name: 'Simpan & Publikasikan' }).click();
    await page.getByRole('heading', { name: 'Kuis', exact: true }).waitFor();
    await go('quiz/new');
    await page.getByLabel('Jenis soal').selectOption('match_image');
    await page.getByLabel('Pertanyaan').fill('TEST cocokkan');
    const items = page.locator('.list-editor .item');
    for (const [i, img, arti] of [[0, 'TEST gambar 1', 'TEST satu'], [1, 'TEST gambar 2', 'TEST dua']]) {
      await items.nth(i).getByRole('button', { name: 'Pilih' }).click();
      await modalEl().locator('.media-card', { hasText: img }).click();
      await items.nth(i).getByLabel('Arti').fill(arti);
    }
    await page.getByRole('button', { name: 'Simpan & Publikasikan' }).click();
    await page.getByRole('heading', { name: 'Kuis', exact: true }).waitFor();
    const r = (await db.query(`select q.prompt, q.status::text s, k.correct_sequence is not null seq, k.pairs is not null pairs
                               from questions q join question_answer_keys k on k.question_id = q.id where q.prompt in ('TEST susun','TEST cocokkan') order by 1`)).rows;
    assert(r.length === 2 && r.every((x) => x.s === 'published') && r[0].pairs && r[1].seq, JSON.stringify(r));
  });

  // -------------------------------------------------------------- media dipakai
  await step('CMS-50', 'Hapus media yang dipakai → peringatan + daftar pemakaian; batal', async () => {
    await go('media');
    const card = page.locator('.media-card', { hasText: 'TEST video A' });
    await card.getByRole('button', { name: 'Hapus', exact: true }).click();
    await modalEl().getByText(/masih dipakai/).waitFor();
    await modalEl().getByText('TEST_KATA').waitFor();
    await page.screenshot({ path: path.join(OUT, '05_media_in_use.png') });
    await modalEl().getByRole('button', { name: 'Batal' }).click();
  });
  await step('CMS-51', 'Paksa hapus media wajib materi Published → server menolak, data utuh', async () => {
    const card = page.locator('.media-card', { hasText: 'TEST video A' });
    await card.getByRole('button', { name: 'Hapus', exact: true }).click();
    await modalEl().getByRole('button', { name: 'Tetap hapus' }).click();
    await page.locator('#toasts', { hasText: 'Belum bisa dipublikasikan' }).waitFor();
    assert((await q1(`select count(*)::int n from media_assets where title='TEST video A'`)).n === 1, 'media terhapus!');
  });
  await step('CMS-52', 'Ganti berkas video: id tetap, berkas lama dihapus', async () => {
    const before = await q1(`select id, path from media_assets where title='TEST video A'`);
    await page.locator('.media-card', { hasText: 'TEST video A' }).getByRole('button', { name: 'Ganti' }).click();
    await modalEl().getByText(/SEMUA/).waitFor();
    await modalEl().locator('input[type=file]').setInputFiles(path.join(MEDIA, 'TEST_video_b.mp4'));
    await modalEl().getByRole('button', { name: 'Ganti berkas' }).click();
    await page.locator('#toasts', { hasText: 'Berkas diganti.' }).waitFor();
    const after = await q1(`select id, path, original_filename from media_assets where title='TEST video A'`);
    const old = await q1(`select count(*)::int n from storage.objects where name = $1`, [before.path]);
    assert(after.id === before.id && after.path !== before.path && after.original_filename === 'TEST_video_b.mp4' && old.n === 0, JSON.stringify({ before, after, old }));
  });
  await step('CMS-53', 'Hapus media tak terpakai → baris & berkas hilang', async () => {
    await uploadVia('+ Gambar', path.join(MEDIA, 'TEST_image_2.png'), 'TEST hapus saya');
    await page.locator('#toasts', { hasText: 'Media berhasil diunggah' }).last().waitFor();
    await page.waitForTimeout(500);
    const p = (await q1(`select path from media_assets where title='TEST hapus saya'`)).path;
    await page.locator('.media-card', { hasText: 'TEST hapus saya' }).getByRole('button', { name: 'Hapus', exact: true }).click();
    await modalEl().getByRole('button', { name: 'Hapus', exact: true }).click();
    await page.locator('#toasts', { hasText: 'Media dihapus.' }).waitFor();
    const r = await q1(`select (select count(*) from media_assets where title='TEST hapus saya')::int m, (select count(*) from storage.objects where name=$1)::int o`, [p]);
    assert(r.m === 0 && r.o === 0, JSON.stringify(r));
  });
  await step('CMS-54', 'Pratinjau media (signed URL) terbuka', async () => {
    await page.locator('.media-card', { hasText: 'TEST gambar 1' }).getByRole('button', { name: 'Putar' }).click();
    await modalEl().locator('img').waitFor();
    const src = await modalEl().locator('img').getAttribute('src');
    assert(src.includes('/storage/v1/object/sign/'), src);
    const ok = await page.evaluate(async (u) => (await fetch(u)).status, src);
    assert(ok === 200, `HTTP ${ok}`);
    await modalEl().getByRole('button', { name: 'Tutup' }).click();
  });

  // -------------------------------------------------------------- impor
  await step('CMS-60', 'Impor CSV (titik koma): pratinjau → validasi → impor sebagai Draft', async () => {
    const csv = path.join(OUT, 'TEST_import.csv');
    fs.writeFileSync(csv, '﻿term;category;meaning;video_file\r\nTEST_IMP_1;keluarga;"TEST arti; dengan titik koma";TEST_video_b.mp4\r\nTEST_IMP_2;tidak-ada;x;\r\nTEST_IMP_3;Warna;y;belum.mp4\r\n');
    await go('import');
    await page.getByLabel('Berkas CSV / JSON').setInputFiles(csv);
    await page.getByText('3 baris').waitFor();
    await page.getByRole('button', { name: '1. Validasi (tanpa menyimpan)' }).click();
    await page.getByText('2 baris siap diimpor, 1 baris bermasalah').waitFor();
    await page.getByText('Kategori "tidak-ada" tidak ditemukan').waitFor();
    assert((await q1(`select count(*)::int n from signs where term like 'TEST_IMP%'`)).n === 0, 'dry run menyimpan data');
    await page.getByRole('button', { name: '2. Impor sebagai Draft' }).click();
    await page.getByText('Impor selesai: 2 baris').waitFor();
    const r = (await db.query(`select term, status::text s, meaning, video_asset_id is not null v from signs where term like 'TEST_IMP%' order by term`)).rows;
    assert(r.length === 2 && r.every((x) => x.s === 'draft') && r[0].meaning === 'TEST arti; dengan titik koma' && r[0].v && !r[1].v, JSON.stringify(r));
    await page.screenshot({ path: path.join(OUT, '06_import.png'), fullPage: true });
  });
  await step('CMS-61', 'Template impor kosong dapat diunduh (header saja)', async () => {
    const [dl] = await Promise.all([page.waitForEvent('download'), page.getByRole('button', { name: 'Unduh template CSV (kosong)' }).click()]);
    const txt = fs.readFileSync(await dl.path(), 'utf8').replace(/^﻿/, '').trim();
    assert(txt.split('\n').length === 1 && txt.startsWith('term,category'), txt);
  });

  // -------------------------------------------------------------- kategori
  await step('CMS-70', 'Kategori: tambah, ubah urutan, nonaktifkan', async () => {
    await go('categories');
    await page.getByRole('button', { name: '+ Tambah kategori' }).click();
    await modalEl().getByLabel(/^Nama/).fill('TEST Kategori Baru');
    await modalEl().getByRole('button', { name: 'Simpan' }).click();
    await page.locator('tr', { hasText: 'TEST Kategori Baru' }).waitFor();
    assert((await q1(`select slug from categories where name='TEST Kategori Baru'`)).slug === 'test-kategori-baru', 'slug');
    await page.locator('tr', { hasText: 'TEST Kategori Baru' }).getByRole('button', { name: 'Nonaktifkan' }).click();
    await page.waitForTimeout(500);
    assert(!(await q1(`select is_active from categories where name='TEST Kategori Baru'`)).is_active, 'aktif');
    const before = await q1(`select id from categories where kind='sign' order by sort_order, name limit 1`);
    await page.locator('tbody tr').nth(0).getByRole('button', { name: 'Turunkan' }).click();
    await page.waitForTimeout(600);
    const after = await q1(`select id from categories where kind='sign' order by sort_order, name limit 1`);
    assert(before.id !== after.id, 'urutan tidak berubah');
  });

  // -------------------------------------------------------------- pengguna & premium
  await step('CMS-80', 'Pengguna: detail + set Premium manual', async () => {
    await go('users');
    await page.locator('tr', { hasText: 'cms.user@test.local' }).getByRole('button', { name: 'Detail' }).click();
    await modalEl().getByLabel('Premium aktif').check();
    await modalEl().getByLabel('Paket').fill('TEST paket');
    await modalEl().getByRole('button', { name: 'Simpan Premium' }).click();
    await page.locator('#toasts', { hasText: 'Status Premium disimpan' }).waitFor();
    const r = await q1(`select has_premium('a0000000-0000-4000-8000-0000000000b1') p`);
    assert(r.p === true, 'premium tidak aktif');
    await page.locator('tr', { hasText: 'cms.user@test.local' }).getByText('Premium · TEST paket').waitFor();
  });
  await step('CMS-81', 'Admin tidak bisa menonaktifkan diri sendiri (tombol dinonaktifkan)', async () => {
    await page.locator('tr', { hasText: 'cms.admin@test.local' }).getByRole('button', { name: 'Detail' }).click();
    assert(await modalEl().getByRole('button', { name: 'Nonaktifkan akun' }).isDisabled(), 'tombol aktif');
    await modalEl().getByRole('button', { name: 'Tutup' }).click();
  });
  await step('CMS-82', 'Nonaktifkan pengguna → akun ditandai nonaktif', async () => {
    await page.locator('tr', { hasText: 'cms.user@test.local' }).getByRole('button', { name: 'Detail' }).click();
    await modalEl().getByRole('button', { name: 'Nonaktifkan akun' }).click();
    await page.locator('.modal').last().getByRole('button', { name: 'Ya, lanjutkan' }).click();
    await page.locator('#toasts', { hasText: 'Status akun diubah' }).waitFor();
    assert((await q1(`select is_active from profiles where id='a0000000-0000-4000-8000-0000000000b1'`)).is_active === false, 'masih aktif');
    await db.query(`update profiles set is_active = true where id='a0000000-0000-4000-8000-0000000000b1'`);
  });
  await step('CMS-83', 'Premium: info paket tersimpan; konten Premium terdaftar', async () => {
    await go('premium');
    await page.getByLabel('Judul').fill('TEST judul premium');
    await page.getByRole('button', { name: '+ Paket' }).click();
    await page.getByLabel('Nama paket').fill('TEST paket bulanan');
    await page.getByRole('button', { name: 'Simpan informasi' }).click();
    await page.locator('#toasts', { hasText: 'Informasi Premium disimpan' }).waitFor();
    const r = await q1(`select value from app_settings where key='premium_info'`);
    assert(r.value.title === 'TEST judul premium' && r.value.plans[0].name === 'TEST paket bulanan', JSON.stringify(r.value));
  });

  // -------------------------------------------------------------- banner, pengumuman, FAQ
  await step('CMS-90', 'Banner: aktif tanpa gambar ditolak; dengan gambar tersimpan', async () => {
    await go('banners');
    await page.getByRole('button', { name: '+ Tambah banner' }).click();
    await modalEl().getByLabel('Judul').fill('TEST banner');
    await modalEl().getByLabel('Aktif (tayang)').check();
    await modalEl().getByRole('button', { name: 'Simpan' }).click();
    await modalEl().getByText('Banner aktif wajib memiliki gambar.').waitFor();
    await modalEl().locator('label.field', { hasText: 'Gambar banner' }).getByRole('button', { name: 'Pilih' }).click();
    await page.locator('.modal').last().locator('.media-card', { hasText: 'TEST gambar 2' }).click();
    await modalEl().getByLabel('Tujuan saat diketuk').selectOption('route');
    await modalEl().getByRole('button', { name: 'Simpan' }).click();
    await page.locator('tr', { hasText: 'TEST banner' }).getByText('Tayang').waitFor();
    const r = await q1(`select target_type, target_value, is_active from banners where title='TEST banner'`);
    assert(r.is_active && r.target_type === 'route' && r.target_value === '/alphabet', JSON.stringify(r));
  });
  await step('CMS-91', 'Pengumuman & FAQ dapat dibuat', async () => {
    await go('announcements');
    await page.getByRole('button', { name: '+ Tambah pengumuman' }).click();
    await modalEl().getByLabel('Judul').fill('TEST pengumuman'); await modalEl().getByLabel('Isi').fill('TEST isi');
    await modalEl().getByLabel('Terbitkan').check(); await modalEl().getByRole('button', { name: 'Simpan' }).click();
    await page.locator('tr', { hasText: 'TEST pengumuman' }).waitFor();
    await go('faqs');
    await page.getByRole('button', { name: '+ Tambah FAQ' }).click();
    await modalEl().getByLabel('Pertanyaan').fill('TEST tanya?'); await modalEl().getByLabel('Jawaban').fill('TEST jawab');
    await modalEl().getByRole('button', { name: 'Simpan' }).click();
    await page.locator('tr', { hasText: 'TEST tanya?' }).waitFor();
  });
  await step('CMS-92', 'Pengaturan batas media tersimpan', async () => {
    await go('settings');
    await page.getByLabel('Audio (MB)').fill('15');
    await page.getByRole('button', { name: 'Simpan', exact: true }).click();
    await page.locator('#toasts', { hasText: 'Batas media disimpan' }).waitFor();
    assert((await q1(`select (value->>'audio_max_mb')::int n from app_settings where key='media_limits'`)).n === 15, 'setting');
  });
  await step('CMS-93', 'Dashboard memperbarui angka setelah perubahan', async () => {
    await go('dashboard');
    const v = await page.locator('.stat', { hasText: 'Materi alfabet' }).locator('.num').innerText();
    const p = await page.locator('.stat', { hasText: 'Pengguna Premium' }).locator('.num').innerText();
    assert(v === '1' && p === '1', `alfabet=${v} premium=${p}`);
  });

  // -------------------------------------------------------------- responsif
  await step('CMS-95', 'Tampilan HP (390×844): menu lipat, tanpa scroll horizontal', async () => {
    await page.setViewportSize({ width: 390, height: 844 });
    await go('vocabulary');
    const overflow = await page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
    assert(overflow <= 0, `overflow ${overflow}px`);
    await page.getByRole('button', { name: 'Buka menu' }).click();
    await page.getByRole('link', { name: /Percakapan/ }).click();
    await page.getByRole('heading', { name: 'Percakapan', exact: true }).waitFor();
    await page.screenshot({ path: path.join(OUT, '07_mobile.png'), fullPage: true });
    await page.setViewportSize({ width: 1360, height: 900 });
  });

  // -------------------------------------------------------------- keamanan API
  await step('CMS-99', 'Token pengguna biasa ditolak di RPC admin & penulisan konten (API langsung)', async () => {
    const res = await page.evaluate(async () => {
      const t = await fetch('http://127.0.0.1:54321/auth/v1/token?grant_type=password', { method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: 'cms.user@test.local', password: 'User#12345' }) }).then((r) => r.json());
      const H = { Authorization: `Bearer ${t.access_token}`, 'Content-Type': 'application/json', Prefer: 'return=representation' };
      const a = await fetch('http://127.0.0.1:54321/rest/v1/rpc/admin_dashboard_stats', { method: 'POST', headers: H, body: '{}' });
      const b = await fetch('http://127.0.0.1:54321/rest/v1/signs', { method: 'POST', headers: H, body: JSON.stringify({ term: 'HACK' }) });
      const c = await fetch('http://127.0.0.1:54321/rest/v1/question_answer_keys?select=*', { headers: H }).then((r) => r.json());
      const d = await fetch('http://127.0.0.1:54321/storage/v1/object/bisindo-media/hack.mp4', { method: 'POST', headers: { ...H, 'Content-Type': 'video/mp4' }, body: 'x' });
      return { a: a.status, b: b.status, c: c.length, d: d.status };
    });
    assert(res.a === 403 && res.b === 403 && res.c === 0 && res.d === 403, JSON.stringify(res));
  });

  await step('CMS-100', 'Keluar', async () => {
    await page.getByRole('button', { name: 'Keluar' }).click();
    await page.getByRole('button', { name: 'Masuk' }).waitFor();
  });
} finally {
  const bad = consoleErrors.filter((e) => !/Failed to load resource: the server responded with a status of (40[0-9])/.test(e));
  results.push({ id: 'CMS-CON', name: 'Tidak ada error JavaScript di konsol', ok: bad.length === 0, error: bad.slice(0, 5).join(' | ') });
  console.log(`${bad.length ? 'GAGAL' : 'LULUS'} CMS-CON konsol: ${bad.length} error`);
  fs.writeFileSync(path.join(OUT, 'results.json'), JSON.stringify({ results, consoleErrors }, null, 2));
  const fail = results.filter((r) => !r.ok).length;
  console.log(`\nTOTAL ${results.length} uji, ${results.length - fail} LULUS, ${fail} GAGAL`);
  await browser.close(); await db.end(); shim.kill();
  process.exitCode = fail ? 1 : 0;
}
