import 'package:flutter/widgets.dart';

import 'text_utils.dart';

/// A run of one paragraph's text that sits on one page.
class PageSeg {
  final int para, start, end;
  final bool endsPara;
  const PageSeg(this.para, this.start, this.end, this.endsPara);
}

/// Lays chapter text out into pages of [width] x [height].
///
/// Each paragraph is measured once; lines are then dealt onto pages, splitting a paragraph
/// across a page break when it does not fit.
List<List<PageSeg>> paginate(
  List<String> paras, {
  required TextStyle Function(int headingLevel) styleFor,
  required double width,
  required double height,
  required double paraGap,
  TextAlign align = TextAlign.start,
  TextScaler scaler = TextScaler.noScaling,
}) {
  final pages = <List<PageSeg>>[];
  var cur = <PageSeg>[];
  var y = 0.0;
  if (width <= 0 || height <= 0) return [[]];

  for (var i = 0; i < paras.length; i++) {
    final text = paraText(paras[i]);
    if (text.isEmpty) continue;
    final tp = TextPainter(
      text: TextSpan(text: text, style: styleFor(headingLevel(paras[i]))),
      textDirection: TextDirection.ltr,
      textAlign: align,
      textScaler: scaler,
    )..layout(maxWidth: width);
    final lines = tp.computeLineMetrics();

    // Character offset where each line starts.
    final starts = <int>[0];
    var top = lines.isEmpty ? 0.0 : lines.first.height;
    for (var l = 1; l < lines.length; l++) {
      final o = tp.getPositionForOffset(Offset(0, top + lines[l].height / 2)).offset;
      starts.add(o > starts.last ? o : starts.last + 1);
      top += lines[l].height;
    }

    var segStart = 0;
    for (var l = 0; l < lines.length; l++) {
      final h = lines[l].height;
      if (y + h > height + 0.5 && y > 0) {
        if (starts[l] > segStart) cur.add(PageSeg(i, segStart, starts[l].clamp(0, text.length), false));
        pages.add(cur);
        cur = [];
        y = 0;
        segStart = starts[l].clamp(0, text.length);
      }
      y += h;
    }
    if (segStart < text.length) cur.add(PageSeg(i, segStart, text.length, true));
    y += paraGap;
    tp.dispose();
  }
  if (cur.isNotEmpty || pages.isEmpty) pages.add(cur);
  return pages;
}

/// Index of the page that shows [para] (its first segment), or the nearest page after it.
int pageOfPara(List<List<PageSeg>> pages, int para) {
  for (var i = 0; i < pages.length; i++) {
    if (pages[i].any((s) => s.para >= para)) return i;
  }
  return pages.isEmpty ? 0 : pages.length - 1;
}
