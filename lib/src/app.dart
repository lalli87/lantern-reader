import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import 'models.dart';
import 'narrator.dart';
import 'settings.dart';

/// App-wide singletons, set once in main().
late Settings settings;
late Narrator narrator;
late String dataDir;

String get coversDir => p.join(dataDir, 'covers');
String get fontsDir => p.join(dataDir, 'fonts');

/// Opens the main side panel; set by the home shell.
VoidCallback? openMainDrawer;

/// Hamburger button for top-level screens.
class MenuButton extends StatelessWidget {
  const MenuButton({super.key});
  @override
  Widget build(BuildContext context) =>
      IconButton(tooltip: 'Menu', icon: const Icon(Icons.menu), onPressed: () => openMainDrawer?.call());
}

/// Bumped whenever books change so lists refresh.
final libraryChanged = ValueNotifier<int>(0);
void bumpLibrary() => libraryChanged.value++;

const seedColor = Color(0xFFB5541C);

File? coverFile(Book b) {
  final c = b.coverPath;
  if (c == null || c.isEmpty) return null;
  final f = File(p.isAbsolute(c) ? c : p.join(coversDir, c));
  return f.existsSync() ? f : null;
}

final _loadedFonts = <String>{};

/// Registers a font file under [family] so it can be used for reading.
Future<bool> loadFontFile(String family, String path) async {
  if (_loadedFonts.contains(family)) return true;
  try {
    final bytes = await File(path).readAsBytes();
    final loader = FontLoader(family)..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
    _loadedFonts.add(family);
    return true;
  } catch (_) {
    return false;
  }
}

Future<void> loadUserFonts() async {
  for (final f in settings.userFonts) {
    await loadFontFile(f['name'] ?? '', p.join(fontsDir, f['file'] ?? ''));
  }
}

void toast(BuildContext context, String msg) {
  final m = ScaffoldMessenger.maybeOf(context);
  m?.hideCurrentSnackBar();
  m?.showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
}

Future<bool> confirm(BuildContext context, String title, String message, {String ok = 'OK', bool danger = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: Theme.of(c).colorScheme.error) : null,
          onPressed: () => Navigator.pop(c, true),
          child: Text(ok),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// Asks for a line (or block) of text. Returns null if cancelled.
Future<String?> promptText(BuildContext context, String title,
    {String initial = '', String? hint, String? help, bool multiline = false, bool secret = false, String ok = 'Save'}) {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (help != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(help)),
        TextField(
          controller: ctrl,
          autofocus: true,
          obscureText: secret,
          minLines: multiline ? 4 : 1,
          maxLines: multiline ? 10 : 1,
          decoration: InputDecoration(hintText: hint, border: const OutlineInputBorder()),
          onSubmitted: multiline ? null : (v) => Navigator.pop(c, v),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(c, ctrl.text), child: Text(ok)),
      ],
    ),
  );
}

/// Book cover: the real image if there is one, otherwise a coloured tile with the title's initials.
class CoverView extends StatelessWidget {
  final Book book;
  final double width;
  const CoverView(this.book, {super.key, this.width = 56});

  @override
  Widget build(BuildContext context) {
    final f = coverFile(book);
    final h = width * 1.45;
    Widget child;
    if (f != null) {
      child = Image.file(f, width: width, height: h, fit: BoxFit.cover, errorBuilder: (_, _, _) => _tile(h));
    } else {
      child = _tile(h);
    }
    return ClipRRect(borderRadius: BorderRadius.circular(width * 0.09), child: child);
  }

  Widget _tile(double h) {
    final hue = (book.title.hashCode % 360).abs().toDouble();
    final c1 = HSLColor.fromAHSL(1, hue, 0.42, 0.36).toColor();
    final c2 = HSLColor.fromAHSL(1, (hue + 28) % 360, 0.5, 0.24).toColor();
    final words = book.title.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final initials = words.take(2).map((w) => w.characters.first.toUpperCase()).join();
    return Container(
      width: width,
      height: h,
      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c1, c2])),
      alignment: Alignment.center,
      child: Text(initials,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: width * 0.38, fontWeight: FontWeight.w700)),
    );
  }
}

/// Friendly names for common speech engines.
String engineLabel(String pkg) => switch (pkg) {
      'com.samsung.SMT' => 'Samsung',
      'com.google.android.tts' => 'Google',
      '' => 'System default',
      _ => pkg.split('.').last,
    };
