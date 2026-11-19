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

/// Page input for a page read by OCR: [lines] of words { text, x0, y0, x1, y1 } in canvas pixels;
/// [toPdf](x, y) converts a canvas point to PDF coordinates (origin bottom-left). The shared Dart code
/// (segmentsFromOcr) splits merged columns and evens out line heights.
export function ocrPageInput(lines, toPdf, w, h) {
  const ocr = [];
  let t = '';
  for (const line of lines) {
    const out = [];
    for (const wd of line.words) {
      const [ax, ay] = toPdf(wd.x0, wd.y0), [bx, by] = toPdf(wd.x1, wd.y1);
      // top-down page points
      out.push([wd.text, r1(Math.min(ax, bx)), r1(h - Math.max(ay, by)), r1(Math.max(ax, bx)), r1(h - Math.min(ay, by))]);
    }
    if (out.length) { ocr.push(out); t += out.map(x => x[0]).join(' ') + '\n'; }
  }
  return { w, h, t, ocr };
}

const letters = s => (s.match(/[\p{L}\p{N}]/gu) || []).length;

/// Reads [data] (Uint8Array) and returns { title, chapters: [{ title, paras, pages }] }.
/// Options: [base] folder holding pdf.js; [onProgress](done, total, what); [askOcr](pages) → Promise<bool>,
/// asked when the PDF looks scanned; [ocr](page, pdfjsLib) → Promise<pageInput> recognizes one page.
export async function parsePdf(data, name, { base = './pdfjs/', onProgress, lib, askOcr, ocr } = {}) {
  const m = lib || await pdfjs(base);
  let doc;
  const task = m.getDocument({ data, cMapUrl: base + 'cmaps/', cMapPacked: true, standardFontDataUrl: base + 'standard_fonts/',
    wasmUrl: base + 'wasm/', iccUrl: base + 'iccs/', isEvalSupported: false });
  try {
    doc = await task.promise;
  } catch (e) {
    throw new Error(/password/i.test(String(e?.name || e)) ? 'This PDF is password-protected.' : `This PDF could not be opened (${e?.message || e}).`);
  }
  try {
    const pages = [], failed = [];
    for (let i = 1; i <= doc.numPages; i++) {
      try {
        const pg = await doc.getPage(i);
        const tc = await pg.getTextContent();
        pages.push(pageInput(tc.items, pg.view));
        pg.cleanup();
      } catch (e) {
        failed.push(`page ${i}: ${e?.message || e}`);
        pages.push({ w: 612, h: 792, t: '', r: [] }); // one unreadable page should not sink the whole book
      }
      onProgress?.(i, doc.numPages, 'read');
    }
    const counts = pages.map(p => letters(p.t));
    const total = counts.reduce((a, b) => a + b, 0);
    const empty = counts.map((c, i) => c < 25 ? i : -1).filter(i => i >= 0);
    if (failed.length) console.warn('Lantern: pages pdf.js could not read', failed);
    console.info(`Lantern: pdf.js found ${total} letters on ${doc.numPages} pages (${empty.length} pages with almost none)`);
    if (failed.length > doc.numPages / 2) throw new Error(`The browser could not read ${failed.length} of ${doc.numPages} pages (${failed[0]}).`);
    // Scanned (picture-only) pages: offer text recognition.
    const scanned = total < 40 * Math.min(doc.numPages, 5) || empty.length >= doc.numPages * 0.6;
    let didOcr = false;
    if (scanned && empty.length && ocr && (!askOcr || await askOcr(empty.length))) {
      didOcr = true;
      for (let k = 0; k < empty.length; k++) {
        const i = empty[k];
        try {
          const pg = await doc.getPage(i + 1);
          pages[i] = await ocr(pg, m);
          pg.cleanup();
        } catch (e) { console.warn('Lantern: OCR failed on page', i + 1, e); }
        onProgress?.(k + 1, empty.length, 'ocr');
      }
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
    if (out.error) {
      if (/no text layer/.test(out.error) && !scanned) throw new Error(`${out.error} (The browser found ${total} letters in ${doc.numPages} pages.)`);
      throw new Error(didOcr ? 'Text recognition found too little readable text in this PDF.' : out.error);
    }
    return out;
  } finally {
    task.destroy();
  }
}
