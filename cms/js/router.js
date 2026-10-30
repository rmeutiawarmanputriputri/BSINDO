// Router hash sederhana: #/vocabulary, #/vocabulary/<id>, dst.
let flash = null;
export function navigate(path, opts = {}) {
  flash = opts.flash || null;
  const target = '#/' + path.replace(/^#?\/?/, '');
  if (location.hash === target) window.dispatchEvent(new HashChangeEvent('hashchange'));
  else location.hash = target;
}
export function takeFlash() { const f = flash; flash = null; return f; }
export function currentPath() { return location.hash.replace(/^#\/?/, '').split('?')[0]; }
export function matchRoute(routes, path) {
  const parts = path.split('/').filter(Boolean);
  for (const r of routes) {
    const rp = r.path.split('/').filter(Boolean);
    if (rp.length !== parts.length) continue;
    const params = {};
    if (rp.every((seg, i) => (seg.startsWith(':') ? ((params[seg.slice(1)] = decodeURIComponent(parts[i])), true) : seg === parts[i]))) return { route: r, params };
  }
  return null;
}
