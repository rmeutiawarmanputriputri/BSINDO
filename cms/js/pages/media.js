import { h, clear, modal, toast, confirmDialog, fmtBytes, fmtDate, fmtDuration, statusBadge, select, field,
  loading, emptyState, errorState, pager, debounce, STATUS_OPTIONS } from '../ui.js';
import { sb, unwrap, rpc, MEDIA_RULES, createMedia, replaceMediaFile, signedUrl, removeObjects, escapeLike,
  getSettings, cacheMedia, forgetMedia, forgetSignedUrl, validateMediaFile, probeMedia, friendlyError } from '../api.js';

const KIND_ICON = { video: '🎬', audio: '🔊', image: '🖼️' };
const KIND_LABEL = { video: 'Video', audio: 'Audio', image: 'Gambar' };
const USAGE_LABEL = { sign: 'Materi', conversation: 'Topik percakapan', conversation_item: 'Kalimat percakapan', lesson: 'Pelajaran',
  category: 'Kategori', banner: 'Banner', question: 'Soal kuis', question_option: 'Pilihan soal' };
const MODULE_LABEL = { vocabulary: 'Kosakata', alphabet: 'Alfabet', number: 'Angka' };

export const mediaName = (m) => (m ? (m.title || m.original_filename || m.path.split('/').pop()) : '');

/** Elemen pratinjau (signed URL). */
export async function previewEl(asset) {
  const url = await signedUrl(asset.path);
  if (asset.kind === 'video') return h('video', { src: url, controls: true, preload: 'metadata', playsinline: true });
  if (asset.kind === 'audio') return h('audio', { src: url, controls: true, preload: 'metadata' });
  return h('img', { src: url, alt: mediaName(asset) });
}

export function openPreview(asset) {
  const box = h('div', { class: 'preview' }, h('div', { class: 'loading' }, 'Memuat pratinjau…'));
  modal({ title: mediaName(asset), body: h('div', { class: 'stack' }, box,
    h('div', { class: 'mono' }, asset.path)), wide: asset.kind !== 'audio' });
  previewEl(asset).then((el) => clear(box, el)).catch((e) => clear(box, errorState(e.message)));
}

function usageList(usage) {
  if (!usage.length) return h('p', { class: 'muted' }, 'Tidak dipakai materi mana pun.');
  return h('ul', {}, usage.map((u) => h('li', {},
    `${USAGE_LABEL[u.type] || u.type}${u.module ? ' · ' + (MODULE_LABEL[u.module] || u.module) : ''}: `,
    h('b', {}, u.title || '—'), ` (${u.field}, ${u.status})`)));
}

// ------------------------------------------------------------------ dialog unggah
/** Dialog unggah dengan pratinjau sebelum disimpan. Resolve → baris media_assets atau null. */
export function uploadDialog(kind, { title: presetTitle } = {}) {
  return new Promise((resolve) => {
    let file = null; let busy = false; let finished = false;
    const rules = MEDIA_RULES[kind];
    const input = h('input', { type: 'file', accept: rules.mimes.concat(rules.ext.map((e) => '.' + e)).join(','), class: 'sr-only', id: 'media-file' });
    const preview = h('div', { class: 'preview' });
    const info = h('div', { class: 'muted small' });
    const err = h('div');
    const titleIn = h('input', { type: 'text', value: presetTitle || '', maxlength: 160, placeholder: 'mis. Huruf A — tampak depan' });
    const descIn = h('textarea', { maxlength: 1000, placeholder: 'Opsional' });
    const statusIn = select(STATUS_OPTIONS.filter(([v]) => v !== 'archived'), 'published');
    const bar = h('div'); const progress = h('div', { class: 'progress hidden', role: 'progressbar', 'aria-valuemin': 0, 'aria-valuemax': 100 }, bar);
    const progText = h('div', { class: 'small muted' });
    const drop = h('label', { class: 'dropzone', for: 'media-file' },
      h('div', { style: { fontSize: '28px' } }, KIND_ICON[kind]),
      h('b', {}, 'Klik untuk memilih berkas'), ' atau seret ke sini', h('div', { class: 'help' }, rules.label));
    getSettings(true).then((s) => { drop.querySelector('.help').textContent = `${rules.label} · maks ${(s.media_limits || {})[kind + '_max_mb'] ?? '?'} MB`; }).catch(() => {});

    const pick = async (f) => {
      clear(err); clear(preview); clear(info); file = null;
      if (!f) return;
      try {
        await validateMediaFile(f, kind);
      } catch (e) { clear(err, h('div', { class: 'alert error' }, e.message)); return; }
      file = f;
      if (!titleIn.value) titleIn.value = f.name.replace(/\.[^.]+$/, '').slice(0, 160);
      const url = URL.createObjectURL(f);
      const el = kind === 'video' ? h('video', { src: url, controls: true, playsinline: true })
        : kind === 'audio' ? h('audio', { src: url, controls: true }) : h('img', { src: url, alt: 'Pratinjau' });
      clear(preview, el);
      const p = await probeMedia(f, kind);
      clear(info, `${f.name} · ${fmtBytes(f.size)}${p.duration_ms ? ' · ' + fmtDuration(p.duration_ms) : ''}${p.width ? ` · ${p.width}×${p.height}` : ''}`);
      if (!p.playable) {
        err.appendChild(h('div', { class: 'alert warn' },
          'Browser tidak bisa memutar/membaca berkas ini. Kemungkinan codec tidak umum — untuk Android gunakan MP4 (H.264 + AAC) atau MP3/M4A.'));
      }
    };
    input.addEventListener('change', () => pick(input.files[0]));
    drop.addEventListener('dragover', (e) => { e.preventDefault(); drop.classList.add('drag'); });
    drop.addEventListener('dragleave', () => drop.classList.remove('drag'));
    drop.addEventListener('drop', (e) => { e.preventDefault(); drop.classList.remove('drag'); pick(e.dataTransfer.files[0]); });

    const m = modal({
      title: `Unggah ${KIND_LABEL[kind]}`, wide: kind === 'video',
      body: h('div', { class: 'stack' }, input, drop, err, preview, info,
        h('div', { class: 'form-grid' },
          field('Judul / nama', titleIn, { required: true, help: 'Nama ini dipakai saat mencari & saat impor CSV.' }),
          field('Status', statusIn, { help: 'Hanya media Published yang bisa diputar di aplikasi.' }),
          field('Deskripsi', descIn, { full: true })),
        progress, progText),
      actions: [
        { label: 'Batal', onClick: (c) => { if (!busy) c(); } },
        { label: 'Unggah & Simpan', kind: 'primary', onClick: async (close) => {
          if (busy) return;
          clear(err);
          if (!file) { clear(err, h('div', { class: 'alert error' }, 'Pilih berkas terlebih dahulu.')); return; }
          if (!titleIn.value.trim()) { clear(err, h('div', { class: 'alert error' }, 'Judul wajib diisi.')); return; }
          busy = true; progress.classList.remove('hidden');
          m.el.querySelectorAll('footer button').forEach((b) => { b.disabled = true; });
          try {
            const { asset } = await createMedia(file, kind, { title: titleIn.value.trim(), description: descIn.value.trim(), status: statusIn.value },
              (p) => { bar.style.width = `${Math.round(p * 100)}%`; progress.setAttribute('aria-valuenow', Math.round(p * 100)); progText.textContent = `Mengunggah… ${Math.round(p * 100)}%`; });
            cacheMedia(asset);
            toast('Media berhasil diunggah.', 'ok');
            finished = true; resolve(asset); close();
          } catch (e) {
            clear(err, h('div', { class: 'alert error', role: 'alert' }, e.message));
            progText.textContent = 'Unggah gagal.';
          } finally {
            busy = false;
            m.el.querySelectorAll('footer button').forEach((b) => { b.disabled = false; });
          }
        } },
      ],
      onClose: () => { if (!finished) resolve(null); },
    });
  });
}

// ------------------------------------------------------------------ pemilih media
export function pickMedia(kind) {
  return new Promise((resolve) => {
    let done = false; let q = '';
    const list = h('div', { class: 'media-grid' });
    const load = async () => {
      clear(list, loading());
      let query = sb.from('media_assets').select('id, kind, path, title, original_filename, mime_type, size_bytes, duration_ms, status, created_at')
        .eq('kind', kind).order('created_at', { ascending: false }).limit(60);
      if (q) query = query.or(`title.ilike.%${escapeLike(q).replace(/[,()]/g, ' ')}%,original_filename.ilike.%${escapeLike(q).replace(/[,()]/g, ' ')}%`);
      try {
        const rows = unwrap(await query);
        if (!rows.length) { clear(list, emptyState('Belum ada media. Unggah baru.')); return; }
        clear(list, rows.map((r) => h('div', { class: 'media-card selectable', tabindex: 0, role: 'button',
          onclick: () => { cacheMedia(r); done = true; resolve(r); m.close(); },
          onkeydown: (e) => { if (e.key === 'Enter') e.currentTarget.click(); } },
          h('div', { class: 'thumb' }, KIND_ICON[r.kind]),
          h('div', { class: 'meta' }, h('b', {}, mediaName(r)), h('span', { class: 'muted small' }, `${fmtBytes(r.size_bytes)} `), statusBadge(r.status)))));
      } catch (e) { clear(list, errorState(e.message, load)); }
    };
    const search = h('input', { type: 'search', placeholder: 'Cari judul atau nama berkas…', oninput: debounce((e) => { q = e.target.value.trim(); load(); }) });
    const m = modal({
      title: `Pilih ${KIND_LABEL[kind]}`, wide: true,
      body: h('div', { class: 'stack' }, h('div', { class: 'row' }, search,
        h('button', { class: 'btn', type: 'button', onclick: async () => {
          const a = await uploadDialog(kind);
          if (a) { done = true; resolve(a); m.close(); }
        } }, '+ Unggah baru')), list),
      onClose: () => { if (!done) resolve(null); },
    });
    load();
  });
}

/** Field form untuk satu media. getValue() → id | null */
export function mediaField(kind, initialId, { onChange } = {}) {
  let id = initialId || null; let asset = null;
  const name = h('span', { class: 'name' });
  const btnPrev = h('button', { class: 'btn ghost sm', type: 'button', onclick: () => asset && openPreview(asset) }, '▶ Pratinjau');
  const btnClear = h('button', { class: 'btn ghost sm', type: 'button', onclick: () => set(null) }, 'Lepas');
  const render = () => {
    if (!id) { name.textContent = 'Belum ada'; name.className = 'name muted'; btnPrev.classList.add('hidden'); btnClear.classList.add('hidden'); return; }
    name.className = 'name';
    name.textContent = asset ? `${KIND_ICON[kind]} ${mediaName(asset)}${asset.status !== 'published' ? ` (${asset.status})` : ''}` : '…';
    btnPrev.classList.toggle('hidden', !asset); btnClear.classList.remove('hidden');
  };
  const set = (a) => { asset = a; id = a?.id || null; render(); onChange?.(id); };
  const el = h('div', { class: 'media-field' }, name, btnPrev,
    h('button', { class: 'btn secondary sm', type: 'button', onclick: async () => { const a = await pickMedia(kind); if (a) set(a); } }, 'Pilih'),
    h('button', { class: 'btn secondary sm', type: 'button', onclick: async () => { const a = await uploadDialog(kind); if (a) set(a); } }, 'Unggah'),
    btnClear);
  render();
  if (id) {
    sb.from('media_assets').select('id, kind, path, title, original_filename, status, mime_type').eq('id', id).maybeSingle()
      .then(({ data }) => { asset = data; if (!data) name.textContent = '(media tidak ditemukan)'; render(); });
  }
  return { el, getValue: () => id };
}

// ------------------------------------------------------------------ halaman Media
export async function mediaPage(root) {
  const state = { kind: '', status: '', q: '', page: 0, size: 24 };
  const listBox = h('div');
  const kindSel = select([['', 'Semua jenis'], ['video', 'Video'], ['audio', 'Audio'], ['image', 'Gambar']], '', { 'aria-label': 'Jenis', onchange: (e) => { state.kind = e.target.value; state.page = 0; load(); } });
  const statusSel = select([['', 'Semua status'], ...STATUS_OPTIONS], '', { 'aria-label': 'Status', onchange: (e) => { state.status = e.target.value; state.page = 0; load(); } });
  const search = h('input', { type: 'search', placeholder: 'Cari judul / nama berkas', 'aria-label': 'Cari', oninput: debounce((e) => { state.q = e.target.value.trim(); state.page = 0; load(); }) });

  clear(root,
    h('div', { class: 'page-head' }, h('h1', {}, 'Media'), h('span', { class: 'spacer' }),
      ['video', 'audio', 'image'].map((k) => h('button', { class: 'btn', type: 'button', onclick: async () => { if (await uploadDialog(k)) load(); } }, `+ ${KIND_LABEL[k]}`))),
    h('p', { class: 'muted' }, 'Video & audio rekaman BISINDO diunggah di sini lalu dihubungkan ke materi. Format untuk Android: MP4 (H.264 + AAC) / WebM, MP3 / M4A / AAC, JPG / PNG / WebP.'),
    h('div', { class: 'filters' }, kindSel, statusSel, search), listBox);

  async function load() {
    clear(listBox, loading());
    let q = sb.from('media_assets').select('id, kind, path, title, description, original_filename, mime_type, size_bytes, duration_ms, width, height, status, created_at', { count: 'exact' })
      .order('created_at', { ascending: false }).range(state.page * state.size, state.page * state.size + state.size - 1);
    if (state.kind) q = q.eq('kind', state.kind);
    if (state.status) q = q.eq('status', state.status);
    if (state.q) { const s = escapeLike(state.q).replace(/[,()]/g, ' '); q = q.or(`title.ilike.%${s}%,original_filename.ilike.%${s}%`); }
    try {
      const { data, count } = unwrap(await q);
      if (!data.length) { clear(listBox, emptyState('Belum ada media.')); return; }
      clear(listBox, h('div', { class: 'media-grid' }, data.map(card)),
        pager({ page: state.page, pageSize: state.size, total: count || 0, onPage: (p) => { state.page = p; load(); } }));
    } catch (e) { clear(listBox, errorState(e.message, load)); }
  }

  function card(m) {
    return h('div', { class: 'media-card' },
      h('div', { class: 'thumb', role: 'button', tabindex: 0, 'aria-label': `Pratinjau ${mediaName(m)}`, onclick: () => openPreview(m) }, KIND_ICON[m.kind]),
      h('div', { class: 'meta' }, h('b', { title: mediaName(m) }, mediaName(m)),
        h('div', { class: 'small muted' }, `${KIND_LABEL[m.kind]} · ${fmtBytes(m.size_bytes)}${m.duration_ms ? ' · ' + fmtDuration(m.duration_ms) : ''}`),
        h('div', { class: 'small muted' }, fmtDate(m.created_at)), statusBadge(m.status)),
      h('div', { class: 'acts' },
        h('button', { class: 'btn ghost sm', type: 'button', onclick: () => openPreview(m) }, 'Putar'),
        h('button', { class: 'btn ghost sm', type: 'button', onclick: () => editDialog(m) }, 'Detail'),
        h('button', { class: 'btn ghost sm', type: 'button', onclick: () => replaceDialog(m) }, 'Ganti'),
        h('button', { class: 'btn ghost sm', type: 'button', style: { color: 'var(--error)' }, onclick: () => deleteMedia(m) }, 'Hapus')));
  }

  async function editDialog(m) {
    const titleIn = h('input', { type: 'text', value: m.title || '', maxlength: 160 });
    const descIn = h('textarea', { maxlength: 1000 }, m.description || '');
    const statusIn = select(STATUS_OPTIONS, m.status);
    const usageBox = h('div', {}, loading('Memeriksa pemakaian…'));
    const urlBox = h('div', { class: 'mono' }, '…');
    modal({
      title: 'Detail media', body: h('div', { class: 'stack' },
        h('div', { class: 'form-grid' }, field('Judul', titleIn), field('Status', statusIn), field('Deskripsi', descIn, { full: true })),
        h('dl', { class: 'kv' }, h('dt', {}, 'Nama berkas asli'), h('dd', {}, m.original_filename || '—'),
          h('dt', {}, 'Path Storage'), h('dd', { class: 'mono' }, m.path), h('dt', {}, 'Tipe'), h('dd', {}, m.mime_type),
          h('dt', {}, 'URL (berlaku 1 jam)'), h('dd', {}, urlBox)),
        h('h3', {}, 'Dipakai oleh'), usageBox),
      actions: [{ label: 'Tutup', onClick: (c) => c() }, { label: 'Simpan', kind: 'primary', onClick: async (c) => {
        try {
          if (statusIn.value !== 'published' && m.status === 'published') {
            const usage = await rpc('media_usage', { p_asset_id: m.id });
            if (usage.some((u) => u.status === 'published')
              && !(await confirmDialog({ message: 'Media ini dipakai materi Published. Jika statusnya diubah, media tidak akan bisa diputar di aplikasi. Lanjutkan?', danger: true }))) return;
          }
          unwrap(await sb.from('media_assets').update({ title: titleIn.value.trim() || null, description: descIn.value.trim() || null, status: statusIn.value }).eq('id', m.id));
          forgetMedia(m.id); toast('Media diperbarui.', 'ok'); c(); load();
        } catch (e) { toast(e.message, 'error'); }
      } }],
    });
    signedUrl(m.path).then((u) => clear(urlBox, h('a', { href: u, target: '_blank', rel: 'noopener' }, 'Buka berkas'))).catch((e) => clear(urlBox, e.message));
    rpc('media_usage', { p_asset_id: m.id }).then((u) => clear(usageBox, usageList(u))).catch((e) => clear(usageBox, errorState(e.message)));
  }

  async function replaceDialog(m) {
    let usage = [];
    try { usage = await rpc('media_usage', { p_asset_id: m.id }); } catch (e) { toast(e.message, 'error'); return; }
    const input = h('input', { type: 'file', accept: MEDIA_RULES[m.kind].mimes.join(',') });
    const bar = h('div'); const progress = h('div', { class: 'progress' }, bar); const msg = h('div');
    const preview = h('div', { class: 'preview' });
    input.addEventListener('change', () => {
      clear(preview); const f = input.files[0]; if (!f) return;
      const url = URL.createObjectURL(f);
      clear(preview, m.kind === 'video' ? h('video', { src: url, controls: true }) : m.kind === 'audio' ? h('audio', { src: url, controls: true }) : h('img', { src: url, alt: '' }));
    });
    modal({
      title: `Ganti berkas: ${mediaName(m)}`, wide: m.kind === 'video',
      body: h('div', { class: 'stack' },
        usage.length ? h('div', { class: 'alert warn' }, `Berkas baru akan dipakai oleh SEMUA (${usage.length}) materi berikut:`, usageList(usage))
          : h('p', { class: 'muted' }, 'Media ini belum dipakai materi apa pun.'),
        h('p', { class: 'small muted' }, 'Jika hanya satu materi yang perlu video berbeda, unggah media baru dari form materi tersebut — materi lain tidak akan berubah.'),
        input, preview, progress, msg),
      actions: [{ label: 'Batal', onClick: (c) => c() }, { label: 'Ganti berkas', kind: 'primary', onClick: async (c) => {
        const f = input.files[0];
        if (!f) { clear(msg, h('div', { class: 'alert error' }, 'Pilih berkas pengganti.')); return; }
        try {
          const r = await replaceMediaFile(m, f, (p) => { bar.style.width = `${Math.round(p * 100)}%`; });
          forgetMedia(m.id); forgetSignedUrl(m.path);
          toast(r.removedOld ? 'Berkas diganti.' : `Berkas diganti, tetapi berkas lama gagal dihapus (${r.oldPath}).`, r.removedOld ? 'ok' : 'error');
          c(); load();
        } catch (e) { clear(msg, h('div', { class: 'alert error' }, e.message)); }
      } }],
    });
  }

  async function deleteMedia(m) {
    let usage;
    try { usage = await rpc('media_usage', { p_asset_id: m.id }); } catch (e) { toast(e.message, 'error'); return; }
    const used = usage.length > 0;
    const ok = await confirmDialog({
      title: 'Hapus media',
      message: used ? `PERINGATAN: media "${mediaName(m)}" masih dipakai ${usage.length} materi. Materi tersebut akan kehilangan media ini. Materi Published yang mewajibkan media ini tidak akan bisa dilepas (penghapusan dibatalkan otomatis).`
        : `Hapus media "${mediaName(m)}" secara permanen?`,
      details: used ? usageList(usage) : null, confirmLabel: used ? 'Tetap hapus' : 'Hapus', danger: true,
    });
    if (!ok) return;
    try {
      const r = await rpc('admin_delete_media', { p_asset_id: m.id, p_force: used });
      forgetMedia(m.id); forgetSignedUrl(r.path);
      const removed = await removeObjects([r.path]);
      toast(removed ? 'Media dihapus.' : `Data media dihapus, tetapi berkas di Storage gagal dihapus: ${r.path}`, removed ? 'ok' : 'error');
      load();
    } catch (e) { toast(friendlyError(e.raw || e), 'error'); }
  }

  load();
}
