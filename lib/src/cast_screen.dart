import 'package:flutter/material.dart';

import 'app.dart';
import 'characters.dart';
import 'cloud_tts.dart';
import 'db.dart';
import 'models.dart';

/// Deletes a chapter together with its saved natural-voice audio and speaker labels.
Future<void> deleteChapterAndAudio(int bookId, int chapterId) async {
  final ch = await Db.chapter(chapterId);
  if (ch != null) {
    try {
      await deleteChapterAudio(settings, ch.title, [ch.content, ch.translated]);
    } catch (_) {}
  }
  await Db.deleteChapter(bookId, chapterId);
}

/// Deletes every chapter before the one being read. The cast, bookmarks of the remaining chapters and
/// the reading position are kept. Returns how many chapters were removed.
Future<int> deleteFinishedChapters(int bookId) async {
  final b = await Db.book(bookId);
  if (b == null) return 0;
  final done = (await Db.chapterMetas(bookId)).where((m) => m.idx < b.curChapter).toList();
  for (final m in done) {
    await deleteChapterAndAudio(bookId, m.id);
  }
  bumpLibrary();
  return done.length;
}

/// The book's characters: who they are, and which voice each will get.
class CastScreen extends StatefulWidget {
  final Book book;
  const CastScreen({super.key, required this.book});
  @override
  State<CastScreen> createState() => _CastScreenState();
}

class _CastScreenState extends State<CastScreen> {
  List<CastMember> _cast = [];
  List<ChapterMeta> _metas = [];
  Set<int> _done = {};
  bool _running = false, _cancel = false;
  String _status = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _cancel = true;
    super.dispose();
  }

  Future<void> _load() async {
    final c = await Cast.of(widget.book.id!);
    final m = await Db.chapterMetas(widget.book.id!);
    final d = await Cast.analysedChapters(widget.book.id!);
    if (mounted) {
      setState(() {
        _cast = c;
        _metas = m;
        _done = d;
      });
    }
  }

  Future<void> _analyse(List<ChapterMeta> list) async {
    if (list.isEmpty) return toast(context, 'Every chapter has already been checked.');
    setState(() {
      _running = true;
      _cancel = false;
      _error = null;
    });
    var lines = 0, added = 0, i = 0;
    try {
      for (final m in list) {
        if (_cancel) break;
        i++;
        setState(() => _status = 'Chapter $i of ${list.length}: ${m.title}');
        final ch = await Db.chapter(m.id);
        if (ch == null) continue;
        final r = await analyzeChapter(settings, ch);
        lines += r.lines;
        added += r.newCharacters;
        await _load();
      }
      if (mounted) {
        setState(() => _status = '${_cancel ? 'Stopped' : 'Done'}: $lines lines of dialogue labelled, $added new character${added == 1 ? '' : 's'}.');
      }
    } catch (e) {
      if (mounted) setState(() => _error = settings.aiProvider == 'claude' ? '$e'.replaceFirst('AiException: ', '') : friendlyCloudError(e, voiceGemini));
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme, cs = Theme.of(context).colorScheme;
    final current = _metas.where((m) => m.idx == widget.book.curChapter).toList();
    final todo = _metas.where((m) => !_done.contains(m.id)).toList();
    return Scaffold(
      appBar: AppBar(title: Text('Characters · ${widget.book.title}', overflow: TextOverflow.ellipsis)),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
        Text(
          'The app reads each chapter with AI to find who says each line, then gives every character a voice that '
          'fits their gender and age. The cast stays with the book, so deleting finished chapters keeps it.',
          style: tt.bodyMedium,
        ),
        const SizedBox(height: 6),
        Text(
          'Uses your ${settings.aiProvider == 'claude' ? 'Claude' : 'Gemini'} key (a text model, which costs far less than voices). '
          'Character voices during listening come in the next update.',
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 14),
        Text('${_done.length} of ${_metas.length} chapters checked', style: tt.titleSmall),
        const SizedBox(height: 8),
        if (_running) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: 8),
          Text(_status),
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerLeft, child: OutlinedButton(onPressed: () => setState(() => _cancel = true), child: const Text('Stop'))),
        ] else ...[
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(
              icon: const Icon(Icons.person_search),
              label: const Text('Check the current chapter'),
              onPressed: current.isEmpty ? null : () => _analyse(current),
            ),
            OutlinedButton(
              onPressed: todo.isEmpty ? null : () => _analyse(todo),
              child: Text('Check all unchecked (${todo.length})'),
            ),
          ]),
          if (_status.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_status)),
        ],
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: TextStyle(color: cs.error))),
        const Divider(height: 32),
        Row(children: [
          Expanded(child: Text('Cast (${_cast.length})', style: tt.titleMedium)),
          Text('Narrator: ${settings.cloudTtsVoice}', style: tt.bodySmall),
        ]),
        const SizedBox(height: 4),
        if (_cast.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text('No characters yet. Check a chapter to find them.', textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
          ),
        for (final c in _cast)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: c.gender == 'female' ? cs.tertiaryContainer : (c.gender == 'male' ? cs.primaryContainer : cs.surfaceContainerHighest),
              child: Icon(c.gender == 'female' ? Icons.face_3 : (c.gender == 'male' ? Icons.face : Icons.person_outline), size: 20),
            ),
            title: Text(c.name),
            subtitle: Text([
              if (c.aliases.isNotEmpty) 'also ${c.aliases.take(3).join(', ')}',
              [c.gender, c.age].where((x) => x != 'unknown').join(', ').ifEmpty('gender and age unknown'),
              '${c.lines} line${c.lines == 1 ? '' : 's'}',
            ].join(' · ')),
            isThreeLine: c.aliases.isNotEmpty,
            trailing: Text(c.voice ?? 'narrator voice', style: tt.labelLarge?.copyWith(color: cs.primary)),
            onLongPress: () async {
              if (!await confirm(context, 'Remove ${c.name}?', 'Their lines will be read by the narrator.', ok: 'Remove')) return;
              await Cast.delete(c.id!);
              _load();
            },
          ),
      ]),
    );
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}
