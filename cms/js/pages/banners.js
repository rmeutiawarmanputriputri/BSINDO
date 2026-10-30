import { h, clear, modal, toast, confirmDialog, badge, select, field, checkbox, loading, errorState, table, fmtDate } from '../ui.js';
import { sb, unwrap, rpc } from '../api.js';
import { mediaField, openPreview } from './media.js';

const TARGETS = [['none', 'Tanpa tautan'], ['route', 'Halaman aplikasi'], ['url', 'Tautan web (https)'],
  ['sign', 'Materi (ID)'], ['conversation', 'Topik percakapan (ID)'], ['category', 'Kategori (ID)']];
export const APP_ROUTES = [['/alphabet', 'Alfabet'], ['/numbers', 'Angka'], ['/vocabulary', 'Kosakata'], ['/conversations', 'Percakapan'],
  ['/quiz', 'Kuis'], ['/profile', 'Profil'], ['/premium', 'Info Premium'], ['/faq', 'FAQ']];

const toLocal = (v) => (v ? new Date(new Date(v).getTime() - new Date().getTimezoneOffset() * 60000).toISOString().slice(0, 16) : '');

export async function bannersPage(root) {
  const box = h('div');
  let rows = [];
  clear(root,
    h('div', { class: 'page-head' }, h('h1', {}, 'Banner Beranda'), h('span', { class: 'spacer' }),
      h('button', { class: 'btn', type: 'button', onclick: () => edit(null) }, '+ Tambah banner')),
    h('p', { class: 'muted' }, 'Banner aktif tampil di Beranda aplikasi sesuai urutan dan periode tayang.'), box);

  async function load() {
    clear(box, loading());
    try {
      rows = unwrap(await sb.from('banners').select('*').order('sort_order').order('created_at'));
      const now = Date.now();
      clear(box, table([
        { label: 'Urutan', render: (r, i) => h('div', { class: 'row', style: { gap: '2px' } },
          h('button', { class: 'btn ghost sm', type: 'button', 'aria-label': 'Naikkan', disabled: i === 0, onclick: () => move(i, -1) }, '↑'),
          h('button', { class: 'btn ghost sm', type: 'button', 'aria-label': 'Turunkan', disabled: i === rows.length - 1, onclick: () => move(i, 1) }, '↓')) },
        { label: 'Judul', render: (r) => h('div', {}, h('b', {}, r.title), h('div', { class: 'small muted' }, r.description || '')) },
        { label: 'Tujuan', render: (r) => (r.target_type === 'none' ? '—' : `${TARGETS.find((t) => t[0] === r.target_type)?.[1]}: ${r.target_value}`) },
        { label: 'Periode', render: (r) => h('span', { class: 'small' }, `${r.starts_at ? fmtDate(r.starts_at) : 'kapan saja'} → ${r.ends_at ? fmtDate(r.ends_at) : 'tanpa batas'}`) },
        { label: 'Status', render: (r) => {
          if (!r.is_active) return badge('Nonaktif', 'inactive');
          if (r.ends_at && new Date(r.ends_at).getTime() < now) return badge('Berakhir', 'expired');
          if (r.starts_at && new Date(r.starts_at).getTime() > now) return badge('Terjadwal', 'warn');
          return badge('Tayang', 'ok');
        } },
        { label: '', class: 'actions', render: (r) => h('div', { class: 'row' },
          r.image_asset_id ? h('button', { class: 'btn ghost sm', type: 'button', onclick: async () => {
            const m = unwrap(await sb.from('media_assets').select('*').eq('id', r.image_asset_id).single()); openPreview(m);
          } }, 'Gambar') : null,
          h('button', { class: 'btn secondary sm', type: 'button', onclick: () => edit(r) }, 'Ubah'),
          h('button', { class: 'btn ghost sm', type: 'button', style: { color: 'var(--error)' }, onclick: () => remove(r) }, 'Hapus')) },
      ], rows, { empty: 'Belum ada banner.' }));
    } catch (e) { clear(box, errorState(e.message, load)); }
  }
  async function move(i, d) {
    const ids = rows.map((r) => r.id); [ids[i], ids[i + d]] = [ids[i + d], ids[i]];
    try { await rpc('admin_reorder', { p_table: 'banners', p_ids: ids }); load(); } catch (e) { toast(e.message, 'error'); }
  }
  async function remove(r) {
    if (!(await confirmDialog({ title: 'Hapus banner', message: `Hapus banner "${r.title}"? Gambar tetap ada di Media.`, danger: true, confirmLabel: 'Hapus' }))) return;
    try { unwrap(await sb.from('banners').delete().eq('id', r.id)); toast('Banner dihapus.', 'ok'); load(); } catch (e) { toast(e.message, 'error'); }
  }

  function edit(r) {
    const title = h('input', { type: 'text', value: r?.title || '', maxlength: 120 });
    const desc = h('textarea', { maxlength: 300 }, r?.description || '');
    const img = mediaField('image', r?.image_asset_id);
    const ttype = select(TARGETS, r?.target_type || 'none');
    const tval = h('input', { type: 'text', value: r?.target_value || '', maxlength: 500 });
    const routeSel = select(APP_ROUTES, r?.target_value || '/alphabet');
    const tvalWrap = h('div');
    const renderTarget = () => {
      const t = ttype.value;
      clear(tvalWrap, t === 'none' ? null : t === 'route' ? field('Halaman', routeSel) : field(t === 'url' ? 'URL (https://…)' : 'ID (UUID)', tval));
    };
    ttype.addEventListener('change', renderTarget); renderTarget();
    const starts = h('input', { type: 'datetime-local', value: toLocal(r?.starts_at) });
    const ends = h('input', { type: 'datetime-local', value: toLocal(r?.ends_at) });
    const active = checkbox('Aktif (tayang)', r ? r.is_active : false);
    const order = h('input', { type: 'number', value: r?.sort_order ?? rows.length });
    const err = h('div');
    modal({
      title: r ? 'Ubah banner' : 'Tambah banner',
      body: h('div', { class: 'stack' }, err, h('div', { class: 'form-grid' },
        field('Judul', title, { required: true }), field('Urutan', order), field('Deskripsi', desc, { full: true }),
        field('Gambar banner', img.el, { required: true, full: true, help: 'Disarankan rasio 16:9 atau 2:1, maks sesuai batas gambar.' }),
        field('Tujuan saat diketuk', ttype), tvalWrap, field('Mulai tayang', starts), field('Selesai tayang', ends),
        h('div', { class: 'full' }, active.el))),
      actions: [{ label: 'Batal', onClick: (c) => c() }, { label: 'Simpan', kind: 'primary', onClick: async (c) => {
        const t = ttype.value;
        const v = { title: title.value.trim(), description: desc.value.trim() || null, image_asset_id: img.getValue(),
          target_type: t, target_value: t === 'none' ? null : t === 'route' ? routeSel.value : tval.value.trim() || null,
          starts_at: starts.value ? new Date(starts.value).toISOString() : null, ends_at: ends.value ? new Date(ends.value).toISOString() : null,
          is_active: active.input.checked, sort_order: parseInt(order.value, 10) || 0 };
        const problems = [];
        if (!v.title) problems.push('Judul wajib diisi.');
        if (v.is_active && !v.image_asset_id) problems.push('Banner aktif wajib memiliki gambar.');
        if (t === 'url' && !/^https:\/\//.test(v.target_value || '')) problems.push('URL harus diawali https://');
        if (['sign', 'conversation', 'category'].includes(t) && !/^[0-9a-f-]{36}$/i.test(v.target_value || '')) problems.push('ID harus UUID yang valid.');
        if (v.starts_at && v.ends_at && v.ends_at <= v.starts_at) problems.push('Waktu selesai harus setelah waktu mulai.');
        if (problems.length) { clear(err, h('div', { class: 'alert error' }, h('ul', {}, problems.map((p) => h('li', {}, p))))); return; }
        try {
          if (r) unwrap(await sb.from('banners').update(v).eq('id', r.id)); else unwrap(await sb.from('banners').insert(v));
          toast('Banner tersimpan.', 'ok'); c(); load();
        } catch (e) { clear(err, h('div', { class: 'alert error' }, e.message)); }
      } }],
    });
  }
  load();
}
