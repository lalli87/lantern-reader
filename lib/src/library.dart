import 'package:flutter/material.dart';

import 'app.dart';
import 'book_detail.dart';
import 'db.dart';
import 'file_pick.dart';
import 'importers.dart';
import 'pdf_import.dart';
import 'models.dart';
import 'narration_ui.dart';
import 'reader.dart';
import 'text_utils.dart';

enum LibFilter { reading, all, favorites, toRead, finished, trash }

const libFilterLabels = _filterLabels;

const _filterLabels = {
  LibFilter.reading: 'Reading now',
  LibFilter.all: 'All books',
  LibFilter.favorites: 'Favourites',
  LibFilter.toRead: 'To read',
  LibFilter.finished: 'Finished',
  LibFilter.trash: 'Trash',
};

const _sortLabels = {
  'recent': 'Last opened',
  'added': 'Date added',
  'title': 'Title',
  'author': 'Author',
  'size': 'Length',
  'format': 'Format',
};

const _groupTitles = {'author': 'Authors', 'series': 'Series', 'format': 'Formats', 'shelf': 'Shelves'};

const _groupLabels = {'none': 'No grouping', 'author': 'By author', 'series': 'By series', 'format': 'By format', 'shelf': 'By shelf'};

class LibraryScreen extends StatefulWidget {
  final VoidCallback onOpenBrowser;
  const LibraryScreen({super.key, required this.onOpenBrowser});

  @override
  State<LibraryScreen> createState() => LibraryState();
}

class LibraryState extends State<LibraryScreen> {
  List<Book> _books = [], _trash = [];
  List<Shelf> _shelves = [];
  Map<int, Set<int>> _shelfBooks = {};
  LibFilter _filter = LibFilter.all;
  String _group = 'none', _query = '';
  bool _searching = false, _loaded = false, _importing = false;
  String _importStatus = '';

  @override
  void initState() {
    super.initState();
    libraryChanged.addListener(_load);
    settings.addListener(_refresh);
    _load(first: true);
  }

  @override
  void dispose() {
    libraryChanged.removeListener(_load);
    settings.removeListener(_refresh);
    super.dispose();
  }

  /// Called from the side panel.
  void show({LibFilter? filter, String? group}) {
    setState(() {
      if (filter != null) _filter = filter;
      if (group != null) _group = group;
      _searching = false;
      _query = '';
    });
  }

  /// Which side-panel entry matches what is shown.
  String get selectionKey => _group == 'none' ? _filter.name : _group;

  /// Book counts for the side panel.
  Map<LibFilter, int> get counts => {
        LibFilter.reading: _books.where((b) => b.lastReadAt > 0 && b.shelf != shelfFinished).length,
        LibFilter.all: _books.length,
        LibFilter.favorites: _books.where((b) => b.favorite).length,
        LibFilter.toRead: _books.where((b) => b.shelf == shelfToRead).length,
        LibFilter.finished: _books.where((b) => b.shelf == shelfFinished).length,
        LibFilter.trash: _trash.length,
      };

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _load({bool first = false}) async {
    final b = await Db.books(), t = await Db.books(trashed: true), s = await Db.shelves();
    final sb = {for (final x in s) x.id: await Db.bookIdsOn(x.id)};
    if (!mounted) return;
    setState(() {
      _books = b;
      _trash = t;
      _shelves = s;
      _shelfBooks = sb;
      if (first && b.any((x) => x.lastReadAt > 0 && x.shelf != shelfFinished)) _filter = LibFilter.reading;
      _loaded = true;
    });
  }

  List<Book> get _visible {
    var list = switch (_filter) {
      LibFilter.reading => _books.where((b) => b.lastReadAt > 0 && b.shelf != shelfFinished).toList(),
      LibFilter.all => List.of(_books),
      LibFilter.favorites => _books.where((b) => b.favorite).toList(),
      LibFilter.toRead => _books.where((b) => b.shelf == shelfToRead).toList(),
      LibFilter.finished => _books.where((b) => b.shelf == shelfFinished).toList(),
      LibFilter.trash => List.of(_trash),
    };
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((b) => '${b.title}\n${b.author}\n${b.series}\n${b.format}\n${b.language}'.toLowerCase().contains(q)).toList();
    }
    final by = _filter == LibFilter.reading && settings.sortBy == 'recent' ? 'recent' : settings.sortBy;
    int cmp(Book a, Book b) => switch (by) {
          'title' => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
          'author' => a.author.toLowerCase().compareTo(b.author.toLowerCase()),
          'added' => a.addedAt.compareTo(b.addedAt),
          'size' => a.charCount.compareTo(b.charCount),
          'format' => a.format.compareTo(b.format),
          _ => (a.lastReadAt == 0 ? a.addedAt : a.lastReadAt).compareTo(b.lastReadAt == 0 ? b.addedAt : b.lastReadAt),
        };
    list.sort((a, b) => settings.sortAsc ? cmp(a, b) : cmp(b, a));
    return list;
  }

  // ---- actions ----

  Future<void> _open(Book b) async {
    if (b.trashedAt > 0 || b.chapterCount == 0) return _details(b);
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ReaderScreen(bookId: b.id!)));
    _load();
  }

  Future<void> _details(Book b) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => BookDetailScreen(bookId: b.id!)));
    _load();
  }

  Future<void> _import() async {
    // No type filter: Android cannot map extensions such as .md or .fb2 and would grey those files out.
    setState(() => _importStatus = '');
    final List<PickedFile> files;
    try {
      files = await pickImportFiles();
    } catch (_) {
      if (mounted) toast(context, 'Could not open the file picker.');
      return;
    }
    if (files.isEmpty || !mounted) return;
    setState(() => _importing = true);
    var ok = 0;
    final problems = <String>[];
    int? last;
    for (final x in files) {
      try {
        if (x.error != null || x.path.isEmpty) {
          problems.add('${x.name}: could not be copied from storage');
          continue;
        }
        if (!importExtensions.contains(x.name.split('.').last.toLowerCase())) {
          problems.add('${x.name}: this file type is not supported yet');
          continue;
        }
        if (_books.any((b) => b.fileName == x.name && b.fileSize == x.size)) {
          problems.add('${x.name}: already in your library');
          continue;
        }
        if (mounted) setState(() => _importStatus = files.length > 1 ? 'Reading ${x.name}' : '');
        final parsed = await parseBookFile(x.path, x.name, onProgress: (done, total) {
          if (!mounted || total < 20 || done % 5 != 0 && done != total) return;
          setState(() => _importStatus = '${files.length > 1 ? '${x.name}\n' : ''}Reading page $done of $total');
        });
        last = await saveImported(parsed, fileName: x.name, fileSize: x.size, coversDir: coversDir);
        ok++;
      } on FormatException catch (e) {
        problems.add('${x.name}: ${e.message}');
      } catch (e) {
        problems.add('${x.name}: could not be read');
      } finally {
        await x.discard();
      }
    }
    bumpLibrary();
    if (!mounted) return;
    setState(() {
      _importing = false;
      _filter = LibFilter.all;
    });
    if (problems.isEmpty) {
      toast(context, 'Added $ok book${ok == 1 ? '' : 's'}.');
    } else {
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(ok > 0 ? 'Added $ok, skipped ${problems.length}' : 'Nothing was added'),
          content: SingleChildScrollView(child: Text(problems.join('\n\n'))),
          actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
        ),
      );
    }
    if (ok == 1 && last != null && files.length == 1 && mounted) {
      final b = await Db.book(last);
      if (b != null && mounted) _open(b);
    }
  }

  Future<void> _newBook({bool paste = false}) async {
    final title = await promptText(context, paste ? 'Paste text as a book' : 'New empty book', hint: 'Book title', ok: paste ? 'Next' : 'Create');
    if (title == null || title.trim().isEmpty || !mounted) return;
    String? text;
    if (paste) {
      text = await promptText(context, 'Text', hint: 'Paste the text here', multiline: true, ok: 'Add');
      if (text == null || text.trim().isEmpty) return;
    }
    final id = await Db.insertBook(Book(title: title.trim(), format: paste ? 'TXT' : 'WEB'));
    if (text != null) await Db.addChapter(id, title.trim(), plainToParagraphs(text).join('\n'));
    bumpLibrary();
    if (mounted) toast(context, paste ? 'Book added.' : 'Book created. Save chapters into it from the Web tab.');
  }

  void _addMenu() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.public),
            title: const Text('Save chapters from a website'),
            subtitle: const Text('Open the Web tab, go to a chapter and tap Save chapter'),
            onTap: () {
              Navigator.pop(c);
              widget.onOpenBrowser();
            },
          ),
          ListTile(
            leading: const Icon(Icons.file_open_outlined),
            title: const Text('Import book files'),
            subtitle: const Text('PDF, EPUB, TXT, Markdown, HTML, FB2, DOCX, ODT'),
            onTap: () {
              Navigator.pop(c);
              _import();
            },
          ),
          ListTile(
            leading: const Icon(Icons.content_paste),
            title: const Text('Paste text'),
            onTap: () {
              Navigator.pop(c);
              _newBook(paste: true);
            },
          ),
          ListTile(
            leading: const Icon(Icons.create_new_folder_outlined),
            title: const Text('New empty book'),
            onTap: () {
              Navigator.pop(c);
              _newBook();
            },
          ),
        ]),
      ),
    );
  }

  Future<void> _bookMenu(Book b, String v) async {
    switch (v) {
      case 'details':
        return _details(b);
      case 'listen':
        narrator.start(b.id!, b.curChapter, b.curPara);
        if (mounted) showNarrationPanel(context);
      case 'fav':
        b.favorite = !b.favorite;
        await Db.updateBook(b);
      case 'toread':
        b.shelf = b.shelf == shelfToRead ? shelfNone : shelfToRead;
        await Db.updateBook(b);
      case 'finished':
        b.shelf = b.shelf == shelfFinished ? shelfNone : shelfFinished;
        await Db.updateBook(b);
      case 'trash':
        await Db.setTrashed(b.id!, true);
        if (mounted) toast(context, 'Moved to trash.');
      case 'restore':
        await Db.setTrashed(b.id!, false);
      case 'delete':
        if (!await confirm(context, 'Delete “${b.title}”?', 'Its chapters, bookmarks and highlights are removed for good.', ok: 'Delete', danger: true)) return;
        if (narrator.book?.id == b.id) await narrator.stop();
        await Db.deleteBook(b.id!);
    }
    _load();
  }

  Widget _menuButton(Book b) => PopupMenuButton<String>(
        onSelected: (v) => _bookMenu(b, v),
        itemBuilder: (c) => b.trashedAt > 0
            ? const [
                PopupMenuItem(value: 'restore', child: Text('Restore')),
                PopupMenuItem(value: 'delete', child: Text('Delete permanently')),
              ]
            : [
                const PopupMenuItem(value: 'details', child: Text('Details')),
                if (b.chapterCount > 0) const PopupMenuItem(value: 'listen', child: Text('Listen')),
                PopupMenuItem(value: 'fav', child: Text(b.favorite ? 'Remove from favourites' : 'Add to favourites')),
                PopupMenuItem(value: 'toread', child: Text(b.shelf == shelfToRead ? 'Remove from To read' : 'Mark as To read')),
                PopupMenuItem(value: 'finished', child: Text(b.shelf == shelfFinished ? 'Mark as not finished' : 'Mark as finished')),
                const PopupMenuItem(value: 'trash', child: Text('Move to trash')),
              ],
      );

  // ---- tiles ----

  String _meta(Book b) => [
        b.format,
        '${b.chapterCount} ch',
        if (b.fileSize > 0) fmtSize(b.fileSize),
      ].join(' · ');

  Widget _tile(Book b) {
    final tt = Theme.of(context).textTheme, cs = Theme.of(context).colorScheme;
    if (settings.libraryView == 'compact') {
      return ListTile(
        dense: true,
        title: Text(b.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text([if (b.author.isNotEmpty) b.author, _meta(b), '${(b.progress * 100).round()}%'].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: _menuButton(b),
        onTap: () => _open(b),
        onLongPress: () => _details(b),
      );
    }
    return InkWell(
      onTap: () => _open(b),
      onLongPress: () => _details(b),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CoverView(b, width: 62),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(b.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700, height: 1.2)),
              if (b.author.isNotEmpty) Text(b.author, maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.bodyMedium),
              const SizedBox(height: 2),
              Text(_meta(b), style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: LinearProgressIndicator(value: b.progress, minHeight: 5, borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 10),
                SizedBox(width: 38, child: Text('${(b.progress * 100).round()}%', style: tt.bodySmall)),
                if (b.favorite) Icon(Icons.star, size: 16, color: cs.primary),
                if (b.shelf == shelfFinished) Padding(padding: const EdgeInsets.only(left: 4), child: Icon(Icons.done_all, size: 16, color: cs.primary)),
                if (b.shelf == shelfToRead) Padding(padding: const EdgeInsets.only(left: 4), child: Icon(Icons.schedule, size: 16, color: cs.primary)),
              ]),
            ]),
          ),
          _menuButton(b),
        ]),
      ),
    );
  }

  Widget _gridTile(Book b, double w) {
    final tt = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _open(b),
      onLongPress: () => _details(b),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Stack(children: [
          CoverView(b, width: w),
          if (b.progress > 0)
            Positioned(left: 0, right: 0, bottom: 0, child: LinearProgressIndicator(value: b.progress, minHeight: 4)),
        ]),
        const SizedBox(height: 6),
        Text(b.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600, height: 1.2)),
        if (b.author.isNotEmpty) Text(b.author, maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.bodySmall),
      ]),
    );
  }

  Widget _booksView(List<Book> list) {
    if (settings.libraryView == 'grid') {
      return LayoutBuilder(builder: (c, cons) {
        final cols = (cons.maxWidth / 128).floor().clamp(2, 8);
        final w = (cons.maxWidth - 32 - (cols - 1) * 14) / cols;
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols, crossAxisSpacing: 14, mainAxisSpacing: 14, mainAxisExtent: w * 1.45 + 62),
          itemCount: list.length,
          itemBuilder: (c, i) => _gridTile(list[i], w),
        );
      });
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: list.length,
      itemBuilder: (c, i) => _tile(list[i]),
    );
  }

  Widget _grouped(List<Book> list) {
    final groups = <String, List<Book>>{};
    void put(String k, Book b) => (groups[k] ??= []).add(b);
    for (final b in list) {
      switch (_group) {
        case 'author':
          put(b.author.isEmpty ? 'Unknown author' : b.author, b);
        case 'series':
          put(b.series.isEmpty ? 'Not in a series' : b.series, b);
        case 'format':
          put(b.format, b);
        case 'shelf':
          final on = _shelves.where((s) => _shelfBooks[s.id]?.contains(b.id) ?? false).toList();
          if (on.isEmpty) put('Not on a shelf', b);
          for (final s in on) {
            put(s.name, b);
          }
      }
    }
    final keys = groups.keys.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    if (_group == 'series') {
      for (final g in groups.values) {
        g.sort((a, b) => (a.seriesNo ?? 1e9).compareTo(b.seriesNo ?? 1e9));
      }
    }
    return ListView(padding: const EdgeInsets.only(bottom: 96), children: [
      for (final k in keys)
        ExpansionTile(
          title: Text(k, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('${groups[k]!.length} book${groups[k]!.length == 1 ? '' : 's'}'),
          trailing: _group == 'shelf' && _shelves.any((s) => s.name == k)
              ? PopupMenuButton<String>(
                  onSelected: (v) async {
                    final s = _shelves.firstWhere((s) => s.name == k);
                    if (v == 'rename') {
                      final n = await promptText(context, 'Rename shelf', initial: s.name);
                      if (n != null && n.trim().isNotEmpty) await Db.renameShelf(s.id, n.trim());
                    } else if (await confirm(context, 'Remove shelf “${s.name}”?', 'The books stay in your library.', ok: 'Remove')) {
                      await Db.deleteShelf(s.id);
                    }
                    _load();
                  },
                  itemBuilder: (c) => const [
                    PopupMenuItem(value: 'rename', child: Text('Rename shelf')),
                    PopupMenuItem(value: 'delete', child: Text('Remove shelf')),
                  ],
                )
              : null,
          children: [for (final b in groups[k]!) _tile(b)],
        ),
    ]);
  }

  Widget _empty() {
    final cs = Theme.of(context).colorScheme, tt = Theme.of(context).textTheme;
    final none = _books.isEmpty && _filter != LibFilter.trash;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(none ? Icons.auto_stories_outlined : Icons.inbox_outlined, size: 64, color: cs.outline),
          const SizedBox(height: 16),
          Text(
            none ? 'Your library is empty' : (_query.isNotEmpty ? 'No books match “$_query”' : 'Nothing in ${_filterLabels[_filter]!.toLowerCase()}'),
            style: tt.titleMedium,
            textAlign: TextAlign.center,
          ),
          if (none) ...[
            const SizedBox(height: 8),
            Text('Save chapters from a website in the Web tab, or import book files you already have.',
                textAlign: TextAlign.center, style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 20),
            FilledButton.icon(icon: const Icon(Icons.public), label: const Text('Open the web browser'), onPressed: widget.onOpenBrowser),
            const SizedBox(height: 8),
            OutlinedButton.icon(icon: const Icon(Icons.file_open_outlined), label: const Text('Import book files'), onPressed: _import),
          ],
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _visible;
    final view = settings.libraryView;
    return Scaffold(
      appBar: AppBar(
        leading: const MenuButton(),
        title: _searching
            ? TextField(
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Title, author, series, format…', border: InputBorder.none),
                onChanged: (v) => setState(() => _query = v),
              )
            : Text(_group == 'none' ? _filterLabels[_filter]! : _groupTitles[_group]!),
        actions: [
          IconButton(
            tooltip: _searching ? 'Close search' : 'Search',
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) _query = '';
            }),
          ),
          PopupMenuButton<String>(
            tooltip: 'Sort',
            icon: const Icon(Icons.sort),
            onSelected: (v) => v == 'dir' ? settings.set('sortAsc', !settings.sortAsc) : settings.set('sortBy', v),
            itemBuilder: (c) => [
              for (final e in _sortLabels.entries) CheckedPopupMenuItem(value: e.key, checked: settings.sortBy == e.key, child: Text(e.value)),
              const PopupMenuDivider(),
              PopupMenuItem(value: 'dir', child: Text(settings.sortAsc ? 'Ascending ↑ (tap to reverse)' : 'Descending ↓ (tap to reverse)')),
            ],
          ),
          PopupMenuButton<String>(
            tooltip: 'Layout and grouping',
            icon: Icon(view == 'grid' ? Icons.grid_view : (view == 'compact' ? Icons.view_headline : Icons.view_agenda_outlined)),
            onSelected: (v) => v.startsWith('g:') ? setState(() => _group = v.substring(2)) : settings.set('libraryView', v),
            itemBuilder: (c) => [
              CheckedPopupMenuItem(value: 'list', checked: view == 'list', child: const Text('Detailed list')),
              CheckedPopupMenuItem(value: 'compact', checked: view == 'compact', child: const Text('Compact list')),
              CheckedPopupMenuItem(value: 'grid', checked: view == 'grid', child: const Text('Cover grid')),
              const PopupMenuDivider(),
              for (final e in _groupLabels.entries) CheckedPopupMenuItem(value: 'g:${e.key}', checked: _group == e.key, child: Text(e.value)),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: SizedBox(
            height: 48,
            child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
              for (final f in LibFilter.values)
                if (f != LibFilter.trash || _trash.isNotEmpty || _filter == LibFilter.trash)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(_filterLabels[f]!),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                  ),
            ]),
          ),
        ),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Stack(children: [
              list.isEmpty ? _empty() : (_group == 'none' ? _booksView(list) : _grouped(list)),
              if (_importing)
                Positioned.fill(
                  child: ColoredBox(
                    color: const Color(0x66000000),
                    child: Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const CircularProgressIndicator(),
                        if (_importStatus.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Text(_importStatus, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
                          ),
                      ]),
                    ),
                  ),
                ),
            ]),
      floatingActionButton: FloatingActionButton.extended(onPressed: _addMenu, icon: const Icon(Icons.add), label: const Text('Add')),
    );
  }
}
