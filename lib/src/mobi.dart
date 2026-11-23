import 'dart:convert';
import 'dart:typed_data';

import 'imported.dart';
import 'text_utils.dart';

/// Kindle books without copy protection: MOBI, PRC, AZW and AZW3 (KF8). Pure Dart, so the web version can
/// share it. Pictures other than the cover are not kept; the text is split into chapters at the book's page
/// breaks (MOBI) or its files (KF8), with headings as titles.
ImportedBook parseMobi(Uint8List bytes, String fallbackTitle) {
  final db = _PalmDb(bytes);
  if (db.records.isEmpty) throw const FormatException('This Kindle file is damaged.');
  var head = _MobiHeader(db, 0);
  // Newer files hold an old-style (MOBI 6) copy followed by a KF8 copy after a BOUNDARY record. The old
  // copy is simpler to read and has the same text; a KF8-only file (most AZW3) is read as KF8.
  final kf8 = head.version >= 8;
  if (head.encryption != 0) {
    throw const FormatException(
        'This Kindle book is copy-protected (DRM), so it can only be read in Amazon\'s Kindle app.');
  }
  final raw = kf8 ? head.firstFlow(head.text()) : head.text();
  final html = head.decode(raw);
  final title = head.title.isNotEmpty ? head.title : fallbackTitle;

  final parts = kf8
      ? html.split(RegExp(r'(?=<html[\s>])', caseSensitive: false))
      : html.split(RegExp(r'<mbp:pagebreak\s*/?>', caseSensitive: false));
  final chapters = <ImportedChapter>[];
  final pending = <String>[];
  for (final part in parts) {
    final paras = htmlToParagraphs(part);
    if (paras.isEmpty) continue;
    final h = paras.firstWhere((x) => headingLevel(x) > 0, orElse: () => '');
    final heading = h.isNotEmpty && paras.indexOf(h) < 3 ? paraText(h) : '';
    final size = paras.fold<int>(0, (n, x) => n + x.length);
    if (heading.isEmpty && (size < 400 || chapters.isEmpty && pending.isEmpty && size < 1500)) {
      // Title pages, copyright notices and short bits go with the next chapter.
      pending.addAll(paras);
      continue;
    }
    if (heading.isEmpty && chapters.isNotEmpty && pending.isEmpty) {
      chapters.last.paras.addAll(paras);
      continue;
    }
    chapters.add(ImportedChapter(heading.isEmpty ? 'Section ${chapters.length + 1}' : heading, [...pending, ...paras]));
    pending.clear();
  }
  if (pending.isNotEmpty) {
    if (chapters.isEmpty) {
      chapters.add(ImportedChapter(title, [...pending]));
    } else {
      chapters.last.paras.addAll(pending);
    }
  }
  if (chapters.isEmpty) throw const FormatException('This Kindle book has no readable text.');
  // One big chapter with headings inside (common for converted books): split at the headings.
  final ImportedBook book = chapters.length == 1
      ? singleToBook(title, kf8 ? 'AZW3' : 'MOBI', chapters.single.paras, detectChapters: true)
      : ImportedBook(title: title, format: kf8 ? 'AZW3' : 'MOBI', chapters: chapters);
  book
    ..title = title
    ..author = head.exth[100]?.map(head.decodeShort).join(', ') ?? ''
    ..description = head.exth[103] == null ? '' : htmlToParagraphs(head.decodeShort(head.exth[103]!.first)).join('\n')
    ..language = head.exth[524] == null ? '' : head.decodeShort(head.exth[524]!.first)
    ..cover = head.cover();
  return book;
}

/// Whether [bytes] look like a Kindle (PalmDB BOOKMOBI / TEXtREAd) file.
bool looksLikeMobi(Uint8List bytes) {
  if (bytes.length < 78) return false;
  final type = latin1.decode(bytes.sublist(60, 68));
  return type == 'BOOKMOBI' || type == 'TEXtREAd';
}

class _PalmDb {
  final Uint8List bytes;
  final List<int> offsets = [];
  _PalmDb(this.bytes) {
    if (!looksLikeMobi(bytes)) throw const FormatException('This is not a Kindle book file.');
    final bd = ByteData.sublistView(bytes);
    final n = bd.getUint16(76);
    for (var i = 0; i < n; i++) {
      if (78 + i * 8 + 4 > bytes.length) break;
      offsets.add(bd.getUint32(78 + i * 8));
    }
  }
  List<int> get records => offsets;
  Uint8List record(int i) {
    if (i < 0 || i >= offsets.length) return Uint8List(0);
    final start = offsets[i], end = i + 1 < offsets.length ? offsets[i + 1] : bytes.length;
    if (start > bytes.length || end < start) return Uint8List(0);
    return Uint8List.sublistView(bytes, start, end.clamp(start, bytes.length));
  }
}

class _MobiHeader {
  final _PalmDb db;
  final int base; // index of this header's record 0 (KF8 copies start after the BOUNDARY record)
  late final Uint8List r0 = db.record(base);
  late final ByteData bd = ByteData.sublistView(r0);
  int compression = 1, textLength = 0, textRecords = 0, encryption = 0, encoding = 1252, version = 0;
  int firstImage = -1, huffRecord = 0, huffCount = 0, extraFlags = 0;
  String title = '';
  final Map<int, List<Uint8List>> exth = {};

  _MobiHeader(this.db, this.base) {
    if (r0.length < 16) throw const FormatException('This Kindle file is damaged.');
    compression = bd.getUint16(0);
    textLength = bd.getUint32(4);
    textRecords = bd.getUint16(8);
    encryption = bd.getUint16(12);
    if (r0.length >= 24 && latin1.decode(r0.sublist(16, 20)) == 'MOBI') {
      final len = bd.getUint32(20);
      encoding = bd.getUint32(28);
      version = r0.length > 40 ? bd.getUint32(36) : 0;
      if (r0.length > 0x58) {
        final off = bd.getUint32(0x54), n = bd.getUint32(0x58);
        if (off + n <= r0.length) title = decodeShort(r0.sublist(off, off + n));
      }
      if (r0.length > 0x70) firstImage = bd.getUint32(0x6C);
      if (r0.length > 0x78) {
        huffRecord = bd.getUint32(0x70);
        huffCount = bd.getUint32(0x74);
      }
      if (len >= 0xE4 && r0.length >= 0xF4) extraFlags = bd.getUint16(0xF2);
      if (r0.length > 0x84 && bd.getUint32(0x80) & 0x40 != 0) _readExth(16 + len);
      final t = exth[503];
      if (t != null) title = decodeShort(t.first);
    } else {
      // Plain PalmDOC (TEXtREAd): no MOBI header.
      title = latin1.decode(db.bytes.sublist(0, 32)).replaceAll('\u0000', '').trim();
    }
    if (version >= 8 && r0.length >= 0xC4) fdst = bd.getUint32(0xC0);
  }

  int fdst = 0xFFFFFFFF;

  /// KF8 keeps the book's HTML as flow 0, followed by style sheets and pictures as other flows.
  Uint8List firstFlow(Uint8List text) {
    if (fdst == 0xFFFFFFFF || fdst == 0) return text;
    final r = db.record(base + fdst);
    if (r.length < 20 || latin1.decode(r.sublist(0, 4)) != 'FDST') return text;
    final b = ByteData.sublistView(r);
    final start = b.getUint32(12), end = b.getUint32(16);
    if (start >= end || end > text.length) return text;
    return Uint8List.sublistView(text, start, end);
  }

  void _readExth(int at) {
    if (at + 12 > r0.length || latin1.decode(r0.sublist(at, at + 4)) != 'EXTH') return;
    final count = bd.getUint32(at + 8);
    var p = at + 12;
    for (var i = 0; i < count && p + 8 <= r0.length; i++) {
      final type = bd.getUint32(p), len = bd.getUint32(p + 4);
      if (len < 8 || p + len > r0.length) break;
      (exth[type] ??= []).add(Uint8List.sublistView(r0, p + 8, p + len));
      p += len;
    }
  }

  String decodeShort(Uint8List b) => (encoding == 65001 ? utf8.decode(b, allowMalformed: true) : latin1.decode(b)).trim();

  String decode(Uint8List b) => encoding == 65001 ? utf8.decode(b, allowMalformed: true) : _cp1252(b);

  /// All text records, decompressed and joined.
  Uint8List text() {
    final out = BytesBuilder(copy: false);
    _HuffReader? huff;
    if (compression == 17480) {
      final recs = [for (var i = 0; i < huffCount; i++) db.record(base + huffRecord + i)];
      huff = _HuffReader(recs);
    } else if (compression != 1 && compression != 2) {
      throw const FormatException('This Kindle book uses a compression Lantern can\'t read.');
    }
    for (var i = 1; i <= textRecords; i++) {
      var r = db.record(base + i);
      r = Uint8List.sublistView(r, 0, (r.length - trailingSize(r, extraFlags)).clamp(0, r.length));
      out.add(switch (compression) {
        2 => palmDocDecompress(r),
        17480 => huff!.unpack(r),
        _ => r,
      });
    }
    final b = out.takeBytes();
    return textLength > 0 && textLength < b.length ? Uint8List.sublistView(b, 0, textLength) : b;
  }

  Uint8List? cover() {
    final c = exth[201];
    if (c == null || firstImage <= 0 || firstImage == 0xFFFFFFFF) return null;
    final off = ByteData.sublistView(c.first).getUint32(0);
    final r = db.record(base + firstImage + off);
    if (r.length < 4) return null;
    final jpeg = r[0] == 0xFF && r[1] == 0xD8, png = r[0] == 0x89 && r[1] == 0x50, gif = r[0] == 0x47 && r[1] == 0x49;
    return jpeg || png || gif ? Uint8List.fromList(r) : null;
  }
}

/// Size of the extra bytes Kindle files add at the end of each text record ([flags] from the header).
int trailingSize(Uint8List data, int flags) {
  var num = 0;
  for (var f = flags >> 1; f != 0; f >>= 1) {
    if (f & 1 != 0) {
      final end = data.length - num;
      var v = 0;
      for (var i = (end - 4).clamp(0, end); i < end; i++) {
        final b = data[i];
        if (b & 0x80 != 0) v = 0;
        v = (v << 7) | (b & 0x7F);
      }
      num += v;
    }
  }
  if (flags & 1 != 0 && data.length - num - 1 >= 0) num += (data[data.length - num - 1] & 3) + 1;
  return num;
}

/// PalmDOC (LZ77-style) decompression used by most MOBI files.
Uint8List palmDocDecompress(Uint8List data) {
  final out = <int>[];
  var i = 0;
  while (i < data.length) {
    final c = data[i++];
    if (c >= 1 && c <= 8) {
      for (var k = 0; k < c && i < data.length; k++) {
        out.add(data[i++]);
      }
    } else if (c < 0x80) {
      out.add(c);
    } else if (c >= 0xC0) {
      out
        ..add(0x20)
        ..add(c ^ 0x80);
    } else if (i < data.length) {
      final v = (c << 8) | data[i++];
      final dist = (v >> 3) & 0x7FF, len = (v & 7) + 3;
      if (dist == 0 || dist > out.length) continue;
      for (var k = 0; k < len; k++) {
        out.add(out[out.length - dist]);
      }
    }
  }
  return Uint8List.fromList(out);
}

/// HUFF/CDIC decompression (older Amazon-made MOBI files), after calibre's huffcdic.py.
class _HuffReader {
  late final List<(int, bool, int)> dict1;
  final List<int> mincode = [], maxcode = [];
  final List<(Uint8List, bool)?> dictionary = [];

  _HuffReader(List<Uint8List> recs) {
    if (recs.isEmpty) throw const FormatException('This Kindle file is damaged.');
    final huff = recs.first;
    if (huff.length < 16 || latin1.decode(huff.sublist(0, 4)) != 'HUFF') throw const FormatException('This Kindle file is damaged.');
    final bd = ByteData.sublistView(huff);
    final off1 = bd.getUint32(8), off2 = bd.getUint32(12);
    dict1 = [
      for (var i = 0; i < 256; i++)
        () {
          final v = bd.getUint32(off1 + i * 4);
          final codelen = v & 0x1F, term = v & 0x80 != 0, mc = v >> 8;
          return (codelen, term, ((mc + 1) << (32 - codelen)) - 1);
        }(),
    ];
    mincode.add(0);
    maxcode.add(0);
    for (var codelen = 1; codelen <= 32; codelen++) {
      final mn = bd.getUint32(off2 + (codelen - 1) * 8), mx = bd.getUint32(off2 + (codelen - 1) * 8 + 4);
      mincode.add(mn << (32 - codelen));
      maxcode.add(((mx + 1) << (32 - codelen)) - 1);
    }
    for (final cdic in recs.skip(1)) {
      if (cdic.length < 16 || latin1.decode(cdic.sublist(0, 4)) != 'CDIC') continue;
      final cb = ByteData.sublistView(cdic);
      final phrases = cb.getUint32(8), bits = cb.getUint32(12);
      final n = [1 << bits, phrases - dictionary.length].reduce((a, b) => a < b ? a : b);
      for (var i = 0; i < n; i++) {
        final off = cb.getUint16(16 + i * 2);
        final blen = cb.getUint16(16 + off);
        final start = 18 + off, end = (start + (blen & 0x7FFF)).clamp(start, cdic.length);
        dictionary.add((Uint8List.sublistView(cdic, start, end), blen & 0x8000 != 0));
      }
    }
  }

  Uint8List unpack(Uint8List input) {
    final data = Uint8List(input.length + 8)..setAll(0, input);
    final bd = ByteData.sublistView(data);
    var bitsLeft = input.length * 8, pos = 0, n = 32;
    var x = bd.getUint64(0);
    final out = BytesBuilder(copy: false);
    while (true) {
      if (n <= 0) {
        pos += 4;
        if (pos + 8 > data.length) break;
        x = bd.getUint64(pos);
        n += 32;
      }
      final code = (x >>> n) & 0xFFFFFFFF;
      var (codelen, term, mc) = dict1[code >>> 24];
      if (!term) {
        while (codelen < 32 && code < mincode[codelen]) {
          codelen++;
        }
        mc = maxcode[codelen];
      }
      n -= codelen;
      bitsLeft -= codelen;
      if (bitsLeft < 0 || codelen == 0) break;
      final r = (mc - code) >>> (32 - codelen);
      if (r < 0 || r >= dictionary.length) break;
      var entry = dictionary[r];
      if (entry == null) break; // a phrase that refers to itself: damaged data
      if (!entry.$2) {
        dictionary[r] = null;
        entry = (unpack(entry.$1), true);
        dictionary[r] = entry;
      }
      out.add(entry.$1);
    }
    return out.takeBytes();
  }
}

const _cp1252High = [
  0x20AC, 0x81, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021, 0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0x8D, 0x017D, 0x8F, //
  0x90, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014, 0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0x9D, 0x017E, 0x0178,
];

String _cp1252(Uint8List b) {
  final codes = Uint16List(b.length);
  for (var i = 0; i < b.length; i++) {
    final c = b[i];
    codes[i] = c >= 0x80 && c < 0xA0 ? _cp1252High[c - 0x80] : c;
  }
  return String.fromCharCodes(codes);
}
