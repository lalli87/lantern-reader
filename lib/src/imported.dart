import 'dart:typed_data';

import 'text_utils.dart';

/// A parsed book before it is stored. Pure Dart (no Flutter, no dart:io) so the web version can
/// use the same code compiled to JavaScript.

class ImportedChapter {
  String title;
  List<String> paras;

  /// For PDFs: the 0-based page each paragraph starts on, so the original pages can follow the text.
  List<int>? pages;
  ImportedChapter(this.title, this.paras, [this.pages]);
}

class ImportedBook {
  String title, author, series, language, description, format;
  double? seriesNo;
  List<ImportedChapter> chapters;
  Uint8List? cover;
  ImportedBook({
    required this.title,
    this.author = '',
    this.series = '',
    this.seriesNo,
    this.language = '',
    this.description = '',
    required this.format,
    required this.chapters,
    this.cover,
  });
}

final _chapterLine = RegExp(r'^(chapter|ch\.|prologue|epilogue|part|book|volume|第)\s*[\divxlc零一二三四五六七八九十百千]*', caseSensitive: false);

/// Splits a flat paragraph list into chapters at headings (or at "Chapter N" lines for plain text).
ImportedBook singleToBook(String title, String format, List<String> paras, {bool detectChapters = false}) {
  if (detectChapters) {
    paras = [
      for (final l in paras)
        (l.length < 80 && _chapterLine.hasMatch(l) && RegExp(r'\d|prologue|epilogue|[一二三四五六七八九十]', caseSensitive: false).hasMatch(l))
            ? '# $l'
            : l,
    ];
  }
  // Split on the shallowest heading level that appears at least twice.
  var level = 0;
  for (var l = 1; l <= 3 && level == 0; l++) {
    if (paras.where((x) => headingLevel(x) == l).length >= 2) level = l;
  }
  final chapters = <ImportedChapter>[];
  if (level == 0) {
    chapters.add(ImportedChapter(title, paras));
  } else {
    ImportedChapter? cur;
    for (final x in paras) {
      final hl = headingLevel(x);
      if (hl > 0 && hl <= level) {
        cur = ImportedChapter(paraText(x), []);
        chapters.add(cur);
      } else {
        (cur ??= _front(chapters, title)).paras.add(x);
      }
    }
  }
  chapters.removeWhere((c) => c.paras.isEmpty && chapters.length > 1 && c.title == title);
  return ImportedBook(title: title, format: format, chapters: chapters);
}

ImportedChapter _front(List<ImportedChapter> list, String title) {
  final c = ImportedChapter(title, []);
  list.add(c);
  return c;
}
