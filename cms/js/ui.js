// Komponen UI kecil tanpa framework. Teks SELALU lewat textContent (tanpa innerHTML)
// sehingga isi dari database tidak bisa menyisipkan HTML/skrip.

export function h(tag, attrs = {}, ...children) {
  const el = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs || {})) {
    if (v === undefined || v === null || v === false) continue;
    if (k === 'class') el.className = v;
    else if (k === 'dataset') Object.assign(el.dataset, v);
    else if (k.startsWith('on') && typeof v === 'function') el.addEventListener(k.slice(2).toLowerCase(), v);
    else if (k === 'value') el.value = v;
    else if (k === 'checked') el.checked = !!v;
    else if (k === 'style' && typeof v === 'object') Object.assign(el.style, v);
    else el.setAttribute(k, v === true ? '' : String(v));
  }
  append(el, children);
  return el;
}

function append(el, children) {
  for (const c of children.flat(Infinity)) {
    if (c === null || c === undefined || c === false) continue;
    el.appendChild(c instanceof Node ? c : document.createTextNode(String(c)));
  }
}

export function clear(el, ...children) {
  el.replaceChildren();
  append(el, children);
  return el;
}

// ------------------------------------------------------------------ toast
export function toast(message, kind = 'info', ms = 4500) {
  const box = document.getElementById('toasts');
  const t = h('div', { class: `toast ${kind}` }, message);
  box.appendChild(t);
  while (box.children.length > 3) box.firstChild.remove();   // maksimal 3 sekaligus
  setTimeout(() => t.remove(), ms);
}

// ------------------------------------------------------------------ modal
export function modal({ title, body, actions = [], wide = false, onClose }) {
  const close = () => { backdrop.remove(); document.removeEventListener('keydown', onKey); onClose?.(); };
  const onKey = (e) => { if (e.key === 'Escape') close(); };
  const footer = actions.length ? h('footer', {}, actions.map((a) =>
    h('button', { class: `btn ${a.kind || 'secondary'}`, type: 'button', onclick: () => a.onClick?.(close) }, a.label))) : null;
  const dlg = h('div', { class: `modal${wide ? ' wide' : ''}`, role: 'dialog', 'aria-modal': 'true', 'aria-label': title },
    h('header', {}, h('h2', {}, title), h('button', { class: 'btn ghost sm', type: 'button', 'aria-label': 'Tutup', onclick: close }, '✕')),
    h('div', { class: 'body' }, body),
    footer);
  const backdrop = h('div', { class: 'modal-backdrop', onmousedown: (e) => { if (e.target === backdrop) close(); } }, dlg);
  document.body.appendChild(backdrop);
  document.addEventListener('keydown', onKey);
  setTimeout(() => dlg.querySelector('input,select,textarea,button')?.focus(), 0);
  return { close, el: dlg };
}

export function confirmDialog({ title = 'Konfirmasi', message, details, confirmLabel = 'Ya, lanjutkan', danger = false }) {
  return new Promise((resolve) => {
    let done = false;
    const m = modal({
      title,
      body: h('div', { class: 'stack' }, h('p', {}, message), details || null),
      actions: [
        { label: 'Batal', onClick: (c) => { done = true; resolve(false); c(); } },
        { label: confirmLabel, kind: danger ? 'danger' : 'primary', onClick: (c) => { done = true; resolve(true); c(); } },
      ],
      onClose: () => { if (!done) resolve(false); },
    });
    return m;
  });
}

// ------------------------------------------------------------------ badges & format
const STATUS_LABEL = {
  draft: 'Draft', published: 'Published', archived: 'Archived', inactive: 'Inactive',
  in_review: 'Ditinjau', verified: 'Terverifikasi',
};
export const STATUS_OPTIONS = [['draft', 'Draft'], ['published', 'Published'], ['archived', 'Archived'], ['inactive', 'Inactive']];

export function statusBadge(status) {
  return h('span', { class: `badge ${status}`, title: `Status: ${STATUS_LABEL[status] || status}` },
    status === 'published' ? '● ' : '○ ', STATUS_LABEL[status] || status);
}
export const badge = (text, cls = '') => h('span', { class: `badge ${cls}` }, text);

export function fmtDate(v, withTime = true) {
  if (!v) return '—';
  const d = new Date(v);
  if (Number.isNaN(d.getTime())) return '—';
  return d.toLocaleString('id-ID', withTime
    ? { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' }
    : { day: '2-digit', month: 'short', year: 'numeric' });
}
export function fmtBytes(n) {
  if (!n && n !== 0) return '—';
  const u = ['B', 'KB', 'MB', 'GB']; let i = 0; let x = Number(n);
  while (x >= 1024 && i < u.length - 1) { x /= 1024; i++; }
  return `${x.toFixed(i ? 1 : 0)} ${u[i]}`;
}
export function fmtDuration(ms) {
  if (!ms) return '';
  const s = Math.round(ms / 1000);
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;
}

// ------------------------------------------------------------------ states
export const loading = (text = 'Memuat…') => h('div', { class: 'loading' }, h('span', { class: 'spinner' }), ' ', text);
export const emptyState = (text) => h('div', { class: 'empty' }, text);
export function errorState(message, onRetry) {
  return h('div', { class: 'alert error' }, message, ' ',
    onRetry ? h('button', { class: 'btn sm secondary', type: 'button', onclick: onRetry }, 'Coba lagi') : null);
}
export function issuesAlert(issues, title = 'Belum bisa dipublikasikan. Yang masih kurang:') {
  return h('div', { class: 'alert warn', role: 'alert' }, h('b', {}, title), h('ul', {}, issues.map((i) => h('li', {}, i))));
}

// ------------------------------------------------------------------ table
export function table(columns, rows, { empty = 'Belum ada data.' } = {}) {
  if (!rows.length) return h('div', { class: 'table-wrap' }, emptyState(empty));
  return h('div', { class: 'table-wrap' }, h('table', {},
    h('thead', {}, h('tr', {}, columns.map((c) => h('th', { scope: 'col' }, c.label)))),
    h('tbody', {}, rows.map((r, i) => h('tr', {}, columns.map((c) =>
      h('td', { class: c.class || '' }, c.render ? c.render(r, i) : (r[c.key] ?? '—'))))))));
}

export function pager({ page, pageSize, total, onPage }) {
  const pages = Math.max(1, Math.ceil(total / pageSize));
  return h('div', { class: 'pager' },
    h('span', { class: 'muted small' }, `${total} data · halaman ${page + 1} dari ${pages}`),
    h('button', { class: 'btn secondary sm', type: 'button', disabled: page <= 0, onclick: () => onPage(page - 1) }, '‹ Sebelumnya'),
    h('button', { class: 'btn secondary sm', type: 'button', disabled: page + 1 >= pages, onclick: () => onPage(page + 1) }, 'Berikutnya ›'));
}

// ------------------------------------------------------------------ form fields
export function field(label, input, { help, required, full } = {}) {
  return h('label', { class: `field${full ? ' full' : ''}` },
    h('span', {}, label, required ? h('span', { class: 'req', 'aria-hidden': 'true' }, ' *') : null), input,
    help ? h('div', { class: 'help' }, help) : null);
}
export function select(options, value, attrs = {}) {
  return h('select', attrs, options.map(([v, l]) => h('option', { value: v, selected: String(v) === String(value ?? '') }, l)));
}
export function checkbox(label, checked, attrs = {}) {
  const input = h('input', { type: 'checkbox', checked, ...attrs });
  return { el: h('label', { class: 'check' }, input, label), input };
}
export function debounce(fn, ms = 300) {
  let t; return (...a) => { clearTimeout(t); t = setTimeout(() => fn(...a), ms); };
}
