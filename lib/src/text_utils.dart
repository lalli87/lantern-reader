import 'dart:typed_data';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

/// Chapter text is stored as one paragraph per line. A line that starts with one to three '#'
/// followed by a space is a heading.
final _headingRe = RegExp(r'^(#{1,3}) ');

int headingLevel(String p) => _headingRe.firstMatch(p)?.group(1)?.length ?? 0;
String paraText(String p) => p.replaceFirst(_headingRe, '');
List<String> splitParas(String content) => content.isEmpty ? <String>[] : content.split('\n');

String _clean(String s) => s.replaceAll(RegExp(r'[\s ​﻿]+'), ' ').trim();

const _skipTags = {'script', 'style', 'noscript', 'iframe', 'svg', 'form', 'button', 'nav', 'head', 'template', 'select', 'input', 'video', 'audio', 'canvas', 'object'};
const _blockTags = {
  'p', 'div', 'section', 'article', 'li', 'blockquote', 'pre', 'tr', 'ul', 'ol', 'table', 'header', 'footer',
  'figure', 'figcaption', 'dd', 'dt', 'dl', 'main', 'aside', 'address', 'center', 'body', 'html', 'td', 'th',
};

/// Flattens an HTML fragment into paragraphs, marking h1..h6 as headings.
List<String> htmlToParagraphs(String html) {
  final doc = html_parser.parse(html);
  final out = <String>[];
  final buf = StringBuffer();

  void flush([int level = 0]) {
    final t = _clean(buf.toString());
    buf.clear();
    if (t.isEmpty) return;
    out.add(level > 0 ? '${'#' * level.clamp(1, 3)} $t' : t);
  }

  void walk(dom.Node n) {
    if (n is dom.Text) {
      buf.write(n.text);
      return;
    }
    if (n is! dom.Element) {
      n.nodes.forEach(walk);
      return;
    }
    final tag = n.localName ?? '';
    if (_skipTags.contains(tag)) return;
    if (tag == 'br' || tag == 'hr') {
      flush();
      return;
    }
    final m = RegExp(r'^h([1-6])$').firstMatch(tag);
    if (m != null) {
      flush();
      n.nodes.forEach(walk);
      flush(int.parse(m.group(1)!));
      return;
    }
    final block = _blockTags.contains(tag);
    if (block) flush();
    n.nodes.forEach(walk);
    if (block) flush();
  }

  walk(doc.documentElement ?? doc);
  flush();
  return out;
}

/// Plain text (pasted, .txt) into paragraphs: blank-line or single-line separated.
List<String> plainToParagraphs(String text) {
  final t = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  return t.split('\n').map(_clean).where((l) => l.isNotEmpty).toList();
}

/// A unit handed to the speech engine: a whole paragraph, or a slice of a long one.
class SpeechChunk {
  final int para; // -1 for a spoken chapter title
  final int start, end; // offsets inside the paragraph's display text
  final String text;
  final int lastPara; // last paragraph covered when short paragraphs are merged
  /// Character voice for this piece (a Gemini / Chirp 3 HD voice name); null = the narrator.
  final String? voice;
  /// Reading style for a character's piece (Gemini only).
  final String style;
  const SpeechChunk(this.para, this.start, this.end, this.text, {int? lastPara, this.voice, this.style = ''})
      : lastPara = lastPara ?? para;
}

final _sentenceEnd = RegExp(r'''[.!?…。！？]+["'”’)\]]*\s+''');

/// Splits paragraphs into chunks no longer than [maxLen], cutting at sentence ends.
List<SpeechChunk> speechChunks(List<String> paras, {int maxLen = 900, int from = 0}) {
  final out = <SpeechChunk>[];
  for (var i = from; i < paras.length; i++) {
    final t = paraText(paras[i]);
    if (t.trim().isEmpty) continue;
    if (t.length <= maxLen) {
      out.add(SpeechChunk(i, 0, t.length, t));
      continue;
    }
    var start = 0;
    while (start < t.length) {
      var end = t.length;
      if (end - start > maxLen) {
        end = start + maxLen;
        // Prefer the last sentence end inside the window, then the last space.
        var cut = -1;
        for (final m in _sentenceEnd.allMatches(t.substring(start, end))) {
          cut = start + m.end;
        }
        if (cut <= start) {
          final sp = t.lastIndexOf(' ', end);
          cut = sp > start ? sp + 1 : end;
        }
        end = cut;
      }
      out.add(SpeechChunk(i, start, end, t.substring(start, end)));
      start = end;
    }
  }
  return out;
}

/// Start of the sentence containing [offset], for resuming mid-chunk.
int sentenceStartBefore(String text, int offset) {
  var s = 0;
  for (final m in _sentenceEnd.allMatches(text)) {
    if (m.end > offset) break;
    s = m.end;
  }
  return s;
}

/// Applies pronunciation fixes. Each rule is [from, to]; matching ignores case and respects
/// word boundaries when [from] is a plain word.
String applyReplacements(String text, List<List<String>> rules) {
  var t = text;
  for (final r in rules) {
    if (r.length < 2 || r[0].isEmpty) continue;
    final plain = RegExp(r'^[\w\s]+$').hasMatch(r[0]);
    final re = RegExp(plain ? '\\b${RegExp.escape(r[0])}\\b' : RegExp.escape(r[0]), caseSensitive: false);
    t = t.replaceAll(re, r[1]);
  }
  return t;
}

String safeFileName(String s) {
  final t = s.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  return t.isEmpty ? 'untitled' : (t.length > 80 ? t.substring(0, 80).trim() : t);
}

String fmtSize(int bytes) {
  if (bytes <= 0) return '';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} kB';
  return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
}

/// Rough listening time at normal speed (about 15 characters per second for English).
String fmtListenTime(int chars, {double rate = 1}) {
  final mins = (chars / 15 / 60 / rate).round();
  if (mins < 1) return '<1 min';
  if (mins < 60) return '$mins min';
  return '${mins ~/ 60} h ${mins % 60} min';
}

String fmtDate(int ms) {
  if (ms <= 0) return '';
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  const mo = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${mo[d.month - 1]} ${d.day}, ${d.year}';
}

// ---- WAV helpers (for audio export) ----

class WavData {
  final int sampleRate, channels, bits;
  final Uint8List pcm;
  WavData(this.sampleRate, this.channels, this.bits, this.pcm);
}

/// Reads a PCM WAV file, tolerating extra chunks before 'data'.
WavData? parseWav(Uint8List b) {
  if (b.length < 44) return null;
  final d = ByteData.sublistView(b);
  String tag(int o) => String.fromCharCodes(b.sublist(o, o + 4));
  if (tag(0) != 'RIFF' || tag(8) != 'WAVE') return null;
  var o = 12;
  int rate = 22050, ch = 1, bits = 16;
  while (o + 8 <= b.length) {
    final id = tag(o);
    var size = d.getUint32(o + 4, Endian.little);
    final body = o + 8;
    if (id == 'fmt ' && body + 16 <= b.length) {
      ch = d.getUint16(body + 2, Endian.little);
      rate = d.getUint32(body + 4, Endian.little);
      bits = d.getUint16(body + 14, Endian.little);
    } else if (id == 'data') {
      // Engines that stream to a file sometimes leave the size as 0 or 0xFFFFFFFF.
      if (size == 0 || body + size > b.length) size = b.length - body;
      return WavData(rate, ch, bits, Uint8List.sublistView(b, body, body + size));
    }
    o = body + size + (size & 1);
  }
  return null;
}

Uint8List pcmToWav(Uint8List pcm, int sampleRate, {int channels = 1, int bits = 16}) {
  final out = Uint8List(44 + pcm.length);
  final d = ByteData.sublistView(out);
  void tag(int o, String s) => out.setRange(o, o + 4, s.codeUnits);
  final byteRate = sampleRate * channels * bits ~/ 8;
  tag(0, 'RIFF');
  d.setUint32(4, 36 + pcm.length, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  d.setUint32(16, 16, Endian.little);
  d.setUint16(20, 1, Endian.little);
  d.setUint16(22, channels, Endian.little);
  d.setUint32(24, sampleRate, Endian.little);
  d.setUint32(28, byteRate, Endian.little);
  d.setUint16(32, channels * bits ~/ 8, Endian.little);
  d.setUint16(34, bits, Endian.little);
  tag(36, 'data');
  d.setUint32(40, pcm.length, Endian.little);
  out.setRange(44, out.length, pcm);
  return out;
}

/// Joins WAV files that share a format into one. Returns null if nothing usable was given.
Uint8List? mergeWavs(List<Uint8List> files) {
  final parts = files.map(parseWav).whereType<WavData>().toList();
  if (parts.isEmpty) return null;
  final first = parts.first;
  final bb = BytesBuilder(copy: false);
  for (final p in parts) {
    if (p.sampleRate == first.sampleRate && p.channels == first.channels && p.bits == first.bits) bb.add(p.pcm);
  }
  return pcmToWav(bb.toBytes(), first.sampleRate, channels: first.channels, bits: first.bits);
}
