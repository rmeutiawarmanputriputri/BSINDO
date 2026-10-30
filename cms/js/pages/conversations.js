// Percakapan: topik (conversation_modules) + kalimat berurutan (conversation_items).
import { h, clear, toast, confirmDialog, fmtDate, statusBadge, badge, select, field, checkbox, loading,
  errorState, table, debounce, issuesAlert, STATUS_OPTIONS } from '../ui.js';
import { sb, unwrap, rpc, getCategories, escapeLike, setContentStatus, slugify } from '../api.js';
import { mediaField } from './media.js';
import { statusMenu } from './signs.js';
import { navigate } from '../router.js';

const MOD_COLS = 'id, slug, category_id, title, description, context_note, thumbnail_asset_id, sort_order, is_premium, source_note, validated_by, verified_at, status, updated_at';

export async function conversationListPage(root) {
  const state = { status: '', q: '' };
  const box = h('div');
  clear(root,
    h('div', { class: 'page-head' }, h('h1', {}, 'Percakapan'), h('span', { class: 'spacer' }),
      h('button', { class: 'btn', type: 'button', onclick: () => navigate('conversations/new') }, '+ Tambah topik')),
    h('p', { class: 'muted' }, 'Setiap topik berisi kalimat berurutan (video, audio, terjemahan, penjelasan, bagian kalimat). Aplikasi memakai urutan ini untuk simulasi percakapan. Susunan isyarat BISINDO tidak selalu sama dengan susunan kata bahasa Indonesia — isi hanya materi yang sudah diverifikasi.'),
    h('div', { class: 'filters' },
      select([['', 'Semua status'], ...STATUS_OPTIONS], '', { 'aria-label': 'Status', onchange: (e) => { state.status = e.target.value; load(); } }),
      h('input', { type: 'search', placeholder: 'Cari topik…', 'aria-label': 'Cari', oninput: debounce((e) => { state.q = e.target.value.trim(); load(); }) })),
    box);

  async function load() {
    clear(box, loading());
    let q = sb.from('conversation_modules').select(MOD_COLS).order('sort_order').order('title');
    if (state.status) q = q.eq('status', state.status);
    if (state.q) q = q.ilike('title', `%${escapeLike(state.q)}%`);
    try {
      const rows = unwrap(await q);
      const counts = {};
      if (rows.length) {
        const items = unwrap(await sb.from('conversation_items').select('module_id').in('module_id', rows.map((r) => r.id)));
        items.forEach((i) => { counts[i.module_id] = (counts[i.module_id] || 0) + 1; });
      }
      clear(box, table([
        { label: 'Urutan', key: 'sort_order' },
        { label: 'Topik', render: (r) => h('div', {}, h('b', {}, r.title), r.is_premium ? [' ', badge('Premium', 'premium')] : null) },
        { label: 'Kalimat', render: (r) => String(counts[r.id] || 0) },
        { label: 'Status', render: (r) => statusBadge(r.status) },
        { label: 'Diubah', render: (r) => h('span', { class: 'small muted' }, fmtDate(r.updated_at)) },
        { label: '', class: 'actions', render: (r) => h('div', { class: 'row' },
          h('button', { class: 'btn secondary sm', type: 'button', onclick: () => navigate(`conversations/${r.id}`) }, 'Ubah'),
          statusMenu(r, load, { type: 'conversation', table: 'conversation_modules' })) },
      ], rows, { empty: 'Belum ada topik percakapan.' }));
    } catch (e) { clear(box, errorState(e.message, load)); }
  }
  load();
}

export async function conversationFormPage(root, id) {
  clear(root, loading());
  let mod = { status: 'draft', sort_order: 0, is_premium: false };
  let items = [];
  let vocab = [];
  try {
    if (id) {
      mod = unwrap(await sb.from('conversation_modules').select(MOD_COLS).eq('id', id).single());
      items = unwrap(await sb.from('conversation_items')
        .select('id, position, speaker_label, text_id, translation, explanation, context_note, sign_id, video_asset_id, audio_asset_id')
        .eq('module_id', id).order('position'));
      if (items.length) {
        const parts = unwrap(await sb.from('conversation_item_parts')
          .select('item_id, position, part_text, meaning, sign_id').in('item_id', items.map((i) => i.id)).order('position'));
        items.forEach((i) => { i.parts = parts.filter((p) => p.item_id === i.id); });
      }
    }
    vocab = unwrap(await sb.from('signs').select('id, term, status').eq('content_module', 'vocabulary').order('term').limit(2000));
  } catch (e) { clear(root, errorState(e.message, () => conversationFormPage(root, id))); return; }
  const cats = (await getCategories()).filter((c) => c.kind === 'conversation');

  const f = {
    title: h('input', { type: 'text', value: mod.title || '', maxlength: 120 }),
    slug: h('input', { type: 'text', value: mod.slug || '', maxlength: 80, pattern: '[a-z0-9]+(-[a-z0-9]+)*' }),
    category_id: select([['', '— tanpa kategori —'], ...cats.map((c) => [c.id, c.name])], mod.category_id || ''),
    description: h('textarea', { maxlength: 1000 }, mod.description || ''),
    context_note: h('textarea', { maxlength: 1000 }, mod.context_note || ''),
    sort_order: h('input', { type: 'number', value: mod.sort_order ?? 0 }),
    source_note: h('input', { type: 'text', value: mod.source_note || '' }),
    validated_by: h('input', { type: 'text', value: mod.validated_by || '' }),
    verified_at: h('input', { type: 'date', value: mod.verified_at ? mod.verified_at.slice(0, 10) : '' }),
  };
  if (!id) f.title.addEventListener('input', () => { f.slug.value = slugify(f.title.value); });
  const premium = checkbox('Topik Premium', mod.is_premium);
  const thumb = mediaField('image', mod.thumbnail_asset_id);
  const msg = h('div');

  // ---------------- editor kalimat
  const list = h('div', { class: 'list-editor' });
  const rows = items.map((it) => makeItem(it));
  function makeItem(it = {}) {
    const r = {
      id: it.id || null,
      speaker: h('input', { type: 'text', value: it.speaker_label || 'A', maxlength: 30 }),
      text: h('textarea', { maxlength: 500 }, it.text_id || ''),
      translation: h('textarea', { maxlength: 500 }, it.translation || ''),
      explanation: h('textarea', { maxlength: 2000 }, it.explanation || ''),
      context: h('input', { type: 'text', value: it.context_note || '' }),
      sign_id: it.sign_id || null,
      video: mediaField('video', it.video_asset_id),
      audio: mediaField('audio', it.audio_asset_id),
      parts: (it.parts || []).map((p) => makePart(p)),
      partsBox: h('div', { class: 'stack' }),
    };
    return r;
  }
  // Bagian kalimat: kosakata dari kamus dan/atau teks bagian + arti bagian (diisi pemilik).
  function makePart(p = {}) {
    const statusLabel = { draft: 'Draft', published: 'Published', archived: 'Archived', inactive: 'Inactive' };
    return {
      sign: select([['', '— tanpa kosakata —'], ...vocab.map((v) => [v.id, v.status === 'published' ? v.term : `${v.term} (${statusLabel[v.status] || v.status})`])],
        p.sign_id || '', { 'aria-label': 'Kosakata' }),
      text: h('input', { type: 'text', value: p.part_text || '', maxlength: 120, placeholder: 'Teks bagian (opsional bila kosakata dipilih)', 'aria-label': 'Teks bagian' }),
      meaning: h('input', { type: 'text', value: p.meaning || '', maxlength: 500, placeholder: 'Arti bagian (opsional)', 'aria-label': 'Arti bagian' }),
    };
  }
  function renderParts(r) {
    clear(r.partsBox,
      r.parts.length ? r.parts.map((p, j) => h('div', { class: 'part-row' },
        h('span', { class: 'small muted' }, `${j + 1}.`), p.sign, p.text, p.meaning,
        h('button', { class: 'btn ghost sm', type: 'button', disabled: j === 0, 'aria-label': `Naikkan bagian ${j + 1}`, onclick: () => { [r.parts[j - 1], r.parts[j]] = [r.parts[j], r.parts[j - 1]]; renderParts(r); } }, '↑'),
        h('button', { class: 'btn ghost sm', type: 'button', style: { color: 'var(--error)' }, 'aria-label': `Hapus bagian ${j + 1}`, onclick: () => { r.parts.splice(j, 1); renderParts(r); } }, '✕')))
        : h('p', { class: 'small muted' }, 'Belum ada bagian. Pecah kalimat menjadi kosakata/isyarat sesuai susunan BISINDO yang sudah diverifikasi.'),
      h('div', {}, h('button', { class: 'btn secondary sm', type: 'button', onclick: () => { r.parts.push(makePart()); renderParts(r); } }, '+ Tambah bagian')));
  }
  function renderItems() {
    clear(list, rows.length ? rows.map((r, i) => h('div', { class: 'item' },
      h('div', { class: 'item-head' }, h('b', {}, `Kalimat ${i + 1}`), h('span', { class: 'spacer' }),
        h('button', { class: 'btn ghost sm', type: 'button', disabled: i === 0, 'aria-label': 'Naikkan', onclick: () => { [rows[i - 1], rows[i]] = [rows[i], rows[i - 1]]; renderItems(); } }, '↑'),
        h('button', { class: 'btn ghost sm', type: 'button', disabled: i === rows.length - 1, 'aria-label': 'Turunkan', onclick: () => { [rows[i + 1], rows[i]] = [rows[i], rows[i + 1]]; renderItems(); } }, '↓'),
        h('button', { class: 'btn ghost sm', type: 'button', style: { color: 'var(--error)' }, onclick: () => { rows.splice(i, 1); renderItems(); } }, 'Hapus')),
      h('div', { class: 'form-grid' },
        field('Pembicara', r.speaker, { help: 'mis. A / B / Guru / Siswa' }),
        field('Konteks (opsional)', r.context),
        field('Kalimat (bahasa Indonesia)', r.text, { required: true, full: true }),
        field('Terjemahan / susunan isyarat', r.translation),
        field('Penjelasan makna', r.explanation),
        field('Video kalimat', r.video.el, { required: true, full: true }),
        field('Audio / voice', r.audio.el, { full: true }),
        h('div', { class: 'field full', role: 'group', 'aria-label': `Bagian kalimat ${i + 1}` },
          h('span', {}, 'Bagian kalimat (kosakata · teks bagian · arti bagian)'), (renderParts(r), r.partsBox),
          h('div', { class: 'help' }, 'Urutan bagian = urutan isyarat. Pilih kosakata dari kamus, atau isi teks bagian bila belum ada di kamus.')))))
      : h('div', { class: 'empty' }, 'Belum ada kalimat. Tambahkan kalimat sesuai materi Anda.'));
  }
  renderItems();

  async function saveAll(publish) {
    clear(msg);
    const title = f.title.value.trim();
    const slug = f.slug.value.trim() || slugify(title);
    if (!title) { clear(msg, h('div', { class: 'alert error' }, 'Judul topik wajib diisi.')); return; }
    if (!/^[a-z0-9]+(-[a-z0-9]+)*$/.test(slug)) { clear(msg, h('div', { class: 'alert error' }, 'Slug hanya huruf kecil, angka, dan tanda hubung.')); return; }
    const empty = rows.findIndex((r) => !r.text.value.trim());
    if (empty >= 0) { clear(msg, h('div', { class: 'alert error' }, `Kalimat ${empty + 1} masih kosong.`)); return; }
    const v = {
      title, slug, category_id: f.category_id.value || null, description: f.description.value.trim() || null,
      context_note: f.context_note.value.trim() || null, sort_order: parseInt(f.sort_order.value, 10) || 0,
      is_premium: premium.input.checked, thumbnail_asset_id: thumb.getValue(),
      source_note: f.source_note.value.trim() || null, validated_by: f.validated_by.value.trim() || null, verified_at: f.verified_at.value || null,
    };
    try {
      let mid = id;
      if (id) unwrap(await sb.from('conversation_modules').update(v).eq('id', id));
      else mid = unwrap(await sb.from('conversation_modules').insert({ ...v, status: 'draft' }).select('id').single()).id;
      await rpc('admin_save_conversation_items', { p_module_id: mid, p_items: rows.map((r) => ({
        id: r.id, speaker_label: r.speaker.value.trim() || 'A', text_id: r.text.value.trim(),
        translation: r.translation.value.trim(), explanation: r.explanation.value.trim(), context_note: r.context.value.trim(),
        sign_id: r.sign_id, video_asset_id: r.video.getValue(), audio_asset_id: r.audio.getValue(),
        parts: r.parts.map((p) => ({ sign_id: p.sign.value || null, part_text: p.text.value.trim(), meaning: p.meaning.value.trim() }))
          .filter((p) => p.sign_id || p.part_text),
      })) });
      if (publish) {
        const issues = await setContentStatus('conversation', 'conversation_modules', mid, 'published');
        if (issues.length) {
          const alert = issuesAlert(issues, 'Tersimpan sebagai Draft. Belum bisa dipublikasikan — yang masih kurang:');
          navigate(`conversations/${mid}`, { flash: alert });
          return;
        }
        toast('Topik dipublikasikan.', 'ok');
      } else toast('Topik & kalimat tersimpan.', 'ok');
      navigate('conversations');
    } catch (e) { clear(msg, h('div', { class: 'alert error', role: 'alert' }, e.message)); }
  }

  async function remove() {
    if (!(await confirmDialog({ title: 'Hapus topik', message: `Hapus topik "${mod.title}" beserta seluruh kalimatnya? Progres pengguna untuk topik ini ikut terhapus.`, danger: true, confirmLabel: 'Hapus' }))) return;
    try { unwrap(await sb.from('conversation_modules').delete().eq('id', id)); toast('Topik dihapus.', 'ok'); navigate('conversations'); } catch (e) { toast(e.message, 'error'); }
  }

  clear(root,
    h('div', { class: 'page-head' }, h('button', { class: 'btn ghost', type: 'button', onclick: () => navigate('conversations') }, '‹ Kembali'),
      h('h1', {}, id ? 'Ubah topik percakapan' : 'Tambah topik percakapan'), id ? statusBadge(mod.status) : null),
    msg,
    h('form', { class: 'stack', onsubmit: (e) => { e.preventDefault(); saveAll(false); } },
      h('div', { class: 'card' }, h('h2', {}, 'Topik'), h('div', { class: 'form-grid' },
        field('Judul topik', f.title, { required: true }), field('Slug', f.slug, { help: 'Otomatis dari judul.' }),
        field('Kategori', f.category_id), field('Urutan', f.sort_order),
        field('Deskripsi', f.description, { full: true }), field('Konteks penggunaan', f.context_note, { full: true }),
        field('Thumbnail', thumb.el, { full: true }), h('div', { class: 'full' }, premium.el),
        field('Sumber materi', f.source_note, { required: true }), field('Divalidasi oleh', f.validated_by, { required: true }),
        field('Tanggal verifikasi', f.verified_at, { required: true }))),
      h('div', { class: 'card' }, h('div', { class: 'page-head' }, h('h2', { style: { margin: 0 } }, 'Kalimat'), h('span', { class: 'spacer' }),
        h('button', { class: 'btn secondary', type: 'button', onclick: () => { rows.push(makeItem()); renderItems(); } }, '+ Tambah kalimat')), list),
      h('div', { class: 'form-actions' },
        id ? h('button', { class: 'btn danger', type: 'button', onclick: remove, style: { marginRight: 'auto' } }, 'Hapus topik') : null,
        h('button', { class: 'btn secondary', type: 'submit' }, mod.status === 'published' ? 'Simpan perubahan' : 'Simpan sebagai Draft'),
        mod.status !== 'published' ? h('button', { class: 'btn success', type: 'button', onclick: () => saveAll(true) }, 'Simpan & Publikasikan') : null)));
}
