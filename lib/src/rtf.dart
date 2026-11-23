import 'dart:typed_data';

import 'package:charset/charset.dart';

import 'imported.dart';

/// Rich Text Format (.rtf) documents: the text and paragraphs, without formatting. Pure Dart.
ImportedBook parseRtf(Uint8List bytes, String fallbackTitle) {
  final (title, author, paras) = rtfToParagraphs(String.fromCharCodes(bytes));
  if (paras.isEmpty) throw const FormatException('This RTF document has no readable text.');
  final t = title.isEmpty ? fallbackTitle : title;
  return singleToBook(t, 'RTF', paras, detectChapters: true)
    ..title = t
    ..author = author;
}

const _skipDest = {
  'fonttbl', 'colortbl', 'stylesheet', 'pict', 'header', 'headerl', 'headerr', 'headerf', 'footer', 'footerl', 'footerr', //
  'footerf', 'object', 'themedata', 'datastore', 'listtable', 'listoverridetable', 'revtbl', 'rsidtbl', 'generator',
  'xmlnstbl', 'latentstyles', 'mmathPr', 'fldinst', 'filetbl', 'colorschememapping', 'pgdsctbl', 'operator', 'company',
  'creatim', 'revtim', 'printim', 'buptim', 'keywords', 'subject', 'doccomm', 'comment', 'category', 'manager', 'bkmkstart',
  'bkmkend', 'shppict', 'nonshppict', 'blipuid', 'userprops', 'xe', 'tc', 'private',
};

const _symbols = {
  'emdash': '\u2014', 'endash': '\u2013', 'lquote': '\u2018', 'rquote': '\u2019', 'ldblquote': '\u201C', //
  'rdblquote': '\u201D', 'bullet': '\u2022', 'tab': ' ', 'emspace': ' ', 'enspace': ' ', 'qmspace': ' ',
};

class _Group {
  bool skip;
  int uc;
  String? capture; // 'title' or 'author' while inside \info
  _Group(this.skip, this.uc, this.capture);
}

/// (title, author, paragraphs) from RTF source text (bytes as Latin-1 code units).
(String, String, List<String>) rtfToParagraphs(String s) {
  var codepage = 1252;
  final stack = <_Group>[_Group(false, 1, null)];
  final out = StringBuffer();
  final title = StringBuffer(), author = StringBuffer();
  final pending = <int>[]; // \'hh bytes, decoded together (double-byte code pages)
  var skipChars = 0;

  StringBuffer target() => switch (stack.last.capture) {
        'title' => title,
        'author' => author,
        _ => out,
      };

  void flushBytes() {
    if (pending.isEmpty) return;
    final b = Uint8List.fromList(pending);
    pending.clear();
    String t;
    try {
      t = switch (codepage) {
        936 => gbk.decode(b, allowMalformed: true),
        932 => shiftJis.decode(b),
        949 => eucKr.decode(b),
        1251 => windows1251.decode(b),
        1250 => windows1250.decode(b),
        _ => windows1252.decode(b),
      };
    } catch (_) {
      t = String.fromCharCodes(b);
    }
    if (!stack.last.skip) target().write(t);
  }

  void emit(String t) {
    flushBytes();
    if (skipChars > 0) {
      skipChars--;
      return;
    }
    if (!stack.last.skip) target().write(t);
  }

  var i = 0;
  var startOfGroup = false;
  while (i < s.length) {
    final c = s[i];
    if (c == '{') {
      flushBytes();
      final g = stack.last;
      stack.add(_Group(g.skip, g.uc, g.capture));
      startOfGroup = true;
      i++;
      continue;
    }
    if (c == '}') {
      flushBytes();
      if (stack.length > 1) stack.removeLast();
      startOfGroup = false;
      i++;
      continue;
    }
    if (c == '\\' && i + 1 < s.length) {
      final n = s[i + 1];
      if (n == '\'' && i + 3 < s.length) {
        final v = int.tryParse(s.substring(i + 2, i + 4), radix: 16);
        i += 4;
        if (v == null) continue;
        if (skipChars > 0) {
          skipChars--;
        } else {
          pending.add(v);
        }
        startOfGroup = false;
        continue;
      }
      if (RegExp(r'[a-zA-Z]').hasMatch(n)) {
        final m = RegExp(r'([a-zA-Z]+)(-?\d+)? ?').matchAsPrefix(s, i + 1)!;
        final word = m.group(1)!, param = m.group(2) == null ? null : int.parse(m.group(2)!);
        i = m.end;
        final first = startOfGroup;
        startOfGroup = false;
        switch (word) {
          case 'par' || 'line' || 'sect' || 'page' || 'row':
            emit('\n');
          case 'cell':
            emit(' ');
          case 'u':
            if (param != null) {
              flushBytes();
              if (skipChars > 0) skipChars = 0;
              if (!stack.last.skip) target().writeCharCode(param < 0 ? param + 65536 : param);
              skipChars = stack.last.uc;
            }
          case 'uc':
            stack.last.uc = param ?? 1;
          case 'ansicpg':
            codepage = param ?? 1252;
          case 'title' || 'author':
            stack.last.capture = word;
            stack.last.skip = false;
          case 'info':
            // Only the title and author inside \info are of interest.
            stack.last.skip = true;
          default:
            if (_symbols.containsKey(word)) {
              emit(_symbols[word]!);
            } else if (first && _skipDest.contains(word)) {
              stack.last.skip = true;
            }
        }
        continue;
      }
      i += 2;
      startOfGroup = false;
      switch (n) {
        case '*':
          stack.last.skip = true;
        case '\\' || '{' || '}':
          emit(n);
        case '~':
          emit('\u00A0');
        case '_':
          emit('-');
        case '\n' || '\r':
          emit('\n');
      }
      continue;
    }
    if (c == '\n' || c == '\r') {
      i++;
      continue;
    }
    startOfGroup = false;
    if (skipChars > 0) {
      skipChars--;
      i++;
      continue;
    }
    // Plain text runs: copy until the next special character.
    var j = i;
    while (j < s.length && !'\\{}\r\n'.contains(s[j])) {
      j++;
    }
    final run = s.substring(i, j);
    if (skipChars > 0 && run.isNotEmpty) {
      final k = skipChars < run.length ? skipChars : run.length;
      skipChars -= k;
      emit(run.substring(k));
    } else {
      emit(run);
    }
    i = j;
  }
  flushBytes();
  final paras = [
    for (final l in out.toString().split('\n'))
      if (l.replaceAll('\u00A0', ' ').trim().isNotEmpty) l.replaceAll(RegExp(r'[ \t\u00A0]+'), ' ').trim(),
  ];
  return (title.toString().trim(), author.toString().trim(), paras);
}
