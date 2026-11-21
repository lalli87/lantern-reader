import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern_reader/src/app.dart';
import 'package:lantern_reader/src/cast_screen.dart';
import 'package:lantern_reader/src/characters.dart';
import 'package:lantern_reader/src/db.dart';
import 'package:lantern_reader/src/models.dart';
import 'package:lantern_reader/src/settings.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  testWidgets('characters screen lists the cast', (t) async {
    late Book book;
    await t.runAsync(() async {
      await Db.open(inMemoryDatabasePath, factory: databaseFactoryFfiNoIsolate);
      settings = Settings();
      await settings.load();
      final id = await Db.insertBook(Book(title: 'The Azure Lantern'));
      await Db.addChapter(id, 'c1', '"Hi," she said.');
      await Cast.save(CastMember(bookId: id, name: 'Lin Mei', aliases: ['Junior Sister'], gender: 'female', age: 'young adult', voice: 'Kore', lines: 12));
      await Cast.save(CastMember(bookId: id, name: 'Gatekeeper', lines: 1));
      book = (await Db.book(id))!;
    });
    await t.pumpWidget(MaterialApp(home: CastScreen(book: book)));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await t.pump();
    expect(find.text('Lin Mei'), findsOneWidget);
    expect(find.text('Kore'), findsOneWidget);
    expect(find.text('narrator voice'), findsOneWidget);
    expect(find.text('0 of 1 chapters checked'), findsOneWidget);
    expect(t.takeException(), isNull);

    // Tap a character to edit; saving marks the voice as the user's choice.
    await t.tap(find.text('Lin Mei'));
    await t.pumpAndSettle();
    expect(find.text('Voice'), findsOneWidget);
    await t.scrollUntilVisible(find.text('Same person as another character…'), 400, scrollable: find.byType(Scrollable).first);
    expect(find.text('Same person as another character…'), findsOneWidget);
    await t.tap(find.text('Save'));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await t.pumpAndSettle();
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await t.pump();
    expect(find.text('your choice'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.runAsync(Db.close);
  });
}
