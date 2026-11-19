import 'dart:math' as math;

import 'pdf_layout.dart';

/// "Column mode" on original PDF pages: double-tap a column to zoom to its width, then tap the
/// right or left side to move down and up through it, on to the next column, and the next page.
/// This file only does the arithmetic; reader.dart drives the PDF viewer.

/// Blocks worth stopping at: real text areas, not page numbers or stray marks.
List<LRect> readingBlocks(PageLayout p) => [
  for (final b in p.blocks)
    if (b.w >= p.width * 0.12 && b.w * math.max(b.h, 12) >= p.width * p.height * 0.004) b,
];

/// Where column mode is looking: [block] of [readingBlocks] on [page] (1-based), with the top
/// of the view at [top] (page points, measured from the top of the page).
class ColumnSpot {
  const ColumnSpot(this.page, this.block, this.top);
  final int page;
  final int block;
  final double top;
}

/// Margin kept around a column when zooming to it, in page points.
const columnPad = 8.0;

/// Height of the page area that fits on screen when [b] fills the width of a view with
/// [viewAspect] = height / width.
double columnViewHeight(LRect b, double viewAspect) => (b.w + columnPad * 2) * viewAspect;

/// The area to show for [spot]: the column's width, [columnViewHeight] tall, as
/// (left, top, right, bottom) in top-down page points.
(double, double, double, double) columnArea(LRect b, double top, double viewAspect, double pageH) {
  final h = columnViewHeight(b, viewAspect);
  final t = h >= pageH ? 0.0 : top.clamp(0.0, pageH - h);
  return (b.l - columnPad, t, b.r + columnPad, math.min(pageH, t + h));
}

/// Starting spot after a double-tap at page point (x, y): the column under the finger, with the
/// tap a third of the way down the screen (or the column's top, when that is close).
ColumnSpot? spotAt(List<LRect> blocks, int page, double x, double y, double viewAspect) {
  var best = -1;
  var bestD = double.infinity;
  for (var i = 0; i < blocks.length; i++) {
    final b = blocks[i];
    final dx = x < b.l ? b.l - x : (x > b.r ? x - b.r : 0.0);
    final dy = y < b.t ? b.t - y : (y > b.b ? y - b.b : 0.0);
    final d = dx * dx + dy * dy * 4;
    if (d < bestD) {
      bestD = d;
      best = i;
    }
  }
  if (best < 0 || bestD > 80 * 80) return null;
  final b = blocks[best];
  final h = columnViewHeight(b, viewAspect);
  var top = y - h / 3;
  if (top < b.t + h * 0.25) top = b.t - columnPad;
  return ColumnSpot(page, best, top);
}

/// The next spot when moving forward ([dir] > 0) or back. Null means "past this page's
/// last (or first) column": the caller turns the page.
ColumnSpot? stepColumn(List<LRect> blocks, ColumnSpot s, int dir, double viewAspect) {
  if (s.block < 0 || s.block >= blocks.length) return null;
  final b = blocks[s.block];
  final h = columnViewHeight(b, viewAspect);
  if (dir > 0) {
    if (s.top + h < b.b + columnPad - 2) {
      // Overlap a little so the last line on screen is the first line after the move.
      return ColumnSpot(s.page, s.block, math.min(s.top + h * 0.88, b.b + columnPad - h));
    }
    if (s.block + 1 < blocks.length) return ColumnSpot(s.page, s.block + 1, blocks[s.block + 1].t - columnPad);
    return null;
  }
  if (s.top > b.t - columnPad + 2) {
    return ColumnSpot(s.page, s.block, math.max(b.t - columnPad, s.top - h * 0.88));
  }
  if (s.block > 0) {
    final p = blocks[s.block - 1];
    final ph = columnViewHeight(p, viewAspect);
    return ColumnSpot(s.page, s.block - 1, math.max(p.t - columnPad, p.b + columnPad - ph));
  }
  return null;
}

/// First spot on a page entered going forward, or last spot entered going back.
ColumnSpot? enterPage(List<LRect> blocks, int page, int dir, double viewAspect) {
  if (blocks.isEmpty) return null;
  if (dir > 0) return ColumnSpot(page, 0, blocks.first.t - columnPad);
  final b = blocks.last;
  return ColumnSpot(page, blocks.length - 1, math.max(b.t - columnPad, b.b + columnPad - columnViewHeight(b, viewAspect)));
}
