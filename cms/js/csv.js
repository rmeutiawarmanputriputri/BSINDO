// Parser CSV kecil (RFC 4180): tanda kutip, kutip ganda, baris baru di dalam
// sel, BOM, CRLF. Pemisah dideteksi otomatis (koma atau titik koma — Excel
// berbahasa Indonesia sering memakai titik koma).

export function detectDelimiter(text) {
  const first = text.replace(/^﻿/, '').split(/\r?\n/)[0] || '';
  let inQ = false; let commas = 0; let semis = 0; let tabs = 0;
  for (const ch of first) {
    if (ch === '"') inQ = !inQ;
    else if (!inQ && ch === ',') commas++;
    else if (!inQ && ch === ';') semis++;
    else if (!inQ && ch === '\t') tabs++;
  }
  if (tabs > commas && tabs > semis) return '\t';
  return semis > commas ? ';' : ',';
}

export function parseCsv(text, delimiter = detectDelimiter(text)) {
  const s = text.replace(/^﻿/, '');
  const rows = []; let row = []; let cell = ''; let inQ = false;
  for (let i = 0; i < s.length; i++) {
    const ch = s[i];
    if (inQ) {
      if (ch === '"') {
        if (s[i + 1] === '"') { cell += '"'; i++; } else inQ = false;
      } else cell += ch;
      continue;
    }
    if (ch === '"' && cell === '') inQ = true;
    else if (ch === delimiter) { row.push(cell); cell = ''; }
    else if (ch === '\n' || ch === '\r') {
      if (ch === '\r' && s[i + 1] === '\n') i++;
      row.push(cell); rows.push(row); row = []; cell = '';
    } else cell += ch;
  }
  if (inQ) throw new Error('CSV tidak valid: tanda kutip tidak ditutup.');
  if (cell !== '' || row.length) { row.push(cell); rows.push(row); }
  return rows.filter((r) => r.some((c) => c.trim() !== ''));
}

/** CSV → array objek berdasarkan baris header. */
export function csvToObjects(text) {
  const rows = parseCsv(text);
  if (rows.length < 1) throw new Error('Berkas kosong.');
  const header = rows[0].map((h) => h.trim().toLowerCase());
  if (header.some((h) => !h)) throw new Error('Baris header berisi kolom kosong.');
  const dup = header.find((h, i) => header.indexOf(h) !== i);
  if (dup) throw new Error(`Kolom "${dup}" muncul dua kali di header.`);
  return { header, rows: rows.slice(1).map((r) => Object.fromEntries(header.map((h, i) => [h, (r[i] ?? '').trim()]))) };
}

export function toCsv(header, rows = []) {
  const esc = (v) => { const s = v == null ? '' : String(v); return /[",\n\r;]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s; };
  return [header.map(esc).join(','), ...rows.map((r) => header.map((h) => esc(r[h])).join(','))].join('\r\n') + '\r\n';
}
