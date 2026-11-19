import 'package:flutter_test/flutter_test.dart';
import 'package:lantern_reader/src/pdf_column_zoom.dart';
import 'package:lantern_reader/src/pdf_import.dart';
import 'package:lantern_reader/src/pdf_layout.dart';

const _pageH = 800.0;

/// Builds pdfium-style text plus one box per character (PDF coordinates, origin bottom-left)
/// from printed lines given as (text, x, topY, size). Lines are emitted in the order given,
/// which lets a test scramble the order the way real magazine PDFs do.
(String, List<(double, double, double, double)>) _page(List<(String, double, double, double)> lines) {
  final text = StringBuffer();
  final rects = <(double, double, double, double)>[];
  for (final (t, x, top, size) in lines) {
    var cx = x;
    for (final ch in t.split('')) {
      final w = size * 0.5;
      final glyphH = RegExp(r'[A-Zbdfhklt]').hasMatch(ch) ? size * 0.72 : size * 0.5;
      rects.add((cx, _pageH - top - (size * 0.72 - glyphH), cx + w, _pageH - top - size * 0.72));
      text.write(ch);
      cx += w;
    }
    text.write('\n');
    rects.add((0, 0, 0, 0));
  }
  return (text.toString(), rects);
}

PageLayout _lay(List<(String, double, double, double)> lines) {
  final (t, r) = _page(lines);
  return layoutPage(segmentsFromChars(t, r, _pageH), 600, _pageH);
}

List<String> _paras(List<(String, double, double, double)> lines) => pdfPagesToParagraphs([layoutToText(_lay(lines))]);

void main() {
  // Two columns of 4 lines each, 10 pt type, 14 pt line pitch.
  final left = [
    'The harbor was quiet that morning and the boats',
    'rocked against the pier while gulls circled over',
    'the water looking for scraps from the fishermen',
    'who had been out since well before the dawn.',
  ];
  final right = [
    'Across town the market was already busy with',
    'vendors shouting prices for tomatoes, peppers',
    'and bread that had come out of the ovens only',
    'minutes earlier, still warm to the touch.',
  ];

  test('columns printed side by side are read one column at a time', () {
    // pdfium often returns such pages line by line across both columns.
    final lines = <(String, double, double, double)>[
      ('Morning in the Port Town', 40, 40, 22),
      for (var i = 0; i < 4; i++) ...[(left[i], 40, 100.0 + i * 14, 10), (right[i], 320, 100.0 + i * 14, 10)],
    ];
    final p = _paras(lines);
    expect(p, ['Morning in the Port Town', left.join(' '), right.join(' ')]);
  });

  test('a paragraph flowing into the next column stays one paragraph', () {
    final lines = <(String, double, double, double)>[
      for (var i = 0; i < 4; i++) (left[i].replaceAll('dawn.', 'dawn and'), 40, 100.0 + i * 14, 10),
      for (var i = 0; i < 4; i++) (right[i], 320, 100.0 + i * 14, 10),
    ];
    final p = _paras(lines);
    expect(p.length, 1);
    expect(p.single, contains('dawn and Across town'));
  });

  test('headings, short lines and blank space start new paragraphs', () {
    final p = _paras([
      ('Zinnia', 40, 60, 20),
      ('{ Zinnia Elegans }', 40, 86, 10),
      ('Old-fashioned zinnias provide a bounty of cut flowers', 40, 104, 10),
      ('from summer right through to the first frost.', 40, 118, 10),
      ('Zinnias are one of the fastest annuals to grow from', 40, 140, 10),
      ('seed, so sow them right up to early summer.', 40, 154, 10),
    ]);
    expect(p, [
      'Zinnia',
      '{ Zinnia Elegans }',
      'Old-fashioned zinnias provide a bounty of cut flowers from summer right through to the first frost.',
      'Zinnias are one of the fastest annuals to grow from seed, so sow them right up to early summer.',
    ]);
  });

  test('page folios in the margin and sideways credits are dropped', () {
    final lines = <(String, double, double, double)>[
      for (var i = 0; i < 4; i++) (left[i], 40, 100.0 + i * 14, 10),
      // A photo credit printed up the page edge arrives one letter per line.
      for (var i = 0; i < 8; i++) ('RALPHLEE'[i], 580, 300.0 + i * 6, 6),
      ('8 | SOUTHERN LIVING', 40, 770, 8),
    ];
    expect(_paras(lines), [left.join(' ')]);
  });

  test('running headers repeated on many pages are found', () {
    final lay = _lay([('THE MOUNTAIN SAGA', 40, 20, 8), (left[0], 40, 100, 10)]);
    final key = normalizedMarginLine(lay.lines.first, lay);
    expect(key, 'the mountain saga');
    expect(layoutToText(lay, skip: {key}), isNot(contains('MOUNTAIN')));
  });

  test('blockAt finds the column under a tap', () {
    final lay = _lay([
      for (var i = 0; i < 4; i++) ...[(left[i], 40, 100.0 + i * 14, 10), (right[i], 320, 100.0 + i * 14, 10)],
    ]);
    expect(lay.blocks.length, 2);
    expect(lay.blockAt(100, 120)!.l, lessThan(50));
    expect(lay.blockAt(400, 120)!.l, greaterThan(300));
    expect(lay.blockAt(300, 700), isNull);
  });

  test('a plain single-column page keeps its paragraphs', () {
    final p = _paras([
      ('    It was late when the cultivator finally reached the', 40, 100, 10),
      ('mountain gate, and the guards had long since gone home.', 40, 114, 10),
      ('    He sat down on the cold stone steps and waited for the', 40, 128, 10),
      ('sun to rise over the eastern ridge.', 40, 142, 10),
    ]);
    expect(p.length, 2);
    expect(p.first, endsWith('gone home.'));
  });

  group('column mode', () {
    // Two tall columns, 250 pt wide: on a 2:1 phone view about 532 pt of a column fits.
    const cols = [LRect(40, 100, 290, 1300), LRect(320, 100, 570, 900)];
    const aspect = 2.0;

    test('double-tap picks the column and starts near its top', () {
      final s = spotAt(cols, 1, 400, 150, aspect)!;
      expect(s.block, 1);
      expect(s.top, 100 - columnPad);
      expect(spotAt(cols, 1, 300, 5000, aspect), isNull);
    });

    test('side taps walk down a column, into the next, then off the page', () {
      var s = const ColumnSpot(1, 0, 92);
      final tops = <(int, int)>[];
      while (true) {
        final n = stepColumn(cols, s, 1, aspect);
        if (n == null) break;
        s = n;
        tops.add((s.block, s.top.round()));
      }
      expect(tops.first.$1, 0);
      expect(tops.where((t) => t.$1 == 1).first.$2, 92); // second column starts at its top
      expect(s.block, 1);
      // Each screen shares a little with the one before, and nothing is skipped.
      final h = columnViewHeight(cols[0], aspect);
      expect(tops.first.$2 - 92, lessThan(h));
      // And back again.
      final back = stepColumn(cols, const ColumnSpot(1, 1, 92), -1, aspect)!;
      expect(back.block, 0);
      expect(back.top + h, closeTo(1300 + columnPad, 0.01));
    });

    test('the area shown is the column width at the phone shape', () {
      final (l, t, r, b) = columnArea(cols[0], 92, aspect, 1400);
      expect(l, 40 - columnPad);
      expect(r, 290 + columnPad);
      expect((b - t) / (r - l), closeTo(aspect, 0.001));
    });
  });

  group('OCR', () {
    OcrWord w(String t, double l, double top, double h) => OcrWord(t, LRect(l, top, l + t.length * h * 0.5, top + h));
    List<OcrWord> line(String text, double l, double top, double h) {
      final out = <OcrWord>[];
      var x = l;
      for (final t in text.split(' ')) {
        out.add(w(t, x, top, h));
        x += t.length * h * 0.5 + h * 0.3;
      }
      return out;
    }

    test('a recognizer line spanning two columns is split again, and columns read in order', () {
      // The recognizer joined each left-column line with the right-column line beside it.
      final lines = <List<OcrWord>>[
        for (var i = 0; i < 4; i++) [...line(left[i].substring(0, 40), 40, 100.0 + i * 14, 10), ...line(right[i].substring(0, 40), 300, 100.0 + i * 14, 10)]
      ];
      final segs = segmentsFromOcr(lines);
      expect(segs.length, 8);
      final lay = layoutPage(segs, 600, 800);
      expect(lay.blocks.length, 2);
      expect(lay.lines.first.text, left[0].substring(0, 40).trim());
      expect(lay.lines[4].text, right[0].substring(0, 40).trim());
    });

    test('body lines get one height, headings keep theirs', () {
      final segs = segmentsFromOcr([
        line('Zinnia', 40, 40, 24),
        line('Old fashioned zinnias give', 40, 80, 10),
        line('cut flowers', 40, 94, 8), // no ascenders: smaller boxes
        line('summer through frost.', 40, 108, 11),
      ]);
      final hs = segs.map((s) => s.box.h).toList();
      expect(hs.first, 24);
      expect(hs.skip(1).toSet(), hasLength(1)); // body lines share one height
      final p = pdfPagesToParagraphs([layoutToText(layoutPage(segs, 600, 800))]);
      expect(p, ['Zinnia', 'Old fashioned zinnias give cut flowers summer through frost.']);
    });
  });

  test('capital magazine name next to a page number is a folio', () {
    final lay = _lay([(left[0], 40, 100, 10), ('NETWORK MONTHLY 2', 40, 770, 8)]);
    expect(layoutToText(lay), isNot(contains('MONTHLY')));
  });
}
