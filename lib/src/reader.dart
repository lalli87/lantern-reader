import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'ai.dart';
import 'app.dart';
import 'comics.dart';
import 'stats.dart';
import 'study.dart';
import 'book_detail.dart';
import 'browser.dart';
import 'db.dart';
import 'models.dart';
import 'narration_ui.dart';
import 'pagination.dart';
import 'file_pick.dart';
import 'drive_sync.dart';
import 'pdf_column_zoom.dart';
import 'pdf_layout.dart';
import 'pdf_import.dart';
import 'pdf_pages.dart';
import 'reader_extras.dart';
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
  int _per = 1; // pages shown at once: 2 side by side in landscape
  final _offsetCtrl = ScrollOffsetController();
  Timer? _autoTimer, _nightTimer;
  bool _autoScroll = false, _autoPaused = false;
  int _autoElapsed = 0;
  bool? _nightApplied;

  // Original PDF pages
  bool _hasPdf = false, _pdfMode = false;
  PdfPageMap _pdfMap = PdfPageMap.empty();
  PdfViewerController _pdfCtrl = PdfViewerController();
  int _pdfPage = 1; // 1-based, as pdfrx counts
  int _pdfGen = 0;
  // Column mode: zoomed to one column of the original page (see pdf_column_zoom.dart).
  ColumnSpot? _col;
  double _colZoom = 0;
  final Map<int, List<LRect>> _pdfBlocks = {};
  // Double-tap on original pages is detected here (not by the viewer) so the first tap of the
  // pair can never turn the page.
  DateTime _lastTapAt = DateTime.fromMillisecondsSinceEpoch(0);
  Offset? _lastTapPos;

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
  late final _readTime = ReadingTimer(() => _book?.id, isListening: () => narrator.isPlaying && narrator.book?.id == _book?.id);

  @override
  void initState() {
    super.initState();
    _readTime.start();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkNight());
    _nightTimer = Timer.periodic(const Duration(minutes: 1), (_) => _checkNight());
    driveSync.bookOpened(widget.bookId);
    settings.addListener(_onSettings);
    narrator.state.addListener(_onNarration);
    _itemPos.itemPositions.addListener(_onScroll);
    _applySystem();
    _load();
  }

  @override
  void dispose() {
    _readTime.stop();
    _autoTimer?.cancel();
    _nightTimer?.cancel();
    _savePosition();
    driveSync.bookClosed(widget.bookId);
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
    if (isComicFormat(b.format)) {
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ComicScreen(bookId: b.id!)));
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
    _col = null; // jumping elsewhere (narration, slider, contents) leaves column mode
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

  // ---- column mode ----

  double get _viewAspect {
    final v = _pdfCtrl.viewSize;
    return v.width <= 0 ? 1.6 : v.height / v.width;
  }

  /// Text columns of a page (1-based) in reading order, worked out once per page.
  Future<List<LRect>> _blocksOf(int page) async {
    final cached = _pdfBlocks[page];
    if (cached != null) return cached;
    var blocks = const <LRect>[];
    try {
      final pg = _pdfCtrl.document.pages[page - 1];
      final pt = await pg.loadText();
      final lay = pt == null ? null : pageLayoutOf(pt, pg.width, pg.height);
      if (lay != null) blocks = readingBlocks(lay);
    } catch (_) {}
    return _pdfBlocks[page] = blocks;
  }

  /// Double-tap: zoom to the column under the finger, or back out to the whole page.
  Future<void> _onPdfDoubleTap(Offset docPos) async {
    if (!_pdfCtrl.isReady) return;
    if (_col != null) {
      _col = null;
      await _pdfCtrl.goToPage(pageNumber: _pdfPage, anchor: PdfPageAnchor.all);
      return;
    }
    final hit = _pdfCtrl.getPdfPageHitTestResult(docPos, useDocumentLayoutCoordinates: true);
    if (hit == null) return;
    final page = hit.page.pageNumber;
    final blocks = await _blocksOf(page);
    final spot = spotAt(blocks, page, hit.offset.x, hit.page.height - hit.offset.y, _viewAspect);
    if (!mounted) return;
    if (spot == null) {
      // Pictures or a scanned page: plain 2.5× zoom on the spot.
      await _pdfCtrl.setZoom(docPos, _pdfCtrl.currentZoom * 2.5);
      return;
    }
    await _showColumn(spot, blocks);
    if (!settings.colZoomHintShown) {
      settings.set('colZoomHintShown', true);
      if (mounted) toast(context, 'Column view: tap the right side to read on, the left to go back. Double-tap to see the whole page.');
    }
  }

  Future<void> _showColumn(ColumnSpot s, List<LRect> blocks) async {
    final b = blocks[s.block];
    final h = _pdfCtrl.document.pages[s.page - 1].height;
    final (l, t, r, bot) = columnArea(b, s.top, _viewAspect, h);
    _col = s;
    await _pdfCtrl.goToRectInsidePage(
      pageNumber: s.page,
      rect: PdfRect(l, h - t, r, h - bot),
      anchor: PdfPageAnchor.top,
      duration: const Duration(milliseconds: 220),
    );
    if (mounted && _col == s) _colZoom = _pdfCtrl.currentZoom;
  }

  /// Side tap in column mode: down or up the column, on to the next column, then the next page.
  Future<void> _stepColumn(int dir) async {
    final cur = _col!;
    final blocks = await _blocksOf(cur.page);
    var next = stepColumn(blocks, cur, dir, _viewAspect);
    var nextBlocks = blocks;
    if (next == null) {
      final page = cur.page + dir;
      if (page < 1 || page > _pdfCtrl.pageCount) return;
      nextBlocks = await _blocksOf(page);
      next = enterPage(nextBlocks, page, dir, _viewAspect);
      if (next == null) {
        // A page without text (a full-page photo): show it whole, leave column mode.
        _pdfGoTo(page, animate: true);
        return;
      }
    }
    if (!mounted) return;
    await _showColumn(next, nextBlocks);
  }

  void _setPdfMode(bool on) {
    settings.set('pdfPageView', on);
    setState(() {
      _pdfMode = on;
      if (on) {
        _pdfGen++;
        _pdfCtrl = PdfViewerController();
        _col = null;
        _pdfBlocks.clear();
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
              child: Text(
                'The original PDF could not be opened.',
                textAlign: TextAlign.center,
                style: TextStyle(color: t.fg),
              ),
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
    SystemChrome.setEnabledSystemUIMode(settings.fullScreen && !_chrome ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
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

  Widget _warm(Widget child) => settings.warmth <= 0 ? child : ColorFiltered(colorFilter: warmFilter(settings.warmth), child: child);

  // ---- hands-free reading ----

  void _startAutoScroll() {
    _autoTimer?.cancel();
    _autoElapsed = 0;
    setState(() {
      _autoScroll = true;
      _autoPaused = false;
    });
    _setChrome(false);
    _autoTimer = Timer.periodic(const Duration(milliseconds: 50), (_) => _autoTick());
  }

  void _stopAutoScroll() {
    _autoTimer?.cancel();
    _autoTimer = null;
    if (mounted) setState(() => _autoScroll = false);
  }

  void _autoTick() {
    if (!mounted || _autoPaused || _chrome || _selActive) return;
    final sp = settings.autoScrollSpeed.clamp(1, 10);
    if (settings.paged || _pdfMode) {
      // Speed 1 turns a page every 55 seconds, speed 10 every 10.
      _autoElapsed += 50;
      if (_autoElapsed >= (60 - sp * 5) * 1000) {
        _autoElapsed = 0;
        _turnPage(1);
      }
      return;
    }
    // Speed is about sp × 6 lines a minute.
    final line = settings.fontSize * settings.lineHeight;
    _offsetCtrl.animateScroll(offset: sp * 0.1 * line * 0.05, duration: const Duration(milliseconds: 50));
    _autoElapsed += 50;
    if (_autoElapsed % 1000 == 0) {
      // At the end of the chapter, carry on into the next one.
      final pos = _itemPos.itemPositions.value;
      final end = pos.where((p) => p.index == _paras.length + 1).firstOrNull;
      if (end != null && end.itemTrailingEdge <= 1.0 && _idx + 1 < _metas.length) _open(_idx + 1);
    }
  }

  Widget _autoScrollBar(ColorScheme cs) {
    final sp = settings.autoScrollSpeed;
    return Material(
      color: cs.surfaceContainerHigh.withValues(alpha: 0.95),
      elevation: 4,
      shape: const StadiumBorder(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Slower',
            icon: const Icon(Icons.remove),
            onPressed: sp > 1 ? () => settings.set('autoScrollSpeed', sp - 1) : null,
          ),
          Text('Speed $sp', style: TextStyle(color: cs.onSurface)),
          IconButton(
            tooltip: 'Faster',
            icon: const Icon(Icons.add),
            onPressed: sp < 10 ? () => settings.set('autoScrollSpeed', sp + 1) : null,
          ),
          IconButton(
            tooltip: _autoPaused ? 'Resume' : 'Pause',
            icon: Icon(_autoPaused ? Icons.play_arrow : Icons.pause),
            onPressed: () => setState(() => _autoPaused = !_autoPaused),
          ),
          IconButton(tooltip: 'Stop', icon: const Icon(Icons.close), onPressed: _stopAutoScroll),
        ],
      ),
    );
  }

  /// Switches to the night or day theme when the automatic schedule (or the phone's dark mode) changes.
  /// Switching by hand in between is left alone until the next change.
  void _checkNight() {
    if (!mounted) return;
    final want = nightWanted(settings, DateTime.now(), MediaQuery.platformBrightnessOf(context));
    if (want == null) {
      _nightApplied = null;
      return;
    }
    if (want == _nightApplied) return;
    _nightApplied = want;
    if (settings.readerTheme.dark != want) settings.toggleDayNight();
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
      final page = pageOfPara(_pages, para) ~/ _per;
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
    if (_pdfMode && _col != null && _pdfCtrl.isReady && _pdfCtrl.currentZoom > _colZoom * 0.8) {
      _stepColumn(delta);
      return;
    }
    if (_pdfMode) {
      _pdfGoTo(_pdfPage + delta, animate: true);
    } else if (settings.paged) {
      final c = _pageCtrl;
      if (c == null || !c.hasClients) return;
      final target = (c.page ?? 0).round() + delta;
      settings.pageTurn == 'none'
          ? c.jumpToPage(target)
          : c.animateToPage(
              target,
              duration: Duration(milliseconds: settings.pageTurn == 'turn' ? 420 : 180),
              curve: Curves.easeOut,
            );
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
      await Db.addBookmark(
        Bookmark(bookId: _book!.id!, chapterId: ch.id!, para: _topPara, snippet: t.length > 140 ? '${t.substring(0, 140)}…' : t),
      );
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
      color: settings.quoteColor,
    );
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
          ],
        ),
      ),
    );
  }

  // ---- AI ----

  Future<void> _translateChapter() async {
    final ch = _chapter!;
    if (ch.translated.isNotEmpty &&
        !await confirm(context, 'Translate again?', 'This replaces the saved translation of this chapter.', ok: 'Translate')) {
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
    final now = DateTime.now();
    final last = _lastTapPos;
    if (_pdfMode && last != null && now.difference(_lastTapAt) < const Duration(milliseconds: 350) && (pos - last).distance < 48) {
      _lastTapPos = null;
      final doc = _pdfCtrl.isReady ? _pdfCtrl.globalToDocument(pos) : null;
      if (doc != null) _onPdfDoubleTap(doc);
      return;
    }
    _lastTapAt = now;
    _lastTapPos = pos;
    final selAtDown = _selAtDown;
    // On original pages, wait long enough to tell a single tap from the first half of a double-tap.
    _tapTimer = Timer(Duration(milliseconds: _pdfMode ? 350 : 220), () {
      if (!mounted || selAtDown || _selActive) return;
      if (DateTime.now().difference(_spanTapAt) < const Duration(milliseconds: 500)) return;
      if (_autoScroll) return setState(() => _autoPaused = !_autoPaused);
      if (_chrome) return _setChrome(false);
      final x = pos.dx / size.width, y = pos.dy / size.height;
      if (y < 0.14 && x < 0.22 && settings.cornerTheme) return settings.toggleDayNight();
      if (y < 0.14 && x > 0.78 && settings.cornerBookmark) {
        _toggleBookmark();
        return;
      }
      final turns = settings.paged || _pdfMode;
      switch (settings.tapZones) {
        case 'forward':
          // One hand: the left quarter goes back, the middle opens the menu, anywhere else goes forward.
          final middle = x > 0.33 && x < 0.67 && y > 0.33 && y < 0.67;
          if (!middle) return _turnPage(x < 0.25 ? -1 : 1);
        case 'off':
          break;
        default:
          // Original pages keep narrower turn zones so taps on the page's own columns don't flip it.
          final edge = _pdfMode ? 0.2 : 0.3;
          if (turns && x < edge) return _turnPage(-1);
          if (turns && x > 1 - edge) return _turnPage(1);
      }
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
          },
        ),
        ContextMenuButtonItem(
          label: 'Note',
          onPressed: () {
            done();
            _addQuote(para, base + sel.start, base + sel.end, text, withNote: true);
          },
        ),
      ],
      ContextMenuButtonItem(
        label: 'Listen from here',
        onPressed: () {
          done();
          _listen(fromPara: para);
        },
      ),
      if (text.isNotEmpty) ...[
        ContextMenuButtonItem(
          label: 'Look up',
          onPressed: () {
            done();
            showLookup(context,
                text: text, paragraph: para < _paras.length ? paraText(_paras[para]) : text, bookTitle: _book?.title ?? '', onGlossaryChanged: _reloadMarks);
          },
        ),
        ContextMenuButtonItem(
          label: 'Translate',
          onPressed: () {
            done();
            showSelectionTranslation(context, text,
                onSaveNote: _showTr
                    ? null
                    : (tr) async {
                        final q = Quote(
                            bookId: _book!.id!, chapterId: _chapter!.id!, para: para, start: base + sel.start, end: base + sel.end, text: text, note: tr, color: settings.quoteColor);
                        await Db.addQuote(q);
                        await _reloadMarks();
                      });
          },
        ),
        ContextMenuButtonItem(
          label: 'Search web',
          onPressed: () {
            done();
            _openWeb(settings.searchUrl, text);
          },
        ),

        ContextMenuButtonItem(
          label: 'Add to glossary',
          onPressed: () async {
            done();
            if (await showGlossaryEditor(context, word: text.trim())) _reloadMarks();
          },
        ),
      ],
      ...ets.contextMenuButtonItems.where((i) => i.type == ContextMenuButtonType.copy || i.type == ContextMenuButtonType.selectAll),
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
        child: Center(
          child: Text(next ? 'End of book' : '', style: TextStyle(color: t.fg.withValues(alpha: 0.5))),
        ),
      );
    }
    final m = _metas[next ? _idx + 1 : _idx - 1];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: t.accent,
          side: BorderSide(color: t.accent.withValues(alpha: 0.5)),
        ),
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
      scrollOffsetController: _offsetCtrl,
      initialScrollIndex: _paras.isEmpty ? 0 : _topPara + 1,
      initialAlignment: _topPara == 0 ? 0 : 0.02,
      padding: EdgeInsets.fromLTRB(settings.margin, safe.top + 12, settings.margin, safe.bottom + 12 + (settings.statusLine ? 22 : 0)),
      itemCount: _paras.length + 2,
      itemBuilder: (c, i) {
        if (i == 0) return _chapterButton(false);
        if (i == _paras.length + 1) return Padding(padding: const EdgeInsets.only(bottom: 80), child: _chapterButton(true));
        return Padding(
          padding: EdgeInsets.only(bottom: gap),
          child: _para(i - 1),
        );
      },
    );
  }

  /// Characters from paragraph [para] to the end of the chapter (for "time left").
  int _charsFrom(int para) {
    var n = 0;
    for (var i = para.clamp(0, _paras.length); i < _paras.length; i++) {
      n += _paras[i].length;
    }
    return n;
  }

  Widget _pageView(Size size, EdgeInsets safe) {
    final s = settings, t = s.readerTheme;
    const bar = 26.0;
    // Two pages side by side on a wide landscape screen.
    final spread = s.twoPages && size.width > size.height && size.width >= 640;
    final colGap = spread ? s.margin * 1.6 : 0.0;
    final w = spread ? (size.width - s.margin * 2 - colGap) / 2 : size.width - s.margin * 2;
    final h = size.height - safe.top - safe.bottom - bar * 2 - 8;
    final gap = s.paraSpacing * s.fontSize;
    final key =
        '${_chapter?.id}|$_showTr|$w|$h|$spread|${s.fontFamily}|${s.fontSize}|${s.bold}|${s.lineHeight}|${s.paraSpacing}|${s.justify}|${_paras.length}';
    final lead = _idx > 0 ? 1 : 0;
    if (key != _pagesKey) {
      _pagesKey = key;
      _per = spread ? 2 : 1;
      _pages = paginate(
        _paras,
        styleFor: _style,
        width: w,
        height: h,
        paraGap: gap,
        align: s.justify ? TextAlign.justify : TextAlign.start,
      );
      _pageNo = pageOfPara(_pages, _topPara) ~/ _per * _per;
      _pageCtrl?.dispose();
      _pageCtrl = PageController(initialPage: _pageNo ~/ _per + lead);
    }
    final views = (_pages.length + _per - 1) ~/ _per;
    final trail = _idx + 1 < _metas.length ? 1 : 0;
    final small = TextStyle(
      fontSize: 11.5,
      color: t.fg.withValues(alpha: 0.55),
      fontFamily: s.fontFamily == 'system' ? null : s.fontFamily,
    );

    Widget column(int i) {
      if (i >= _pages.length) return const SizedBox.shrink();
      return SizedBox(
        height: h,
        width: w,
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final seg in _pages[i])
                Padding(
                  padding: EdgeInsets.only(bottom: seg.endsPara ? gap : 0),
                  child: _para(seg.para, start: seg.start, end: seg.end),
                ),
            ],
          ),
        ),
      );
    }

    return PageView.builder(
      key: ValueKey('pages-$key'),
      controller: _pageCtrl,
      itemCount: views + lead + trail,
      onPageChanged: (p) {
        if (p < lead) {
          _open(_idx - 1, para: 1 << 30);
        } else if (p >= lead + views) {
          _open(_idx + 1);
        } else {
          _pageNo = (p - lead) * _per;
          if (_pages[_pageNo].isNotEmpty) _topPara = _pages[_pageNo].first.para;
          _scheduleSave();
          setState(() {});
        }
      },
      itemBuilder: (c, p) {
        if (p < lead || p >= lead + views) {
          return Center(child: CircularProgressIndicator(color: t.accent));
        }
        final first = (p - lead) * _per;
        final last = math.min(first + _per, _pages.length) - 1;
        final nextPara = last + 1 < _pages.length && _pages[last + 1].isNotEmpty ? _pages[last + 1].first.para : _paras.length;
        final pageLabel = spread && last > first ? '${first + 1}–${last + 1} / ${_pages.length}' : '${first + 1} / ${_pages.length}';
        final body = Padding(
          padding: EdgeInsets.fromLTRB(s.margin, safe.top, s.margin, safe.bottom),
          child: Column(
            children: [
              SizedBox(
                height: bar,
                child: s.showProgress
                    ? Row(
                        children: [
                          Expanded(
                            child: Text(_chapter?.title ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: small),
                          ),
                          if (!s.statusLine) Text('${_idx + 1} of ${_metas.length}', style: small),
                        ],
                      )
                    : null,
              ),
              const SizedBox(height: 4),
              spread
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        column(first),
                        SizedBox(width: colGap),
                        column(first + 1),
                      ],
                    )
                  : column(first),
              const SizedBox(height: 4),
              SizedBox(
                height: bar,
                child: s.showProgress || s.statusLine
                    ? Row(
                        children: [
                          if (s.showProgress) Text(pageLabel, style: small),
                          const Spacer(),
                          if (s.statusLine) Text(timeLeftLabel(_charsFrom(nextPara)), style: small),
                          const Spacer(),
                          if (s.statusLine)
                            ClockBattery(style: small)
                          else if (s.showProgress)
                            Text('${_idx + 1} of ${_metas.length}', style: small),
                        ],
                      )
                    : null,
              ),
            ],
          ),
        );
        return s.pageTurn == 'turn' && _pageCtrl != null
            ? PageTurn(controller: _pageCtrl!, index: p, width: size.width, background: t.bg, child: body)
            : body;
      },
    );
  }

  /// A thin line at the bottom of the page in scroll mode: progress in the chapter, time left, clock and battery.
  Widget _scrollStatus(EdgeInsets safe) {
    final s = settings, t = s.readerTheme;
    final small = TextStyle(
      fontSize: 11.5,
      color: t.fg.withValues(alpha: 0.55),
      fontFamily: s.fontFamily == 'system' ? null : s.fontFamily,
    );
    final pct = _paras.isEmpty ? 0 : ((_topPara + 1) / _paras.length * 100).round();
    return IgnorePointer(
      child: Container(
        color: t.bg.withValues(alpha: 0.92),
        padding: EdgeInsets.fromLTRB(s.margin, 3, s.margin, safe.bottom + 3),
        child: Row(
          children: [
            Text('$pct%', style: small),
            const Spacer(),
            Text(timeLeftLabel(_charsFrom(_topPara)), style: small),
            const Spacer(),
            ClockBattery(style: small),
          ],
        ),
      ),
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
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Listener(
                          behavior: HitTestBehavior.translucent,
                          onPointerDown: (e) {
                            _readTime.poke();
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
                          child: _warm(
                            MediaQuery(
                              data: mq.copyWith(textScaler: TextScaler.noScaling),
                              child: _pdfMode
                                  ? _pdfView(mq)
                                  : settings.paged
                                  ? _pageView(mq.size, mq.padding)
                                  : _scrollView(mq.padding),
                            ),
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
                      if (settings.statusLine && !settings.paged && !_pdfMode && !_chrome)
                        Positioned(left: 0, right: 0, bottom: 0, child: _scrollStatus(mq.padding)),
                      if (_autoScroll && !_chrome)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: mq.padding.bottom + 30,
                          child: Center(child: _autoScrollBar(scheme)),
                        ),
                      if (_brightShown)
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.65), borderRadius: BorderRadius.circular(14)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.brightness_6, color: Colors.white),
                                const SizedBox(width: 10),
                                Text('${((_brightness ?? 0.5) * 100).round()}%', style: const TextStyle(color: Colors.white, fontSize: 16)),
                              ],
                            ),
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
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Translating this chapter…')],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (_chrome) ..._chromeBars(scheme, mq),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _message(String text, ReaderTheme t) => SafeArea(
    child: Stack(
      children: [
        Align(
          alignment: Alignment.topLeft,
          child: BackButton(color: t.fg),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: t.fg, fontSize: 16),
            ),
          ),
        ),
      ],
    ),
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
              child: Row(
                children: [
                  const BackButton(),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _book?.title ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        Text(
                          _chapter?.title ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
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
                        case 'auto':
                          _startAutoScroll();
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
                      PopupMenuItem(value: 'auto', child: Text(settings.paged || _pdfMode ? 'Turn pages automatically' : 'Auto-scroll')),
                      const PopupMenuItem(value: 'info', child: Text('Book details')),
                    ],
                  ),
                ],
              ),
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const SizedBox(width: 12),
                      Text('Chapter ${_idx + 1} of ${_metas.length}', style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
                      const Spacer(),
                      Text(
                        total == 0
                            ? ''
                            : _pdfMode
                            ? 'Page ${at + 1} of $total'
                            : '${((at + 1) / total * 100).round()}% of chapter',
                        style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(width: 12),
                    ],
                  ),
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
                              _pageCtrl?.jumpToPage(v.round() ~/ _per + (_idx > 0 ? 1 : 0));
                            } else {
                              _goToPara(v.round());
                            }
                            setState(() {});
                          },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        tooltip: 'Previous chapter',
                        icon: const Icon(Icons.skip_previous),
                        onPressed: _idx > 0 ? () => _open(_idx - 1) : null,
                      ),
                      IconButton(
                        tooltip: 'Chapters, bookmarks, highlights',
                        icon: const Icon(Icons.format_list_bulleted),
                        onPressed: () => showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          showDragHandle: true,
                          builder: (_) => ContentsSheet(
                            book: _book!,
                            metas: _metas,
                            currentIdx: _idx,
                            onOpen: (i, p) => _open(i, para: p),
                          ),
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
                        onPressed: _idx + 1 < _metas.length ? () => _open(_idx + 1) : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ];
  }
}
