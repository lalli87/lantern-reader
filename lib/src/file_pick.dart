import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';

/// A file chosen for import. [path] is a local copy; [temporary] copies are deleted after import.
class PickedFile {
  PickedFile(this.path, this.name, this.size, {this.temporary = false, this.error});
  final String path;
  final String name;
  final int size;
  final bool temporary;
  final String? error;

  Future<void> discard() async {
    if (!temporary || path.isEmpty) return;
    try {
      await File(path).delete();
    } catch (_) {}
  }
}

const _files = MethodChannel('lantern/files');

/// Lets the user pick files to import without loading them into memory.
///
/// On Android the file_selector plugin reads each file into one byte array and passes it over
/// the platform channel, which crashes the app on large PDFs. MainActivity streams the files
/// into the cache instead and returns their paths.
Future<List<PickedFile>> pickImportFiles() async {
  if (Platform.isAndroid) {
    final res = await _files.invokeListMethod<Map>('pickFiles') ?? const [];
    return [
      for (final m in res)
        PickedFile(
          (m['path'] as String?) ?? '',
          (m['name'] as String?) ?? 'file',
          (m['size'] as num?)?.toInt() ?? 0,
          temporary: true,
          error: m['error'] as String?,
        ),
    ];
  }
  final xs = await openFiles();
  return [for (final x in xs) PickedFile(x.path, x.name, await x.length())];
}

// ---- books opened or shared from other apps ----

const _incoming = MethodChannel('lantern/incoming');

/// Calls [onFiles] with books opened in Lantern Reader from another app ("Open with", "Share"), now and
/// whenever more arrive.
void listenIncoming(void Function(List<PickedFile> files) onFiles) {
  if (!Platform.isAndroid) return;
  Future<void> take() async {
    try {
      final res = await _incoming.invokeListMethod<Map>('take') ?? const [];
      if (res.isNotEmpty) onFiles(_picked(res));
    } catch (_) {}
  }

  _incoming.setMethodCallHandler((call) async {
    if (call.method == 'ready') await take();
  });
  take();
}

List<PickedFile> _picked(List<Map> res) => [
      for (final m in res)
        PickedFile(
          (m['path'] as String?) ?? '',
          (m['name'] as String?) ?? 'file',
          (m['size'] as num?)?.toInt() ?? 0,
          temporary: true,
          error: m['error'] as String?,
        ),
    ];

// ---- a folder of books on the phone ----

class FolderBook {
  FolderBook(this.uri, this.name, this.size, this.modified);
  final String uri, name;
  final int size, modified;
}

/// Lets the user choose a folder (such as Download); Android remembers the permission. Null if cancelled.
Future<String?> pickBookFolder() => _files.invokeMethod<String>('pickFolder');

/// Book files in the folder and its subfolders with one of [exts].
Future<List<FolderBook>> listBookFolder(String uri, List<String> exts) async {
  final res = await _files.invokeListMethod<Map>('listFolder', {'uri': uri, 'exts': exts}) ?? const [];
  return [
    for (final m in res)
      FolderBook('${m['uri']}', '${m['name']}', (m['size'] as num?)?.toInt() ?? 0, (m['modified'] as num?)?.toInt() ?? 0),
  ];
}

/// Copies chosen folder files into the app for import.
Future<List<PickedFile>> copyFolderBooks(List<String> uris) async =>
    _picked(await _files.invokeListMethod<Map>('copyUris', {'uris': uris}) ?? const []);

/// "primary:Download/Books" → "Download/Books".
String folderLabel(String uri) {
  final seg = Uri.decodeComponent(uri.split('/tree/').last.split('/').first);
  final i = seg.indexOf(':');
  final rest = i >= 0 ? seg.substring(i + 1) : seg;
  return rest.isEmpty ? 'Phone storage' : rest;
}
