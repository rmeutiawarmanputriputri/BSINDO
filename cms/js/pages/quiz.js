// Bank soal kuis (questions.quiz_id IS NULL). Kunci jawaban disimpan atomik
// lewat RPC admin_save_question; tidak pernah bisa dibaca pengguna biasa.
import { h, clear, toast, confirmDialog, fmtDate, statusBadge, badge, select, field, checkbox, loading,
  errorState, table, pager, debounce, issuesAlert, STATUS_OPTIONS } from '../ui.js';
import { sb, unwrap, rpc, getCategories, escapeLike, setContentStatus } from '../api.js';
import { mediaField } from './media.js';
import { statusMenu } from './signs.js';
import { navigate } from '../router.js';

export const QTYPES = [
  ['guess_letter', 'Tebak huruf'], ['guess_number', 'Tebak angka'], ['guess_sign', 'Tebak gerakan (video)'],
  ['multiple_choice', 'Pilihan ganda'], ['match_image', 'Cocokkan gambar & arti'], ['arrange_word', 'Susun kosakata'],
];
export const QMODULES = [['alphabet', 'Alfabet'], ['number', 'Angka'], ['vocabulary', 'Kosakata'], ['conversation', 'Percakapan'], ['general', 'Umum']];
export const DIFF = [['easy', 'Mudah'], ['medium', 'Sedang'], ['hard', 'Sulit']];
const L = (pairs) => Object.fromEntries(pairs);
const SINGLE = ['guess_letter', 'guess_number', 'guess_sign', 'multiple_choice'];

export async function quizListPage(root) {
  const state = { module: '', type: '', difficulty: '', status: '', q: '', page: 0, size: 25 };
  const cats = await getCategories(); const catName = Object.fromEntries(cats.map((c) => [c.id, c.name]));
  const box = h('div');
  const sel = (opts, key, label) => select([['', label], ...opts], '', { 'aria-label': label, onchange: (e) => { state[key] = e.target.value; state.page = 0; load(); } });
  clear(root,
    h('div', { class: 'page-head' }, h('h1', {}, 'Kuis'), h('span', { class: 'spacer' }),
      h('button', { class: 'btn', type: 'button', onclick: () => navigate('quiz/new') }, '+ Tambah soal')),
    h('p', { class: 'muted' }, 'Bank soal untuk kuis per kategori, kuis campuran, dan latihan materi yang belum dikuasai. Hanya soal Published & aktif yang muncul di aplikasi.'),
    h('div', { class: 'filters' }, sel(QMODULES, 'module', 'Semua modul'), sel(QTYPES, 'type', 'Semua jenis'), sel(DIFF, 'difficulty', 'Semua tingkat'),
      sel(STATUS_OPTIONS, 'status', 'Semua status'),
      h('input', { type: 'search', placeholder: 'Cari pertanyaan…', 'aria-label': 'Cari', oninput: debounce((e) => { state.q = e.target.value.trim(); state.page = 0; load(); }) })),
    box);

  async function load() {
    clear(box, loading());
    let q = sb.from('questions').select('id, module, category_id, question_type, prompt, difficulty, sort_order, status, is_active, is_premium, updated_at', { count: 'exact' })
      .is('quiz_id', null).order('module').order('sort_order').order('created_at')
      .range(state.page * state.size, state.page * state.size + state.size - 1);
    for (const k of ['module', 'difficulty', 'status']) if (state[k]) q = q.eq(k, state[k]);
    if (state.type) q = q.eq('question_type', state.type);
    if (state.q) q = q.ilike('prompt', `%${escapeLike(state.q)}%`);
    try {
      const { data, count } = unwrap(await q);
      clear(box, table([
        { label: 'Pertanyaan', render: (r) => h('div', {}, h('b', {}, r.prompt.length > 90 ? r.prompt.slice(0, 90) + '…' : r.prompt),
          h('div', { class: 'small muted' }, `${L(QMODULES)[r.module] || r.module}${r.category_id ? ' · ' + (catName[r.category_id] || '') : ''}`)) },
        { label: 'Jenis', render: (r) => L(QTYPES)[r.question_type] },
        { label: 'Tingkat', render: (r) => L(DIFF)[r.difficulty] },
        { label: 'Aktif', render: (r) => [r.is_active ? badge('Aktif', 'ok') : badge('Nonaktif', 'inactive'), r.is_premium ? [' ', badge('Premium', 'premium')] : null] },
        { label: 'Status', render: (r) => statusBadge(r.status) },
        { label: 'Diubah', render: (r) => h('span', { class: 'small muted' }, fmtDate(r.updated_at)) },
        { label: '', class: 'actions', render: (r) => h('div', { class: 'row' },
          h('button', { class: 'btn secondary sm', type: 'button', onclick: () => navigate(`quiz/${r.id}`) }, 'Ubah'),
          statusMenu(r, load, { type: 'question', table: 'questions' })) },
      ], data, { empty: 'Belum ada soal. Tambah atau impor dari CSV.' }),
      pager({ page: state.page, pageSize: state.size, total: count || 0, onPage: (p) => { state.page = p; load(); } }));
    } catch (e) { clear(box, errorState(e.message, load)); }
  }
  load();
}

export async function quizFormPage(root, id) {
  clear(root, loading());
  let q = { question_type: 'multiple_choice', module: 'vocabulary', difficulty: 'medium', status: 'draft', is_active: true, is_premium: false, sort_order: 0 };
  let opts = []; let key = null;
  try {
    if (id) {
      q = unwrap(await sb.from('questions').select('*').eq('id', id).single());
      opts = unwrap(await sb.from('question_options').select('id, position, label, image_asset_id, side').eq('question_id', id).order('position'));
      key = unwrap(await sb.from('question_answer_keys').select('*').eq('question_id', id).maybeSingle());
    }
  } catch (e) { clear(root, errorState(e.message, () => quizFormPage(root, id))); return; }
  const cats = await getCategories();

  const f = {
    question_type: select(QTYPES, q.question_type),
    module: select(QMODULES, q.module || 'general'),
    category_id: select([['', '— tanpa kategori —'], ...cats.map((c) => [c.id, `${c.name} (${c.kind === 'sign' ? 'kosakata' : 'percakapan'})`])], q.category_id || ''),
    difficulty: select(DIFF, q.difficulty),
    prompt: h('textarea', { maxlength: 500 }, q.prompt || ''),
    explanation: h('textarea', { maxlength: 2000 }, key?.explanation || ''),
    sort_order: h('input', { type: 'number', value: q.sort_order ?? 0 }),
  };
  const active = checkbox('Aktif', q.is_active);
  const premium = checkbox('Soal Premium', q.is_premium);
  const video = mediaField('video', q.video_asset_id);
  const image = mediaField('image', q.image_asset_id);
  const msg = h('div');

  // Status editor pilihan (bergantung jenis soal)
  let single = []; let correct = 0; let tiles = []; let pairs = [];
  const byId = Object.fromEntries(opts.map((o) => [o.id, o]));
  if (SINGLE.includes(q.question_type)) {
    single = opts.map((o) => ({ label: o.label, image: o.image_asset_id }));
    correct = Math.max(0, opts.findIndex((o) => o.id === key?.correct_option_id));
  } else if (q.question_type === 'arrange_word') {
    tiles = (key?.correct_sequence || []).map((oid) => byId[oid]?.label).filter(Boolean);
    if (!tiles.length) tiles = opts.map((o) => o.label);
  } else if (q.question_type === 'match_image') {
    pairs = (key?.pairs || []).map((p) => ({ image: byId[p.left]?.image_asset_id || null, meaning: byId[p.right]?.label || '' }));
  }
  if (!single.length) single = [{ label: '' }, { label: '' }];
  if (!pairs.length) pairs = [{ image: null, meaning: '' }, { image: null, meaning: '' }];
  if (!tiles.length) tiles = ['', ''];

  const editor = h('div', { class: 'list-editor' });
  const mediaHint = h('div', { class: 'help' });
  function renderEditor() {
    const t = f.question_type.value;
    mediaHint.textContent = t === 'guess_sign' ? 'Wajib: video gerakan yang ditebak (atau tautkan dari materi).'
      : (t === 'guess_letter' || t === 'guess_number') ? 'Wajib: video atau gambar huruf/angka yang ditebak.' : 'Opsional.';
    if (SINGLE.includes(t)) {
      clear(editor, h('p', { class: 'small muted' }, 'Tandai satu jawaban benar. Urutan pilihan diacak di aplikasi.'),
        single.map((o, i) => {
          const media = mediaField('image', o.image, { onChange: (v) => { o.image = v; } });
          return h('div', { class: 'item' }, h('div', { class: 'item-head' },
            h('label', { class: 'check' }, h('input', { type: 'radio', name: 'correct', checked: i === correct, onchange: () => { correct = i; } }), 'Jawaban benar'),
            h('span', { class: 'spacer' }),
            h('button', { class: 'btn ghost sm', type: 'button', disabled: single.length <= 2, onclick: () => { single.splice(i, 1); if (correct >= single.length) correct = 0; renderEditor(); } }, 'Hapus')),
          h('div', { class: 'form-grid' }, field(`Pilihan ${i + 1}`, h('input', { type: 'text', value: o.label, maxlength: 200, oninput: (e) => { o.label = e.target.value; } }), { required: true }),
            field('Gambar pilihan (opsional)', media.el)));
        }),
        h('button', { class: 'btn secondary', type: 'button', disabled: single.length >= 8, onclick: () => { single.push({ label: '' }); renderEditor(); } }, '+ Pilihan'));
    } else if (t === 'arrange_word') {
      clear(editor, h('p', { class: 'small muted' }, 'Isi ubin (huruf atau kata) sesuai URUTAN BENAR. Aplikasi mengacak ubin untuk pengguna.'),
        h('div', { class: 'row' }, tiles.map((tile, i) => h('div', { class: 'row', style: { gap: '4px' } },
          h('input', { type: 'text', value: tile, maxlength: 200, style: { width: '110px' }, 'aria-label': `Ubin ${i + 1}`, oninput: (e) => { tiles[i] = e.target.value; } }),
          h('button', { class: 'btn ghost sm', type: 'button', 'aria-label': `Hapus ubin ${i + 1}`, disabled: tiles.length <= 2, onclick: () => { tiles.splice(i, 1); renderEditor(); } }, '✕')))),
        h('button', { class: 'btn secondary', type: 'button', disabled: tiles.length >= 20, onclick: () => { tiles.push(''); renderEditor(); } }, '+ Ubin'));
    } else if (t === 'match_image') {
      clear(editor, h('p', { class: 'small muted' }, 'Setiap baris = satu pasangan benar (gambar ↔ arti). Aplikasi mengacak sisi arti.'),
        pairs.map((p, i) => {
          const media = mediaField('image', p.image, { onChange: (v) => { p.image = v; } });
          return h('div', { class: 'item' }, h('div', { class: 'item-head' }, h('b', {}, `Pasangan ${i + 1}`), h('span', { class: 'spacer' }),
            h('button', { class: 'btn ghost sm', type: 'button', disabled: pairs.length <= 2, onclick: () => { pairs.splice(i, 1); renderEditor(); } }, 'Hapus')),
          h('div', { class: 'form-grid' }, field('Gambar', media.el, { required: true }),
            field('Arti', h('input', { type: 'text', value: p.meaning, maxlength: 200, oninput: (e) => { p.meaning = e.target.value; } }), { required: true })));
        }),
        h('button', { class: 'btn secondary', type: 'button', disabled: pairs.length >= 8, onclick: () => { pairs.push({ image: null, meaning: '' }); renderEditor(); } }, '+ Pasangan'));
    }
  }
  f.question_type.addEventListener('change', renderEditor);
  renderEditor();

  function payload(status) {
    const t = f.question_type.value;
    const base = {
      id: id || null, module: f.module.value, category_id: f.category_id.value || null, question_type: t,
      prompt: f.prompt.value.trim(), difficulty: f.difficulty.value, sort_order: parseInt(f.sort_order.value, 10) || 0,
      is_active: active.input.checked, is_premium: premium.input.checked, status,
      sign_id: q.sign_id || null, video_asset_id: video.getValue(), image_asset_id: image.getValue(),
      explanation: f.explanation.value.trim(),
    };
    if (SINGLE.includes(t)) return { ...base, options: single.map((o) => ({ label: o.label.trim(), image_asset_id: o.image || null })), correct_index: correct };
    if (t === 'arrange_word') return { ...base, options: tiles.map((x) => ({ label: x.trim() })), correct_sequence: tiles.map((_, i) => i) };
    return {
      ...base,
      options: pairs.flatMap((p, i) => [{ label: `Gambar ${i + 1}`, side: 'left', image_asset_id: p.image || null }, { label: p.meaning.trim(), side: 'right' }]),
      pairs: pairs.map((_, i) => ({ left: i * 2, right: i * 2 + 1 })),
    };
  }
  function localErrors(p) {
    const e = [];
    if (!p.prompt) e.push('Pertanyaan wajib diisi.');
    if (p.options.some((o) => !o.label)) e.push('Semua pilihan/ubin/arti wajib diisi.');
    return e;
  }

  async function save(status) {
    clear(msg);
    // "Simpan" mempertahankan status saat ini (server memvalidasi ulang bila Published);
    // "Publikasikan" menyimpan sebagai Draft dulu lalu memeriksa kelengkapan.
    const p = payload(status === 'published' ? 'draft' : (q.status || 'draft'));
    const errs = localErrors(p);
    if (errs.length) { clear(msg, h('div', { class: 'alert error' }, h('ul', {}, errs.map((x) => h('li', {}, x))))); return; }
    try {
      const qid = await rpc('admin_save_question', { p });
      if (status === 'published') {
        const issues = await setContentStatus('question', 'questions', qid, 'published');
        if (issues.length) { navigate(`quiz/${qid}`, { flash: issuesAlert(issues, 'Tersimpan sebagai Draft. Belum bisa dipublikasikan — yang masih kurang:') }); return; }
        toast('Soal dipublikasikan.', 'ok');
      } else toast('Soal tersimpan.', 'ok');
      navigate('quiz');
    } catch (e) { clear(msg, h('div', { class: 'alert error', role: 'alert' }, e.message)); }
  }

  async function remove() {
    if (!(await confirmDialog({ title: 'Hapus soal', message: 'Hapus soal ini permanen? Riwayat kuis pengguna tetap tersimpan.', danger: true, confirmLabel: 'Hapus' }))) return;
    try { unwrap(await sb.from('questions').delete().eq('id', id)); toast('Soal dihapus.', 'ok'); navigate('quiz'); } catch (e) { toast(e.message, 'error'); }
  }

  clear(root,
    h('div', { class: 'page-head' }, h('button', { class: 'btn ghost', type: 'button', onclick: () => navigate('quiz') }, '‹ Kembali'),
      h('h1', {}, id ? 'Ubah soal' : 'Tambah soal'), id ? statusBadge(q.status) : null),
    q.quiz_id ? h('div', { class: 'alert info' }, 'Soal ini milik kuis pelajaran (aplikasi lama) dan hanya mendukung pilihan ganda.') : null,
    msg,
    h('form', { class: 'stack', onsubmit: (e) => { e.preventDefault(); save(null); } },
      h('div', { class: 'card' }, h('div', { class: 'form-grid' },
        field('Jenis soal', f.question_type, { required: true }), field('Modul', f.module, { required: true }),
        field('Kategori', f.category_id, { help: 'Untuk kuis per kategori.' }), field('Tingkat kesulitan', f.difficulty),
        field('Pertanyaan', f.prompt, { required: true, full: true }),
        h('div', { class: 'full' }, field('Video soal', video.el), mediaHint),
        field('Gambar soal', image.el, { full: true }),
        field('Urutan', f.sort_order), h('div', { class: 'stack' }, active.el, premium.el))),
      h('div', { class: 'card' }, h('h2', {}, 'Jawaban'), editor),
      h('div', { class: 'card' }, field('Pembahasan', f.explanation, { help: 'Ditampilkan setelah pengguna menjawab.' })),
      h('div', { class: 'form-actions' },
        id ? h('button', { class: 'btn danger', type: 'button', onclick: remove, style: { marginRight: 'auto' } }, 'Hapus') : null,
        h('button', { class: 'btn secondary', type: 'submit' }, q.status === 'published' ? 'Simpan perubahan' : 'Simpan sebagai Draft'),
        q.status !== 'published' ? h('button', { class: 'btn success', type: 'button', onclick: () => save('published') }, 'Simpan & Publikasikan') : null)));
}
