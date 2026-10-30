// Akses Supabase untuk CMS. Semua otorisasi ditegakkan DI DATABASE
// (RLS + RPC SECURITY DEFINER yang memeriksa is_admin()). CMS hanya memakai
// anon/publishable key + sesi login admin.

const cfg = window.BISINDO_CONFIG || {};
export const BUCKET = cfg.MEDIA_BUCKET || 'bisindo-media';
export const configOk = !!(cfg.SUPABASE_URL && cfg.SUPABASE_ANON_KEY && !/x{6,}/.test(cfg.SUPABASE_URL));

export const sb = configOk
  ? window.supabase.createClient(cfg.SUPABASE_URL, cfg.SUPABASE_ANON_KEY, {
      auth: { persistSession: true, autoRefreshToken: true, storageKey: 'bisindo-cms-auth' },
    })
  : null;

// ------------------------------------------------------------------ error
const MESSAGES = [
  [/not_admin|42501|permission denied|row-level security/i, 'Akses ditolak: hanya akun admin aktif yang boleh melakukan ini.'],
  [/media_in_use/i, 'Media masih dipakai materi lain.'],
  [/media_too_large/i, null],
  [/answer_key_invalid/i, null],
  [/cannot_demote_self/i, 'Anda tidak bisa menurunkan peran akun Anda sendiri.'],
  [/cannot_deactivate_self/i, 'Anda tidak bisa menonaktifkan akun Anda sendiri.'],
  [/expires_in_past/i, 'Tanggal berakhir Premium harus di masa depan.'],
  [/JWT expired|invalid JWT|refresh_token/i, 'Sesi berakhir. Silakan masuk lagi.'],
  [/Failed to fetch|NetworkError|network/i, 'Gagal terhubung ke server. Periksa koneksi internet.'],
  [/duplicate key|23505/i, 'Data sudah ada (duplikat). Periksa slug/nama yang unik.'],
  [/violates foreign key|23503/i, 'Data masih dirujuk data lain sehingga tidak bisa diubah/dihapus.'],
];

export function friendlyError(err) {
  if (!err) return 'Terjadi kesalahan.';
  const raw = [err.message, err.code, err.details, err.hint].filter(Boolean).join(' ');
  if (/publish_blocked:/.test(raw)) return 'Belum bisa dipublikasikan: ' + raw.split('publish_blocked:')[1].split(/\s(?:23514|Lengkapi)/)[0].trim();
  for (const [re, msg] of MESSAGES) {
    if (re.test(raw)) return msg || err.message.replace(/^\w+:\s*/, '');
  }
  if (err.code === '23514' || /check constraint/i.test(raw)) return 'Data tidak valid: ' + (err.message || '');
  return err.message || String(err);
}

/** Lempar Error berpesan ramah bila respons Supabase gagal. */
export function unwrap({ data, error, count }) {
  if (error) {
    const e = new Error(friendlyError(error));
    e.raw = error;
    throw e;
  }
  return count !== undefined && count !== null ? { data, count } : data;
}

export async function rpc(fn, args = {}) {
  return unwrap(await sb.rpc(fn, args));
}

export const escapeLike = (s) => s.replace(/[\\%_]/g, (c) => '\\' + c);

// ------------------------------------------------------------------ auth
export async function currentSession() {
  const { data } = await sb.auth.getSession();
  return data.session;
}
export async function signIn(email, password) {
  const { data, error } = await sb.auth.signInWithPassword({ email, password });
  if (error) {
    throw new Error(/invalid login credentials/i.test(error.message)
      ? 'Email atau kata sandi salah.'
      : /email not confirmed/i.test(error.message) ? 'Email belum diverifikasi.' : friendlyError(error));
  }
  return data.session;
}
export async function signOut() { await sb.auth.signOut(); }

/** Verifikasi peran admin DI SERVER (assert_admin memeriksa profiles.role & is_active). */
export async function loadAdminProfile(userId) {
  const { error } = await sb.rpc('assert_admin');
  if (error) return null;
  const p = unwrap(await sb.from('profiles').select('id, full_name, role, is_active').eq('id', userId).single());
  return p;
}

// ------------------------------------------------------------------ settings
let settingsCache = null; let settingsAt = 0;
export async function getSettings(force = false) {
  // Cache singkat (60 dtk) agar perubahan dari tab/admin lain cepat terbaca.
  if (!settingsCache || force || Date.now() - settingsAt > 60000) {
    const rows = unwrap(await sb.from('app_settings').select('key, value, is_public, description'));
    settingsCache = Object.fromEntries(rows.map((r) => [r.key, r.value]));
    settingsAt = Date.now();
  }
  return settingsCache;
}
export async function saveSetting(key, value) {
  unwrap(await sb.from('app_settings').update({ value }).eq('key', key));
  settingsCache = null;
}

// ------------------------------------------------------------------ categories cache
let catCache = null;
export async function getCategories(force = false) {
  if (!catCache || force) {
    catCache = unwrap(await sb.from('categories').select('id, slug, name, kind, is_active, sort_order').order('kind').order('sort_order').order('name'));
  }
  return catCache;
}
export const invalidateCategories = () => { catCache = null; };

// ------------------------------------------------------------------ media
export const MEDIA_RULES = {
  video: { mimes: ['video/mp4', 'video/webm'], ext: ['mp4', 'webm'], label: 'Video (MP4/WebM)' },
  audio: { mimes: ['audio/mpeg', 'audio/mp4', 'audio/aac', 'audio/x-m4a'], ext: ['mp3', 'm4a', 'aac', 'mp4'], label: 'Audio (MP3/M4A/AAC)' },
  image: { mimes: ['image/jpeg', 'image/png', 'image/webp'], ext: ['jpg', 'jpeg', 'png', 'webp'], label: 'Gambar (JPG/PNG/WebP)' },
};
const EXT_MIME = { mp4: null, webm: 'video/webm', mp3: 'audio/mpeg', m4a: 'audio/mp4', aac: 'audio/aac', jpg: 'image/jpeg', jpeg: 'image/jpeg', png: 'image/png', webp: 'image/webp' };

/** MIME yang dipakai + validasi format/ukuran. Melempar Error berpesan jelas. */
export async function validateMediaFile(file, kind) {
  const rules = MEDIA_RULES[kind];
  const ext = (file.name.split('.').pop() || '').toLowerCase();
  let mime = (file.type || '').toLowerCase();
  if (mime === 'audio/mp3') mime = 'audio/mpeg';
  if (mime === 'audio/m4a') mime = 'audio/x-m4a';
  if (!mime || !rules.mimes.includes(mime)) {
    mime = ext === 'mp4' ? (kind === 'audio' ? 'audio/mp4' : 'video/mp4') : EXT_MIME[ext];
  }
  if (!rules.ext.includes(ext) || !mime || !rules.mimes.includes(mime)) {
    throw new Error(`Format tidak didukung untuk ${kind}: .${ext || '?'}. Gunakan ${rules.label}.`);
  }
  const limits = (await getSettings()).media_limits || {};
  const maxMb = Math.min(50, Number(limits[`${kind}_max_mb`]) || { video: 50, audio: 20, image: 5 }[kind]);
  if (file.size <= 0) throw new Error('Berkas kosong.');
  if (file.size > maxMb * 1048576) {
    throw new Error(`Ukuran ${(file.size / 1048576).toFixed(1)} MB melebihi batas ${maxMb} MB untuk ${kind}. Kompres berkas atau ubah batas di Pengaturan.`);
  }
  return mime;
}

/** Baca durasi/dimensi dari berkas lokal (untuk metadata). */
export function probeMedia(file, kind) {
  return new Promise((resolve) => {
    const url = URL.createObjectURL(file);
    const done = (v) => { URL.revokeObjectURL(url); resolve(v); };
    const timer = setTimeout(() => done({ playable: false }), 15000);
    if (kind === 'image') {
      const img = new Image();
      img.onload = () => { clearTimeout(timer); done({ width: img.naturalWidth, height: img.naturalHeight, playable: true }); };
      img.onerror = () => { clearTimeout(timer); done({ playable: false }); };
      img.src = url;
      return;
    }
    const el = document.createElement(kind === 'video' ? 'video' : 'audio');
    el.preload = 'metadata';
    el.onloadedmetadata = () => {
      clearTimeout(timer);
      done({
        duration_ms: Number.isFinite(el.duration) ? Math.round(el.duration * 1000) : null,
        width: el.videoWidth || null, height: el.videoHeight || null, playable: true,
      });
    };
    el.onerror = () => { clearTimeout(timer); done({ playable: false }); };
    el.src = url;
  });
}

const uuid = () => (crypto.randomUUID ? crypto.randomUUID()
  : '10000000-1000-4000-8000-100000000000'.replace(/[018]/g, (c) => (c ^ crypto.getRandomValues(new Uint8Array(1))[0] & 15 >> c / 4).toString(16)));

export function newMediaPath(kind, fileName) {
  const ext = (fileName.split('.').pop() || 'bin').toLowerCase().replace(/[^a-z0-9]/g, '');
  const d = new Date();
  return `library/${kind}/${d.getUTCFullYear()}/${String(d.getUTCMonth() + 1).padStart(2, '0')}/${uuid()}.${ext}`;
}

/** Unggah langsung ke Storage dengan progres (XHR). onProgress(0..1). */
export async function uploadWithProgress(path, file, mime, onProgress) {
  const session = await currentSession();
  if (!session) throw new Error('Sesi berakhir. Silakan masuk lagi.');
  const url = `${cfg.SUPABASE_URL}/storage/v1/object/${BUCKET}/${path.split('/').map(encodeURIComponent).join('/')}`;
  await new Promise((resolve, reject) => {
    const xhr = new XMLHttpRequest();
    xhr.open('POST', url);
    xhr.setRequestHeader('Authorization', `Bearer ${session.access_token}`);
    xhr.setRequestHeader('apikey', cfg.SUPABASE_ANON_KEY);
    xhr.setRequestHeader('x-upsert', 'false');
    xhr.setRequestHeader('cache-control', 'max-age=3600');
    xhr.setRequestHeader('Content-Type', mime);
    xhr.upload.onprogress = (e) => { if (e.lengthComputable) onProgress?.(e.loaded / e.total); };
    xhr.onload = () => {
      if (xhr.status >= 200 && xhr.status < 300) { onProgress?.(1); resolve(); return; }
      let msg = `Unggah gagal (HTTP ${xhr.status}).`;
      try {
        const b = JSON.parse(xhr.responseText);
        const m = b.message || b.error || '';
        if (/exceeded the maximum allowed size|too large|413/i.test(m) || xhr.status === 413) msg = 'Unggah gagal: berkas melebihi batas ukuran server Storage.';
        else if (/mime type|not supported/i.test(m)) msg = 'Unggah gagal: format berkas ditolak server Storage.';
        else if (/row-level security|unauthorized|403/i.test(m) || xhr.status === 403) msg = 'Unggah ditolak: hanya admin yang boleh mengunggah.';
        else if (m) msg = `Unggah gagal: ${m}`;
      } catch { /* respons bukan JSON */ }
      reject(new Error(msg));
    };
    xhr.onerror = () => reject(new Error('Unggah gagal: koneksi terputus. Coba lagi.'));
    xhr.ontimeout = () => reject(new Error('Unggah gagal: waktu habis. Coba lagi dengan koneksi lebih stabil.'));
    xhr.send(file);
  });
}

export async function removeObjects(paths) {
  const { error } = await sb.storage.from(BUCKET).remove(paths);
  return !error;
}

/** Unggah berkas + buat baris media_assets. Membersihkan berkas bila penyimpanan DB gagal. */
export async function createMedia(file, kind, meta, onProgress) {
  const mime = await validateMediaFile(file, kind);
  const probe = await probeMedia(file, kind);
  const path = newMediaPath(kind, file.name);
  await uploadWithProgress(path, file, mime, onProgress);
  const { data, error } = await sb.from('media_assets').insert({
    kind, path, bucket: BUCKET, mime_type: mime, size_bytes: file.size,
    duration_ms: probe.duration_ms || null, width: probe.width || null, height: probe.height || null,
    title: meta.title || null, description: meta.description || null,
    original_filename: file.name.slice(0, 255), status: meta.status || 'published',
  }).select('*').single();
  if (error) {
    await removeObjects([path]);
    throw new Error(friendlyError(error));
  }
  return { asset: data, probe };
}

/** Ganti berkas media (id tetap). Berkas lama dihapus setelah DB diperbarui. */
export async function replaceMediaFile(asset, file, onProgress) {
  const mime = await validateMediaFile(file, asset.kind);
  const probe = await probeMedia(file, asset.kind);
  const path = newMediaPath(asset.kind, file.name);
  await uploadWithProgress(path, file, mime, onProgress);
  const { data, error } = await sb.rpc('admin_replace_media_file', {
    p_asset_id: asset.id, p_new_path: path, p_mime_type: mime, p_size_bytes: file.size,
    p_original_filename: file.name.slice(0, 255), p_duration_ms: probe.duration_ms || null,
    p_width: probe.width || null, p_height: probe.height || null,
  });
  if (error) {
    await removeObjects([path]);
    throw new Error(friendlyError(error));
  }
  forgetSignedUrl(data.old_path);
  const removed = await removeObjects([data.old_path]);
  return { removedOld: removed, oldPath: data.old_path };
}

const signed = new Map();
export async function signedUrl(path) {
  const hit = signed.get(path);
  if (hit && hit.exp > Date.now()) return hit.url;
  const { data, error } = await sb.storage.from(BUCKET).createSignedUrl(path, 3600);
  if (error) throw new Error(friendlyError(error));
  signed.set(path, { url: data.signedUrl, exp: Date.now() + 50 * 60 * 1000 });
  return data.signedUrl;
}
export const forgetSignedUrl = (path) => signed.delete(path);

const mediaCache = new Map();
export async function getMediaByIds(ids) {
  const need = [...new Set(ids.filter((id) => id && !mediaCache.has(id)))];
  if (need.length) {
    const rows = unwrap(await sb.from('media_assets').select('id, kind, path, title, original_filename, mime_type, size_bytes, duration_ms, status').in('id', need));
    rows.forEach((r) => mediaCache.set(r.id, r));
  }
  return Object.fromEntries(ids.filter(Boolean).map((id) => [id, mediaCache.get(id)]));
}
export const cacheMedia = (row) => mediaCache.set(row.id, row);
export const forgetMedia = (id) => mediaCache.delete(id);

/** Status materi: cek kekurangan di server lalu ubah status. Mengembalikan daftar kekurangan (kosong = sukses). */
export async function setContentStatus(type, table, id, status) {
  if (status === 'published') {
    const issues = await rpc('publish_issues', { p_type: type, p_id: id });
    if (issues.length) return issues;
  }
  unwrap(await sb.from(table).update({ status }).eq('id', id));
  return [];
}

export function slugify(s) {
  return (s || '').toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '')
    .replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 80);
}
