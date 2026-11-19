import 'dart:math' as math;

import 'imported.dart';
import 'pdf_layout.dart';

/// Turning PDF page text into a book: paragraphs, chapters and page numbers. Pure Dart, shared by the
/// phone app (text from pdfium) and the web version (text from pdf.js, compiled to JavaScript).

final _sentenceEnd = RegExp(r'''[.!?…:;"”’)\]]$''');
final _headingLine = RegExp(
  r'^(chapter|ch\.|prologue|epilogue|part|book|volume|interlude|afterword|第)(\s+[\w一二三四五六七八九十百]+)?\s*([:.\-–—]\s*.{0,60})?$',
  caseSensitive: false,
);

/// Rebuilds paragraphs from PDF page text, which arrives as one line per printed line.
/// Lines are joined until one ends a sentence and is noticeably shorter than a full line.
/// When [pagesOut] is given, it receives the PDF page index (from [firstPage]) each paragraph starts on.
/// Pages that went through the column layout (see pdf_layout.dart) mark paragraph starts with a
/// [hardBreak] line; for those, the line-length guess is not needed and is left out.
List<String> pdfPagesToParagraphs(List<String> pages, {int firstPage = 0, List<int>? pagesOut}) {
  final laidOut = pages.any((p) => p.contains(hardBreak));
  final lines = <String>[];
  final lineOwner = <int>[];
  for (var pi = 0; pi < pages.length; pi++) {
    for (var l in pages[pi].replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n')) {
      if (l.contains(hardBreak) && l.replaceAll(hardBreak, '').trim().isEmpty) {
        lines.add(hardBreak);
        lineOwner.add(firstPage + pi);
        continue;
      }
      l = l.replaceAll(RegExp(r'[\s ]+'), ' ').trim();
      if (RegExp(r'^(page\s*)?\d{1,4}(\s*(of|/)\s*\d+)?$', caseSensitive: false).hasMatch(l)) l = ''; // page numbers
      lines.add(l);
      lineOwner.add(firstPage + pi);
    }
    lines.add(''); // page break: may or may not end a paragraph, handled below
    lineOwner.add(firstPage + pi);
  }
  final lens = lines.where((l) => l.length > 20).map((l) => l.length).toList()..sort();
  final full = lens.isEmpty ? 80 : lens[(lens.length * 0.8).floor().clamp(0, lens.length - 1)];

  final out = <String>[];
  final buf = StringBuffer();
  var bufPage = firstPage;
  void flush() {
    final t = buf.toString().trim();
    buf.clear();
    if (t.isNotEmpty) {
      out.add(t);
      pagesOut?.add(bufPage);
    }
  }

  for (var i = 0; i < lines.length; i++) {
    final l = lines[i];
    if (l == hardBreak) {
      flush();
      continue;
    }
    if (l.isEmpty) {
      // Blank line: a paragraph break unless the text clearly runs on (no sentence end yet).
      final cur = buf.toString().trimRight();
      if (cur.isNotEmpty && _sentenceEnd.hasMatch(cur)) flush();
      continue;
    }
    if (l.length < 70 && _headingLine.hasMatch(l)) {
      // Chapter headings stand alone.
      flush();
      out.add(l);
      pagesOut?.add(lineOwner[i]);
      continue;
    }
    final cur = buf.toString();
    if (cur.trim().isEmpty) bufPage = lineOwner[i];
    if (cur.endsWith('-') && !cur.endsWith(' -') && RegExp(r'^[a-z]').hasMatch(l)) {
      // Hyphenated word split across lines.
      buf
        ..clear()
        ..write(cur.substring(0, cur.length - 1))
        ..write(l);
    } else {
      if (cur.isNotEmpty) buf.write(' ');
      buf.write(l);
    }
    if (laidOut) continue; // the layout already marked where paragraphs end
    final short = l.length < full * 0.72;
    if (short && _sentenceEnd.hasMatch(l)) flush();
  }
  flush();
  return out;
}

/// Imports a text-based PDF. Chapters come from the PDF's bookmarks when it has them, otherwise
/// from "Chapter N" headings, otherwise groups of ten pages.
/// The PDF is opened from [path] so pdfium reads it from disk as needed; large magazines
/// (100 MB+, mostly images) would not fit in memory as one byte array.
/// Replaces each page's text with its column-aware version, dropping running headers and
/// footers that repeat across pages.
void applyLayouts(List<String> pageTexts, List<PageLayout?> layouts) {
  final counts = <String, int>{};
  for (final p in layouts) {
    if (p == null) continue;
    for (final m in {for (final l in p.lines) normalizedMarginLine(l, p)}) {
      if (m.isNotEmpty) counts[m] = (counts[m] ?? 0) + 1;
    }
  }
  final n = layouts.where((p) => p != null).length;
  final repeat = math.max(3, (n * 0.25).ceil());
  final skip = {
    for (final e in counts.entries)
      if (e.value >= repeat) e.key,
  };
  for (var i = 0; i < layouts.length; i++) {
    final p = layouts[i];
    if (p != null && p.lines.isNotEmpty) pageTexts[i] = layoutToText(p, skip: skip);
  }
}

/// Builds the book from each page's text (after [applyLayouts]) and the PDF's bookmarks
/// ([marks]: title and 1-based page). [fileName] gives the title.
ImportedBook bookFromPdfPages(List<String> pageTexts, List<(String, int)> marks, String fileName) {
  marks = [...marks];
  final chars = pageTexts.fold<int>(0, (n, t) => n + t.trim().length);
  if (chars < 40 * pageTexts.length.clamp(1, 5)) {
    throw const FormatException('This PDF has no text layer (it looks like scanned pages), so it cannot be read aloud yet.');
  }
  final base = fileName.replaceFirst(RegExp(r'\.pdf$', caseSensitive: false), '');

  marks.sort((a, b) => a.$2.compareTo(b.$2));

  ImportedChapter section(String title, int start, int end) {
    final pages = <int>[];
    final paras = pdfPagesToParagraphs(pageTexts.sublist(start, end), firstPage: start, pagesOut: pages);
    return ImportedChapter(title, paras, pages);
  }

  if (marks.length >= 2) {
    final chapters = <ImportedChapter>[];
    if (marks.first.$2 > 1) {
      final front = section(base, 0, (marks.first.$2 - 1).clamp(0, pageTexts.length));
      if (front.paras.isNotEmpty) chapters.add(front);
    }
    for (var i = 0; i < marks.length; i++) {
      final start = (marks[i].$2 - 1).clamp(0, pageTexts.length - 1);
      final end = i + 1 < marks.length ? (marks[i + 1].$2 - 1).clamp(start, pageTexts.length) : pageTexts.length;
      final c = section(marks[i].$1, start, end == start ? start + 1 : end);
      if (c.paras.isNotEmpty) chapters.add(c);
    }
    if (chapters.isNotEmpty) return ImportedBook(title: base, format: 'PDF', chapters: chapters);
  }

  final allPages = <int>[];
  final paras = pdfPagesToParagraphs(pageTexts, pagesOut: allPages);
  final detected = singleToBook(base, 'PDF', paras, detectChapters: true);
  if (detected.chapters.length > 1) {
    // Chapter detection keeps paragraphs in order (headings removed), so walk both lists together.
    var k = 0;
    for (final c in detected.chapters) {
      final pg = <int>[];
      for (final para in c.paras) {
        var j = k;
        while (j < paras.length && paras[j] != para) {
          j++;
        }
        if (j < paras.length) k = j + 1;
        pg.add(j < paras.length ? allPages[j] : (pg.isEmpty ? 0 : pg.last));
      }
      c.pages = pg;
    }
    return detected;
  }
  // No structure found: ten pages per section so the contents list stays usable.
  final chapters = <ImportedChapter>[];
  for (var p = 0; p < pageTexts.length; p += 10) {
    final end = (p + 10).clamp(0, pageTexts.length);
    final c = section(pageTexts.length <= 10 ? base : 'Pages ${p + 1}–$end', p, end);
    if (c.paras.isNotEmpty) chapters.add(c);
  }
  return ImportedBook(title: base, format: 'PDF', chapters: chapters);
}
