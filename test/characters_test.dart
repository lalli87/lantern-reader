import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lantern_reader/src/ai.dart';
import 'package:lantern_reader/src/characters.dart';
import 'package:lantern_reader/src/cloud_tts.dart';
import 'package:lantern_reader/src/db.dart';
import 'package:lantern_reader/src/exports.dart' show audioBatches;
import 'package:lantern_reader/src/models.dart';
import 'package:lantern_reader/src/settings.dart';
import 'package:lantern_reader/src/text_utils.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('an existing version-1 library upgrades and keeps its books', () async {
    final dir = await Directory.systemTemp.createTemp('lantern');
    final path = '${dir.path}/old.db';
    final old = await databaseFactoryFfiNoIsolate.openDatabase(path,
        options: OpenDatabaseOptions(version: 1, onCreate: (d, v) async {
      await d.execute('CREATE TABLE books(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT)');
      await d.execute('CREATE TABLE kv(k TEXT PRIMARY KEY, v TEXT)');
      await d.insert('books', {'title': 'Kept'});
    }));
    await old.close();
    await Db.open(path, factory: databaseFactoryFfiNoIsolate);
    expect((await Db.db.query('books')).single['title'], 'Kept');
    await Cast.save(CastMember(bookId: 1, name: 'Lin Mei', gender: 'female'));
    expect((await Cast.of(1)).single.name, 'Lin Mei');
    await Db.close();
    await dir.delete(recursive: true);
  });

  group('cast', () {
    late int bookId;
    setUp(() async {
      await Db.open(inMemoryDatabasePath, factory: databaseFactoryFfiNoIsolate);
      bookId = await Db.insertBook(Book(title: 'B'));
    });
    tearDown(Db.close);

    test('voices fit gender and age, avoid the narrator and spread out', () {
      final cast = <CastMember>[];
      String? add(String g, String a) {
        final v = pickVoice(g, a, cast, 'Charon');
        cast.add(CastMember(bookId: 1, name: 'x${cast.length}', gender: g, age: a, voice: v));
        return v;
      }

      final m1 = add('male', 'adult');
      expect(maleVoices, contains(m1));
      expect(m1, isNot('Charon'));
      expect(femaleVoices, contains(add('female', 'adult')));
      expect(['Algenib', 'Rasalgethi', 'Schedar'], contains(add('male', 'elderly')));
      expect(['Leda', 'Zephyr', 'Despina'], contains(add('female', 'teen')));
      expect(add('unknown', 'adult'), isNull);
      final males = [for (var i = 0; i < 10; i++) add('male', 'adult')];
      expect(males.toSet().length, 10, reason: 'no repeats while unused voices remain');
    });

    test('analysis merges into one cast across chapters, keeping user choices', () async {
      final (m1, added1) = await mergeAnalysis(bookId, {
        'characters': [
          {'name': 'Lin Mei', 'aliases': ['Junior Sister'], 'gender': 'female', 'age': 'young adult'},
          {'name': 'Old Shen', 'gender': 'male', 'age': 'elderly'},
        ],
        'lines': [
          {'p': 2, 'speaker': 'Lin Mei'},
          {'p': 5, 'speaker': 'Old Shen'},
          {'p': 7, 'speaker': 'unknown'},
          {'p': 99, 'speaker': 'Lin Mei'},
        ],
      }, 'Charon', paraCount: 20);
      expect(added1, 2);
      final cast = await Cast.of(bookId);
      final lin = cast.firstWhere((c) => c.name == 'Lin Mei');
      final shen = cast.firstWhere((c) => c.name == 'Old Shen');
      expect(m1, {2: lin.id, 5: shen.id});
      expect(femaleVoices, contains(lin.voice));
      expect(shen.style, contains('elderly'));

      // The user picks a voice for Lin Mei; a later chapter calls her by an alias and adds a stranger.
      lin
        ..voice = 'Sulafat'
        ..userSet = true;
      await Cast.save(lin);
      final (m2, added2) = await mergeAnalysis(bookId, {
        'characters': [
          {'name': 'Junior Sister', 'gender': 'male', 'age': 'adult'},
          {'name': 'Gatekeeper', 'gender': 'unknown'},
        ],
        'lines': [
          {'p': 0, 'speaker': 'junior sister'},
          {'p': 1, 'speaker': 'Gatekeeper'},
          {'p': 3, 'speaker': 'A Stranger'},
        ],
      }, 'Charon');
      expect(added2, 2);
      final after = await Cast.of(bookId);
      final lin2 = after.firstWhere((c) => c.id == lin.id);
      expect(lin2.voice, 'Sulafat');
      expect(lin2.gender, 'female');
      expect(lin2.lines, 2);
      expect(m2[0], lin.id);
      expect(after.firstWhere((c) => c.name == 'Gatekeeper').voice, isNull);
      expect(after.any((c) => c.name == 'A Stranger'), true);
    });

    test('deleting chapters keeps the cast and the reading position', () async {
      final ids = [for (var i = 0; i < 5; i++) await Db.addChapter(bookId, 'c$i', '"Hi," she said.')];
      await Db.savePosition(bookId, 3, 4);
      await Cast.saveSpeakers(ids[0], {0: 1});
      await Cast.save(CastMember(bookId: bookId, name: 'Lin Mei'));
      for (final id in ids.take(3)) {
        await Db.deleteChapter(bookId, id);
      }
      final b = (await Db.book(bookId))!;
      expect(b.curChapter, 0);
      expect(b.curPara, 4);
      expect((await Db.chapterAt(bookId, 0))!.title, 'c3');
      expect(await Cast.speakers(ids[0]), isNull);
      expect((await Cast.of(bookId)).length, 1);
      expect(await Cast.analysedChapters(bookId), isEmpty);
      await Db.deleteBook(bookId, forget: true);
      expect(await Cast.of(bookId), isEmpty);
    });

    test('long chapters are split, dialogue is detected', () {
      final paras = List.generate(30, (i) => 'x' * 3000);
      final b = analysisBatches(paras, maxChars: 10000);
      expect(b.expand((e) => e).toList(), List.generate(30, (i) => i));
      expect(b.every((x) => x.length <= 4), true);
      expect(hasDialogue('“Come here,” he said.'), true);
      expect(hasDialogue('She walked away.'), false);
      expect(hasDialogue('「来」'), true);
    });

    test('checking a chapter asks Gemini once and stores who speaks', () async {
      final s = Settings();
      await s.load();
      s.setSecret('geminiKey', 'test');
      final cid = await Db.addChapter(bookId, 'Chapter 1', 'The gate was shut.\n"Name?" the keeper asked.\n"Lin Mei," she said.\nNothing happened.');
      String? sent;
      final reply = {
        'characters': [
          {'name': 'Keeper', 'gender': 'male', 'age': 'elderly'},
          {'name': 'Lin Mei', 'gender': 'female', 'age': 'young adult'},
        ],
        'lines': [
          {'p': 1, 'speaker': 'Keeper'},
          {'p': 2, 'speaker': 'Lin Mei'},
        ],
      };
      final r = await http.runWithClient(() async => analyzeChapter(s, (await Db.chapter(cid))!), () => MockClient((req) async {
            sent = req.body;
            return http.Response(jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': jsonEncode(reply)}
                    ]
                  }
                }
              ]
            }), 200);
          }));
      expect(r.lines, 2);
      expect(r.newCharacters, 2);
      final body = jsonDecode(sent!) as Map;
      expect(body['generationConfig'], {'responseMimeType': 'application/json'});
      expect('$body', contains('[2] "Lin Mei," she said.'));
      final who = (await Cast.speakers(cid))!;
      final cast = await Cast.of(bookId);
      expect(cast.firstWhere((c) => c.id == who[2]).name, 'Lin Mei');
      expect(cast.firstWhere((c) => c.id == who[1]).name, 'Keeper');
      expect(await Cast.analysedChapters(bookId), {cid});
    });

    test('a chapter with no dialogue is marked checked without asking', () async {
      final s = Settings();
      await s.load();
      final cid = await Db.addChapter(bookId, 'Quiet', 'Snow fell.\nShe slept.');
      final r = await analyzeChapter(s, (await Db.chapter(cid))!);
      expect(r.lines, 0);
      expect(await Cast.speakers(cid), isEmpty);
    });
    test('with a Chirp 3 HD narrator, quoted words go to the character and the rest to the narrator', () async {
      final s = Settings();
      await s.load();
      s.set('voiceSource', voiceGoogle);
      s.set('googleVoice', 'en-US-Chirp3-HD-Algenib');
      expect(narratorName(s), 'Algenib');
      expect(characterVoicesUnavailable(s), isNull);
      // A character found while the narrator was Charon got Algenib, which is now the narrator's voice.
      final elder = CastMember(bookId: bookId, name: 'Crimson Corpse', gender: 'male', age: 'elderly', voice: 'Algenib');
      final girl = CastMember(bookId: bookId, name: 'Lin Mei', gender: 'female', age: 'teen', voice: 'Leda');
      await Cast.save(elder);
      await Cast.save(girl);
      final text = 'The gate was shut.\n“Who goes there?” the old man rasped. “Speak!”\n“Lin Mei,” she said.\nNothing happened.';
      final cid = await Db.addChapter(bookId, 'One', text);
      await Cast.saveSpeakers(cid, {1: elder.id!, 2: girl.id!});
      final ch = (await Db.chapter(cid))!;
      final plan = (await characterPlan(s, voiceGoogle, ch, splitParas(ch.content)))!;

      final fixed = (await Cast.of(bookId)).firstWhere((c) => c.name == 'Crimson Corpse');
      expect(fixed.voice, isNot('Algenib'), reason: 'never the narrator\'s voice');
      expect(maleVoices, contains(fixed.voice));

      String? voiceOf(String t) => plan.firstWhere((c) => c.text.contains(t)).voice;
      expect(voiceOf('gate was shut'), isNull);
      expect(voiceOf('Who goes there'), fixed.voice);
      expect(voiceOf('the old man rasped'), isNull);
      expect(voiceOf('Speak!'), fixed.voice);
      expect(voiceOf('Lin Mei,'), 'Leda');
      expect(voiceOf('she said'), isNull);
      // Pieces point at the right words for follow-along.
      final p1 = paraText(splitParas(text)[1]);
      final q = plan.firstWhere((c) => c.text.contains('Who goes there'));
      expect(p1.substring(q.start, q.end), '“Who goes there?”');
      expect(plan.firstWhere((c) => c.voice == fixed.voice).style, contains('elderly man'));

      expect(googleCharacterVoice(s, 'Leda'), 'en-US-Chirp3-HD-Leda');
      expect(cloudVoiceId(s, voiceGoogle, voice: 'Leda'), isNot(cloudVoiceId(s, voiceGoogle)));

      // Character voices off, or a non-Chirp voice: no plan, the narrator reads everything.
      s.set('googleVoice', 'en-US-Neural2-D');
      expect(narratorName(s), isNull);
      expect(characterVoicesUnavailable(s), contains('Chirp 3 HD'));
      expect(await characterPlan(s, voiceGoogle, ch, splitParas(ch.content)), isNull);
    });

    test('character pieces are synthesised with the character\'s voice', () async {
      final s = Settings();
      await s.load();
      s.setSecret('googleTtsKey', 'k');
      s.set('googleVoice', 'en-GB-Chirp3-HD-Charon');
      Map? body;
      await http.runWithClient(() => googleSpeech(s, '“Hello.”', voice: googleCharacterVoice(s, 'Kore')), () => MockClient((req) async {
            body = jsonDecode(req.body) as Map;
            return http.Response(jsonEncode({'audioContent': base64.encode([1, 2, 3])}), 200);
          }));
      expect(body!['voice'], {'languageCode': 'en-GB', 'name': 'en-GB-Chirp3-HD-Kore'});
      final g = geminiSpeechBody('gemini-3.8-flash-lite-tts', '“Hello.”', 'Spoken aloud by a teenager', 'Leda');
      expect('$g', contains('Leda'));
      expect('$g', contains('Spoken aloud by a teenager'));
    });
    test('merging two characters keeps every line under one voice', () async {
      final cid = await Db.addChapter(bookId, 'One', 'a\n"x"\n"y"\n"z"');
      final a = CastMember(bookId: bookId, name: 'Luo Chen', gender: 'male', voice: 'Orus', lines: 5);
      final b = CastMember(bookId: bookId, name: 'Devil Lord', aliases: ['the Devil'], voice: 'Puck', lines: 2);
      await Cast.save(a);
      await Cast.save(b);
      await Cast.saveSpeakers(cid, {1: a.id!, 2: b.id!, 3: b.id!});
      await Cast.merge(b, a);
      final cast = await Cast.of(bookId);
      expect(cast, hasLength(1));
      expect(cast.single.aliases, containsAll(['Devil Lord', 'the Devil']));
      expect(cast.single.lines, 7);
      expect(cast.single.voice, 'Orus');
      expect(await Cast.speakers(cid), {1: a.id, 2: a.id, 3: a.id});
    });

    test('a deleted novel\'s characters come back when it is added again', () async {
      final old = Book(title: 'An Alchemist\'s Path', format: 'WEB', sourceUrl: 'https://www.wuxiaworld.com/novel/aptte/chapter-1');
      await Db.insertBook(old);
      await Cast.save(CastMember(bookId: old.id!, name: 'Luo Chen', gender: 'male', voice: 'Orus', userSet: true));
      await Db.deleteBook(old.id!);
      expect(await Cast.of(old.id!), isEmpty);
      final again = Book(title: 'Alchemist', format: 'WEB', sourceUrl: 'https://wuxiaworld.com/novel/aptte/chapter-1001');
      await Db.insertBook(again);
      final cast = await Cast.of(again.id!);
      expect(cast.single.name, 'Luo Chen');
      expect(cast.single.voice, 'Orus');
      expect(cast.single.userSet, isTrue);
      // Used once: another new book doesn't get them too.
      final third = Book(title: 'Alchemist 2', sourceUrl: 'https://wuxiaworld.com/novel/aptte/chapter-5');
      await Db.insertBook(third);
      expect(await Cast.of(third.id!), isEmpty);
    });

    test('audio files join pieces of the same voice and keep voices apart', () {
      final b = audioBatches([
        const SpeechChunk(0, 0, 10, 'Narration.'),
        const SpeechChunk(1, 0, 5, '“Hi.”', voice: 'Kore', style: 's'),
        const SpeechChunk(1, 5, 15, 'she said.'),
        const SpeechChunk(2, 0, 9, 'And then.'),
      ], 2000);
      expect(b.map((x) => (x.text, x.voice)), [('Narration.', null), ('“Hi.”', 'Kore'), ('she said.\nAnd then.', null)]);
      expect(b[1].style, 's');
    });
  });
}
