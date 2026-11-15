import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'src/app.dart';
import 'src/browser.dart';
import 'src/db.dart';
import 'src/library.dart';
import 'src/narration_ui.dart';
import 'src/narrator.dart';
import 'src/notes.dart';
import 'src/reader.dart';
import 'src/settings.dart';
import 'src/settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  dataDir = (await getApplicationDocumentsDirectory()).path;
  await Db.open(p.join(dataDir, 'lantern.db'));
  settings = Settings();
  await settings.load();
  await loadUserFonts();
  try {
    narrator = await AudioService.init(
      builder: () => Narrator(settings),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.lalli87.lantern_reader.narration',
        androidNotificationChannelName: 'Narration',
        androidNotificationIcon: 'drawable/ic_stat_narration',
        androidStopForegroundOnPause: false,
      ),
    );
  } catch (e) {
    // Narration still works in the foreground if the media service cannot start.
    debugPrint('Media service unavailable: $e');
    narrator = Narrator(settings);
  }
  runApp(const LanternApp());
}

class LanternApp extends StatelessWidget {
  const LanternApp({super.key});

  @override
  Widget build(BuildContext context) {
    ThemeData theme(Brightness b) => ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: seedColor, brightness: b),
          appBarTheme: const AppBarTheme(centerTitle: false),
        );
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp(
        title: 'Lantern Reader',
        debugShowCheckedModeBanner: false,
        theme: theme(Brightness.light),
        darkTheme: theme(Brightness.dark),
        themeMode: switch (settings.appTheme) { 'light' => ThemeMode.light, 'dark' => ThemeMode.dark, _ => ThemeMode.system },
        home: const HomeShell(),
      ),
    );
  }
}

/// Home: one section at a time, chosen from a ReadEra-style side panel, with the mini player at the bottom.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

enum _Section { library, web, notes, settings }

class _HomeShellState extends State<HomeShell> {
  final _scaffold = GlobalKey<ScaffoldState>();
  final _libraryKey = GlobalKey<LibraryState>();
  final _notesKey = GlobalKey<NotesState>();
  final _browserKey = GlobalKey<BrowserScreenState>();
  _Section _section = _Section.library;
  bool _browserBuilt = false;
  // What the panel highlights: a library filter, a grouping, or a notes tab.
  String _selected = 'all';

  @override
  void initState() {
    super.initState();
    openMainDrawer = () => _scaffold.currentState?.openDrawer();
    narrator.error.addListener(_onNarratorError);
    if (settings.openLastBook) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final books = (await Db.books()).where((b) => b.lastReadAt > 0 && b.chapterCount > 0).toList()
          ..sort((a, b) => b.lastReadAt.compareTo(a.lastReadAt));
        if (books.isNotEmpty && mounted) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => ReaderScreen(bookId: books.first.id!)));
        }
      });
    }
  }

  @override
  void dispose() {
    openMainDrawer = null;
    narrator.error.removeListener(_onNarratorError);
    super.dispose();
  }

  void _onNarratorError() {
    final e = narrator.error.value;
    if (e != null && mounted) toast(context, e);
  }

  void _go(_Section s, String selected, [void Function()? then]) {
    Navigator.pop(context); // close the panel
    setState(() {
      _section = s;
      _selected = selected;
      if (s == _Section.web) _browserBuilt = true;
    });
    if (then != null) WidgetsBinding.instance.addPostFrameCallback((_) => then());
  }

  void _library(LibFilter f, {String group = 'none'}) =>
      _go(_Section.library, group == 'none' ? f.name : group, () => _libraryKey.currentState?.show(filter: f, group: group));

  void _notes(int tab, String key) => _go(_Section.notes, key, () => _notesKey.currentState?.showTab(tab));

  Widget _drawer() {
    final counts = _libraryKey.currentState?.counts ?? const <LibFilter, int>{};
    final cs = Theme.of(context).colorScheme;
    Widget item(String key, IconData icon, String label, VoidCallback onTap, {int? count}) => ListTile(
          selected: _selected == key,
          selectedTileColor: cs.secondaryContainer,
          shape: const StadiumBorder(),
          leading: Icon(icon),
          title: Text(label),
          trailing: count == null || count == 0 ? null : Text('$count', style: TextStyle(color: cs.onSurfaceVariant)),
          onTap: onTap,
        );
    Widget lib(LibFilter f, IconData icon) => item(f.name, icon, libFilterLabels[f]!, () => _library(f), count: counts[f]);
    return NavigationDrawer(
      selectedIndex: null,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 16, 12),
          child: Row(children: [
            ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.asset('assets/icon.png', width: 44, height: 44)),
            const SizedBox(width: 14),
            Text('Lantern Reader', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(children: [
            lib(LibFilter.reading, Icons.autorenew),
            lib(LibFilter.all, Icons.menu_book_outlined),
            lib(LibFilter.favorites, Icons.star_border),
            lib(LibFilter.toRead, Icons.schedule),
            lib(LibFilter.finished, Icons.done_all),
            item('author', Icons.person_outline, 'Authors', () => _library(LibFilter.all, group: 'author')),
            item('series', Icons.sell_outlined, 'Series', () => _library(LibFilter.all, group: 'series')),
            item('shelf', Icons.collections_bookmark_outlined, 'Shelves', () => _library(LibFilter.all, group: 'shelf')),
            item('format', Icons.layers_outlined, 'Formats', () => _library(LibFilter.all, group: 'format')),
            const Divider(height: 20),
            item('web', Icons.public, 'Web browser', () => _go(_Section.web, 'web')),
            item('quotes', Icons.format_quote_outlined, 'Highlights & notes', () => _notes(0, 'quotes')),
            item('bookmarks', Icons.bookmarks_outlined, 'Bookmarks', () => _notes(1, 'bookmarks')),
            item('glossary', Icons.translate, 'Glossary', () => _notes(2, 'glossary')),
            const Divider(height: 20),
            lib(LibFilter.trash, Icons.delete_outline),
            item('settings', Icons.settings_outlined, 'Settings', () => _go(_Section.settings, 'settings')),
            const SizedBox(height: 16),
          ]),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _section == _Section.library,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_scaffold.currentState?.isDrawerOpen ?? false) return;
        if (_section == _Section.web && await (_browserKey.currentState?.goBack() ?? Future.value(false))) return;
        setState(() {
          _section = _Section.library;
          _selected = 'all';
        });
      },
      child: Scaffold(
        key: _scaffold,
        drawer: _drawer(),
        onDrawerChanged: (open) {
          if (!open) return;
          setState(() {
            if (_section == _Section.library) _selected = _libraryKey.currentState?.selectionKey ?? _selected;
          });
        },
        body: IndexedStack(index: _section.index, children: [
          LibraryScreen(key: _libraryKey, onOpenBrowser: () {
            setState(() {
              _section = _Section.web;
              _selected = 'web';
              _browserBuilt = true;
            });
          }),
          _browserBuilt ? BrowserScreen(key: _browserKey) : const SizedBox.shrink(),
          NotesScreen(key: _notesKey),
          const SettingsScreen(),
        ]),
        bottomNavigationBar: SafeArea(
          top: false,
          child: MiniPlayer(
            onOpen: (s) => Navigator.push(
                context, MaterialPageRoute(builder: (_) => ReaderScreen(bookId: s.bookId!, chapterIdx: s.chapterIdx, para: s.para < 0 ? 0 : s.para))),
          ),
        ),
      ),
    );
  }
}
