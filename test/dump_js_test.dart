// Writes the page scripts to disk so they can be run in a real browser engine during development,
// and converts a captured extraction result back into paragraphs.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lantern_reader/src/browser.dart';
import 'package:lantern_reader/src/text_utils.dart';

void main() {
  final out = Platform.environment['JS_OUT'];
  test('dump scripts', () {
    if (out == null) return;
    File('$out/extract.js').writeAsStringSync(extractJs(null));
    File('$out/extract_hint.js').writeAsStringSync(extractJs('.story'));
    File('$out/next.js').writeAsStringSync(nextLinkJs);
    File('$out/textonly.js').writeAsStringSync(textOnlyJs);
  });
  test('captured result becomes paragraphs', () {
    if (out == null) return;
    for (final f in Directory(out).listSync().whereType<File>().where((f) => f.path.endsWith('.result.json'))) {
      final m = unwrapJsResult(f.readAsStringSync()) as Map;
      final paras = htmlToParagraphs('${m['html']}');
      File(f.path.replaceAll('.result.json', '.paras.txt')).writeAsStringSync(
          'how=${m['how']} title=${m['title']} heading=${m['heading']} next=${m['next']} guess=${guessBookTitle('${m['docTitle']}', Uri.parse('${m['url']}').host)}\n'
          'paras=${paras.length} chars=${paras.fold<int>(0, (n, p) => n + p.length)}\n---\n${paras.join('\n')}');
    }
  });
}
