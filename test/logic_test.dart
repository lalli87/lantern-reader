import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern_reader/src/ai.dart';
import 'package:lantern_reader/src/browser.dart';
import 'package:lantern_reader/src/cloud_tts.dart';
import 'package:lantern_reader/src/pdf_import.dart';
import 'package:lantern_reader/src/pdf_pages.dart';
import 'package:lantern_reader/src/db.dart';
import 'package:lantern_reader/src/epub_export.dart';
import 'package:lantern_reader/src/exports.dart';
import 'package:lantern_reader/src/importers.dart';
import 'package:lantern_reader/src/models.dart';
import 'package:lantern_reader/src/reader_widgets.dart';
import 'package:lantern_reader/src/text_utils.dart';
import 'package:lantern_reader/src/updates.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('text', () {
    test('html becomes paragraphs with headings', () {
      final p = htmlToParagraphs('<div><h1>Chapter 1: Dawn</h1><p>First   line.</p><p>Second<br>third</p>'
          '<script>x()</script><nav>menu</nav><h3>Part</h3><div>Tail&nbsp;text</div></div>');
      expect(p, ['# Chapter 1: Dawn', 'First line.', 'Second', 'third', '### Part', 'Tail text']);
      expect(headingLevel(p[0]), 1);
      expect(paraText(p[4]), 'Part');
      expect(headingLevel('#hashtag not heading'), 0);
    });

    test('speech chunks cover long paragraphs without losing text', () {
      final long = List.generate(60, (i) => 'Sentence number $i goes on for a little while.').join(' ');
      final chunks = speechChunks(['# Title', 'Short one.', long, '   '], maxLen: 300);
      expect(chunks.first.text, 'Title');
      expect(chunks.every((c) => c.text.length <= 300), true);
      final rebuilt = chunks.where((c) => c.para == 2).map((c) => c.text).join();
      expect(rebuilt, long);
      // Chunks of the long paragraph are contiguous.
      final parts = chunks.where((c) => c.para == 2).toList();
      for (var i = 1; i < parts.length; i++) {
        expect(parts[i].start, parts[i - 1].end);
      }
      expect(chunks.any((c) => c.para == 3), false);
    });

    test('resume point is the start of the sentence', () {
      const t = 'One two. Three four five! Six seven.';
      expect(sentenceStartBefore(t, 0), 0);
      expect(sentenceStartBefore(t, 15), 9);
      expect(t.substring(sentenceStartBefore(t, 30)), 'Six seven.');
    });

    test('pronunciation rules', () {
      expect(applyReplacements('Xiao Yan met xiao yan. Yanxiao stays.', [
        ['Xiao Yan', 'Shao Yen']
      ]), 'Shao Yen met Shao Yen. Yanxiao stays.');
      expect(applyReplacements('a -> b', [
        ['->', 'to']
      ]), 'a to b');
    });

    test('glossary pattern matches whole words only', () {
      final re = glossaryPattern([DictEntry(kind: 1, word: 'Lin'), DictEntry(kind: 2, word: 'Nascent Soul')])!;
      final hits = re.allMatches('Lin reached Nascent Soul; Linda did not. LIN!').map((m) => m.group(0)).toList();
      expect(hits, ['Lin', 'Nascent Soul', 'LIN']);
      expect(glossaryPattern([]), null);
    });

    test('translation batches keep every paragraph', () {
      final paras = List.generate(40, (i) => 'p$i ${'x' * 400}');
      final b = batchParagraphs(paras, maxChars: 3000);
      expect(b.expand((e) => e).toList(), paras);
      expect(b.length, greaterThan(3));
    });
  });

  group('browser helpers', () {
    test('javascript results unwrap', () {
      expect(unwrapJsResult('{"a":1}'), {'a': 1});
      expect(unwrapJsResult(jsonEncode('{"a":1}')), {'a': 1});
      expect(unwrapJsResult('"https://x.y/z"'), 'https://x.y/z');
      expect(unwrapJsResult('null'), null);
    });

    test('book title guess', () {
      expect(guessBookTitle('Chapter 12: The Gate - Martial Peak | WuxiaWorld', 'www.wuxiaworld.com'), 'Martial Peak');
      expect(guessBookTitle('Chapter 3', 'novel.example.com'), 'novel.example.com');
    });
  });

  group('audio', () {
    test('wav round trip and merge', () {
      final pcm = Uint8List.fromList(List.generate(1000, (i) => i % 256));
      final wav = pcmToWav(pcm, 24000);
      final back = parseWav(wav)!;
      expect(back.sampleRate, 24000);
      expect(back.pcm, pcm);
      final merged = parseWav(mergeWavs([wav, wav])!)!;
      expect(merged.pcm.length, 2000);
      expect(parseWav(Uint8List(10)), null);
    });

    test('wav with unknown data size still parses', () {
      final wav = pcmToWav(Uint8List.fromList(List.filled(200, 7)), 22050);
      ByteData.sublistView(wav).setUint32(40, 0xFFFFFFFF, Endian.little);
      expect(parseWav(wav)!.pcm.length, 200);
    });

    test('incremental wav writer', () async {
      final dir = await Directory.systemTemp.createTemp('lantern');
      final path = '${dir.path}/a.wav';
      final w = await WavWriter.open(path);
      await w.add(Uint8List.fromList(List.filled(300, 1)), 24000);
      await w.add(Uint8List.fromList(List.filled(500, 2)), 24000);
      await w.add(Uint8List.fromList(List.filled(100, 3)), 16000); // wrong rate is skipped
      expect(await w.close(), 800);
      final back = parseWav(await File(path).readAsBytes())!;
      expect(back.sampleRate, 24000);
      expect(back.pcm.length, 800);
      expect(back.pcm[299], 1);
      expect(back.pcm[300], 2);
      await dir.delete(recursive: true);
    });
  });

  group('books', () {
    final book = Book(id: 7, title: 'Tom & "Jerry" <1>', author: 'A. Writer', series: 'Saga', seriesNo: 2, language: 'en');
    final chapters = [
      Chapter(bookId: 7, idx: 0, title: 'Chapter 1: Start', content: 'Hello <world> & all.\nSecond paragraph.'),
      Chapter(bookId: 7, idx: 1, title: 'Chapter 2', content: '# Chapter 2\n## Scene\nText here.'),
    ];

    test('epub export reads back identically', () {
      final bytes = buildEpub(book, chapters);
      final zip = ZipDecoder().decodeBytes(bytes);
      expect(zip.files.first.name, 'mimetype');
      expect(utf8.decode(zip.files.first.readBytes()!), 'application/epub+zip');
      // The first entry must be stored, not compressed, for strict readers.
      expect(bytes.sublist(30, 38 + 20), utf8.encode('mimetypeapplication/epub+zip'));

      final back = parseBookBytes(bytes, 'x.epub');
      expect(back.title, book.title);
      expect(back.author, 'A. Writer');
      expect(back.series, 'Saga');
      expect(back.seriesNo, 2);
      expect(back.chapters.map((c) => c.title), ['Chapter 1: Start', 'Chapter 2']);
      expect(back.chapters[0].paras, ['# Chapter 1: Start', 'Hello <world> & all.', 'Second paragraph.']);
      expect(back.chapters[1].paras, ['# Chapter 2', '## Scene', 'Text here.']);
    });

    test('plain text export', () {
      final t = buildPlainText(book, chapters);
      expect(t.contains('Chapter 1: Start\n\nHello <world> & all.'), true);
      expect('Chapter 2'.allMatches(t).length, 1);
    });

    test('txt chapters are detected', () {
      final b = parseBookBytes(utf8.encode('Intro words\n\nChapter 1\nAlpha.\n\nChapter 2: Two\nBeta.\nGamma.\n'), 'My Novel.txt');
      expect(b.title, 'My Novel');
      expect(b.chapters.map((c) => c.title), ['My Novel', 'Chapter 1', 'Chapter 2: Two']);
      expect(b.chapters[2].paras, ['Beta.', 'Gamma.']);
    });

    test('update check compares versions and reads GitHub releases', () {
      expect(compareVersions('0.2.10', '0.2.9'), greaterThan(0));
      expect(compareVersions('v0.2.7', '0.2.7'), 0);
      expect(compareVersions('0.2', '0.2.1'), lessThan(0));
      final r = parseRelease({
        'tag_name': 'v0.2.8',
        'html_url': 'https://github.com/lalli87/lantern-reader/releases/tag/v0.2.8',
        'published_at': '2026-11-16T18:00:00Z',
        'body': 'Add update check\n\nCo-Authored-By: Claude <x@y>\n\n- **lantern-reader.apk**: direct install\n- **lantern-reader.aab**: Play',
        'assets': [
          {'name': 'lantern-reader.aab', 'browser_download_url': 'https://x/aab', 'size': 1},
          {'name': 'lantern-reader.apk', 'browser_download_url': 'https://x/apk', 'size': 52000000},
        ],
      });
      expect(r.version, '0.2.8');
      expect(r.apkUrl, 'https://x/apk');
      expect(r.notes, 'Add update check');
    });

    test('pdf paragraphs remember the page they start on', () {
      final pages = <int>[];
      final paras = pdfPagesToParagraphs([
        'Chapter 1\nThe first paragraph is long enough to look like a full line of text here\nand ends now.\n',
        'A second paragraph on page two that is also quite long so the line counts\nas full.\n',
        'Chapter 2\nThird page text.\n',
      ], firstPage: 4, pagesOut: pages);
      expect(paras.length, pages.length);
      expect(paras.first, 'Chapter 1');
      expect(pages.first, 4);
      expect(pages[paras.indexWhere((x) => x.startsWith('A second'))], 5);
      expect(pages[paras.indexOf('Chapter 2')], 6);
    });

    test('pdf page map finds text for a page and a page for text', () {
      final m = PdfPageMap([
        [1, 1, 2, 4], // chapter 0 starts on page 1 (page 0 is a cover), page 3 is only pictures
        [5, 6],
      ]);
      expect(m.pageOf(0, 2), 2);
      expect(m.pageOf(1, 9), 6);
      expect(m.pageOf(2, 0), isNull);
      expect(m.locate(0), (0, 0)); // cover: start of the text
      expect(m.locate(1), (0, 0)); // first paragraph on the page, not the last
      expect(m.locate(3), (0, 2)); // picture page: the text that runs onto it
      expect(m.locate(5), (1, 0));
      expect(PdfPageMap.parse(m.toJson()).chapters, m.chapters);
    });

    test('files are imported from a path, not from bytes held by the picker', () async {
      final dir = await Directory.systemTemp.createTemp('lantern_import');
      final f = File('${dir.path}/From Disk.txt')..writeAsStringSync('Chapter 1\nAlpha.\n\nChapter 2\nBeta.\n');
      final b = await parseBookFile(f.path, 'From Disk.txt');
      expect(b.chapters.map((c) => c.title), ['Chapter 1', 'Chapter 2']);
      await dir.delete(recursive: true);
    });

    test('txt without chapters is one chapter', () {
      final b = parseBookBytes(utf8.encode('Just a note.\nAnother line.'), 'note.txt');
      expect(b.chapters.length, 1);
      expect(b.chapters.first.paras.length, 2);
    });

    test('markdown headings split chapters', () {
      final b = parseBookBytes(utf8.encode('# One\nSome **bold** and *soft* text.\n\n# Two\n- item\n> quoted [link](http://a.b)\n'), 'm.md');
      expect(b.chapters.map((c) => c.title), ['One', 'Two']);
      expect(b.chapters[0].paras, ['Some bold and soft text.']);
      expect(b.chapters[1].paras, ['- item', 'quoted link']);
    });

    test('fb2', () {
      const fb2 = '<?xml version="1.0"?><FictionBook xmlns:l="http://www.w3.org/1999/xlink"><description><title-info>'
          '<author><first-name>Ann</first-name><last-name>Lee</last-name></author><book-title>Fb Book</book-title>'
          '<annotation><p>About it.</p></annotation><lang>en</lang><sequence name="Ser" number="3"/></title-info></description>'
          '<body><section><title><p>Ch A</p></title><p>Para one.</p><section><title><p>Sub</p></title><p>Inner.</p></section></section>'
          '<section><title><p>Ch B</p></title><p>Para two.</p></section></body></FictionBook>';
      final b = parseBookBytes(utf8.encode(fb2), 'f.fb2');
      expect([b.title, b.author, b.series, b.seriesNo, b.description], ['Fb Book', 'Ann Lee', 'Ser', 3, 'About it.']);
      expect(b.chapters.map((c) => c.title), ['Ch A', 'Ch B']);
      expect(b.chapters[0].paras, ['Para one.', '## Sub', 'Inner.']);
    });

    test('docx', () {
      final a = Archive();
      const doc = '<w:document xmlns:w="w"><w:body>'
          '<w:p><w:pPr><w:pStyle w:val="Heading1"/></w:pPr><w:r><w:t>First</w:t></w:r></w:p>'
          '<w:p><w:r><w:t>Hello </w:t></w:r><w:r><w:t>there.</w:t></w:r></w:p>'
          '<w:p><w:pPr><w:pStyle w:val="Heading1"/></w:pPr><w:r><w:t>Second</w:t></w:r></w:p>'
          '<w:p><w:r><w:t>Bye.</w:t></w:r></w:p></w:body></w:document>';
      a.addFile(ArchiveFile.bytes('word/document.xml', utf8.encode(doc)));
      final b = parseBookBytes(ZipEncoder().encodeBytes(a), 'Doc Name.docx');
      expect(b.title, 'Doc Name');
      expect(b.chapters.map((c) => c.title), ['First', 'Second']);
      expect(b.chapters[0].paras, ['Hello there.']);
    });

    test('unsupported and broken files fail clearly', () {
      expect(() => parseBookBytes(Uint8List(4), 'a.pdf'), throwsFormatException);
      expect(() => parseBookBytes(Uint8List.fromList([1, 2, 3]), 'a.epub'), throwsFormatException);
    });
  });

  group('database', () {
    setUp(() async {
      sqfliteFfiInit();
      await Db.open(inMemoryDatabasePath, factory: databaseFactoryFfiNoIsolate);
    });
    tearDown(Db.close);

    test('chapters append, reorder, delete and keep counts', () async {
      final id = await Db.insertBook(Book(title: 'B'));
      final c1 = await Db.addChapter(id, 'one', 'aaaa', url: 'http://x/1');
      final c2 = await Db.addChapter(id, 'two', 'bbbbbb');
      final c3 = await Db.addChapter(id, 'three', 'cc');
      var b = (await Db.book(id))!;
      expect([b.chapterCount, b.charCount], [3, 12]);
      expect(await Db.hasChapterUrl(id, 'http://x/1'), true);
      expect(await Db.hasChapterUrl(id, 'http://x/2'), false);

      await Db.reorderChapters(id, [c3, c1, c2]);
      expect((await Db.chapterMetas(id)).map((m) => m.title), ['three', 'one', 'two']);
      await Db.deleteChapter(id, c1);
      final metas = await Db.chapterMetas(id);
      expect(metas.map((m) => (m.idx, m.title)), [(0, 'three'), (1, 'two')]);
      b = (await Db.book(id))!;
      expect([b.chapterCount, b.charCount], [2, 8]);
      expect((await Db.chapterAt(id, 1))!.title, 'two');
    });

    test('position, marks, shelves, trash, delete', () async {
      final id = await Db.insertBook(Book(title: 'B'));
      final c = await Db.addChapter(id, 'one', 'a\nb\nc\nd');
      await Db.addChapter(id, 'two', 'e');
      await Db.savePosition(id, 1, 0);
      final b = (await Db.book(id))!;
      expect(b.curChapter, 1);
      expect(b.progress, 0.5);
      expect(b.lastReadAt, greaterThan(0));

      await Db.addBookmark(Bookmark(bookId: id, chapterId: c, para: 2, snippet: 'c'));
      final q = Quote(bookId: id, chapterId: c, para: 1, start: 0, end: 1, text: 'b');
      await Db.addQuote(q);
      q.note = 'n';
      await Db.updateQuote(q);
      expect((await Db.quotes(chapterId: c)).single.note, 'n');
      expect((await Db.bookmarks(bookId: id)).single.para, 2);

      final s = await Db.addShelf('Fav');
      await Db.setOnShelf(s, id, true);
      await Db.setOnShelf(s, id, true);
      expect((await Db.shelves()).single.count, 1);
      expect(await Db.shelfIdsOf(id), {s});

      await Db.setTrashed(id, true);
      expect(await Db.books(), isEmpty);
      expect((await Db.books(trashed: true)).length, 1);
      expect((await Db.shelves()).single.count, 0);
      await Db.deleteBook(id);
      expect(await Db.quotes(), isEmpty);
      expect(await Db.bookmarks(), isEmpty);
      expect(await Db.chapterMetas(id), isEmpty);
    });

    test('imported book is stored with its chapters', () async {
      final ib = parseBookBytes(utf8.encode('# A\nx\n# B\ny'), 't.md');
      final id = await saveImported(ib, fileName: 't.md', fileSize: 11);
      final b = (await Db.book(id))!;
      expect([b.format, b.chapterCount, b.fileName], ['MD', 2, 't.md']);
      await Db.setTranslation((await Db.chapterMetas(id)).first.id, 'tr', 'French');
      expect((await Db.chapterMetas(id)).map((m) => m.hasTranslation), [true, false]);
    });
  });

  group('new in 0.2', () {
    test('pdf lines become paragraphs', () {
      final pageA = 'The keeper wrote her name in a ledger that looked older than the gate it-\n'
          'self, and when he finished he blew on the ink as if it mattered very much\n'
          'that it dried properly.\n'
          'She waited.\n'
          '12\n';
      final pageB = '"Next," he said, and that was all. The morning went on without her, bright\n'
          'and cold and entirely uninterested in what she had come all this way to do.\n';
      final p = pdfPagesToParagraphs([pageA, pageB]);
      expect(p, [
        'The keeper wrote her name in a ledger that looked older than the gate itself, and when he finished he blew on the ink as if it mattered very much that it dried properly.',
        'She waited.',
        '"Next," he said, and that was all. The morning went on without her, bright and cold and entirely uninterested in what she had come all this way to do.',
      ]);
    });

    test('pdf text with chapter headings is split', () {
      final paras = pdfPagesToParagraphs(['Chapter 1\nIt began with rain falling on the roofs of the town all night long.\n', 'Chapter 2\nThe sun came up.\n']);
      final b = singleToBook('X', 'PDF', paras, detectChapters: true);
      expect(b.chapters.map((c) => c.title), ['Chapter 1', 'Chapter 2']);
    });

    test('cloud chunks merge short lines but keep long paragraphs whole', () {
      final paras = ['"Yes."', '"No."', '"Maybe," she said.', 'x' * 900, 'Short end.'];
      final c = cloudChunks(paras);
      expect(c.first.para, 0);
      expect(c.first.lastPara, 2);
      expect(c.first.text, '"Yes."\n"No."\n"Maybe," she said.');
      expect(c[1].para, 3);
      expect(c[1].text.length, 900);
      expect(c.last.text, 'Short end.');
    });

    test('google voice kinds', () {
      expect(googleVoiceKind('en-US-Chirp3-HD-Charon'), 'Chirp3-HD');
      expect(googleVoiceKind('en-US-Neural2-D'), 'Neural2');
      expect(googleVoiceKind('en-GB-Studio-B'), 'Studio');
      expect(googleVoiceKind('en-US-Standard-A'), 'Standard');
    });
  });
}
