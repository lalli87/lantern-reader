import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'ai.dart';
import 'app.dart';
import 'book_detail.dart';
import 'browser.dart';
import 'db.dart';
import 'models.dart';
import 'narration_ui.dart';
import 'pagination.dart';
import 'file_pick.dart';
import 'pdf_import.dart';
import 'pdf_pages.dart';
import 'reader_widgets.dart';
import 'settings.dart';
import 'text_utils.dart';

class ReaderScreen extends StatefulWidget {
  final int bookId;
  final int? chapterIdx, para;
  const ReaderScreen({super.key, required this.bookId, this.chapterIdx, this.para});

  @override
  State<ReaderScreen> createState() => _ReaderState();
}

class _ReaderState extends State<ReaderScreen> {
  Book? _book;
  List<ChapterMeta> _metas = [];
  Chapter? _chapter;
  List<String> _paras = [];
  int _idx = 0, _topPara = 0;
  bool _showTr = false, _chrome = false, _loading = true, _busy = false;
  String? _loadError;

  Map<int, List<Quote>> _quotes = {};
  Set<int> _bookmarked = {};
  List<DictEntry> _glossary = [];
  RegExp? _glossRe;

  // Scroll mode
  ItemScrollController _itemCtrl = ItemScrollController();
  ItemPositionsListener _itemPos = ItemPositionsListener.create();
  int _listGen = 0;

  // Page mode
  PageController? _pageCtrl;
  List<List<PageSeg>> _pages = [];
  String _pagesKey = '';
  int _pageNo = 0;

  // Original PDF pages
  bool _hasPdf = false, _pdfMode = false;
  PdfPageMap _pdfMap = PdfPageMap.empty();
  PdfViewerController _pdfCtrl = PdfViewerController();
  int _pdfPage = 1; // 1-based, as pdfrx counts
  int _pdfGen = 0;

  // Narration marker
  int _spokenPara = -1, _spokenStart = -1, _spokenEnd = -1, _spokenLast = -1;

  // Taps
  Offset? _downPos;
  DateTime _downAt = DateTime.now(), _spanTapAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _selActive = false, _selAtDown = false;
  Timer? _tapTimer, _saveTimer, _brightHide;
  double? _brightness;
  bool _brightShown = false;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    settings.addListener(_onSettings);
    narrator.state.addListener(_onNarration);
    _itemPos.itemPositions.addListener(_onScroll);
    _applySystem();
    _load();
  }

  @override
  void dispose() {
    _savePosition();
    settings.removeListener(_onSettings);
    narrator.state.removeListener(_onNarration);
    _itemPos.itemPositions.removeListener(_onScroll);
    _tapTimer?.cancel();
    _saveTimer?.cancel();
    _brightHide?.cancel();
    _pageCtrl?.dispose();
    _focus.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(const []);
    WakelockPlus.disable().catchError((_) {});
    ScreenBrightness.instance.resetApplicationScreenBrightness().catchError((_) {});
    bumpLibrary();
    super.dispose();
  }

  // ---- loading ----

  Future<void> _load() async {
    final b = await Db.book(widget.bookId);
    if (b == null) {
      if (mounted) setState(() => _loadError = 'This book is no longer in the library.');
      return;
    }
    _book = b;
    _metas = await Db.chapterMetas(b.id!);
    _glossary = await Db.dict();
    _glossRe = settings.markGlossary ? glossaryPattern(_glossary) : null;
    if (_metas.isEmpty) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = 'This book has no chapters yet. Save some from the Web tab.';
        });
      }
      return;
    }
    _hasPdf = b.format == 'PDF' && hasOriginalPdf(b.id!);
    _pdfMap = _hasPdf ? await loadPdfPageMap(b.id!) : PdfPageMap.empty();
    _pdfMode = _hasPdf && settings.pdfPageView;
    final ns = narrator.state.value;
    _showTr = ns.bookId == b.id && narrator.usingTranslation;
    await _open(widget.chapterIdx ?? b.curChapter, para: widget.para ?? b.curPara);
  }

  Future<void> _open(int idx, {int para = 0, bool fromPdf = false}) async {
    if (_metas.isEmpty) return;
    idx = idx.clamp(0, _metas.length - 1);
    final ch = await Db.chapterAt(_book!.id!, idx);
    if (ch == null) return;
    final qs = await Db.quotes(chapterId: ch.id);
    final bs = await Db.bookmarks(bookId: _book!.id);
    if (!mounted) return;
    setState(() {
      _chapter = ch;
      _idx = idx;
      if (ch.translated.isEmpty) _showTr = false;
      _paras = splitParas(_showTr ? ch.translated : ch.content);
      _setQuotes(qs);
      _bookmarked = bs.where((b) => b.chapterId == ch.id).map((b) => b.para).toSet();
      _topPara = _paras.isEmpty ? 0 : para.clamp(0, _paras.length - 1);
      _resetViews();
      _loading = false;
    });
    if (_pdfMode && !fromPdf) _pdfShowPara(_topPara);
    _onNarration();
    _savePosition();
  }

  // ---- original PDF pages ----

  /// Scrolls the original pages to where paragraph [para] of the open chapter starts.
  void _pdfShowPara(int para, {bool animate = false}) {
    final pg = _pdfMap.pageOf(_idx, para);
    if (pg == null) return;
    _pdfGoTo(pg + 1, animate: animate);
  }

  void _pdfGoTo(int pageNumber, {bool animate = false}) {
    if (!_pdfCtrl.isReady) {
      _pdfPage = pageNumber; // used as the start page once the viewer is ready
      return;
    }
    pageNumber = pageNumber.clamp(1, _pdfCtrl.pageCount);
    if (pageNumber == _pdfPage && _pdfCtrl.pageNumber == pageNumber) return;
    _pdfCtrl.goToPage(pageNumber: pageNumber, duration: animate ? const Duration(milliseconds: 250) : Duration.zero);
  }

  /// The user moved to another page: keep the text position (and so Listen) in step.
  void _onPdfPage(int? n) {
    if (n == null || !mounted) return;
    _pdfPage = n;
    if (_chrome) setState(() {});
    final ns = narrator.state.value;
    if (ns.bookId == _book?.id && ns.playing) return; // the narration drives the pages
    final loc = _pdfMap.locate(n - 1);
    if (loc == null) return;
    if (loc.$1 != _idx) {
      _open(loc.$1, para: loc.$2, fromPdf: true);
    } else if (loc.$2 != _topPara) {
      _topPara = loc.$2;
      _scheduleSave();
    }
  }

  void _setPdfMode(bool on) {
    settings.set('pdfPageView', on);
    setState(() {
      _pdfMode = on;
      if (on) {
        _pdfGen++;
        _pdfCtrl = PdfViewerController();
        _pdfPage = (_pdfMap.pageOf(_idx, _topPara) ?? 0) + 1;
      } else {
        _resetViews();
      }
    });
  }

  /// For PDFs imported before pages were kept: attach the original file now.
  Future<void> _linkPdf() async {
    final files = await pickImportFiles();
    if (files.isEmpty || !mounted) return;
    final x = files.first;
    try {
      if (x.error != null || !x.name.toLowerCase().endsWith('.pdf')) {
        toast(context, 'Choose the PDF file this book came from.');
        return;
      }
      setState(() => _busy = true);
      var map = PdfPageMap.empty();
      try {
        final parsed = await parsePdf(x.path, x.name);
        if (parsed.chapters.length == _metas.length) map = PdfPageMap.fromBook(parsed);
      } catch (_) {}
      await keepOriginalPdf(_book!.id!, x.path, map, temporary: x.temporary);
      if (!mounted) return;
      _hasPdf = true;
      _pdfMap = map;
      setState(() => _busy = false);
      _setPdfMode(true);
      if (map.isEmpty) {
        toast(context, 'Pages linked. They will not follow the text because the chapters differ; import the PDF again for that.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        toast(context, 'Could not link that file.');
      }
    } finally {
      await x.discard();
    }
  }

  Widget _pdfView(MediaQueryData mq) {
    final t = settings.readerTheme;
    return Padding(
      padding: EdgeInsets.only(top: mq.padding.top),
      child: PdfViewer.file(
        originalPdfPath(_book!.id!),
        key: ValueKey('pdf-${_book!.id}-$_pdfGen'),
        controller: _pdfCtrl,
        initialPageNumber: _pdfPage,
        params: PdfViewerParams(
          backgroundColor: t.dark ? const Color(0xFF1A1A1A) : const Color(0xFFDADADA),
          margin: 6,
          onPageChanged: _onPdfPage,
          loadingBannerBuilder: (c, done, total) => Center(child: CircularProgressIndicator(color: t.accent)),
          errorBannerBuilder: (c, err, st, ref) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text('The original PDF could not be opened.', textAlign: TextAlign.center, style: TextStyle(color: t.fg)),
            ),
          ),
        ),
      ),
    );
  }

  void _setQuotes(List<Quote> qs) {
    _quotes = {};
    for (final q in qs) {
      (_quotes[q.para] ??= []).add(q);
    }
  }

  /// Rebuilds the list or pages so they start at [_topPara].
  void _resetViews() {
    _listGen++;
    _itemPos.itemPositions.removeListener(_onScroll);
    _itemCtrl = ItemScrollController();
    _itemPos = ItemPositionsListener.create()..itemPositions.addListener(_onScroll);
    _pagesKey = '';
  }

  Future<void> _reloadMarks() async {
    final qs = await Db.quotes(chapterId: _chapter!.id);
    final bs = await Db.bookmarks(bookId: _book!.id);
    _glossary = await Db.dict();
    if (!mounted) return;
    setState(() {
      _setQuotes(qs);
      _bookmarked = bs.where((b) => b.chapterId == _chapter!.id).map((b) => b.para).toSet();
      _glossRe = settings.markGlossary ? glossaryPattern(_glossary) : null;
    });
  }

  // ---- settings and system chrome ----

  void _onSettings() {
    if (!mounted) return;
    _applySystem();
    setState(() {
      _glossRe = settings.markGlossary ? glossaryPattern(_glossary) : null;
    });
  }

  void _applySystem() {
    (settings.keepScreenOn ? WakelockPlus.enable() : WakelockPlus.disable()).catchError((_) {});
    SystemChrome.setPreferredOrientations(switch (settings.orientation) {
      1 => const [DeviceOrientation.portraitUp],
      2 => const [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight],
      _ => const [],
    });
    _applyFullScreen();
  }

  void _applyFullScreen() {
    SystemChrome.setEnabledSystemUIMode(
        settings.fullScreen && !_chrome ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
  }

  void _setChrome(bool v) {
    if (_chrome == v) return;
    setState(() => _chrome = v);
    _applyFullScreen();
  }

  // ---- position ----

  void _onScroll() {
    if (settings.paged || _paras.isEmpty) return;
    final pos = _itemPos.itemPositions.value.where((p) => p.itemTrailingEdge > 0.02);
    if (pos.isEmpty) return;
    final first = pos.reduce((a, b) => a.index < b.index ? a : b).index;
    final para = (first - 1).clamp(0, _paras.length - 1);
    if (para != _topPara) {
      _topPara = para;
      _scheduleSave();
      if (_chrome) setState(() {});
    }
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 800), _savePosition);
  }

  void _savePosition() {
    final b = _book;
    if (b == null || _chapter == null) return;
    // While this book is being narrated, the narrator owns the saved position.
    final ns = narrator.state.value;
    if (ns.bookId == b.id && ns.playing) return;
    Db.savePosition(b.id!, _idx, _topPara, within: _paras.isEmpty ? 0 : _topPara / _paras.length);
  }

  void _goToPara(int para, {bool animate = false}) {
    if (_paras.isEmpty) return;
    para = para.clamp(0, _paras.length - 1);
    if (_pdfMode) {
      _pdfShowPara(para, animate: animate);
    } else if (settings.paged) {
      final page = pageOfPara(_pages, para);
      final lead = _idx > 0 ? 1 : 0;
      if (_pageCtrl?.hasClients ?? false) {
        animate
            ? _pageCtrl!.animateToPage(page + lead, duration: const Duration(milliseconds: 250), curve: Curves.easeOut)
            : _pageCtrl!.jumpToPage(page + lead);
      }
    } else if (_itemCtrl.isAttached) {
      animate
          ? _itemCtrl.scrollTo(index: para + 1, alignment: 0.12, duration: const Duration(milliseconds: 350), curve: Curves.easeOut)
          : _itemCtrl.jumpTo(index: para + 1, alignment: 0.02);
    }
    _topPara = para;
    _scheduleSave();
  }

  void _turnPage(int delta) {
    if (_pdfMode) {
      _pdfGoTo(_pdfPage + delta, animate: true);
    } else if (settings.paged) {
      final c = _pageCtrl;
      if (c == null || !c.hasClients) return;
      final target = (c.page ?? 0).round() + delta;
      c.animateToPage(target, duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
    } else if (_itemCtrl.isAttached) {
      final pos = _itemPos.itemPositions.value.toList()..sort((a, b) => a.index.compareTo(b.index));
      if (pos.isEmpty) return;
      final target = delta > 0 ? pos.last.index : (pos.first.index - (pos.length - 1)).clamp(0, _paras.length + 1);
      _itemCtrl.scrollTo(index: target, alignment: 0.02, duration: const Duration(milliseconds: 200));
    }
  }

  // ---- narration ----

  void _onNarration() {
    final b = _book;
    if (b == null || !mounted) return;
    final s = narrator.state.value;
    if (s.bookId != b.id) {
      if (_spokenPara != -1) setState(() => _spokenPara = _spokenStart = _spokenEnd = -1);
      return;
    }
    if (s.chapterIdx != _idx) {
      if (settings.followNarration && s.playing) _open(s.chapterIdx, para: s.para < 0 ? 0 : s.para);
      return;
    }
    if (s.para != _spokenPara || s.start != _spokenStart || s.end != _spokenEnd || s.lastPara != _spokenLast) {
      final moved = s.para != _spokenPara;
      setState(() {
        _spokenPara = s.para;
        _spokenStart = s.start;
        _spokenEnd = s.end;
        _spokenLast = s.lastPara;
      });
      if (moved && s.para >= 0 && s.playing && settings.followNarration) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _goToPara(s.para, animate: true);
        });
      }
    } else {
      setState(() {});
    }
  }

  Future<void> _listen({int? fromPara}) async {
    final b = _book!;
    final s = narrator.state.value;
    final here = s.bookId == b.id && s.chapterIdx == _idx;
    if (fromPara != null && here) {
      await narrator.jumpToPara(fromPara);
      if (!narrator.isPlaying) await narrator.play();
    } else if (fromPara != null || !here) {
      unawaited(narrator.start(b.id!, _idx, fromPara ?? _topPara, translated: _showTr));
    }
    if (mounted && fromPara == null) await showNarrationPanel(context);
  }

  // ---- marks ----

  Future<void> _toggleBookmark() async {
    final ch = _chapter;
    if (ch == null || _paras.isEmpty) return;
    final existing = (await Db.bookmarks(bookId: _book!.id)).where((b) => b.chapterId == ch.id && b.para == _topPara).firstOrNull;
    if (existing != null) {
      await Db.deleteBookmark(existing.id!);
    } else {
      final t = paraText(_paras[_topPara]);
      await Db.addBookmark(Bookmark(
          bookId: _book!.id!, chapterId: ch.id!, para: _topPara, snippet: t.length > 140 ? '${t.substring(0, 140)}…' : t));
    }
    await _reloadMarks();
    if (mounted) toast(context, existing != null ? 'Bookmark removed' : 'Bookmark added');
  }

  Future<void> _addQuote(int para, int start, int end, String text, {bool withNote = false}) async {
    final q = Quote(
        bookId: _book!.id!,
        chapterId: _chapter!.id!,
        para: para,
        start: start,
        end: end,
        text: text,
        color: settings.quoteColor);
    await Db.addQuote(q);
    await _reloadMarks();
    if (withNote && mounted) {
      await showQuoteSheet(context, q);
      await _reloadMarks();
    }
  }

  Future<void> _showGlossary(String word) async {
    final e = _glossary.where((g) => g.word.toLowerCase() == word.toLowerCase()).firstOrNull;
    if (e == null) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (c) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(e.word, style: Theme.of(c).textTheme.titleLarge),
          Text(const ['Word', 'Character', 'Term'][e.kind.clamp(0, 2)], style: Theme.of(c).textTheme.labelMedium),
          const SizedBox(height: 10),
          Text(e.definition.isEmpty ? 'No description yet.' : e.definition, style: Theme.of(c).textTheme.bodyLarge),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () async {
                Navigator.pop(c);
                if (await showGlossaryEditor(context, entry: e)) _reloadMarks();
              },
              child: const Text('Edit'),
            ),
          ),
        ]),
      ),
    );
  }

  // ---- AI ----

  Future<void> _translateSelection(String text) async {
    showDialog<void>(
      context: context,
      builder: (c) => FutureBuilder<String>(
        future: translateSnippet(settings, text),
        builder: (c, snap) => AlertDialog(
          title: Text('In ${settings.targetLang}'),
          content: snap.connectionState != ConnectionState.done
              ? const SizedBox(height: 72, child: Center(child: CircularProgressIndicator()))
              : SingleChildScrollView(child: SelectableText(snap.hasError ? '${snap.error}' : snap.data ?? '')),
          actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close'))],
        ),
      ),
    );
  }

  Future<void> _translateChapter() async {
    final ch = _chapter!;
    if (ch.translated.isNotEmpty && !await confirm(context, 'Translate again?', 'This replaces the saved translation of this chapter.', ok: 'Translate')) {
      return;
    }
    setState(() => _busy = true);
    try {
      final lines = await translateParagraphs(settings, splitParas(ch.content));
      await Db.setTranslation(ch.id!, lines.join('\n'), settings.targetLang);
      _metas = await Db.chapterMetas(_book!.id!);
      _showTr = true;
      await _open(_idx, para: _topPara);
    } catch (e) {
      if (mounted) toast(context, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _find() async {
    final q = await promptText(context, 'Find in this chapter', hint: 'Text to find', ok: 'Find');
    if (q == null || q.trim().isEmpty) return;
    final needle = q.trim().toLowerCase();
    for (var k = 1; k <= _paras.length; k++) {
      final i = (_topPara + k) % _paras.length;
      if (_paras[i].toLowerCase().contains(needle)) {
        _goToPara(i);
        return;
      }
    }
    if (mounted) toast(context, 'No match in this chapter.');
  }

  // ---- taps and keys ----

  void _onTap(Offset pos, Size size) {
    _tapTimer?.cancel();
    final selAtDown = _selAtDown;
    _tapTimer = Timer(const Duration(milliseconds: 220), () {
      if (!mounted || selAtDown || _selActive) return;
      if (DateTime.now().difference(_spanTapAt) < const Duration(milliseconds: 500)) return;
      if (_chrome) return _setChrome(false);
      final x = pos.dx / size.width, y = pos.dy / size.height;
      if (y < 0.14 && x < 0.22 && settings.cornerTheme) return settings.toggleDayNight();
      if (y < 0.14 && x > 0.78 && settings.cornerBookmark) {
        _toggleBookmark();
        return;
      }
      if ((settings.paged || _pdfMode) && x < 0.3) return _turnPage(-1);
      if ((settings.paged || _pdfMode) && x > 0.7) return _turnPage(1);
      _setChrome(true);
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (!settings.volumeKeys || narrator.isPlaying) return KeyEventResult.ignored;
    final down = e.logicalKey == LogicalKeyboardKey.audioVolumeDown, up = e.logicalKey == LogicalKeyboardKey.audioVolumeUp;
    if (!down && !up) return KeyEventResult.ignored;
    if (e is KeyDownEvent) _turnPage(down ? 1 : -1);
    return KeyEventResult.handled;
  }

  void _setBrightness(double v) {
    _brightness = v.clamp(0.02, 1.0);
    ScreenBrightness.instance.setApplicationScreenBrightness(_brightness!).catchError((_) {});
    _brightHide?.cancel();
    setState(() => _brightShown = true);
    _brightHide = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _brightShown = false);
    });
  }

  // ---- selection menu ----

  Widget _selectionMenu(BuildContext c, EditableTextState ets, int para, int base) {
    final v = ets.textEditingValue;
    final sel = v.selection;
    final text = sel.isValid && !sel.isCollapsed ? sel.textInside(v.text) : '';
    void done() {
      ets.hideToolbar();
      ets.userUpdateTextEditingValue(v.copyWith(selection: TextSelection.collapsed(offset: sel.end)), SelectionChangedCause.toolbar);
    }

    final items = <ContextMenuButtonItem>[
      if (text.isNotEmpty && !_showTr) ...[
        ContextMenuButtonItem(
            label: 'Highlight',
            onPressed: () {
              done();
              _addQuote(para, base + sel.start, base + sel.end, text);
            }),
        ContextMenuButtonItem(
            label: 'Note',
            onPressed: () {
              done();
              _addQuote(para, base + sel.start, base + sel.end, text, withNote: true);
            }),
      ],
      ContextMenuButtonItem(
          label: 'Listen from here',
          onPressed: () {
            done();
            _listen(fromPara: para);
          }),
      if (text.isNotEmpty) ...[
        ContextMenuButtonItem(
            label: 'Translate',
            onPressed: () {
              done();
              _translateSelection(text);
            }),
        ContextMenuButtonItem(
            label: 'Search web',
            onPressed: () {
              done();
              _openWeb(settings.searchUrl, text);
            }),
        ContextMenuButtonItem(
            label: 'Define',
            onPressed: () {
              done();
              _openWeb(settings.dictUrl, text);
            }),
        ContextMenuButtonItem(
            label: 'Add to glossary',
            onPressed: () async {
              done();
              if (await showGlossaryEditor(context, word: text.trim())) _reloadMarks();
            }),
      ],
      ...ets.contextMenuButtonItems
          .where((i) => i.type == ContextMenuButtonType.copy || i.type == ContextMenuButtonType.selectAll),
    ];
    return AdaptiveTextSelectionToolbar.buttonItems(anchors: ets.contextMenuAnchors, buttonItems: items);
  }

  void _openWeb(String template, String text) {
    final url = template.replaceAll('%s', Uri.encodeQueryComponent(text.trim()));
    Navigator.push(context, MaterialPageRoute(builder: (_) => BrowserScreen(initialUrl: url, standalone: true)));
  }

  // ---- building ----

  TextStyle _style(int level) => readerTextStyle(settings, scale: const [1.0, 1.36, 1.2, 1.08][level.clamp(0, 3)], heading: level > 0);

  Widget _para(int i, {int start = 0, int? end}) {
    final t = settings.readerTheme;
    final full = paraText(_paras[i]);
    final spoken = _spokenPara == i;
    final spokenWhole = i > _spokenPara && i <= _spokenLast;
    return ParaText(
      key: ValueKey('p$i-$start'),
      text: end == null ? full : full.substring(start.clamp(0, full.length), end.clamp(0, full.length)),
      para: i,
      base: start,
      style: _style(headingLevel(_paras[i])),
      align: settings.justify && headingLevel(_paras[i]) == 0 ? TextAlign.justify : TextAlign.start,
      quotes: _showTr ? const [] : (_quotes[i] ?? const []),
      glossary: _glossRe,
      spokenStart: spoken ? _spokenStart : (spokenWhole ? 0 : -1),
      spokenEnd: spoken ? (_spokenLast > _spokenPara ? 1 << 30 : _spokenEnd) : (spokenWhole ? 1 << 30 : -1),
      spokenColor: t.accent.withValues(alpha: t.dark ? 0.30 : 0.22),
      dark: t.dark,
      onQuoteTap: (q) async {
        _spanTapAt = DateTime.now();
        if (await showQuoteSheet(context, q)) _reloadMarks();
      },
      onGlossaryTap: (w) {
        _spanTapAt = DateTime.now();
        _showGlossary(w);
      },
      onSelection: (has) => _selActive = has,
      menuBuilder: _selectionMenu,
    );
  }

  Widget _chapterButton(bool next) {
    final has = next ? _idx + 1 < _metas.length : _idx > 0;
    final t = settings.readerTheme;
    if (!has) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text(next ? 'End of book' : '', style: TextStyle(color: t.fg.withValues(alpha: 0.5)))),
      );
    }
    final m = _metas[next ? _idx + 1 : _idx - 1];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(foregroundColor: t.accent, side: BorderSide(color: t.accent.withValues(alpha: 0.5))),
        icon: Icon(next ? Icons.arrow_forward : Icons.arrow_back),
        label: Text(m.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        onPressed: () => _open(next ? _idx + 1 : _idx - 1, para: next ? 0 : 1 << 30),
      ),
    );
  }

  Widget _scrollView(EdgeInsets safe) {
    final gap = settings.paraSpacing * settings.fontSize;
    return ScrollablePositionedList.builder(
      key: ValueKey('list-$_listGen'),
      itemScrollController: _itemCtrl,
      itemPositionsListener: _itemPos,
      initialScrollIndex: _paras.isEmpty ? 0 : _topPara + 1,
      initialAlignment: _topPara == 0 ? 0 : 0.02,
      padding: EdgeInsets.fromLTRB(settings.margin, safe.top + 12, settings.margin, safe.bottom + 12),
      itemCount: _paras.length + 2,
      itemBuilder: (c, i) {
        if (i == 0) return _chapterButton(false);
        if (i == _paras.length + 1) return Padding(padding: const EdgeInsets.only(bottom: 80), child: _chapterButton(true));
        return Padding(padding: EdgeInsets.only(bottom: gap), child: _para(i - 1));
      },
    );
  }

  Widget _pageView(Size size, EdgeInsets safe) {
    final s = settings, t = s.readerTheme;
    const bar = 26.0;
    final w = size.width - s.margin * 2;
    final h = size.height - safe.top - safe.bottom - bar * 2 - 8;
    final gap = s.paraSpacing * s.fontSize;
    final key = '${_chapter?.id}|$_showTr|$w|$h|${s.fontFamily}|${s.fontSize}|${s.bold}|${s.lineHeight}|${s.paraSpacing}|${s.justify}|${_paras.length}';
    final lead = _idx > 0 ? 1 : 0;
    if (key != _pagesKey) {
      _pagesKey = key;
      _pages = paginate(_paras, styleFor: _style, width: w, height: h, paraGap: gap, align: s.justify ? TextAlign.justify : TextAlign.start);
      _pageNo = pageOfPara(_pages, _topPara);
      _pageCtrl?.dispose();
      _pageCtrl = PageController(initialPage: _pageNo + lead);
    }
    final trail = _idx + 1 < _metas.length ? 1 : 0;
    final small = TextStyle(fontSize: 11.5, color: t.fg.withValues(alpha: 0.55), fontFamily: s.fontFamily == 'system' ? null : s.fontFamily);
    return PageView.builder(
      key: ValueKey('pages-$key'),
      controller: _pageCtrl,
      itemCount: _pages.length + lead + trail,
      onPageChanged: (p) {
        if (p < lead) {
          _open(_idx - 1, para: 1 << 30);
        } else if (p >= lead + _pages.length) {
          _open(_idx + 1);
        } else {
          _pageNo = p - lead;
          if (_pages[_pageNo].isNotEmpty) _topPara = _pages[_pageNo].first.para;
          _scheduleSave();
          setState(() {});
        }
      },
      itemBuilder: (c, p) {
        if (p < lead || p >= lead + _pages.length) {
          return Center(child: CircularProgressIndicator(color: t.accent));
        }
        final page = _pages[p - lead];
        return Padding(
          padding: EdgeInsets.fromLTRB(s.margin, safe.top, s.margin, safe.bottom),
          child: Column(children: [
            SizedBox(
              height: bar,
              child: s.showProgress
                  ? Align(alignment: Alignment.centerLeft, child: Text(_chapter?.title ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: small))
                  : null,
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: h,
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  for (final seg in page)
                    Padding(
                      padding: EdgeInsets.only(bottom: seg.endsPara ? gap : 0),
                      child: _para(seg.para, start: seg.start, end: seg.end),
                    ),
                ]),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: bar,
              child: s.showProgress
                  ? Row(children: [
                      Text('${p - lead + 1} / ${_pages.length}', style: small),
                      const Spacer(),
                      Text('${_idx + 1} of ${_metas.length}', style: small),
                    ])
                  : null,
            ),
          ]),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = settings.readerTheme;
    final scheme = ColorScheme.fromSeed(seedColor: t.accent, brightness: t.dark ? Brightness.dark : Brightness.light);
    final mq = MediaQuery.of(context);
    return Theme(
      data: ThemeData(colorScheme: scheme, useMaterial3: true),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: (t.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
        ),
        child: Scaffold(
          backgroundColor: t.bg,
          body: _loadError != null
              ? _message(_loadError!, t)
              : _loading
                  ? Center(child: CircularProgressIndicator(color: t.accent))
                  : Focus(
                      focusNode: _focus,
                      autofocus: true,
                      onKeyEvent: _onKey,
                      child: Stack(children: [
                        Positioned.fill(
                          child: Listener(
                            behavior: HitTestBehavior.translucent,
                            onPointerDown: (e) {
                              _downPos = e.position;
                              _downAt = DateTime.now();
                              _selAtDown = _selActive;
                            },
                            onPointerUp: (e) {
                              final d = _downPos;
                              if (d != null &&
                                  (e.position - d).distance < 14 &&
                                  DateTime.now().difference(_downAt) < const Duration(milliseconds: 280)) {
                                _onTap(e.position, mq.size);
                              }
                            },
                            child: MediaQuery(
                              data: mq.copyWith(textScaler: TextScaler.noScaling),
                              child: _pdfMode
                                  ? _pdfView(mq)
                                  : settings.paged
                                      ? _pageView(mq.size, mq.padding)
                                      : _scrollView(mq.padding),
                            ),
                          ),
                        ),
                        if (settings.brightnessSwipe)
                          Positioned(
                            left: 0,
                            top: mq.size.height * 0.15,
                            bottom: mq.size.height * 0.15,
                            width: 26,
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onVerticalDragUpdate: (d) => _setBrightness((_brightness ?? 0.5) - d.delta.dy / 320),
                            ),
                          ),
                        if (_brightShown)
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.65), borderRadius: BorderRadius.circular(14)),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.brightness_6, color: Colors.white),
                                const SizedBox(width: 10),
                                Text('${((_brightness ?? 0.5) * 100).round()}%', style: const TextStyle(color: Colors.white, fontSize: 16)),
                              ]),
                            ),
                          ),
                        if (_busy)
                          Positioned.fill(
                            child: ColoredBox(
                              color: Colors.black.withValues(alpha: 0.45),
                              child: const Center(
                                child: Card(
                                  child: Padding(
                                    padding: EdgeInsets.all(24),
                                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                                      CircularProgressIndicator(),
                                      SizedBox(height: 16),
                                      Text('Translating this chapter…'),
                                    ]),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (_chrome) ..._chromeBars(scheme, mq),
                      ]),
                    ),
        ),
      ),
    );
  }

  Widget _message(String text, ReaderTheme t) => SafeArea(
        child: Stack(children: [
          Align(alignment: Alignment.topLeft, child: BackButton(color: t.fg)),
          Center(child: Padding(padding: const EdgeInsets.all(32), child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: t.fg, fontSize: 16)))),
        ]),
      );

  List<Widget> _chromeBars(ColorScheme cs, MediaQueryData mq) {
    final ns = narrator.state.value;
    final playingHere = ns.bookId == _book?.id && ns.playing;
    final pdfPages = _pdfMode && _pdfCtrl.isReady ? _pdfCtrl.pageCount : 0;
    final total = _pdfMode ? pdfPages : (settings.paged ? _pages.length : _paras.length);
    final at = _pdfMode ? _pdfPage - 1 : (settings.paged ? _pageNo : _topPara);
    final isPdf = _book?.format == 'PDF';
    final hasTr = _chapter?.translated.isNotEmpty ?? false;
    return [
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: Material(
          color: cs.surfaceContainer,
          elevation: 3,
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: 56,
              child: Row(children: [
                const BackButton(),
                Expanded(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_book?.title ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    Text(_chapter?.title ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
                  ]),
                ),
                IconButton(
                  tooltip: 'Bookmark',
                  icon: Icon(_bookmarked.contains(_topPara) ? Icons.bookmark : Icons.bookmark_border),
                  onPressed: _toggleBookmark,
                ),
                if (_hasPdf)
                  IconButton(
                    tooltip: _pdfMode ? 'Show text' : 'Show original pages',
                    icon: Icon(_pdfMode ? Icons.notes : Icons.picture_as_pdf_outlined),
                    onPressed: () => _setPdfMode(!_pdfMode),
                  ),
                if (!_pdfMode) IconButton(tooltip: 'Find', icon: const Icon(Icons.search), onPressed: _find),
                PopupMenuButton<String>(
                  onSelected: (v) async {
                    switch (v) {
                      case 'tr':
                        _translateChapter();
                      case 'toggle':
                        _showTr = !_showTr;
                        _open(_idx, para: _topPara);
                      case 'pdf':
                        _setPdfMode(!_pdfMode);
                      case 'linkpdf':
                        _linkPdf();
                      case 'info':
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => BookDetailScreen(bookId: _book!.id!)));
                        _load();
                    }
                  },
                  itemBuilder: (c) => [
                    if (hasTr) PopupMenuItem(value: 'toggle', child: Text(_showTr ? 'Show original' : 'Show translation')),
                    PopupMenuItem(value: 'tr', child: Text(hasTr ? 'Translate again' : 'Translate chapter (${settings.targetLang})')),
                    if (isPdf && _hasPdf)
                      PopupMenuItem(value: 'pdf', child: Text(_pdfMode ? 'Show text (for reading aloud)' : 'Show original pages')),
                    if (isPdf && !_hasPdf) const PopupMenuItem(value: 'linkpdf', child: Text('Show original pages… (pick the PDF)')),
                    const PopupMenuItem(value: 'info', child: Text('Book details')),
                  ],
                ),
              ]),
            ),
          ),
        ),
      ),
      Positioned(
        bottom: 0,
        left: 0,
        right: 0,
        child: Material(
          color: cs.surfaceContainer,
          elevation: 3,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  const SizedBox(width: 12),
                  Text('Chapter ${_idx + 1} of ${_metas.length}', style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
                  const Spacer(),
                  Text(
                      total == 0
                          ? ''
                          : _pdfMode
                              ? 'Page ${at + 1} of $total'
                              : '${((at + 1) / total * 100).round()}% of chapter',
                      style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
                  const SizedBox(width: 12),
                ]),
                Slider(
                  value: total <= 1 ? 0 : at.clamp(0, total - 1).toDouble(),
                  max: total <= 1 ? 1 : (total - 1).toDouble(),
                  onChanged: total <= 1
                      ? null
                      : (v) {
                          if (_pdfMode) {
                            _pdfGoTo(v.round() + 1);
                            _pdfPage = v.round() + 1;
                          } else if (settings.paged) {
                            _pageCtrl?.jumpToPage(v.round() + (_idx > 0 ? 1 : 0));
                          } else {
                            _goToPara(v.round());
                          }
                          setState(() {});
                        },
                ),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  IconButton(
                      tooltip: 'Previous chapter',
                      icon: const Icon(Icons.skip_previous),
                      onPressed: _idx > 0 ? () => _open(_idx - 1) : null),
                  IconButton(
                    tooltip: 'Chapters, bookmarks, highlights',
                    icon: const Icon(Icons.format_list_bulleted),
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      showDragHandle: true,
                      builder: (_) => ContentsSheet(book: _book!, metas: _metas, currentIdx: _idx, onOpen: (i, p) => _open(i, para: p)),
                    ),
                  ),
                  FilledButton.icon(
                    icon: Icon(playingHere ? Icons.graphic_eq : Icons.headphones),
                    label: Text(playingHere ? 'Playing' : 'Listen'),
                    onPressed: _listen,
                  ),
                  IconButton(
                    tooltip: 'Text and layout',
                    icon: const Icon(Icons.text_fields),
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      showDragHandle: true,
                      barrierColor: Colors.black.withValues(alpha: 0.12),
                      builder: (_) => StatefulBuilder(
                        builder: (c, setS) => ReaderSettingsSheet(
                          brightness: _brightness,
                          onBrightness: (v) {
                            _setBrightness(v);
                            setS(() {});
                          },
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Day / night',
                    icon: Icon(settings.readerTheme.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
                    onPressed: settings.toggleDayNight,
                  ),
                  IconButton(
                      tooltip: 'Next chapter',
                      icon: const Icon(Icons.skip_next),
                      onPressed: _idx + 1 < _metas.length ? () => _open(_idx + 1) : null),
                ]),
              ]),
            ),
          ),
        ),
      ),
    ];
  }
}
