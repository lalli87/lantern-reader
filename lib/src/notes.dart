import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'app.dart';
import 'db.dart';
import 'exports.dart';
import 'models.dart';
import 'reader.dart';
import 'reader_widgets.dart';
import 'settings.dart';
import 'text_utils.dart';

/// Highlights and notes, bookmarks, and the glossary, gathered from every book.
class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});
  @override
  State<NotesScreen> createState() => NotesState();
}

class NotesState extends State<NotesScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  void showTab(int i) => _tabs.animateTo(i);

  List<Quote> _quotes = [];
  List<Bookmark> _bookmarks = [];
  List<DictEntry> _dict = [];
  Map<int, Book> _books = {};
  Map<int, (int, String)> _chapters = {}; // chapter id -> (index, title)
  String _query = '';
  int _kind = 0;

  @override
  void initState() {
    super.initState();
    libraryChanged.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    libraryChanged.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final q = await Db.quotes(), b = await Db.bookmarks(), d = await Db.dict();
    final books = {for (final x in await Db.books()) x.id!: x};
    final ch = <int, (int, String)>{};
    for (final id in {...q.map((e) => e.bookId), ...b.map((e) => e.bookId)}) {
      for (final m in await Db.chapterMetas(id)) {
        ch[m.id] = (m.idx, m.title);
      }
    }
    if (!mounted) return;
    setState(() {
      _quotes = q.where((e) => books.containsKey(e.bookId)).toList();
      _bookmarks = b.where((e) => books.containsKey(e.bookId)).toList();
      _dict = d;
      _books = books;
      _chapters = ch;
    });
  }

  Future<void> _go(int bookId, int chapterId, int para) async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => ReaderScreen(bookId: bookId, chapterIdx: _chapters[chapterId]?.$1 ?? 0, para: para)));
    _load();
  }

  Future<void> _exportNotes() async {
    if (_quotes.isEmpty) return toast(context, 'There are no highlights to export yet.');
    final sb = StringBuffer('# Highlights and notes\n');
    final byBook = <int, List<Quote>>{};
    for (final q in _quotes) {
      (byBook[q.bookId] ??= []).add(q);
    }
    for (final e in byBook.entries) {
      sb.writeln('\n## ${_books[e.key]?.title ?? ''}\n');
      for (final q in e.value.reversed) {
        sb.writeln('> ${q.text}');
        if (q.note.isNotEmpty) sb.writeln('\nNote: ${q.note}');
        sb.writeln('\n— ${_chapters[q.chapterId]?.$2 ?? ''}, ${fmtDate(q.createdAt)}\n');
      }
    }
    await offerFile(context, 'highlights.md', Uint8List.fromList(utf8.encode(sb.toString())));
  }

  bool _match(String s) => _query.isEmpty || s.toLowerCase().contains(_query.toLowerCase());

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final quotes = _quotes.where((q) => _match('${q.text}\n${q.note}\n${_books[q.bookId]?.title}')).toList();
    final marks = _bookmarks.where((b) => _match('${b.snippet}\n${_books[b.bookId]?.title}')).toList();
    final dict = _dict.where((d) => d.kind == _kind && _match('${d.word}\n${d.definition}')).toList();
    Widget empty(IconData icon, String text) => Center(
          child: Padding(
            padding: const EdgeInsets.all(36),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 56, color: cs.outline),
              const SizedBox(height: 14),
              Text(text, textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
            ]),
          ),
        );

    return Scaffold(
        appBar: AppBar(
          leading: const MenuButton(),
          title: TextField(
            decoration: const InputDecoration(hintText: 'Search notes and glossary', border: InputBorder.none, prefixIcon: Icon(Icons.search)),
            onChanged: (v) => setState(() => _query = v),
          ),
          actions: [IconButton(tooltip: 'Export highlights', icon: const Icon(Icons.ios_share), onPressed: _exportNotes)],
          bottom: TabBar(controller: _tabs, tabs: [
            Tab(text: 'Highlights (${_quotes.length})'),
            Tab(text: 'Bookmarks (${_bookmarks.length})'),
            Tab(text: 'Glossary (${_dict.length})'),
          ]),
        ),
        body: TabBarView(controller: _tabs, children: [
          quotes.isEmpty
              ? empty(Icons.format_quote, 'Passages you highlight and notes you write while reading are collected here.')
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: quotes.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (c, i) {
                    final q = quotes[i];
                    return ListTile(
                      leading: Container(width: 6, height: 44, decoration: BoxDecoration(color: quoteColors[q.color % quoteColors.length], borderRadius: BorderRadius.circular(3))),
                      title: Text(q.text, maxLines: 4, overflow: TextOverflow.ellipsis),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text([
                          if (q.note.isNotEmpty) 'Note: ${q.note}',
                          '${_books[q.bookId]?.title ?? ''} · ${_chapters[q.chapterId]?.$2 ?? ''}',
                        ].join('\n')),
                      ),
                      onTap: () => _go(q.bookId, q.chapterId, q.para),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit_note),
                        onPressed: () async {
                          if (await showQuoteSheet(context, q)) _load();
                        },
                      ),
                    );
                  },
                ),
          marks.isEmpty
              ? empty(Icons.bookmarks_outlined, 'Bookmarks from all your books appear here.')
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: marks.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (c, i) {
                    final b = marks[i];
                    return ListTile(
                      leading: const Icon(Icons.bookmark),
                      title: Text(b.snippet, maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${_books[b.bookId]?.title ?? ''} · ${_chapters[b.chapterId]?.$2 ?? ''} · ${fmtDate(b.createdAt)}'),
                      onTap: () => _go(b.bookId, b.chapterId, b.para),
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () async {
                          await Db.deleteBookmark(b.id!);
                          _load();
                        },
                      ),
                    );
                  },
                ),
          Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(children: [
                Expanded(
                  child: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, label: Text('Words')),
                      ButtonSegment(value: 1, label: Text('Characters')),
                      ButtonSegment(value: 2, label: Text('Terms')),
                    ],
                    selected: {_kind},
                    showSelectedIcon: false,
                    onSelectionChanged: (v) => setState(() => _kind = v.first),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Add entry',
                  icon: const Icon(Icons.add),
                  onPressed: () async {
                    if (await showGlossaryEditor(context, kind: _kind)) _load();
                  },
                ),
              ]),
            ),
            Expanded(
              child: dict.isEmpty
                  ? empty(
                      Icons.translate,
                      const [
                        'Foreign words you want to remember. Select a word while reading and choose “Add to glossary”.',
                        'Who is who. Add characters so their names are marked in the text and you can tap for a reminder.',
                        'Special terms and their meanings, such as cultivation ranks or place names.',
                      ][_kind])
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: dict.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (c, i) {
                        final d = dict[i];
                        return ListTile(
                          title: Text(d.word, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: d.definition.isEmpty ? null : Text(d.definition, maxLines: 3, overflow: TextOverflow.ellipsis),
                          onTap: () async {
                            if (await showGlossaryEditor(context, entry: d)) _load();
                          },
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              await Db.deleteDict(d.id!);
                              _load();
                            },
                          ),
                        );
                      },
                    ),
            ),
          ]),
        ]),
    );
  }
}
