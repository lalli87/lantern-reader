import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:charset/charset.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern_reader/src/app.dart';
import 'package:lantern_reader/src/comics.dart';
import 'package:lantern_reader/src/db.dart';
import 'package:lantern_reader/src/importers.dart';
import 'package:lantern_reader/src/pdf_import.dart';
import 'package:lantern_reader/src/rtf.dart';
import 'package:lantern_reader/src/settings.dart';
import 'package:lantern_reader/src/text_decode.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Uint8List zip(Map<String, List<int>> files) {
  final a = Archive();
  for (final e in files.entries) {
    a.addFile(ArchiveFile.bytes(e.key, e.value));
  }
  return Uint8List.fromList(ZipEncoder().encode(a));
}

// A 1×1 PNG.
final png = base64.decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');

void main() {
  group('text encodings', () {
    test('UTF-8, UTF-16 and Windows-1252 are told apart', () {
      expect(decodeText(Uint8List.fromList(utf8.encode('Café “quotes”'))), 'Café “quotes”');
      expect(decodeText(Uint8List.fromList([0xFF, 0xFE, 0x48, 0, 0x69, 0])), 'Hi');
      final le = <int>[];
      for (final c in 'Plain UTF-16 text without a byte order mark, long enough to tell.'.codeUnits) {
        le.addAll([c & 0xFF, c >> 8]);
      }
      expect(decodeText(Uint8List.fromList(le)), startsWith('Plain UTF-16 text'));
      expect(decodeText(windows1252.encode('Café “quotes” — fine')), 'Café “quotes” — fine');
    });

    test('Chinese GBK text (common for downloaded web novels) is read correctly', () {
      const s = '第一章 少年\n他站在山顶，望着远方的云海。这是一个关于修炼的故事。';
      expect(decodeText(Uint8List.fromList(gbk.encode(s))), s);
    });
  });

  group('RTF', () {
    test('text, paragraphs, symbols, Unicode and the title come through; formatting does not', () {
      const rtf = r'{\rtf1\ansi\ansicpg1252\deff0{\fonttbl{\f0 Times New Roman;}}{\colortbl;\red0\green0\blue0;}'
          r'{\info{\title The Long Road}{\author A. Writer}}'
          r'{\*\generator Word;}\pard\b Chapter 1\b0\par '
          r"It was a caf\'e9 \ldblquote by the sea\rdblquote .\par "
          r'Unicode: \u8364?uro and \u20013?\par '
          r'{\pict\pngblip 89504e47}Chapter 2\par Second\line line.\par}';
      final b = parseRtf(Uint8List.fromList(latin1.encode(rtf)), 'file');
      expect(b.title, 'The Long Road');
      expect(b.author, 'A. Writer');
      expect(b.format, 'RTF');
      expect(b.chapters.map((c) => c.title), ['Chapter 1', 'Chapter 2']);
      final all = b.chapters.expand((c) => c.paras).toList();
      expect(all, contains('It was a café “by the sea”.'));
      expect(all, contains('Unicode: €uro and 中'));
      expect(all, contains('Second'));
      expect(all.join(' '), isNot(contains('Times New Roman')));
      expect(all.join(' '), isNot(contains('89504e47')));
    });
  });

  test('a book inside a ZIP file is found and read', () {
    final epubless = zip({
      '__MACOSX/._book.fb2': [1, 2, 3],
      'readme.txt': utf8.encode('hi'),
      'book.fb2': utf8.encode('<?xml version="1.0"?><FictionBook><description><title-info><book-title>Zipped</book-title>'
          '</title-info></description><body><section><title><p>One</p></title><p>${'Words in a line. ' * 40}</p></section></body></FictionBook>'),
    });
    final b = parseBookBytes(epubless, 'book.fb2.zip');
    expect(b.title, 'Zipped');
  });

  group('comics', () {
    late Directory dir;
    setUpAll(() async {
      sqfliteFfiInit();
      dir = await Directory.systemTemp.createTemp('lantern_comics');
      dataDir = dir.path;
      await Db.open(inMemoryDatabasePath, factory: databaseFactoryFfiNoIsolate);
      settings = Settings();
      await settings.load();
    });
    tearDownAll(() async {
      await Db.close();
      await dir.delete(recursive: true);
    });

    test('pages sort the way people expect', () {
      final names = ['p10.jpg', 'p2.jpg', 'p1.jpg', 'Cover.jpg'];
      names.sort(naturalCompare);
      expect(names, ['Cover.jpg', 'p1.jpg', 'p2.jpg', 'p10.jpg']);
    });

    test('a CBZ becomes a book of pages, with its ComicInfo details and cover', () async {
      final bytes = zip({
        'Issue 1/page10.png': png,
        'Issue 1/page2.png': png,
        'Issue 1/page1.png': png,
        'Issue 1/Thumbs.db': [0],
        'ComicInfo.xml': utf8.encode('<ComicInfo><Series>Star Ranger</Series><Number>3</Number><Writer>Ann Lee</Writer></ComicInfo>'),
      });
      final f = File('${dir.path}/ranger.cbz')..writeAsBytesSync(bytes);
      expect(zipIsComic(f.path), isTrue);
      final id = await importComic(f.path, 'ranger.cbz', bytes.length);
      final b = (await Db.book(id))!;
      expect(b.format, 'CBZ');
      expect(b.title, 'Star Ranger #3');
      expect(b.author, 'Ann Lee');
      expect(b.chapterCount, 3);
      expect(b.coverPath, isNotNull);
      expect(comicPages(id).length, 3);
      await deleteComicPages(id);
      expect(comicPages(id), isEmpty);
    });

    test('a ZIP of book files is not mistaken for a comic', () {
      final f = File('${dir.path}/books.zip')..writeAsBytesSync(zip({'a.epub': [1], 'b.txt': utf8.encode('x'), 'cover.jpg': png}));
      expect(zipIsComic(f.path), isFalse);
    });

    test('an archive with no pictures gives a clear message', () async {
      final f = File('${dir.path}/empty.cbz')..writeAsBytesSync(zip({'notes.txt': utf8.encode('nothing')}));
      expect(() => importComic(f.path, 'empty.cbz', 10), throwsA(isA<FormatException>()));
    });

    test('a PDF inside a ZIP is passed to the PDF reader', () async {
      final f = File('${dir.path}/notpdf.zip')..writeAsBytesSync(zip({'story.txt': utf8.encode('Chapter 1\nHello there.\nChapter 2\nBye.')}));
      final b = await parseBookFile(f.path, 'notpdf.zip');
      expect(b.chapters.map((c) => c.title), ['Chapter 1', 'Chapter 2']);
    });
  });
}
