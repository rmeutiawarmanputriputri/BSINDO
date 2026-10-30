import { h, clear, modal, toast, confirmDialog, badge, select, field, checkbox, loading, errorState, table } from '../ui.js';
import { sb, unwrap, rpc, invalidateCategories, slugify } from '../api.js';
import { mediaField } from './media.js';

const KIND = [['sign', 'Kosakata'], ['conversation', 'Percakapan']];

export async function categoriesPage(root) {
  let kind = 'sign';
  const box = h('div');
  clear(root,
    h('div', { class: 'page-head' }, h('h1', {}, 'Kategori'), h('span', { class: 'spacer' }),
      h('button', { class: 'btn', type: 'button', onclick: () => edit(null) }, '+ Tambah kategori')),
    h('div', { class: 'filters' }, select(KIND, kind, { 'aria-label': 'Jenis', onchange: (e) => { kind = e.target.value; load(); } })),
    box);

  let rows = [];
  async function load() {
    clear(box, loading());
    try {
      rows = unwrap(await sb.from('categories').select('id, slug, name, kind, description, icon_key, image_asset_id, sort_order, is_active').eq('kind', kind).order('sort_order').order('name'));
      const counts = {};
      const used = unwrap(await sb.from(kind === 'sign' ? 'signs' : 'conversation_modules').select('category_id').not('category_id', 'is', null));
      used.forEach((u) => { counts[u.category_id] = (counts[u.category_id] || 0) + 1; });
      clear(box, table([
        { label: 'Urutan', render: (r, i) => h('div', { class: 'row', style: { gap: '2px' } },
          h('button', { class: 'btn ghost sm', type: 'button', 'aria-label': 'Naikkan', disabled: i === 0, onclick: () => move(i, -1) }, '↑'),
          h('button', { class: 'btn ghost sm', type: 'button', 'aria-label': 'Turunkan', disabled: i === rows.length - 1, onclick: () => move(i, 1) }, '↓')) },
        { label: 'Nama', render: (r) => h('div', {}, h('b', {}, r.name), h('div', { class: 'small muted mono' }, r.slug)) },
        { label: 'Materi', render: (r) => String(counts[r.id] || 0) },
        { label: 'Status', render: (r) => (r.is_active ? badge('Aktif', 'ok') : badge('Nonaktif', 'inactive')) },
        { label: '', class: 'actions', render: (r) => h('div', { class: 'row' },
          h('button', { class: 'btn secondary sm', type: 'button', onclick: () => edit(r) }, 'Ubah'),
          h('button', { class: 'btn ghost sm', type: 'button', onclick: () => toggle(r) }, r.is_active ? 'Nonaktifkan' : 'Aktifkan'),
          h('button', { class: 'btn ghost sm', type: 'button', style: { color: 'var(--error)' }, onclick: () => remove(r, counts[r.id] || 0) }, 'Hapus')) },
      ], rows, { empty: 'Belum ada kategori.' }));
    } catch (e) { clear(box, errorState(e.message, load)); }
  }

  async function move(i, d) {
    const ids = rows.map((r) => r.id);
    [ids[i], ids[i + d]] = [ids[i + d], ids[i]];
    try { await rpc('admin_reorder', { p_table: 'categories', p_ids: ids }); invalidateCategories(); load(); } catch (e) { toast(e.message, 'error'); }
  }
  async function toggle(r) {
    try { unwrap(await sb.from('categories').update({ is_active: !r.is_active }).eq('id', r.id)); invalidateCategories(); load(); } catch (e) { toast(e.message, 'error'); }
  }
  async function remove(r, n) {
    if (n > 0) { toast(`Kategori masih dipakai ${n} materi. Pindahkan materinya atau nonaktifkan kategori.`, 'error'); return; }
    if (!(await confirmDialog({ title: 'Hapus kategori', message: `Hapus kategori "${r.name}"?`, danger: true, confirmLabel: 'Hapus' }))) return;
    try { unwrap(await sb.from('categories').delete().eq('id', r.id)); invalidateCategories(); toast('Kategori dihapus.', 'ok'); load(); } catch (e) { toast(e.message, 'error'); }
  }

  function edit(r) {
    const name = h('input', { type: 'text', value: r?.name || '', maxlength: 80 });
    const slug = h('input', { type: 'text', value: r?.slug || '', maxlength: 80 });
    if (!r) name.addEventListener('input', () => { slug.value = slugify(name.value); });
    const k = select(KIND, r?.kind || kind);
    const desc = h('textarea', { maxlength: 500 }, r?.description || '');
    const icon = h('input', { type: 'text', value: r?.icon_key || '', maxlength: 60, placeholder: 'mis. family, school' });
    const order = h('input', { type: 'number', value: r?.sort_order ?? rows.length });
    const active = checkbox('Aktif', r ? r.is_active : true);
    const img = mediaField('image', r?.image_asset_id);
    const err = h('div');
    modal({
      title: r ? 'Ubah kategori' : 'Tambah kategori',
      body: h('div', { class: 'stack' }, err, h('div', { class: 'form-grid' },
        field('Nama', name, { required: true }), field('Slug', slug, { required: true, help: 'Huruf kecil & tanda hubung; dipakai saat impor CSV.' }),
        field('Jenis', k), field('Urutan', order), field('Deskripsi', desc, { full: true }),
        field('Kunci ikon', icon, { help: 'Nama ikon di aplikasi (opsional).' }), h('div', {}, active.el),
        field('Gambar / ikon', img.el, { full: true }))),
      actions: [{ label: 'Batal', onClick: (c) => c() }, { label: 'Simpan', kind: 'primary', onClick: async (c) => {
        const v = { name: name.value.trim(), slug: slug.value.trim(), kind: k.value, description: desc.value.trim() || null,
          icon_key: icon.value.trim() || null, sort_order: parseInt(order.value, 10) || 0, is_active: active.input.checked, image_asset_id: img.getValue() };
        if (!v.name || !/^[a-z0-9]+(-[a-z0-9]+)*$/.test(v.slug)) { clear(err, h('div', { class: 'alert error' }, 'Nama wajib diisi dan slug hanya huruf kecil, angka, tanda hubung.')); return; }
        try {
          if (r) unwrap(await sb.from('categories').update(v).eq('id', r.id)); else unwrap(await sb.from('categories').insert(v));
          invalidateCategories(); toast('Kategori tersimpan.', 'ok'); c(); load();
        } catch (e) { clear(err, h('div', { class: 'alert error' }, e.message)); }
      } }],
    });
  }
  load();
}
