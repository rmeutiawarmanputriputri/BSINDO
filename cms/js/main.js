import { h, clear, toast, field, errorState } from './ui.js';
import { sb, configOk, currentSession, signIn, signOut, loadAdminProfile } from './api.js';
import { navigate, currentPath, matchRoute, takeFlash } from './router.js';
import { dashboardPage } from './pages/dashboard.js';
import { categoriesPage } from './pages/categories.js';
import { signListPage, signFormPage } from './pages/signs.js';
import { conversationListPage, conversationFormPage } from './pages/conversations.js';
import { mediaPage } from './pages/media.js';
import { quizListPage, quizFormPage } from './pages/quiz.js';
import { usersPage } from './pages/users.js';
import { premiumPage } from './pages/premium.js';
import { bannersPage } from './pages/banners.js';
import { announcementsPage, faqsPage } from './pages/simple.js';
import { importPage } from './pages/import.js';
import { settingsPage, reportsPage } from './pages/settings.js';

const app = document.getElementById('app');
let me = null;

const NAV = [
  ['Ringkasan', [['dashboard', '📊', 'Dashboard']]],
  ['Materi', [['categories', '🗂️', 'Kategori'], ['alphabet', '🔤', 'Alfabet'], ['numbers', '🔢', 'Angka'],
    ['vocabulary', '📚', 'Kosakata'], ['conversations', '💬', 'Percakapan'], ['media', '🎬', 'Media (video & audio)']]],
  ['Latihan', [['quiz', '📝', 'Kuis']]],
  ['Aplikasi', [['banners', '🖼️', 'Banner Beranda'], ['announcements', '🔔', 'Pengumuman'], ['faqs', '❓', 'FAQ'], ['reports', '🚩', 'Laporan konten']]],
  ['Pengguna', [['users', '👥', 'Pengguna'], ['premium', '⭐', 'Premium']]],
  ['Alat', [['import', '⬆️', 'Impor massal'], ['settings', '⚙️', 'Pengaturan']]],
];

const ROUTES = [
  { path: 'dashboard', render: dashboardPage },
  { path: 'categories', render: categoriesPage },
  { path: 'alphabet', render: (r) => signListPage(r, 'alphabet') },
  { path: 'alphabet/new', render: (r) => signFormPage(r, 'alphabet') },
  { path: 'alphabet/:id', render: (r, p) => signFormPage(r, 'alphabet', p.id) },
  { path: 'numbers', render: (r) => signListPage(r, 'number') },
  { path: 'numbers/new', render: (r) => signFormPage(r, 'number') },
  { path: 'numbers/:id', render: (r, p) => signFormPage(r, 'number', p.id) },
  { path: 'vocabulary', render: (r) => signListPage(r, 'vocabulary') },
  { path: 'vocabulary/new', render: (r) => signFormPage(r, 'vocabulary') },
  { path: 'vocabulary/:id', render: (r, p) => signFormPage(r, 'vocabulary', p.id) },
  { path: 'conversations', render: conversationListPage },
  { path: 'conversations/new', render: (r) => conversationFormPage(r) },
  { path: 'conversations/:id', render: (r, p) => conversationFormPage(r, p.id) },
  { path: 'media', render: mediaPage },
  { path: 'quiz', render: quizListPage },
  { path: 'quiz/new', render: (r) => quizFormPage(r) },
  { path: 'quiz/:id', render: (r, p) => quizFormPage(r, p.id) },
  { path: 'users', render: (r) => usersPage(r, { me }) },
  { path: 'premium', render: premiumPage },
  { path: 'premium/users', render: (r) => usersPage(r, { filter: 'premium', title: 'Pengguna Premium', me }) },
  { path: 'banners', render: bannersPage },
  { path: 'announcements', render: announcementsPage },
  { path: 'faqs', render: faqsPage },
  { path: 'reports', render: reportsPage },
  { path: 'import', render: importPage },
  { path: 'settings', render: settingsPage },
];

// ------------------------------------------------------------------ login
function loginView(message) {
  const email = h('input', { type: 'email', autocomplete: 'username', required: true });
  const pass = h('input', { type: 'password', autocomplete: 'current-password', required: true });
  const err = h('div', {}, message ? h('div', { class: 'alert error', role: 'alert' }, message) : null);
  const btn = h('button', { class: 'btn', type: 'submit', style: { width: '100%' } }, 'Masuk');
  clear(app, h('div', { class: 'login-wrap' }, h('form', { class: 'card login-card stack', onsubmit: async (e) => {
    e.preventDefault(); clear(err); btn.disabled = true; btn.textContent = 'Memeriksa…';
    try {
      const s = await signIn(email.value.trim(), pass.value);
      await enter(s);
    } catch (ex) { clear(err, h('div', { class: 'alert error', role: 'alert' }, ex.message)); }
    btn.disabled = false; btn.textContent = 'Masuk';
  } },
  h('img', { class: 'logo', src: 'assets/logo.svg', alt: 'Logo BISINDO' }),
  h('h1', { style: { textAlign: 'center' } }, 'BISINDO CMS'),
  h('p', { class: 'muted', style: { textAlign: 'center' } }, 'Masuk dengan akun admin yang sama dengan aplikasi.'),
  err, field('Email', email), field('Kata sandi', pass), btn)));
  email.focus();
}

async function enter(session) {
  const profile = await loadAdminProfile(session.user.id);
  if (!profile) {
    await signOut();
    loginView('Akun ini bukan admin aktif. Hanya admin yang dapat membuka CMS.');
    return;
  }
  me = { ...profile, email: session.user.email };
  renderShell();
  if (!currentPath()) navigate('dashboard'); else route();
}

// ------------------------------------------------------------------ shell
let content;
function renderShell() {
  content = h('main', { class: 'content', id: 'content', tabindex: -1 });
  const nav = h('nav', { class: 'nav', 'aria-label': 'Menu utama' }, NAV.map(([group, items]) => [
    h('div', { class: 'nav-group' }, group),
    items.map(([path, ico, label]) => h('a', { href: `#/${path}`, dataset: { path }, onclick: () => document.body.classList.remove('nav-open') },
      h('span', { class: 'ico', 'aria-hidden': 'true' }, ico), label))]));
  clear(app, h('div', { class: 'layout' },
    h('aside', { class: 'sidebar' }, h('div', { class: 'brand' }, h('img', { src: 'assets/logo.svg', alt: '' }),
      h('div', {}, h('b', {}, 'BISINDO'), h('span', {}, 'CMS v1.1.0'))), nav),
    h('div', { class: 'main' },
      h('header', { class: 'topbar' },
        h('button', { class: 'btn ghost menu-btn', type: 'button', 'aria-label': 'Buka menu', onclick: () => document.body.classList.toggle('nav-open') }, '☰'),
        h('span', { class: 'spacer' }),
        h('span', { class: 'muted small' }, `${me.full_name} · ${me.email}`),
        h('button', { class: 'btn secondary sm', type: 'button', onclick: async () => { await signOut(); me = null; loginView(); } }, 'Keluar')),
      content)));
}

async function route() {
  if (!me || !content) return;
  const path = currentPath() || 'dashboard';
  document.querySelectorAll('.nav a').forEach((a) => {
    const p = a.dataset.path;
    a.classList.toggle('active', path === p || path.startsWith(p + '/'));
    if (a.classList.contains('active')) a.setAttribute('aria-current', 'page'); else a.removeAttribute('aria-current');
  });
  const m = matchRoute(ROUTES, path);
  const flash = takeFlash();
  window.scrollTo(0, 0);
  if (!m) { clear(content, h('h1', {}, 'Halaman tidak ditemukan'), h('a', { href: '#/dashboard' }, 'Kembali ke Dashboard')); return; }
  try {
    await m.route.render(content, m.params);
    if (flash) content.insertBefore(flash, content.children[1] || null);
  } catch (e) {
    console.error(e);
    clear(content, errorState(e.message || 'Terjadi kesalahan.', () => route()));
  }
}

// ------------------------------------------------------------------ boot
async function boot() {
  if (!configOk) {
    clear(app, h('div', { class: 'login-wrap' }, h('div', { class: 'card login-card stack' }, h('h1', {}, 'Konfigurasi belum diisi'),
      h('p', {}, 'Salin ', h('code', {}, 'config.example.js'), ' menjadi ', h('code', {}, 'config.js'), ' lalu isi SUPABASE_URL dan anon/publishable key. Lihat docs/CMS_SETUP.md.'))));
    return;
  }
  window.addEventListener('hashchange', route);
  sb.auth.onAuthStateChange((event) => {
    if (event === 'SIGNED_OUT' && me) { me = null; loginView('Sesi berakhir. Silakan masuk lagi.'); }
  });
  try {
    const s = await currentSession();
    if (s) await enter(s); else loginView();
  } catch (e) {
    loginView(e.message);
  }
}
window.addEventListener('unhandledrejection', (e) => { toast(e.reason?.message || 'Terjadi kesalahan.', 'error'); });
boot();
