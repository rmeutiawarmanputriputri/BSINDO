// Alfabet, Angka, dan Kosakata — semuanya baris di tabel `signs`
// (dibedakan kolom content_module).
import { h, clear, modal, toast, confirmDialog, fmtDate, statusBadge, badge, select, field, checkbox, loading,
  errorState, table, pager, debounce, issuesAlert, STATUS_OPTIONS } from '../ui.js';
import { sb, unwrap, rpc, getCategories, escapeLike, setContentStatus } from '../api.js';
import { mediaField } from './media.js';
import { navigate } from '../router.js';

export const NUMBER_GROUPS = [['0-9', '0–9'], ['10-20', '10–20'], ['tens', 'Puluhan'], ['100+', '100 ke atas']];
const GROUP_LABEL = Object.fromEntries(NUMBER_GROUPS);

export const MODULES = {
  alphabet: { title: 'Alfabet', route: 'alphabet', noun: 'huruf', order: [['sort_order', true], ['symbol', true]] },
  number: { title: 'Angka', route: 'numbers', noun: 'angka', order: [['number_group', true], ['sort_order', true]] },
  vocabulary: { title: 'Kosakata', route: 'vocabulary', noun: 'kosakata', order: [['term_normalized', true]] },
};

const COLS = 'id, content_module, entry_type, category_id, term, symbol, number_group, meaning, movement_description, usage_example, '
  + 'video_asset_id, thumbnail_asset_id, image_asset_id, audio_asset_id, source_note, validated_by, verified_at, sort_order, is_premium, status, updated_at';

export async function signListPage(root, module) {
  const M = MODULES[module];
  const state = { status: '', category: '', group: '', q: '', page: 0, size: 25 };
  const cats = (await getCategories()).filter((c) => c.kind === 'sign');
  const catName = Object.fromEntries(cats.map((c) => [c.id, c.name]));
  const box = h('div');

  const filters = [
    select([['', 'Semua status'], ...STATUS_OPTIONS], '', { 'aria-label': 'Status', onchange: (e) => { state.status = e.target.value; state.page = 0; load(); } }),
  ];
  if (module === 'vocabulary') filters.push(select([['', 'Semua kategori'], ...cats.map((c) => [c.id, c.name + (c.is_active ? '' : ' (nonaktif)')])], '',
    { 'aria-label': 'Kategori', onchange: (e) => { state.category = e.target.value; state.page = 0; load(); } }));
  if (module === 'number') filters.push(select([['', 'Semua kelompok'], ...NUMBER_GROUPS], '',
    { 'aria-label': 'Kelompok', onchange: (e) => { state.group = e.target.value; state.page = 0; load(); } }));
  filters.push(h('input', { type: 'search', placeholder: `Cari ${M.noun}…`, 'aria-label': 'Cari', oninput: debounce((e) => { state.q = e.target.value.trim(); state.page = 0; load(); }) }));

  clear(root,
    h('div', { class: 'page-head' }, h('h1', {}, M.title), h('span', { class: 'spacer' }),
      h('button', { class: 'btn', type: 'button', onclick: () => navigate(`${M.route}/new`) }, `+ Tambah ${M.noun}`)),
    h('div', { class: 'filters' }, filters), box);

  async function load() {
    clear(box, loading());
    let q = sb.from('signs').select(COLS, { count: 'exact' }).eq('content_module', module)
      .range(state.page * state.size, state.page * state.size + state.size - 1);
    for (const [col, asc] of M.order) q = q.order(col, { ascending: asc });
    if (state.status) q = q.eq('status', state.status);
    if (state.category) q = q.eq('category_id', state.category);
    if (state.group) q = q.eq('number_group', state.group);
    if (state.q) { const s = escapeLike(state.q).replace(/[,()]/g, ' '); q = q.or(`term.ilike.%${s}%,symbol.ilike.%${s}%`); }
    try {
      const { data, count } = unwrap(await q);
      const cols = [];
      if (module !== 'vocabulary') cols.push({ label: module === 'alphabet' ? 'Huruf' : 'Angka', render: (r) => h('b', { style: { fontSize: '18px' } }, r.symbol || '—') });
      cols.push({ label: 'Judul', render: (r) => h('div', {}, h('b', {}, r.term), r.is_premium ? [' ', badge('Premium', 'premium')] : null) });
      if (module === 'vocabulary') cols.push({ label: 'Kategori', render: (r) => catName[r.category_id] || '—' });
      if (module === 'number') cols.push({ label: 'Kelompok', render: (r) => GROUP_LABEL[r.number_group] || '—' });
      cols.push({ label: 'Media', render: (r) => [r.video_asset_id ? '🎬' : h('span', { class: 'muted', title: 'Belum ada video' }, '— '), r.image_asset_id ? '🖼️' : '', r.audio_asset_id ? '🔊' : ''] });
      if (module !== 'vocabulary') cols.push({ label: 'Urutan', key: 'sort_order' });
      cols.push({ label: 'Status', render: (r) => statusBadge(r.status) });
      cols.push({ label: 'Diubah', render: (r) => h('span', { class: 'small muted' }, fmtDate(r.updated_at)) });
      cols.push({ label: '', class: 'actions', render: (r) => h('div', { class: 'row' },
        h('button', { class: 'btn secondary sm', type: 'button', onclick: () => navigate(`${M.route}/${r.id}`) }, 'Ubah'),
        statusMenu(r, load)) });
      clear(box, table(cols, data, { empty: `Belum ada ${M.noun}. Materi belum tersedia — tambah atau impor dari CSV.` }),
        pager({ page: state.page, pageSize: state.size, total: count || 0, onPage: (p) => { state.page = p; load(); } }));
    } catch (e) { clear(box, errorState(e.message, load)); }
  }
  load();
}

/** Tombol ubah status cepat (dengan validasi publish di server). */
export function statusMenu(row, reload, { type = 'sign', table: tbl = 'signs' } = {}) {
  const sel = select(STATUS_OPTIONS, row.status, { 'aria-label': 'Ubah status', class: 'btn sm secondary', style: { width: 'auto' } });
  sel.addEventListener('change', async () => {
    const target = sel.value;
    if (target === row.status) return;
    try {
      const issues = await setContentStatus(type, tbl, row.id, target);
      if (issues.length) {
        sel.value = row.status;
        modal({ title: 'Belum bisa dipublikasikan', body: issuesAlert(issues), actions: [{ label: 'Tutup', onClick: (c) => c() }] });
        return;
      }
      toast(`Status diubah ke ${target}.`, 'ok');
      reload();
    } catch (e) { sel.value = row.status; toast(e.message, 'error'); }
  });
  return sel;
}

// ------------------------------------------------------------------ form
export async function signFormPage(root, module, id) {
  const M = MODULES[module];
  clear(root, loading());
  let row = { content_module: module, entry_type: 'word', status: 'draft', is_premium: false, sort_order: 0 };
  try {
    if (id) row = unwrap(await sb.from('signs').select(COLS).eq('id', id).single());
  } catch (e) { clear(root, errorState(e.message, () => signFormPage(root, module, id))); return; }
  const cats = (await getCategories()).filter((c) => c.kind === 'sign');

  const f = {
    symbol: h('input', { type: 'text', value: row.symbol || '', maxlength: 16 }),
    term: h('input', { type: 'text', value: row.term || '', maxlength: 120 }),
    number_group: select([['', '— pilih —'], ...NUMBER_GROUPS], row.number_group || ''),
    category_id: select([['', '— pilih kategori —'], ...cats.map((c) => [c.id, c.name + (c.is_active ? '' : ' (nonaktif)')])], row.category_id || ''),
    entry_type: select([['word', 'Kata'], ['phrase', 'Frasa']], row.entry_type),
    meaning: h('textarea', { maxlength: 1000 }, row.meaning || ''),
    movement_description: h('textarea', { maxlength: 2000 }, row.movement_description || ''),
    usage_example: h('textarea', { maxlength: 500 }, row.usage_example || ''),
    sort_order: h('input', { type: 'number', value: row.sort_order ?? 0, step: 1 }),
    source_note: h('input', { type: 'text', value: row.source_note || '' }),
    validated_by: h('input', { type: 'text', value: row.validated_by || '' }),
    verified_at: h('input', { type: 'date', value: row.verified_at ? row.verified_at.slice(0, 10) : '' }),
  };
  const premium = checkbox('Konten Premium (hanya pengguna Premium yang bisa memutar medianya)', row.is_premium);
  const media = {
    video_asset_id: mediaField('video', row.video_asset_id),
    image_asset_id: mediaField('image', row.image_asset_id),
    audio_asset_id: mediaField('audio', row.audio_asset_id),
    thumbnail_asset_id: mediaField('image', row.thumbnail_asset_id),
  };
  const msg = h('div');
  if (module !== 'vocabulary') f.symbol.addEventListener('input', () => { if (!id && (!f.term.value || f.term.value === f.term.dataset.auto)) { f.term.value = f.symbol.value; f.term.dataset.auto = f.symbol.value; } });

  const fields = [];
  if (module === 'alphabet') fields.push(field('Huruf', f.symbol, { required: true, help: 'mis. A' }));
  if (module === 'number') fields.push(field('Angka', f.symbol, { required: true, help: 'mis. 7, 15, 30, 100' }), field('Kelompok', f.number_group, { required: true }));
  fields.push(field(module === 'vocabulary' ? 'Nama materi / kosakata' : 'Judul', f.term, { required: true }));
  if (module === 'vocabulary') fields.push(field('Kategori', f.category_id, { required: true }), field('Jenis', f.entry_type));
  fields.push(field(module === 'vocabulary' ? 'Arti' : 'Keterangan singkat', f.meaning, { required: module === 'vocabulary', full: true }));
  fields.push(field(module === 'vocabulary' ? 'Penjelasan gerakan' : 'Penjelasan gerakan tangan', f.movement_description, { full: true }));
  if (module === 'vocabulary') fields.push(field('Contoh penggunaan', f.usage_example, { full: true }));
  fields.push(field('Video gerakan', media.video_asset_id.el, { required: true, full: true, help: 'Wajib untuk dipublikasikan.' }));
  fields.push(field('Gambar panduan visual gerakan', media.image_asset_id.el, { full: true }));
  fields.push(field('Audio / voice', media.audio_asset_id.el, { full: true }));
  fields.push(field('Thumbnail', media.thumbnail_asset_id.el, { full: true }));
  if (module !== 'vocabulary') fields.push(field('Urutan tampil', f.sort_order, { help: 'Angka kecil tampil lebih dulu.' }));
  fields.push(h('div', { class: 'full' }, premium.el));
  fields.push(h('h3', { class: 'full', style: { marginTop: '8px' } }, 'Sumber & validasi (wajib untuk publikasi)'));
  fields.push(field('Sumber materi', f.source_note, { required: true }), field('Divalidasi oleh', f.validated_by, { required: true }));
  fields.push(field('Tanggal verifikasi', f.verified_at, { required: true }));

  const values = () => ({
    content_module: module,
    term: f.term.value.trim() || (module !== 'vocabulary' ? f.symbol.value.trim() : ''),
    symbol: module === 'vocabulary' ? null : (f.symbol.value.trim() || null),
    number_group: module === 'number' ? (f.number_group.value || null) : null,
    category_id: module === 'vocabulary' ? (f.category_id.value || null) : (row.category_id || null),
    entry_type: module === 'vocabulary' ? f.entry_type.value : (row.entry_type || 'word'),
    meaning: f.meaning.value.trim() || null,
    movement_description: f.movement_description.value.trim() || null,
    usage_example: module === 'vocabulary' ? (f.usage_example.value.trim() || null) : row.usage_example || null,
    sort_order: parseInt(f.sort_order.value, 10) || 0,
    is_premium: premium.input.checked,
    source_note: f.source_note.value.trim() || null,
    validated_by: f.validated_by.value.trim() || null,
    verified_at: f.verified_at.value || null,
    ...Object.fromEntries(Object.entries(media).map(([k, v]) => [k, v.getValue()])),
  });

  async function save(publish) {
    clear(msg);
    const v = values();
    if (!v.term) { clear(msg, h('div', { class: 'alert error' }, 'Judul wajib diisi.')); return; }
    if (module !== 'vocabulary' && !v.symbol) { clear(msg, h('div', { class: 'alert error' }, `${module === 'alphabet' ? 'Huruf' : 'Angka'} wajib diisi.`)); return; }
    try {
      // Bila materi sudah published, perubahan disimpan dengan status tetap (server menolak bila merusak).
      let savedId = id;
      if (id) unwrap(await sb.from('signs').update(v).eq('id', id));
      else savedId = unwrap(await sb.from('signs').insert({ ...v, status: 'draft' }).select('id').single()).id;
      if (publish) {
        const issues = await setContentStatus('sign', 'signs', savedId, 'published');
        if (issues.length) {
          const alert = issuesAlert(issues, 'Tersimpan sebagai Draft. Belum bisa dipublikasikan — yang masih kurang:');
          if (!id) navigate(`${M.route}/${savedId}`, { flash: alert });
          else clear(msg, alert);
          return;
        }
        toast('Tersimpan dan dipublikasikan.', 'ok');
      } else toast('Tersimpan.', 'ok');
      navigate(M.route);
    } catch (e) { clear(msg, h('div', { class: 'alert error', role: 'alert' }, e.message)); }
  }

  async function remove() {
    if (!(await confirmDialog({ title: `Hapus ${M.noun}`, message: `Hapus "${row.term}" permanen? Favorit & progres pengguna untuk materi ini ikut terhapus. Pertimbangkan status Archived/Inactive.`, danger: true, confirmLabel: 'Hapus' }))) return;
    try { unwrap(await sb.from('signs').delete().eq('id', id)); toast('Dihapus.', 'ok'); navigate(M.route); } catch (e) { toast(e.message, 'error'); }
  }

  const issuesBtn = id ? h('button', { class: 'btn ghost', type: 'button', onclick: async () => {
    try { const i = await rpc('publish_issues', { p_type: 'sign', p_id: id }); clear(msg, i.length ? issuesAlert(i, 'Kekurangan untuk publikasi (berdasarkan data tersimpan):') : h('div', { class: 'alert ok' }, 'Siap dipublikasikan.')); } catch (e) { toast(e.message, 'error'); }
  } }, 'Cek kelengkapan') : null;

  clear(root,
    h('div', { class: 'page-head' }, h('button', { class: 'btn ghost', type: 'button', onclick: () => navigate(M.route) }, '‹ Kembali'),
      h('h1', {}, id ? `Ubah ${M.noun}` : `Tambah ${M.noun}`), id ? statusBadge(row.status) : null),
    msg,
    h('form', { class: 'card', onsubmit: (e) => { e.preventDefault(); save(false); } },
      h('div', { class: 'form-grid' }, fields),
      h('div', { class: 'form-actions' },
        id ? h('button', { class: 'btn danger', type: 'button', onclick: remove, style: { marginRight: 'auto' } }, 'Hapus') : null,
        issuesBtn,
        h('button', { class: 'btn secondary', type: 'submit' }, row.status === 'published' ? 'Simpan perubahan' : 'Simpan sebagai Draft'),
        row.status !== 'published' ? h('button', { class: 'btn success', type: 'button', onclick: () => save(true) }, 'Simpan & Publikasikan') : null)));
}
