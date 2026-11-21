import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lantern_reader/src/app.dart';
import 'package:lantern_reader/src/cloud_tts.dart';
import 'package:lantern_reader/src/db.dart';
import 'package:lantern_reader/src/exports.dart';
import 'package:lantern_reader/src/models.dart';
import 'package:lantern_reader/src/settings.dart';
import 'package:lantern_reader/src/text_utils.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FakePaths extends Fake with MockPlatformInterfaceMixin implements PathProviderPlatform {
  FakePaths(this.root);
  final String root;
  @override
  Future<String?> getTemporaryPath() async => '$root/tmp';
  @override
  Future<String?> getApplicationSupportPath() async => '$root/support';
  @override
  Future<String?> getApplicationDocumentsPath() async => '$root/docs';
}

void main() {
  setUpAll(sqfliteFfiInit);

  test('an audio file made ahead also fills the in-app voice store, and is found again by chapter title', () async {
    final root = await Directory.systemTemp.createTemp('lantern_offline');
    PathProviderPlatform.instance = FakePaths(root.path);
    await Db.open(inMemoryDatabasePath, factory: databaseFactoryFfiNoIsolate);
    settings = Settings();
    await settings.load();
    settings.setSecret('googleTtsKey', 'k');
    settings.set('googleVoice', 'en-US-Chirp3-HD-Algenib');
    final book = Book(title: 'An Alchemist\'s Path', format: 'WEB');
    await Db.insertBook(book);
    final text = List.generate(30, (i) => 'Paragraph $i of the chapter, long enough to be its own piece of speech. ' * 3).join('\n');
    await Db.addChapter(book.id!, 'Chapter 1008', text);
    final meta = (await Db.chapterMetas(book.id!)).single;

    var calls = 0;
    final dir = await Directory('${root.path}/docs/Audiobooks/${safeFileName(book.title)}').create(recursive: true);
    final path = await http.runWithClient(
      () => renderChapterAudio(book: book, meta: meta, source: voiceGoogle, dir: dir, cancelled: () => false),
      () => MockClient((req) async {
        calls++;
        return http.Response(jsonEncode({'audioContent': base64.encode([calls, calls])}), 200);
      }),
    );
    expect(path, isNotNull);
    final pieces = await chapterCloudPieces((await Db.chapter(meta.id))!, voiceGoogle);
    expect(calls, pieces.length, reason: 'one request per in-app piece');
    expect(File(path!).lengthSync(), pieces.length * 2);

    // Every piece the player will ask for is now saved: no internet needed.
    for (final c in pieces) {
      expect(await cachedCloudAudio(settings, voiceGoogle, applyReplacements(c.text, settings.replacements)), isNotNull);
    }
    // And the file is found by title even after chapter numbers shift.
    expect((await exportedChapterFile(book, 'Chapter 1008'))?.path, path);
    expect(await exportedChapterFile(book, 'Chapter 1009'), isNull);

    await Db.close();
    await root.delete(recursive: true);
  });
}
