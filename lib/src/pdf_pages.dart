import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'app.dart';
import 'importers.dart';

/// Original PDF files are kept next to the library so the reader can show the real pages
/// (with pictures and layout), alongside a map of which page each paragraph came from.
String get pdfsDir => p.join(dataDir, 'pdfs');
String originalPdfPath(int bookId) => p.join(pdfsDir, 'book_$bookId.pdf');
String _mapPath(int bookId) => p.join(pdfsDir, 'book_$bookId.json');

bool hasOriginalPdf(int bookId) => File(originalPdfPath(bookId)).existsSync();

/// Which PDF page each paragraph of each chapter starts on (0-based pages).
class PdfPageMap {
  PdfPageMap(this.chapters);
  final List<List<int>> chapters;

  static PdfPageMap empty() => PdfPageMap(const []);
  bool get isEmpty => chapters.isEmpty;

  factory PdfPageMap.fromBook(ImportedBook ib) => PdfPageMap([for (final c in ib.chapters) c.pages ?? const <int>[]]);

  /// The page for [para] of chapter [ch], or null when unknown.
  int? pageOf(int ch, int para) {
    if (ch < 0 || ch >= chapters.length) return null;
    final c = chapters[ch];
    if (c.isEmpty) return null;
    return c[para.clamp(0, c.length - 1)];
  }

  /// The first paragraph starting on [page]; failing that, the last one starting before it
  /// (a page that only continues earlier text); failing that, the very first paragraph.
  (int, int)? locate(int page) {
    (int, int)? before;
    for (var ch = 0; ch < chapters.length; ch++) {
      final c = chapters[ch];
      for (var i = 0; i < c.length; i++) {
        if (c[i] == page) return (ch, i);
        if (c[i] < page) before = (ch, i);
      }
    }
    if (before != null) return before;
    for (var ch = 0; ch < chapters.length; ch++) {
      if (chapters[ch].isNotEmpty) return (ch, 0);
    }
    return null;
  }

  String toJson() => jsonEncode({'v': 1, 'chapters': chapters});

  static PdfPageMap parse(String s) {
    final j = jsonDecode(s) as Map<String, dynamic>;
    return PdfPageMap([
      for (final c in (j['chapters'] as List? ?? const [])) [for (final x in c as List) (x as num).toInt()],
    ]);
  }
}

Future<PdfPageMap> loadPdfPageMap(int bookId) async {
  try {
    return PdfPageMap.parse(await File(_mapPath(bookId)).readAsString());
  } catch (_) {
    return PdfPageMap.empty();
  }
}

/// Stores the original file for [bookId]. A [temporary] source (the picker's cache copy) is moved,
/// anything else is copied.
Future<void> keepOriginalPdf(int bookId, String source, PdfPageMap map, {bool temporary = false}) async {
  await Directory(pdfsDir).create(recursive: true);
  final target = originalPdfPath(bookId);
  if (p.equals(source, target)) {
    // already in place
  } else if (temporary) {
    try {
      await File(source).rename(target);
    } catch (_) {
      await File(source).copy(target);
    }
  } else {
    await File(source).copy(target);
  }
  await File(_mapPath(bookId)).writeAsString(map.toJson());
}

Future<void> deleteOriginalPdf(int bookId) async {
  for (final f in [originalPdfPath(bookId), _mapPath(bookId)]) {
    try {
      await File(f).delete();
    } catch (_) {}
  }
}
