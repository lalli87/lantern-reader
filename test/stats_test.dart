import 'package:flutter_test/flutter_test.dart';
import 'package:lantern_reader/src/db.dart';
import 'package:lantern_reader/src/library.dart' show searchInsideBooks;
import 'package:lantern_reader/src/models.dart';
import 'package:lantern_reader/src/stats.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);
  setUp(() => Db.open(inMemoryDatabasePath, factory: databaseFactoryFfiNoIsolate));
  tearDown(Db.close);

  Future<String> day(DateTime d, int bookId, {int read = 0, int listen = 0}) async {
    final k = dayKey(d);
    await Db.db.rawInsert('INSERT INTO activity(day, book_id, read_ms, listen_ms) VALUES(?, ?, ?, ?)', [k, bookId, read, listen]);
    return k;
  }

  test('time adds up per day and book; totals, days and top books', () async {
    final b = Book(title: 'Martial Peak');
    await Db.insertBook(b);
    await Activity.add(b.id!, readMs: 30000);
    await Activity.add(b.id!, readMs: 30000, listenMs: 120000);
    final today = DateTime.now();
    final t = await Activity.since(DateTime(today.year, today.month, today.day));
    expect(t, (60000, 120000));
    final days = await Activity.days(14);
    expect(days, hasLength(14));
    expect(dayKey(days.last.$1), dayKey(today));
    expect((days.last.$2, days.last.$3), (60000, 120000));
    final top = await Activity.topBooks(DateTime(today.year, today.month, 1));
    expect(top.single.$2, 'Martial Peak');
    expect(fmtDuration(3 * 60000), '3 min');
    expect(fmtDuration(95 * 60000), '1 h 35 min');
  });

  test('the streak counts days in a row, and today not started yet doesn\'t break it', () async {
    final now = DateTime(2026, 11, 23, 9);
    await day(DateTime(2026, 11, 22), 1, read: 120000);
    await day(DateTime(2026, 11, 21), 1, listen: 60000);
    await day(DateTime(2026, 11, 20), 1, read: 10000); // under a minute: doesn't count
    await day(DateTime(2026, 11, 19), 1, read: 600000);
    expect(await Activity.streak(today: now), 2);
    await day(DateTime(2026, 11, 23), 1, read: 90000);
    expect(await Activity.streak(today: now), 3);
  });

  test('finishing a book file is noticed; saved web chapters are not marked finished', () async {
    final epub = Book(title: 'Dune', format: 'EPUB');
    final web = Book(title: 'Web novel', format: 'WEB');
    await Db.insertBook(epub);
    await Db.insertBook(web);
    for (final b in [epub, web]) {
      await Db.addChapter(b.id!, 'One', 'text');
      await Db.addChapter(b.id!, 'Two', 'text');
    }
    await Db.savePosition(epub.id!, 1, 0, within: 1);
    await Db.savePosition(web.id!, 1, 0, within: 1);
    expect((await Db.book(epub.id!))!.shelf, shelfFinished);
    expect((await Db.book(web.id!))!.shelf, shelfNone);
    final year = DateTime(DateTime.now().year);
    expect((await Activity.finished(year)).map((f) => f.$2), ['Dune']);
    // Marking it not finished removes it from the finished list.
    final e = (await Db.book(epub.id!))!..shelf = shelfNone;
    await Db.updateBook(e);
    expect(await Activity.finished(year), isEmpty);
  });

  test('search inside books finds words in chapter text, case-insensitively', () async {
    final b = Book(title: 'Alchemist', format: 'WEB');
    await Db.insertBook(b);
    await Db.addChapter(b.id!, 'Chapter 1', 'Intro line.\nHe found the Flesh Ganoderma deep in the cave.\nEnd.');
    await Db.addChapter(b.id!, 'Chapter 2', 'Nothing here.');
    final trashed = Book(title: 'Old');
    await Db.insertBook(trashed);
    await Db.addChapter(trashed.id!, 'X', 'flesh ganoderma again');
    await Db.setTrashed(trashed.id!, true);
    final r = await searchInsideBooks('flesh ganoderma');
    expect(r, hasLength(1));
    expect(r.single.chapterTitle, 'Chapter 1');
    expect(r.single.para, 1);
    expect(r.single.snippet, contains('Flesh Ganoderma'));
    expect(await searchInsideBooks('100%'), isEmpty, reason: 'wildcards are taken literally');
  });
}
