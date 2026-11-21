import 'dart:convert';

import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;

import 'ai.dart';
import 'db.dart';
import 'models.dart';
import 'settings.dart';
import 'text_utils.dart';

/// One character in a book's cast. The cast belongs to the book, so it survives deleting chapters.
class CastMember {
  int? id;
  int bookId, lines, createdAt;
  String name, gender, age, style;
  String? voice; // null = read with the narrator's voice
  List<String> aliases;
  bool userSet; // the user chose the voice/details; analysis won't overwrite them

  CastMember({
    this.id,
    required this.bookId,
    required this.name,
    this.aliases = const [],
    this.gender = 'unknown',
    this.age = 'unknown',
    this.voice,
    this.style = '',
    this.lines = 0,
    this.userSet = false,
    int? createdAt,
  }) : createdAt = createdAt ?? nowMs();

  factory CastMember.fromMap(Map<String, Object?> m) => CastMember(
        id: m['id'] as int?,
        bookId: m['book_id'] as int,
        name: m['name'] as String? ?? '',
        aliases: _list(m['aliases']),
        gender: m['gender'] as String? ?? 'unknown',
        age: m['age'] as String? ?? 'unknown',
        voice: m['voice'] as String?,
        style: m['style'] as String? ?? '',
        lines: m['lines'] as int? ?? 0,
        userSet: (m['user_set'] as int? ?? 0) != 0,
        createdAt: m['created_at'] as int? ?? 0,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'book_id': bookId,
        'name': name,
        'aliases': jsonEncode(aliases),
        'gender': gender,
        'age': age,
        'voice': voice,
        'style': style,
        'lines': lines,
        'user_set': userSet ? 1 : 0,
        'created_at': createdAt,
      };

  static List<String> _list(Object? v) {
    try {
      return List<String>.from(jsonDecode('${v ?? '[]'}') as List);
    } catch (_) {
      return [];
    }
  }

  bool matches(String n) {
    final k = _norm(n);
    return k.isNotEmpty && (_norm(name) == k || aliases.any((a) => _norm(a) == k));
  }
}

String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ').trim();

// ---- storage ----

class Cast {
  static Future<List<CastMember>> of(int bookId) async =>
      (await Db.db.query('characters', where: 'book_id=?', whereArgs: [bookId], orderBy: 'lines DESC, name COLLATE NOCASE'))
          .map(CastMember.fromMap)
          .toList();

  static Future<void> save(CastMember c) async {
    if (c.id == null) {
      c.id = await Db.db.insert('characters', c.toMap());
    } else {
      await Db.db.update('characters', c.toMap(), where: 'id=?', whereArgs: [c.id]);
    }
  }

  static Future<void> delete(int id) => Db.db.delete('characters', where: 'id=?', whereArgs: [id]);

  /// Who speaks each paragraph of a chapter: {paragraph index: character id}. Null if not analysed yet.
  static Future<Map<int, int>?> speakers(int chapterId) async {
    final r = await Db.db.query('chapter_speakers', where: 'chapter_id=?', whereArgs: [chapterId]);
    if (r.isEmpty) return null;
    try {
      final m = jsonDecode(r.first['data'] as String) as Map;
      return {for (final e in m.entries) int.parse('${e.key}'): (e.value as num).toInt()};
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveSpeakers(int chapterId, Map<int, int> map) => Db.db.insert(
        'chapter_speakers',
        {'chapter_id': chapterId, 'data': jsonEncode({for (final e in map.entries) '${e.key}': e.value}), 'created_at': nowMs()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  /// Ids of a book's chapters that already have speaker labels.
  static Future<Set<int>> analysedChapters(int bookId) async => (await Db.db.rawQuery(
          'SELECT s.chapter_id FROM chapter_speakers s JOIN chapters c ON c.id = s.chapter_id WHERE c.book_id=?', [bookId]))
      .map((e) => e['chapter_id'] as int)
      .toSet();
}

// ---- voices ----

/// Gemini's prebuilt voices by how they sound. Google Cloud's Chirp 3 HD voices use the same names.
const femaleVoices = [
  'Kore', 'Aoede', 'Leda', 'Zephyr', 'Callirrhoe', 'Autonoe', 'Despina', 'Erinome', 'Laomedeia', 'Achernar',
  'Gacrux', 'Pulcherrima', 'Vindemiatrix', 'Sulafat',
];
const maleVoices = [
  'Charon', 'Puck', 'Fenrir', 'Orus', 'Enceladus', 'Iapetus', 'Umbriel', 'Algieba', 'Algenib', 'Rasalgethi',
  'Alnilam', 'Schedar', 'Achird', 'Zubenelgenubi', 'Sadachbia', 'Sadaltager',
];
const _olderVoices = {'female': ['Gacrux', 'Vindemiatrix', 'Sulafat'], 'male': ['Algenib', 'Rasalgethi', 'Schedar']};
const _youngerVoices = {'female': ['Leda', 'Zephyr', 'Despina'], 'male': ['Puck', 'Fenrir', 'Achird']};

const castGenders = ['male', 'female', 'unknown'];
const castAges = ['child', 'teen', 'young adult', 'adult', 'elderly', 'unknown'];

String voiceGender(String voice) => femaleVoices.contains(voice) ? 'female' : (maleVoices.contains(voice) ? 'male' : 'unknown');

/// A short delivery note for a character's age, used as the reading style for their lines.
String styleForAge(String age) => switch (age) {
      'child' => 'a young child',
      'teen' => 'a teenager',
      'elderly' => 'elderly, slow and weathered',
      _ => '',
    };

/// Picks a voice that fits gender and age, preferring voices no other character uses yet and never
/// the narrator's. Unknown gender keeps the narrator's voice (null).
String? pickVoice(String gender, String age, List<CastMember> cast, String narrator) {
  if (gender != 'male' && gender != 'female') return null;
  final pool = gender == 'female' ? femaleVoices : maleVoices;
  final preferred = age == 'elderly'
      ? _olderVoices[gender]!
      : (age == 'child' || age == 'teen' || age == 'young adult' ? _youngerVoices[gender]! : const <String>[]);
  final use = <String, int>{};
  for (final c in cast) {
    if (c.voice != null) use[c.voice!] = (use[c.voice!] ?? 0) + 1;
  }
  String? best;
  var bestScore = 1 << 30;
  for (final v in pool) {
    if (v == narrator) continue;
    // Fewest characters sharing it first; a matching age is worth one shared use.
    final score = (use[v] ?? 0) * 2 - (preferred.contains(v) ? 1 : 0);
    if (score < bestScore) {
      best = v;
      bestScore = score;
    }
  }
  return best;
}

// ---- analysis ----

final _dialogue = RegExp(r'["“”„«»「」『』]');

bool hasDialogue(String para) => _dialogue.hasMatch(para);

const _system = '''You label who speaks the dialogue in a chapter of a novel, so an audiobook can give each character their own voice.
The chapter is given as numbered paragraphs like "[12] text". Known characters from earlier chapters are listed first.
Return JSON only, in this form:
{"characters":[{"name":"...","aliases":["..."],"gender":"male|female|unknown","age":"child|teen|young adult|adult|elderly|unknown"}],
 "lines":[{"p":12,"speaker":"..."}]}
Rules:
- "lines": one entry for every paragraph that contains spoken dialogue (words in quotation marks said aloud). Skip pure narration.
- "speaker": the name of the character whose words are quoted in that paragraph. Use the same name as in "characters".
  If a paragraph quotes several people, give the main speaker. If you truly cannot tell, use "unknown".
- "characters": every character who speaks in this chapter. Reuse the exact names of known characters; put nicknames,
  titles and other ways the text refers to them in "aliases" (for example "Senior Brother", "the old man").
- Judge gender and age from the text (pronouns, titles, descriptions). Use "unknown" when it is not clear.''';

class AnalysisResult {
  final int lines, newCharacters;
  AnalysisResult(this.lines, this.newCharacters);
}

/// Splits paragraphs into numbered batches of about [maxChars], so very long chapters fit one request.
List<List<int>> analysisBatches(List<String> paras, {int maxChars = 40000}) {
  final out = <List<int>>[];
  var cur = <int>[], n = 0;
  for (var i = 0; i < paras.length; i++) {
    if (cur.isNotEmpty && n + paras[i].length > maxChars) {
      out.add(cur);
      cur = [];
      n = 0;
    }
    cur.add(i);
    n += paras[i].length;
  }
  if (cur.isNotEmpty) out.add(cur);
  return out;
}

/// Adds what the model found to the cast (new characters get a voice that fits) and returns the
/// paragraph → character id map. Characters the user has edited are left as they are.
Future<(Map<int, int>, int)> mergeAnalysis(int bookId, Map<String, dynamic> data, String narratorVoice, {int paraCount = 1 << 30}) async {
  final cast = await Cast.of(bookId);
  var added = 0;
  CastMember? find(String n) => cast.where((c) => c.matches(n)).firstOrNull;

  Future<CastMember> ensure(String name, {List<String> aliases = const [], String gender = 'unknown', String age = 'unknown'}) async {
    var c = find(name) ?? aliases.map(find).whereType<CastMember>().firstOrNull;
    final g = castGenders.contains(gender) ? gender : 'unknown';
    final a = castAges.contains(age) ? age : 'unknown';
    if (c == null) {
      c = CastMember(bookId: bookId, name: name, aliases: aliases.where((x) => _norm(x) != _norm(name)).toSet().toList(), gender: g, age: a);
      c.voice = pickVoice(g, a, cast, narratorVoice);
      c.style = styleForAge(a);
      cast.add(c);
      added++;
    } else {
      final known = {_norm(c.name), ...c.aliases.map(_norm)};
      final extra = [name, ...aliases].where((x) => x.trim().isNotEmpty && !known.contains(_norm(x))).toSet();
      if (extra.isNotEmpty) c.aliases = [...c.aliases, ...extra];
      if (!c.userSet) {
        final gotGender = c.gender == 'unknown' && g != 'unknown';
        if (gotGender) c.gender = g;
        if (c.age == 'unknown' && a != 'unknown') {
          c.age = a;
          c.style = styleForAge(a);
        }
        if (gotGender && c.voice == null) c.voice = pickVoice(c.gender, c.age, cast, narratorVoice);
      }
    }
    await Cast.save(c);
    return c;
  }

  for (final raw in (data['characters'] as List? ?? const [])) {
    if (raw is! Map) continue;
    final name = '${raw['name'] ?? ''}'.trim();
    if (name.isEmpty || name.toLowerCase() == 'unknown' || name.toLowerCase() == 'narrator') continue;
    await ensure(name,
        aliases: [for (final a in (raw['aliases'] as List? ?? const [])) '$a'.trim()].where((a) => a.isNotEmpty).toList(),
        gender: '${raw['gender'] ?? 'unknown'}'.toLowerCase(),
        age: '${raw['age'] ?? 'unknown'}'.toLowerCase());
  }

  final map = <int, int>{};
  final counts = <int, int>{};
  for (final raw in (data['lines'] as List? ?? const [])) {
    if (raw is! Map) continue;
    final p = (raw['p'] as num?)?.toInt();
    final who = '${raw['speaker'] ?? ''}'.trim();
    if (p == null || p < 0 || p >= paraCount || who.isEmpty) continue;
    final l = who.toLowerCase();
    if (l == 'unknown' || l == 'narrator') continue;
    final c = find(who) ?? await ensure(who);
    map[p] = c.id!;
    counts[c.id!] = (counts[c.id!] ?? 0) + 1;
  }
  for (final c in cast) {
    final n = counts[c.id];
    if (n != null) {
      c.lines += n;
      await Cast.save(c);
    }
  }
  return (map, added);
}

/// Finds who speaks each line of dialogue in [chapter] and updates the book's cast.
Future<AnalysisResult> analyzeChapter(Settings s, Chapter chapter) async {
  final paras = splitParas(chapter.content);
  if (!paras.any(hasDialogue)) {
    await Cast.saveSpeakers(chapter.id!, {});
    return AnalysisResult(0, 0);
  }
  final all = <int, int>{};
  var added = 0;
  for (final batch in analysisBatches(paras)) {
    if (!batch.any((i) => hasDialogue(paras[i]))) continue;
    final cast = await Cast.of(chapter.bookId);
    final known = cast.isEmpty
        ? 'Known characters: none yet.'
        : 'Known characters:\n${cast.map((c) => '- ${c.name}${c.aliases.isEmpty ? '' : ' (also: ${c.aliases.take(6).join(', ')})'}; ${c.gender}; ${c.age}').join('\n')}';
    final text = batch.map((i) => '[$i] ${paraText(paras[i])}').join('\n');
    final data = await askJson(s, _system, '$known\n\nChapter "${chapter.title}":\n$text');
    final (map, n) = await mergeAnalysis(chapter.bookId, data, s.cloudTtsVoice, paraCount: paras.length);
    all.addAll(map);
    added += n;
  }
  await Cast.saveSpeakers(chapter.id!, all);
  return AnalysisResult(all.length, added);
}
