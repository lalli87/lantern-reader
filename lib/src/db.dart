import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'models.dart';

/// SQLite storage. One instance for the whole app.
class Db {
  static late Database db;
  static String path = '';

  static Future<void> open(String path, {DatabaseFactory? factory}) async {
    final f = factory ?? databaseFactory;
    Db.path = path;
    db = await f.openDatabase(
      path,
      options: OpenDatabaseOptions(version: 2, onCreate: _create, onUpgrade: _upgrade),
    );
  }

  static Future<void> close() => db.close();

  static Future<void> _create(Database d, int v) async {
    await d.execute('''CREATE TABLE books(
      id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, author TEXT, series TEXT, series_no REAL,
      language TEXT, description TEXT, format TEXT, source_url TEXT, file_name TEXT, review TEXT,
      file_size INTEGER, added_at INTEGER, last_read_at INTEGER, cur_chapter INTEGER, cur_para INTEGER,
      shelf INTEGER, trashed_at INTEGER, chapter_count INTEGER, char_count INTEGER, progress REAL,
      favorite INTEGER, cover_path TEXT)''');
    await d.execute('''CREATE TABLE chapters(
      id INTEGER PRIMARY KEY AUTOINCREMENT, book_id INTEGER, idx INTEGER, title TEXT, url TEXT,
      content TEXT, translated TEXT, translated_lang TEXT, char_count INTEGER, added_at INTEGER)''');
    await d.execute('CREATE INDEX chapters_book ON chapters(book_id, idx)');
    await d.execute('''CREATE TABLE bookmarks(
      id INTEGER PRIMARY KEY AUTOINCREMENT, book_id INTEGER, chapter_id INTEGER, para INTEGER,
      snippet TEXT, created_at INTEGER)''');
    await d.execute('''CREATE TABLE quotes(
      id INTEGER PRIMARY KEY AUTOINCREMENT, book_id INTEGER, chapter_id INTEGER, para INTEGER,
      start INTEGER, "end" INTEGER, text TEXT, note TEXT, color INTEGER, created_at INTEGER)''');
    await d.execute('''CREATE TABLE dict(
      id INTEGER PRIMARY KEY AUTOINCREMENT, kind INTEGER, word TEXT, definition TEXT, created_at INTEGER)''');
    await d.execute('CREATE TABLE shelves(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)');
    await d.execute('CREATE TABLE shelf_books(shelf_id INTEGER, book_id INTEGER, PRIMARY KEY(shelf_id, book_id))');
    await d.execute('CREATE TABLE kv(k TEXT PRIMARY KEY, v TEXT)');
    await _createV2(d);
  }

  static Future<void> _upgrade(Database d, int from, int to) async {
    if (from < 2) await _createV2(d);
  }

  /// Version 2: character voices. The cast belongs to the book, so deleting chapters keeps it.
  static Future<void> _createV2(Database d) async {
    await d.execute('''CREATE TABLE IF NOT EXISTS characters(
      id INTEGER PRIMARY KEY AUTOINCREMENT, book_id INTEGER, name TEXT, aliases TEXT, gender TEXT, age TEXT,
      voice TEXT, style TEXT, lines INTEGER, user_set INTEGER, created_at INTEGER)''');
    await d.execute('CREATE INDEX IF NOT EXISTS characters_book ON characters(book_id)');
    await d.execute('CREATE TABLE IF NOT EXISTS chapter_speakers(chapter_id INTEGER PRIMARY KEY, data TEXT, created_at INTEGER)');
  }

  // ---- key/value ----
  static Future<String?> kvGet(String k) async {
    final r = await db.query('kv', where: 'k=?', whereArgs: [k]);
    return r.isEmpty ? null : r.first['v'] as String?;
  }

  static Future<void> kvSet(String k, String v) =>
      db.insert('kv', {'k': k, 'v': v}, conflictAlgorithm: ConflictAlgorithm.replace);

  static Future<Map<String, dynamic>> kvJson(String k) async {
    final s = await kvGet(k);
    if (s == null) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(s) as Map);
    } catch (_) {
      return {};
    }
  }

  // ---- books ----
  static Future<int> insertBook(Book b) async {
    b.id = await db.insert('books', b.toMap());
    await _restoreKeptCast(b);
    return b.id!;
  }

  /// Where a deleted book's characters are kept, so adding the same novel again brings them back: by the
  /// novel part of its web address (the address minus its last part, e.g. `wuxiaworld.com/novel/<name>`)
  /// and by title.
  static List<String> castKeepKeys(Book b) {
    final keys = <String>[];
    final u = Uri.tryParse(b.sourceUrl);
    if (u != null && u.host.isNotEmpty) {
      final segs = u.pathSegments.where((x) => x.isNotEmpty).toList();
      if (segs.length >= 3) keys.add('castKeep:${u.host.replaceFirst('www.', '')}/${segs.sublist(0, segs.length - 1).join('/')}');
    }
    final t = b.title.trim().toLowerCase();
    if (t.isNotEmpty) keys.add('castKeep:title:$t');
    return keys;
  }

  static Future<void> _keepCast(int bookId) async {
    final b = await book(bookId);
    if (b == null) return;
    final rows = await db.query('characters', where: 'book_id=?', whereArgs: [bookId]);
    if (rows.isEmpty) return;
    final data = jsonEncode([
      for (final r in rows) {for (final e in r.entries) if (e.key != 'id' && e.key != 'book_id') e.key: e.value},
    ]);
    for (final k in castKeepKeys(b)) {
      await kvSet(k, data);
    }
  }

  static Future<void> _restoreKeptCast(Book b) async {
    final keys = castKeepKeys(b);
    if (keys.isEmpty) return;
    for (final k in keys) {
      final v = await kvGet(k);
      if (v == null || v.isEmpty) continue;
      try {
        for (final r in (jsonDecode(v) as List).cast<Map>()) {
          await db.insert('characters', {...Map<String, Object?>.from(r), 'book_id': b.id});
        }
      } catch (_) {}
      break;
    }
    await db.delete('kv', where: 'k IN (${List.filled(keys.length, '?').join(',')})', whereArgs: keys);
  }

  static Future<void> updateBook(Book b) => db.update('books', b.toMap(), where: 'id=?', whereArgs: [b.id]);

  static Future<Book?> book(int id) async {
    final r = await db.query('books', where: 'id=?', whereArgs: [id]);
    return r.isEmpty ? null : Book.fromMap(r.first);
  }

  static Future<List<Book>> books({bool trashed = false}) async {
    final r = await db.query('books', where: trashed ? 'trashed_at>0' : 'trashed_at=0');
    return r.map(Book.fromMap).toList();
  }

  static Future<void> setTrashed(int id, bool t) =>
      db.update('books', {'trashed_at': t ? nowMs() : 0}, where: 'id=?', whereArgs: [id]);

  /// Deletes a book. A book that was synced to Google Drive is remembered (kv `sync.pending`) so the
  /// next sync deletes it on Drive and other devices too; [forget] skips that (sync's own deletions).
  static Future<void> deleteBook(int id, {bool forget = false}) async {
    final m = await kvJson('sync.books');
    final e = m.remove('$id');
    if (e is Map && e['sig'] != null && e['sid'] != null && !forget) {
      final p = await kvJson('sync.pending');
      p[e['sid'] as String] = nowMs();
      await kvSet('sync.pending', jsonEncode(p));
    }
    if (e != null) await kvSet('sync.books', jsonEncode(m));
    try {
      await _keepCast(id);
    } catch (_) {}
    await db.transaction((t) async {
      await t.rawDelete('DELETE FROM chapter_speakers WHERE chapter_id IN (SELECT id FROM chapters WHERE book_id=?)', [id]);
      await t.delete('characters', where: 'book_id=?', whereArgs: [id]);
      for (final table in ['chapters', 'bookmarks', 'quotes', 'shelf_books']) {
        await t.delete(table, where: 'book_id=?', whereArgs: [id]);
      }
      await t.delete('books', where: 'id=?', whereArgs: [id]);
    });
  }

  /// Saves where the reader or narrator is, and derives overall progress.
  static Future<void> savePosition(int bookId, int chapterIdx, int para, {double? within}) async {
    final b = await book(bookId);
    if (b == null) return;
    final n = b.chapterCount == 0 ? 1 : b.chapterCount;
    final p = ((chapterIdx + (within ?? 0)) / n).clamp(0.0, 1.0);
    await db.update('books', {'cur_chapter': chapterIdx, 'cur_para': para, 'progress': p, 'last_read_at': nowMs()},
        where: 'id=?', whereArgs: [bookId]);
  }

  /// Sets the position to one that came from another device, keeping that device's time.
  static Future<void> setPositionAt(int bookId, int chapterIdx, int para, int at) async {
    final b = await book(bookId);
    if (b == null) return;
    final n = b.chapterCount == 0 ? 1 : b.chapterCount;
    await db.update('books', {'cur_chapter': chapterIdx, 'cur_para': para, 'progress': (chapterIdx / n).clamp(0.0, 1.0), 'last_read_at': at},
        where: 'id=?', whereArgs: [bookId]);
  }

  /// Replaces all chapters of a book (new text from another device); bookmarks and highlights of the
  /// old chapters are dropped.
  static Future<void> replaceChapters(int bookId, List<(String, String)> chapters) async {
    await db.transaction((t) async {
      final old = await t.query('chapters', columns: ['id'], where: 'book_id=?', whereArgs: [bookId]);
      final ids = [for (final r in old) r['id']];
      for (final table in ['bookmarks', 'quotes']) {
        if (ids.isNotEmpty) await t.delete(table, where: 'chapter_id IN (${List.filled(ids.length, '?').join(',')})', whereArgs: ids);
      }
      await t.delete('chapters', where: 'book_id=?', whereArgs: [bookId]);
      final now = nowMs();
      for (var i = 0; i < chapters.length; i++) {
        await t.insert('chapters', Chapter(bookId: bookId, idx: i, title: chapters[i].$1, content: chapters[i].$2, addedAt: now).toMap());
      }
      await _recount(t, bookId);
      final b = await t.query('books', columns: ['cur_chapter'], where: 'id=?', whereArgs: [bookId]);
      final cur = b.isEmpty ? 0 : (b.first['cur_chapter'] as int? ?? 0);
      if (cur >= chapters.length) {
        await t.update('books', {'cur_chapter': chapters.isEmpty ? 0 : chapters.length - 1, 'cur_para': 0}, where: 'id=?', whereArgs: [bookId]);
      }
    });
  }

  static Future<void> _recount(DatabaseExecutor t, int bookId) async {
    final r = await t.rawQuery(
        'SELECT COUNT(*) c, COALESCE(SUM(char_count),0) s FROM chapters WHERE book_id=?', [bookId]);
    await t.update('books', {'chapter_count': r.first['c'], 'char_count': r.first['s']},
        where: 'id=?', whereArgs: [bookId]);
  }

  // ---- chapters ----
  static Future<List<ChapterMeta>> chapterMetas(int bookId) async {
    final r = await db.rawQuery(
        "SELECT id, book_id, idx, title, url, char_count, (translated IS NOT NULL AND translated<>'') has_tr "
        'FROM chapters WHERE book_id=? ORDER BY idx',
        [bookId]);
    return r.map(ChapterMeta.fromMap).toList();
  }

  static Future<Chapter?> chapter(int id) async {
    final r = await db.query('chapters', where: 'id=?', whereArgs: [id]);
    return r.isEmpty ? null : Chapter.fromMap(r.first);
  }

  static Future<Chapter?> chapterAt(int bookId, int idx) async {
    final r = await db.query('chapters', where: 'book_id=? AND idx=?', whereArgs: [bookId, idx], limit: 1);
    return r.isEmpty ? null : Chapter.fromMap(r.first);
  }

  /// Appends a chapter to the end of a book and returns its id.
  static Future<int> addChapter(int bookId, String title, String content, {String url = ''}) async {
    return db.transaction((t) async {
      final r = await t.rawQuery('SELECT COALESCE(MAX(idx),-1)+1 n FROM chapters WHERE book_id=?', [bookId]);
      final c = Chapter(bookId: bookId, idx: r.first['n'] as int, title: title, content: content, url: url);
      final id = await t.insert('chapters', c.toMap());
      await _recount(t, bookId);
      return id;
    });
  }

  static Future<bool> hasChapterUrl(int bookId, String url) async {
    if (url.isEmpty) return false;
    final r = await db.query('chapters', columns: ['id'], where: 'book_id=? AND url=?', whereArgs: [bookId, url], limit: 1);
    return r.isNotEmpty;
  }

  static Future<void> updateChapter(Chapter c) async {
    await db.transaction((t) async {
      await t.update('chapters', c.toMap(), where: 'id=?', whereArgs: [c.id]);
      await _recount(t, c.bookId);
    });
  }

  static Future<void> setTranslation(int chapterId, String text, String lang) =>
      db.update('chapters', {'translated': text, 'translated_lang': lang}, where: 'id=?', whereArgs: [chapterId]);

  static Future<void> deleteChapter(int bookId, int chapterId) async {
    await db.transaction((t) async {
      // Keep the reading position on the same chapter when an earlier one is removed.
      final ch = await t.query('chapters', columns: ['idx'], where: 'id=?', whereArgs: [chapterId]);
      final bk = await t.query('books', columns: ['cur_chapter'], where: 'id=?', whereArgs: [bookId]);
      if (ch.isNotEmpty && bk.isNotEmpty) {
        final idx = ch.first['idx'] as int, cur = bk.first['cur_chapter'] as int? ?? 0;
        if (idx < cur) {
          await t.update('books', {'cur_chapter': cur - 1}, where: 'id=?', whereArgs: [bookId]);
        } else if (idx == cur) {
          await t.update('books', {'cur_para': 0}, where: 'id=?', whereArgs: [bookId]);
        }
      }
      await t.delete('chapters', where: 'id=?', whereArgs: [chapterId]);
      await t.delete('bookmarks', where: 'chapter_id=?', whereArgs: [chapterId]);
      await t.delete('quotes', where: 'chapter_id=?', whereArgs: [chapterId]);
      await t.delete('chapter_speakers', where: 'chapter_id=?', whereArgs: [chapterId]);
      await _renumber(t, bookId, null);
      await _recount(t, bookId);
    });
  }

  /// Rewrites idx 0..n-1, either in current order or in the order of [ids].
  static Future<void> _renumber(DatabaseExecutor t, int bookId, List<int>? ids) async {
    ids ??= (await t.query('chapters', columns: ['id'], where: 'book_id=?', whereArgs: [bookId], orderBy: 'idx'))
        .map((e) => e['id'] as int)
        .toList();
    for (var i = 0; i < ids.length; i++) {
      await t.update('chapters', {'idx': i}, where: 'id=?', whereArgs: [ids[i]]);
    }
  }

  static Future<void> reorderChapters(int bookId, List<int> ids) => db.transaction((t) => _renumber(t, bookId, ids));

  // ---- bookmarks ----
  static Future<int> addBookmark(Bookmark b) async => b.id = await db.insert('bookmarks', b.toMap());
  static Future<void> deleteBookmark(int id) => db.delete('bookmarks', where: 'id=?', whereArgs: [id]);
  static Future<List<Bookmark>> bookmarks({int? bookId}) async {
    final r = await db.query('bookmarks',
        where: bookId == null ? null : 'book_id=?', whereArgs: bookId == null ? null : [bookId], orderBy: 'created_at DESC');
    return r.map(Bookmark.fromMap).toList();
  }

  // ---- quotes ----
  static Future<int> addQuote(Quote q) async => q.id = await db.insert('quotes', q.toMap());
  static Future<void> updateQuote(Quote q) => db.update('quotes', q.toMap(), where: 'id=?', whereArgs: [q.id]);
  static Future<void> deleteQuote(int id) => db.delete('quotes', where: 'id=?', whereArgs: [id]);
  static Future<List<Quote>> quotes({int? bookId, int? chapterId}) async {
    final w = <String>[], a = <Object>[];
    if (bookId != null) {
      w.add('book_id=?');
      a.add(bookId);
    }
    if (chapterId != null) {
      w.add('chapter_id=?');
      a.add(chapterId);
    }
    final r = await db.query('quotes',
        where: w.isEmpty ? null : w.join(' AND '), whereArgs: a.isEmpty ? null : a, orderBy: 'created_at DESC');
    return r.map(Quote.fromMap).toList();
  }

  // ---- glossary ----
  static Future<int> addDict(DictEntry e) async => e.id = await db.insert('dict', e.toMap());
  static Future<void> updateDict(DictEntry e) => db.update('dict', e.toMap(), where: 'id=?', whereArgs: [e.id]);
  static Future<void> deleteDict(int id) => db.delete('dict', where: 'id=?', whereArgs: [id]);
  static Future<List<DictEntry>> dict() async =>
      (await db.query('dict', orderBy: 'word COLLATE NOCASE')).map(DictEntry.fromMap).toList();

  // ---- shelves (user collections) ----
  static Future<List<Shelf>> shelves() async {
    final r = await db.rawQuery('SELECT s.id, s.name, (SELECT COUNT(*) FROM shelf_books sb JOIN books b ON b.id=sb.book_id '
        'WHERE sb.shelf_id=s.id AND b.trashed_at=0) c FROM shelves s ORDER BY s.name COLLATE NOCASE');
    return r.map((m) => Shelf(m['id'] as int, m['name'] as String, m['c'] as int)).toList();
  }

  static Future<int> addShelf(String name) => db.insert('shelves', {'name': name});
  static Future<void> renameShelf(int id, String name) =>
      db.update('shelves', {'name': name}, where: 'id=?', whereArgs: [id]);
  static Future<void> deleteShelf(int id) async {
    await db.delete('shelf_books', where: 'shelf_id=?', whereArgs: [id]);
    await db.delete('shelves', where: 'id=?', whereArgs: [id]);
  }

  static Future<Set<int>> shelfIdsOf(int bookId) async =>
      (await db.query('shelf_books', where: 'book_id=?', whereArgs: [bookId])).map((e) => e['shelf_id'] as int).toSet();

  static Future<Set<int>> bookIdsOn(int shelfId) async =>
      (await db.query('shelf_books', where: 'shelf_id=?', whereArgs: [shelfId])).map((e) => e['book_id'] as int).toSet();

  static Future<void> setOnShelf(int shelfId, int bookId, bool on) async {
    if (on) {
      await db.insert('shelf_books', {'shelf_id': shelfId, 'book_id': bookId},
          conflictAlgorithm: ConflictAlgorithm.ignore);
    } else {
      await db.delete('shelf_books', where: 'shelf_id=? AND book_id=?', whereArgs: [shelfId, bookId]);
    }
  }
}
