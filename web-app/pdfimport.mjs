// PDF import for the web version. pdf.js extracts the text and where each character sits;
// pdfbook.js (the phone app's Dart code compiled to JavaScript) works out columns, paragraphs
// and chapters, so a PDF reads the same in the browser as on the phone.

let pdfjsP;
function pdfjs(base) {
  return (pdfjsP ??= import(base + 'pdf.min.mjs').then(m => {
    if (typeof window !== 'undefined') m.GlobalWorkerOptions.workerSrc = base + 'pdf.worker.min.mjs';
    return m;
  }));
}

const r1 = v => Math.round(v * 10) / 10;

/// Text and per-character boxes of one page, in PDF coordinates (origin bottom-left), in the
/// shape pdfbook.js expects: { w, h, t, r: [left, top, right, bottom, ...] }.
export function pageInput(items, view) {
  const [x0, y0, x1, y1] = view;
  let t = '';
  const r = [];
  const push = (ch, l, top, right, bottom) => { t += ch; r.push(r1(l), r1(top), r1(right), r1(bottom)); };
  let lastR = null, lastY = 0;
  for (const it of items) {
    if (!('str' in it)) continue;
    const [a, b, c, d, e, f] = it.transform;
    const fs = Math.hypot(c, d) || Math.hypot(a, b) || it.height || 10;
    const str = it.str;
    // Sideways text (photo credits up the page edge) is left out of the reading text.
    const sideways = Math.abs(b) > Math.abs(a) * 0.5;
    if (str.length && !sideways) {
      const x = e - x0, y = f - y0;
      // pdf.js often splits words into separate items without a space between them.
      if (lastR !== null && Math.abs(y - lastY) < fs * 0.3 && x - lastR > fs * 0.12 && !/\s$/.test(t)) push(' ', 0, 0, 0, 0);
      const cw = (it.width || fs * 0.5 * str.length) / str.length;
      for (let k = 0; k < str.length; k++) {
        const ch = str[k], l = x + k * cw;
        // Rough glyph boxes: capitals and ascenders reach cap height, descenders drop below.
        let top = y + fs * 0.72, bottom = y;
        if (/[gjpqy]/.test(ch)) { top = y + fs * 0.5; bottom = y - fs * 0.22; }
        else if (/[a-z]/.test(ch) && !/[bdfhklt]/.test(ch)) top = y + fs * 0.5;
        else if (/[^\p{L}\p{N}]/u.test(ch)) top = y + fs * 0.5;
        if (/\s/.test(ch)) push(ch, 0, 0, 0, 0);
        else push(ch, l, top, l + cw, bottom);
      }
      lastR = x + (it.width || 0);
      lastY = y;
    }
    if (it.hasEOL) { push('\n', 0, 0, 0, 0); lastR = null; }
  }
  return { w: x1 - x0, h: y1 - y0, t, r };
}

/// Reads [data] (Uint8Array) and returns { title, chapters: [{ title, paras, pages }] }.
/// [base] is the folder holding pdf.js; [onProgress](done, total) reports pages read.
export async function parsePdf(data, name, { base = './pdfjs/', onProgress, lib } = {}) {
  const m = lib || await pdfjs(base);
  let doc;
  const task = m.getDocument({ data, cMapUrl: base + 'cmaps/', cMapPacked: true, isEvalSupported: false });
  try {
    doc = await task.promise;
  } catch (e) {
    throw new Error(/password/i.test(String(e?.name || e)) ? 'This PDF is password-protected.' : 'This PDF could not be opened. It may be damaged.');
  }
  try {
    const pages = [];
    for (let i = 1; i <= doc.numPages; i++) {
      try {
        const pg = await doc.getPage(i);
        const tc = await pg.getTextContent();
        pages.push(pageInput(tc.items, pg.view));
        pg.cleanup();
      } catch {
        pages.push({ w: 612, h: 792, t: '', r: [] }); // one unreadable page should not sink the whole book
      }
      onProgress?.(i, doc.numPages);
    }
    const outline = [];
    try {
      for (const o of (await doc.getOutline()) || []) {
        let dest = o.dest;
        if (typeof dest === 'string') dest = await doc.getDestination(dest);
        if (!Array.isArray(dest) || dest[0] == null) continue;
        const idx = typeof dest[0] === 'object' ? await doc.getPageIndex(dest[0]) : dest[0];
        outline.push([o.title || '', idx + 1]);
      }
    } catch {}
    const out = JSON.parse(globalThis.lanternPdfBook(JSON.stringify({ name, outline, pages })));
    if (out.error) throw new Error(out.error);
    return out;
  } finally {
    task.destroy();
  }
}
