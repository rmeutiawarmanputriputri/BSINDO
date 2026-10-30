import { h, clear, toast, field, checkbox, loading, errorState, table, statusBadge } from '../ui.js';
import { sb, unwrap, getSettings, saveSetting } from '../api.js';
import { navigate } from '../router.js';

const MOD = { vocabulary: 'Kosakata', alphabet: 'Alfabet', number: 'Angka' };

export async function premiumPage(root) {
  clear(root, h('div', { class: 'page-head' }, h('h1', {}, 'Premium')), loading());
  let info;
  try { info = (await getSettings(true)).premium_info || {}; } catch (e) { clear(root, errorState(e.message, () => premiumPage(root))); return; }

  // ---------------- info paket (teks dari pemilik)
  const enabled = checkbox('Tampilkan informasi & kunci Premium di aplikasi', !!info.enabled);
  const title = h('input', { type: 'text', value: info.title || '', maxlength: 120 });
  const desc = h('textarea', { maxlength: 2000 }, info.description || '');
  const plans = (info.plans || []).map((p) => ({ ...p }));
  const planBox = h('div', { class: 'list-editor' });
  function renderPlans() {
    clear(planBox, plans.length ? plans.map((p, i) => h('div', { class: 'item' },
      h('div', { class: 'item-head' }, h('b', {}, `Paket ${i + 1}`), h('span', { class: 'spacer' }),
        h('button', { class: 'btn ghost sm', type: 'button', onclick: () => { plans.splice(i, 1); renderPlans(); } }, 'Hapus')),
      h('div', { class: 'form-grid' },
        field('Nama paket', h('input', { type: 'text', value: p.name || '', maxlength: 80, oninput: (e) => { p.name = e.target.value; } }), { required: true }),
        field('Harga (teks tampil)', h('input', { type: 'text', value: p.price_label || '', maxlength: 60, placeholder: 'mis. Rp…/bulan', oninput: (e) => { p.price_label = e.target.value; } })),
        field('Keterangan', h('textarea', { maxlength: 500, oninput: (e) => { p.description = e.target.value; } }, p.description || ''), { full: true }))))
      : h('p', { class: 'muted' }, 'Belum ada paket.'));
  }
  renderPlans();

  const contentBox = h('div', {}, loading());
  clear(root,
    h('div', { class: 'page-head' }, h('h1', {}, 'Premium'), h('span', { class: 'spacer' }),
      h('button', { class: 'btn secondary', type: 'button', onclick: () => navigate('premium/users') }, 'Pengguna Premium →')),
    h('div', { class: 'alert info' }, 'Status Premium pengguna diatur di menu Pengguna → Detail (manual). Integrasi RevenueCat sudah disiapkan tetapi nonaktif sampai kredensial diisi (lihat docs/CMS_SETUP.md).'),
    h('div', { class: 'card stack' }, h('h2', {}, 'Informasi paket'), enabled.el,
      h('div', { class: 'form-grid' }, field('Judul', title), field('Deskripsi', desc, { full: true })),
      h('div', { class: 'page-head' }, h('h3', { style: { margin: 0 } }, 'Paket'), h('span', { class: 'spacer' }),
        h('button', { class: 'btn secondary sm', type: 'button', onclick: () => { plans.push({ name: '' }); renderPlans(); } }, '+ Paket')),
      planBox,
      h('div', { class: 'form-actions' }, h('button', { class: 'btn', type: 'button', onclick: async () => {
        if (plans.some((p) => !p.name?.trim())) { toast('Nama paket wajib diisi.', 'error'); return; }
        try {
          await saveSetting('premium_info', { enabled: enabled.input.checked, title: title.value.trim() || null,
            description: desc.value.trim() || null, plans: plans.map((p) => ({ name: p.name.trim(), price_label: p.price_label?.trim() || null, description: p.description?.trim() || null })) });
          toast('Informasi Premium disimpan.', 'ok');
        } catch (e) { toast(e.message, 'error'); }
      } }, 'Simpan informasi'))),
    h('div', { class: 'card', style: { marginTop: '16px' } }, h('h2', {}, 'Konten Premium'),
      h('p', { class: 'muted small' }, 'Tandai konten Premium dari form masing-masing materi. Media konten Premium hanya dapat diputar pengguna Premium.'), contentBox));

  async function loadContent() {
    try {
      const [signs, mods, qs] = await Promise.all([
        sb.from('signs').select('id, content_module, term, status').eq('is_premium', true).order('term').limit(200),
        sb.from('conversation_modules').select('id, title, status').eq('is_premium', true).limit(200),
        sb.from('questions').select('id, prompt, status').eq('is_premium', true).is('quiz_id', null).limit(200),
      ]).then((r) => r.map(unwrap));
      const rows = [
        ...signs.map((s) => ({ type: MOD[s.content_module], title: s.term, status: s.status, route: `${s.content_module === 'number' ? 'numbers' : s.content_module}/${s.id}`, table: 'signs', id: s.id })),
        ...mods.map((m) => ({ type: 'Percakapan', title: m.title, status: m.status, route: `conversations/${m.id}`, table: 'conversation_modules', id: m.id })),
        ...qs.map((q) => ({ type: 'Soal kuis', title: q.prompt.slice(0, 80), status: q.status, route: `quiz/${q.id}`, table: 'questions', id: q.id })),
      ];
      clear(contentBox, table([
        { label: 'Jenis', key: 'type' }, { label: 'Judul', key: 'title' }, { label: 'Status', render: (r) => statusBadge(r.status) },
        { label: '', class: 'actions', render: (r) => h('div', { class: 'row' },
          h('button', { class: 'btn secondary sm', type: 'button', onclick: () => navigate(r.route) }, 'Buka'),
          h('button', { class: 'btn ghost sm', type: 'button', onclick: async () => {
            try { unwrap(await sb.from(r.table).update({ is_premium: false }).eq('id', r.id)); toast('Dijadikan gratis.', 'ok'); loadContent(); } catch (e) { toast(e.message, 'error'); }
          } }, 'Jadikan gratis')) },
      ], rows, { empty: 'Belum ada konten Premium. Semua konten gratis.' }));
    } catch (e) { clear(contentBox, errorState(e.message, loadContent)); }
  }
  loadContent();
}
