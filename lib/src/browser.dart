import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import 'app.dart';
import 'db.dart';
import 'models.dart';
import 'reader.dart';
import 'text_utils.dart';

const textOnlyJs = '''
(function(){
  if(!document.getElementById('__lantern_css')){
    var s=document.createElement('style'); s.id='__lantern_css';
    s.textContent='img,picture,video,audio,embed,object{display:none!important}*{background-image:none!important}';
    (document.head||document.documentElement).appendChild(s);
  }
  document.querySelectorAll('video,audio').forEach(function(m){try{m.pause();m.removeAttribute('autoplay');}catch(e){}});
})()''';

const undoTextOnlyJs = "(function(){var s=document.getElementById('__lantern_css'); if(s) s.remove();})()";

/// Finds the link to the following chapter, if the page has one.
const nextLinkJs = '''
(function(){
  try{
    var l=document.querySelector('a[rel~="next"][href], link[rel~="next"][href]');
    if(l&&l.href&&!/^javascript/i.test(l.href)) return l.href;
    var as=document.querySelectorAll('a[href]'), best=null, score=0;
    for(var i=0;i<as.length;i++){
      var a=as[i], h=a.getAttribute('href')||'';
      if(!h||h.charAt(0)==='#'||/^javascript/i.test(h)) continue;
      var t=((a.innerText||a.getAttribute('aria-label')||a.title||'')+'').trim().toLowerCase();
      if(t.length>30) continue;
      var s=0;
      if(/^next\\s*chapter/.test(t)) s=5;
      else if(/^next\\b/.test(t)||t==='下一章'||t==='下一页') s=4;
      else if(/next/.test(t)&&/chapter/.test(t)) s=3;
      else if(t==='>'||t==='»'||t==='→'||t==='›') s=1;
      var c=((a.className||'')+' '+(a.id||'')).toLowerCase();
      if(s===0 && /next[-_]?(ch|page)|nextchap|\\bnext\\b/.test(c)) s=2;
      if(s>score){score=s;best=a.href;}
    }
    return best;
  }catch(e){return null;}
})()''';

/// Pulls the story text out of the page: a site-specific or well-known container if there is one,
/// otherwise whatever the article extractor decides is the main content.
String extractJs(String? hint) => '''
(function(){
  try{
    var sel=(window.getSelection&&String(window.getSelection()))||'';
    var hint=${jsonEncode(hint)};
    var cands=[hint,'#chapter-content','.chapter-content','#chr-content','.chr-c','.reading-content','.chapter-body',
      '.chapter__content','#chaptercontent','.entry-content','.post-content','#content .text'];
    var best=null,bestLen=0;
    for(var i=0;i<cands.length;i++){
      if(!cands[i]) continue;
      try{
        var els=document.querySelectorAll(cands[i]);
        for(var j=0;j<els.length;j++){var L=(els[j].innerText||'').length; if(L>bestLen){best=els[j];bestLen=L;}}
      }catch(e){}
      if(i===0&&best) break;
    }
    var art=null;
    try{ art=new Readability(document.cloneNode(true)).parse(); }catch(e){}
    var artLen=art&&art.textContent?art.textContent.length:0;
    var html,how;
    if(best&&(bestLen>=0.5*artLen||(hint&&bestLen>0))){html=best.innerHTML;how='container';}
    else if(art&&art.content){html=art.content;how='article';}
    else{html=document.body?document.body.innerHTML:'';how='page';}
    var h=document.querySelector('h1')||document.querySelector('.chapter-title')||document.querySelector('h2');
    return JSON.stringify({title:(art&&art.title)||document.title||'',docTitle:document.title||'',
      heading:h?(h.innerText||'').trim():'',html:html,selection:sel,url:location.href,next:$nextLinkJs,how:how});
  }catch(e){return JSON.stringify({error:String(e)});}
})()''';

/// JavaScript results arrive as JSON text, sometimes wrapped in an extra layer of quoting.
dynamic unwrapJsResult(Object? r) {
  dynamic v = r;
  for (var i = 0; i < 2 && v is String; i++) {
    try {
      v = jsonDecode(v);
    } catch (_) {
      break;
    }
  }
  return v;
}

/// Guesses the novel's name from a page title such as "Chapter 12 - Some Novel | Site".
String guessBookTitle(String docTitle, String host) {
  final parts = docTitle.split(RegExp(r'\s+[-–—|:·]\s+')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  final good = parts.where((s) => !RegExp(r'chapter|^ch\.?\s*\d|^\d+$|episode|第', caseSensitive: false).hasMatch(s)).toList();
  if (good.isEmpty) return host.replaceFirst('www.', '');
  final site = host.replaceFirst('www.', '').split('.').first.toLowerCase();
  final notSite = good.where((s) => s.toLowerCase().replaceAll(' ', '') != site).toList();
  return (notSite.isEmpty ? good : notSite).first;
}

class BrowserScreen extends StatefulWidget {
  final String? initialUrl;
  final bool standalone;
  const BrowserScreen({super.key, this.initialUrl, this.standalone = false});

  @override
  State<BrowserScreen> createState() => BrowserScreenState();
}

class BrowserScreenState extends State<BrowserScreen> {
  late final WebViewController _c;
  final _url = TextEditingController();
  final _urlFocus = FocusNode();
  double _progress = 0;
  String _current = '';
  String? _next, _extractor;
  bool _saving = false, _canBack = false, _canForward = false;

  @override
  void initState() {
    super.initState();
    _c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (r) {
          final ok = RegExp(r'^(https?|about|data|blob):', caseSensitive: false).hasMatch(r.url);
          return ok ? NavigationDecision.navigate : NavigationDecision.prevent;
        },
        onPageStarted: (u) {
          _setUrl(u);
          _applyTextOnly();
          if (mounted) setState(() => _next = null);
        },
        onProgress: (p) {
          if (mounted) setState(() => _progress = p / 100);
          if (p > 30) _applyTextOnly();
        },
        onPageFinished: (u) async {
          _setUrl(u);
          _applyTextOnly();
          _refreshNav();
        },
        onUrlChange: (c) {
          if (c.url != null) _setUrl(c.url!);
          _refreshNav();
        },
      ));
    final platform = _c.platform;
    if (platform is AndroidWebViewController) platform.setMediaPlaybackRequiresUserGesture(true);
    _c.loadRequest(Uri.parse(widget.initialUrl ?? settings.homeUrl));
  }

  @override
  void dispose() {
    _url.dispose();
    _urlFocus.dispose();
    super.dispose();
  }

  void _setUrl(String u) {
    _current = u;
    if (!_urlFocus.hasFocus) _url.text = u;
  }

  void _applyTextOnly() {
    if (settings.blockMedia) _c.runJavaScript(textOnlyJs).catchError((_) {});
  }

  Future<void> _refreshNav() async {
    try {
      final b = await _c.canGoBack(), f = await _c.canGoForward();
      final n = unwrapJsResult(await _c.runJavaScriptReturningResult(nextLinkJs));
      if (mounted) {
        setState(() {
          _canBack = b;
          _canForward = f;
          _next = n is String && n.startsWith('http') ? n : null;
        });
      }
    } catch (_) {}
  }

  /// Used by the home screen's back handling. Returns true if the page went back.
  Future<bool> goBack() async {
    if (await _c.canGoBack()) {
      await _c.goBack();
      return true;
    }
    return false;
  }

  void _go(String input) {
    var t = input.trim();
    if (t.isEmpty) return;
    if (!RegExp(r'^[a-z]+://', caseSensitive: false).hasMatch(t)) {
      t = (t.contains('.') && !t.contains(' ')) ? 'https://$t' : settings.searchUrl.replaceAll('%s', Uri.encodeQueryComponent(t));
    }
    _urlFocus.unfocus();
    _c.loadRequest(Uri.parse(t));
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      _extractor ??= await rootBundle.loadString('assets/js/readability.js');
      await _c.runJavaScript(_extractor!);
      final host = Uri.tryParse(_current)?.host ?? '';
      final raw = await _c.runJavaScriptReturningResult(extractJs(settings.siteSelectors[host] as String?));
      final m = unwrapJsResult(raw);
      if (m is! Map || m['error'] != null) throw Exception(m is Map ? m['error'] : 'The page did not return any text.');
      final selection = '${m['selection'] ?? ''}'.trim();
      final usedSelection = selection.length > 200;
      final paras = usedSelection ? plainToParagraphs(selection) : htmlToParagraphs('${m['html'] ?? ''}');
      final heading = '${m['heading'] ?? ''}'.trim();
      final title = (heading.isNotEmpty && heading.length < 140) ? heading : '${m['title'] ?? ''}'.trim();
      if (!mounted) return;
      final next = m['next'] is String ? m['next'] as String : null;
      final goNext = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _SaveSheet(
          url: '${m['url'] ?? _current}',
          host: host,
          chapterTitle: title.isEmpty ? 'Untitled chapter' : title,
          bookGuess: guessBookTitle('${m['docTitle'] ?? ''}', host),
          paras: paras,
          usedSelection: usedSelection,
          hasNext: next != null,
        ),
      );
      if (goNext == true && next != null) _c.loadRequest(Uri.parse(next));
    } catch (e) {
      if (mounted) toast(context, 'Could not read this page: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _menu(String v) async {
    final host = Uri.tryParse(_current)?.host ?? '';
    switch (v) {
      case 'home':
        _c.loadRequest(Uri.parse(settings.homeUrl));
      case 'sethome':
        settings.set('homeUrl', _current);
        toast(context, 'Start page set.');
      case 'media':
        settings.set('blockMedia', !settings.blockMedia);
        settings.blockMedia ? _applyTextOnly() : _c.runJavaScript(undoTextOnlyJs);
        setState(() {});
      case 'copy':
        await Clipboard.setData(ClipboardData(text: _current));
        if (mounted) toast(context, 'Link copied.');
      case 'selector':
        final cur = settings.siteSelectors[host] as String? ?? '';
        final s = await promptText(context, 'Story text location for $host',
            initial: cur,
            hint: '.chapter-content',
            help: 'Only needed if saving picks up the wrong text on this site. Enter the CSS selector of the element that '
                'holds the story. Leave empty to detect automatically.');
        if (s != null) {
          final map = settings.siteSelectors;
          s.trim().isEmpty ? map.remove(host) : map[host] = s.trim();
          settings.set('siteSelectors', map);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !widget.standalone || !_canBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) goBack();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: widget.standalone ? null : const MenuButton(),
          titleSpacing: 0,
          title: SizedBox(
            height: 42,
            child: TextField(
              controller: _url,
              focusNode: _urlFocus,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.go,
              autocorrect: false,
              style: const TextStyle(fontSize: 14.5),
              onTap: () => _url.selection = TextSelection(baseOffset: 0, extentOffset: _url.text.length),
              onSubmitted: _go,
              decoration: InputDecoration(
                hintText: 'Search or type a web address',
                isDense: true,
                filled: true,
                fillColor: cs.surfaceContainerHighest,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
              ),
            ),
          ),
          actions: [
            PopupMenuButton<String>(
              onSelected: _menu,
              itemBuilder: (c) => [
                const PopupMenuItem(value: 'home', child: Text('Start page')),
                const PopupMenuItem(value: 'sethome', child: Text('Use this page as start page')),
                CheckedPopupMenuItem(value: 'media', checked: settings.blockMedia, child: const Text('Text only (hide images and video)')),
                const PopupMenuItem(value: 'copy', child: Text('Copy link')),
                const PopupMenuItem(value: 'selector', child: Text('Fix text detection for this site…')),
              ],
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(3),
            child: _progress > 0 && _progress < 1 ? LinearProgressIndicator(value: _progress, minHeight: 3) : const SizedBox(height: 3),
          ),
        ),
        body: WebViewWidget(controller: _c),
        bottomNavigationBar: Material(
          color: cs.surfaceContainer,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(children: [
                IconButton(tooltip: 'Back', visualDensity: VisualDensity.compact, icon: const Icon(Icons.arrow_back), onPressed: _canBack ? _c.goBack : null),
                IconButton(tooltip: 'Forward', visualDensity: VisualDensity.compact, icon: const Icon(Icons.arrow_forward), onPressed: _canForward ? _c.goForward : null),
                IconButton(tooltip: 'Reload', visualDensity: VisualDensity.compact, icon: const Icon(Icons.refresh), onPressed: _c.reload),
                const SizedBox(width: 4),
                Expanded(
                  child: FilledButton.icon(
                  icon: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.bookmark_add_outlined),
                    label: const Text('Save chapter', maxLines: 1, softWrap: false, overflow: TextOverflow.fade),
                    onPressed: _saving ? null : _save,
                  ),
                ),
                const SizedBox(width: 6),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.only(left: 14, right: 8)),
                  onPressed: _next == null ? null : () => _c.loadRequest(Uri.parse(_next!)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [Text('Next'), Icon(Icons.chevron_right, size: 20)]),
                ),
                const SizedBox(width: 6),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Preview of what will be saved, with the chapter title and target book. Pops true for "save and
/// go to the next chapter", false for a plain save, null if cancelled.
class _SaveSheet extends StatefulWidget {
  final String url, host, chapterTitle, bookGuess;
  final List<String> paras;
  final bool usedSelection, hasNext;
  const _SaveSheet({
    required this.url,
    required this.host,
    required this.chapterTitle,
    required this.bookGuess,
    required this.paras,
    required this.usedSelection,
    required this.hasNext,
  });

  @override
  State<_SaveSheet> createState() => _SaveSheetState();
}

class _SaveSheetState extends State<_SaveSheet> {
  late final _title = TextEditingController(text: widget.chapterTitle);
  late final _newBook = TextEditingController(text: widget.bookGuess);
  List<Book> _books = [];
  int? _bookId; // null = create a new book
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    Db.books().then((all) {
      if (!mounted) return;
      int recency(Book b) => b.lastReadAt > b.addedAt ? b.lastReadAt : b.addedAt;
      final web = all.where((b) => b.format == 'WEB').toList()..sort((a, b) => recency(b).compareTo(recency(a)));
      final remembered = (settings.browserTargets[widget.host] as num?)?.toInt();
      final guess = widget.bookGuess.toLowerCase();
      setState(() {
        _books = web;
        _bookId = web.where((b) => b.id == remembered).firstOrNull?.id ?? web.where((b) => b.title.toLowerCase() == guess).firstOrNull?.id;
        _loaded = true;
      });
    });
  }

  Future<void> _save(bool goNext) async {
    final chars = widget.paras.fold<int>(0, (n, p) => n + p.length);
    if (chars == 0) return;
    var id = _bookId;
    if (id == null) {
      final name = _newBook.text.trim();
      if (name.isEmpty) return toast(context, 'Give the new book a name.');
      id = await Db.insertBook(Book(title: name, format: 'WEB', sourceUrl: widget.url));
    } else if (await Db.hasChapterUrl(id, widget.url)) {
      if (!mounted) return;
      if (!await confirm(context, 'Already saved', 'This page is already a chapter in this book. Save it again?', ok: 'Save again')) return;
    }
    var paras = widget.paras;
    final title = _title.text.trim().isEmpty ? 'Untitled chapter' : _title.text.trim();
    // Drop a leading line that just repeats the chapter title.
    if (paras.isNotEmpty && paraText(paras.first).trim().toLowerCase() == title.toLowerCase()) paras = paras.sublist(1);
    await Db.addChapter(id, title, paras.join('\n'), url: widget.url);
    settings.set('browserTargets', {...settings.browserTargets, widget.host: id});
    bumpLibrary();
    if (!mounted) return;
    final b = await Db.book(id);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    nav.pop(goNext);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      persist: false,
      duration: const Duration(seconds: 5),
      content: Text('Saved as chapter ${b?.chapterCount ?? ''} of “${b?.title ?? ''}”.'),
      action: goNext
          ? null
          : SnackBarAction(
              label: 'Read',
              onPressed: () => nav.push(MaterialPageRoute(builder: (_) => ReaderScreen(bookId: id!, chapterIdx: (b?.chapterCount ?? 1) - 1, para: 0))),
            ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final chars = widget.paras.fold<int>(0, (n, p) => n + p.length);
    final words = widget.paras.fold<int>(0, (n, p) => n + p.split(' ').length);
    final thin = chars < 400;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 16),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Save this chapter', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'Chapter title', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          if (_loaded)
            DropdownButtonFormField<int?>(
              key: ValueKey('book-$_bookId-${_books.length}'),
              initialValue: _bookId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Add to book', border: OutlineInputBorder()),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('＋ New book')),
                for (final b in _books)
                  DropdownMenuItem<int?>(value: b.id, child: Text('${b.title}  (${b.chapterCount})', overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setState(() => _bookId = v),
            ),
          if (_loaded && _bookId == null) ...[
            const SizedBox(height: 12),
            TextField(controller: _newBook, decoration: const InputDecoration(labelText: 'New book name', border: OutlineInputBorder())),
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: thin ? cs.errorContainer : cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                thin
                    ? (chars == 0
                        ? 'No story text was found on this page. If the chapter is still loading or locked, open it fully and try again.'
                        : 'Only a little text was found ($words words). The chapter may be locked or still loading.')
                    : '${widget.paras.length} paragraphs · $words words · ${fmtListenTime(chars)} to listen'
                        '${widget.usedSelection ? ' · from your selection' : ''}',
                style: TextStyle(fontWeight: FontWeight.w600, color: thin ? cs.onErrorContainer : null),
              ),
              if (chars > 0) ...[
                const SizedBox(height: 8),
                Text(widget.paras.take(4).map(paraText).join('\n'), maxLines: 6, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
              ],
            ]),
          ),
          const SizedBox(height: 14),
          Row(children: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            const Spacer(),
            if (widget.hasNext) ...[
              OutlinedButton(onPressed: chars == 0 ? null : () => _save(false), child: const Text('Save')),
              const SizedBox(width: 8),
              FilledButton(onPressed: chars == 0 ? null : () => _save(true), child: const Text('Save & next')),
            ] else
              FilledButton(onPressed: chars == 0 ? null : () => _save(false), child: const Text('Save')),
          ]),
        ]),
      ),
    );
  }
}
