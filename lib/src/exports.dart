import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

import 'ai.dart';
import 'app.dart';
import 'cloud_tts.dart';
import 'db.dart';
import 'models.dart';
import 'text_utils.dart';

/// Offers to share a generated file or drop it in the phone's Downloads folder.
Future<void> offerFile(BuildContext context, String name, Uint8List bytes) async {
  final tmp = await getTemporaryDirectory();
  final f = File(p.join(tmp.path, name));
  await f.writeAsBytes(bytes);
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text(fmtSize(bytes.length))),
        ListTile(
          leading: const Icon(Icons.share_outlined),
          title: const Text('Share or open with another app'),
          onTap: () async {
            Navigator.pop(c);
            await SharePlus.instance.share(ShareParams(files: [XFile(f.path)], subject: name));
          },
        ),
        if (Platform.isAndroid)
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Save to Downloads'),
            onTap: () async {
              Navigator.pop(c);
              try {
                final out = File('/storage/emulated/0/Download/$name');
                await out.writeAsBytes(bytes);
                if (context.mounted) toast(context, 'Saved to Downloads/$name');
              } catch (_) {
                if (context.mounted) toast(context, 'Could not write to Downloads. Use Share instead.');
              }
            },
          ),
      ]),
    ),
  );
}

// ---- audio files ----

/// Writes a WAV file incrementally so long chapters never sit in memory.
class WavWriter {
  final RandomAccessFile _f;
  int _rate = 0, _channels = 1, _bits = 16, _bytes = 0;
  WavWriter._(this._f);

  static Future<WavWriter> open(String path) async {
    final f = await File(path).open(mode: FileMode.write);
    await f.writeFrom(Uint8List(44));
    return WavWriter._(f);
  }

  Future<void> add(Uint8List pcm, int rate, {int channels = 1, int bits = 16}) async {
    if (_rate == 0) {
      _rate = rate;
      _channels = channels;
      _bits = bits;
    } else if (rate != _rate || channels != _channels || bits != _bits) {
      return;
    }
    await _f.writeFrom(pcm);
    _bytes += pcm.length;
  }

  Future<int> close() async {
    await _f.setPosition(0);
    await _f.writeFrom(pcmToWav(Uint8List(0), _rate == 0 ? 22050 : _rate, channels: _channels, bits: _bits)
      ..buffer.asByteData().setUint32(4, 36 + _bytes, Endian.little)
      ..buffer.asByteData().setUint32(40, _bytes, Endian.little));
    await _f.close();
    return _bytes;
  }
}

/// Folder where audio for [book] is written. Prefers the shared Audiobooks folder so any player can
/// find the files; falls back to the app's own storage.
Future<Directory> audioFolder(Book book) async {
  final name = safeFileName(book.title);
  if (Platform.isAndroid) {
    try {
      final d = Directory('/storage/emulated/0/Audiobooks/Lantern Reader/$name');
      await d.create(recursive: true);
      // Shared media folders only accept media files, so test with a tiny WAV.
      final probe = File(p.join(d.path, 'probe.wav'));
      await probe.writeAsBytes(pcmToWav(Uint8List(2), 22050));
      await probe.delete();
      return d;
    } catch (_) {}
    final ext = await getExternalStorageDirectory();
    if (ext != null) return Directory(p.join(ext.path, 'Audiobooks', name)).create(recursive: true);
  }
  final docs = await getApplicationDocumentsDirectory();
  return Directory(p.join(docs.path, 'Audiobooks', name)).create(recursive: true);
}

const _audioChannel = MethodChannel('lantern/audio');

/// Converts a WAV file to a compact AAC (.m4a) file with Android's built-in encoder.
/// Returns false where no encoder is available (the WAV is then kept).
Future<bool> wavToM4a(String wav, String out) async {
  if (!Platform.isAndroid) return false;
  try {
    await _audioChannel.invokeMethod('wavToM4a', {'wav': wav, 'out': out, 'bitrate': 64000});
    return File(out).existsSync() && File(out).lengthSync() > 0;
  } catch (_) {
    return false;
  }
}

/// File type produced for a voice source.
String audioExtFor(String source) => source == voiceGoogle ? 'mp3' : (Platform.isAndroid ? 'm4a' : 'wav');

/// Renders one chapter to an audio file with the phone voice, a Google Cloud voice (MP3) or a
/// Gemini voice. Phone and Gemini audio is encoded to M4A on Android. Returns the file path, or
/// null if cancelled or nothing was produced.
Future<String?> renderChapterAudio({
  required Book book,
  required ChapterMeta meta,
  required String source,
  required Directory dir,
  required bool Function() cancelled,
  void Function(double)? onProgress,
}) async {
  final ch = await Db.chapter(meta.id);
  if (ch == null) return null;
  final paras = splitParas(ch.content);
  final titleFirst = paras.isNotEmpty && paraText(paras.first).trim() == ch.title.trim();
  final limit = switch (source) { voiceGoogle => 1500, voiceGemini => 2400, _ => 3000 };
  final chunks = [
    if (!titleFirst && ch.title.isNotEmpty) SpeechChunk(-1, 0, 0, '${ch.title}.'),
    ...speechChunks(paras, maxLen: limit),
  ];
  // Group whole paragraphs up to the size limit so the voice keeps its flow.
  final batches = <String>[];
  final sb = StringBuffer();
  for (final c in chunks) {
    if (sb.isNotEmpty && sb.length + c.text.length + 1 > limit) {
      batches.add(sb.toString());
      sb.clear();
    }
    sb.writeln(c.text);
  }
  if (sb.isNotEmpty) batches.add(sb.toString());
  if (batches.isEmpty) return null;

  final name = '${(meta.idx + 1).toString().padLeft(4, '0')} - ${safeFileName(ch.title)}';
  final tmpDir = (await getTemporaryDirectory()).path;

  if (source == voiceGoogle) {
    // MP3 frames can simply be appended one after another.
    final path = p.join(dir.path, '$name.mp3');
    final out = await File(path).open(mode: FileMode.write);
    try {
      for (var i = 0; i < batches.length; i++) {
        if (cancelled()) break;
        await out.writeFrom(await googleSpeech(settings, applyReplacements(batches[i], settings.replacements)));
        onProgress?.call((i + 1) / batches.length);
      }
    } catch (_) {
      await out.close();
      File(path).deleteSync();
      rethrow;
    }
    await out.close();
    if (cancelled() || File(path).lengthSync() == 0) {
      File(path).deleteSync();
      return null;
    }
    return path;
  }

  final wavPath = p.join(tmpDir, 'export_$name.wav'.replaceAll(RegExp(r'[^\w.\- ]'), '_'));
  final w = await WavWriter.open(wavPath);
  final tmp = p.join(tmpDir, 'render.wav');
  try {
    for (var i = 0; i < batches.length; i++) {
      if (cancelled()) break;
      final text = applyReplacements(batches[i], settings.replacements);
      if (source == voiceGemini) {
        final (pcm, rate) = await geminiSpeech(settings, text);
        await w.add(pcm, rate);
      } else {
        final bytes = await narrator.renderWav(text, tmp);
        final wav = bytes == null ? null : parseWav(bytes);
        if (wav == null) throw Exception('The speech engine did not produce audio. Try a different engine or voice.');
        await w.add(wav.pcm, wav.sampleRate, channels: wav.channels, bits: wav.bits);
      }
      onProgress?.call((i + 1) / batches.length);
    }
  } catch (_) {
    await w.close();
    File(wavPath).deleteSync();
    rethrow;
  }
  final n = await w.close();
  if (cancelled() || n == 0) {
    File(wavPath).deleteSync();
    return null;
  }
  final m4a = p.join(dir.path, '$name.m4a');
  if (await wavToM4a(wavPath, m4a)) {
    File(wavPath).deleteSync();
    return m4a;
  }
  final keep = p.join(dir.path, '$name.wav');
  await File(wavPath).copy(keep);
  File(wavPath).deleteSync();
  return keep;
}

// ---- backup ----

/// Bundles the library database, covers and added fonts into one zip. API keys are left out.
Future<Uint8List> createBackup() async {
  final tmp = await getTemporaryDirectory();
  final copy = p.join(tmp.path, 'backup.db');
  if (File(copy).existsSync()) File(copy).deleteSync();
  try {
    await Db.db.execute("VACUUM INTO '${copy.replaceAll("'", "''")}'");
  } catch (_) {
    try {
      await Db.db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
    } catch (_) {}
    await File(Db.path).copy(copy);
  }
  final d = await databaseFactory.openDatabase(copy);
  await d.delete('kv', where: 'k=?', whereArgs: ['secrets']);
  await d.close();

  final a = Archive();
  a.addFile(ArchiveFile.bytes('lantern.db', await File(copy).readAsBytes()));
  for (final folder in ['covers', 'fonts']) {
    final dir = Directory(p.join(dataDir, folder));
    if (!dir.existsSync()) continue;
    for (final f in dir.listSync().whereType<File>()) {
      a.addFile(ArchiveFile.bytes('$folder/${p.basename(f.path)}', await f.readAsBytes()));
    }
  }
  File(copy).deleteSync();
  return ZipEncoder().encodeBytes(a);
}

/// Replaces the whole library with the contents of a backup zip.
Future<void> restoreBackup(Uint8List zip) async {
  final Archive a;
  try {
    a = ZipDecoder().decodeBytes(zip);
  } catch (_) {
    throw const FormatException('That file is not a Lantern Reader backup.');
  }
  final dbFile = a.files.where((f) => f.name == 'lantern.db').firstOrNull;
  if (dbFile == null) throw const FormatException('That file is not a Lantern Reader backup.');

  final tmp = await getTemporaryDirectory();
  final incoming = p.join(tmp.path, 'restore.db');
  await File(incoming).writeAsBytes(dbFile.readBytes()!);
  final check = await databaseFactory.openDatabase(incoming);
  try {
    await check.rawQuery('SELECT COUNT(*) FROM books');
  } catch (_) {
    await check.close();
    throw const FormatException('The backup is damaged.');
  }
  await check.close();

  final secrets = await Db.kvGet('secrets');
  final path = Db.path;
  await Db.close();
  for (final suffix in ['', '-wal', '-shm', '-journal']) {
    final f = File('$path$suffix');
    if (f.existsSync()) f.deleteSync();
  }
  await File(incoming).copy(path);
  for (final f in a.files) {
    if (!f.isFile || !(f.name.startsWith('covers/') || f.name.startsWith('fonts/'))) continue;
    final out = File(p.join(dataDir, p.dirname(f.name), p.basename(f.name)));
    await out.parent.create(recursive: true);
    await out.writeAsBytes(f.readBytes()!);
  }
  await Db.open(path);
  if (secrets != null) await Db.kvSet('secrets', secrets);
  await settings.load();
  await loadUserFonts();
  bumpLibrary();
}
