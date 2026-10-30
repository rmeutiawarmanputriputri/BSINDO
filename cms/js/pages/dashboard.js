import { h, clear, loading, errorState, fmtDate, fmtBytes } from '../ui.js';
import { rpc } from '../api.js';
import { navigate } from '../router.js';

const ACT = {
  user_registered: (e) => `Pengguna baru: ${e.name}`,
  quiz_finished: (e) => `${e.name} menyelesaikan kuis (${e.score}%)`,
  content_updated: (e) => `Materi diperbarui: ${e.name} (${e.status})`,
};

export async function dashboardPage(root) {
  clear(root, h('div', { class: 'page-head' }, h('h1', {}, 'Dashboard')), loading());
  let s;
  try { s = await rpc('admin_dashboard_stats'); } catch (e) { clear(root, h('h1', {}, 'Dashboard'), errorState(e.message, () => dashboardPage(root))); return; }
  const mod = s.signs_by_module || {};
  const stat = (num, lbl, route) => h('div', { class: 'card stat', role: route ? 'link' : null, tabindex: route ? 0 : null,
    style: route ? { cursor: 'pointer' } : null, onclick: route ? () => navigate(route) : null },
  h('div', { class: 'num' }, String(num ?? 0)), h('div', { class: 'lbl' }, lbl));
  const max = Math.max(1, ...(s.daily_active || []).map((d) => d.users));

  clear(root,
    h('div', { class: 'page-head' }, h('h1', {}, 'Dashboard'), h('span', { class: 'spacer' }),
      h('button', { class: 'btn secondary', type: 'button', onclick: () => dashboardPage(root) }, '↻ Muat ulang')),
    h('h2', {}, 'Pengguna'),
    h('div', { class: 'grid stats' },
      stat(s.users_total, 'Total pengguna', 'users'), stat(s.users_active_7d, 'Aktif 7 hari terakhir'),
      stat(s.users_new_7d, 'Pendaftar baru (7 hari)'), stat(s.premium_users, 'Pengguna Premium', 'premium'),
      stat(s.users_inactive, 'Akun nonaktif', 'users')),
    h('h2', { style: { marginTop: '20px' } }, 'Konten'),
    h('div', { class: 'grid stats' },
      stat(s.materials_total, `Total materi (${s.materials_published} published)`),
      stat(mod.alphabet || 0, 'Materi alfabet', 'alphabet'), stat(mod.number || 0, 'Materi angka', 'numbers'),
      stat(mod.vocabulary || 0, 'Kosakata', 'vocabulary'), stat(s.conversation_topics, `Topik percakapan (${s.conversation_sentences} kalimat)`, 'conversations'),
      stat(s.categories, 'Kategori', 'categories'), stat(s.drafts, 'Draft menunggu'),
      stat(s.quiz_questions_bank, 'Soal kuis (bank)', 'quiz'), stat(s.banners_active, 'Banner aktif', 'banners')),
    h('h2', { style: { marginTop: '20px' } }, 'Media & aktivitas'),
    h('div', { class: 'grid stats' },
      stat(s.videos, 'Video', 'media'), stat(s.audios, 'Audio', 'media'), stat(s.images, 'Gambar', 'media'),
      stat(fmtBytes(s.media_bytes), 'Total ukuran media'), stat(s.quiz_sessions_total, 'Kuis dikerjakan'),
      stat(s.quiz_sessions_7d, 'Kuis (7 hari)'), stat(s.open_reports, 'Laporan terbuka', 'reports')),
    h('div', { class: 'grid two', style: { marginTop: '20px' } },
      h('div', { class: 'card' }, h('h3', {}, 'Pengguna aktif harian (14 hari)'),
        h('div', { class: 'bars', role: 'img', 'aria-label': 'Grafik pengguna aktif harian' },
          (s.daily_active || []).map((d) => h('div', { class: 'bar', title: `${d.day}: ${d.users} pengguna`, style: { height: `${(d.users / max) * 100}%` } }))),
        h('div', { class: 'bars-labels' }, (s.daily_active || []).map((d) => h('span', {}, d.day.slice(8, 10))))),
      h('div', { class: 'card' }, h('h3', {}, 'Aktivitas terbaru'),
        (s.recent_activity || []).length
          ? h('ul', { class: 'activity' }, s.recent_activity.slice(0, 12).map((e) => h('li', {}, (ACT[e.type] || (() => e.type))(e), ' ', h('span', { class: 'small muted' }, `· ${fmtDate(e.at)}`))))
          : h('p', { class: 'muted' }, 'Belum ada aktivitas.'))));
}
