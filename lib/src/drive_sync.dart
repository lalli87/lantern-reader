import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import 'app.dart';
import 'db.dart';
import 'importers.dart';
import 'models.dart';
import 'pdf_pages.dart';
import 'text_utils.dart';

/// Google Drive sync of books and reading positions, shared with the web version.
/// Format and rules: docs/SYNC.md (the web side is web-app/sync.mjs).

const driveScope = 'https://www.googleapis.com/auth/drive.file';
const _folderName = 'Lantern Reader';
const _folderMime = 'application/vnd.google-apps.folder';

/// OAuth "Web application" client ID, set at build time (GitHub repo variable GOOGLE_CLIENT_ID) or in
/// Settings. Android sign-in also needs an "Android" client for the app's package and signing key.
const buildGoogleClientId = String.fromEnvironment('GOOGLE_CLIENT_ID');

class AuthExpired implements Exception {
  @override
  String toString() => 'Google sign-in expired.';
}

class DriveFile {
  DriveFile(this.id, this.name, this.props);
  final String id, name;
  final Map<String, String> props;
}

/// The few Drive calls sync needs; [HttpDrive] talks to Google, tests use an in-memory one.
abstract class DriveApi {
  Future<String> folderId();
  Future<List<DriveFile>> listFolder(String folder);
  Future<Uint8List> download(String id);

  /// Creates a file in [folder] (when [fileId] is null) or replaces [fileId]'s content and properties.
  Future<void> upload({
    String? fileId,
    required String folder,
    required String name,
    required Map<String, String> props,
    required Uint8List bytes,
    required String mime,
  });
  Future<void> trash(String id);
  Future<String> userEmail();
}

class HttpDrive implements DriveApi {
  HttpDrive(this.token, {this.base = 'https://www.googleapis.com', http.Client? client}) : _c = client ?? http.Client();
  final Future<String> Function() token;
  final String base;
  final http.Client _c;

  Future<http.Response> _send(String method, String url, {Object? json, Uint8List? body, String? type}) async {
    final r = http.Request(method, Uri.parse(url));
    r.headers['authorization'] = 'Bearer ${await token()}';
    if (json != null) {
      r.headers['content-type'] = 'application/json';
      r.body = jsonEncode(json);
    } else if (body != null) {
      r.headers['content-type'] = type!;
      r.bodyBytes = body;
    }
    final res = await http.Response.fromStream(await _c.send(r));
    if (res.statusCode == 401) throw AuthExpired();
    if (res.statusCode >= 300) {
      var m = '';
      try {
        m = ((jsonDecode(res.body) as Map)['error'] as Map?)?['message'] as String? ?? '';
      } catch (_) {}
      if (RegExp('has not been used|is disabled').hasMatch(m)) {
        m = 'The Google Drive API is not turned on for this project (console.cloud.google.com → APIs & Services → Library → Google Drive API → Enable).';
      }
      throw HttpException('Drive ${res.statusCode}: $m');
    }
    return res;
  }

  Future<List<DriveFile>> _list(String q) async {
    final out = <DriveFile>[];
    var page = '';
    do {
      final u =
          '$base/drive/v3/files?q=${Uri.encodeQueryComponent(q)}&pageSize=1000&spaces=drive'
          '&fields=${Uri.encodeQueryComponent('nextPageToken,files(id,name,appProperties)')}${page.isEmpty ? '' : '&pageToken=$page'}';
      final j = jsonDecode((await _send('GET', u)).body) as Map<String, dynamic>;
      for (final f in (j['files'] as List? ?? const []).cast<Map<String, dynamic>>()) {
        out.add(DriveFile(f['id'] as String, f['name'] as String? ?? '', Map<String, String>.from(f['appProperties'] as Map? ?? const {})));
      }
      page = j['nextPageToken'] as String? ?? '';
    } while (page.isNotEmpty);
    return out;
  }

  @override
  Future<String> folderId() async {
    final found = await _list(
      "mimeType='$_folderMime' and name='$_folderName' and trashed=false and appProperties has { key='lantern' and value='root' }",
    );
    if (found.isNotEmpty) return found.first.id;
    final r = await _send(
      'POST',
      '$base/drive/v3/files?fields=id',
      json: {
        'name': _folderName,
        'mimeType': _folderMime,
        'appProperties': {'lantern': 'root'},
      },
    );
    return (jsonDecode(r.body) as Map)['id'] as String;
  }

  @override
  Future<List<DriveFile>> listFolder(String folder) => _list("'$folder' in parents and trashed=false");

  @override
  Future<Uint8List> download(String id) async => (await _send('GET', '$base/drive/v3/files/$id?alt=media')).bodyBytes;

  @override
  Future<void> upload({
    String? fileId,
    required String folder,
    required String name,
    required Map<String, String> props,
    required Uint8List bytes,
    required String mime,
  }) async {
    final b = 'lantern${Random().nextInt(1 << 30)}';
    final meta = <String, Object>{
      'appProperties': props,
      if (fileId == null) 'name': name,
      if (fileId == null) 'parents': [folder],
    };
    final body = BytesBuilder(copy: false)
      ..add(
        utf8.encode(
          '--$b\r\ncontent-type: application/json; charset=UTF-8\r\n\r\n${jsonEncode(meta)}\r\n--$b\r\ncontent-type: $mime\r\n\r\n',
        ),
      )
      ..add(bytes)
      ..add(utf8.encode('\r\n--$b--'));
    final url = fileId == null
        ? '$base/upload/drive/v3/files?uploadType=multipart&fields=id'
        : '$base/upload/drive/v3/files/$fileId?uploadType=multipart&fields=id';
    await _send(fileId == null ? 'POST' : 'PATCH', url, body: body.takeBytes(), type: 'multipart/related; boundary=$b');
  }

  @override
  Future<void> trash(String id) => _send('PATCH', '$base/drive/v3/files/$id?fields=id', json: {'trashed': true});

  @override
  Future<String> userEmail() async {
    final r = await _send('GET', '$base/drive/v3/about?fields=${Uri.encodeQueryComponent('user(emailAddress)')}');
    return ((jsonDecode(r.body) as Map)['user'] as Map?)?['emailAddress'] as String? ?? '';
  }
}

/// "chapters:characters", identical to the web version's bookSig.
String bookSig(List<String> chapterContents) => '${chapterContents.length}:${chapterContents.fold<int>(0, (n, c) => n + c.length)}';

String _newId() {
  final r = Random.secure();
  String h(int n) => List.generate(n, (_) => r.nextInt(16).toRadixString(16)).join();
  return '${h(8)}-${h(4)}-4${h(3)}-${h(4)}-${h(12)}';
}

String _safeName(String s) {
  final t = s.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  return (t.isEmpty ? 'Untitled' : t).substring(0, min(80, t.isEmpty ? 8 : t.length));
}

class SyncStats {
  int uploaded = 0, downloaded = 0, removed = 0, positions = 0;
  @override
  String toString() => '$uploaded sent, $downloaded received, $positions position${positions == 1 ? '' : 's'} updated';
}

/// Local sync bookkeeping, kept in the kv table: which Drive id (sid) each book has and the text
/// signature last exchanged, books deleted here that other devices should delete, this device's id.
class SyncState {
  static const books = 'sync.books', pending = 'sync.pending', device = 'sync.device', last = 'sync.last';
}

class SyncEngine {
  SyncEngine(this.drive, {this.deviceName = 'Android phone', int Function()? now, this.isOpen}) : now = now ?? nowMs;
  final DriveApi drive;
  final String deviceName;
  final int Function() now;

  /// Book currently on screen: incoming positions skip it so the page doesn't jump.
  final bool Function(int bookId)? isOpen;

  Future<List<String>> _contents(int bookId) async {
    final out = <String>[];
    for (final m in await Db.chapterMetas(bookId)) {
      out.add((await Db.chapter(m.id))?.content ?? '');
    }
    return out;
  }

  Future<String> _upload(String folder, int bookId, String sid, String? fileId) async {
    final b = (await Db.book(bookId))!;
    final metas = await Db.chapterMetas(bookId);
    final contents = await _contents(bookId);
    final json = jsonEncode({
      'v': 1,
      'sid': sid,
      'title': b.title,
      'author': b.author,
      'format': b.format,
      'addedAt': b.addedAt,
      'chapters': [
        for (var i = 0; i < metas.length; i++) {'title': metas[i].title, 'paras': splitParas(contents[i])},
      ],
    });
    final sig = bookSig(contents);
    await drive.upload(
      fileId: fileId,
      folder: folder,
      name: '${_safeName(b.title)}.lantern.json.gz',
      props: {'lantern': 'book', 'sid': sid, 'sig': sig},
      bytes: Uint8List.fromList(gzip.encode(utf8.encode(json))),
      mime: 'application/gzip',
    );
    return sig;
  }

  Future<Map<String, dynamic>> _getBook(DriveFile f) async {
    var bytes = await drive.download(f.id);
    if (bytes.length > 2 && bytes[0] == 0x1f && bytes[1] == 0x8b) bytes = Uint8List.fromList(gzip.decode(bytes));
    final j = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    if (j['chapters'] is! List) throw FormatException('Unreadable book file on Drive: ${f.name}');
    return j;
  }

  static List<(String, List<String>)> _chaptersOf(Map<String, dynamic> j) => [
    for (final c in (j['chapters'] as List).cast<Map<String, dynamic>>())
      (c['title'] as String? ?? '', (c['paras'] as List? ?? const []).cast<String>()),
  ];

  Future<SyncStats> run({bool full = true}) async {
    final stats = SyncStats();
    final folder = await drive.folderId();
    final files = await drive.listFolder(folder);
    final remoteBooks = <String, DriveFile>{};
    final progressFiles = <DriveFile>[];
    for (final f in files) {
      if (f.props['lantern'] == 'book' && f.props['sid'] != null) remoteBooks[f.props['sid']!] = f;
      if (f.props['lantern'] == 'progress') progressFiles.add(f);
    }
    var deviceId = await Db.kvGet(SyncState.device) ?? '';
    if (deviceId.isEmpty) {
      deviceId = _newId();
      await Db.kvSet(SyncState.device, deviceId);
    }
    final ownName = 'progress-$deviceId.json';
    DriveFile? ownFile;
    Map<String, dynamic> ownDoc = {};
    final docs = <Map<String, dynamic>>[];
    for (final f in progressFiles) {
      try {
        final d = jsonDecode(utf8.decode(await drive.download(f.id))) as Map<String, dynamic>;
        docs.add(d);
        if (f.name == ownName) {
          ownFile = f;
          ownDoc = d;
        }
      } catch (_) {}
    }
    final pending = await Db.kvJson(SyncState.pending);
    final ownDeleted = <String, dynamic>{...(ownDoc['deleted'] as Map? ?? const {}), ...pending};
    final deleted = <String, dynamic>{...ownDeleted};
    for (final d in docs) {
      deleted.addAll(Map<String, dynamic>.from(d['deleted'] as Map? ?? const {}));
    }

    final map = await Db.kvJson(SyncState.books); // bookId -> {sid, sig}
    Future<void> saveMap() => Db.kvSet(SyncState.books, jsonEncode(map));

    if (full) {
      final localSids = <String>{};
      for (final b in await Db.books()) {
        final key = '${b.id}';
        final e = Map<String, dynamic>.from(map[key] as Map? ?? const {});
        var sid = e['sid'] as String? ?? '';
        if (sid.isEmpty) {
          sid = _newId();
          map[key] = {'sid': sid};
          await saveMap();
        }
        if (deleted.containsKey(sid)) {
          map.remove(key);
          await saveMap();
          await Db.deleteBook(b.id!, forget: true);
          await deleteOriginalPdf(b.id!);
          stats.removed++;
          continue;
        }
        localSids.add(sid);
        final r = remoteBooks[sid];
        final known = e['sig'] as String?;
        final sig = bookSig(await _contents(b.id!));
        if (r != null) {
          if (sig != known) {
            map[key] = {'sid': sid, 'sig': await _upload(folder, b.id!, sid, r.id)};
            stats.uploaded++;
          } else if (r.props['sig'] != known) {
            final j = await _getBook(r);
            final chapters = _chaptersOf(j);
            await Db.replaceChapters(b.id!, [for (final c in chapters) (c.$1, c.$2.join('\n'))]);
            map[key] = {
              'sid': sid,
              'sig': bookSig([for (final c in chapters) c.$2.join('\n')]),
            };
            stats.downloaded++;
          }
        } else {
          map[key] = {'sid': sid, 'sig': await _upload(folder, b.id!, sid, null)};
          stats.uploaded++;
        }
        await saveMap();
      }
      for (final MapEntry(key: sid, value: f) in remoteBooks.entries) {
        if (localSids.contains(sid) || deleted.containsKey(sid)) continue;
        final j = await _getBook(f);
        final chapters = _chaptersOf(j);
        final id = await saveImported(
          ImportedBook(
            title: j['title'] as String? ?? 'Untitled',
            author: j['author'] as String? ?? '',
            format: (j['format'] as String?)?.isNotEmpty == true ? j['format'] as String : 'TXT',
            chapters: [for (final c in chapters) ImportedChapter(c.$1, c.$2)],
          ),
        );
        map['$id'] = {
          'sid': sid,
          'sig': bookSig([for (final c in chapters) c.$2.join('\n')]),
        };
        await saveMap();
        stats.downloaded++;
      }
    }

    // Reading positions: newest wins, applied with its own time so it doesn't bounce back.
    final best = <String, Map<String, dynamic>>{};
    for (final d in docs) {
      for (final MapEntry(key: sid, value: e) in Map<String, dynamic>.from(d['books'] as Map? ?? const {}).entries) {
        final m = Map<String, dynamic>.from(e as Map);
        if (best[sid] == null || (m['at'] as num? ?? 0) > (best[sid]!['at'] as num? ?? 0)) best[sid] = m;
      }
    }
    final locals = await Db.books();
    final mine = <String, Object>{};
    for (final b in locals) {
      final sid = (map['${b.id}'] as Map?)?['sid'] as String?;
      if (sid == null || deleted.containsKey(sid)) continue;
      final e = best[sid];
      var ch = b.curChapter, para = b.curPara, at = b.lastReadAt;
      if (e != null && (e['at'] as num? ?? 0) > b.lastReadAt && !(isOpen?.call(b.id!) ?? false)) {
        ch = ((e['ch'] as num?)?.toInt() ?? 0).clamp(0, max(0, b.chapterCount - 1));
        para = max(0, (e['para'] as num?)?.toInt() ?? 0);
        at = (e['at'] as num).toInt();
        await Db.setPositionAt(b.id!, ch, para, at);
        stats.positions++;
      }
      mine[sid] = {'ch': ch, 'para': para, 'at': at, 'title': b.title};
    }

    for (final sid in pending.keys) {
      final r = remoteBooks[sid];
      if (r != null) await drive.trash(r.id);
    }

    await drive.upload(
      fileId: ownFile?.id,
      folder: folder,
      name: ownName,
      props: {'lantern': 'progress', 'dev': deviceId},
      bytes: Uint8List.fromList(utf8.encode(jsonEncode({'v': 1, 'device': deviceName, 'at': now(), 'books': mine, 'deleted': ownDeleted}))),
      mime: 'application/json',
    );
    await Db.kvSet(SyncState.pending, '{}');
    await Db.kvSet(SyncState.last, '${now()}');
    return stats;
  }
}

/// SHA-1 fingerprint(s) of the certificate this installed copy is signed with ("AA:BB:…"); empty off Android.
Future<List<String>> appSigningSha1() async {
  if (!Platform.isAndroid) return const [];
  try {
    return ((await const MethodChannel('lantern/files').invokeMethod<List>('signingSha1')) ?? const []).cast<String>();
  } catch (_) {
    return const [];
  }
}

/// Signs in with Google and hands out Drive access tokens.
class GoogleAuth {
  bool _ready = false;
  GoogleSignInAccount? _user;

  Future<void> _init(String clientId) async {
    if (_ready) return;
    await GoogleSignIn.instance.initialize(serverClientId: clientId.isEmpty ? null : clientId);
    _ready = true;
  }

  /// A token for [driveScope], or null when the user must sign in again ([interactive] shows Google's screens).
  Future<String?> token(String clientId, {bool interactive = false}) async {
    await _init(clientId);
    _user ??= await GoogleSignIn.instance.attemptLightweightAuthentication();
    if (_user == null) {
      if (!interactive) return null;
      _user = await GoogleSignIn.instance.authenticate(scopeHint: const [driveScope]);
    }
    var a = await _user!.authorizationClient.authorizationForScopes(const [driveScope]);
    if (a == null && interactive) a = await _user!.authorizationClient.authorizeScopes(const [driveScope]);
    return a?.accessToken;
  }

  String get email => _user?.email ?? '';

  Future<void> signOut() async {
    _user = null;
    try {
      await GoogleSignIn.instance.disconnect();
    } catch (_) {}
  }
}

/// App-wide sync controller: sign-in state, automatic runs, status for the UI.
class DriveSyncController extends ChangeNotifier with WidgetsBindingObserver {
  final _auth = GoogleAuth();
  bool busy = false, paused = false;
  String error = '';
  int lastSync = 0;
  int? openBookId;
  Timer? _debounce, _tick;
  bool _started = false;
  String? _token;
  int _tokenAt = 0;

  String get email => settings.syncEmail;
  bool get signedIn => email.isNotEmpty;
  String get clientId => settings.googleClientId.isNotEmpty ? settings.googleClientId : buildGoogleClientId;

  /// Called once from the home screen.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    lastSync = int.tryParse(await Db.kvGet(SyncState.last) ?? '') ?? 0;
    if (signedIn) auto(delay: const Duration(seconds: 3));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!signedIn) return;
    if (state == AppLifecycleState.resumed && nowMs() - lastSync > 30000) auto(full: openBookId == null, delay: const Duration(seconds: 1));
    if (state == AppLifecycleState.paused) auto(full: false, delay: Duration.zero);
  }

  Future<String> _getToken({bool interactive = false}) async {
    if (_token != null && nowMs() - _tokenAt < 45 * 60 * 1000) return _token!;
    final t = await _auth.token(clientId, interactive: interactive);
    if (t == null) throw AuthExpired();
    _token = t;
    _tokenAt = nowMs();
    return t;
  }

  /// Sync soon (debounced). Safe to call often.
  void auto({bool full = true, Duration delay = const Duration(seconds: 4)}) {
    if (!signedIn || paused) return;
    _debounce?.cancel();
    _debounce = Timer(delay, () => run(full: full).catchError((_) => null));
  }

  Future<SyncStats?>? _running;

  Future<SyncStats?> run({bool full = true, bool interactive = false}) {
    return _running ??= _run(full, interactive).whenComplete(() => _running = null);
  }

  Future<SyncStats?> _run(bool full, bool interactive) async {
    if (!signedIn) return null;
    busy = true;
    error = '';
    notifyListeners();
    try {
      await _getToken(interactive: interactive);
      final engine = SyncEngine(HttpDrive(() => _getToken()), deviceName: 'Phone', isOpen: (id) => id == openBookId);
      final s = await engine.run(full: full);
      lastSync = nowMs();
      paused = false;
      if (s.downloaded > 0 || s.removed > 0 || s.positions > 0) bumpLibrary();
      return s;
    } on AuthExpired {
      _token = null;
      paused = true;
      return null;
    } catch (e) {
      error = '$e';
      rethrow;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// From a button: Google's sign-in screens, then a first sync.
  Future<SyncStats?> signIn() async {
    try {
      final t = await _auth.token(clientId, interactive: true);
      if (t == null) throw Exception('Google did not give access to Drive.');
      _token = t;
      _tokenAt = nowMs();
      var mail = _auth.email;
      if (mail.isEmpty) mail = await HttpDrive(() async => t).userEmail();
      settings.set('syncEmail', mail.isEmpty ? 'Google account' : mail);
      paused = false;
      return await run(interactive: true);
    } on GoogleSignInException catch (e) {
      // Android reports a rejected app (signing key or package not registered) as "canceled" too,
      // so explain both and show the key this copy is signed with.
      final sha = (await appSigningSha1()).join(' or ');
      final keyNote = sha.isEmpty
          ? ''
          : '\n\nThis copy of the app is signed with SHA-1:\n$sha\n\nOne of the Android OAuth clients in Google Cloud must have '
              'exactly this SHA-1 and the package com.lalli87.lantern_reader.';
      final what = switch (e.code) {
        GoogleSignInExceptionCode.canceled =>
          'Google sign-in did not finish. If you picked your account and came straight back here, Google did not accept this copy of the app.',
        GoogleSignInExceptionCode.clientConfigurationError => 'Google sign-in is not set up for this copy of the app. ${e.description ?? ''}',
        _ => 'Google sign-in failed: ${e.description ?? e.code.name}',
      };
      throw Exception('$what$keyNote');
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    _token = null;
    settings.set('syncEmail', '');
    paused = false;
    notifyListeners();
  }

  /// While a book is open, positions are shared every two minutes.
  void bookOpened(int id) {
    openBookId = id;
    if (!signedIn) return;
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(minutes: 2), (_) => auto(full: false, delay: Duration.zero));
  }

  void bookClosed(int id) {
    if (openBookId == id) openBookId = null;
    _tick?.cancel();
    _tick = null;
    auto(delay: const Duration(seconds: 2));
  }
}

final driveSync = DriveSyncController();
