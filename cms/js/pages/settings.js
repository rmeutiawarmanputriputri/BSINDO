import { h, clear, toast, field, loading, errorState, table, select, fmtDate, badge } from '../ui.js';
import { sb, unwrap, getSettings, saveSetting } from '../api.js';

export async function settingsPage(root) {
  clear(root, h('h1', {}, 'Pengaturan'), loading());
  let s;
  try { s = await getSettings(true); } catch (e) { clear(root, errorState(e.message, () => settingsPage(root))); return; }
  const lim = s.media_limits || {};
  const inp = (k, d) => h('input', { type: 'number', min: 1, max: 50, step: 1, value: lim[k] ?? d });
  const video = inp('video_max_mb', 50); const audio = inp('audio_max_mb', 20); const image = inp('image_max_mb', 5);
  clear(root, h('div', { class: 'page-head' }, h('h1', {}, 'Pengaturan')),
    h('div', { class: 'card stack' }, h('h2', {}, 'Batas ukuran unggah media'),
      h('p', { class: 'muted small' }, 'Batas ini ditegakkan di server (trigger database). Batas keras bucket Storage = 50 MB. Paket Supabase gratis juga membatasi 50 MB per berkas.'),
      h('div', { class: 'form-grid' }, field('Video (MB)', video), field('Audio (MB)', audio), field('Gambar (MB)', image)),
      h('div', { class: 'form-actions' }, h('button', { class: 'btn', type: 'button', onclick: async () => {
        const v = { video_max_mb: +video.value, audio_max_mb: +audio.value, image_max_mb: +image.value };
        if (Object.values(v).some((x) => !Number.isFinite(x) || x < 1 || x > 50)) { toast('Nilai harus 1–50 MB.', 'error'); return; }
        try { await saveSetting('media_limits', v); toast('Batas media disimpan.', 'ok'); } catch (e) { toast(e.message, 'error'); }
      } }, 'Simpan'))));
}

// ------------------------------------------------------------------ laporan konten (fitur lama, dipindah ke CMS)
const CAT = { wrong_sign: 'Isyarat salah', wrong_meaning: 'Arti salah', video_problem: 'Masalah video', wrong_example: 'Contoh salah', other: 'Lainnya' };
const ST = [['open', 'Terbuka'], ['in_review', 'Ditinjau'], ['resolved', 'Selesai'], ['rejected', 'Ditolak']];

export async function reportsPage(root) {
  let status = 'open';
  const box = h('div');
  clear(root, h('div', { class: 'page-head' }, h('h1', {}, 'Laporan konten')),
    h('div', { class: 'filters' }, select([['', 'Semua'], ...ST], status, { 'aria-label': 'Status', onchange: (e) => { status = e.target.value; load(); } })), box);
  async function load() {
    clear(box, loading());
    try {
      let q = sb.from('content_reports').select('id, sign_id, conversation_module_id, lesson_id, category, description, status, resolution_message, created_at').order('created_at', { ascending: false }).limit(200);
      if (status) q = q.eq('status', status);
      const rows = unwrap(await q);
      const ids = (k) => [...new Set(rows.map((r) => r[k]).filter(Boolean))];
      const [signs, mods, lessons] = await Promise.all([
        ids('sign_id').length ? sb.from('signs').select('id, term').in('id', ids('sign_id')).then(unwrap) : [],
        ids('conversation_module_id').length ? sb.from('conversation_modules').select('id, title').in('id', ids('conversation_module_id')).then(unwrap) : [],
        ids('lesson_id').length ? sb.from('lessons').select('id, title').in('id', ids('lesson_id')).then(unwrap) : [],
      ]);
      const name = Object.fromEntries([...signs.map((s) => [s.id, s.term]), ...mods.map((m) => [m.id, m.title]), ...lessons.map((l) => [l.id, l.title])]);
      clear(box, table([
        { label: 'Target', render: (r) => name[r.sign_id || r.conversation_module_id || r.lesson_id] || '—' },
        { label: 'Kategori', render: (r) => CAT[r.category] || r.category },
        { label: 'Keterangan', render: (r) => h('span', { class: 'small' }, r.description || '—') },
        { label: 'Dibuat', render: (r) => h('span', { class: 'small muted' }, fmtDate(r.created_at)) },
        { label: 'Status', render: (r) => badge(ST.find((s) => s[0] === r.status)?.[1] || r.status, r.status === 'resolved' ? 'ok' : r.status === 'rejected' ? 'error' : 'warn') },
        { label: 'Tindak lanjut', render: (r) => {
          const st = select(ST, r.status, { 'aria-label': 'Status laporan' });
          const msg = h('input', { type: 'text', value: r.resolution_message || '', maxlength: 500, placeholder: 'Pesan untuk pelapor' });
          return h('div', { class: 'row' }, st, msg, h('button', { class: 'btn sm', type: 'button', onclick: async () => {
            const closed = ['resolved', 'rejected'].includes(st.value);
            try {
              unwrap(await sb.from('content_reports').update({ status: st.value, resolution_message: msg.value.trim() || null,
                resolved_at: closed ? new Date().toISOString() : null }).eq('id', r.id));
              toast('Laporan diperbarui.', 'ok'); load();
            } catch (e) { toast(e.message, 'error'); }
          } }, 'Simpan'));
        } },
      ], rows, { empty: 'Tidak ada laporan.' }));
    } catch (e) { clear(box, errorState(e.message, load)); }
  }
  load();
}
