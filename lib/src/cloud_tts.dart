import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'ai.dart';
import 'settings.dart';
import 'text_utils.dart';

/// Voice sources for narration.
const voiceDevice = 'device', voiceGoogle = 'google', voiceGemini = 'gemini';

String voiceSourceLabel(String s) => switch (s) {
      voiceGoogle => 'Google Cloud',
      voiceGemini => 'Gemini',
      _ => 'Phone',
    };

/// Kinds of Google Cloud voices, roughly from most to least natural.
const googleVoiceKinds = ['Chirp3-HD', 'Chirp-HD', 'Studio', 'Neural2', 'WaveNet', 'Standard'];

String googleVoiceKind(String name) {
  for (final k in googleVoiceKinds) {
    if (name.contains('-$k-')) return k;
  }
  return 'Other';
}

class GoogleVoice {
  final String name, gender;
  final List<String> languages;
  GoogleVoice(this.name, this.gender, this.languages);
  String get kind => googleVoiceKind(name);
  String get language => languages.isEmpty ? name.split('-').take(2).join('-') : languages.first;
}

String _googleKey(Settings s) => s.googleTtsKey.isNotEmpty ? s.googleTtsKey : s.geminiKey;

String _err(http.Response r) {
  try {
    final j = jsonDecode(r.body);
    final m = j is Map && j['error'] is Map ? j['error']['message'] : null;
    if (m != null) {
      final msg = '$m';
      if (msg.contains('has not been used') || msg.contains('is disabled')) {
        return 'The Cloud Text-to-Speech API is not turned on for this key\'s Google Cloud project. '
            'Enable it at console.cloud.google.com → APIs & Services → Library.';
      }
      return '${r.statusCode}: $msg';
    }
  } catch (_) {}
  return 'Request failed (${r.statusCode}).';
}

/// Lists Google Cloud voices for a language such as "en-US" (empty = all languages).
Future<List<GoogleVoice>> googleVoices(Settings s, {String language = ''}) async {
  final key = _googleKey(s);
  if (key.isEmpty) throw AiException('Add a Google Cloud API key in Settings → Voices.');
  final r = await http
      .get(Uri.parse('https://texttospeech.googleapis.com/v1/voices${language.isEmpty ? '' : '?languageCode=$language'}'),
          headers: {'x-goog-api-key': key})
      .timeout(const Duration(seconds: 30));
  if (r.statusCode != 200) throw AiException(_err(r));
  final list = ((jsonDecode(r.body) as Map)['voices'] as List? ?? [])
      .map((v) => GoogleVoice('${v['name']}', '${v['ssmlGender'] ?? ''}', ((v['languageCodes'] as List?) ?? []).map((e) => '$e').toList()))
      .toList();
  list.sort((a, b) {
    final k = googleVoiceKinds.indexOf(a.kind).compareTo(googleVoiceKinds.indexOf(b.kind));
    return k != 0 ? k : a.name.compareTo(b.name);
  });
  return list;
}

/// Speech from Google Cloud Text-to-Speech as MP3 bytes. Text must stay under 5000 bytes.
Future<Uint8List> googleSpeech(Settings s, String text, {String? voice}) async {
  final key = _googleKey(s);
  if (key.isEmpty) throw AiException('Add a Google Cloud API key in Settings → Voices.');
  final name = voice ?? s.googleVoice;
  final lang = name.split('-').take(2).join('-');
  final r = await http
      .post(
        Uri.parse('https://texttospeech.googleapis.com/v1/text:synthesize'),
        headers: {'x-goog-api-key': key, 'content-type': 'application/json'},
        body: jsonEncode({
          'input': {'text': text},
          'voice': {'languageCode': lang, 'name': name},
          'audioConfig': {'audioEncoding': 'MP3'},
        }),
      )
      .timeout(const Duration(seconds: 60));
  if (r.statusCode != 200) throw AiException(_err(r));
  final b64 = (jsonDecode(r.body) as Map)['audioContent'] as String?;
  if (b64 == null || b64.isEmpty) throw AiException('Google returned no audio.');
  return base64.decode(b64);
}

/// The Google voice for a character: the narrator's Chirp 3 HD voice with the character's voice name,
/// e.g. en-US-Chirp3-HD-Algenib + Orus → en-US-Chirp3-HD-Orus.
String googleCharacterVoice(Settings s, String voice) =>
    s.googleVoice.replaceFirst(RegExp(r'-Chirp3-HD-[A-Za-z]+$'), '-Chirp3-HD-$voice');

/// The voice used for a cloud source, used to keep cached audio apart per voice. [voice] is a
/// character's voice name (null = the narrator) and [style] its reading style.
String cloudVoiceId(Settings s, String source, {String? voice, String style = ''}) => source == voiceGoogle
    ? (voice == null ? s.googleVoice : googleCharacterVoice(s, voice))
    : voice == null
        ? '${s.cloudTtsModel}/${s.cloudTtsVoice}/${s.cloudTtsStyle}'
        : '${s.cloudTtsModel}/$voice/$style';

String _cacheKey(Settings s, String source, String text, String? voice, String style) =>
    sha1.convert(utf8.encode('$source|${cloudVoiceId(s, source, voice: voice, style: style)}|$text')).toString();

Directory? _cacheDir;
int _writesSinceTrim = 0;

/// Saved voice audio lives in the app's own storage (not the cache folder Android may empty when space
/// is low), so chapters made ready for offline listening stay ready. The old cache folder is removed.
Future<Directory> _voiceDir() async {
  if (_cacheDir != null) return _cacheDir!;
  _cacheDir = Directory(p.join((await getApplicationSupportDirectory()).path, 'voice_cache'));
  try {
    final old = Directory(p.join((await getTemporaryDirectory()).path, 'voice_cache'));
    if (await old.exists()) await old.delete(recursive: true);
  } catch (_) {}
  return _cacheDir!;
}

/// The saved audio for a piece, if it has been fetched before (no internet needed).
Future<File?> cachedCloudAudio(Settings s, String source, String text, {String? voice, String style = ''}) async {
  final f = File(p.join((await _voiceDir()).path, '${_cacheKey(s, source, text, voice, style)}.${source == voiceGoogle ? 'mp3' : 'wav'}'));
  return await f.exists() && await f.length() > 0 ? f : null;
}

/// Audio for [text] from a cloud voice, as a playable file (MP3 for Google, WAV for Gemini).
/// Results are cached on disk, so replaying a passage costs nothing.
/// [voice] and [style] give a character's voice instead of the narrator's.
Future<File> cloudAudioFile(Settings s, String source, String text, {String? voice, String style = ''}) async {
  await _voiceDir();
  await _cacheDir!.create(recursive: true);
  final ext = source == voiceGoogle ? 'mp3' : 'wav';
  final f = File(p.join(_cacheDir!.path, '${_cacheKey(s, source, text, voice, style)}.$ext'));
  if (await f.exists() && await f.length() > 0) return f;
  final Uint8List bytes;
  if (source == voiceGoogle) {
    bytes = await googleSpeech(s, text, voice: voice == null ? null : googleCharacterVoice(s, voice));
  } else {
    final (pcm, rate) = await geminiSpeech(s, text, voice: voice, style: voice == null ? null : style);
    bytes = pcmToWav(pcm, rate);
  }
  final tmp = File('${f.path}.part');
  await tmp.writeAsBytes(bytes, flush: true);
  await tmp.rename(f.path);
  if (++_writesSinceTrim >= 25) {
    _writesSinceTrim = 0;
    trimVoiceCache();
  }
  return f;
}

/// Keeps the voice cache under [maxBytes] by deleting the oldest files.
Future<void> trimVoiceCache({int maxBytes = 1500 * 1024 * 1024}) async {
  final d = _cacheDir;
  if (d == null || !await d.exists()) return;
  final files = d.listSync().whereType<File>().toList()
    ..sort((a, b) => a.statSync().modified.compareTo(b.statSync().modified));
  var total = files.fold<int>(0, (n, f) => n + f.lengthSync());
  for (final f in files) {
    if (total <= maxBytes) break;
    total -= f.lengthSync();
    try {
      f.deleteSync();
    } catch (_) {}
  }
}

Future<int> voiceCacheSize() async {
  await _voiceDir();
  if (!await _cacheDir!.exists()) return 0;
  return _cacheDir!.listSync().whereType<File>().fold<int>(0, (n, f) => n + f.lengthSync());
}

Future<void> clearVoiceCache() async {
  if (_cacheDir != null && await _cacheDir!.exists()) await _cacheDir!.delete(recursive: true);
}

/// Groups paragraphs into cloud-sized pieces: whole paragraphs where possible, so a voice keeps
/// its flow, while staying well inside the request limits.
List<SpeechChunk> cloudChunks(List<String> paras, {int maxLen = 1400}) {
  final raw = speechChunks(paras, maxLen: maxLen);
  final out = <SpeechChunk>[];
  for (final c in raw) {
    // Merge very short paragraphs (dialogue lines) into the previous piece to avoid many tiny requests.
    final last = out.isEmpty ? null : out.last;
    if (last != null && last.para >= 0 && c.para >= 0 && c.start == 0 && last.voice == c.voice &&
        last.text.length + c.text.length < 380 && c.text.length < 160) {
      out[out.length - 1] =
          SpeechChunk(last.para, last.start, last.end, '${last.text}\n${c.text}', lastPara: c.para, voice: last.voice, style: last.style);
    } else {
      out.add(c);
    }
  }
  return out;
}

/// Plain-language version of a cloud voice error.
String friendlyCloudError(Object e, String source) {
  final m = '$e'.replaceFirst('AiException: ', '').replaceFirst('Exception: ', '');
  final label = voiceSourceLabel(source);
  if (m.contains('402') || m.contains('prepayment') || m.toLowerCase().contains('credits')) {
    return 'Your $label credits have run out. Add credits at ai.studio/projects (Billing), or choose another voice.';
  }
  if (m.contains('429') || m.contains('RESOURCE_EXHAUSTED') || m.toLowerCase().contains('quota')) {
    return 'The $label voice is over its usage limit for now. Try again later or choose another voice.';
  }
  if (m.contains('401') || m.contains('403') || m.contains('API key not valid') || m.contains('PERMISSION_DENIED')) {
    return 'The $label key was refused. Check the key and its restrictions in Settings.';
  }
  return m;
}

/// Removes the saved natural-voice audio of a chapter (current Google and Gemini voices), so deleting
/// a chapter also frees its audio. Audio made with voices chosen earlier is cleared by the size limit.
Future<int> deleteChapterAudio(Settings s, String title, List<String> texts) async {
  await _voiceDir();
  if (!await _cacheDir!.exists()) return 0;
  final pieces = <String>{title, '$title.'};
  for (final t in texts) {
    if (t.isEmpty) continue;
    for (final c in cloudChunks(splitParas(t))) {
      pieces.add(c.text);
    }
  }
  var n = 0;
  for (final source in [voiceGoogle, voiceGemini]) {
    for (final piece in pieces) {
      if (await deleteCachedPiece(s, source, piece)) n++;
    }
  }
  return n;
}

/// Deletes one saved piece of audio. [text] is the piece before word replacements.
Future<bool> deleteCachedPiece(Settings s, String source, String text, {String? voice, String style = ''}) async {
  await _voiceDir();
  final ext = source == voiceGoogle ? 'mp3' : 'wav';
  final f = File(p.join(_cacheDir!.path, '${_cacheKey(s, source, applyReplacements(text, s.replacements), voice, style)}.$ext'));
  if (!await f.exists()) return false;
  await f.delete();
  return true;
}
