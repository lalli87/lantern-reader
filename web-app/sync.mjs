// Google Drive sync for the web version. Same format and rules as the phone app; see docs/SYNC.md.

export class AuthError extends Error {}

const FOLDER = 'Lantern Reader';
const FOLDER_MIME = 'application/vnd.google-apps.folder';

/// Signature used to notice changed book text: "<chapters>:<characters>" (see docs/SYNC.md).
export function bookSig(chapters) {
  let n = 0;
  for (const c of chapters) n += c.paras.join('\n').length;
  return `${chapters.length}:${n}`;
}

async function gzip(text) {
  const s = new Blob([text]).stream().pipeThrough(new CompressionStream('gzip'));
  return new Uint8Array(await new Response(s).arrayBuffer());
}
async function gunzip(bytes) {
  // Accept plain JSON too, in case a file was written uncompressed.
  if (!(bytes[0] === 0x1f && bytes[1] === 0x8b)) return new TextDecoder().decode(bytes);
  const s = new Blob([bytes]).stream().pipeThrough(new DecompressionStream('gzip'));
  return new Response(s).text();
}
const safeName = s => (s.replace(/[\\/:*?"<>|\x00-\x1F]/g, ' ').replace(/\s+/g, ' ').trim() || 'Untitled').slice(0, 80);
const newId = () => (globalThis.crypto?.randomUUID?.() || `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 10)}`);

/**
 * ctx: {
 *   getToken(): Promise<string>         access token for drive.file (throw AuthError if signed out)
 *   db: { all, put, del }                the library (IndexedDB wrapper)
 *   store: { get(k, d), set(k, v) }      small persistent values
 *   deviceName: string                   shown in the progress file
 *   isOpen?(id): boolean                 book currently on screen (incoming positions skip it)
 *   base?: string                        API host (tests)
 *   now?: () => number
 * }
 */
export function createSync(ctx) {
  const base = ctx.base || 'https://www.googleapis.com';
  const now = ctx.now || Date.now;
  const API = base + '/drive/v3', UP = base + '/upload/drive/v3';
  let running = null;

  async function call(method, url, { json, body, headers = {}, raw = false } = {}) {
    const token = await ctx.getToken();
    const h = { authorization: 'Bearer ' + token, ...headers };
    if (json !== undefined) { h['content-type'] = 'application/json'; body = JSON.stringify(json); }
    const r = await fetch(url, { method, headers: h, body });
    if (r.status === 401) throw new AuthError('Google sign-in expired.');
    if (!r.ok) {
      let m = '';
      try { m = (await r.json()).error?.message || ''; } catch {}
      if (/has not been used|is disabled/.test(m)) m = 'The Google Drive API is not turned on for this project (console.cloud.google.com → APIs & Services → Library → Google Drive API → Enable).';
      throw new Error(`Drive ${r.status}: ${m}`);
    }
    return raw ? new Uint8Array(await r.arrayBuffer()) : r.json();
  }

  async function list(q) {
    const out = [];
    let page = '';
    do {
      const u = `${API}/files?q=${encodeURIComponent(q)}&pageSize=1000&spaces=drive&fields=${encodeURIComponent('nextPageToken,files(id,name,appProperties,modifiedTime)')}${page ? '&pageToken=' + page : ''}`;
      const r = await call('GET', u);
      out.push(...(r.files || []));
      page = r.nextPageToken || '';
    } while (page);
    return out;
  }

  async function folderId() {
    const found = await list(`mimeType='${FOLDER_MIME}' and name='${FOLDER}' and trashed=false and appProperties has { key='lantern' and value='root' }`);
    if (found.length) return found[0].id;
    const f = await call('POST', `${API}/files?fields=id`, { json: { name: FOLDER, mimeType: FOLDER_MIME, appProperties: { lantern: 'root' } } });
    return f.id;
  }

  async function upload(metadata, bytes, mime, fileId) {
    const b = 'lantern' + Math.random().toString(36).slice(2);
    const head = `--${b}\r\ncontent-type: application/json; charset=UTF-8\r\n\r\n${JSON.stringify(metadata)}\r\n--${b}\r\ncontent-type: ${mime}\r\n\r\n`;
    const body = new Blob([head, bytes, `\r\n--${b}--`]);
    const url = fileId ? `${UP}/files/${fileId}?uploadType=multipart&fields=id` : `${UP}/files?uploadType=multipart&fields=id`;
    return call(fileId ? 'PATCH' : 'POST', url, { body, headers: { 'content-type': `multipart/related; boundary=${b}` } });
  }

  const download = id => call('GET', `${API}/files/${id}?alt=media`, { raw: true });

  function bookJson(b) {
    return JSON.stringify({ v: 1, sid: b.sid, title: b.title, author: b.author || '', format: b.format || '', addedAt: b.added || 0,
      chapters: b.chapters.map(c => ({ title: c.title, paras: c.paras })) });
  }

  async function putBook(folder, b, fileId) {
    const sig = bookSig(b.chapters);
    const md = { name: safeName(b.title) + '.lantern.json.gz', appProperties: { lantern: 'book', sid: b.sid, sig } };
    if (!fileId) md.parents = [folder];
    await upload(md, await gzip(bookJson(b)), 'application/gzip', fileId);
    return sig;
  }

  async function getBook(file) {
    const j = JSON.parse(await gunzip(await download(file.id)));
    if (!Array.isArray(j.chapters)) throw new Error('Unreadable book file on Drive: ' + file.name);
    return j;
  }

  async function runOnce({ full = true } = {}) {
    const folder = await folderId();
    const files = await list(`'${folder}' in parents and trashed=false`);
    const remoteBooks = new Map(), progressFiles = [];
    for (const f of files) {
      const a = f.appProperties || {};
      if (a.lantern === 'book' && a.sid) remoteBooks.set(a.sid, f);
      if (a.lantern === 'progress') progressFiles.push(f);
    }
    const deviceId = ctx.store.get('syncDevice', '') || (() => { const d = newId(); ctx.store.set('syncDevice', d); return d; })();
    const ownName = `progress-${deviceId}.json`;
    const ownFile = progressFiles.find(f => f.name === ownName);
    const docs = [];
    for (const f of progressFiles) {
      try { docs.push(JSON.parse(new TextDecoder().decode(await download(f.id)))); } catch {}
    }
    const pending = ctx.store.get('syncPendingDeletes', {});
    const ownDoc = ownFile ? docs[progressFiles.indexOf(ownFile)] || {} : {};
    const ownDeleted = { ...(ownDoc.deleted || {}), ...pending };
    const deleted = { ...ownDeleted };
    for (const d of docs) Object.assign(deleted, d.deleted || {});

    const stats = { uploaded: 0, downloaded: 0, removed: 0, positions: 0 };
    if (full) {
      const locals = await ctx.db.all();
      const localSids = new Set();
      for (const b of locals) {
        if (!b.sid) { b.sid = newId(); await ctx.db.put(b); }
        if (deleted[b.sid]) { await ctx.db.del(b.id); stats.removed++; continue; }
        localSids.add(b.sid);
        const r = remoteBooks.get(b.sid), sig = bookSig(b.chapters);
        if (r) {
          if (sig !== b.syncSig) { b.syncSig = await putBook(folder, b, r.id); await ctx.db.put(b); stats.uploaded++; }
          else if ((r.appProperties || {}).sig !== b.syncSig) {
            const j = await getBook(r);
            b.chapters = j.chapters; b.title = j.title || b.title; b.author = j.author || b.author;
            b.ch = Math.min(b.ch || 0, b.chapters.length - 1);
            b.syncSig = bookSig(b.chapters); await ctx.db.put(b); stats.downloaded++;
          }
        } else { b.syncSig = await putBook(folder, b); await ctx.db.put(b); stats.uploaded++; }
      }
      for (const [sid, f] of remoteBooks) {
        if (localSids.has(sid) || deleted[sid]) continue;
        const j = await getBook(f);
        await ctx.db.put({ title: j.title || 'Untitled', author: j.author || '', format: j.format || '', chapters: j.chapters,
          added: j.addedAt || now(), opened: 0, ch: 0, para: 0, posAt: 0, sid, syncSig: bookSig(j.chapters) });
        stats.downloaded++;
      }
    }

    // Reading positions: newest wins.
    const best = {};
    for (const d of docs) for (const [sid, e] of Object.entries(d.books || {})) if (!best[sid] || e.at > best[sid].at) best[sid] = e;
    const locals = await ctx.db.all();
    for (const b of locals) {
      const e = b.sid && best[b.sid];
      if (!e || !(e.at > (b.posAt || 0)) || ctx.isOpen?.(b.id)) continue;
      b.ch = Math.max(0, Math.min(e.ch | 0, b.chapters.length - 1)); b.para = Math.max(0, e.para | 0); b.posAt = e.at;
      await ctx.db.put(b); stats.positions++;
    }

    for (const sid of Object.keys(pending)) {
      const r = remoteBooks.get(sid);
      if (r) await call('PATCH', `${API}/files/${r.id}?fields=id`, { json: { trashed: true } });
    }

    const mine = { v: 1, device: ctx.deviceName || 'Web', at: now(), books: {}, deleted: ownDeleted };
    for (const b of locals) if (b.sid && !deleted[b.sid]) mine.books[b.sid] = { ch: b.ch || 0, para: b.para || 0, at: b.posAt || 0, title: b.title };
    const bytes = new TextEncoder().encode(JSON.stringify(mine));
    await upload(ownFile ? { appProperties: { lantern: 'progress', dev: deviceId } } : { name: ownName, parents: [folder], appProperties: { lantern: 'progress', dev: deviceId } },
      bytes, 'application/json', ownFile?.id);
    ctx.store.set('syncPendingDeletes', {});
    ctx.store.set('syncLast', now());
    return stats;
  }

  return {
    /// Runs a sync; concurrent calls share one run. { full: false } skips book text (positions only).
    run(opts) {
      if (running) return running;
      running = runOnce(opts).finally(() => { running = null; });
      return running;
    },
    /// Call when a book is deleted locally, so other devices delete it too.
    recordDelete(book) {
      if (!book?.sid || !book.syncSig) return;
      const p = ctx.store.get('syncPendingDeletes', {});
      p[book.sid] = now();
      ctx.store.set('syncPendingDeletes', p);
    },
    userInfo: () => call('GET', `${API}/about?fields=user(emailAddress,displayName)`).then(r => r.user || {}),
  };
}
