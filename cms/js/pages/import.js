// Impor massal CSV/JSON → semua baris masuk sebagai DRAFT.
// Alur: pilih jenis → pilih berkas → pratinjau → Validasi (dry run di server) → Impor.
import { h, clear, toast, select, field, table, loading, badge } from '../ui.js';
import { rpc } from '../api.js';
import { csvToObjects, toCsv } from '../csv.js';

export const IMPORT_KINDS = {
  vocabulary: { label: 'Kosakata', required: ['term', 'category'],
    columns: ['term', 'category', 'entry_type', 'meaning', 'movement_description', 'usage_example', 'video_file', 'image_file', 'audio_file', 'thumbnail_file', 'source_note', 'validated_by', 'verified_at', 'sort_order', 'is_premium'] },
  alphabet: { label: 'Alfabet', required: ['symbol'],
    columns: ['symbol', 'term', 'meaning', 'movement_description', 'video_file', 'image_file', 'audio_file', 'thumbnail_file', 'source_note', 'validated_by', 'verified_at', 'sort_order', 'is_premium'] },
  number: { label: 'Angka', required: ['symbol', 'number_group'],
    columns: ['symbol', 'number_group', 'term', 'meaning', 'movement_description', 'video_file', 'image_file', 'audio_file', 'thumbnail_file', 'source_note', 'validated_by', 'verified_at', 'sort_order', 'is_premium'] },
  conversation: { label: 'Percakapan', required: ['topic', 'text'],
    columns: ['topic', 'topic_description', 'category', 'position', 'speaker', 'text', 'translation', 'explanation', 'video_file', 'audio_file'] },
  quiz: { label: 'Soal kuis', required: ['module', 'question_type', 'prompt'],
    columns: ['module', 'category', 'question_type', 'prompt', 'options', 'correct', 'pairs', 'explanation', 'difficulty', 'video_file', 'image_file', 'sort_order', 'is_premium'] },
};

const HELP = {
  vocabulary: 'category = slug atau nama kategori kosakata. entry_type: word | phrase. verified_at: YYYY-MM-DD. is_premium: true | false.',
  alphabet: 'symbol = huruf. term opsional (default = huruf).',
  number: 'number_group: 0-9 | 10-20 | tens | 100+.',
  conversation: 'Baris dengan topic yang sama digabung menjadi satu topik (dibuat baru sebagai Draft bila belum ada). position mulai 1; kosong = ditambahkan di akhir.',
  quiz: 'module: alphabet | number | vocabulary | conversation | general. question_type: guess_letter | guess_number | guess_sign | multiple_choice | match_image | arrange_word. '
    + 'options dipisah "|" dan correct = teks atau nomor pilihan (1, 2, …). arrange_word: correct = ubin urutan benar dipisah "|". match_image: pairs = "gambar.png=Arti|…".',
};

export function importPage(root) {
  let kind = 'vocabulary'; let rows = []; let fileName = ''; let validated = null;
  const kindSel = select(Object.entries(IMPORT_KINDS).map(([k, v]) => [k, v.label]), kind, { onchange: (e) => { kind = e.target.value; reset(); renderHelp(); } });
  const fileIn = h('input', { type: 'file', accept: '.csv,.json,text/csv,application/json' });
  const helpBox = h('div', { class: 'alert info' });
  const previewBox = h('div'); const resultBox = h('div');
  const btnValidate = h('button', { class: 'btn secondary', type: 'button', disabled: true, onclick: () => run(true) }, '1. Validasi (tanpa menyimpan)');
  const btnImport = h('button', { class: 'btn success', type: 'button', disabled: true, onclick: () => run(false) }, '2. Impor sebagai Draft');

  function renderHelp() {
    const k = IMPORT_KINDS[kind];
    clear(helpBox, h('b', {}, `Kolom ${k.label}: `), k.columns.map((c, i) => [i ? ', ' : '', h('code', {}, c), k.required.includes(c) ? '*' : '']),
      h('div', { class: 'small', style: { marginTop: '6px' } }, HELP[kind]),
      h('div', { class: 'small', style: { marginTop: '6px' } }, 'Kolom *_file = nama berkas/judul media yang SUDAH diunggah di menu Media. Media yang belum ada → peringatan, materi tetap masuk sebagai Draft tanpa media.'),
      h('div', { class: 'row', style: { marginTop: '8px' } },
        h('button', { class: 'btn sm secondary', type: 'button', onclick: () => download(`template_${kind}.csv`, toCsv(k.columns), 'text/csv') }, 'Unduh template CSV (kosong)'),
        h('button', { class: 'btn sm secondary', type: 'button', onclick: () => download(`template_${kind}.json`, JSON.stringify([Object.fromEntries(k.columns.map((c) => [c, '']))], null, 2), 'application/json') }, 'Unduh template JSON (kosong)')));
  }
  function reset() { rows = []; validated = null; fileIn.value = ''; clear(previewBox); clear(resultBox); btnValidate.disabled = true; btnImport.disabled = true; }

  fileIn.addEventListener('change', async () => {
    clear(previewBox); clear(resultBox); validated = null; btnImport.disabled = true; rows = [];
    const f = fileIn.files[0]; if (!f) return;
    fileName = f.name;
    if (f.size > 5 * 1048576) { clear(previewBox, h('div', { class: 'alert error' }, 'Berkas lebih dari 5 MB. Pecah menjadi beberapa berkas.')); return; }
    try {
      const text = await f.text();
      let header;
      if (/\.json$/i.test(f.name) || /^\s*[[{]/.test(text)) {
        const data = JSON.parse(text);
        const arr = Array.isArray(data) ? data : data.rows;
        if (!Array.isArray(arr)) throw new Error('JSON harus berupa array objek atau { "rows": [...] }.');
        rows = arr.map((o) => Object.fromEntries(Object.entries(o || {}).map(([k, v]) => [k.toLowerCase(), v == null ? '' : String(v).trim()])));
        header = [...new Set(rows.flatMap((r) => Object.keys(r)))];
      } else {
        ({ header, rows } = csvToObjects(text));
      }
      rows = rows.filter((r) => Object.values(r).some((v) => v !== ''));
      const k = IMPORT_KINDS[kind];
      const unknown = header.filter((c) => !k.columns.includes(c));
      const missing = k.required.filter((c) => !header.includes(c));
      if (!rows.length) throw new Error('Tidak ada baris data (template kosong?).');
      if (rows.length > 2000) throw new Error(`Terlalu banyak baris (${rows.length}). Maksimum 2000 per impor.`);
      clear(previewBox,
        missing.length ? h('div', { class: 'alert error' }, `Kolom wajib tidak ada: ${missing.join(', ')}`) : null,
        unknown.length ? h('div', { class: 'alert warn' }, `Kolom tidak dikenal (diabaikan): ${unknown.join(', ')}`) : null,
        h('p', {}, h('b', {}, `${rows.length} baris`), ` dari ${fileName}. Pratinjau 20 baris pertama:`),
        table([{ label: '#', render: (_, i) => String(i + 1) }, ...k.columns.filter((c) => header.includes(c)).map((c) => ({
          label: c, render: (r) => h('span', { class: 'small' }, (r[c] || '').length > 60 ? r[c].slice(0, 60) + '…' : (r[c] || '')) }))], rows.slice(0, 20)));
      btnValidate.disabled = missing.length > 0;
    } catch (e) { clear(previewBox, h('div', { class: 'alert error' }, `Gagal membaca berkas: ${e.message}`)); }
  });

  async function run(dry) {
    clear(resultBox, loading(dry ? 'Memvalidasi di server…' : 'Mengimpor…'));
    btnValidate.disabled = true; btnImport.disabled = true;
    try {
      const k = IMPORT_KINDS[kind];
      const clean = rows.map((r) => Object.fromEntries(k.columns.filter((c) => r[c] !== undefined && r[c] !== '').map((c) => [c, r[c]])));
      const res = await rpc('admin_import', { p_kind: kind, p_rows: clean, p_dry_run: dry });
      if (dry) validated = res;
      const problems = res.results.filter((r) => !r.ok || (r.warnings || []).length);
      clear(resultBox,
        h('div', { class: `alert ${res.failed ? 'warn' : 'ok'}` },
          dry ? `Validasi: ${res.ok} baris siap diimpor, ${res.failed} baris bermasalah. Belum ada data yang disimpan.`
            : `Impor selesai: ${res.ok} baris tersimpan sebagai Draft, ${res.failed} baris gagal.`),
        problems.length ? table([
          { label: 'Baris', render: (r) => String(r.row) },
          { label: 'Hasil', render: (r) => (r.ok ? badge('OK', 'ok') : badge('Gagal', 'error')) },
          { label: 'Keterangan', render: (r) => h('div', {}, (r.errors || []).map((e) => h('div', { style: { color: 'var(--error)' } }, e)),
            (r.warnings || []).map((w) => h('div', { class: 'small muted' }, '⚠ ' + w))) },
        ], problems) : null);
      if (!dry) { toast(`${res.ok} baris diimpor sebagai Draft.`, 'ok'); rows = []; fileIn.value = ''; clear(previewBox); }
    } catch (e) { clear(resultBox, h('div', { class: 'alert error' }, e.message)); }
    btnValidate.disabled = !rows.length;
    btnImport.disabled = !(validated && validated.ok > 0 && rows.length);
  }

  renderHelp();
  clear(root,
    h('div', { class: 'page-head' }, h('h1', {}, 'Impor massal')),
    h('div', { class: 'card stack' },
      h('div', { class: 'form-grid' }, field('Jenis data', kindSel), field('Berkas CSV / JSON', fileIn)),
      helpBox, previewBox,
      h('div', { class: 'row' }, btnValidate, btnImport),
      h('p', { class: 'small muted' }, 'Semua data hasil impor berstatus Draft dan tidak tampil di aplikasi sampai Anda melengkapi & mempublikasikannya. Baris yang gagal tidak menggagalkan baris lain.'),
      resultBox));
}

function download(name, content, type) {
  // BOM hanya untuk CSV agar Excel membaca UTF-8 dengan benar.
  const url = URL.createObjectURL(new Blob([(type === 'text/csv' ? '﻿' : '') + content], { type: `${type};charset=utf-8` }));
  const a = h('a', { href: url, download: name });
  document.body.appendChild(a); a.click(); a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
