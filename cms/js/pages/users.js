import { h, clear, modal, toast, confirmDialog, badge, select, field, checkbox, loading, errorState, table, pager, debounce, fmtDate } from '../ui.js';
import { rpc } from '../api.js';

export function premiumBadge(u) {
  return u.is_premium ? badge(`Premium${u.plan ? ' · ' + u.plan : ''}`, 'premium') : badge('Gratis');
}

export async function usersPage(root, { filter = null, title = 'Pengguna', me } = {}) {
  const state = { q: '', page: 0, size: 25, filter };
  const box = h('div');
  clear(root,
    h('div', { class: 'page-head' }, h('h1', {}, title)),
    h('div', { class: 'filters' },
      h('input', { type: 'search', placeholder: 'Cari nama atau email…', 'aria-label': 'Cari', oninput: debounce((e) => { state.q = e.target.value.trim(); state.page = 0; load(); }) }),
      filter ? null : select([['', 'Semua pengguna'], ['premium', 'Premium'], ['inactive', 'Nonaktif'], ['admin', 'Admin']], '',
        { 'aria-label': 'Filter', onchange: (e) => { state.filter = e.target.value || null; state.page = 0; load(); } })),
    box);

  async function load() {
    clear(box, loading());
    try {
      const r = await rpc('admin_list_users', { p_search: state.q || null, p_limit: state.size, p_offset: state.page * state.size, p_filter: state.filter });
      clear(box, table([
        { label: 'Nama', render: (u) => h('div', {}, h('b', {}, u.full_name), h('div', { class: 'small muted' }, u.email)) },
        { label: 'Peran', render: (u) => (u.role === 'admin' ? badge('Admin', 'admin') : badge('Pengguna')) },
        { label: 'Akun', render: (u) => (u.is_active ? badge('Aktif', 'ok') : badge('Nonaktif', 'inactive')) },
        { label: 'Premium', render: (u) => [premiumBadge(u), u.premium_expires_at ? h('div', { class: 'small muted' }, `s.d. ${fmtDate(u.premium_expires_at, false)}`) : null] },
        { label: 'Terdaftar', render: (u) => h('span', { class: 'small muted' }, fmtDate(u.created_at, false)) },
        { label: 'Login terakhir', render: (u) => h('span', { class: 'small muted' }, fmtDate(u.last_sign_in_at)) },
        { label: '', class: 'actions', render: (u) => h('button', { class: 'btn secondary sm', type: 'button', onclick: () => detail(u.id) }, 'Detail') },
      ], r.rows, { empty: 'Tidak ada pengguna.' }),
      pager({ page: state.page, pageSize: state.size, total: r.total, onPage: (p) => { state.page = p; load(); } }));
    } catch (e) { clear(box, errorState(e.message, load)); }
  }

  async function detail(id) {
    const body = h('div', {}, loading());
    const m = modal({ title: 'Detail pengguna', body, wide: true });
    let u;
    try { u = await rpc('admin_user_detail', { p_user_id: id }); } catch (e) { clear(body, errorState(e.message)); return; }
    const p = u.progress || {};
    const sub = u.subscription || {};
    const isMe = me && me.id === u.id;

    const premium = checkbox('Premium aktif', u.is_premium);
    const plan = h('input', { type: 'text', value: sub.plan || '', maxlength: 80, placeholder: 'Nama paket' });
    const exp = h('input', { type: 'date', value: sub.expires_at ? sub.expires_at.slice(0, 10) : '' });
    const note = h('input', { type: 'text', value: sub.note || '', maxlength: 500 });

    clear(body, h('div', { class: 'grid two' },
      h('div', { class: 'stack' },
        h('dl', { class: 'kv' },
          h('dt', {}, 'Nama'), h('dd', {}, u.full_name), h('dt', {}, 'Email'), h('dd', {}, u.email),
          h('dt', {}, 'Peran'), h('dd', {}, u.role), h('dt', {}, 'Status akun'), h('dd', {}, u.is_active ? 'Aktif' : 'Nonaktif'),
          h('dt', {}, 'Terdaftar'), h('dd', {}, fmtDate(u.created_at)), h('dt', {}, 'Login terakhir'), h('dd', {}, fmtDate(u.last_sign_in_at)),
          h('dt', {}, 'Aktivitas terakhir'), h('dd', {}, fmtDate(p.last_activity))),
        h('div', { class: 'row' },
          h('button', { class: 'btn secondary', type: 'button', disabled: isMe, onclick: async () => {
            const to = u.role === 'admin' ? 'user' : 'admin';
            if (!(await confirmDialog({ message: to === 'admin' ? `Jadikan ${u.full_name} ADMIN? Admin dapat mengubah seluruh konten & pengguna.` : `Cabut peran admin dari ${u.full_name}?`, danger: to === 'admin' }))) return;
            try { await rpc('admin_set_user_role', { p_user_id: u.id, p_role: to }); toast('Peran diubah.', 'ok'); m.close(); load(); } catch (e) { toast(e.message, 'error'); }
          } }, u.role === 'admin' ? 'Cabut admin' : 'Jadikan admin'),
          h('button', { class: `btn ${u.is_active ? 'danger' : 'success'}`, type: 'button', disabled: isMe, onclick: async () => {
            if (!(await confirmDialog({ message: u.is_active ? `Nonaktifkan akun ${u.full_name}? Pengguna tidak bisa membuka materi sampai diaktifkan lagi. Data & progres tetap tersimpan.` : `Aktifkan kembali akun ${u.full_name}?`, danger: u.is_active }))) return;
            try { await rpc('admin_set_user_active', { p_user_id: u.id, p_active: !u.is_active }); toast('Status akun diubah.', 'ok'); m.close(); load(); } catch (e) { toast(e.message, 'error'); }
          } }, u.is_active ? 'Nonaktifkan akun' : 'Aktifkan akun')),
        isMe ? h('p', { class: 'small muted' }, 'Ini akun Anda sendiri — peran & status tidak dapat diubah dari sini.') : null),
      h('div', { class: 'stack' },
        h('h3', {}, 'Ringkasan progres'),
        h('dl', { class: 'kv' },
          h('dt', {}, 'Materi dipelajari'), h('dd', {}, `${p.signs_learned ?? 0} (dibuka ${p.signs_viewed ?? 0})`),
          h('dt', {}, 'Per modul'), h('dd', {}, Object.entries(p.learned_by_module || {}).map(([k, v]) => `${k}: ${v}`).join(', ') || '—'),
          h('dt', {}, 'Percakapan selesai'), h('dd', {}, String(p.conversations_completed ?? 0)),
          h('dt', {}, 'Pelajaran selesai'), h('dd', {}, String(p.lessons_completed ?? 0)),
          h('dt', {}, 'Favorit'), h('dd', {}, String(p.favorites ?? 0)),
          h('dt', {}, 'Kuis'), h('dd', {}, `${p.quiz_sessions ?? 0} sesi${p.quiz_avg != null ? `, rata-rata ${p.quiz_avg}%` : ''}`)),
        h('h3', {}, 'Premium'),
        sub.source === 'revenuecat' ? h('div', { class: 'alert info' }, 'Langganan ini dikelola RevenueCat. Perubahan manual akan ditimpa event RevenueCat berikutnya.') : null,
        premium.el,
        h('div', { class: 'form-grid' }, field('Paket', plan), field('Berlaku sampai', exp, { help: 'Kosongkan = tanpa batas.' }), field('Catatan', note, { full: true })),
        h('div', { class: 'row' }, h('button', { class: 'btn', type: 'button', onclick: async () => {
          try {
            await rpc('admin_set_premium', { p_user_id: u.id, p_is_premium: premium.input.checked, p_plan: plan.value.trim() || null,
              p_expires_at: exp.value ? new Date(exp.value + 'T23:59:59').toISOString() : null, p_note: note.value.trim() || null });
            toast('Status Premium disimpan.', 'ok'); m.close(); load();
          } catch (e) { toast(e.message, 'error'); }
        } }, 'Simpan Premium')))));
  }
  load();
}
