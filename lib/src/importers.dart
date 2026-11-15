import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import 'db.dart';
import 'models.dart';
import 'text_utils.dart';

class ImportedChapter {
  String title;
  List<String> paras;
  ImportedChapter(this.title, this.paras);
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

const importExtensions = ['pdf', 'epub', 'txt', 'md', 'markdown', 'html', 'htm', 'xhtml', 'fb2', 'docx', 'odt'];

/// Reads a book file into chapters. Throws [FormatException] for unsupported or unreadable files.
ImportedBook parseBookBytes(Uint8List bytes, String fileName) {
  final ext = p.extension(fileName).replaceFirst('.', '').toLowerCase();
  final base = p.basenameWithoutExtension(fileName);
  switch (ext) {
    case 'epub':
      return _epub(bytes, base);
    case 'txt':
      return _single(base, 'TXT', plainToParagraphs(_decode(bytes)), detectChapters: true);
    case 'md' || 'markdown':
      return _single(base, 'MD', _markdown(_decode(bytes)));
    case 'html' || 'htm' || 'xhtml':
      final s = _decode(bytes);
      final t = RegExp(r'<title[^>]*>([^<]*)</title>', caseSensitive: false).firstMatch(s)?.group(1)?.trim();
      return _single((t == null || t.isEmpty) ? base : t, 'HTML', htmlToParagraphs(s));
    case 'fb2':
      return _fb2(_decode(bytes), base);
    case 'docx':
      return _docx(bytes, base);
    case 'odt':
      return _odt(bytes, base);
  }
  throw FormatException('Unsupported file type: .$ext');
}

String _decode(Uint8List b) {
  try {
    return utf8.decode(b);
  } catch (_) {
    return latin1.decode(b);
  }
}

final _chapterLine = RegExp(r'^(chapter|ch\.|prologue|epilogue|part|book|volume|第)\s*[\divxlc零一二三四五六七八九十百千]*', caseSensitive: false);

/// Public entry for other importers (PDF).
ImportedBook singleToBook(String title, String format, List<String> paras, {bool detectChapters = false}) =>
    _single(title, format, paras, detectChapters: detectChapters);

/// Splits a flat paragraph list into chapters at headings (or at "Chapter N" lines for plain text).
ImportedBook _single(String title, String format, List<String> paras, {bool detectChapters = false}) {
  if (detectChapters) {
    paras = [
      for (final l in paras)
        (l.length < 80 && _chapterLine.hasMatch(l) && RegExp(r'\d|prologue|epilogue|[一二三四五六七八九十]', caseSensitive: false).hasMatch(l))
            ? '# $l'
            : l
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

List<String> _markdown(String s) {
  final out = <String>[];
  for (var l in plainToParagraphs(s)) {
    final h = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(l);
    if (h != null) {
      out.add('${'#' * h.group(1)!.length.clamp(1, 3)} ${h.group(2)!.replaceAll(RegExp(r'\s*#+$'), '')}');
      continue;
    }
    if (RegExp(r'^(-{3,}|\*{3,}|_{3,}|```.*)$').hasMatch(l)) continue;
    l = l
        .replaceAllMapped(RegExp(r'!?\[([^\]]*)\]\([^)]*\)'), (m) => m.group(1)!)
        .replaceAllMapped(RegExp(r'(\*\*|__)(.+?)\1'), (m) => m.group(2)!)
        .replaceAllMapped(RegExp(r'(?<![\w*])[*_](?!\s)(.+?)(?<!\s)[*_](?![\w*])'), (m) => m.group(1)!)
        .replaceAll('`', '')
        .replaceFirst(RegExp(r'^>\s?'), '');
    out.add(l);
  }
  return out;
}

Archive _unzip(Uint8List bytes) {
  try {
    return ZipDecoder().decodeBytes(bytes);
  } catch (e) {
    throw const FormatException('This file is damaged or not a valid archive.');
  }
}

Uint8List? _file(Archive a, String path) {
  final want = Uri.decodeFull(path).toLowerCase();
  for (final f in a.files) {
    if (f.isFile && f.name.toLowerCase() == want) return f.readBytes();
  }
  return null;
}

String _txt(XmlElement? e) => (e?.innerText ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();

XmlElement? _first(XmlNode n, String local) {
  for (final e in n.descendantElements) {
    if (e.name.local == local) return e;
  }
  return null;
}

Iterable<XmlElement> _all(XmlNode n, String local) => n.descendantElements.where((e) => e.name.local == local);

String? _attr(XmlElement e, String local) {
  for (final a in e.attributes) {
    if (a.name.local == local) return a.value;
  }
  return null;
}

ImportedBook _epub(Uint8List bytes, String fallbackTitle) {
  final zip = _unzip(bytes);
  final container = _file(zip, 'META-INF/container.xml');
  if (container == null) throw const FormatException('Not a valid EPUB (no container).');
  final opfPath = _attr(_first(XmlDocument.parse(_decode(container)), 'rootfile')!, 'full-path') ?? '';
  final opfBytes = _file(zip, opfPath);
  if (opfBytes == null) throw const FormatException('Not a valid EPUB (no package file).');
  final opf = XmlDocument.parse(_decode(opfBytes));
  final dir = p.posix.dirname(opfPath) == '.' ? '' : '${p.posix.dirname(opfPath)}/';
  String resolve(String href, [String? from]) =>
      p.posix.normalize('${from ?? dir}${Uri.decodeFull(href.split('#').first)}');

  final meta = _first(opf, 'metadata');
  String m(String name) => meta == null ? '' : _txt(_first(meta, name));
  final manifest = <String, XmlElement>{for (final i in _all(opf, 'item')) _attr(i, 'id') ?? '': i};

  // Series and cover from <meta name=... content=...>.
  var series = '';
  double? seriesNo;
  String? coverId;
  for (final e in _all(opf, 'meta')) {
    final name = _attr(e, 'name') ?? '', content = _attr(e, 'content') ?? '';
    if (name == 'calibre:series') series = content;
    if (name == 'calibre:series_index') seriesNo = double.tryParse(content);
    if (name == 'cover') coverId = content;
    if (_attr(e, 'property') == 'belongs-to-collection') series = _txt(e);
  }
  Uint8List? cover;
  final coverItem = manifest.values.where((i) => (_attr(i, 'properties') ?? '').contains('cover-image')).firstOrNull ??
      manifest[coverId];
  if (coverItem != null && (_attr(coverItem, 'media-type') ?? '').startsWith('image/')) {
    cover = _file(zip, resolve(_attr(coverItem, 'href') ?? ''));
  }

  // Chapter titles from the navigation document (EPUB 3) or the NCX (EPUB 2).
  final titles = <String, String>{};
  final navItem = manifest.values.where((i) => (_attr(i, 'properties') ?? '').split(' ').contains('nav')).firstOrNull;
  if (navItem != null) {
    final href = _attr(navItem, 'href') ?? '';
    final nb = _file(zip, resolve(href));
    if (nb != null) {
      final navDir = p.posix.dirname(resolve(href)) == '.' ? '' : '${p.posix.dirname(resolve(href))}/';
      try {
        for (final a in _all(XmlDocument.parse(_decode(nb)), 'a')) {
          final h = _attr(a, 'href');
          if (h != null && h.isNotEmpty) titles.putIfAbsent(resolve(h, navDir), () => _txt(a));
        }
      } catch (_) {}
    }
  }
  final ncxItem = manifest.values.where((i) => _attr(i, 'media-type') == 'application/x-dtbncx+xml').firstOrNull;
  if (titles.isEmpty && ncxItem != null) {
    final href = _attr(ncxItem, 'href') ?? '';
    final nb = _file(zip, resolve(href));
    if (nb != null) {
      final ncxDir = p.posix.dirname(resolve(href)) == '.' ? '' : '${p.posix.dirname(resolve(href))}/';
      try {
        for (final np in _all(XmlDocument.parse(_decode(nb)), 'navPoint')) {
          final src = _attr(_first(np, 'content') ?? np, 'src');
          if (src != null) titles.putIfAbsent(resolve(src, ncxDir), () => _txt(_first(np, 'text')));
        }
      } catch (_) {}
    }
  }

  final chapters = <ImportedChapter>[];
  for (final ref in _all(opf, 'itemref')) {
    final item = manifest[_attr(ref, 'idref')];
    if (item == null) continue;
    final path = resolve(_attr(item, 'href') ?? '');
    final b = _file(zip, path);
    if (b == null) continue;
    final paras = htmlToParagraphs(_decode(b));
    if (paras.isEmpty) continue;
    var title = titles[path] ?? '';
    if (title.isEmpty) {
      final h = paras.where((x) => headingLevel(x) > 0).firstOrNull;
      title = h != null ? paraText(h) : '';
    }
    // A file with no title of its own continues the previous chapter.
    if (title.isEmpty && chapters.isNotEmpty) {
      chapters.last.paras.addAll(paras);
    } else {
      chapters.add(ImportedChapter(title.isEmpty ? 'Section ${chapters.length + 1}' : title, paras));
    }
  }
  if (chapters.isEmpty) throw const FormatException('This EPUB has no readable text.');
  final t = m('title');
  return ImportedBook(
    title: t.isEmpty ? fallbackTitle : t,
    author: m('creator'),
    language: m('language'),
    description: htmlToParagraphs(m('description')).join('\n'),
    series: series,
    seriesNo: seriesNo,
    format: 'EPUB',
    chapters: chapters,
    cover: cover,
  );
}

ImportedBook _fb2(String xmlText, String fallbackTitle) {
  final doc = XmlDocument.parse(xmlText);
  final info = _first(doc, 'title-info');
  final a = info == null ? null : _first(info, 'author');
  final author = a == null
      ? ''
      : ['first-name', 'middle-name', 'last-name'].map((n) => _txt(_first(a, n))).where((s) => s.isNotEmpty).join(' ');
  final seq = info == null ? null : _first(info, 'sequence');
  final chapters = <ImportedChapter>[];

  void section(XmlElement s, int depth) {
    final titleEl = s.childElements.where((e) => e.name.local == 'title').firstOrNull;
    final title = _txt(titleEl);
    ImportedChapter cur;
    if (depth == 0 || chapters.isEmpty) {
      cur = ImportedChapter(title.isEmpty ? 'Section ${chapters.length + 1}' : title, []);
      chapters.add(cur);
    } else {
      cur = chapters.last;
      if (title.isNotEmpty) cur.paras.add('## $title');
    }
    for (final e in s.childElements) {
      switch (e.name.local) {
        case 'section':
          section(e, depth + 1);
        case 'title':
          break;
        case 'p' || 'subtitle' || 'v' || 'text-author':
          final t = _txt(e);
          if (t.isNotEmpty) chapters.last.paras.add(e.name.local == 'subtitle' ? '### $t' : t);
        default:
          for (final pp in _all(e, 'p')) {
            final t = _txt(pp);
            if (t.isNotEmpty) chapters.last.paras.add(t);
          }
      }
    }
  }

  for (final body in _all(doc, 'body')) {
    for (final s in body.childElements.where((e) => e.name.local == 'section')) {
      section(s, 0);
    }
  }
  chapters.removeWhere((c) => c.paras.isEmpty);
  if (chapters.isEmpty) throw const FormatException('This FB2 file has no readable text.');

  Uint8List? cover;
  final img = info == null ? null : _first(info, 'image');
  final ref = img == null ? null : _attr(img, 'href')?.replaceFirst('#', '');
  if (ref != null) {
    final bin = _all(doc, 'binary').where((b) => _attr(b, 'id') == ref).firstOrNull;
    if (bin != null) {
      try {
        cover = base64.decode(bin.innerText.replaceAll(RegExp(r'\s'), ''));
      } catch (_) {}
    }
  }
  final t = info == null ? '' : _txt(_first(info, 'book-title'));
  final ann = info == null ? null : _first(info, 'annotation');
  return ImportedBook(
    title: t.isEmpty ? fallbackTitle : t,
    author: author,
    language: info == null ? '' : _txt(_first(info, 'lang')),
    description: ann == null ? '' : _all(ann, 'p').map(_txt).join('\n'),
    series: seq == null ? '' : (_attr(seq, 'name') ?? ''),
    seriesNo: seq == null ? null : double.tryParse(_attr(seq, 'number') ?? ''),
    format: 'FB2',
    chapters: chapters,
    cover: cover,
  );
}

ImportedBook _docx(Uint8List bytes, String fallbackTitle) {
  final zip = _unzip(bytes);
  final body = _file(zip, 'word/document.xml');
  if (body == null) throw const FormatException('Not a valid Word document.');
  final paras = <String>[];
  for (final wp in _all(XmlDocument.parse(_decode(body)), 'p')) {
    final sb = StringBuffer();
    for (final e in wp.descendantElements) {
      switch (e.name.local) {
        case 't':
          sb.write(e.innerText);
        case 'tab':
          sb.write(' ');
        case 'br' || 'cr':
          sb.write('\n');
      }
    }
    final ps = _first(wp, 'pStyle');
    final style = ps == null ? '' : (_attr(ps, 'val') ?? '');
    final h = RegExp(r'^(?:heading|Heading)\s?(\d)$').firstMatch(style);
    final level = style == 'Title' ? 1 : (h == null ? 0 : int.parse(h.group(1)!).clamp(1, 3));
    for (final line in plainToParagraphs(sb.toString())) {
      paras.add(level > 0 ? '${'#' * level} $line' : line);
    }
  }
  var title = fallbackTitle, author = '';
  final core = _file(zip, 'docProps/core.xml');
  if (core != null) {
    try {
      final c = XmlDocument.parse(_decode(core));
      final t = _txt(_first(c, 'title'));
      if (t.isNotEmpty) title = t;
      author = _txt(_first(c, 'creator'));
    } catch (_) {}
  }
  if (paras.isEmpty) throw const FormatException('This document has no readable text.');
  return _single(title, 'DOCX', paras)..author = author;
}

ImportedBook _odt(Uint8List bytes, String fallbackTitle) {
  final zip = _unzip(bytes);
  final body = _file(zip, 'content.xml');
  if (body == null) throw const FormatException('Not a valid OpenDocument text file.');
  final paras = <String>[];
  for (final e in XmlDocument.parse(_decode(body)).descendantElements) {
    final n = e.name.local;
    if (n != 'p' && n != 'h') continue;
    // Skip paragraphs nested in another paragraph-like element (e.g. inside a frame).
    if (e.ancestorElements.any((a) => a.name.local == 'p' || a.name.local == 'h')) continue;
    final t = _txt(e);
    if (t.isEmpty) continue;
    final level = n == 'h' ? (int.tryParse(_attr(e, 'outline-level') ?? '1') ?? 1).clamp(1, 3) : 0;
    paras.add(level > 0 ? '${'#' * level} $t' : t);
  }
  if (paras.isEmpty) throw const FormatException('This document has no readable text.');
  return _single(fallbackTitle, 'ODT', paras);
}

/// Stores a parsed book and returns its id. [coversDir] is where the cover image is written.
Future<int> saveImported(ImportedBook ib, {String fileName = '', int fileSize = 0, String? coversDir}) async {
  final book = Book(
    title: ib.title,
    author: ib.author,
    series: ib.series,
    seriesNo: ib.seriesNo,
    language: ib.language,
    description: ib.description,
    format: ib.format,
    fileName: fileName,
    fileSize: fileSize,
  );
  final id = await Db.insertBook(book);
  if (ib.cover != null && coversDir != null) {
    try {
      final f = File(p.join(coversDir, 'cover_$id.img'));
      await f.parent.create(recursive: true);
      await f.writeAsBytes(ib.cover!);
      book.coverPath = f.path;
      await Db.updateBook(book);
    } catch (_) {}
  }
  for (final c in ib.chapters) {
    await Db.addChapter(id, c.title, c.paras.join('\n'));
  }
  return id;
}
