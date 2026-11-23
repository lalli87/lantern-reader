import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'app.dart';
import 'db.dart';
import 'models.dart';
import 'settings.dart';
import 'text_utils.dart';

/// One paragraph (or the slice of it on a page) with highlights, glossary marks and the
/// narration marker painted in, and text selection enabled.
class ParaText extends StatefulWidget {
  final String text;
  final int para, base;
  final TextStyle style;
  final TextAlign align;
  final List<Quote> quotes;
  final RegExp? glossary;
  final int spokenStart, spokenEnd; // range within the paragraph being read aloud; -1 if none
  final Color spokenColor;
  final bool dark;
  final void Function(Quote q) onQuoteTap;
  final void Function(String word) onGlossaryTap;
  final void Function(bool hasSelection) onSelection;
  final Widget Function(BuildContext, EditableTextState, int para, int base) menuBuilder;

  const ParaText({
    super.key,
    required this.text,
    required this.para,
    this.base = 0,
    required this.style,
    required this.align,
    required this.quotes,
    required this.glossary,
    this.spokenStart = -1,
    this.spokenEnd = -1,
    required this.spokenColor,
    required this.dark,
    required this.onQuoteTap,
    required this.onGlossaryTap,
    required this.onSelection,
    required this.menuBuilder,
  });

  @override
  State<ParaText> createState() => _ParaTextState();
}

class _ParaTextState extends State<ParaText> {
  final _recognizers = <TapGestureRecognizer>[];
  late TextSpan _span;

  @override
  void initState() {
    super.initState();
    _span = _build();
  }

  @override
  void didUpdateWidget(ParaText old) {
    super.didUpdateWidget(old);
    final w = widget;
    if (old.text != w.text ||
        old.style != w.style ||
        old.quotes != w.quotes ||
        old.glossary != w.glossary ||
        old.spokenStart != w.spokenStart ||
        old.spokenEnd != w.spokenEnd ||
        old.spokenColor != w.spokenColor) {
      final stale = List.of(_recognizers);
      _recognizers.clear();
      _span = _build();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final r in stale) {
          r.dispose();
        }
      });
    }
  }

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  TextSpan _build() {
    final w = widget, t = w.text, n = t.length;
    final quotes = <(int, int, Quote)>[];
    for (final q in w.quotes) {
      final a = (q.start - w.base).clamp(0, n), b = (q.end - w.base).clamp(0, n);
      if (b > a) quotes.add((a, b, q));
    }
    final gloss = <(int, int)>[];
    if (w.glossary != null) {
      for (final m in w.glossary!.allMatches(t).take(40)) {
        gloss.add((m.start, m.end));
      }
    }
    final sa = w.spokenStart < 0 ? -1 : (w.spokenStart - w.base).clamp(0, n);
    final sb = w.spokenStart < 0 ? -1 : (w.spokenEnd - w.base).clamp(0, n);
    if (quotes.isEmpty && gloss.isEmpty && sb <= sa) return TextSpan(text: t, style: w.style);

    final cuts = <int>{0, n};
    for (final q in quotes) {
      cuts
        ..add(q.$1)
        ..add(q.$2);
    }
    for (final g in gloss) {
      cuts
        ..add(g.$1)
        ..add(g.$2);
    }
    if (sb > sa) {
      cuts
        ..add(sa)
        ..add(sb);
    }
    final pts = cuts.toList()..sort();
    final children = <InlineSpan>[];
    for (var i = 0; i + 1 < pts.length; i++) {
      final a = pts[i], b = pts[i + 1];
      final q = quotes.where((x) => x.$1 <= a && x.$2 >= b).firstOrNull?.$3;
      final g = gloss.where((x) => x.$1 <= a && x.$2 >= b).firstOrNull;
      final spoken = sb > sa && sa <= a && sb >= b;
      TapGestureRecognizer? rec;
      if (q != null) {
        rec = TapGestureRecognizer()..onTap = () => w.onQuoteTap(q);
      } else if (g != null) {
        final word = t.substring(g.$1, g.$2);
        rec = TapGestureRecognizer()..onTap = () => w.onGlossaryTap(word);
      }
      if (rec != null) _recognizers.add(rec);
      children.add(TextSpan(
        text: t.substring(a, b),
        recognizer: rec,
        style: TextStyle(
          backgroundColor: q != null
              ? quoteColors[q.color % quoteColors.length].withValues(alpha: w.dark ? 0.38 : 0.5)
              : (spoken ? w.spokenColor : null),
          decoration: g != null || (q != null && q.note.isNotEmpty) ? TextDecoration.underline : null,
          decorationStyle: g != null ? TextDecorationStyle.dotted : TextDecorationStyle.solid,
        ),
      ));
    }
    return TextSpan(style: w.style, children: children);
  }

  @override
  Widget build(BuildContext context) {
    return SelectableText.rich(
      _span,
      textAlign: widget.align,
      textScaler: TextScaler.noScaling,
      onSelectionChanged: (sel, cause) => widget.onSelection(!sel.isCollapsed),
      contextMenuBuilder: (c, ets) => widget.menuBuilder(c, ets, widget.para, widget.base),
    );
  }
}

/// Typography and layout controls shown from the reader's "Aa" button.
class ReaderSettingsSheet extends StatelessWidget {
  final double? brightness;
  final ValueChanged<double> onBrightness;
  const ReaderSettingsSheet({super.key, required this.brightness, required this.onBrightness});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final s = settings;
        final fonts = <String, String>{
          for (final f in bundledFonts) f: f,
          ...systemFonts,
          for (final f in s.userFonts) f['name']!: f['name']!,
        };
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                height: 64,
                child: Row(children: [
                  for (final t in readerThemes)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => s.setReaderTheme(t.id),
                          child: Container(
                            decoration: BoxDecoration(
                              color: t.bg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: s.themeId == t.id ? Theme.of(context).colorScheme.primary : Colors.grey.withValues(alpha: 0.4),
                                  width: s.themeId == t.id ? 2.5 : 1),
                            ),
                            alignment: Alignment.center,
                            child: Text(t.label, style: TextStyle(color: t.fg, fontSize: 12.5, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('font-${s.fontFamily}-${fonts.length}'),
                    initialValue: fonts.containsKey(s.fontFamily) ? s.fontFamily : 'system',
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Font', border: OutlineInputBorder(), isDense: true),
                    items: [
                      for (final e in fonts.entries)
                        DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value, style: TextStyle(fontFamily: systemFonts.containsKey(e.key) && e.key == 'system' ? null : e.key)),
                        )
                    ],
                    onChanged: (v) => s.set('fontFamily', v),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Add a font file',
                  icon: const Icon(Icons.add),
                  onPressed: () => addUserFont(context),
                ),
              ]),
              _slider(context, Icons.format_size, 'Size', s.fontSize, 12, 40, (v) => s.set('fontSize', v.roundToDouble()), '${s.fontSize.round()}'),
              _slider(context, Icons.format_line_spacing, 'Line spacing', s.lineHeight, 1.0, 2.4,
                  (v) => s.set('lineHeight', (v * 20).round() / 20), s.lineHeight.toStringAsFixed(2)),
              _slider(context, Icons.space_bar, 'Margins', s.margin, 4, 64, (v) => s.set('margin', v.roundToDouble()), '${s.margin.round()}'),
              _slider(context, Icons.segment, 'Paragraph gap', s.paraSpacing, 0, 1.6,
                  (v) => s.set('paraSpacing', (v * 10).round() / 10), s.paraSpacing.toStringAsFixed(1)),
              _slider(context, Icons.brightness_6, 'Brightness', brightness ?? 0.5, 0.02, 1, onBrightness,
                  brightness == null ? 'auto' : '${(brightness! * 100).round()}%'),
              const SizedBox(height: 4),
              Wrap(spacing: 8, runSpacing: 4, children: [
                FilterChip(label: const Text('Bold'), selected: s.bold, onSelected: (v) => s.set('bold', v)),
                FilterChip(label: const Text('Justify'), selected: s.justify, onSelected: (v) => s.set('justify', v)),
                FilterChip(label: const Text('Turn pages'), selected: s.paged, onSelected: (v) => s.set('paged', v)),
                FilterChip(label: const Text('Keep screen on'), selected: s.keepScreenOn, onSelected: (v) => s.set('keepScreenOn', v)),
                FilterChip(label: const Text('Clock & battery'), selected: s.statusLine, onSelected: (v) => s.set('statusLine', v)),
                if (s.paged)
                  FilterChip(label: const Text('Two pages in landscape'), selected: s.twoPages, onSelected: (v) => s.set('twoPages', v)),
              ]),
              _slider(context, Icons.wb_twilight, 'Warm light', s.warmth, 0, 1, (v) => s.set('warmth', (v * 20).round() / 20),
                  s.warmth == 0 ? 'off' : '${(s.warmth * 100).round()}%'),
              if (s.paged) ...[
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'slide', label: Text('Slide')),
                    ButtonSegment(value: 'turn', label: Text('Page turn')),
                    ButtonSegment(value: 'none', label: Text('No animation')),
                  ],
                  selected: {s.pageTurn},
                  showSelectedIcon: false,
                  onSelectionChanged: (v) => s.set('pageTurn', v.first),
                ),
              ],
              const SizedBox(height: 12),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Auto'), icon: Icon(Icons.screen_rotation)),
                  ButtonSegment(value: 1, label: Text('Portrait'), icon: Icon(Icons.stay_current_portrait)),
                  ButtonSegment(value: 2, label: Text('Landscape'), icon: Icon(Icons.stay_current_landscape)),
                ],
                selected: {s.orientation},
                showSelectedIcon: false,
                onSelectionChanged: (v) => s.set('orientation', v.first),
              ),
            ]),
          ),
        );
      },
    );
  }

  Widget _slider(BuildContext context, IconData icon, String label, double value, double min, double max,
      ValueChanged<double> onChanged, String shown) {
    return Row(children: [
      Icon(icon, size: 20),
      const SizedBox(width: 8),
      SizedBox(width: 92, child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
      Expanded(child: Slider(value: value.clamp(min, max), min: min, max: max, onChanged: onChanged)),
      SizedBox(width: 40, child: Text(shown, textAlign: TextAlign.end)),
    ]);
  }
}

/// Lets the user pick a .ttf/.otf file and registers it as a reading font.
Future<void> addUserFont(BuildContext context) async {
  final x = await openFile();
  if (x == null) return;
  final ext = p.extension(x.name).toLowerCase();
  if (ext != '.ttf' && ext != '.otf') {
    if (context.mounted) toast(context, 'Choose a .ttf or .otf font file.');
    return;
  }
  final name = p.basenameWithoutExtension(x.name).replaceAll(RegExp(r'[-_]+'), ' ').trim();
  final file = '${safeFileName(name)}$ext';
  await Directory(fontsDir).create(recursive: true);
  await File(p.join(fontsDir, file)).writeAsBytes(await x.readAsBytes());
  if (!await loadFontFile(name, p.join(fontsDir, file))) {
    if (context.mounted) toast(context, 'That font file could not be read.');
    return;
  }
  final list = settings.userFonts..removeWhere((f) => f['name'] == name);
  settings.set('userFonts', [...list, {'name': name, 'file': file}]);
  settings.set('fontFamily', name);
}

/// Contents, bookmarks and highlights for the open book.
class ContentsSheet extends StatefulWidget {
  final Book book;
  final List<ChapterMeta> metas;
  final int currentIdx;
  final void Function(int chapterIdx, int para) onOpen;
  const ContentsSheet({super.key, required this.book, required this.metas, required this.currentIdx, required this.onOpen});

  @override
  State<ContentsSheet> createState() => _ContentsSheetState();
}

class _ContentsSheetState extends State<ContentsSheet> {
  List<Bookmark> _bookmarks = [];
  List<Quote> _quotes = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final b = await Db.bookmarks(bookId: widget.book.id);
    final q = await Db.quotes(bookId: widget.book.id);
    if (mounted) {
      setState(() {
        _bookmarks = b;
        _quotes = q;
      });
    }
  }

  int _idxOf(int chapterId) {
    final i = widget.metas.indexWhere((m) => m.id == chapterId);
    return i < 0 ? 0 : i;
  }

  String _titleOf(int chapterId) => widget.metas.where((m) => m.id == chapterId).firstOrNull?.title ?? '';

  void _go(int idx, int para) {
    Navigator.pop(context);
    widget.onOpen(idx, para);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 3,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (context, scroll) => Column(children: [
          TabBar(tabs: [
            Tab(text: 'Chapters (${widget.metas.length})'),
            Tab(text: 'Bookmarks (${_bookmarks.length})'),
            Tab(text: 'Highlights (${_quotes.length})'),
          ]),
          Expanded(
            child: TabBarView(children: [
              ListView.builder(
                controller: ScrollController(initialScrollOffset: (widget.currentIdx * 52.0 - 120).clamp(0, double.infinity)),
                itemExtent: 52,
                itemCount: widget.metas.length,
                itemBuilder: (c, i) {
                  final m = widget.metas[i];
                  final cur = i == widget.currentIdx;
                  return ListTile(
                    dense: true,
                    selected: cur,
                    leading: SizedBox(width: 34, child: Text('${i + 1}', style: TextStyle(color: cs.onSurfaceVariant))),
                    title: Text(m.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: cur ? FontWeight.w700 : null)),
                    trailing: m.hasTranslation ? const Icon(Icons.translate, size: 16) : null,
                    onTap: () => _go(i, 0),
                  );
                },
              ),
              _bookmarks.isEmpty
                  ? const _Empty('No bookmarks yet. Tap the bookmark icon while reading.')
                  : ListView(children: [
                      for (final b in _bookmarks)
                        ListTile(
                          leading: const Icon(Icons.bookmark),
                          title: Text(b.snippet, maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle: Text('${_titleOf(b.chapterId)} · ${fmtDate(b.createdAt)}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () async {
                              await Db.deleteBookmark(b.id!);
                              _load();
                            },
                          ),
                          onTap: () => _go(_idxOf(b.chapterId), b.para),
                        ),
                    ]),
              _quotes.isEmpty
                  ? const _Empty('No highlights yet. Select text while reading to highlight it or add a note.')
                  : ListView(children: [
                      for (final q in _quotes)
                        ListTile(
                          leading: CircleAvatar(radius: 8, backgroundColor: quoteColors[q.color % quoteColors.length]),
                          title: Text(q.text, maxLines: 3, overflow: TextOverflow.ellipsis),
                          subtitle: Text([if (q.note.isNotEmpty) 'Note: ${q.note}', _titleOf(q.chapterId)].join('\n')),
                          isThreeLine: q.note.isNotEmpty,
                          onTap: () => _go(_idxOf(q.chapterId), q.para),
                        ),
                    ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty(this.text);
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
      );
}

/// Edit sheet for one highlight: colour, note, copy, delete. Returns true if anything changed.
Future<bool> showQuoteSheet(BuildContext context, Quote q) async {
  final note = TextEditingController(text: q.note);
  var changed = false;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => StatefulBuilder(
      builder: (c, setS) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(c).bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('“${q.text}”', maxLines: 5, overflow: TextOverflow.ellipsis, style: Theme.of(c).textTheme.bodyLarge),
          const SizedBox(height: 14),
          Row(children: [
            for (var i = 0; i < quoteColors.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () async {
                    q.color = i;
                    settings.set('quoteColor', i);
                    await Db.updateQuote(q);
                    changed = true;
                    setS(() {});
                  },
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: quoteColors[i],
                    child: q.color == i ? const Icon(Icons.check, size: 18, color: Colors.black87) : null,
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 14),
          TextField(
            controller: note,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Note', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          Row(children: [
            TextButton.icon(
              icon: const Icon(Icons.delete_outline),
              label: const Text('Remove'),
              onPressed: () async {
                await Db.deleteQuote(q.id!);
                changed = true;
                note.text = q.note;
                if (c.mounted) Navigator.pop(c);
              },
            ),
            const Spacer(),
            FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Done')),
          ]),
        ]),
      ),
    ),
  );
  if (note.text != q.note && (await Db.quotes(chapterId: q.chapterId)).any((x) => x.id == q.id)) {
    q.note = note.text;
    await Db.updateQuote(q);
    changed = true;
  }
  return changed;
}

/// Add or edit a glossary entry. Returns true if saved.
Future<bool> showGlossaryEditor(BuildContext context, {DictEntry? entry, String word = '', int kind = 0}) async {
  final e = entry ?? DictEntry(kind: kind, word: word);
  final w = TextEditingController(text: e.word), d = TextEditingController(text: e.definition);
  var k = e.kind;
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setS) => AlertDialog(
        title: Text(entry == null ? 'Add to glossary' : 'Edit entry'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Word')),
                ButtonSegment(value: 1, label: Text('Character')),
                ButtonSegment(value: 2, label: Text('Term')),
              ],
              selected: {k},
              showSelectedIcon: false,
              onSelectionChanged: (v) => setS(() => k = v.first),
            ),
            const SizedBox(height: 14),
            TextField(controller: w, decoration: const InputDecoration(labelText: 'Word or name', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(
              controller: d,
              minLines: 2,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: k == 0 ? 'Meaning or translation' : (k == 1 ? 'Who they are' : 'Definition'),
                border: const OutlineInputBorder(),
              ),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Save')),
        ],
      ),
    ),
  );
  if (ok != true || w.text.trim().isEmpty) return false;
  e
    ..word = w.text.trim()
    ..definition = d.text.trim()
    ..kind = k;
  if (e.id == null) {
    await Db.addDict(e);
  } else {
    await Db.updateDict(e);
  }
  return true;
}

/// Matches any glossary word as a whole word, longest first. Null when the glossary is empty.
RegExp? glossaryPattern(List<DictEntry> entries) {
  final words = entries.map((e) => e.word.trim()).where((w) => w.length > 1).toSet().toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  if (words.isEmpty) return null;
  final alt = words.take(400).map(RegExp.escape).join('|');
  return RegExp('(?<![\\p{L}\\p{N}])(?:$alt)(?![\\p{L}\\p{N}])', caseSensitive: false, unicode: true);
}
