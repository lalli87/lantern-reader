import 'dart:math' as math;

/// Reading-order layout for PDF pages: magazines and newsletters print text in columns,
/// boxes and side panels, and the PDF's own text order often jumps between them.
/// This works from character positions only (pure Dart, no pdfium), so it is easy to test.
///
/// Coordinates here are top-down: y grows towards the bottom of the page.

/// A rectangle on the page in top-down coordinates.
class LRect {
  const LRect(this.l, this.t, this.r, this.b);
  final double l, t, r, b;
  double get w => r - l;
  double get h => b - t;
  LRect union(LRect o) => LRect(math.min(l, o.l), math.min(t, o.t), math.max(r, o.r), math.max(b, o.b));
  bool contains(double x, double y, [double pad = 0]) => x >= l - pad && x <= r + pad && y >= t - pad && y <= b + pad;
  @override
  String toString() => 'LRect(${l.toStringAsFixed(1)}, ${t.toStringAsFixed(1)}, ${r.toStringAsFixed(1)}, ${b.toStringAsFixed(1)})';
}

/// One run of text on one printed line (a line can hold several runs when columns sit side by side).
class LSeg {
  LSeg(this.text, this.box, this.size);
  String text;
  LRect box;

  /// Typical character height: a stand-in for the font size.
  final double size;
}

/// A line of text in reading order, ready to be turned into paragraphs.
class LLine {
  LLine(this.text, this.box, this.size, this.block, this.blockBox, this.pitch);
  final String text;
  final LRect box;
  final double size;

  /// Index of the text block (column piece) this line belongs to, and that block's bounds.
  final int block;
  final LRect blockBox;

  /// Usual distance from one line to the next in this block (0 when unknown).
  final double pitch;
}

class PageLayout {
  PageLayout(this.lines, this.blocks, this.width, this.height);
  final List<LLine> lines;

  /// Text blocks in reading order (used to zoom to a column).
  final List<LRect> blocks;
  final double width, height;

  /// The block under (x, y), or the nearest block on that horizontal band.
  LRect? blockAt(double x, double y) {
    for (final b in blocks) {
      if (b.contains(x, y, 4)) return b;
    }
    LRect? best;
    var bestD = double.infinity;
    for (final b in blocks) {
      final dx = x < b.l ? b.l - x : (x > b.r ? x - b.r : 0.0);
      final dy = y < b.t ? b.t - y : (y > b.b ? y - b.b : 0.0);
      final d = dx * dx + dy * dy * 4;
      if (d < bestD) {
        bestD = d;
        best = b;
      }
    }
    return bestD < 60 * 60 ? best : null;
  }
}

/// Marks a forced paragraph break in page text handed to `pdfPagesToParagraphs`.
const hardBreak = ' ';

final _sentenceEnd = RegExp(r'''[.!?…:;"”’)\]}]$''');
final _folio = RegExp(r'^(\d{1,4}\s*[|•·]\s*.{1,40}|.{1,40}\s*[|•·]\s*\d{1,4}|(page\s*)?\d{1,4}(\s*(of|/)\s*\d+)?)$', caseSensitive: false);
// "SOUTHERN LIVING 7" / "8 SOUTHERN LIVING": magazine name in capitals next to the page number (OCR drops the bar).
final _capsFolio = RegExp(r"^(\d{1,4}\s+[A-Z][A-Z .&'’-]{2,40}|[A-Z][A-Z .&'’-]{2,40}\s+\d{1,4})$");

double _median(List<double> xs) {
  if (xs.isEmpty) return 0;
  final s = [...xs]..sort();
  return s[s.length ~/ 2];
}

final _capOrAscender = RegExp(r'[A-Zbdfhkl0-9]');
final _descender = RegExp(r'[gjpqy]');
final _lower = RegExp(r'[a-z]');

/// A stand-in for the font size of a run: the height of its capitals and ascenders (all about
/// the same), else of its descending letters, else its x-height scaled up.
double _sizeOf(List<String> chars, List<double> hs) {
  List<double> pick(RegExp re) => [
    for (var i = 0; i < chars.length; i++)
      if (re.hasMatch(chars[i])) hs[i],
  ];
  final tall = pick(_capOrAscender);
  if (tall.isNotEmpty) return _median(tall);
  final desc = pick(_descender);
  if (desc.isNotEmpty) return _median(desc);
  final low = pick(_lower);
  if (low.isNotEmpty) return _median(low) / 0.68;
  return _median(hs);
}

/// Splits page text into line runs. [rects] holds one rectangle per character of [text]
/// in PDF coordinates (origin bottom-left: left, top, right, bottom with top > bottom).
List<LSeg> segmentsFromChars(String text, List<(double, double, double, double)> rects, double pageHeight) {
  final segs = <LSeg>[];
  final buf = StringBuffer();
  LRect? box;
  final heights = <double>[];
  final chars = <String>[];
  double lastR = 0;

  void end() {
    final t = buf.toString().replaceAll(RegExp(r'[\s ]+'), ' ').trim();
    if (t.isNotEmpty && box != null) segs.add(LSeg(t, box!, _sizeOf(chars, heights)));
    buf.clear();
    box = null;
    heights.clear();
    chars.clear();
  }

  final n = math.min(text.length, rects.length);
  for (var i = 0; i < n; i++) {
    final ch = text[i];
    if (ch == '\n' || ch == '\r') {
      end();
      continue;
    }
    final (l, top, r, bottom) = rects[i];
    final blank = ch.trim().isEmpty || r <= l || top <= bottom;
    if (blank) {
      if (box != null) buf.write(' ');
      continue;
    }
    final c = LRect(l, pageHeight - top, r, pageHeight - bottom);
    final b = box;
    if (b != null) {
      final h = math.max(c.h, _median(heights));
      final cy = (c.t + c.b) / 2;
      final sameLine = cy > b.t - h * 0.2 && cy < b.b + h * 0.2;
      final gap = c.l - lastR;
      // A big jump sideways (column gutter) or to another line starts a new run.
      if (!sameLine || gap > h * 1.6 || gap < -h * 2) {
        end();
      }
    }
    if (box == null) {
      box = c;
    } else {
      box = box!.union(c);
    }
    buf.write(ch);
    heights.add(c.h);
    chars.add(ch);
    lastR = c.r;
  }
  end();
  return _dropVerticalText(segs);
}

/// Text printed sideways (photo credits up the page edge) arrives one letter per line: single
/// letters stacked tightly on top of each other, closer than any two printed lines could be.
List<LSeg> _dropVerticalText(List<LSeg> segs) {
  final singles = [
    for (final s in segs)
      if (s.text.length == 1) s,
  ]..sort((a, b) => a.box.t.compareTo(b.box.t));
  if (singles.length < 4) return segs;
  final drop = <LSeg>{};
  final used = <LSeg>{};
  for (final start in singles) {
    if (used.contains(start)) continue;
    final chain = [start];
    var cur = start;
    for (final o in singles) {
      if (o.box.t <= cur.box.t || used.contains(o)) continue;
      final cx = (cur.box.l + cur.box.r) / 2, ox = (o.box.l + o.box.r) / 2;
      final size = math.max(math.max(cur.box.w, cur.box.h), 2.0);
      if ((ox - cx).abs() < size * 0.6 && o.box.t - cur.box.b < size * 0.6) {
        chain.add(o);
        cur = o;
      }
    }
    if (chain.length >= 4) {
      drop.addAll(chain);
      used.addAll(chain);
    }
  }
  if (drop.isEmpty) return segs;
  return [
    for (final s in segs)
      if (!drop.contains(s)) s,
  ];
}

/// Gaps in the projection of [boxes] onto one axis, as (start, end) pairs.
List<(double, double)> _gaps(List<LRect> boxes, bool vertical) {
  final iv = [for (final b in boxes) vertical ? (b.l, b.r) : (b.t, b.b)]..sort((a, b) => a.$1.compareTo(b.$1));
  final out = <(double, double)>[];
  var end = iv.first.$2;
  for (final (s, e) in iv.skip(1)) {
    if (s > end) out.add((end, s));
    end = math.max(end, e);
  }
  return out;
}

/// Lays out one page. [segs] come from [segmentsFromChars].
PageLayout layoutPage(List<LSeg> segs, double width, double height) {
  if (segs.isEmpty) return PageLayout(const [], const [], width, height);
  final mh = math.max(_median([for (final s in segs) s.size]), 1.0);
  final leaves = <List<LSeg>>[];

  void cut(List<LSeg> region, int depth) {
    if (region.length <= 1 || depth > 60) {
      leaves.add(region);
      return;
    }
    final boxes = [for (final s in region) s.box];
    final vGaps = _gaps(boxes, true).where((g) => g.$2 - g.$1 >= mh * 0.8).toList();
    final hGaps = _gaps(boxes, false);
    (double, double)? widest(List<(double, double)> gs) => gs.isEmpty ? null : gs.reduce((a, b) => (b.$2 - b.$1) > (a.$2 - a.$1) ? b : a);
    final v = widest(vGaps);
    final section = widest(hGaps.where((g) => g.$2 - g.$1 >= mh * 1.6).toList());

    bool splitAt((double, double) g, bool vertical) {
      final mid = (g.$1 + g.$2) / 2;
      final a = <LSeg>[], b = <LSeg>[];
      for (final s in region) {
        ((vertical ? s.box.r : s.box.b) <= mid ? a : b).add(s);
      }
      if (a.isEmpty || b.isEmpty) return false;
      // Columns hold several lines and the right one starts at a straight left edge; gaps
      // that only line up by chance are wide word spacing in justified text.
      if (vertical && (_lineCount(a) < 3 || _lineCount(b) < 3 || !_alignedLeft(b, mh))) return false;
      cut(a, depth + 1);
      cut(b, depth + 1);
      return true;
    }

    // Side-by-side columns win unless a clearly larger empty band separates two sections.
    if (v != null && (section == null || section.$2 - section.$1 < mh * 2.5)) {
      if (splitAt(v, true)) return;
    }
    if (section != null && splitAt(section, false)) return;
    if (v != null && splitAt(v, true)) return;
    // Something (a title, a pull quote) spans the columns: split above or below it and look again.
    final small = widest(hGaps.where((g) => g.$2 - g.$1 >= mh * 0.25).toList());
    if (small != null && _hasColumnsSomewhere(region, mh) && splitAt(small, false)) return;
    leaves.add(region);
  }

  cut(segs, 0);
  _mergeStacked(leaves, mh);

  final lines = <LLine>[];
  final blocks = <LRect>[];
  for (final leaf in leaves) {
    leaf.sort((a, b) {
      if (_sameLine(a.box, b.box)) return a.box.l.compareTo(b.box.l);
      return (a.box.t + a.box.b).compareTo(b.box.t + b.box.b);
    });
    // Join runs that share a printed line.
    final merged = <LSeg>[];
    for (final s in leaf) {
      final last = merged.isEmpty ? null : merged.last;
      if (last != null) {
        if (_sameLine(last.box, s.box) && s.box.l >= last.box.r - 1) {
          final sep = s.box.l - last.box.r > math.max(last.size, s.size) * 0.3 ? ' ' : '';
          merged[merged.length - 1] = LSeg('${last.text}$sep${s.text}', last.box.union(s.box), math.max(last.size, s.size));
          continue;
        }
      }
      merged.add(LSeg(s.text, s.box, s.size));
    }
    final bb = merged.map((s) => s.box).reduce((a, b) => a.union(b));
    final bi = blocks.length;
    blocks.add(bb);
    // Line tops are steadier than glyph gaps: a line with no descenders looks farther from the next.
    final steps = <double>[
      for (var i = 1; i < merged.length; i++)
        if (merged[i].box.t > merged[i - 1].box.t) merged[i].box.t - merged[i - 1].box.t,
    ];
    final pitch = steps.length >= 2 ? _median(steps) : 0.0;
    for (final s in merged) {
      lines.add(LLine(s.text, s.box, s.size, bi, bb, pitch));
    }
  }
  return PageLayout(lines, blocks, width, height);
}

/// Splitting around spanning elements can chop one column into slices; glue back slices that
/// sit directly on top of each other with the same width and type size.
void _mergeStacked(List<List<LSeg>> leaves, double mh) {
  LRect boxOf(List<LSeg> l) => l.map((s) => s.box).reduce((a, b) => a.union(b));
  double sizeOf(List<LSeg> l) => _median([for (final s in l) s.size]);
  var i = 0;
  while (i + 1 < leaves.length) {
    final a = boxOf(leaves[i]), b = boxOf(leaves[i + 1]);
    final sa = sizeOf(leaves[i]), sb = sizeOf(leaves[i + 1]);
    final u = a.union(b);
    final overlap = math.min(a.r, b.r) - math.max(a.l, b.l);
    final stacked = b.t >= a.b - mh * 0.3 && b.t - a.b < mh * 1.5;
    final aligned =
        overlap >= math.min(a.w, b.w) * 0.7 && u.w <= math.max(a.w, b.w) * 1.15 && ((a.l - b.l).abs() < mh * 2.5 || (a.r - b.r).abs() < mh);
    final sameType = (sa - sb).abs() <= math.max(sa, sb) * 0.25;
    if (stacked && aligned && sameType) {
      leaves[i] = [...leaves[i], ...leaves[i + 1]];
      leaves.removeAt(i + 1);
    } else {
      i++;
    }
  }
}

/// Whether most printed lines in [segs] start at the same left edge (first-line indents allowed).
bool _alignedLeft(List<LSeg> segs, double mh) {
  final sorted = [...segs]..sort((a, b) => a.box.t.compareTo(b.box.t));
  final starts = <double>[];
  LRect? line;
  for (final s in sorted) {
    if (line != null && _sameLine(line, s.box)) {
      starts[starts.length - 1] = math.min(starts.last, s.box.l);
    } else {
      starts.add(s.box.l);
      line = s.box;
    }
  }
  final edge = starts.reduce(math.min);
  final onEdge = starts.where((x) => x - edge < mh * 0.5).length;
  final indented = starts.where((x) => x - edge >= mh * 0.5 && x - edge < mh * 3.5).length;
  return onEdge >= 2 && onEdge + indented >= starts.length * 0.85 && onEdge >= starts.length * 0.5;
}

/// Number of distinct printed lines in [segs].
int _lineCount(List<LSeg> segs) {
  final tops = [for (final s in segs) s.box]..sort((a, b) => a.t.compareTo(b.t));
  var n = 0;
  LRect? last;
  for (final b in tops) {
    if (last == null || !_sameLine(last, b)) {
      n++;
      last = b;
      if (n >= 3) return n;
    }
  }
  return n;
}

/// True when four or more printed lines in [region] have a wide gap at the same place, i.e.
/// some part of it is set in columns (scattered wide gaps are justified word spacing).
bool _hasColumnsSomewhere(List<LSeg> region, double mh) {
  final gaps = <(double, double, LRect)>[];
  for (final s in region) {
    for (final o in region) {
      if (identical(s, o) || !_sameLine(s.box, o.box)) continue;
      final g = o.box.l - s.box.r;
      if (g >= mh * 0.8) gaps.add((s.box.r, o.box.l, s.box));
    }
  }
  for (final a in gaps) {
    var n = 0;
    for (final b in gaps) {
      if (identical(a, b) || _sameLine(a.$3, b.$3)) continue;
      // A column's text starts at one straight edge; word gaps that overlap by chance don't.
      if (math.min(a.$2, b.$2) - math.max(a.$1, b.$1) > mh * 0.4 && (a.$2 - b.$2).abs() < mh * 0.5) n++;
    }
    if (n >= 3) return true;
  }
  return false;
}

/// Whether two boxes sit on the same printed line. Small marks (quotes, superscripts) count
/// when they touch the band of the taller box.
bool _sameLine(LRect a, LRect b) {
  final big = a.h >= b.h ? a : b, small = identical(big, a) ? b : a;
  final overlap = math.min(a.b, b.b) - math.max(a.t, b.t);
  if (overlap > small.h * 0.5) return true;
  return small.h < big.h * 0.6 && small.b >= big.t - big.h * 0.15 && small.t <= big.b;
}

/// Lines in the top or bottom margin that look like running headers, footers or page numbers.
String normalizedMarginLine(LLine l, PageLayout p) {
  final inMargin = l.box.b < p.height * 0.075 || l.box.t > p.height * 0.925;
  if (!inMargin || l.text.length > 60) return '';
  return l.text.toLowerCase().replaceAll(RegExp(r'\d+'), '#').replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Turns a laid-out page into text: one printed line per text line, with [hardBreak] lines
/// where a new paragraph or heading clearly starts. [skip] holds normalized margin lines
/// (see [normalizedMarginLine]) that repeat on many pages and should be dropped.
String layoutToText(PageLayout p, {Set<String> skip = const {}}) {
  final kept = <LLine>[];
  for (final l in p.lines) {
    final m = normalizedMarginLine(l, p);
    if (m.isNotEmpty && (skip.contains(m) || _folio.hasMatch(l.text) || _capsFolio.hasMatch(l.text))) continue;
    kept.add(l);
  }
  final out = StringBuffer();
  for (var i = 0; i < kept.length; i++) {
    final l = kept[i];
    if (i > 0) {
      final a = kept[i - 1];
      if (_breakBetween(a, l)) out.writeln(hardBreak);
    }
    out.writeln(l.text);
  }
  return out.toString();
}

bool _breakBetween(LLine a, LLine b) {
  final big = math.max(a.size, b.size);
  // Heading ↔ body. Sizes of very short lines are rough guesses, so they need a bigger jump.
  final diff = big > 0 ? (a.size - b.size).abs() / big : 0.0;
  if (diff > 0.4 || (diff > 0.25 && a.text.length >= 10 && b.text.length >= 10)) return true;
  final ends = _sentenceEnd.hasMatch(a.text);
  // Text that flows on into the next column (which starts higher up) keeps going.
  if (a.block != b.block && b.box.t < a.box.t) return ends;
  final bb = a.blockBox;
  final h = math.max(a.size, 1.0);
  final step = b.box.t - a.box.t;
  final pitch = a.pitch > 0 ? a.pitch : b.pitch;
  if (pitch > 0 ? step > pitch * 1.4 : b.box.t - a.box.b > h * 1.2) return true; // blank space between paragraphs
  if (b.box.l > bb.l + h * 1.2 && a.box.l <= bb.l + h * 0.5 && ends) return true; // first-line indent
  final short = a.box.r < bb.r - math.max(h * 3, bb.w * 0.2);
  // A short line ends a paragraph, unless the sentence plainly runs on (ragged-right text).
  final runsOn = !ends && RegExp(r'^[a-z(]').hasMatch(b.text);
  if (short && !runsOn && !a.text.endsWith('-') && !a.text.endsWith(',')) return true;
  if (ends && a.box.r < bb.r - h * 1.5) return true;
  return false;
}

/// One recognized word (OCR) with its box in page points, top-down.
class OcrWord {
  const OcrWord(this.text, this.box);
  final String text;
  final LRect box;
}

/// Line runs from OCR output ([lines] of words, as the recognizer grouped them), ready for [layoutPage].
/// Recognizers sometimes join words from two columns into one line, so lines are split again at wide gaps;
/// and since word boxes vary with ascenders and descenders, every run of body text gets the page's usual
/// line height (only clearly bigger text, like headings, keeps its own size).
List<LSeg> segmentsFromOcr(List<List<OcrWord>> lines) {
  final groups = <List<OcrWord>>[];
  for (final line in lines) {
    final words = [
      for (final w in line)
        if (w.text.trim().isNotEmpty && w.box.w > 0 && w.box.h > 0) w
    ]..sort((a, b) => a.box.l.compareTo(b.box.l));
    if (words.isEmpty) continue;
    final mh = _median([for (final w in words) w.box.h]);
    var cur = [words.first];
    for (final w in words.skip(1)) {
      if (w.box.l - cur.last.box.r > mh * 1.1) {
        groups.add(cur);
        cur = [w];
      } else {
        cur.add(w);
      }
    }
    groups.add(cur);
  }
  if (groups.isEmpty) return const [];
  final heights = [for (final g in groups) _median([for (final w in g) w.box.h])];
  final pageH = _median(heights);
  final segs = <LSeg>[];
  for (var i = 0; i < groups.length; i++) {
    final g = groups[i];
    final top = g.map((w) => w.box.t).reduce(math.min);
    final h = (heights[i] / pageH - 1).abs() < 0.3 ? pageH : heights[i];
    final l = g.first.box.l, r = g.map((w) => w.box.r).reduce(math.max);
    segs.add(LSeg(g.map((w) => w.text.trim()).join(' '), LRect(l, top, r, top + h), h * 0.75));
  }
  return segs;
}
