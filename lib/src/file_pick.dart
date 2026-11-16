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
