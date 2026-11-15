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
      options: OpenDatabaseOptions(version: 1, onCreate: _create),
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
  static Future<int> insertBook(Book b) async => b.id = await db.insert('books', b.toMap());

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

  static Future<void> deleteBook(int id) async {
    await db.transaction((t) async {
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
      await t.delete('chapters', where: 'id=?', whereArgs: [chapterId]);
      await t.delete('bookmarks', where: 'chapter_id=?', whereArgs: [chapterId]);
      await t.delete('quotes', where: 'chapter_id=?', whereArgs: [chapterId]);
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
