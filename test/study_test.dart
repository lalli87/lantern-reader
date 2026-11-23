import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lantern_reader/src/ai.dart';
import 'package:lantern_reader/src/app.dart';
import 'package:lantern_reader/src/db.dart';
import 'package:lantern_reader/src/importers.dart';
import 'package:lantern_reader/src/models.dart';
import 'package:lantern_reader/src/settings.dart';
import 'package:lantern_reader/src/study.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const dictJson = '''[{"word":"serene","phonetic":"/səˈɹiːn/","meanings":[
 {"partOfSpeech":"adjective","definitions":[{"definition":"Peaceful, calm.","example":"a serene lake"},{"definition":"Fair and unclouded."}]},
 {"partOfSpeech":"noun","definitions":[{"definition":"Calmness."}]}]}]''';

void main() {
  setUpAll(sqfliteFfiInit);
  setUp(() async {
    await Db.open(inMemoryDatabasePath, factory: databaseFactoryFfiNoIsolate);
    settings = Settings();
    await settings.load();
  });
  tearDown(Db.close);

  test('dictionary replies are read; phrases and names are not looked up', () async {
    final d = parseDictionary(dictJson)!;
    expect(d.word, 'serene');
    expect(d.phonetic, '/səˈɹiːn/');
    expect(d.meanings.map((m) => m.partOfSpeech), ['adjective', 'noun']);
    expect(d.meanings.first.definitions.first, ('Peaceful, calm.', 'a serene lake'));
    expect(parseDictionary('{"title":"No Definitions Found"}'), isNull);

    Uri? asked;
    final r = await http.runWithClient(() => lookUpWord('Serene,'), () => MockClient((req) async {
          asked = req.url;
          return http.Response(dictJson, 200, headers: {'content-type': 'application/json; charset=utf-8'});
        }));
    expect(asked!.path, endsWith('/serene'));
    expect(r!.meanings, hasLength(2));
    expect(await lookUpWord('Flesh Ganoderma'), isNull, reason: 'more than one word');
    expect(await lookUpWord('洛尘'), isNull);
  });

  test('AI explains selected words in the passage', () async {
    settings.setSecret('geminiKey', 'k');
    String? sent;
    final r = await http.runWithClient(
      () => explainInContext(settings, 'Flesh Ganoderma', 'Ding Yi, the Flesh Ganoderma, laughed.', 'An Alchemist\'s Path'),
      () => MockClient((req) async {
        sent = req.body;
        return http.Response(jsonEncode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': 'A spirit herb that has gained a mind; here it is Ding Yi.'}
                ]
              }
            }
          ]
        }), 200);
      }),
    );
    expect(r, contains('spirit herb'));
    expect(sent, contains('Flesh Ganoderma'));
    expect(sent, contains('Ding Yi, the Flesh Ganoderma'));
  });

  test('notes export as Markdown, text and a Word file that opens', () async {
    final b = Book(title: 'Dune', format: 'EPUB');
    await Db.insertBook(b);
    final c1 = await Db.addChapter(b.id!, 'Book One', 'Fear is the mind-killer.\nSecond.');
    final c2 = await Db.addChapter(b.id!, 'Book Two', 'The spice must flow.');
    await Db.addQuote(Quote(bookId: b.id!, chapterId: c2, para: 0, start: 0, end: 20, text: 'The spice must flow.'));
    await Db.addQuote(Quote(bookId: b.id!, chapterId: c1, para: 0, start: 0, end: 24, text: 'Fear is the mind-killer.', note: 'Litany <against> fear & doubt'));
    final notes = await loadNotes(bookId: b.id);
    expect(notes.single.$1, 'Dune');
    expect(notes.single.$2.map((x) => x.$2), ['Book One', 'Book Two'], reason: 'in reading order');
    final md = notesMarkdown(notes);
    expect(md, startsWith('# Dune'));
    expect(md, contains('> Fear is the mind-killer.'));
    expect(md, contains('**Note:** Litany <against> fear & doubt'));
    expect(notesText(notes), contains('“The spice must flow.”'));
    // The Word file is read back by Lantern's own DOCX importer.
    final docx = parseBookBytes(notesDocx(notes), 'notes.docx');
    final all = docx.chapters.expand((c) => c.paras).join('\n');
    expect(all, contains('Fear is the mind-killer.'));
    expect(all, contains('Note: Litany <against> fear & doubt'));
  });

  testWidgets('a quote becomes a picture', (t) async {
    final png = (await t.runAsync(() => quoteImage('The spice must flow.', 'Dune', 'Frank Herbert')))!;
    expect(png.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
  });

  testWidgets('the look-up sheet shows the dictionary and offers AI and the glossary', (t) async {
    await http.runWithClient(() async {
      await t.pumpWidget(MaterialApp(
        home: Builder(
          builder: (c) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showLookup(c, text: 'serene', paragraph: 'The lake was serene.', bookTitle: 'Test'),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ));
      await t.tap(find.text('go'));
      for (var i = 0; i < 10; i++) {
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
        await t.pump(const Duration(milliseconds: 100));
      }
    }, () => MockClient((_) async => http.Response(dictJson, 200, headers: {'content-type': 'application/json; charset=utf-8'})));
    expect(find.text('adjective'), findsOneWidget);
    expect(find.textContaining('Peaceful, calm.'), findsOneWidget);
    expect(find.text('In this story'), findsOneWidget);
    await t.scrollUntilVisible(find.text('Save to glossary'), 200, scrollable: find.byType(Scrollable).last);
    expect(find.text('Save to glossary'), findsOneWidget);
  });
}
