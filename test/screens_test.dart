// Renders the main screens with a seeded library so they can be checked by eye, and exercises
// pagination against real fonts.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern_reader/main.dart';
import 'package:lantern_reader/src/app.dart';
import 'package:lantern_reader/src/book_detail.dart';
import 'package:lantern_reader/src/db.dart';
import 'package:lantern_reader/src/models.dart';
import 'package:lantern_reader/src/narration_ui.dart';
import 'package:lantern_reader/src/narrator.dart';
import 'package:lantern_reader/src/pagination.dart';
import 'package:lantern_reader/src/reader.dart';
import 'package:lantern_reader/src/reader_widgets.dart';
import 'package:lantern_reader/src/settings.dart';
import 'package:lantern_reader/src/text_utils.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> _font(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
  }
  await loader.load();
}

String _para(int seed, int sentences) {
  const bits = [
    'The mountain path wound upward through pines heavy with last night\'s rain.',
    'Lin Mei tightened the strap of her pack and kept her eyes on the ridge.',
    '"We should reach the gate before dusk," Old Shen said, not slowing.',
    'Somewhere below, a bell rang three times and then fell silent.',
    'She had heard stories of the Azure Lantern Sect since she was a child, and none of them had mentioned the stairs.',
    'A cold wind carried the smell of woodsmoke and something sweeter beneath it.',
    'He laughed, a short dry sound.',
    'By the time the lanterns were lit, her legs had stopped complaining and simply gone numb.',
  ];
  return List.generate(sentences, (i) => bits[(seed * 3 + i * 5) % bits.length]).join(' ');
}

Future<void> _seed() async {
  final a = await Db.insertBook(Book(title: 'The Azure Lantern', author: 'Shen Wei (sample)', format: 'WEB', sourceUrl: 'https://example.com/novel/azure-lantern'));
  for (var c = 0; c < 12; c++) {
    final paras = ['# Chapter ${c + 1}: ${['The Stairs', 'The Gate', 'First Light', 'A Bowl of Rice'][c % 4]}', for (var i = 0; i < 40; i++) _para(c * 7 + i, 2 + (i % 4))];
    await Db.addChapter(a, 'Chapter ${c + 1}: ${['The Stairs', 'The Gate', 'First Light', 'A Bowl of Rice'][c % 4]}', paras.join('\n'), url: 'https://example.com/c$c');
  }
  await Db.savePosition(a, 2, 5, within: 0.15);
  final b = await Db.insertBook(Book(title: 'Notes on Slow Rivers', author: 'M. Okafor (sample)', format: 'EPUB', fileSize: 1900000, favorite: true));
  await Db.addChapter(b, 'One', _para(1, 30));
  await Db.addChapter(b, 'Two', _para(2, 30));
  await Db.savePosition(b, 1, 0);
  final c = await Db.insertBook(Book(title: 'Winter Field Guide', author: 'Sample Author', format: 'TXT', shelf: shelfToRead, series: 'Field Guides', seriesNo: 2));
  await Db.addChapter(c, 'Winter Field Guide', _para(3, 20));
  await Db.insertBook(Book(title: 'An Empty Notebook', format: 'WEB'));
  final ch = (await Db.chapterMetas(a))[2];
  await Db.addQuote(Quote(bookId: a, chapterId: ch.id, para: 6, start: 10, end: 60, text: 'sample highlight text from the chapter', note: 'Remember this', color: 0));
  await Db.addQuote(Quote(bookId: a, chapterId: ch.id, para: 8, start: 0, end: 40, text: 'another highlighted passage', color: 3));
  await Db.addBookmark(Bookmark(bookId: a, chapterId: ch.id, para: 5, snippet: 'The mountain path wound upward…'));
  await Db.addDict(DictEntry(kind: 1, word: 'Lin Mei', definition: 'The narrator. A new disciple.'));
  await Db.addDict(DictEntry(kind: 1, word: 'Old Shen', definition: 'Her guide up the mountain.'));
  await Db.addDict(DictEntry(kind: 2, word: 'Azure Lantern Sect', definition: 'The mountain sect the story follows.'));
}

void main() {
  final sdk = Platform.environment['FLUTTER_HOME'] ?? '/home/claude/sdk/flutter-dl/flutter';
  final mf = '$sdk/bin/cache/artifacts/material_fonts';

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _font('Roboto', ['$mf/Roboto-Regular.ttf', '$mf/Roboto-Medium.ttf', '$mf/Roboto-Bold.ttf']);
    await _font('MaterialIcons', ['$mf/MaterialIcons-Regular.otf']);
    await _font('Literata', ['assets/fonts/Literata-Regular.ttf', 'assets/fonts/Literata-Bold.ttf']);
    await _font('Atkinson Hyperlegible', ['assets/fonts/AtkinsonHyperlegible-Regular.ttf', 'assets/fonts/AtkinsonHyperlegible-Bold.ttf']);
    await _font('JetBrains Mono', ['assets/fonts/JetBrainsMono-Regular.ttf', 'assets/fonts/JetBrainsMono-Bold.ttf']);
    sqfliteFfiInit();
  });

  setUp(() async {
    await Db.open(inMemoryDatabasePath, factory: databaseFactoryFfiNoIsolate);
    settings = Settings();
    await settings.load();
    narrator = Narrator(settings);
    dataDir = Directory.systemTemp.path;
    await _seed();
  });
  tearDown(Db.close);

  Future<void> phone(WidgetTester t) async {
    t.view.physicalSize = const Size(824, 1780);
    t.view.devicePixelRatio = 2.0;
    addTearDown(t.view.reset);
    debugDisableShadows = false;
    addTearDown(() => debugDisableShadows = true);
  }

  // Screenshots are written only when run with --update-goldens; they are for looking at, not for
  // pixel-exact comparison (sample data carries timestamps).
  Future<void> shot(String name) async {
    if (autoUpdateGoldenFiles) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/$name.png'));
  }

  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 120));
    }
  }

  Widget app(Widget home, {Brightness b = Brightness.light}) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: seedColor, brightness: b)),
        home: home,
      );

  test('pagination covers every character once and every page fits', () {
    final paras = ['# Chapter 1: The Stairs', for (var i = 0; i < 30; i++) _para(i, 2 + i % 5)];
    TextStyle style(int lvl) => TextStyle(fontFamily: 'Literata', fontSize: lvl > 0 ? 26 : 19, height: lvl > 0 ? 1.25 : 1.55, fontWeight: lvl > 0 ? FontWeight.w700 : FontWeight.w400);
    const w = 360.0, h = 700.0, gap = 13.0;
    final pages = paginate(paras, styleFor: style, width: w, height: h, paraGap: gap);
    expect(pages.length, greaterThan(3));

    // Every paragraph is covered exactly, in order, with no gaps or overlaps.
    final covered = <int, int>{};
    for (final page in pages) {
      for (final s in page) {
        expect(s.start, covered[s.para] ?? 0, reason: 'paragraph ${s.para} continues where it left off');
        expect(s.end, greaterThan(s.start));
        covered[s.para] = s.end;
        expect(s.endsPara, s.end == paraText(paras[s.para]).length);
      }
    }
    for (var i = 0; i < paras.length; i++) {
      expect(covered[i], paraText(paras[i]).length, reason: 'paragraph $i fully placed');
    }

    // Laid out the way the reader draws them, no page is taller than the page area.
    for (final page in pages) {
      var y = 0.0;
      for (final s in page) {
        final tp = TextPainter(
          text: TextSpan(text: paraText(paras[s.para]).substring(s.start, s.end), style: style(headingLevel(paras[s.para]))),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: w);
        y += tp.height + (s.endsPara ? gap : 0);
      }
      expect(y - gap, lessThanOrEqualTo(h + 1), reason: 'page fits');
    }
    expect(pageOfPara(pages, 0), 0);
    expect(pageOfPara(pages, 30), pages.indexWhere((pg) => pg.any((s) => s.para == 30)));
    expect(pageOfPara(pages, 999), pages.length - 1);
  });

  testWidgets('library', (t) async {
    await phone(t);
    await t.pumpWidget(const LanternApp());
    await settle(t);
    expect(find.text('The Azure Lantern'), findsOneWidget);
    await shot('library_reading');

    await t.tap(find.text('All books'));
    await settle(t);
    expect(find.text('An Empty Notebook'), findsOneWidget);
    await shot('library_all');

    settings.set('libraryView', 'grid');
    settings.set('appTheme', 'dark');
    await settle(t);
    await shot('library_grid_dark');

    await t.tap(find.text('Add'));
    await settle(t);
    await shot('library_add');
    await t.tapAt(const Offset(200, 100));
    await settle(t);

    await t.tap(find.byTooltip('Menu'));
    await settle(t);
    await shot('drawer');
    await t.tap(find.text('Highlights & notes'));
    await settle(t);
    expect(find.textContaining('sample highlight'), findsOneWidget);
    await shot('notes');
    await t.tap(find.textContaining('Glossary'));
    await settle(t);
    await shot('glossary');

    await t.tap(find.byTooltip('Menu').first);
    await settle(t);
    await t.tap(find.text('Settings'));
    await settle(t);
    await shot('settings');
  });

  testWidgets('reader, scrolling', (t) async {
    await phone(t);
    final id = (await Db.books()).firstWhere((b) => b.title == 'The Azure Lantern').id!;
    await t.pumpWidget(app(ReaderScreen(bookId: id)));
    await settle(t);
    expect(find.byType(ParaText), findsWidgets);
    // Opens where the book was left: chapter 3.
    expect(find.textContaining('Chapter 3'), findsNothing); // chrome hidden; title is above the saved paragraph
    await shot('reader_scroll');

    // A tap in the middle shows the controls.
    await t.tapAt(const Offset(206, 500));
    await settle(t);
    expect(find.text('Listen'), findsOneWidget);
    expect(find.text('Chapter 3 of 12'), findsOneWidget);
    await shot('reader_controls');

    // Text settings sheet, then switch theme and font from it.
    await t.tap(find.byTooltip('Text and layout'));
    await settle(t);
    await shot('reader_text_sheet');
    await t.tap(find.text('Sepia'));
    await settle(t);
    expect(settings.themeId, 'sepia');
    await t.tapAt(const Offset(206, 120));
    await settle(t);

    // Next chapter from the bar.
    await t.tap(find.byTooltip('Next chapter'));
    await settle(t);
    expect(find.text('Chapter 4 of 12'), findsOneWidget);
    expect((await Db.book(id))!.curChapter, 3);

    // Contents sheet.
    await t.tap(find.byTooltip('Chapters, bookmarks, highlights'));
    await settle(t);
    expect(find.text('Chapters (12)'), findsOneWidget);
    await shot('reader_contents');
  });

  testWidgets('reader, page turning and night theme', (t) async {
    await phone(t);
    settings.set('paged', true);
    settings.setReaderTheme('night');
    final id = (await Db.books()).firstWhere((b) => b.title == 'The Azure Lantern').id!;
    await t.pumpWidget(app(ReaderScreen(bookId: id, chapterIdx: 0, para: 0)));
    await settle(t);
    expect(find.textContaining('1 / '), findsOneWidget);
    await shot('reader_paged_night');

    // Tap the right edge: next page.
    await t.tapAt(const Offset(380, 500));
    await settle(t);
    expect(find.textContaining('2 / '), findsOneWidget);
    // Tap the left edge: back.
    await t.tapAt(const Offset(30, 500));
    await settle(t);
    expect(find.textContaining('1 / '), findsOneWidget);

    // Top-left corner flips day/night; top-right adds a bookmark.
    await t.tapAt(const Offset(30, 60));
    await settle(t);
    expect(settings.readerTheme.dark, false);
    await t.tapAt(const Offset(390, 60));
    await settle(t);
    await t.pump(const Duration(seconds: 5));
    expect((await Db.bookmarks(bookId: id)).length, 2);

    settings.setReaderTheme('console');
    settings.set('fontFamily', 'JetBrains Mono');
    await settle(t);
    await shot('reader_paged_console');
  });

  testWidgets('book details and narration panel', (t) async {
    await phone(t);
    final id = (await Db.books()).firstWhere((b) => b.title == 'The Azure Lantern').id!;
    await t.pumpWidget(app(BookDetailScreen(bookId: id)));
    await settle(t);
    expect(find.text('Continue reading'), findsOneWidget);
    await shot('book_details');

    await t.pumpWidget(app(const Scaffold(body: Align(alignment: Alignment.bottomCenter, child: Material(child: NarrationPanel()))), b: Brightness.dark));
    await settle(t);
    await shot('narration_panel');

    settings.set('voiceSource', 'gemini');
    await t.pumpWidget(app(const Scaffold(body: Material(child: VoicePicker())), b: Brightness.dark));
    await settle(t);
    expect(find.text('Charon'), findsOneWidget);
    await shot('voice_gemini');
  });
}
