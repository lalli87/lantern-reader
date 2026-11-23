import 'dart:io';
import 'dart:math' as math;

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';

import 'importers.dart';
import 'pdf_book.dart';
import 'pdf_layout.dart';
import 'pdf_ocr.dart';

export 'pdf_book.dart';

/// [askOcr] is asked when the PDF is made of pictures of pages (no text inside); answering yes runs text
/// recognition on those pages, reporting through [onOcrProgress].
Future<ImportedBook> parsePdf(String path, String fileName,
    {void Function(int done, int total)? onProgress, Future<bool> Function(int pages)? askOcr, void Function(int done, int total)? onOcrProgress}) async {
  await pdfrxFlutterInitialize();
  final PdfDocument doc;
  try {
    doc = await PdfDocument.openFile(path);
  } catch (_) {
    throw const FormatException('This PDF could not be opened. It may be damaged or password-protected.');
  }
  try {
    final pageTexts = <String>[];
    final layouts = <PageLayout?>[];
    final total = doc.pages.length;
    for (final page in doc.pages) {
      String t = '';
      PageLayout? lay;
      try {
        final pt = await page.loadText();
        t = pt?.fullText ?? '';
        if (pt != null) lay = pageLayoutOf(pt, page.width, page.height);
      } catch (_) {} // one unreadable page should not sink the whole book
      pageTexts.add(t);
      layouts.add(lay);
      onProgress?.call(pageTexts.length, total);
    }
    // Scanned pages (pictures only): offer text recognition.
    final letters = [for (final t in pageTexts) RegExp(r'[\p{L}\p{N}]', unicode: true).allMatches(t).length];
    final allLetters = letters.fold<int>(0, (a, b) => a + b);
    final empty = [for (var i = 0; i < letters.length; i++) if (letters[i] < 25) i];
    final scanned = allLetters < 40 * math.min(pageTexts.length, 5) || empty.length >= pageTexts.length * 0.6;
    if (scanned && empty.isNotEmpty && askOcr != null && await askOcr(empty.length)) {
      final ocr = PdfOcr(Directory.systemTemp.path);
      try {
        for (var k = 0; k < empty.length; k++) {
          final i = empty[k];
          try {
            final lay = await ocr.page(doc.pages[i]);
            if (lay != null) {
              layouts[i] = lay;
              pageTexts[i] = lay.lines.map((l) => l.text).join('\n');
            }
          } catch (_) {} // one page that can't be recognized should not stop the rest
          onOcrProgress?.call(k + 1, empty.length);
        }
      } finally {
        await ocr.close();
      }
    }
    applyLayouts(pageTexts, layouts);
    // Top-level bookmarks with page numbers become chapters.
    final marks = <(String, int)>[];
    try {
      for (final n in await doc.loadOutline()) {
        final p = n.dest?.pageNumber;
        if (p != null && n.title.trim().isNotEmpty) marks.add((n.title.trim(), p));
      }
    } catch (_) {}
    return bookFromPdfPages(pageTexts, marks, fileName);
  } finally {
    await doc.dispose();
  }
}

/// Reading-order layout of one page from pdfium's text and character boxes, or null when
/// the boxes do not line up with the text (then the plain text order is used).
PageLayout? pageLayoutOf(PdfPageRawText pt, double width, double height) {
  if (pt.charRects.length != pt.fullText.length || pt.fullText.trim().isEmpty) return null;
  final rects = [for (final r in pt.charRects) (r.left, r.top, r.right, r.bottom)];
  return layoutPage(segmentsFromChars(pt.fullText, rects, height), width, height);
}

/// Any supported file at [path], including PDF.
Future<ImportedBook> parseBookFile(String path, String fileName,
    {void Function(int done, int total)? onProgress, Future<bool> Function(int pages)? askOcr, void Function(int done, int total)? onOcrProgress}) async {
  if (fileName.toLowerCase().endsWith('.pdf')) {
    return parsePdf(path, fileName, onProgress: onProgress, askOcr: askOcr, onOcrProgress: onOcrProgress);
  }
  final bytes = await File(path).readAsBytes();
  if (fileName.toLowerCase().endsWith('.zip')) {
    // A PDF inside a ZIP needs a file of its own for the PDF engine.
    final entry = bookInZip(ZipDecoder().decodeBytes(bytes));
    if (entry != null && entry.name.toLowerCase().endsWith('.pdf')) {
      final tmp = File('${Directory.systemTemp.path}/zip_${DateTime.now().microsecondsSinceEpoch}.pdf');
      await tmp.writeAsBytes(entry.readBytes()!);
      try {
        return await parsePdf(tmp.path, p.basename(entry.name), onProgress: onProgress, askOcr: askOcr, onOcrProgress: onOcrProgress);
      } finally {
        await tmp.delete();
      }
    }
  }
  return parseBookBytes(bytes, fileName);
}

