import 'dart:convert';
import 'dart:typed_data';

import 'package:charset/charset.dart';

/// Turns the bytes of a text file into text, guessing the encoding: UTF-8, UTF-16 (with or without a byte
/// order mark), Chinese GBK, Japanese Shift-JIS, Korean EUC-KR, or Western Windows-1252. Pure Dart.
String decodeText(Uint8List b) {
  if (b.length >= 3 && b[0] == 0xEF && b[1] == 0xBB && b[2] == 0xBF) {
    return utf8.decode(Uint8List.sublistView(b, 3), allowMalformed: true);
  }
  if (b.length >= 2 && ((b[0] == 0xFF && b[1] == 0xFE) || (b[0] == 0xFE && b[1] == 0xFF))) return utf16.decode(b);
  // UTF-16 without a byte order mark: every other byte is zero in mostly-Latin text.
  if (b.length >= 64) {
    var evenZero = 0, oddZero = 0;
    final n = b.length < 4000 ? b.length : 4000;
    for (var i = 0; i + 1 < n; i += 2) {
      if (b[i] == 0) evenZero++;
      if (b[i + 1] == 0) oddZero++;
    }
    if (oddZero > n / 2 * 0.4 && evenZero < n / 2 * 0.05) return const Utf16Decoder().decodeUtf16Le(b);
    if (evenZero > n / 2 * 0.4 && oddZero < n / 2 * 0.05) return const Utf16Decoder().decodeUtf16Be(b);
  }
  try {
    return utf8.decode(b);
  } catch (_) {}
  // Text in a Western single-byte encoding has few bytes above 127; CJK text has many.
  // In CJK encodings the bytes above 127 come in pairs; in Western text they stand alone.
  var high = 0, alone = 0;
  for (var i = 0; i < b.length; i++) {
    if (b[i] < 0x80) continue;
    high++;
    if ((i == 0 || b[i - 1] < 0x80) && (i + 1 >= b.length || b[i + 1] < 0x80)) alone++;
  }
  if (high < b.length * 0.1 || alone > high * 0.3) return windows1252.decode(b);
  for (final dec in <String Function()>[
    () => _strict(gbk.decode(b, allowMalformed: true)),
    () => _strict(shiftJis.decode(b)),
    () => _strict(eucKr.decode(b)),
  ]) {
    try {
      return dec();
    } catch (_) {}
  }
  return gbk.decode(b, allowMalformed: true);
}

/// Rejects a decoding with more than a handful of unknown characters.
String _strict(String s) {
  final bad = '\uFFFD'.allMatches(s).length + String.fromCharCode(0xE7B3).allMatches(s).length;
  if (bad > 0 && bad > s.length / 2000) throw const FormatException('wrong encoding');
  return s;
}
