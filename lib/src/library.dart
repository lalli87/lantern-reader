import 'dart:io';

import 'package:flutter/material.dart';

import 'app.dart';
import 'comics.dart';
import 'book_detail.dart';
import 'db.dart';
import 'drive_sync.dart';
import 'file_pick.dart';
import 'importers.dart';
import 'pdf_import.dart';
import 'models.dart';
import 'pdf_pages.dart';
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
  'progress': 'Progress',
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
  final Set<int> _picked = {}; // books selected with a long press
  String _continueChapter = '';

  @override
  void initState() {
    super.initState();
    libraryChanged.addListener(_load);
    settings.addListener(_refresh);
    _load(first: true);
    listenIncoming(_importFiles);
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
    final cont = _continueOf(b);
    final contCh = cont == null ? '' : (await Db.chapterAt(cont.id!, cont.curChapter))?.title ?? '';
    if (!mounted) return;
    setState(() {
      _continueChapter = contCh;
      _picked.removeWhere((id) => !b.any((x) => x.id == id) && !t.any((x) => x.id == id));
      _books = b;
      _trash = t;
      _shelves = s;
      _shelfBooks = sb;
      if (first && b.any((x) => x.lastReadAt > 0 && x.shelf != shelfFinished)) _filter = LibFilter.reading;
      _loaded = true;
    });
    if (first) {
      // PDFs imported before covers were made from their first page get one now.
      addMissingPdfCovers(b, coversDir).then((n) {
        if (n > 0 && mounted) _load();
      });
    }
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
      'progress' => a.progress.compareTo(b.progress),
      'format' => a.format.compareTo(b.format),
      _ => (a.lastReadAt == 0 ? a.addedAt : a.lastReadAt).compareTo(b.lastReadAt == 0 ? b.addedAt : b.lastReadAt),
    };
    list.sort((a, b) => settings.sortAsc ? cmp(a, b) : cmp(b, a));
    return list;
  }

  // ---- actions ----

  /// The book to offer in the "Continue" card: the last one opened that isn't finished.
  Book? _continueOf(List<Book> books) {
    Book? best;
    for (final b in books) {
      if (b.lastReadAt == 0 || b.shelf == shelfFinished || b.chapterCount == 0) continue;
      if (best == null || b.lastReadAt > best.lastReadAt) best = b;
    }
    return best;
  }

  bool get _showContinue =>
      _picked.isEmpty && !_searching && _group == 'none' && (_filter == LibFilter.reading || _filter == LibFilter.all);

  Widget _continueCard(Book b) {
    final tt = Theme.of(context).textTheme, cs = Theme.of(context).colorScheme;
    // A rough "time left": about 1,000 characters a minute.
    final leftMin = (b.charCount * (1 - b.progress) / 1000).round();
    final left = leftMin < 1 ? '' : (leftMin < 90 ? 'about $leftMin min left' : 'about ${(leftMin / 60).round()} h left');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Card(
        margin: EdgeInsets.zero,
        color: cs.secondaryContainer,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _open(b),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CoverView(b, width: 72),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CONTINUE',
                        style: tt.labelSmall?.copyWith(color: cs.onSecondaryContainer, letterSpacing: 1.2, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        b.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700, height: 1.2),
                      ),
                      if (_continueChapter.isNotEmpty && _continueChapter != b.title)
                        Text(_continueChapter, maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.bodySmall),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: b.progress, minHeight: 5, borderRadius: BorderRadius.circular(3)),
                      const SizedBox(height: 4),
                      Text(['${(b.progress * 100).round()}%', if (left.isNotEmpty) left].join(' · '), style: tt.bodySmall),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          FilledButton.icon(
                            style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                            icon: const Icon(Icons.menu_book, size: 18),
                            label: const Text('Read'),
                            onPressed: () => _open(b),
                          ),
                          const SizedBox(width: 8),
                          if (!isComicFormat(b.format))
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                              icon: const Icon(Icons.headphones, size: 18),
                              label: const Text('Listen'),
                              onPressed: () {
                                narrator.start(b.id!, b.curChapter, b.curPara);
                                showNarrationPanel(context);
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---- selecting several books ----

  void _toggle(Book b) => setState(() => _picked.contains(b.id) ? _picked.remove(b.id) : _picked.add(b.id!));

  List<Book> get _pickedBooks => [..._books, ..._trash].where((b) => _picked.contains(b.id)).toList();

  Future<void> _batch(String v) async {
    final books = _pickedBooks;
    if (books.isEmpty) return;
    switch (v) {
      case 'all':
        setState(() => _picked.addAll(_visible.map((b) => b.id!)));
        return;
      case 'fav':
        final on = !books.every((b) => b.favorite);
        for (final b in books) {
          b.favorite = on;
          await Db.updateBook(b);
        }
      case 'toread' || 'finished':
        final shelf = v == 'toread' ? shelfToRead : shelfFinished;
        final on = !books.every((b) => b.shelf == shelf);
        for (final b in books) {
          b.shelf = on ? shelf : shelfNone;
          await Db.updateBook(b);
        }
      case 'shelf':
        final s = await _chooseShelf();
        if (s == null) return;
        for (final b in books) {
          await Db.setOnShelf(s, b.id!, true);
        }
        if (mounted) toast(context, 'Added ${books.length} book${books.length == 1 ? '' : 's'} to the shelf.');
      case 'trash':
        for (final b in books) {
          await Db.setTrashed(b.id!, true);
        }
        if (mounted) toast(context, 'Moved ${books.length} book${books.length == 1 ? '' : 's'} to the trash.');
      case 'restore':
        for (final b in books) {
          await Db.setTrashed(b.id!, false);
        }
      case 'delete':
        if (!await confirm(
          context,
          'Delete ${books.length} book${books.length == 1 ? '' : 's'}?',
          'Their chapters, bookmarks and highlights are removed for good.',
          ok: 'Delete',
          danger: true,
        )) {
          return;
        }
        for (final b in books) {
          if (narrator.book?.id == b.id) await narrator.stop();
          await Db.deleteBook(b.id!);
          await deleteOriginalPdf(b.id!);
        }
        driveSync.auto();
    }
    setState(_picked.clear);
    _load();
  }

  /// Picks a shelf (or makes a new one); its id, or null.
  Future<int?> _chooseShelf() async {
    final r = await showDialog<Object>(
      context: context,
      builder: (c) => SimpleDialog(
        title: const Text('Add to shelf'),
        children: [
          for (final s in _shelves) SimpleDialogOption(onPressed: () => Navigator.pop(c, s.id), child: Text(s.name)),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(c, 'new'),
            child: const Row(children: [Icon(Icons.add, size: 20), SizedBox(width: 8), Text('New shelf…')]),
          ),
        ],
      ),
    );
    if (r is int) return r;
    if (r != 'new' || !mounted) return null;
    final name = await promptText(context, 'New shelf');
    if (name == null || name.trim().isEmpty) return null;
    return Db.addShelf(name.trim());
  }

  PreferredSizeWidget _selectionBar() {
    final trash = _filter == LibFilter.trash;
    return AppBar(
      leading: IconButton(tooltip: 'Done', icon: const Icon(Icons.close), onPressed: () => setState(_picked.clear)),
      title: Text('${_picked.length} selected'),
      actions: trash
          ? [
              IconButton(tooltip: 'Restore', icon: const Icon(Icons.restore_from_trash_outlined), onPressed: () => _batch('restore')),
              IconButton(tooltip: 'Delete permanently', icon: const Icon(Icons.delete_forever_outlined), onPressed: () => _batch('delete')),
            ]
          : [
              IconButton(tooltip: 'Favourite', icon: const Icon(Icons.star_border), onPressed: () => _batch('fav')),
              IconButton(
                tooltip: 'Add to a shelf',
                icon: const Icon(Icons.collections_bookmark_outlined),
                onPressed: () => _batch('shelf'),
              ),
              IconButton(tooltip: 'Move to trash', icon: const Icon(Icons.delete_outline), onPressed: () => _batch('trash')),
              PopupMenuButton<String>(
                onSelected: _batch,
                itemBuilder: (c) => const [
                  PopupMenuItem(value: 'all', child: Text('Select all')),
                  PopupMenuItem(value: 'toread', child: Text('Mark as To read')),
                  PopupMenuItem(value: 'finished', child: Text('Mark as finished')),
                ],
              ),
            ],
    );
  }

  // ---- search inside books ----

  Widget _searchInsideTile() {
    final q = _query.trim();
    return ListTile(
      leading: const Icon(Icons.manage_search),
      title: Text('Search inside books for “$q”'),
      subtitle: const Text('Find these words in the text of every book'),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SearchInsideScreen(query: q))),
    );
  }

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
    await _importFiles(files);
  }

  /// Imports picked, shared or found files, then opens the book if there was just one.
  Future<void> _importFiles(List<PickedFile> files) async {
    if (files.isEmpty || !mounted) return;
    if (_importing) {
      // Another import is running: wait for it, so the two don't trip over each other.
      while (_importing && mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
      if (!mounted) return;
    }
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
        final ext = x.name.split('.').last.toLowerCase();
        if (!importExtensions.contains(ext)) {
          problems.add('${x.name}: this file type is not supported yet');
          continue;
        }
        if (_books.any((b) => b.fileName == x.name && b.fileSize == x.size)) {
          problems.add('${x.name}: already in your library');
          continue;
        }
        if (mounted) setState(() => _importStatus = files.length > 1 ? 'Reading ${x.name}' : '');
        if (comicExtensions.contains(ext) || ext == 'zip' && zipIsComic(x.path)) {
          if (mounted) setState(() => _importStatus = '${files.length > 1 ? '${x.name}\n' : ''}Unpacking the comic pages');
          last = await importComic(x.path, x.name, x.size);
          ok++;
          continue;
        }
        final parsed = await parseBookFile(
          x.path,
          x.name,
          onProgress: (done, total) {
            if (!mounted || total < 20 || done % 5 != 0 && done != total) return;
            setState(() => _importStatus = '${files.length > 1 ? '${x.name}\n' : ''}Reading page $done of $total');
          },
          askOcr: (pages) async {
            if (!mounted) return false;
            return confirm(
              context,
              'Recognize the text?',
              '“${x.name}” is made of pictures of pages, with no text inside. Lantern can read the words off the pictures '
                  '(on the phone, offline). About a second per page; $pages page${pages == 1 ? '' : 's'}.',
              ok: 'Recognize',
            );
          },
          onOcrProgress: (done, total) {
            if (mounted) setState(() => _importStatus = '${files.length > 1 ? '${x.name}\n' : ''}Recognizing text: page $done of $total');
          },
        );
        last = await saveImported(parsed, fileName: x.name, fileSize: x.size, coversDir: coversDir);
        if (parsed.format == 'PDF') {
          // Keep the original so the reader can show the real pages, pictures included.
          try {
            await keepOriginalPdf(last, x.path, PdfPageMap.fromBook(parsed), temporary: x.temporary);
          } catch (_) {}
        }
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
    driveSync.auto();
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
    final title = await promptText(
      context,
      paste ? 'Paste text as a book' : 'New empty book',
      hint: 'Book title',
      ok: paste ? 'Next' : 'Create',
    );
    if (title == null || title.trim().isEmpty || !mounted) return;
    String? text;
    if (paste) {
      text = await promptText(context, 'Text', hint: 'Paste the text here', multiline: true, ok: 'Add');
      if (text == null || text.trim().isEmpty) return;
    }
    final id = await Db.insertBook(Book(title: title.trim(), format: paste ? 'TXT' : 'WEB'));
    if (text != null) await Db.addChapter(id, title.trim(), plainToParagraphs(text).join('\n'));
    bumpLibrary();
    driveSync.auto();
    if (mounted) toast(context, paste ? 'Book added.' : 'Book created. Save chapters into it from the Web tab.');
  }

  Future<void> _scanFolder({bool change = false}) async {
    var uri = change ? null : await Db.kvGet('scan.folder');
    if (uri == null || uri.isEmpty) {
      try {
        uri = await pickBookFolder();
      } catch (_) {
        if (mounted) toast(context, 'Could not open the folder picker.');
        return;
      }
      if (uri == null) return;
      await Db.kvSet('scan.folder', uri);
    }
    if (!mounted) return;
    setState(() {
      _importing = true;
      _importStatus = 'Looking for books in ${folderLabel(uri!)}';
    });
    List<FolderBook> found;
    try {
      found = await listBookFolder(uri, importExtensions);
    } catch (_) {
      await Db.kvSet('scan.folder', '');
      if (mounted) {
        setState(() => _importing = false);
        toast(context, 'Lantern can no longer open that folder. Choose it again.');
      }
      return;
    } finally {
      if (mounted) setState(() => _importStatus = '');
    }
    if (!mounted) return;
    setState(() => _importing = false);
    final fresh = found.where((f) => !_books.any((b) => b.fileName == f.name && b.fileSize == f.size)).toList()
      ..sort((a, b) => b.modified.compareTo(a.modified));
    final picked = await Navigator.push<Object>(
      context,
      MaterialPageRoute(
        builder: (_) => FolderBooksScreen(folder: folderLabel(uri!), books: fresh, total: found.length),
      ),
    );
    if (!mounted) return;
    if (picked == 'change') return _scanFolder(change: true);
    if (picked is! List<FolderBook> || picked.isEmpty) return;
    setState(() {
      _importing = true;
      _importStatus = 'Copying ${picked.length} book${picked.length == 1 ? '' : 's'}';
    });
    final files = await copyFolderBooks([for (final b in picked) b.uri]);
    if (!mounted) return;
    setState(() => _importing = false);
    await _importFiles(files);
  }

  void _addMenu() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
              subtitle: const Text('EPUB, PDF, Kindle (MOBI, AZW3), comics (CBZ, CBR), FB2, DOCX, ODT, RTF, TXT, HTML, Markdown, ZIP'),
              onTap: () {
                Navigator.pop(c);
                _import();
              },
            ),
            if (Platform.isAndroid)
              ListTile(
                leading: const Icon(Icons.folder_open_outlined),
                title: const Text('Find books on this phone'),
                subtitle: const Text('Look in a folder, such as Download, for books not in your library yet'),
                onTap: () {
                  Navigator.pop(c);
                  _scanFolder();
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
          ],
        ),
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
        if (!await confirm(
          context,
          'Delete “${b.title}”?',
          'Its chapters, bookmarks and highlights are removed for good.',
          ok: 'Delete',
          danger: true,
        )) {
          return;
        }
        if (narrator.book?.id == b.id) await narrator.stop();
        await Db.deleteBook(b.id!);
        await deleteOriginalPdf(b.id!);
        driveSync.auto();
    }
    _load();
  }

  Widget _menuButton(Book b) => PopupMenuButton<String>(
    onSelected: (v) => _bookMenu(b, v),
    itemBuilder: (c) => b.trashedAt > 0
        ? const [PopupMenuItem(value: 'restore', child: Text('Restore')), PopupMenuItem(value: 'delete', child: Text('Delete permanently'))]
        : [
            const PopupMenuItem(value: 'details', child: Text('Details')),
            if (b.chapterCount > 0 && !isComicFormat(b.format)) const PopupMenuItem(value: 'listen', child: Text('Listen')),
            PopupMenuItem(value: 'fav', child: Text(b.favorite ? 'Remove from favourites' : 'Add to favourites')),
            PopupMenuItem(value: 'toread', child: Text(b.shelf == shelfToRead ? 'Remove from To read' : 'Mark as To read')),
            PopupMenuItem(value: 'finished', child: Text(b.shelf == shelfFinished ? 'Mark as not finished' : 'Mark as finished')),
            const PopupMenuItem(value: 'trash', child: Text('Move to trash')),
          ],
  );

  // ---- tiles ----

  String _meta(Book b) => [b.format, '${b.chapterCount} ch', if (b.fileSize > 0) fmtSize(b.fileSize)].join(' · ');

  Widget _tile(Book b) {
    final tt = Theme.of(context).textTheme, cs = Theme.of(context).colorScheme;
    if (settings.libraryView == 'compact') {
      return ListTile(
        dense: true,
        title: Text(
          b.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          [if (b.author.isNotEmpty) b.author, _meta(b), '${(b.progress * 100).round()}%'].join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: _picked.isEmpty ? null : Checkbox(value: _picked.contains(b.id), onChanged: (_) => _toggle(b)),
        trailing: _picked.isEmpty ? _menuButton(b) : null,
        selected: _picked.contains(b.id),
        onTap: () => _picked.isEmpty ? _open(b) : _toggle(b),
        onLongPress: () => _toggle(b),
      );
    }
    final picked = _picked.contains(b.id);
    return InkWell(
      onTap: () => _picked.isEmpty ? _open(b) : _toggle(b),
      onLongPress: () => _toggle(b),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                CoverView(b, width: 62),
                if (picked) const Positioned.fill(child: _PickedMark()),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    b.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700, height: 1.2),
                  ),
                  if (b.author.isNotEmpty) Text(b.author, maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.bodyMedium),
                  const SizedBox(height: 2),
                  Text(_meta(b), style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(value: b.progress, minHeight: 5, borderRadius: BorderRadius.circular(3)),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(width: 38, child: Text('${(b.progress * 100).round()}%', style: tt.bodySmall)),
                      if (b.favorite) Icon(Icons.star, size: 16, color: cs.primary),
                      if (b.shelf == shelfFinished)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Icon(Icons.done_all, size: 16, color: cs.primary),
                        ),
                      if (b.shelf == shelfToRead)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Icon(Icons.schedule, size: 16, color: cs.primary),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (_picked.isEmpty) _menuButton(b) else Checkbox(value: picked, onChanged: (_) => _toggle(b)),
          ],
        ),
      ),
    );
  }

  Widget _gridTile(Book b, double w) {
    final tt = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _picked.isEmpty ? _open(b) : _toggle(b),
      onLongPress: () => _toggle(b),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              CoverView(b, width: w),
              if (_picked.contains(b.id)) const Positioned.fill(child: _PickedMark()),
              if (b.progress > 0) Positioned(left: 0, right: 0, bottom: 0, child: LinearProgressIndicator(value: b.progress, minHeight: 4)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            b.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600, height: 1.2),
          ),
          if (b.author.isNotEmpty) Text(b.author, maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.bodySmall),
        ],
      ),
    );
  }

  Widget _booksView(List<Book> list) {
    final cont = _showContinue ? _continueOf(_books) : null;
    final header = [if (_searching && _query.trim().length >= 2) _searchInsideTile(), if (cont != null) _continueCard(cont)];
    // The book in the Continue card isn't repeated just below it in "Reading now".
    final rest = cont != null && _filter == LibFilter.reading ? list.where((b) => b.id != cont.id).toList() : list;
    if (settings.libraryView == 'grid') {
      return LayoutBuilder(
        builder: (c, cons) {
          final cols = (cons.maxWidth / 128).floor().clamp(2, 8);
          final w = (cons.maxWidth - 32 - (cols - 1) * 14) / cols;
          return CustomScrollView(
            slivers: [
              SliverList(delegate: SliverChildListDelegate(header)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    mainAxisExtent: w * 1.45 + 62,
                  ),
                  delegate: SliverChildBuilderDelegate((c, i) => _gridTile(rest[i], w), childCount: rest.length),
                ),
              ),
            ],
          );
        },
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: header.length + rest.length,
      itemBuilder: (c, i) => i < header.length ? header[i] : _tile(rest[i - header.length]),
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
    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
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
      ],
    );
  }

  Widget _empty() {
    final cs = Theme.of(context).colorScheme, tt = Theme.of(context).textTheme;
    final none = _books.isEmpty && _filter != LibFilter.trash;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(none ? Icons.auto_stories_outlined : Icons.inbox_outlined, size: 64, color: cs.outline),
            const SizedBox(height: 16),
            Text(
              none
                  ? 'Your library is empty'
                  : (_query.isNotEmpty ? 'No books match “$_query”' : 'Nothing in ${_filterLabels[_filter]!.toLowerCase()}'),
              style: tt.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (none) ...[
              const SizedBox(height: 8),
              Text(
                'Save chapters from a website in the Web tab, or import book files you already have.',
                textAlign: TextAlign.center,
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(icon: const Icon(Icons.public), label: const Text('Open the web browser'), onPressed: widget.onOpenBrowser),
              const SizedBox(height: 8),
              OutlinedButton.icon(icon: const Icon(Icons.file_open_outlined), label: const Text('Import book files'), onPressed: _import),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _visible;
    final view = settings.libraryView;
    return PopScope(
      canPop: _picked.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _picked.isNotEmpty) setState(_picked.clear);
      },
      child: Scaffold(
        appBar: _picked.isNotEmpty
            ? _selectionBar()
            : AppBar(
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
                      for (final e in _sortLabels.entries)
                        CheckedPopupMenuItem(value: e.key, checked: settings.sortBy == e.key, child: Text(e.value)),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'dir',
                        child: Text(settings.sortAsc ? 'Ascending ↑ (tap to reverse)' : 'Descending ↓ (tap to reverse)'),
                      ),
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
                      for (final e in _groupLabels.entries)
                        CheckedPopupMenuItem(value: 'g:${e.key}', checked: _group == e.key, child: Text(e.value)),
                    ],
                  ),
                ],
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(48),
                  child: SizedBox(
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
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
                      ],
                    ),
                  ),
                ),
              ),
        body: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : Stack(
                children: [
                  list.isEmpty && !(_searching && _query.trim().length >= 2)
                      ? _empty()
                      : (_group == 'none' || _searching ? _booksView(list) : _grouped(list)),
                  if (_importing)
                    Positioned.fill(
                      child: ColoredBox(
                        color: const Color(0x66000000),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(),
                              if (_importStatus.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 16),
                                  child: Text(
                                    _importStatus,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
        floatingActionButton: _picked.isNotEmpty
            ? null
            : FloatingActionButton.extended(onPressed: _addMenu, icon: const Icon(Icons.add), label: const Text('Add')),
      ),
    );
  }
}

/// New books found in a folder on the phone, to tick and import.
class FolderBooksScreen extends StatefulWidget {
  final String folder;
  final List<FolderBook> books;
  final int total;
  const FolderBooksScreen({super.key, required this.folder, required this.books, required this.total});
  @override
  State<FolderBooksScreen> createState() => _FolderBooksScreenState();
}

class _FolderBooksScreenState extends State<FolderBooksScreen> {
  late final Set<FolderBook> _chosen = {...widget.books};

  String _size(int b) => b >= 1 << 20 ? '${(b / (1 << 20)).toStringAsFixed(1)} MB' : '${(b / 1024).ceil()} KB';

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.folder),
        actions: [TextButton(onPressed: () => Navigator.pop(context, 'change'), child: const Text('Other folder'))],
      ),
      body: widget.books.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  widget.total == 0
                      ? 'No books were found in ${widget.folder} or its subfolders.'
                      : 'All ${widget.total} book${widget.total == 1 ? ' is' : 's are'} already in your library.',
                  textAlign: TextAlign.center,
                  style: tt.bodyLarge,
                ),
              ),
            )
          : ListView(
              children: [
                CheckboxListTile(
                  title: Text('${widget.books.length} new book${widget.books.length == 1 ? '' : 's'}', style: tt.titleSmall),
                  value: _chosen.length == widget.books.length ? true : (_chosen.isEmpty ? false : null),
                  tristate: true,
                  onChanged: (_) => setState(() => _chosen.length == widget.books.length ? _chosen.clear() : _chosen.addAll(widget.books)),
                ),
                const Divider(height: 1),
                for (final b in widget.books)
                  CheckboxListTile(
                    value: _chosen.contains(b),
                    onChanged: (v) => setState(() => v == true ? _chosen.add(b) : _chosen.remove(b)),
                    title: Text(b.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      [
                        _size(b.size),
                        if (b.modified > 0)
                          MaterialLocalizations.of(context).formatMediumDate(DateTime.fromMillisecondsSinceEpoch(b.modified)),
                      ].join(' · '),
                    ),
                  ),
              ],
            ),
      bottomNavigationBar: widget.books.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton(
                  onPressed: _chosen.isEmpty ? null : () => Navigator.pop(context, widget.books.where(_chosen.contains).toList()),
                  child: Text('Add ${_chosen.length} book${_chosen.length == 1 ? '' : 's'}'),
                ),
              ),
            ),
    );
  }
}

/// The tick shown over a selected book's cover.
class _PickedMark extends StatelessWidget {
  const _PickedMark();
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(6)),
      child: Center(child: Icon(Icons.check_circle, color: cs.onPrimary, size: 30)),
    );
  }
}

/// A place in a book where search words were found.
class TextMatch {
  TextMatch(this.bookId, this.bookTitle, this.chapterIdx, this.chapterTitle, this.para, this.snippet);
  final int bookId, chapterIdx, para;
  final String bookTitle, chapterTitle, snippet;
}

/// Finds [query] in the text of every book (not in the trash): at most [perChapter] places per chapter
/// and [limit] in all.
Future<List<TextMatch>> searchInsideBooks(String query, {int limit = 300, int perChapter = 3}) async {
  final q = query.trim();
  if (q.length < 2) return [];
  final like = '%${q.replaceAll('\\', '\\\\').replaceAll('%', '\\%').replaceAll('_', '\\_')}%';
  final rows = await Db.db.rawQuery(
    "SELECT c.book_id, c.idx, c.title ct, c.content, b.title bt FROM chapters c JOIN books b ON b.id = c.book_id "
    "WHERE b.trashed_at = 0 AND c.content LIKE ? ESCAPE '\\' ORDER BY b.last_read_at DESC, c.book_id, c.idx LIMIT 400",
    [like],
  );
  final out = <TextMatch>[];
  final needle = q.toLowerCase();
  for (final r in rows) {
    final paras = splitParas(r['content'] as String? ?? '');
    var n = 0;
    for (var i = 0; i < paras.length && n < perChapter; i++) {
      final t = paraText(paras[i]);
      final at = t.toLowerCase().indexOf(needle);
      if (at < 0) continue;
      final from = (at - 60).clamp(0, t.length), to = (at + needle.length + 80).clamp(0, t.length);
      out.add(
        TextMatch(
          r['book_id'] as int,
          r['bt'] as String? ?? '',
          r['idx'] as int,
          r['ct'] as String? ?? '',
          i,
          '${from > 0 ? '…' : ''}${t.substring(from, to)}${to < t.length ? '…' : ''}',
        ),
      );
      n++;
      if (out.length >= limit) return out;
    }
  }
  return out;
}

class SearchInsideScreen extends StatefulWidget {
  final String query;
  const SearchInsideScreen({super.key, required this.query});
  @override
  State<SearchInsideScreen> createState() => _SearchInsideScreenState();
}

class _SearchInsideScreenState extends State<SearchInsideScreen> {
  List<TextMatch>? _found;
  late final _q = TextEditingController(text: widget.query);

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    setState(() => _found = null);
    final r = await searchInsideBooks(_q.text);
    if (mounted) setState(() => _found = r);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme, tt = Theme.of(context).textTheme;
    final found = _found;
    final needle = _q.text.trim().toLowerCase();
    TextSpan highlight(String s) {
      final spans = <TextSpan>[];
      var at = 0;
      final low = s.toLowerCase();
      while (needle.isNotEmpty) {
        final i = low.indexOf(needle, at);
        if (i < 0) break;
        spans.add(TextSpan(text: s.substring(at, i)));
        spans.add(
          TextSpan(
            text: s.substring(i, i + needle.length),
            style: TextStyle(backgroundColor: cs.primaryContainer, color: cs.onPrimaryContainer, fontWeight: FontWeight.w700),
          ),
        );
        at = i + needle.length;
      }
      spans.add(TextSpan(text: s.substring(at)));
      return TextSpan(children: spans);
    }

    // Group the places by book.
    final groups = <int, List<TextMatch>>{};
    for (final m in found ?? const <TextMatch>[]) {
      (groups[m.bookId] ??= []).add(m);
    }
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _q,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(hintText: 'Words to find in your books', border: InputBorder.none),
          onSubmitted: (_) => _run(),
        ),
        actions: [IconButton(tooltip: 'Search', icon: const Icon(Icons.search), onPressed: _run)],
      ),
      body: found == null
          ? const Center(child: CircularProgressIndicator())
          : found.isEmpty
          ? Center(child: Text('“${_q.text.trim()}” wasn’t found in your books.', style: tt.bodyLarge))
          : ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    '${found.length}${found.length >= 300 ? '+' : ''} place${found.length == 1 ? '' : 's'} in ${groups.length} book${groups.length == 1 ? '' : 's'}',
                    style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
                for (final g in groups.values) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text(g.first.bookTitle, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  for (final m in g)
                    ListTile(
                      dense: true,
                      title: Text(m.chapterTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.labelMedium),
                      subtitle: Text.rich(highlight(m.snippet), maxLines: 3, overflow: TextOverflow.ellipsis),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ReaderScreen(bookId: m.bookId, chapterIdx: m.chapterIdx, para: m.para),
                        ),
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}
