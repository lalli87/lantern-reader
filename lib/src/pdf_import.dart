import 'dart:io';

import 'package:pdfrx/pdfrx.dart';

import 'importers.dart';
import 'pdf_book.dart';
import 'pdf_layout.dart';

export 'pdf_book.dart';

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
Future<ImportedBook> parseBookFile(String path, String fileName, {void Function(int done, int total)? onProgress}) async {
  if (fileName.toLowerCase().endsWith('.pdf')) return parsePdf(path, fileName, onProgress: onProgress);
  return parseBookBytes(await File(path).readAsBytes(), fileName);
}

