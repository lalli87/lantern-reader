import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'settings.dart';

class AiException implements Exception {
  final String message;
  AiException(this.message);
  @override
  String toString() => message;
}

const _timeout = Duration(seconds: 120);

String _errorOf(http.Response r) {
  try {
    final j = jsonDecode(r.body);
    final m = j is Map ? (j['error'] is Map ? j['error']['message'] : j['error']) : null;
    if (m != null) return '${r.statusCode}: $m';
  } catch (_) {}
  return 'Request failed (${r.statusCode}).';
}

Future<String> _gemini(Settings s, String system, String user) async {
  if (s.geminiKey.isEmpty) throw AiException('Add your Gemini API key in Settings → AI.');
  final r = await http
      .post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/${s.geminiModel}:generateContent'),
        headers: {'x-goog-api-key': s.geminiKey, 'content-type': 'application/json'},
        body: jsonEncode({
          'systemInstruction': {
            'parts': [
              {'text': system}
            ]
          },
          'contents': [
            {
              'role': 'user',
              'parts': [
                {'text': user}
              ]
            }
          ],
        }),
      )
      .timeout(_timeout);
  if (r.statusCode != 200) throw AiException(_errorOf(r));
  final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map;
  final parts = (((j['candidates'] as List?)?.firstOrNull as Map?)?['content'] as Map?)?['parts'] as List?;
  final text = (parts ?? []).map((e) => (e as Map)['text'] ?? '').join();
  if (text.isEmpty) throw AiException('The model returned no text.');
  return text;
}

Future<String> _claude(Settings s, String system, String user) async {
  if (s.claudeKey.isEmpty) throw AiException('Add your Claude API key in Settings → AI.');
  final r = await http
      .post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {'x-api-key': s.claudeKey, 'anthropic-version': '2023-06-01', 'content-type': 'application/json'},
        body: jsonEncode({
          'model': s.claudeModel,
          'max_tokens': 16000,
          'system': system,
          'messages': [
            {'role': 'user', 'content': user}
          ],
        }),
      )
      .timeout(_timeout);
  if (r.statusCode != 200) throw AiException(_errorOf(r));
  final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map;
  final text = ((j['content'] as List?) ?? []).map((e) => (e as Map)['text'] ?? '').join();
  if (text.isEmpty) throw AiException('The model returned no text.');
  return text;
}

Future<String> _ask(Settings s, String system, String user) =>
    s.aiProvider == 'claude' ? _claude(s, system, user) : _gemini(s, system, user);

/// Groups paragraphs into batches of roughly [maxChars] for translation.
List<List<String>> batchParagraphs(List<String> paras, {int maxChars = 6000}) {
  final out = <List<String>>[];
  var cur = <String>[], n = 0;
  for (final p in paras) {
    if (cur.isNotEmpty && n + p.length > maxChars) {
      out.add(cur);
      cur = [];
      n = 0;
    }
    cur.add(p);
    n += p.length;
  }
  if (cur.isNotEmpty) out.add(cur);
  return out;
}

/// Translates paragraphs, keeping one output line per input line so headings and positions survive.
Future<List<String>> translateParagraphs(Settings s, List<String> paras, {void Function(double)? onProgress}) async {
  final system = 'You are a literary translator. Translate the text into ${s.targetLang}. '
      'The input has one paragraph per line. Return exactly one line per input line, in the same order, '
      'with no blank lines, numbering, or commentary. Keep any leading "#" heading markers unchanged. '
      'Keep names consistent and the tone natural.';
  final out = <String>[];
  final batches = batchParagraphs(paras);
  for (var i = 0; i < batches.length; i++) {
    final res = await _ask(s, system, batches[i].join('\n'));
    final lines = res.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    out.addAll(lines);
    onProgress?.call((i + 1) / batches.length);
  }
  return out;
}

/// Translates or explains a short selection.
Future<String> translateSnippet(Settings s, String text) => _ask(
    s,
    'Translate the user\'s text into ${s.targetLang}. If it is already in ${s.targetLang}, explain its meaning '
        'briefly instead. Reply with the result only.',
    text);

/// Synthesises speech with a Gemini TTS model. Returns 16-bit mono PCM and its sample rate.
Future<(Uint8List, int)> geminiSpeech(Settings s, String text) async {
  if (s.geminiKey.isEmpty) throw AiException('Add your Gemini API key in Settings → AI.');
  final prompt = s.cloudTtsStyle.trim().isEmpty ? text : '${s.cloudTtsStyle.trim()}\n\n$text';
  final r = await http
      .post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/${s.cloudTtsModel}:generateContent'),
        headers: {'x-goog-api-key': s.geminiKey, 'content-type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'responseModalities': ['AUDIO'],
            'speechConfig': {
              'voiceConfig': {
                'prebuiltVoiceConfig': {'voiceName': s.cloudTtsVoice}
              }
            },
          },
        }),
      )
      .timeout(const Duration(minutes: 5));
  if (r.statusCode != 200) throw AiException(_errorOf(r));
  final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map;
  final parts = (((j['candidates'] as List?)?.firstOrNull as Map?)?['content'] as Map?)?['parts'] as List?;
  for (final part in parts ?? const []) {
    final inline = (part as Map)['inlineData'] as Map?;
    if (inline != null && inline['data'] is String) {
      final rate = int.tryParse(RegExp(r'rate=(\d+)').firstMatch('${inline['mimeType']}')?.group(1) ?? '') ?? 24000;
      return (base64.decode(inline['data'] as String), rate);
    }
  }
  throw AiException('The model returned no audio.');
}
