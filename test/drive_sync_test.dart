import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lantern_reader/src/app.dart';
import 'package:lantern_reader/src/db.dart';
import 'package:lantern_reader/src/drive_sync.dart';
import 'package:lantern_reader/src/importers.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// In-memory Drive with the same behaviour as the real one for the calls sync makes.
class FakeDrive implements DriveApi {
  final files = <String, ({String name, Map<String, String> props, Uint8List data, bool trashed, String parent})>{};
  var _n = 0;

  @override
  Future<String> folderId() async {
    for (final e in files.entries) {
      if (e.value.props['lantern'] == 'root' && !e.value.trashed) return e.key;
    }
    final id = 'f${++_n}';
    files[id] = (name: 'Lantern Reader', props: {'lantern': 'root'}, data: Uint8List(0), trashed: false, parent: 'root');
    return id;
  }

  @override
  Future<List<DriveFile>> listFolder(String folder) async => [
    for (final e in files.entries)
      if (e.value.parent == folder && !e.value.trashed) DriveFile(e.key, e.value.name, e.value.props),
  ];

  @override
  Future<Uint8List> download(String id) async => files[id]!.data;

  @override
  Future<void> upload({
    String? fileId,
    required String folder,
    required String name,
    required Map<String, String> props,
    required Uint8List bytes,
    required String mime,
  }) async {
    if (fileId == null) {
      files['f${++_n}'] = (name: name, props: props, data: bytes, trashed: false, parent: folder);
    } else {
      final f = files[fileId]!;
      files[fileId] = (name: f.name, props: {...f.props, ...props}, data: bytes, trashed: false, parent: f.parent);
    }
  }

  @override
  Future<void> trash(String id) async {
    final f = files[id]!;
    files[id] = (name: f.name, props: f.props, data: f.data, trashed: true, parent: f.parent);
  }

  @override
  Future<String> userEmail() async => 'kamal@example.com';

  Map<String, dynamic> book(String title) {
    final f = files.values.firstWhere((f) => f.name.startsWith(title) && !f.trashed);
    return jsonDecode(utf8.decode(gzip.decode(f.data))) as Map<String, dynamic>;
  }
}

/// Each "device" is its own database file; [use] switches the app's database to it.
class Device {
  Device(this.path);
  final String path;
  Future<void> use() async {
    try {
      await Db.close();
    } catch (_) {}
    await Db.open(path, factory: databaseFactoryFfiNoIsolate);
  }
}

void main() {
  late Directory dir;
  late FakeDrive drive;
  var clock = 1000000;
  int now() => clock += 1000;
  SyncEngine engine() => SyncEngine(drive, now: now);

  setUpAll(() => sqfliteFfiInit());
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('lantern_sync');
    dataDir = dir.path;
    drive = FakeDrive();
  });
  tearDown(() async {
    try {
      await Db.close();
    } catch (_) {}
    await dir.delete(recursive: true);
  });

  ImportedBook novel(String title, int n) => ImportedBook(
    title: title,
    format: 'EPUB',
    chapters: [
      for (var i = 0; i < n; i++) ImportedChapter('Chapter ${i + 1}', ['# Chapter ${i + 1}', 'Text of chapter ${i + 1}.', 'More.']),
    ],
  );

  test('books, positions, edits and deletions travel between devices', () async {
    final a = Device('${dir.path}/a.db'), b = Device('${dir.path}/b.db');

    await a.use();
    final idA = await saveImported(novel('Martial Peak', 4));
    await saveImported(novel('Magazine', 1));
    var s = await engine().run();
    expect(s.uploaded, 2);
    expect(drive.book('Martial Peak')['chapters'], hasLength(4));
    expect(drive.book('Martial Peak')['chapters'][0]['paras'], ['# Chapter 1', 'Text of chapter 1.', 'More.']);

    await b.use();
    s = await engine().run();
    expect(s.downloaded, 2);
    var books = await Db.books();
    expect(books.map((x) => x.title).toSet(), {'Martial Peak', 'Magazine'});
    final mpB = books.firstWhere((x) => x.title == 'Martial Peak');
    expect(mpB.chapterCount, 4);
    expect((await Db.chapterAt(mpB.id!, 2))!.content, '# Chapter 3\nText of chapter 3.\nMore.');

    // Read on B, then A picks the position up.
    await Db.setPositionAt(mpB.id!, 2, 1, clock += 50000);
    await engine().run();
    await a.use();
    s = await engine().run();
    expect(s.positions, 1);
    var mpA = (await Db.book(idA))!;
    expect((mpA.curChapter, mpA.curPara), (2, 1));

    // A saves a new chapter: B gets the text and keeps its place.
    await Db.addChapter(idA, 'Chapter 5', 'New chapter text.');
    s = await engine().run();
    expect(s.uploaded, 1);
    await b.use();
    s = await engine().run();
    expect(s.downloaded, 1);
    final mpB2 = (await Db.books()).firstWhere((x) => x.title == 'Martial Peak');
    expect(mpB2.chapterCount, 5);
    expect(mpB2.curChapter, 2);

    // Nothing changed: a second run moves nothing.
    s = await engine().run();
    expect((s.uploaded, s.downloaded, s.positions), (0, 0, 0));

    // B deletes the magazine: Drive file goes to the trash and A loses it too.
    final mag = (await Db.books()).firstWhere((x) => x.title == 'Magazine');
    await Db.deleteBook(mag.id!);
    await engine().run();
    expect(drive.files.values.where((f) => f.name.startsWith('Magazine') && f.trashed), hasLength(1));
    await a.use();
    s = await engine().run();
    expect(s.removed, 1);
    expect((await Db.books()).map((x) => x.title), ['Martial Peak']);
  });

  test('reads books and positions written by the web version', () async {
    // A progress file and book exactly as web-app/sync.mjs writes them.
    final folder = await drive.folderId();
    final book = {
      'v': 1,
      'sid': 'web-1',
      'title': 'From the browser',
      'author': 'Someone',
      'format': 'PDF',
      'addedAt': 5,
      'chapters': [
        {
          'title': 'Pages 1–10',
          'paras': ['# Zinnia', 'Old-fashioned zinnias provide a bounty of cut flowers.'],
        },
        {
          'title': 'Pages 11–12',
          'paras': ['Second part.'],
        },
      ],
    };
    final paraLen = ['# Zinnia\nOld-fashioned zinnias provide a bounty of cut flowers.', 'Second part.'];
    await drive.upload(
      folder: folder,
      name: 'From the browser.lantern.json.gz',
      props: {'lantern': 'book', 'sid': 'web-1', 'sig': bookSig(paraLen)},
      bytes: Uint8List.fromList(gzip.encode(utf8.encode(jsonEncode(book)))),
      mime: 'application/gzip',
    );
    await drive.upload(
      folder: folder,
      name: 'progress-web.json',
      props: {'lantern': 'progress', 'dev': 'web'},
      bytes: Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'v': 1,
            'device': 'Chrome on Windows',
            'at': 9,
            'books': {
              'web-1': {'ch': 1, 'para': 0, 'at': 4000000, 'title': 'From the browser'},
            },
            'deleted': {},
          }),
        ),
      ),
      mime: 'application/json',
    );
    await Device('${dir.path}/p.db').use();
    final s = await engine().run();
    expect(s.downloaded, 1);
    expect(s.positions, 1);
    final b = (await Db.books()).single;
    expect((b.title, b.format, b.chapterCount, b.curChapter), ('From the browser', 'PDF', 2, 1));
    // The phone's own progress file now lists the book under the same id.
    final mine = drive.files.values.firstWhere((f) => f.props['lantern'] == 'progress' && f.name != 'progress-web.json');
    expect((jsonDecode(utf8.decode(mine.data)) as Map)['books'], contains('web-1'));
  });
}
