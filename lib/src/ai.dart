import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'settings.dart';
import 'text_utils.dart';

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

Future<String> _gemini(Settings s, String system, String user, {bool json = false}) async {
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
          if (json) 'generationConfig': {'responseMimeType': 'application/json'},
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

/// Asks the chosen AI for a JSON object and decodes it.
Future<Map<String, dynamic>> askJson(Settings s, String system, String user) async {
  final raw = s.aiProvider == 'claude' ? await _claude(s, system, user) : await _gemini(s, system, user, json: true);
  final a = raw.indexOf('{'), b = raw.lastIndexOf('}');
  if (a < 0 || b <= a) throw AiException('The model did not return the expected data.');
  try {
    return Map<String, dynamic>.from(jsonDecode(raw.substring(a, b + 1)) as Map);
  } catch (_) {
    throw AiException('The model did not return the expected data.');
  }
}

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

/// Gemini 3.8 and later TTS models read the text strictly as a transcript (a style written in front
/// of it would be spoken), take the reading style as separate speech metadata, and return WAV
/// instead of raw PCM. Older models (2.x, 3.0, 3.1) use the inline style and raw PCM.
bool geminiTtsUsesMetadata(String model) => !RegExp(r'gemini-(1\.|2\.|3\.[01](\D|$))').hasMatch(model);

/// Request body for a Gemini TTS call, in the right form for the model.
Map<String, Object?> geminiSpeechBody(String model, String text, String style, String voice) {
  final st = style.trim();
  final Map<String, Object?> part = geminiTtsUsesMetadata(model)
      ? {
          'text': text,
          if (st.isNotEmpty) 'speech_metadata': {'style': st.replaceFirst(RegExp(r'[:\s]+$'), '')},
        }
      : {'text': st.isEmpty ? text : '$st\n\n$text'};
  return {
    'contents': [
      {
        'parts': [part]
      }
    ],
    'generationConfig': {
      'responseModalities': ['AUDIO'],
      'speechConfig': {
        'voiceConfig': {
          'prebuiltVoiceConfig': {'voiceName': voice}
        }
      },
    },
  };
}

/// Turns Gemini's inline audio into 16-bit PCM and its sample rate, whether it came as WAV or raw PCM.
(Uint8List, int) geminiAudioToPcm(Uint8List bytes, String mimeType) {
  final isWav = mimeType.contains('wav') || (bytes.length > 12 && String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF');
  if (isWav) {
    final w = parseWav(bytes);
    if (w == null) throw AiException('Gemini returned audio in an unexpected format.');
    return (w.pcm, w.sampleRate);
  }
  final rate = int.tryParse(RegExp(r'rate=(\d+)').firstMatch(mimeType)?.group(1) ?? '') ?? 24000;
  return (bytes, rate);
}

/// Synthesises speech with a Gemini TTS model. Returns 16-bit mono PCM and its sample rate.
Future<(Uint8List, int)> geminiSpeech(Settings s, String text) async {
  if (s.geminiKey.isEmpty) throw AiException('Add your Gemini API key in Settings → AI.');
  final r = await http
      .post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/${s.cloudTtsModel}:generateContent'),
        headers: {'x-goog-api-key': s.geminiKey, 'content-type': 'application/json'},
        body: jsonEncode(geminiSpeechBody(s.cloudTtsModel, text, s.cloudTtsStyle, s.cloudTtsVoice)),
      )
      .timeout(const Duration(minutes: 5));
  if (r.statusCode != 200) throw AiException(_errorOf(r));
  final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map;
  final parts = (((j['candidates'] as List?)?.firstOrNull as Map?)?['content'] as Map?)?['parts'] as List?;
  for (final part in parts ?? const []) {
    final inline = (part as Map)['inlineData'] as Map?;
    if (inline != null && inline['data'] is String) {
      return geminiAudioToPcm(base64.decode(inline['data'] as String), '${inline['mimeType'] ?? ''}');
    }
  }
  throw AiException('The model returned no audio.');
}
