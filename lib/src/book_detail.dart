import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:wakelock_plus/wakelock_plus.dart';

import 'app.dart';
import 'db.dart';
import 'epub_export.dart';
import 'cloud_tts.dart';
import 'exports.dart';
import 'models.dart';
import 'narration_ui.dart';
import 'reader.dart';
import 'text_utils.dart';

/// Everything about one book: details, reading lists, chapters, exports.
class BookDetailScreen extends StatefulWidget {
  final int bookId;
  const BookDetailScreen({super.key, required this.bookId});

  @override
  State<BookDetailScreen> createState() => _BookDetailState();
}

class _BookDetailState extends State<BookDetailScreen> {
  Book? _b;
  List<ChapterMeta> _metas = [];
  List<Shelf> _shelves = [];
  Set<int> _on = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final b = await Db.book(widget.bookId);
    if (b == null) {
      if (mounted) Navigator.pop(context);
      return;
    }
    final m = await Db.chapterMetas(b.id!);
    final s = await Db.shelves();
    final on = await Db.shelfIdsOf(b.id!);
    if (mounted) {
      setState(() {
        _b = b;
        _metas = m;
        _shelves = s;
        _on = on;
      });
    }
  }

  Future<void> _update(void Function(Book) change) async {
    change(_b!);
    await Db.updateBook(_b!);
    bumpLibrary();
    if (mounted) setState(() {});
  }

  Future<List<Chapter>> _chapters() async => [
        for (final m in _metas) (await Db.chapter(m.id))!,
      ];

  Future<void> _export(bool epub) async {
    final b = _b!;
    if (_metas.isEmpty) return toast(context, 'This book has no chapters to export.');
    final chapters = await _chapters();
    final cover = coverFile(b);
    final Uint8List bytes = epub
        ? buildEpub(b, chapters, cover: cover == null ? null : await cover.readAsBytes())
        : Uint8List.fromList(utf8.encode(buildPlainText(b, chapters)));
    if (mounted) await offerFile(context, '${safeFileName(b.title)}.${epub ? 'epub' : 'txt'}', bytes);
  }

  Future<void> _setCover() async {
    final x = await openFile(acceptedTypeGroups: const [
      XTypeGroup(label: 'Images', extensions: ['jpg', 'jpeg', 'png', 'webp'], mimeTypes: ['image/*']),
    ]);
    if (x == null) return;
    await Directory(coversDir).create(recursive: true);
    final name = 'cover_${_b!.id}_${nowMs()}.img';
    await File(p.join(coversDir, name)).writeAsBytes(await x.readAsBytes());
    await _update((b) => b.coverPath = name);
  }

  Future<void> _edit() async {
    final b = _b!;
    final c = {
      'Title': TextEditingController(text: b.title),
      'Author': TextEditingController(text: b.author),
      'Series': TextEditingController(text: b.series),
      'Number in series': TextEditingController(text: b.seriesNo == null ? '' : '${b.seriesNo}'),
      'Language': TextEditingController(text: b.language),
      'Description': TextEditingController(text: b.description),
      'My notes on this book': TextEditingController(text: b.review),
    };
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit details'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (final e in c.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: e.value,
                    minLines: 1,
                    maxLines: e.key.startsWith('Desc') || e.key.startsWith('My') ? 5 : 1,
                    keyboardType: e.key.startsWith('Number') ? const TextInputType.numberWithOptions(decimal: true) : null,
                    decoration: InputDecoration(labelText: e.key, border: const OutlineInputBorder()),
                  ),
                ),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    await _update((b) {
      final t = c['Title']!.text.trim();
      if (t.isNotEmpty) b.title = t;
      b.author = c['Author']!.text.trim();
      b.series = c['Series']!.text.trim();
      b.seriesNo = double.tryParse(c['Number in series']!.text.trim());
      b.language = c['Language']!.text.trim();
      b.description = c['Description']!.text.trim();
      b.review = c['My notes on this book']!.text.trim();
    });
  }

  @override
  Widget build(BuildContext context) {
    final b = _b;
    if (b == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final tt = Theme.of(context).textTheme, cs = Theme.of(context).colorScheme;
    final trashed = b.trashedAt > 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Book details'),
        actions: [
          IconButton(
            tooltip: 'Favourite',
            icon: Icon(b.favorite ? Icons.star : Icons.star_border),
            onPressed: () => _update((b) => b.favorite = !b.favorite),
          ),
          IconButton(tooltip: 'Edit details', icon: const Icon(Icons.edit_outlined), onPressed: _edit),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GestureDetector(onTap: _setCover, child: CoverView(b, width: 104)),
          const SizedBox(width: 18),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(b.title, style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              if (b.author.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(b.author, style: tt.titleMedium)),
              if (b.series.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('${b.series}${b.seriesNo == null ? '' : ' · #${b.seriesNo!.toStringAsFixed(b.seriesNo! % 1 == 0 ? 0 : 1)}'}',
                      style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                ),
              const SizedBox(height: 10),
              Text(
                [
                  b.format,
                  '${b.chapterCount} chapter${b.chapterCount == 1 ? '' : 's'}',
                  if (b.fileSize > 0) fmtSize(b.fileSize),
                  if (b.charCount > 0) listenLabel(b.charCount),
                ].join(' · '),
                style: tt.bodySmall,
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(value: b.progress, borderRadius: BorderRadius.circular(4)),
              const SizedBox(height: 4),
              Text('${(b.progress * 100).round()}% read', style: tt.bodySmall),
            ]),
          ),
        ]),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              icon: const Icon(Icons.menu_book),
              label: Text(b.lastReadAt > 0 ? 'Continue reading' : 'Read'),
              onPressed: _metas.isEmpty
                  ? null
                  : () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => ReaderScreen(bookId: b.id!)));
                      _load();
                    },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.tonalIcon(
              icon: const Icon(Icons.headphones),
              label: const Text('Listen'),
              onPressed: _metas.isEmpty
                  ? null
                  : () async {
                      narrator.start(b.id!, b.curChapter, b.curPara);
                      showNarrationPanel(context);
                    },
            ),
          ),
        ]),
        if (b.description.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(b.description, style: tt.bodyMedium),
        ],
        if (b.review.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text('My notes', style: tt.titleSmall),
          const SizedBox(height: 4),
          Text(b.review, style: tt.bodyMedium),
        ],
        const SizedBox(height: 20),
        Text('Reading list', style: tt.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: shelfNone, label: Text('None')),
            ButtonSegment(value: shelfToRead, label: Text('To read'), icon: Icon(Icons.schedule)),
            ButtonSegment(value: shelfFinished, label: Text('Finished'), icon: Icon(Icons.done_all)),
          ],
          selected: {b.shelf},
          showSelectedIcon: false,
          onSelectionChanged: (v) => _update((b) => b.shelf = v.first),
        ),
        const SizedBox(height: 18),
        Text('Shelves', style: tt.titleSmall),
        const SizedBox(height: 6),
        Wrap(spacing: 8, children: [
          for (final s in _shelves)
            FilterChip(
              label: Text(s.name),
              selected: _on.contains(s.id),
              onSelected: (v) async {
                await Db.setOnShelf(s.id, b.id!, v);
                bumpLibrary();
                _load();
              },
            ),
          ActionChip(
            avatar: const Icon(Icons.add, size: 18),
            label: const Text('New shelf'),
            onPressed: () async {
              final name = await promptText(context, 'New shelf', hint: 'Shelf name', ok: 'Create');
              if (name == null || name.trim().isEmpty) return;
              final id = await Db.addShelf(name.trim());
              await Db.setOnShelf(id, b.id!, true);
              bumpLibrary();
              _load();
            },
          ),
        ]),
        const SizedBox(height: 12),
        const Divider(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.format_list_numbered),
          title: Text('Chapters (${_metas.length})'),
          subtitle: const Text('Rename, reorder or remove'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => ChapterManager(book: b)));
            _load();
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.import_contacts),
          title: const Text('Export as EPUB'),
          subtitle: const Text('Opens in any e-book reader, on any device'),
          onTap: () => _export(true),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.notes),
          title: const Text('Export as plain text'),
          onTap: () => _export(false),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.audio_file_outlined),
          title: const Text('Make audio files'),
          subtitle: const Text('One file per chapter, playable in any audio app'),
          onTap: _metas.isEmpty ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => AudioExportScreen(book: b, metas: _metas))),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.image_outlined),
          title: const Text('Choose cover image'),
          onTap: _setCover,
        ),
        if (b.sourceUrl.isNotEmpty)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.link),
            title: const Text('Source'),
            subtitle: Text(b.sourceUrl, maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: b.sourceUrl));
              if (context.mounted) toast(context, 'Link copied.');
            },
          ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.info_outline),
          title: Text('Added ${fmtDate(b.addedAt)}${b.lastReadAt > 0 ? ' · last opened ${fmtDate(b.lastReadAt)}' : ''}'),
          subtitle: b.fileName.isEmpty ? null : Text('Imported from ${b.fileName}'),
        ),
        const Divider(),
        if (!trashed)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.delete_outline, color: cs.error),
            title: Text('Move to trash', style: TextStyle(color: cs.error)),
            onTap: () async {
              await Db.setTrashed(b.id!, true);
              bumpLibrary();
              if (context.mounted) Navigator.pop(context);
            },
          )
        else ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.restore_from_trash),
            title: const Text('Restore from trash'),
            onTap: () async {
              await Db.setTrashed(b.id!, false);
              bumpLibrary();
              _load();
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.delete_forever, color: cs.error),
            title: Text('Delete permanently', style: TextStyle(color: cs.error)),
            onTap: () async {
              if (!await confirm(context, 'Delete this book?', 'Its chapters, bookmarks and highlights are removed for good.', ok: 'Delete', danger: true)) return;
              if (narrator.book?.id == b.id) await narrator.stop();
              await Db.deleteBook(b.id!);
              bumpLibrary();
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ]),
    );
  }
}

/// Rename, reorder and delete chapters.
class ChapterManager extends StatefulWidget {
  final Book book;
  const ChapterManager({super.key, required this.book});
  @override
  State<ChapterManager> createState() => _ChapterManagerState();
}

class _ChapterManagerState extends State<ChapterManager> {
  List<ChapterMeta> _metas = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final m = await Db.chapterMetas(widget.book.id!);
    if (mounted) setState(() => _metas = m);
    bumpLibrary();
  }

  Future<void> _paste() async {
    final title = await promptText(context, 'New chapter', hint: 'Chapter title', ok: 'Next');
    if (title == null || !mounted) return;
    final text = await promptText(context, 'Chapter text', hint: 'Paste the text here', multiline: true, ok: 'Add');
    if (text == null || text.trim().isEmpty) return;
    await Db.addChapter(widget.book.id!, title.trim().isEmpty ? 'Untitled chapter' : title.trim(), plainToParagraphs(text).join('\n'));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chapters · ${widget.book.title}', overflow: TextOverflow.ellipsis),
        actions: [IconButton(tooltip: 'Add a chapter from pasted text', icon: const Icon(Icons.note_add_outlined), onPressed: _paste)],
      ),
      body: _metas.isEmpty
          ? const Center(child: Text('No chapters yet.'))
          : ReorderableListView.builder(
              itemCount: _metas.length,
              onReorderItem: (from, to) async {
                final m = _metas.removeAt(from);
                _metas.insert(to, m);
                setState(() {});
                await Db.reorderChapters(widget.book.id!, _metas.map((e) => e.id).toList());
                _load();
              },
              itemBuilder: (c, i) {
                final m = _metas[i];
                return ListTile(
                  key: ValueKey(m.id),
                  leading: SizedBox(width: 32, child: Center(child: Text('${i + 1}'))),
                  title: Text(m.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text(fmtListenTime(m.charCount)),
                  onTap: () async {
                    final t = await promptText(context, 'Rename chapter', initial: m.title);
                    if (t == null || t.trim().isEmpty) return;
                    final ch = await Db.chapter(m.id);
                    if (ch == null) return;
                    ch.title = t.trim();
                    await Db.updateChapter(ch);
                    _load();
                  },
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      tooltip: 'Remove',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        if (!await confirm(context, 'Remove this chapter?', m.title, ok: 'Remove', danger: true)) return;
                        await Db.deleteChapter(widget.book.id!, m.id);
                        _load();
                      },
                    ),
                    const SizedBox(width: 28),
                  ]),
                );
              },
            ),
    );
  }
}

/// Turns chapters into audio files, with the phone's voice or a Gemini voice.
class AudioExportScreen extends StatefulWidget {
  final Book book;
  final List<ChapterMeta> metas;
  const AudioExportScreen({super.key, required this.book, required this.metas});
  @override
  State<AudioExportScreen> createState() => _AudioExportState();
}

class _AudioExportState extends State<AudioExportScreen> {
  late int _from = widget.book.curChapter.clamp(0, widget.metas.length - 1);
  int _count = 5;
  String _source = settings.voiceSource;
  bool _running = false, _cancel = false;
  int _done = 0;
  double _part = 0;
  String _status = '', _folder = '';

  @override
  void dispose() {
    _cancel = true;
    WakelockPlus.disable().catchError((_) {});
    super.dispose();
  }

  Future<void> _run() async {
    final list = widget.metas.skip(_from).take(_count).toList();
    setState(() {
      _running = true;
      _cancel = false;
      _done = 0;
      _status = '';
    });
    WakelockPlus.enable().catchError((_) {});
    try {
      if (_source == voiceDevice) await narrator.stop();
      final dir = await audioFolder(widget.book);
      _folder = dir.path;
      for (final m in list) {
        if (_cancel) break;
        setState(() {
          _status = m.title;
          _part = 0;
        });
        await renderChapterAudio(
          book: widget.book,
          meta: m,
          source: _source,
          dir: dir,
          cancelled: () => _cancel,
          onProgress: (v) {
            if (mounted) setState(() => _part = v);
          },
        );
        if (!_cancel && mounted) setState(() => _done++);
      }
      if (mounted) setState(() => _status = _cancel ? 'Stopped.' : 'Finished.');
    } catch (e) {
      if (mounted) setState(() => _status = '$e');
    } finally {
      WakelockPlus.disable().catchError((_) {});
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final max = widget.metas.length - _from;
    final total = _count.clamp(1, max);
    final chars = widget.metas.skip(_from).take(_count).fold<int>(0, (n, m) => n + m.charCount);
    return Scaffold(
      appBar: AppBar(title: const Text('Make audio files')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text(widget.book.title, style: tt.titleLarge),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          key: ValueKey('from-$_from'),
          initialValue: _from,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Start at chapter', border: OutlineInputBorder()),
          items: [
            for (final m in widget.metas) DropdownMenuItem(value: m.idx, child: Text('${m.idx + 1}. ${m.title}', overflow: TextOverflow.ellipsis)),
          ],
          onChanged: _running ? null : (v) => setState(() => _from = v ?? _from),
        ),
        const SizedBox(height: 14),
        Text('How many chapters', style: tt.titleSmall),
        const SizedBox(height: 6),
        Wrap(spacing: 8, children: [
          for (final n in const [1, 5, 10, 20, 50])
            ChoiceChip(label: Text('$n'), selected: _count == n, onSelected: _running ? null : (_) => setState(() => _count = n)),
          ChoiceChip(label: const Text('All remaining'), selected: _count >= 100000, onSelected: _running ? null : (_) => setState(() => _count = 100000)),
        ]),
        const SizedBox(height: 18),
        Text('Voice', style: tt.titleSmall),
        RadioGroup<String>(
          groupValue: _source,
          onChanged: (v) {
            if (!_running) setState(() => _source = v ?? voiceDevice);
          },
          child: Column(children: [
            RadioListTile<String>(
              value: voiceDevice,
              contentPadding: EdgeInsets.zero,
              title: const Text('Phone voice → M4A'),
              subtitle: Text('${engineLabel(settings.ttsEngine)} · ${settings.ttsVoice.isEmpty ? 'default voice' : settings.ttsVoice}. Free and offline.'),
            ),
            RadioListTile<String>(
              value: voiceGoogle,
              contentPadding: EdgeInsets.zero,
              title: const Text('Google Cloud voice → MP3'),
              subtitle: Text(settings.googleTtsKey.isEmpty && settings.geminiKey.isEmpty
                  ? 'Needs a Google Cloud API key (Voice settings → Google).'
                  : '${settings.googleVoice}. Billed to your Google Cloud account.'),
            ),
            RadioListTile<String>(
              value: voiceGemini,
              contentPadding: EdgeInsets.zero,
              title: const Text('Gemini voice → M4A'),
              subtitle: Text(settings.geminiKey.isEmpty
                  ? 'Needs a Gemini API key (Settings → AI).'
                  : '${settings.cloudTtsVoice} · ${settings.cloudTtsModel}. Uses your key\'s quota.'),
            ),
          ]),
        ),
        const SizedBox(height: 8),
        Text('$total chapter${total == 1 ? '' : 's'} · about ${fmtListenTime(chars)} of audio · '
            'roughly ${(chars / 15 * (_source == voiceGoogle ? 4 : 8) / 1024).round()} MB'),
        const SizedBox(height: 18),
        if (_running) ...[
          LinearProgressIndicator(value: total == 0 ? 0 : (_done + _part) / total),
          const SizedBox(height: 8),
          Text('Chapter ${(_done + 1).clamp(1, total)} of $total — $_status'),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: () => setState(() => _cancel = true), child: const Text('Stop')),
          const SizedBox(height: 8),
          Text('Keep this screen open until it finishes.', style: tt.bodySmall),
        ] else ...[
          FilledButton.icon(icon: const Icon(Icons.graphic_eq), label: const Text('Start'), onPressed: _run),
          if (_status.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('$_status ${_done > 0 ? '$_done file${_done == 1 ? '' : 's'} saved.' : ''}'),
            if (_folder.isNotEmpty && _done > 0) Padding(padding: const EdgeInsets.only(top: 6), child: SelectableText(_folder, style: tt.bodySmall)),
          ],
        ],
      ]),
    );
  }
}
