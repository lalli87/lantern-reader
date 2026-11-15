import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'models.dart';
import 'text_utils.dart';

String _x(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');

/// Builds an EPUB 3 file (with an EPUB 2 NCX for older readers) from a book's chapters.
Uint8List buildEpub(Book b, List<Chapter> chapters, {Uint8List? cover}) {
  final a = Archive();
  void add(String name, String text) => a.addFile(ArchiveFile.bytes(name, utf8.encode(text)));

  // The mimetype entry must come first and be stored uncompressed.
  final mt = ascii.encode('application/epub+zip');
  a.addFile(ArchiveFile.noCompress('mimetype', mt.length, mt));

  add('META-INF/container.xml', '''<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles>
</container>''');

  final uid = 'urn:lantern:${b.id ?? 0}-${b.addedAt}';
  final lang = b.language.isEmpty ? 'en' : b.language;
  final modified = '${DateTime.now().toUtc().toIso8601String().split('.').first}Z';
  String file(int i) => 'ch${(i + 1).toString().padLeft(4, '0')}.xhtml';

  final manifest = StringBuffer(), spine = StringBuffer(), nav = StringBuffer(), ncx = StringBuffer();
  for (var i = 0; i < chapters.length; i++) {
    final c = chapters[i];
    final body = StringBuffer();
    final paras = splitParas(c.content);
    final firstIsTitle = paras.isNotEmpty && headingLevel(paras.first) > 0 && paraText(paras.first) == c.title;
    if (!firstIsTitle) body.writeln('<h1>${_x(c.title)}</h1>');
    for (final para in paras) {
      final lvl = headingLevel(para);
      body.writeln(lvl > 0 ? '<h$lvl>${_x(paraText(para))}</h$lvl>' : '<p>${_x(para)}</p>');
    }
    add('OEBPS/${file(i)}', '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="${_x(lang)}" lang="${_x(lang)}">
<head><meta charset="utf-8"/><title>${_x(c.title)}</title><link rel="stylesheet" type="text/css" href="style.css"/></head>
<body>
$body</body>
</html>''');
    manifest.writeln('    <item id="c$i" href="${file(i)}" media-type="application/xhtml+xml"/>');
    spine.writeln('    <itemref idref="c$i"/>');
    nav.writeln('      <li><a href="${file(i)}">${_x(c.title)}</a></li>');
    ncx.writeln('    <navPoint id="n$i" playOrder="${i + 1}"><navLabel><text>${_x(c.title)}</text></navLabel>'
        '<content src="${file(i)}"/></navPoint>');
  }

  var coverMeta = '';
  if (cover != null && cover.length > 4) {
    final png = cover[0] == 0x89 && cover[1] == 0x50;
    final name = png ? 'cover.png' : 'cover.jpg';
    a.addFile(ArchiveFile.bytes('OEBPS/$name', cover));
    manifest.writeln('    <item id="cover-img" href="$name" media-type="${png ? 'image/png' : 'image/jpeg'}" properties="cover-image"/>');
    coverMeta = '\n    <meta name="cover" content="cover-img"/>';
  }

  add('OEBPS/style.css', 'body{margin:5%;line-height:1.5}p{margin:0 0 .7em 0}h1,h2,h3{line-height:1.25;margin:1.2em 0 .6em 0}');
  add('OEBPS/nav.xhtml', '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
<head><meta charset="utf-8"/><title>Contents</title></head>
<body>
  <nav epub:type="toc" id="toc"><h1>Contents</h1>
    <ol>
$nav    </ol>
  </nav>
</body>
</html>''');
  add('OEBPS/toc.ncx', '''<?xml version="1.0" encoding="UTF-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <head><meta name="dtb:uid" content="${_x(uid)}"/></head>
  <docTitle><text>${_x(b.title)}</text></docTitle>
  <navMap>
$ncx  </navMap>
</ncx>''');
  final seriesMeta = b.series.isEmpty
      ? ''
      : '\n    <meta name="calibre:series" content="${_x(b.series)}"/>'
          '${b.seriesNo == null ? '' : '\n    <meta name="calibre:series_index" content="${b.seriesNo}"/>'}';
  add('OEBPS/content.opf', '''<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="uid">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="uid">${_x(uid)}</dc:identifier>
    <dc:title>${_x(b.title)}</dc:title>
    <dc:language>${_x(lang)}</dc:language>${b.author.isEmpty ? '' : '\n    <dc:creator>${_x(b.author)}</dc:creator>'}${b.description.isEmpty ? '' : '\n    <dc:description>${_x(b.description)}</dc:description>'}
    <meta property="dcterms:modified">$modified</meta>$seriesMeta$coverMeta
  </metadata>
  <manifest>
    <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
    <item id="css" href="style.css" media-type="text/css"/>
$manifest  </manifest>
  <spine toc="ncx">
$spine  </spine>
</package>''');

  return ZipEncoder().encodeBytes(a);
}

/// Plain-text export: title, then chapters separated by blank lines.
String buildPlainText(Book b, List<Chapter> chapters) {
  final sb = StringBuffer('${b.title}\n${b.author.isEmpty ? '' : '${b.author}\n'}\n');
  for (final c in chapters) {
    sb.writeln('\n${c.title}\n');
    for (final para in splitParas(c.content)) {
      final t = paraText(para);
      if (t != c.title) sb.writeln('$t\n');
    }
  }
  return sb.toString();
}
