// Compiled to web-app/pdfbook.js with:
//   dart compile js -O2 -o web-app/pdfbook.js tool/web_pdf.dart
// so the web version turns PDFs into books with exactly the same code as the phone app
// (column layout, paragraphs, chapters). The web page extracts text with pdf.js and calls
// `lanternPdfBook(json)`.
import 'dart:convert';
import 'dart:js_interop';

import 'package:lantern_reader/src/pdf_book.dart';
import 'package:lantern_reader/src/pdf_layout.dart';

@JS('lanternPdfBook')
external set _lanternPdfBook(JSFunction f);

/// Input: {"name": file name, "outline": [[title, 1-based page]...],
///         "pages": [{"w", "h", "t": text, "r": [left, top, right, bottom per character, PDF coordinates]}]}
/// Output: {"title", "chapters": [{"title", "paras": [...], "pages": [...]}]} or {"error": message}.
String run(String input) {
  try {
    final j = jsonDecode(input) as Map<String, dynamic>;
    final pageTexts = <String>[];
    final layouts = <PageLayout?>[];
    for (final p in (j['pages'] as List).cast<Map<String, dynamic>>()) {
      final text = p['t'] as String? ?? '';
      final flat = (p['r'] as List? ?? const []).cast<num>();
      final w = (p['w'] as num).toDouble(), h = (p['h'] as num).toDouble();
      pageTexts.add(text);
      if (flat.length != text.length * 4 || text.trim().isEmpty) {
        layouts.add(null);
        continue;
      }
      final rects = [
        for (var i = 0; i < text.length; i++)
          (flat[i * 4].toDouble(), flat[i * 4 + 1].toDouble(), flat[i * 4 + 2].toDouble(), flat[i * 4 + 3].toDouble())
      ];
      layouts.add(layoutPage(segmentsFromChars(text, rects, h), w, h));
    }
    applyLayouts(pageTexts, layouts);
    final marks = [
      for (final m in (j['outline'] as List? ?? const []).cast<List>())
        if ((m[0] as String).trim().isNotEmpty) ((m[0] as String).trim(), (m[1] as num).toInt())
    ];
    final b = bookFromPdfPages(pageTexts, marks, j['name'] as String? ?? 'PDF');
    return jsonEncode({
      'title': b.title,
      'chapters': [
        for (final c in b.chapters) {'title': c.title, 'paras': c.paras, 'pages': c.pages ?? const <int>[]}
      ],
    });
  } on FormatException catch (e) {
    return jsonEncode({'error': e.message});
  } catch (e) {
    return jsonEncode({'error': 'This PDF could not be read ($e).'});
  }
}

void main() {
  _lanternPdfBook = ((JSString s) => run(s.toDart).toJS).toJS;
}
