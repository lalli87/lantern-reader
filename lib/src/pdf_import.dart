import 'dart:io';

import 'package:pdfrx/pdfrx.dart';

import 'importers.dart';

final _sentenceEnd = RegExp(r'''[.!?…:;"”’)\]]$''');
final _headingLine = RegExp(r'^(chapter|ch\.|prologue|epilogue|part|book|volume|interlude|afterword|第)(\s+[\w一二三四五六七八九十百]+)?\s*([:.\-–—]\s*.{0,60})?$', caseSensitive: false);

/// Rebuilds paragraphs from PDF page text, which arrives as one line per printed line.
/// Lines are joined until one ends a sentence and is noticeably shorter than a full line.
List<String> pdfPagesToParagraphs(List<String> pages) {
  final lines = <String>[];
  for (final page in pages) {
    for (var l in page.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n')) {
      l = l.replaceAll(RegExp(r'[\s ]+'), ' ').trim();
      if (RegExp(r'^(page\s*)?\d{1,4}(\s*(of|/)\s*\d+)?$', caseSensitive: false).hasMatch(l)) l = ''; // page numbers
      lines.add(l);
    }
    lines.add(''); // page break: may or may not end a paragraph, handled below
  }
  final lens = lines.where((l) => l.length > 20).map((l) => l.length).toList()..sort();
  final full = lens.isEmpty ? 80 : lens[(lens.length * 0.8).floor().clamp(0, lens.length - 1)];

  final out = <String>[];
  final buf = StringBuffer();
  void flush() {
    final t = buf.toString().trim();
    buf.clear();
    if (t.isNotEmpty) out.add(t);
  }

  for (var i = 0; i < lines.length; i++) {
    final l = lines[i];
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
      continue;
    }
    final cur = buf.toString();
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
Future<ImportedBook> parsePdf(String path, String fileName, {void Function(int done, int total)? onProgress}) async {
  await pdfrxFlutterInitialize();
  final PdfDocument doc;
  try {
    doc = await PdfDocument.openFile(path);
  } catch (_) {
    throw const FormatException('This PDF could not be opened. It may be damaged or password-protected.');
  }
  try {
    final pageTexts = <String>[];
    final total = doc.pages.length;
    for (final page in doc.pages) {
      String t = '';
      try {
        t = (await page.loadText())?.fullText ?? '';
      } catch (_) {} // one unreadable page should not sink the whole book
      pageTexts.add(t);
      onProgress?.call(pageTexts.length, total);
    }
    final chars = pageTexts.fold<int>(0, (n, t) => n + t.trim().length);
    if (chars < 40 * doc.pages.length.clamp(1, 5)) {
      throw const FormatException('This PDF has no text layer (it looks like scanned pages), so it cannot be read aloud yet.');
    }
    final base = fileName.replaceFirst(RegExp(r'\.pdf$', caseSensitive: false), '');

    // Top-level bookmarks with page numbers become chapters.
    final marks = <(String, int)>[];
    try {
      for (final n in await doc.loadOutline()) {
        final p = n.dest?.pageNumber;
        if (p != null && n.title.trim().isNotEmpty) marks.add((n.title.trim(), p));
      }
    } catch (_) {}
    marks.sort((a, b) => a.$2.compareTo(b.$2));

    if (marks.length >= 2) {
      final chapters = <ImportedChapter>[];
      if (marks.first.$2 > 1) {
        final front = pdfPagesToParagraphs(pageTexts.sublist(0, marks.first.$2 - 1));
        if (front.isNotEmpty) chapters.add(ImportedChapter(base, front));
      }
      for (var i = 0; i < marks.length; i++) {
        final start = (marks[i].$2 - 1).clamp(0, pageTexts.length);
        final end = i + 1 < marks.length ? (marks[i + 1].$2 - 1).clamp(start, pageTexts.length) : pageTexts.length;
        final paras = pdfPagesToParagraphs(pageTexts.sublist(start, end == start ? (start + 1).clamp(0, pageTexts.length) : end));
        if (paras.isNotEmpty) chapters.add(ImportedChapter(marks[i].$1, paras));
      }
      if (chapters.isNotEmpty) return ImportedBook(title: base, format: 'PDF', chapters: chapters);
    }

    final paras = pdfPagesToParagraphs(pageTexts);
    final detected = singleToBook(base, 'PDF', paras, detectChapters: true);
    if (detected.chapters.length > 1) return detected;
    // No structure found: ten pages per section so the contents list stays usable.
    final chapters = <ImportedChapter>[];
    for (var p = 0; p < pageTexts.length; p += 10) {
      final end = (p + 10).clamp(0, pageTexts.length);
      final part = pdfPagesToParagraphs(pageTexts.sublist(p, end));
      if (part.isNotEmpty) chapters.add(ImportedChapter(pageTexts.length <= 10 ? base : 'Pages ${p + 1}–$end', part));
    }
    return ImportedBook(title: base, format: 'PDF', chapters: chapters);
  } finally {
    await doc.dispose();
  }
}

/// Any supported file at [path], including PDF.
Future<ImportedBook> parseBookFile(String path, String fileName, {void Function(int done, int total)? onProgress}) async {
  if (fileName.toLowerCase().endsWith('.pdf')) return parsePdf(path, fileName, onProgress: onProgress);
  return parseBookBytes(await File(path).readAsBytes(), fileName);
}

