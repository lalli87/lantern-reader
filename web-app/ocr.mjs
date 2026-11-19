// Text recognition (OCR) for scanned PDF pages in the web version, with Tesseract.js.
// The recognizer itself (about 6 MB: engine and English model) downloads from the jsDelivr CDN the first
// time it is used and is cached by the browser afterwards.
import { ocrPageInput } from './pdfimport.mjs';

let workerP = null;
function loadScript(src) {
  return new Promise((res, rej) => {
    const s = document.createElement('script');
    s.src = src; s.onload = res; s.onerror = () => rej(new Error('Could not load text recognition. Check the connection.'));
    document.head.append(s);
  });
}

function withTimeout(p, ms, msg) {
  let t;
  return Promise.race([p, new Promise((_, rej) => { t = setTimeout(() => rej(new Error(msg)), ms); })]).finally(() => clearTimeout(t));
}

/// paths: { workerPath, corePath, langPath } override the CDN (tests).
async function worker(paths = {}) {
  return (workerP ??= (async () => {
    if (!globalThis.Tesseract) await loadScript(new URL('./ocr/tesseract.min.js', import.meta.url).href);
    let fail;
    const failed = new Promise((_, rej) => { fail = rej; });
    const w = globalThis.Tesseract.createWorker('eng', 1, { ...paths, errorHandler: e => fail(new Error('Text recognition stopped: ' + (e?.message || e))) });
    const ready = await withTimeout(Promise.race([w, failed]), 120000, 'Text recognition did not start (could not download the recognizer?).');
    ready.failed = failed;
    return ready;
  })().catch(e => { workerP = null; throw e; }));
}

/// Renders one pdf.js page and recognizes its words; returns the page input pdfbook.js expects.
export async function ocrPage(page, paths) {
  const w = await worker(paths);
  const [vx0, vy0, vx1, vy1] = page.view;
  const pw = vx1 - vx0, ph = vy1 - vy0;
  const scale = Math.min(3, 2200 / Math.max(pw, ph / 1.4));
  const vp = page.getViewport({ scale });
  const canvas = document.createElement('canvas');
  canvas.width = Math.ceil(vp.width); canvas.height = Math.ceil(vp.height);
  const ctx = canvas.getContext('2d');
  ctx.fillStyle = '#fff'; ctx.fillRect(0, 0, canvas.width, canvas.height);
  await page.render({ canvas, canvasContext: ctx, viewport: vp }).promise;
  const { data } = await withTimeout(Promise.race([w.recognize(canvas, {}, { blocks: true, text: false }), w.failed]), 180000, 'Text recognition took too long on a page.');
  const lines = [];
  for (const b of data.blocks || []) for (const p of b.paragraphs || []) for (const l of p.lines || []) {
    // Drop recognizer noise (bits of pictures read as letters): low confidence, or no letters/digits at all.
    const words = (l.words || []).filter(x => /[\p{L}\p{N}]/u.test(x.text) && (x.confidence >= 60 || (x.confidence >= 35 && x.text.trim().length >= 3)))
      .map(x => ({ text: x.text.trim(), x0: x.bbox.x0, y0: x.bbox.y0, x1: x.bbox.x1, y1: x.bbox.y1 }));
    if (words.length) lines.push({ words });
  }
  canvas.width = canvas.height = 0;
  const toPdf = (x, y) => { const [px, py] = vp.convertToPdfPoint(x, y); return [px - vx0, py - vy0]; };
  return ocrPageInput(lines, toPdf, pw, ph);
}
