// ⚠️ HANYA UNTUK UJI LOKAL — bukan bagian dari produk.
// Emulator kecil subset API Supabase (Auth password, PostgREST, Storage) di atas
// PostgreSQL ASLI dengan peran `authenticated`/`anon` dan klaim JWT, sehingga
// CMS (supabase-js asli di Chromium) diuji terhadap RLS, trigger, dan RPC yang
// sama persis dengan migrasi produksi. Docker/PostgREST tidak tersedia di
// lingkungan pembuatan, karena itu emulator ini dibuat.
//
// Subset yang didukung = yang dipakai CMS: select kolom (tanpa embed), filter
// eq/neq/gt/gte/lt/lte/like/ilike/is/in/not.is, or=(...), order, limit/offset,
// count=exact, single/maybeSingle, insert/update/delete (+return), rpc;
// storage upload (raw), sign, unduh bertanda tangan, remove.
import http from 'node:http';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import pg from 'pg';

const PORT = Number(process.env.SHIM_PORT || 54321);
const STATIC_DIR = process.env.STATIC_DIR || null;      // folder CMS (opsional)
const STATIC_PORT = Number(process.env.STATIC_PORT || 8088);
const SECRET = 'uji-lokal-bukan-rahasia-produksi-0123456789';
const FILES = process.env.FILES_DIR || '/tmp/bisindo-shim-files';
fs.mkdirSync(FILES, { recursive: true });

const pool = new pg.Pool({ host: process.env.PGHOST || '/tmp', port: Number(process.env.PGPORT || 5433),
  user: process.env.PGUSER || 'postgres', database: process.env.PGDATABASE || 'cms_e2e', max: 8 });
// jsonb/json/timestamptz dikembalikan sebagai teks mentah lalu dibungkus json_agg di SQL.
const log = [];

// ------------------------------------------------------------------ JWT
const b64u = (b) => Buffer.from(b).toString('base64url');
function sign(payload) {
  const h = b64u(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
  const p = b64u(JSON.stringify(payload));
  return `${h}.${p}.${crypto.createHmac('sha256', SECRET).update(`${h}.${p}`).digest('base64url')}`;
}
function verify(token) {
  const [h, p, s] = (token || '').split('.');
  if (!s) return null;
  const want = crypto.createHmac('sha256', SECRET).update(`${h}.${p}`).digest('base64url');
  if (want.length !== s.length || !crypto.timingSafeEqual(Buffer.from(want), Buffer.from(s))) return null;
  const claims = JSON.parse(Buffer.from(p, 'base64url').toString());
  if (claims.exp && claims.exp * 1000 < Date.now()) return null;
  return claims;
}
const claimsOf = (req) => verify((req.headers.authorization || '').replace(/^Bearer /i, '')) || { role: 'anon' };

// ------------------------------------------------------------------ util
const ID = /^[a-z_][a-z0-9_]*$/;
const ident = (s) => { if (!ID.test(s)) throw httpErr(400, 'PGRST100', `identifier tidak valid: ${s}`); return `"${s}"`; };
function httpErr(status, code, message, extra = {}) { const e = new Error(message); e.status = status; e.body = { code, message, details: null, hint: null, ...extra }; return e; }
function cors(res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Headers', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,PATCH,PUT,DELETE,OPTIONS,HEAD');
  res.setHeader('Access-Control-Expose-Headers', 'Content-Range, Content-Type');
}
function send(res, status, body, headers = {}) {
  cors(res);
  for (const [k, v] of Object.entries(headers)) res.setHeader(k, v);
  if (body === undefined) { res.statusCode = status; res.end(); return; }
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  res.statusCode = status;
  res.end(typeof body === 'string' ? body : JSON.stringify(body));
}
const readBody = (req) => new Promise((resolve, reject) => {
  const chunks = []; req.on('data', (c) => chunks.push(c)); req.on('end', () => resolve(Buffer.concat(chunks))); req.on('error', reject);
});

async function asUser(claims, fn) {
  const c = await pool.connect();
  try {
    await c.query('begin');
    await c.query(`set local role ${claims.role === 'authenticated' ? 'authenticated' : 'anon'}`);
    await c.query(`select set_config('request.jwt.claims', $1, true)`, [JSON.stringify(claims)]);
    const out = await fn(c);
    await c.query('commit');
    return out;
  } catch (e) {
    await c.query('rollback').catch(() => {});
    throw e;
  } finally { c.release(); }
}
function pgToHttp(e, claims) {
  if (e.status) return e;
  const status = e.code === '42501' ? (claims.role === 'anon' ? 401 : 403)
    : ['23505', '23503'].includes(e.code) ? 409 : e.code === 'P0002' ? 404 : 400;
  return httpErr(status, e.code, e.message, { details: e.detail || null, hint: e.hint || null });
}

// ------------------------------------------------------------------ PostgREST subset
function parseFilter(col, expr, params) {
  let neg = false;
  if (expr.startsWith('not.')) { neg = true; expr = expr.slice(4); }
  const dot = expr.indexOf('.');
  const op = expr.slice(0, dot); const val = expr.slice(dot + 1);
  const c = ident(col);
  let sql;
  const p = (v) => { params.push(v); return `$${params.length}`; };
  switch (op) {
    case 'eq': sql = `${c}::text = ${p(val)}`; break;
    case 'neq': sql = `${c}::text <> ${p(val)}`; break;
    case 'gt': case 'gte': case 'lt': case 'lte': {
      const o = { gt: '>', gte: '>=', lt: '<', lte: '<=' }[op]; sql = `${c} ${o} ${p(val)}`; break;
    }
    case 'like': sql = `${c}::text like ${p(val.replace(/\*/g, '%'))}`; break;
    case 'ilike': sql = `${c}::text ilike ${p(val.replace(/\*/g, '%'))}`; break;
    case 'is': {
      const v = { null: 'null', true: 'true', false: 'false' }[val.toLowerCase()];
      if (!v) throw httpErr(400, 'PGRST100', `nilai is tidak valid: ${val}`);
      sql = `${c} is ${v}`; break;
    }
    case 'in': {
      const items = val.replace(/^\(|\)$/g, '').split(',').map((s) => s.replace(/^"|"$/g, ''));
      sql = `${c}::text = any(${p(items)}::text[])`; break;
    }
    default: throw httpErr(400, 'PGRST100', `operator tidak didukung: ${op}`);
  }
  return neg ? `not (${sql})` : sql;
}
function splitTop(s) {
  const out = []; let depth = 0; let cur = '';
  for (const ch of s) {
    if (ch === '(') depth++; if (ch === ')') depth--;
    if (ch === ',' && depth === 0) { out.push(cur); cur = ''; } else cur += ch;
  }
  if (cur) out.push(cur);
  return out;
}
function buildWhere(searchParams, params) {
  const conds = [];
  for (const [k, v] of searchParams) {
    if (['select', 'order', 'limit', 'offset', 'columns', 'on_conflict'].includes(k)) continue;
    if (k === 'or') {
      const parts = splitTop(v.replace(/^\(|\)$/g, '')).map((part) => {
        const i = part.indexOf('.'); return parseFilter(part.slice(0, i), part.slice(i + 1), params);
      });
      conds.push(`(${parts.join(' or ')})`);
    } else conds.push(parseFilter(k, v, params));
  }
  return conds.length ? `where ${conds.join(' and ')}` : '';
}
function buildSelect(sel) {
  if (!sel || sel === '*') return '*';
  return sel.split(',').map((s) => s.trim()).filter(Boolean).map((s) => {
    if (/[():!]/.test(s)) throw httpErr(400, 'PGRST100', `embed tidak didukung emulator: ${s}`);
    return ident(s);
  }).join(', ');
}
function buildOrder(order) {
  if (!order) return '';
  return 'order by ' + order.split(',').map((o) => {
    const [col, dir, nulls] = o.split('.');
    return `${ident(col)} ${dir === 'desc' ? 'desc' : 'asc'}${nulls === 'nullsfirst' ? ' nulls first' : nulls === 'nullslast' ? ' nulls last' : ''}`;
  }).join(', ');
}
const jsonVal = (v) => (v !== null && typeof v === 'object' ? JSON.stringify(v) : v);

async function restTable(req, res, url, table) {
  const claims = claimsOf(req);
  const sp = url.searchParams;
  const prefer = req.headers.prefer || '';
  const wantObject = (req.headers.accept || '').includes('vnd.pgrst.object+json');
  const t = `public.${ident(table)}`;
  const params = [];
  let sql; let countSql = null;
  const body = ['POST', 'PATCH'].includes(req.method) ? JSON.parse((await readBody(req)).toString() || 'null') : null;

  if (req.method === 'GET' || req.method === 'HEAD') {
    const where = buildWhere(sp, params);
    sql = `select ${buildSelect(sp.get('select'))} from ${t} ${where} ${buildOrder(sp.get('order'))}`
      + (sp.get('limit') ? ` limit ${Number(sp.get('limit'))}` : '') + (sp.get('offset') ? ` offset ${Number(sp.get('offset'))}` : '');
    if (/count=exact/.test(prefer)) countSql = `select count(*)::int n from ${t} ${where}`;
  } else if (req.method === 'POST') {
    const rows = Array.isArray(body) ? body : [body];
    const cols = [...new Set(rows.flatMap((r) => Object.keys(r)))];
    const values = rows.map((r) => `(${cols.map((c) => (c in r ? (params.push(jsonVal(r[c])), `$${params.length}`) : 'default')).join(', ')})`);
    const ret = /return=representation/.test(prefer) ? buildSelect(sp.get('select')) : null;
    sql = { dml: `insert into ${t} (${cols.map(ident).join(', ')}) values ${values.join(', ')}`, ret };
  } else if (req.method === 'PATCH') {
    const sets = Object.entries(body).map(([k, v]) => { params.push(jsonVal(v)); return `${ident(k)} = $${params.length}`; });
    const where = buildWhere(sp, params);
    const ret = /return=representation/.test(prefer) ? buildSelect(sp.get('select')) : null;
    sql = { dml: `update ${t} set ${sets.join(', ')} ${where}`, ret };
  } else if (req.method === 'DELETE') {
    const where = buildWhere(sp, params);
    const ret = /return=representation/.test(prefer) ? buildSelect(sp.get('select')) : null;
    sql = { dml: `delete from ${t} ${where}`, ret };
  } else throw httpErr(405, 'PGRST000', 'method');

  const out = await asUser(claims, async (c) => {
    const text = typeof sql === 'string'
      ? `select coalesce(json_agg(q), '[]'::json) as j from (${sql}) q`
      : sql.ret ? `with w as (${sql.dml} returning *) select coalesce(json_agg(q), '[]'::json) as j from (select ${sql.ret} from w) q`
        : `with w as (${sql.dml} returning 1) select '[]'::json as j from (select count(*) from w) x`;
    const r = await c.query(text, params);
    const n = countSql ? (await c.query(countSql, params.slice(0, (countSql.match(/\$\d+/g) || []).length))).rows[0].n : null;
    return { rows: r.rows[0].j, n };
  });
  const headers = {};
  if (countSql !== null) {
    const off = Number(sp.get('offset') || 0);
    headers['Content-Range'] = out.rows.length ? `${off}-${off + out.rows.length - 1}/${out.n}` : `*/${out.n}`;
  }
  const writeNoReturn = req.method !== 'GET' && !/return=representation/.test(prefer);
  if (writeNoReturn) return send(res, req.method === 'POST' ? 201 : 204, undefined, headers);
  if (wantObject) {
    if (out.rows.length !== 1) {
      throw httpErr(406, 'PGRST116', 'JSON object requested, multiple (or no) rows returned',
        { details: `The result contains ${out.rows.length} rows` });
    }
    return send(res, 200, out.rows[0], headers);
  }
  return send(res, req.method === 'POST' ? 201 : 200, out.rows, headers);
}

const fnCache = new Map();
async function rpcCall(req, res, fn) {
  const claims = claimsOf(req);
  const args = JSON.parse((await readBody(req)).toString() || '{}');
  if (!ID.test(fn)) throw httpErr(404, 'PGRST202', 'fungsi tidak ditemukan');
  if (!fnCache.has(fn)) {
    const r = await pool.query(`select p.proargnames, array(select format_type(t, null) from unnest(p.proargtypes) t) as types,
                                       format_type(p.prorettype, null) as ret, p.proretset
                                from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                                where n.nspname = 'public' and p.proname = $1`, [fn]);
    if (!r.rows.length) throw httpErr(404, 'PGRST202', `Could not find the function public.${fn}`);
    fnCache.set(fn, r.rows[0]);
  }
  const meta = fnCache.get(fn);
  const params = []; const named = [];
  for (const [k, v] of Object.entries(args)) {
    const i = (meta.proargnames || []).indexOf(k);
    if (i < 0) throw httpErr(404, 'PGRST202', `argumen tidak dikenal ${k} untuk ${fn}`);
    const type = meta.types[i];
    params.push(type.startsWith('json') ? JSON.stringify(v) : v);
    named.push(`${ident(k)} => $${params.length}::${type}`);
  }
  const call = `public.${ident(fn)}(${named.join(', ')})`;
  const sql = meta.proretset ? `select coalesce(json_agg(q), '[]'::json) as j from ${call} q` : `select to_json(${call}) as j`;
  const out = await asUser(claims, (c) => c.query(sql, params));
  const j = out.rows[0].j;
  if (meta.ret === 'void') return send(res, 200, 'null');
  return send(res, 200, JSON.stringify(j));
}

// ------------------------------------------------------------------ Auth subset
async function auth(req, res, url) {
  const p = url.pathname.replace('/auth/v1', '');
  if (p === '/token') {
    const body = JSON.parse((await readBody(req)).toString() || '{}');
    let user;
    if (url.searchParams.get('grant_type') === 'password') {
      const r = await pool.query(`select u.id, u.email, u.created_at from auth.users u join t_auth.creds c on c.user_id = u.id
                                  where lower(u.email) = lower($1) and c.password = $2`, [body.email, body.password]);
      if (!r.rows.length) return send(res, 400, { code: 400, error_code: 'invalid_credentials', msg: 'Invalid login credentials' });
      user = r.rows[0];
      await pool.query('update auth.users set last_sign_in_at = now() where id = $1', [user.id]);
    } else if (url.searchParams.get('grant_type') === 'refresh_token') {
      const claims = verify(body.refresh_token);
      if (!claims) return send(res, 400, { code: 400, error_code: 'refresh_token_not_found', msg: 'Invalid Refresh Token' });
      user = (await pool.query('select id, email, created_at from auth.users where id = $1', [claims.sub])).rows[0];
    } else return send(res, 400, { msg: 'unsupported grant' });
    const now = Math.floor(Date.now() / 1000);
    const access = sign({ sub: user.id, role: 'authenticated', aud: 'authenticated', email: user.email, iat: now, exp: now + 3600 });
    return send(res, 200, {
      access_token: access, token_type: 'bearer', expires_in: 3600, expires_at: now + 3600,
      refresh_token: sign({ sub: user.id, kind: 'refresh', iat: now, exp: now + 86400 }),
      user: { id: user.id, aud: 'authenticated', role: 'authenticated', email: user.email, app_metadata: { provider: 'email' }, user_metadata: {}, created_at: user.created_at },
    });
  }
  if (p === '/user') {
    const c = claimsOf(req);
    if (!c.sub) return send(res, 401, { msg: 'invalid JWT' });
    return send(res, 200, { id: c.sub, aud: 'authenticated', role: 'authenticated', email: c.email, app_metadata: {}, user_metadata: {} });
  }
  if (p === '/logout') return send(res, 204);
  return send(res, 404, { msg: 'not found' });
}

// ------------------------------------------------------------------ Storage subset
const fileOf = (bucket, name) => path.join(FILES, bucket, ...name.split('/').map((s) => s.replace(/\.\./g, '_')));
async function storage(req, res, url) {
  const claims = claimsOf(req);
  const p = decodeURIComponent(url.pathname.replace('/storage/v1', ''));
  let m;
  if (req.method === 'POST' && (m = p.match(/^\/object\/sign\/([^/]+)\/(.+)$/))) {
    const [, bucket, name] = m;
    const ok = await asUser(claims, (c) => c.query('select 1 from storage.objects where bucket_id = $1 and name = $2', [bucket, name]));
    if (!ok.rows.length) return send(res, 400, { statusCode: '404', error: 'not_found', message: 'Object not found' });
    const token = sign({ url: `${bucket}/${name}`, exp: Math.floor(Date.now() / 1000) + 3600 });
    return send(res, 200, { signedURL: `/object/sign/${bucket}/${name.split('/').map(encodeURIComponent).join('/')}?token=${token}` });
  }
  if (req.method === 'GET' && (m = p.match(/^\/object\/sign\/([^/]+)\/(.+)$/))) {
    const [, bucket, name] = m;
    const t = verify(url.searchParams.get('token'));
    if (!t || t.url !== `${bucket}/${name}`) return send(res, 400, { error: 'InvalidSignature' });
    const f = fileOf(bucket, name);
    if (!fs.existsSync(f)) return send(res, 404, { error: 'not_found' });
    const meta = JSON.parse(fs.readFileSync(f + '.meta.json', 'utf8'));
    cors(res); res.setHeader('Content-Type', meta.type); res.setHeader('Accept-Ranges', 'bytes');
    const data = fs.readFileSync(f);
    const range = req.headers.range && /bytes=(\d*)-(\d*)/.exec(req.headers.range);
    if (range) {
      const start = Number(range[1] || 0); const end = range[2] ? Number(range[2]) : data.length - 1;
      res.statusCode = 206; res.setHeader('Content-Range', `bytes ${start}-${end}/${data.length}`);
      return res.end(data.subarray(start, end + 1));
    }
    res.statusCode = 200; return res.end(data);
  }
  if (req.method === 'POST' && (m = p.match(/^\/object\/([^/]+)\/(.+)$/))) {
    const [, bucket, name] = m;
    const data = await readBody(req);
    const type = (req.headers['content-type'] || 'application/octet-stream').split(';')[0];
    const b = (await pool.query('select file_size_limit, allowed_mime_types from storage.buckets where id = $1', [bucket])).rows[0];
    if (!b) return send(res, 400, { statusCode: '404', error: 'Bucket not found', message: 'Bucket not found' });
    if (b.file_size_limit && data.length > Number(b.file_size_limit)) return send(res, 413, { statusCode: '413', error: 'Payload too large', message: 'The object exceeded the maximum allowed size' });
    if (b.allowed_mime_types && !b.allowed_mime_types.includes(type)) return send(res, 415, { statusCode: '415', error: 'invalid_mime_type', message: `mime type ${type} is not supported` });
    try {
      await asUser(claims, (c) => c.query('insert into storage.objects (bucket_id, name, owner) values ($1, $2, $3)', [bucket, name, claims.sub || null]));
    } catch (e) {
      if (e.code === '42501') return send(res, 403, { statusCode: '403', error: 'Unauthorized', message: 'new row violates row-level security policy' });
      if (e.code === '23505') return send(res, 409, { statusCode: '409', error: 'Duplicate', message: 'The resource already exists' });
      throw e;
    }
    const f = fileOf(bucket, name);
    fs.mkdirSync(path.dirname(f), { recursive: true });
    fs.writeFileSync(f, data); fs.writeFileSync(f + '.meta.json', JSON.stringify({ type, size: data.length }));
    return send(res, 200, { Key: `${bucket}/${name}`, Id: crypto.randomUUID() });
  }
  if (req.method === 'DELETE' && (m = p.match(/^\/object\/([^/]+)\/?$/))) {
    const [, bucket] = m;
    const { prefixes = [] } = JSON.parse((await readBody(req)).toString() || '{}');
    const r = await asUser(claims, (c) => c.query('delete from storage.objects where bucket_id = $1 and name = any($2::text[]) returning name', [bucket, prefixes]));
    for (const { name } of r.rows) { const f = fileOf(bucket, name); fs.rmSync(f, { force: true }); fs.rmSync(f + '.meta.json', { force: true }); }
    return send(res, 200, r.rows.map((x) => ({ name: x.name, bucket_id: bucket })));
  }
  return send(res, 404, { error: 'not_found' });
}

// ------------------------------------------------------------------ server
http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`);
  if (req.method === 'OPTIONS') return send(res, 204);
  const claims = claimsOf(req);
  try {
    if (url.pathname.startsWith('/auth/v1')) return await auth(req, res, url);
    if (url.pathname.startsWith('/storage/v1')) return await storage(req, res, url);
    let m;
    if ((m = url.pathname.match(/^\/rest\/v1\/rpc\/([a-z0-9_]+)$/))) return await rpcCall(req, res, m[1]);
    if ((m = url.pathname.match(/^\/rest\/v1\/([a-z0-9_]+)$/))) return await restTable(req, res, url, m[1]);
    if (url.pathname === '/__log') return send(res, 200, log);
    return send(res, 404, { message: 'not found' });
  } catch (e) {
    const he = pgToHttp(e, claims);
    log.push({ at: new Date().toISOString(), method: req.method, path: url.pathname + url.search, status: he.status, body: he.body });
    if (!e.status && !e.code) console.error(e);
    return send(res, he.status || 500, he.body || { message: e.message });
  }
}).listen(PORT, '127.0.0.1', () => console.log(`shim API http://127.0.0.1:${PORT}`));

if (STATIC_DIR) {
  const types = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.svg': 'image/svg+xml', '.json': 'application/json' };
  http.createServer((req, res) => {
    const u = new URL(req.url, 'http://x');
    let f = path.join(STATIC_DIR, path.normalize(decodeURIComponent(u.pathname)).replace(/^(\.\.[/\\])+/, ''));
    if (u.pathname === '/') f = path.join(STATIC_DIR, 'index.html');
    if (u.pathname === '/config.js') {
      res.setHeader('Content-Type', 'text/javascript');
      return res.end(`window.BISINDO_CONFIG = { SUPABASE_URL: 'http://127.0.0.1:${PORT}', SUPABASE_ANON_KEY: 'uji-lokal-anon', MEDIA_BUCKET: 'bisindo-media' };`);
    }
    if (!f.startsWith(STATIC_DIR) || !fs.existsSync(f) || fs.statSync(f).isDirectory()) { res.statusCode = 404; return res.end('404'); }
    res.setHeader('Content-Type', types[path.extname(f)] || 'application/octet-stream');
    res.end(fs.readFileSync(f));
  }).listen(STATIC_PORT, '127.0.0.1', () => console.log(`CMS http://127.0.0.1:${STATIC_PORT}`));
}
