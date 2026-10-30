// Pengumuman (notifikasi dalam aplikasi) & FAQ — isi diketik pemilik.
import { h, clear, modal, toast, confirmDialog, badge, field, checkbox, loading, errorState, table, fmtDate } from '../ui.js';
import { sb, unwrap, rpc } from '../api.js';

export async function announcementsPage(root) {
  const box = h('div');
  clear(root,
    h('div', { class: 'page-head' }, h('h1', {}, 'Pengumuman'), h('span', { class: 'spacer' }),
      h('button', { class: 'btn', type: 'button', onclick: () => edit(null) }, '+ Tambah pengumuman')),
    h('p', { class: 'muted' }, 'Pengumuman yang dipublikasikan muncul di menu Notifikasi aplikasi.'), box);
  async function load() {
    clear(box, loading());
    try {
      const rows = unwrap(await sb.from('announcements').select('*').order('created_at', { ascending: false }));
      clear(box, table([
        { label: 'Judul', render: (r) => h('div', {}, h('b', {}, r.title), h('div', { class: 'small muted' }, r.body.slice(0, 120))) },
        { label: 'Status', render: (r) => (r.is_published ? badge('Terbit', 'ok') : badge('Draft', 'draft')) },
        { label: 'Terbit', render: (r) => h('span', { class: 'small muted' }, fmtDate(r.published_at)) },
        { label: '', class: 'actions', render: (r) => h('div', { class: 'row' },
          h('button', { class: 'btn secondary sm', type: 'button', onclick: () => edit(r) }, 'Ubah'),
          h('button', { class: 'btn ghost sm', type: 'button', style: { color: 'var(--error)' }, onclick: async () => {
            if (!(await confirmDialog({ message: `Hapus pengumuman "${r.title}"?`, danger: true, confirmLabel: 'Hapus' }))) return;
            try { unwrap(await sb.from('announcements').delete().eq('id', r.id)); load(); } catch (e) { toast(e.message, 'error'); }
          } }, 'Hapus')) },
      ], rows, { empty: 'Belum ada pengumuman.' }));
    } catch (e) { clear(box, errorState(e.message, load)); }
  }
  function edit(r) {
    const title = h('input', { type: 'text', value: r?.title || '', maxlength: 120 });
    const body = h('textarea', { maxlength: 2000, style: { minHeight: '160px' } }, r?.body || '');
    const pub = checkbox('Terbitkan', r?.is_published || false);
    const err = h('div');
    modal({
      title: r ? 'Ubah pengumuman' : 'Tambah pengumuman',
      body: h('div', { class: 'stack' }, err, field('Judul', title, { required: true }), field('Isi', body, { required: true }), pub.el),
      actions: [{ label: 'Batal', onClick: (c) => c() }, { label: 'Simpan', kind: 'primary', onClick: async (c) => {
        const v = { title: title.value.trim(), body: body.value.trim(), is_published: pub.input.checked,
          published_at: pub.input.checked ? (r?.published_at || new Date().toISOString()) : null };
        if (!v.title || !v.body) { clear(err, h('div', { class: 'alert error' }, 'Judul dan isi wajib diisi.')); return; }
        try {
          if (r) unwrap(await sb.from('announcements').update(v).eq('id', r.id)); else unwrap(await sb.from('announcements').insert(v));
          toast('Pengumuman tersimpan.', 'ok'); c(); load();
        } catch (e) { clear(err, h('div', { class: 'alert error' }, e.message)); }
      } }],
    });
  }
  load();
}

export async function faqsPage(root) {
  const box = h('div');
  let rows = [];
  clear(root,
    h('div', { class: 'page-head' }, h('h1', {}, 'FAQ'), h('span', { class: 'spacer' }),
      h('button', { class: 'btn', type: 'button', onclick: () => edit(null) }, '+ Tambah FAQ')),
    h('p', { class: 'muted' }, 'Pertanyaan umum tentang penggunaan aplikasi, ditampilkan di menu Bantuan.'), box);
  async function load() {
    clear(box, loading());
    try {
      rows = unwrap(await sb.from('faqs').select('*').order('sort_order').order('created_at'));
      clear(box, table([
        { label: 'Urutan', render: (r, i) => h('div', { class: 'row', style: { gap: '2px' } },
          h('button', { class: 'btn ghost sm', type: 'button', 'aria-label': 'Naikkan', disabled: i === 0, onclick: () => move(i, -1) }, '↑'),
          h('button', { class: 'btn ghost sm', type: 'button', 'aria-label': 'Turunkan', disabled: i === rows.length - 1, onclick: () => move(i, 1) }, '↓')) },
        { label: 'Pertanyaan', render: (r) => h('div', {}, h('b', {}, r.question), h('div', { class: 'small muted' }, r.answer.slice(0, 140))) },
        { label: 'Status', render: (r) => (r.is_active ? badge('Aktif', 'ok') : badge('Nonaktif', 'inactive')) },
        { label: '', class: 'actions', render: (r) => h('div', { class: 'row' },
          h('button', { class: 'btn secondary sm', type: 'button', onclick: () => edit(r) }, 'Ubah'),
          h('button', { class: 'btn ghost sm', type: 'button', style: { color: 'var(--error)' }, onclick: async () => {
            if (!(await confirmDialog({ message: 'Hapus FAQ ini?', danger: true, confirmLabel: 'Hapus' }))) return;
            try { unwrap(await sb.from('faqs').delete().eq('id', r.id)); load(); } catch (e) { toast(e.message, 'error'); }
          } }, 'Hapus')) },
      ], rows, { empty: 'Belum ada FAQ.' }));
    } catch (e) { clear(box, errorState(e.message, load)); }
  }
  async function move(i, d) {
    const ids = rows.map((r) => r.id); [ids[i], ids[i + d]] = [ids[i + d], ids[i]];
    try { await rpc('admin_reorder', { p_table: 'faqs', p_ids: ids }); load(); } catch (e) { toast(e.message, 'error'); }
  }
  function edit(r) {
    const q = h('input', { type: 'text', value: r?.question || '', maxlength: 300 });
    const a = h('textarea', { maxlength: 3000, style: { minHeight: '160px' } }, r?.answer || '');
    const act = checkbox('Aktif', r ? r.is_active : true);
    const err = h('div');
    modal({
      title: r ? 'Ubah FAQ' : 'Tambah FAQ',
      body: h('div', { class: 'stack' }, err, field('Pertanyaan', q, { required: true }), field('Jawaban', a, { required: true }), act.el),
      actions: [{ label: 'Batal', onClick: (c) => c() }, { label: 'Simpan', kind: 'primary', onClick: async (c) => {
        const v = { question: q.value.trim(), answer: a.value.trim(), is_active: act.input.checked };
        if (!v.question || !v.answer) { clear(err, h('div', { class: 'alert error' }, 'Pertanyaan dan jawaban wajib diisi.')); return; }
        try {
          if (r) unwrap(await sb.from('faqs').update(v).eq('id', r.id)); else unwrap(await sb.from('faqs').insert({ ...v, sort_order: rows.length }));
          toast('FAQ tersimpan.', 'ok'); c(); load();
        } catch (e) { clear(err, h('div', { class: 'alert error' }, e.message)); }
      } }],
    });
  }
  load();
}
