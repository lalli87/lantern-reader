import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import 'ai.dart';
import 'app.dart';
import 'browser.dart';
import 'db.dart';
import 'exports.dart';
import 'models.dart';
import 'reader_widgets.dart';
import 'settings.dart' show quoteColors;
import 'text_utils.dart';

/// Study tools: looking words up, translating a selection, a book's notes, exporting notes, sharing quotes.

const _audio = MethodChannel('lantern/audio');

// ---- dictionary ----

class DictMeaning {
  DictMeaning(this.partOfSpeech, this.definitions);
  final String partOfSpeech;
  final List<(String, String)> definitions; // (definition, example)
}

class DictResult {
  DictResult(this.word, this.phonetic, this.meanings);
  final String word, phonetic;
  final List<DictMeaning> meanings;
}

/// Reads a reply from the free English dictionary at dictionaryapi.dev.
DictResult? parseDictionary(String body) {
  final data = jsonDecode(body);
  if (data is! List || data.isEmpty || data.first is! Map) return null;
  final first = data.first as Map;
  final meanings = <DictMeaning>[];
  for (final entry in data.whereType<Map>()) {
    for (final m in (entry['meanings'] as List? ?? const []).whereType<Map>()) {
      final defs = [
        for (final d in (m['definitions'] as List? ?? const []).whereType<Map>().take(4))
          ('${d['definition'] ?? ''}'.trim(), '${d['example'] ?? ''}'.trim()),
      ].where((d) => d.$1.isNotEmpty).toList();
      if (defs.isNotEmpty) meanings.add(DictMeaning('${m['partOfSpeech'] ?? ''}', defs));
    }
  }
  if (meanings.isEmpty) return null;
  var phonetic = '${first['phonetic'] ?? ''}';
  if (phonetic.isEmpty) {
    phonetic = (first['phonetics'] as List? ?? const []).whereType<Map>().map((x) => '${x['text'] ?? ''}').firstWhere((x) => x.isNotEmpty, orElse: () => '');
  }
  return DictResult('${first['word'] ?? ''}', phonetic, meanings);
}

/// Looks [word] up in the free English dictionary; null when it isn't a single English word or isn't found.
Future<DictResult?> lookUpWord(String word) async {
  final w = word.trim().toLowerCase().replaceAll(RegExp(r"^[^\p{L}]+|[^\p{L}]+$", unicode: true), '');
  if (w.isEmpty || w.contains(' ') || !RegExp(r"^[a-z'\-]+$").hasMatch(w)) return null;
  final r = await http.get(Uri.parse('https://api.dictionaryapi.dev/api/v2/entries/en/${Uri.encodeComponent(w)}')).timeout(const Duration(seconds: 12));
  if (r.statusCode != 200) return null;
  return parseDictionary(r.body);
}

/// Opens the look-up sheet for selected words: your glossary, an English dictionary, an AI explanation of
/// what they mean in this passage, and buttons for dictionary apps and the web.
Future<void> showLookup(BuildContext context, {required String text, required String paragraph, required String bookTitle, VoidCallback? onGlossaryChanged}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      maxChildSize: 0.92,
      builder: (c, scroll) => _LookupSheet(text: text.trim(), paragraph: paragraph, bookTitle: bookTitle, scroll: scroll, onGlossaryChanged: onGlossaryChanged),
    ),
  );
}

class _LookupSheet extends StatefulWidget {
  const _LookupSheet({required this.text, required this.paragraph, required this.bookTitle, required this.scroll, this.onGlossaryChanged});
  final String text, paragraph, bookTitle;
  final ScrollController scroll;
  final VoidCallback? onGlossaryChanged;
  @override
  State<_LookupSheet> createState() => _LookupSheetState();
}

class _LookupSheetState extends State<_LookupSheet> {
  DictEntry? _mine;
  DictResult? _dict;
  bool _dictDone = false;
  String? _ai, _aiError;
  bool _aiBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final w = widget.text.toLowerCase();
    final mine = (await Db.dict()).where((d) => d.word.trim().toLowerCase() == w).firstOrNull;
    if (mounted) setState(() => _mine = mine);
    try {
      final d = await lookUpWord(widget.text);
      if (mounted) setState(() => _dict = d);
    } catch (_) {}
    if (mounted) setState(() => _dictDone = true);
    // Names and terms of the story's world aren't in dictionaries: explain them right away if an AI key is set.
    if (_dict == null && _mine == null && _hasAi) _explain();
  }

  bool get _hasAi => (settings.aiProvider == 'claude' ? settings.claudeKey : settings.geminiKey).isNotEmpty;

  Future<void> _explain() async {
    setState(() {
      _aiBusy = true;
      _aiError = null;
    });
    try {
      final r = await explainInContext(settings, widget.text, widget.paragraph, widget.bookTitle);
      if (mounted) setState(() => _ai = r.trim());
    } catch (e) {
      if (mounted) setState(() => _aiError = '$e'.replaceFirst('AiException: ', ''));
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  Future<void> _saveToGlossary() async {
    final def = _ai ?? _dict?.meanings.first.definitions.first.$1 ?? '';
    if (await showGlossaryEditor(context, entry: _mine ?? DictEntry(kind: _dict == null ? 2 : 0, word: widget.text, definition: def))) {
      widget.onGlossaryChanged?.call();
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme, cs = Theme.of(context).colorScheme;
    final d = _dict;
    return ListView(controller: widget.scroll, padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
      Text(widget.text, style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
      if (d != null && d.phonetic.isNotEmpty) Text(d.phonetic, style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
      const SizedBox(height: 12),
      if (_mine != null)
        Card(
          color: cs.secondaryContainer,
          child: ListTile(
            leading: const Icon(Icons.translate),
            title: const Text('Your glossary'),
            subtitle: Text(_mine!.definition.isEmpty ? '(no definition)' : _mine!.definition),
          ),
        ),
      if (!_dictDone)
        const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
      else if (d != null)
        for (final m in d.meanings.take(4)) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(m.partOfSpeech, style: tt.labelLarge?.copyWith(color: cs.primary, fontStyle: FontStyle.italic)),
          ),
          for (final (i, x) in m.definitions.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text.rich(TextSpan(children: [
                TextSpan(text: '${i + 1}. ', style: TextStyle(color: cs.onSurfaceVariant)),
                TextSpan(text: x.$1),
                if (x.$2.isNotEmpty) TextSpan(text: '\n“${x.$2}”', style: TextStyle(color: cs.onSurfaceVariant, fontStyle: FontStyle.italic)),
              ])),
            ),
        ],
      const SizedBox(height: 8),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.auto_awesome, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Text('In this story', style: tt.titleSmall),
            ]),
            const SizedBox(height: 8),
            if (_aiBusy)
              const LinearProgressIndicator()
            else if (_ai != null)
              SelectableText(_ai!)
            else if (_aiError != null)
              Text(_aiError!, style: TextStyle(color: cs.error))
            else
              Text(
                  _hasAi
                      ? 'Ask AI what these words mean in this passage (names, ranks, techniques, idioms).'
                      : 'Add a Gemini or Claude key in Settings → Translation to have AI explain names and terms.',
                  style: tt.bodySmall),
            if (!_aiBusy && _ai == null && _hasAi)
              Align(alignment: Alignment.centerRight, child: TextButton(onPressed: _explain, child: const Text('Explain'))),
          ]),
        ),
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 4, children: [
        OutlinedButton.icon(
          icon: const Icon(Icons.bookmark_add_outlined, size: 18),
          label: Text(_mine == null ? 'Save to glossary' : 'Edit glossary entry'),
          onPressed: _saveToGlossary,
        ),
        if (Platform.isAndroid)
          OutlinedButton.icon(
            icon: const Icon(Icons.menu_book_outlined, size: 18),
            label: const Text('Dictionary app'),
            onPressed: () async {
              final ok = await _audio.invokeMethod<bool>('processText', {'text': widget.text}).catchError((_) => false);
              if (ok != true && context.mounted) {
                toast(context, 'No dictionary app is installed. GoldenDict, ColorDict and Google Translate work with Lantern.');
              }
            },
          ),
        OutlinedButton.icon(
          icon: const Icon(Icons.public, size: 18),
          label: const Text('Web'),
          onPressed: () {
            final url = settings.dictUrl.replaceAll('%s', Uri.encodeQueryComponent(widget.text));
            Navigator.push(context, MaterialPageRoute(builder: (_) => BrowserScreen(initialUrl: url, standalone: true)));
          },
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.copy, size: 18),
          label: const Text('Copy'),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: widget.text));
            toast(context, 'Copied.');
          },
        ),
      ]),
    ]);
  }
}

// ---- translation of a selection ----

/// Shows the translation of selected text, with Copy and "Save as note" (keeps the translation as a
/// highlight's note). [onSaveNote] is null when notes can't be saved here.
Future<void> showSelectionTranslation(BuildContext context, String text, {Future<void> Function(String translation)? onSaveNote}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => FutureBuilder<String>(
      future: translateSnippet(settings, text),
      builder: (c, snap) {
        final tt = Theme.of(c).textTheme, cs = Theme.of(c).colorScheme;
        final done = snap.connectionState == ConnectionState.done;
        final tr = snap.data?.trim() ?? '';
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(text, maxLines: 4, overflow: TextOverflow.ellipsis, style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
              const Divider(height: 24),
              Text('In ${settings.targetLang}', style: tt.labelLarge?.copyWith(color: cs.primary)),
              const SizedBox(height: 6),
              if (!done)
                const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
              else if (snap.hasError)
                Text('${snap.error}'.replaceFirst('AiException: ', ''), style: TextStyle(color: cs.error))
              else
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(c).height * 0.45),
                  child: SingleChildScrollView(child: SelectableText(tr, style: tt.bodyLarge)),
                ),
              const SizedBox(height: 12),
              if (done && !snap.hasError)
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton.icon(
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy'),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: tr));
                      toast(c, 'Copied.');
                    },
                  ),
                  if (onSaveNote != null)
                    FilledButton.icon(
                      icon: const Icon(Icons.sticky_note_2_outlined, size: 18),
                      label: const Text('Save as note'),
                      onPressed: () async {
                        await onSaveNote(tr);
                        if (c.mounted) Navigator.pop(c);
                      },
                    ),
                ]),
            ]),
          ),
        );
      },
    ),
  );
}

// ---- exporting notes ----

/// A book's (or several books') highlights and notes as Markdown.
String notesMarkdown(List<(String bookTitle, List<(Quote, String chapterTitle)>)> books) {
  final sb = StringBuffer();
  for (final (title, quotes) in books) {
    sb.writeln('# $title\n');
    for (final (q, ch) in quotes) {
      for (final line in q.text.split('\n')) {
        sb.writeln('> $line');
      }
      if (q.note.isNotEmpty) sb.writeln('\n**Note:** ${q.note}');
      sb.writeln('\n— ${ch.isEmpty ? '' : '$ch, '}${fmtDate(q.createdAt)}\n');
    }
  }
  return sb.toString();
}

/// The same as plain text.
String notesText(List<(String, List<(Quote, String)>)> books) {
  final sb = StringBuffer();
  for (final (title, quotes) in books) {
    sb.writeln(title.toUpperCase());
    sb.writeln('=' * title.length.clamp(3, 60));
    for (final (q, ch) in quotes) {
      sb.writeln('\n“${q.text}”');
      if (q.note.isNotEmpty) sb.writeln('Note: ${q.note}');
      sb.writeln('— ${ch.isEmpty ? '' : '$ch, '}${fmtDate(q.createdAt)}');
    }
    sb.writeln();
  }
  return sb.toString();
}

String _x(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');

/// The same as a Word document (.docx).
Uint8List notesDocx(List<(String, List<(Quote, String)>)> books) {
  final body = StringBuffer();
  void para(String text, {String? style, bool italic = false, String? color}) {
    final rpr = [if (italic) '<w:i/>', if (color != null) '<w:color w:val="$color"/>'].join();
    body.write('<w:p>${style == null ? '' : '<w:pPr><w:pStyle w:val="$style"/></w:pPr>'}');
    final lines = text.split('\n');
    for (var i = 0; i < lines.length; i++) {
      body.write('<w:r>${rpr.isEmpty ? '' : '<w:rPr>$rpr</w:rPr>'}${i > 0 ? '<w:br/>' : ''}<w:t xml:space="preserve">${_x(lines[i])}</w:t></w:r>');
    }
    body.write('</w:p>');
  }

  for (final (title, quotes) in books) {
    para(title, style: 'Heading1');
    for (final (q, ch) in quotes) {
      para('“${q.text}”', style: 'Quote', italic: true);
      if (q.note.isNotEmpty) para('Note: ${q.note}');
      para('— ${ch.isEmpty ? '' : '$ch, '}${fmtDate(q.createdAt)}', color: '777777');
    }
  }
  const styles = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
      '<w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/><w:pPr><w:spacing w:after="120"/></w:pPr>'
      '<w:rPr><w:sz w:val="22"/></w:rPr></w:style>'
      '<w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="heading 1"/><w:basedOn w:val="Normal"/><w:pPr><w:spacing w:before="360" w:after="160"/>'
      '<w:outlineLvl w:val="0"/></w:pPr><w:rPr><w:b/><w:sz w:val="32"/></w:rPr></w:style>'
      '<w:style w:type="paragraph" w:styleId="Quote"><w:name w:val="Quote"/><w:basedOn w:val="Normal"/><w:pPr><w:ind w:left="567"/>'
      '<w:pBdr><w:left w:val="single" w:sz="18" w:space="8" w:color="C0874F"/></w:pBdr></w:pPr></w:style></w:styles>';
  final doc = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>$body'
      '<w:sectPr><w:pgSz w:w="12240" w:h="15840"/><w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/></w:sectPr></w:body></w:document>';
  final a = Archive()
    ..addFile(ArchiveFile.string('[Content_Types].xml',
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
        '<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/></Types>'))
    ..addFile(ArchiveFile.string('_rels/.rels',
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>'))
    ..addFile(ArchiveFile.string('word/_rels/document.xml.rels',
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>'))
    ..addFile(ArchiveFile.string('word/styles.xml', styles))
    ..addFile(ArchiveFile.string('word/document.xml', doc));
  return Uint8List.fromList(ZipEncoder().encode(a));
}

/// Loads highlights (of one book, or all) grouped by book with chapter titles, newest book first.
Future<List<(String, List<(Quote, String)>)>> loadNotes({int? bookId}) async {
  final quotes = await Db.quotes(bookId: bookId);
  final books = {for (final b in await Db.books()) b.id!: b};
  final chTitles = <int, String>{};
  final by = <int, List<(Quote, String)>>{};
  for (final q in quotes) {
    if (!chTitles.containsKey(q.chapterId)) {
      final metas = await Db.chapterMetas(q.bookId);
      for (final m in metas) {
        chTitles[m.id] = m.title;
      }
    }
    (by[q.bookId] ??= []).add((q, chTitles[q.chapterId] ?? ''));
  }
  // In reading order within a book.
  for (final l in by.values) {
    l.sort((a, b) {
      final c = a.$1.chapterId.compareTo(b.$1.chapterId);
      return c != 0 ? c : (a.$1.para != b.$1.para ? a.$1.para.compareTo(b.$1.para) : a.$1.start.compareTo(b.$1.start));
    });
  }
  return [for (final e in by.entries) (books[e.key]?.title ?? 'A removed book', e.value)];
}

/// Asks for a format and offers the notes file.
Future<void> exportNotes(BuildContext context, {int? bookId, String name = 'highlights'}) async {
  final notes = await loadNotes(bookId: bookId);
  if (!context.mounted) return;
  if (notes.isEmpty) return toast(context, 'There are no highlights to export yet.');
  final fmt = await showDialog<String>(
    context: context,
    builder: (c) => SimpleDialog(title: const Text('Export highlights and notes as'), children: [
      SimpleDialogOption(onPressed: () => Navigator.pop(c, 'docx'), child: const ListTile(leading: Icon(Icons.description_outlined), title: Text('Word document'), subtitle: Text('.docx'))),
      SimpleDialogOption(onPressed: () => Navigator.pop(c, 'md'), child: const ListTile(leading: Icon(Icons.notes), title: Text('Markdown'), subtitle: Text('.md, for Obsidian, Notion…'))),
      SimpleDialogOption(onPressed: () => Navigator.pop(c, 'txt'), child: const ListTile(leading: Icon(Icons.text_snippet_outlined), title: Text('Plain text'), subtitle: Text('.txt'))),
    ]),
  );
  if (fmt == null || !context.mounted) return;
  final file = '${safeFileName(name)}.$fmt';
  final bytes = switch (fmt) {
    'docx' => notesDocx(notes),
    'md' => Uint8List.fromList(utf8.encode(notesMarkdown(notes))),
    _ => Uint8List.fromList(utf8.encode(notesText(notes))),
  };
  await offerFile(context, file, bytes);
}

// ---- sharing a quote ----

/// Draws a quote as a picture to share: the words on a coloured card with the book and author below.
Future<Uint8List> quoteImage(String quote, String book, String author, {Color bg = const Color(0xFF3B2A20), Color fg = const Color(0xFFF7EBDD)}) async {
  const w = 1080.0, pad = 96.0;
  final text = quote.trim().length > 900 ? '${quote.trim().substring(0, 900)}…' : quote.trim();
  final size = text.length < 120 ? 58.0 : (text.length < 300 ? 46.0 : 36.0);
  ui.Paragraph para(String s, double fontSize, {FontWeight weight = FontWeight.w400, FontStyle style = FontStyle.normal, double alpha = 1, double height = 1.35}) {
    final b = ui.ParagraphBuilder(ui.ParagraphStyle(fontSize: fontSize, height: height, fontWeight: weight, fontStyle: style, fontFamily: 'Literata'))
      ..pushStyle(ui.TextStyle(color: fg.withValues(alpha: alpha)))
      ..addText(s);
    return b.build()..layout(const ui.ParagraphConstraints(width: w - pad * 2));
  }

  final mark = para('“', 160, weight: FontWeight.w700, alpha: 0.35, height: 1);
  final body = para(text, size);
  final by = para([book, if (author.isNotEmpty) author].join('\n'), 34, weight: FontWeight.w600, alpha: 0.75, height: 1.3);
  final app = para('Lantern Reader', 26, alpha: 0.4);
  final h = (pad + 110 + body.height + 70 + by.height + 70 + app.height + pad).clamp(w * 0.8, 4000.0);
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  c.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = bg);
  c.drawRect(Rect.fromLTWH(pad * 0.55, pad, 8, h - pad * 2), Paint()..color = fg.withValues(alpha: 0.25));
  c.drawParagraph(mark, Offset(pad, pad - 30));
  var y = pad + 110;
  c.drawParagraph(body, Offset(pad, y));
  y += body.height + 70;
  c.drawParagraph(by, Offset(pad, y));
  c.drawParagraph(app, Offset(pad, h - pad - app.height));
  final img = await rec.endRecording().toImage(w.toInt(), h.toInt());
  final png = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  return png!.buffer.asUint8List();
}

/// Shares a quote as text or as a picture.
Future<void> shareQuote(BuildContext context, Quote q) async {
  final b = await Db.book(q.bookId);
  final title = b?.title ?? '', author = b?.author ?? '';
  if (!context.mounted) return;
  final how = await showDialog<String>(
    context: context,
    builder: (c) => SimpleDialog(title: const Text('Share this quote'), children: [
      SimpleDialogOption(onPressed: () => Navigator.pop(c, 'image'), child: const ListTile(leading: Icon(Icons.image_outlined), title: Text('As a picture'))),
      SimpleDialogOption(onPressed: () => Navigator.pop(c, 'text'), child: const ListTile(leading: Icon(Icons.short_text), title: Text('As text'))),
    ]),
  );
  if (how == null) return;
  final text = '“${q.text.trim()}”\n— $title${author.isEmpty ? '' : ', $author'}';
  if (how == 'text') {
    await SharePlus.instance.share(ShareParams(text: text));
    return;
  }
  final png = await quoteImage(q.text, title, author);
  final f = File(p.join(Directory.systemTemp.path, 'quote_${DateTime.now().millisecondsSinceEpoch}.png'));
  await f.writeAsBytes(png);
  await SharePlus.instance.share(ShareParams(files: [XFile(f.path, mimeType: 'image/png')], text: text));
}

// ---- a book's notes ----

/// One book's highlights, notes and bookmarks, with export.
class BookNotesScreen extends StatefulWidget {
  final Book book;
  final void Function(int chapterIdx, int para)? onOpen;
  const BookNotesScreen({super.key, required this.book, this.onOpen});
  @override
  State<BookNotesScreen> createState() => _BookNotesScreenState();
}

class _BookNotesScreenState extends State<BookNotesScreen> {
  List<(Quote, String)> _quotes = [];
  List<Bookmark> _marks = [];
  Map<int, (int, String)> _chapters = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final n = await loadNotes(bookId: widget.book.id);
    final marks = await Db.bookmarks(bookId: widget.book.id);
    final metas = await Db.chapterMetas(widget.book.id!);
    if (!mounted) return;
    setState(() {
      _quotes = n.isEmpty ? [] : n.first.$2;
      _marks = marks;
      _chapters = {for (final m in metas) m.id: (m.idx, m.title)};
      _loaded = true;
    });
  }

  void _go(int chapterId, int para) {
    final idx = _chapters[chapterId]?.$1;
    if (idx == null) return toast(context, 'That chapter has been deleted.');
    widget.onOpen?.call(idx, para);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme, tt = Theme.of(context).textTheme;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.book.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(
              tooltip: 'Export',
              icon: const Icon(Icons.ios_share),
              onPressed: () => exportNotes(context, bookId: widget.book.id, name: '${widget.book.title} – highlights'),
            ),
          ],
          bottom: TabBar(tabs: [Tab(text: 'Highlights & notes (${_quotes.length})'), Tab(text: 'Bookmarks (${_marks.length})')]),
        ),
        body: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(children: [
                _quotes.isEmpty
                    ? Center(child: Padding(padding: const EdgeInsets.all(32), child: Text('Select text while reading to highlight it or add a note.', textAlign: TextAlign.center, style: tt.bodyLarge)))
                    : ListView.separated(
                        itemCount: _quotes.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (c, i) {
                          final (q, ch) = _quotes[i];
                          return ListTile(
                            leading: Container(width: 6, height: 44, decoration: BoxDecoration(color: quoteColors[q.color % quoteColors.length], borderRadius: BorderRadius.circular(3))),
                            title: Text(q.text, maxLines: 5, overflow: TextOverflow.ellipsis),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text([if (q.note.isNotEmpty) 'Note: ${q.note}', ch].join('\n')),
                            ),
                            onTap: () => _go(q.chapterId, q.para),
                            trailing: PopupMenuButton<String>(
                              onSelected: (v) async {
                                if (v == 'edit' && await showQuoteSheet(context, q)) _load();
                                if (v == 'share' && context.mounted) await shareQuote(context, q);
                              },
                              itemBuilder: (c) => const [
                                PopupMenuItem(value: 'edit', child: Text('Colour, note or delete')),
                                PopupMenuItem(value: 'share', child: Text('Share')),
                              ],
                            ),
                          );
                        },
                      ),
                _marks.isEmpty
                    ? Center(child: Text('No bookmarks yet.', style: tt.bodyLarge))
                    : ListView(children: [
                        for (final b in _marks)
                          ListTile(
                            leading: Icon(Icons.bookmark, color: cs.primary),
                            title: Text(b.snippet, maxLines: 2, overflow: TextOverflow.ellipsis),
                            subtitle: Text('${_chapters[b.chapterId]?.$2 ?? ''} · ${fmtDate(b.createdAt)}'),
                            onTap: () => _go(b.chapterId, b.para),
                          ),
                      ]),
              ]),
      ),
    );
  }
}
