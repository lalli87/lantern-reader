import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lantern_reader/src/importers.dart';
import 'package:lantern_reader/src/mobi.dart';

/// PalmDOC "compression" using only literals (enough to exercise the reader).
Uint8List palmLiteral(List<int> b) {
  final out = <int>[];
  for (final c in b) {
    if (c >= 0x09 && c < 0x80) {
      out.add(c);
    } else {
      out
        ..add(1)
        ..add(c);
    }
  }
  return Uint8List.fromList(out);
}

Uint8List u32(int v) => Uint8List(4)..buffer.asByteData().setUint32(0, v);
Uint8List u16(int v) => Uint8List(2)..buffer.asByteData().setUint16(0, v);

/// A minimal Kindle file: record 0 (PalmDOC + MOBI + EXTH headers), text records, optional extra records.
Uint8List buildMobi(String html,
    {int version = 6, int encryption = 0, String title = 'Test Book', String author = 'Jane Writer', List<Uint8List> extra = const [], int? fdst}) {
  final text = utf8.encode(html);
  final textRecs = <Uint8List>[];
  for (var i = 0; i < text.length; i += 4096) {
    final chunk = text.sublist(i, i + 4096 > text.length ? text.length : i + 4096);
    // One trailing entry of 3 bytes (extra-data flag bit 1).
    textRecs.add(Uint8List.fromList([...palmLiteral(chunk), 0xAA, 0xBB, 0x83]));
  }
  final exthRecs = <int>[];
  void ex(int type, List<int> data) => exthRecs.addAll([...u32(type), ...u32(data.length + 8), ...data]);
  ex(100, utf8.encode(author));
  ex(503, utf8.encode(title));
  final exth = [...latin1.encode('EXTH'), ...u32(12 + exthRecs.length), ...u32(2), ...exthRecs];
  const mobiLen = 0xE8;
  final r0 = Uint8List(16 + mobiLen + exth.length + 32);
  final bd = r0.buffer.asByteData();
  bd.setUint16(0, 2); // PalmDOC
  bd.setUint32(4, text.length);
  bd.setUint16(8, textRecs.length);
  bd.setUint16(10, 4096);
  bd.setUint16(12, encryption);
  r0.setAll(16, latin1.encode('MOBI'));
  bd.setUint32(20, mobiLen);
  bd.setUint32(24, 2);
  bd.setUint32(28, 65001);
  bd.setUint32(36, version);
  final nameOff = 16 + mobiLen + exth.length;
  bd.setUint32(0x54, nameOff);
  bd.setUint32(0x58, 4);
  bd.setUint32(0x6C, 0xFFFFFFFF);
  bd.setUint32(0x80, 0x40);
  if (fdst != null) bd.setUint32(0xC0, fdst);
  bd.setUint16(0xF2, 2);
  r0.setAll(16 + mobiLen, exth);
  r0.setAll(nameOff, latin1.encode('Name'));

  final records = [r0, ...textRecs, ...extra];
  final headerLen = 78 + records.length * 8 + 2;
  final out = BytesBuilder();
  final head = Uint8List(78);
  head.setAll(0, latin1.encode('test'));
  head.setAll(60, latin1.encode('BOOKMOBI'));
  head.buffer.asByteData().setUint16(76, records.length);
  out.add(head);
  var off = headerLen;
  for (var i = 0; i < records.length; i++) {
    out.add(u32(off));
    out.add(u32(i * 2));
    off += records[i].length;
  }
  out.add([0, 0]);
  for (final r in records) {
    out.add(r);
  }
  return out.toBytes();
}

void main() {
  test('PalmDOC decompression handles literals, spaces and back-references', () {
    // "ab" + space-prefixed 'c' (0xE3) + back-reference distance 4 length 3 + literal run.
    final data = Uint8List.fromList([0x61, 0x62, 0xE3, 0x80, (4 << 3) | 0, 0x02, 0x58, 0x59]);
    expect(latin1.decode(palmDocDecompress(data)), 'ab cab XY');
  });

  test('trailing record bytes are removed', () {
    expect(trailingSize(Uint8List.fromList([0x41, 0x42, 0xAA, 0xBB, 0x83]), 2), 3);
    expect(trailingSize(Uint8List.fromList([0x41, 0x42, 0x01]), 1), 2, reason: 'multibyte flag: low 2 bits + 1');
  });

  test('a MOBI book becomes chapters at its page breaks, with title and author', () {
    final body = List.generate(40, (i) => '<p>Line $i of the story, with some words to make it a real paragraph.</p>').join();
    final html = '<html><body><p>Test Book</p><p>Copyright</p><mbp:pagebreak/>'
        '<h2>Chapter 1</h2>$body<mbp:pagebreak/><h2>Chapter 2</h2>$body<p>“Quotes” — dashes</p></body></html>';
    final b = parseBookBytes(buildMobi(html), 'test.mobi');
    expect(b.format, 'MOBI');
    expect(b.title, 'Test Book');
    expect(b.author, 'Jane Writer');
    expect(b.chapters.map((c) => c.title), ['Chapter 1', 'Chapter 2']);
    expect(b.chapters.first.paras.first, 'Test Book', reason: 'the title page goes with the first chapter');
    expect(b.chapters.last.paras.last, '“Quotes” — dashes');
    expect(b.chapters.last.paras.where((p) => p.startsWith('Line')).length, 40);
  });

  test('a KF8 (AZW3) book is read from its first flow, one chapter per file', () {
    final body = List.generate(30, (i) => '<p>Para $i of this part, long enough to count as a chapter of text.</p>').join();
    final html = '<?xml version="1.0"?><html><body><h1>Prologue</h1>$body</body></html>'
        '<?xml version="1.0"?><html><body><h1>The Gate</h1>$body</body></html>';
    final css = 'p { margin: 0 } h1 { color: red }';
    final flowLen = utf8.encode(html).length, total = flowLen + css.length;
    final fdstRec = Uint8List.fromList([...latin1.encode('FDST'), ...u32(12), ...u32(2), ...u32(0), ...u32(flowLen), ...u32(flowLen), ...u32(total)]);
    final textRecords = (total / 4096).ceil();
    final bytes = buildMobi(html + css, version: 8, extra: [fdstRec], fdst: 1 + textRecords);
    final b = parseBookBytes(bytes, 'book.azw3');
    expect(b.format, 'AZW3');
    expect(b.chapters.map((c) => c.title), ['Prologue', 'The Gate']);
    expect(b.chapters.expand((c) => c.paras).any((p) => p.contains('margin')), isFalse, reason: 'style sheets are not text');
  });

  test('copy-protected Kindle books get a clear message', () {
    expect(
      () => parseBookBytes(buildMobi('<p>x</p>', encryption: 2), 'locked.azw'),
      throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('copy-protected'))),
    );
  });

  test('a Kindle file with an unknown extension is still recognised', () {
    final html = '<h2>Chapter 1</h2>${'<p>Some text in a paragraph here.</p>' * 30}<h2>Chapter 2</h2>${'<p>More text.</p>' * 30}';
    expect(parseBookBytes(buildMobi(html), 'download.bin').chapters.length, 2);
  });
}
