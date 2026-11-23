import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import 'app.dart';
import 'db.dart';
import 'models.dart';

/// Comic books (CBZ, CBR, CB7, CBT, or a ZIP of pictures): the pages are kept as picture files in the
/// app's storage and shown in a page viewer. Each page is stored as a chapter ("Page 12") with no text,
/// so progress, the library and backups work as for other books.

const comicExtensions = ['cbz', 'cbr', 'cb7', 'cbt'];
bool isComicFormat(String format) => const {'CBZ', 'CBR', 'CB7', 'CBT'}.contains(format);

String get comicsDir => p.join(dataDir, 'comics');
Directory comicDir(int bookId) => Directory(p.join(comicsDir, 'book_$bookId'));

final _imageExt = RegExp(r'\.(jpe?g|png|gif|webp|bmp|avif)$', caseSensitive: false);
bool isImageName(String n) => _imageExt.hasMatch(n) && !n.contains('__MACOSX') && !p.basename(n).startsWith('.');

const _archive = MethodChannel('lantern/archive');

/// Compares names the way people expect: "page2" before "page10".
int naturalCompare(String a, String b) {
  final re = RegExp(r'(\d+)|(\D+)');
  final x = re.allMatches(a.toLowerCase()).toList(), y = re.allMatches(b.toLowerCase()).toList();
  for (var i = 0; i < x.length && i < y.length; i++) {
    final s = x[i].group(0)!, t = y[i].group(0)!;
    final c = x[i].group(1) != null && y[i].group(1) != null
        ? BigInt.parse(s).compareTo(BigInt.parse(t))
        : s.compareTo(t);
    if (c != 0) return c;
  }
  return x.length.compareTo(y.length);
}

/// Whether a ZIP file is a comic (mostly pictures, no book files) rather than a zipped book.
bool zipIsComic(String path) {
  try {
    final names = [for (final f in ZipDecoder().decodeStream(InputFileStream(path)).files) if (f.isFile) f.name];
    final images = names.where(isImageName).length;
    return images >= 3 && images >= names.length * 0.6;
  } catch (_) {
    return false;
  }
}

/// The page file names of a comic, in reading order.
List<File> comicPages(int bookId) {
  final d = comicDir(bookId);
  if (!d.existsSync()) return [];
  return d.listSync().whereType<File>().where((f) => isImageName(f.path)).toList()
    ..sort((a, b) => naturalCompare(p.basename(a.path), p.basename(b.path)));
}

Future<void> deleteComicPages(int bookId) async {
  try {
    final d = comicDir(bookId);
    if (await d.exists()) await d.delete(recursive: true);
  } catch (_) {}
}

/// Imports a comic archive at [path]; returns the new book's id.
Future<int> importComic(String path, String fileName, int fileSize) async {
  final tmp = Directory(p.join(comicsDir, 'import_${DateTime.now().microsecondsSinceEpoch}'));
  await tmp.create(recursive: true);
  try {
    String? info;
    final head = await File(path).openRead(0, 8).fold<List<int>>([], (a, b) => a..addAll(b));
    final zip = head.length >= 2 && head[0] == 0x50 && head[1] == 0x4B;
    final tar = !zip && await _isTar(path);
    var format = switch (p.extension(fileName).toLowerCase()) {
      '.cbr' => 'CBR',
      '.cb7' => 'CB7',
      '.cbt' => 'CBT',
      _ => 'CBZ',
    };
    if (zip || tar) {
      // Many .cbr files are really ZIPs; read them here.
      final a = zip ? ZipDecoder().decodeStream(InputFileStream(path)) : TarDecoder().decodeStream(InputFileStream(path));
      for (final f in a.files) {
        if (!f.isFile) continue;
        if (p.basename(f.name).toLowerCase() == 'comicinfo.xml') info = utf8.decode(f.readBytes()!, allowMalformed: true);
        if (!isImageName(f.name)) continue;
        await File(p.join(tmp.path, _flat(f.name))).writeAsBytes(f.readBytes()!);
      }
      if (zip && format != 'CBZ') format = 'CBZ';
    } else if (Platform.isAndroid) {
      try {
        await _archive.invokeMethod<int>('extract', {'path': path, 'out': tmp.path});
      } on PlatformException catch (e) {
        throw FormatException(switch (e.message ?? '') {
          final m when m.contains('rar5') =>
            'This comic uses the newer RAR 5 format, which Lantern can\'t open yet. Converting it to CBZ (for example with a free converter) will work.',
          final m when m.contains('unknown') => 'This file is not a comic archive Lantern recognises.',
          final m => 'This comic could not be opened ($m).',
        });
      }
      final ci = File(p.join(tmp.path, 'ComicInfo.xml'));
      if (await ci.exists()) {
        info = await ci.readAsString();
        await ci.delete();
      }
    } else {
      throw const FormatException('RAR and 7z comics can be opened on the phone.');
    }
    final pages = tmp.listSync().whereType<File>().where((f) => isImageName(f.path)).toList()
      ..sort((a, b) => naturalCompare(p.basename(a.path), p.basename(b.path)));
    if (pages.isEmpty) throw const FormatException('No pictures were found in this comic.');

    final meta = _comicInfo(info);
    final book = Book(
      title: meta['Title'] ?? _niceTitle(fileName),
      author: meta['Writer'] ?? '',
      series: meta['Series'] ?? '',
      seriesNo: double.tryParse(meta['Number'] ?? ''),
      description: meta['Summary'] ?? '',
      language: meta['LanguageISO'] ?? '',
      format: format,
      fileName: fileName,
      fileSize: fileSize,
    );
    if (book.series.isNotEmpty && meta['Title'] == null) {
      book.title = '${book.series}${book.seriesNo != null ? ' #${meta['Number']}' : ''}';
    }
    final id = await Db.insertBook(book);
    // The cover is the first page (set before the pages are added, as saving the book rewrites its counts).
    try {
      final c = File(p.join(coversDir, 'cover_$id.img'));
      await c.parent.create(recursive: true);
      await pages.first.copy(c.path);
      book.coverPath = c.path;
      await Db.updateBook(book);
    } catch (_) {}
    final dir = comicDir(id);
    if (await dir.exists()) await dir.delete(recursive: true);
    await dir.create(recursive: true);
    for (var i = 0; i < pages.length; i++) {
      await pages[i].rename(p.join(dir.path, '${(i + 1).toString().padLeft(5, '0')}${p.extension(pages[i].path).toLowerCase()}'));
      await Db.addChapter(id, 'Page ${i + 1}', '');
    }
    return id;
  } finally {
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  }
}

Future<bool> _isTar(String path) async {
  try {
    final b = await File(path).openRead(257, 262).fold<List<int>>([], (a, x) => a..addAll(x));
    return String.fromCharCodes(b) == 'ustar';
  } catch (_) {
    return false;
  }
}

/// A file name for a page that keeps its folder in the sort order ("ch1/p2.jpg" → "000_ch1__p2.jpg").
String _flat(String name) => name.replaceAll(RegExp(r'[\\/:]'), '__');

String _niceTitle(String fileName) =>
    p.basenameWithoutExtension(fileName).replaceAll(RegExp(r'[_]+'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

Map<String, String> _comicInfo(String? xml) {
  if (xml == null) return {};
  try {
    final doc = XmlDocument.parse(xml);
    return {
      for (final e in doc.rootElement.childElements)
        if (e.innerText.trim().isNotEmpty) e.name.local: e.innerText.trim(),
    };
  } catch (_) {
    return {};
  }
}

// ---- viewer ----

/// Swipe through a comic's pages; pinch or double-tap to zoom. Tap the left or right edge to turn the
/// page, the middle to show the controls. Right-to-left reading (manga) can be turned on per book.
class ComicScreen extends StatefulWidget {
  final int bookId;
  const ComicScreen({super.key, required this.bookId});
  @override
  State<ComicScreen> createState() => _ComicScreenState();
}

class _ComicScreenState extends State<ComicScreen> {
  Book? _book;
  List<File> _pages = [];
  PageController? _pc;
  int _page = 0;
  bool _bars = false, _rtl = false, _zoomed = false;
  final _tc = TransformationController();
  TapDownDetails? _doubleTap;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final b = await Db.book(widget.bookId);
    if (b == null) return;
    _rtl = await Db.kvGet('comic.rtl.${b.id}') == '1';
    final pages = comicPages(b.id!);
    final start = b.curChapter.clamp(0, pages.isEmpty ? 0 : pages.length - 1);
    if (!mounted) return;
    setState(() {
      _book = b;
      _pages = pages;
      _page = start;
      _pc = PageController(initialPage: start);
    });
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _pc?.dispose();
    _tc.dispose();
    super.dispose();
  }

  void _onPage(int i) {
    _tc.value = Matrix4.identity();
    setState(() {
      _page = i;
      _zoomed = false;
    });
    Db.savePosition(widget.bookId, i, 0, within: i == _pages.length - 1 ? 1 : 0);
  }

  void _go(int delta) {
    final to = _page + delta;
    if (to < 0 || to >= _pages.length) return;
    _pc?.animateToPage(to, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
  }

  void _toggleBars() {
    setState(() => _bars = !_bars);
    SystemChrome.setEnabledSystemUIMode(_bars ? SystemUiMode.edgeToEdge : SystemUiMode.immersiveSticky);
  }

  void _tap(TapUpDetails d, double width) {
    final x = d.localPosition.dx / width;
    if (x < 0.3) {
      _go(_rtl ? 1 : -1);
    } else if (x > 0.7) {
      _go(_rtl ? -1 : 1);
    } else {
      _toggleBars();
    }
  }

  void _zoomAt() {
    final pos = _doubleTap?.localPosition ?? Offset.zero;
    if (_zoomed) {
      _tc.value = Matrix4.identity();
    } else {
      const s = 2.5;
      _tc.value = Matrix4.identity()
        ..translateByDouble(-pos.dx * (s - 1), -pos.dy * (s - 1), 0, 1)
        ..scaleByDouble(s, s, 1, 1);
    }
    setState(() => _zoomed = !_zoomed);
  }

  @override
  Widget build(BuildContext context) {
    final b = _book, pc = _pc;
    if (b == null || pc == null) return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator()));
    if (_pages.isEmpty) {
      return Scaffold(appBar: AppBar(title: Text(b.title)), body: const Center(child: Text('The pages of this comic are missing.')));
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        LayoutBuilder(
          builder: (context, box) => GestureDetector(
            onTapUp: (d) => _tap(d, box.maxWidth),
            onDoubleTapDown: (d) => _doubleTap = d,
            onDoubleTap: _zoomAt,
            child: PageView.builder(
              controller: pc,
              reverse: _rtl,
              physics: _zoomed ? const NeverScrollableScrollPhysics() : const PageScrollPhysics(),
              itemCount: _pages.length,
              onPageChanged: _onPage,
              itemBuilder: (_, i) => InteractiveViewer(
                transformationController: i == _page ? _tc : null,
                minScale: 1,
                maxScale: 5,
                onInteractionEnd: (_) {
                  final z = _tc.value.getMaxScaleOnAxis() > 1.05;
                  if (z != _zoomed) setState(() => _zoomed = z);
                },
                child: Center(
                  child: Image.file(_pages[i], fit: BoxFit.contain, width: box.maxWidth, height: box.maxHeight, filterQuality: FilterQuality.medium,
                      errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48)),
                ),
              ),
            ),
          ),
        ),
        if (_bars) ...[
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Material(
              color: Colors.black.withValues(alpha: 0.75),
              child: SafeArea(
                bottom: false,
                child: Row(children: [
                  const BackButton(color: Colors.white),
                  Expanded(child: Text(b.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 17))),
                  IconButton(
                    tooltip: _rtl ? 'Reading right to left (manga)' : 'Reading left to right',
                    icon: Icon(_rtl ? Icons.format_textdirection_r_to_l : Icons.format_textdirection_l_to_r, color: Colors.white),
                    onPressed: () async {
                      setState(() => _rtl = !_rtl);
                      await Db.kvSet('comic.rtl.${b.id}', _rtl ? '1' : '0');
                      if (context.mounted) toast(context, _rtl ? 'Right to left, like manga' : 'Left to right');
                    },
                  ),
                ]),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Material(
              color: Colors.black.withValues(alpha: 0.75),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Row(children: [
                    Expanded(
                      child: Directionality(
                        textDirection: _rtl ? TextDirection.rtl : TextDirection.ltr,
                        child: Slider(
                          value: _page.toDouble(),
                          max: (_pages.length - 1).toDouble().clamp(0, double.infinity),
                          divisions: _pages.length > 1 ? _pages.length - 1 : null,
                          onChanged: (v) => pc.jumpToPage(v.round()),
                        ),
                      ),
                    ),
                    Text('${_page + 1} / ${_pages.length}', style: const TextStyle(color: Colors.white)),
                  ]),
                ),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}
