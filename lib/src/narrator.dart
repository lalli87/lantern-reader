import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';

import 'app.dart' show engineLabel;
import 'characters.dart';
import 'stats.dart' show Activity;
import 'exports.dart' show exportedChapterFile;
import 'cloud_tts.dart';

import 'db.dart';
import 'models.dart';
import 'settings.dart';
import 'text_utils.dart';

/// What the narrator is doing right now, for the reader and the mini player.
class NarrationState {
  final int? bookId, chapterId;
  final int chapterIdx, para, start, end, lastPara;
  final bool playing, loading;
  final String bookTitle, chapterTitle;
  const NarrationState({
    this.bookId,
    this.chapterId,
    this.chapterIdx = 0,
    this.para = 0,
    this.lastPara = 0,
    this.loading = false,
    this.start = 0,
    this.end = 0,
    this.playing = false,
    this.bookTitle = '',
    this.chapterTitle = '',
  });
  bool get active => bookId != null;
}

enum SleepMode { off, timer, chapterEnd }

class SleepState {
  final SleepMode mode;
  final DateTime? at;
  const SleepState(this.mode, [this.at]);
}

final _speakable = RegExp(r'[\p{L}\p{N}]', unicode: true);

/// Reads chapters aloud with the phone's text-to-speech engine and exposes playback to the
/// system (lock screen, notification, Bluetooth and car controls) through a media session.
class Narrator extends BaseAudioHandler {
  Narrator(this.settings);

  final Settings settings;
  final FlutterTts _tts = FlutterTts();
  final state = ValueNotifier<NarrationState>(const NarrationState());
  final sleep = ValueNotifier<SleepState>(const SleepState(SleepMode.off));
  final error = ValueNotifier<String?>(null);

  Book? _book;
  List<ChapterMeta> _metas = [];
  Chapter? _chapter;
  int _chapterIdx = 0;
  List<String> _paras = [];
  List<SpeechChunk> _chunks = [];
  int _ci = 0;
  bool _translated = false;

  bool _playing = false, _started = false, _stopAfterChunk = false, _ready = false;
  int _spokenBase = 0, _wordOffset = 0, _resumeOffset = 0, _gen = 0, _errors = 0;
  Timer? _sleepTimer, _watchdog;

  AudioSession? _session;

  // Cloud voices: audio files played in sequence, fetched a few pieces ahead.
  AudioPlayer? _player;
  bool _chunkLoaded = false, _loading = false;
  final Map<String, Future<File>> _fetches = {};
  /// Source of the chapter being read. Normally the chosen voice; the phone voice after a fallback.
  String _activeSource = voiceDevice;
  bool get _cloud => _activeSource != voiceDevice;
  bool _prefetching = false, _awake = false;
  int? _nextChapterPrefetched;
  // Chapters being checked for characters in the background, and ones that failed this session.
  final Set<int> _analysing = {}, _analysisFailed = {};
  // Offline: the chapter's file from "Make audio files" plays as one piece marked with [_fileVoice].
  File? _exportFile;
  static const _fileVoice = '\u0000file';
  static const _audioChannel = MethodChannel('lantern/audio');
  bool _interrupted = false, _ignoreFocus = false;
  int _selfInterrupts = 0;
  DateTime _lastSpeakAt = DateTime.fromMillisecondsSinceEpoch(0);

  bool get isPlaying => _playing;

  // Listening time for reading stats, added every half minute while playing.
  Timer? _statTimer;
  DateTime _statAt = DateTime.now();
  void _statTick() {
    final now = DateTime.now();
    final ms = now.difference(_statAt).inMilliseconds;
    _statAt = now;
    final id = _book?.id;
    if (id != null && ms > 0) Activity.add(id, listenMs: ms > 60000 ? 60000 : ms);
  }

  void _trackListening(bool playing) {
    if (playing && _statTimer == null) {
      _statAt = DateTime.now();
      _statTimer = Timer.periodic(const Duration(seconds: 30), (_) => _statTick());
    } else if (!playing && _statTimer != null) {
      _statTick();
      _statTimer?.cancel();
      _statTimer = null;
    }
  }
  Book? get book => _book;
  bool get usingTranslation => _translated;

  /// Connects to the speech engine and audio focus. Safe to call more than once.
  Future<void> init() async {
    if (_ready) return;
    _ready = true;
    _tts.setStartHandler(() => _started = true);
    _tts.setProgressHandler((text, start, end, word) => _wordOffset = start);
    _tts.setCancelHandler(() {});
    _tts.setCompletionHandler(_onChunkDone);
    _tts.setErrorHandler((msg) {
      if (!_playing) return;
      if (++_errors > 3) {
        error.value = 'The speech engine reported an error: $msg';
        pause();
      } else {
        _ci++;
        _speak();
      }
    });
    try {
      // Calls made before the engine is connected wait for it, so cap the wait: with no engine
      // installed they would never return.
      await Future(() async {
        await _tts.awaitSpeakCompletion(false);
        await applyVoice(engineChanged: true);
      }).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('TTS init incomplete: $e');
    }
    try {
      final s = _session = await AudioSession.instance;
      await s.configure(const AudioSessionConfiguration.speech());
      s.interruptionEventStream.listen(_onInterruption);
      s.becomingNoisyEventStream.listen((_) {
        if (_playing) pause();
      });
    } catch (e) {
      debugPrint('Audio session unavailable: $e');
    }
  }

  void _onInterruption(AudioInterruptionEvent e) {
    if (_ignoreFocus) return;
    // The speech engine briefly asks for "duck" focus for every utterance; that is not an interruption.
    if (e.type == AudioInterruptionType.duck) return;
    if (e.begin) {
      if (!_playing) return;
      // If an engine takes full focus for its own speech we would pause ourselves in a loop.
      // Two such events right after our own speak() mean focus handling has to be left alone.
      if (DateTime.now().difference(_lastSpeakAt) < const Duration(milliseconds: 700)) {
        if (++_selfInterrupts >= 2) {
          _ignoreFocus = true;
          return;
        }
      } else {
        _selfInterrupts = 0;
      }
      _interrupted = e.type == AudioInterruptionType.pause;
      pause();
    } else if (_interrupted) {
      _interrupted = false;
      play();
    }
  }

  // ---- engine and voice ----

  Future<List<String>> engines() async {
    try {
      return ((await _tts.getEngines) as List).map((e) => '$e').toList();
    } catch (_) {
      return [];
    }
  }

  Future<String> defaultEngine() async {
    try {
      return '${await _tts.getDefaultEngine ?? ''}';
    } catch (_) {
      return '';
    }
  }

  /// Installed voices as maps with at least `name` and `locale`.
  Future<List<Map<String, String>>> voices() async {
    try {
      final v = (await _tts.getVoices) as List;
      return v.map((e) => (e as Map).map((k, x) => MapEntry('$k', '$x'))).toList()
        ..sort((a, b) => '${a['locale']}${a['name']}'.compareTo('${b['locale']}${b['name']}'));
    } catch (_) {
      return [];
    }
  }

  /// Applies engine, voice, speed and pitch from settings.
  Future<void> applyVoice({bool engineChanged = false}) async {
    if (engineChanged && settings.ttsEngine.isNotEmpty && !kIsWeb && Platform.isAndroid) {
      await _tts.setEngine(settings.ttsEngine);
    }
    if (settings.ttsVoice.isNotEmpty) {
      await _tts.setVoice({'name': settings.ttsVoice, 'locale': settings.ttsLocale});
    }
    // The plugin maps 0.5 to the engine's normal speed.
    await _tts.setSpeechRate(settings.ttsRate * 0.5);
    await _tts.setPitch(settings.ttsPitch);
  }

  Future<void> chooseEngine(String engine) async {
    final was = _playing;
    if (was) await pause();
    settings.set('ttsEngine', engine);
    settings.set('ttsVoice', '');
    settings.set('ttsLocale', '');
    if (engine.isNotEmpty) await _tts.setEngine(engine);
    await applyVoice();
    if (was) await play();
  }

  Future<void> chooseVoice(String name, String locale) async {
    settings.set('ttsVoice', name);
    settings.set('ttsLocale', locale);
    final remembered = settings.voiceRates[name];
    if (remembered is num) settings.set('ttsRate', remembered.toDouble());
    await _restartChunk(applyVoice);
  }

  Future<void> setRate(double r) async {
    settings.set('ttsRate', r);
    if (_cloud) {
      await _player?.setSpeed(r);
      return;
    }
    if (settings.ttsVoice.isNotEmpty) settings.set('voiceRates', {...settings.voiceRates, settings.ttsVoice: r});
    await _restartChunk(() => _tts.setSpeechRate(r * 0.5));
  }

  Future<void> setPitch(double p) async {
    settings.set('ttsPitch', p);
    await _restartChunk(() => _tts.setPitch(p));
  }

  /// Voice changes only apply to the next utterance, so restart the current sentence.
  Future<void> _restartChunk(Future<void> Function() change) async {
    final was = _playing;
    if (was) await pause();
    try {
      await change();
    } catch (e) {
      error.value = 'Could not apply the voice setting: $e';
    }
    if (was) await play();
  }

  /// Speaks a short sample with the current voice.
  /// [voice] and [style] preview a character's voice instead of the narrator's.
  Future<void> preview(String text, {String? voice, String style = ''}) async {
    if (_playing) await pause();
    if (settings.voiceSource != voiceDevice) {
      try {
        final f = await cloudAudioFile(settings, settings.voiceSource, text, voice: voice, style: style);
        final p = await _ensurePlayer();
        _chunkLoaded = false;
        await p.setFilePath(f.path);
        await p.setSpeed(settings.ttsRate);
        unawaited(p.play());
      } catch (e) {
        error.value = '$e';
      }
      return;
    }
    unawaited(_tts.speak(text).catchError((_) {}));
  }

  /// Switches between the phone voice and cloud voices, continuing from the same place.
  Future<void> setVoiceSource(String source) async {
    final was = _playing;
    final para = state.value.para;
    await _halt();
    _nextChapterPrefetched = null;
    settings.set('voiceSource', source);
    if (_book != null && _chapter != null) {
      await _loadChapter(_chapterIdx, para < 0 ? 0 : para);
      if (was) await play();
    }
  }

  /// A cloud voice setting changed (voice name, style): carry on from the same paragraph with it.
  /// The chapter is split again, since a new narrator can change which character voices are used.
  Future<void> cloudVoiceChanged() async {
    if (settings.voiceSource == voiceDevice || _book == null) return;
    _fetches.clear();
    await setVoiceSource(settings.voiceSource);
  }

  /// Turns separate voices for characters on or off, continuing from the same paragraph.
  Future<void> setCharacterVoices(bool on) async {
    settings.set('characterVoices', on);
    if (_book == null || settings.voiceSource == voiceDevice) return;
    await setVoiceSource(settings.voiceSource);
  }

  Future<AudioPlayer> _ensurePlayer() async {
    if (_player != null) return _player!;
    final p = _player = AudioPlayer(handleInterruptions: false, handleAudioSessionActivation: false);
    p.processingStateStream.listen((s) {
      if (s == ProcessingState.completed && _playing && _chunkLoaded) {
        _chunkLoaded = false;
        _started = true;
        _onChunkDone();
      }
    });
    return p;
  }

  // ---- loading ----

  /// Starts reading [bookId] from the given chapter and paragraph.
  Future<void> start(int bookId, int chapterIdx, int para, {bool translated = false}) async {
    await init();
    if (_playing) await _halt();
    final b = await Db.book(bookId);
    if (b == null) return;
    _book = b;
    _translated = translated;
    _metas = await Db.chapterMetas(bookId);
    if (_metas.isEmpty) {
      error.value = 'This book has no chapters yet.';
      return;
    }
    if (!await _loadChapter(chapterIdx.clamp(0, _metas.length - 1), para)) return;
    await play();
  }

  Future<bool> _loadChapter(int idx, int para) async {
    final ch = await Db.chapterAt(_book!.id!, idx);
    if (ch == null) return false;
    _chapter = ch;
    _chapterIdx = idx;
    _paras = splitParas(_translated && ch.translated.isNotEmpty ? ch.translated : ch.content);
    _activeSource = settings.voiceSource;
    _exportFile = null;
    _chunks = _cloud ? (await _characterPlan(ch, _paras) ?? cloudChunks(_paras)) : speechChunks(_paras);
    final first = _chunks.indexWhere((c) => c.para >= para);
    _ci = first < 0 ? _chunks.length : first;
    final titleIsFirstLine = _paras.isNotEmpty && paraText(_paras.first).trim() == ch.title.trim();
    if (para <= 0 && settings.readTitles && !titleIsFirstLine && ch.title.isNotEmpty) {
      _chunks.insert(0, SpeechChunk(-1, 0, 0, ch.title));
      _ci = 0;
    }
    _resumeOffset = 0;
    final cover = _book!.coverPath;
    mediaItem.add(MediaItem(
      id: 'chapter-${ch.id}',
      title: ch.title,
      album: _book!.title,
      artist: _book!.author.isEmpty ? null : _book!.author,
      artUri: cover != null && File(cover).existsSync() ? Uri.file(cover) : null,
    ));
    _publish();
    _analyseAhead();
    return true;
  }

  /// Pieces with character voices for a chapter, or null to read it all with the narrator.
  Future<List<SpeechChunk>?> _characterPlan(Chapter ch, List<String> paras) async {
    if (!settings.characterVoices || _translated) return null;
    try {
      return await characterPlan(settings, _activeSource, ch, paras);
    } catch (e) {
      debugPrint('Character voices unavailable: $e');
      return null;
    }
  }

  /// With character voices on, checks the current and next chapter for characters in the background
  /// if that hasn't been done, so the next chapter is ready before it starts.
  void _analyseAhead() {
    if (!_cloud || !settings.characterVoices || _translated || !canAnalyse(settings)) return;
    if (narratorName(settings, _activeSource) == null) return;
    final bookId = _book!.id!, idx = _chapterIdx, cur = _chapter!;
    () async {
      for (final i in [idx, idx + 1]) {
        if (i >= _metas.length || _book?.id != bookId) return;
        final ch = i == idx ? cur : await Db.chapterAt(bookId, i);
        final id = ch?.id;
        if (ch == null || id == null || _analysing.contains(id) || _analysisFailed.contains(id)) continue;
        if (await Cast.speakers(id) != null) continue;
        _analysing.add(id);
        try {
          await analyzeChapter(settings, ch);
          if (i == idx) await _replanCurrent(ch);
        } catch (e) {
          _analysisFailed.add(id);
          final why = settings.aiProvider == 'claude'
              ? '$e'.replaceFirst('AiException: ', '')
              : friendlyCloudError(e, voiceGemini);
          if (_analysisFailed.length == 1) {
            error.value = 'Couldn\'t find the characters in "${ch.title}": $why Reading it with the narrator\'s voice.';
          }
          return;
        } finally {
          _analysing.remove(id);
        }
      }
    }();
  }

  /// The current chapter has just been checked: use character voices from the next piece on.
  Future<void> _replanCurrent(Chapter ch) async {
    if (_chapter?.id != ch.id || !_cloud) return;
    final plan = await _characterPlan(ch, _paras);
    if (plan == null || _chapter?.id != ch.id || !_cloud || _chunks.isEmpty) return;
    final keep = _ci.clamp(0, _chunks.length - 1);
    final after = _chunks[keep].para < 0 ? -1 : _chunks[keep].lastPara;
    _chunks = [..._chunks.take(keep + 1), ...plan.where((c) => c.para > after)];
  }

  // ---- transport ----

  @override
  Future<void> play() async {
    if (_book == null || _playing) return;
    await init();
    error.value = null;
    if (!_ignoreFocus && _session != null) {
      try {
        if (!await _session!.setActive(true)) {
          error.value = 'Another app is using audio right now.';
          return;
        }
      } catch (_) {}
    }
    try {
      // Speech is played by the engine's process, so ask the system to send headset, Bluetooth
      // and car buttons to this app's media session anyway.
      await AudioService.androidForceEnableMediaButtons();
    } catch (_) {}
    _playing = true;
    _errors = 0;
    if (_cloud && _chunkLoaded && _player != null) {
      // Resume exactly where the audio was paused.
      _publish();
      unawaited(_player!.play());
      return;
    }
    _publish();
    await _speak();
  }

  @override
  Future<void> pause() async {
    if (!_playing) return;
    if (_cloud && _chunkLoaded) {
      _playing = false;
      _gen++;
      _keepAwake(false);
      await _player?.pause();
      _publish();
      return;
    }
    // Resume from the start of the sentence that was being spoken.
    if (_ci < _chunks.length) {
      final c = _chunks[_ci];
      final off = (_spokenBase + _wordOffset).clamp(0, c.text.length);
      _resumeOffset = sentenceStartBefore(c.text, off);
    }
    await _halt();
    _publish();
  }

  Future<void> _halt() async {
    _playing = false;
    _started = false;
    _gen++;
    _watchdog?.cancel();
    _chunkLoaded = false;
    _loading = false;
    _keepAwake(false);
    try {
      await _player?.stop();
    } catch (_) {}
    try {
      await _tts.stop().timeout(const Duration(seconds: 2));
    } catch (_) {}
  }

  Future<void> toggle() => _playing ? pause() : play();

  @override
  Future<void> stop() async {
    await _halt();
    cancelSleep();
    _book = null;
    _chapter = null;
    _chunks = [];
    state.value = const NarrationState();
    playbackState.add(PlaybackState(processingState: AudioProcessingState.idle, playing: false));
    try {
      await _session?.setActive(false);
    } catch (_) {}
    await super.stop();
  }

  @override
  Future<void> skipToNext() => settings.skipByChapter ? nextChapter() : nextPara();
  @override
  Future<void> skipToPrevious() => settings.skipByChapter ? prevChapter() : prevPara();
  @override
  Future<void> fastForward() => nextPara();
  @override
  Future<void> rewind() => prevPara();
  @override
  Future<void> onTaskRemoved() => stop();
  @override
  Future<void> onNotificationDeleted() => stop();

  Future<void> _jump(Future<void> Function() move) async {
    if (_book == null) return;
    final was = _playing;
    await _halt();
    _resumeOffset = 0;
    await move();
    _publish();
    if (was) await play();
  }

  Future<void> nextPara() => _jump(() async {
        if (_ci < _chunks.length) {
          final cur = _chunks[_ci].para;
          while (_ci < _chunks.length && _chunks[_ci].para == cur) {
            _ci++;
          }
        }
        if (_ci >= _chunks.length && _chapterIdx + 1 < _metas.length) await _loadChapter(_chapterIdx + 1, 0);
      });

  Future<void> prevPara() => _jump(() async {
        if (_ci >= _chunks.length) _ci = _chunks.length - 1;
        if (_ci <= 0) return;
        final cur = _chunks[_ci].para;
        // Back to the start of this paragraph if we were mid-way, otherwise to the previous one.
        var i = _ci;
        while (i > 0 && _chunks[i - 1].para == cur) {
          i--;
        }
        if (i == _ci && i > 0) {
          final prev = _chunks[i - 1].para;
          i--;
          while (i > 0 && _chunks[i - 1].para == prev) {
            i--;
          }
        }
        _ci = i;
      });

  Future<void> nextChapter() => _jump(() async {
        if (_chapterIdx + 1 < _metas.length) await _loadChapter(_chapterIdx + 1, 0);
      });

  Future<void> prevChapter() => _jump(() async {
        if (_chapterIdx > 0) await _loadChapter(_chapterIdx - 1, 0);
      });

  /// Moves narration to a paragraph in the current chapter (for "read from here").
  Future<void> jumpToPara(int para) => _jump(() async {
        final i = _chunks.indexWhere((c) => c.para >= para);
        if (i >= 0) _ci = i;
      });

  // ---- speaking ----

  Future<void> _speak() async {
    while (_playing && _ci < _chunks.length && !_speakable.hasMatch(_chunks[_ci].text)) {
      _ci++;
    }
    if (!_playing) return;
    if (_ci >= _chunks.length) return _chapterDone();
    final c = _chunks[_ci];
    var text = c.text;
    _spokenBase = 0;
    if (_resumeOffset > 0 && _resumeOffset < text.length) {
      _spokenBase = _resumeOffset;
      text = text.substring(_resumeOffset);
    }
    _resumeOffset = 0;
    _wordOffset = 0;
    _started = false;
    _lastSpeakAt = DateTime.now();
    _publish();
    if (c.para >= 0) {
      Db.savePosition(_book!.id!, _chapterIdx, c.para, within: _paras.isEmpty ? 0 : c.para / _paras.length);
    }
    final gen = ++_gen;
    if (_activeSource != voiceDevice) return _speakCloud(gen);
    _watchdog?.cancel();
    _watchdog = Timer(const Duration(seconds: 10), () {
      if (_playing && !_started && gen == _gen) {
        error.value = 'The speech engine did not respond. Check that a text-to-speech engine and voice are '
            'installed (phone Settings → Text-to-speech), then pick it under Voice.';
        pause();
      }
    });
    // Not awaited: progress comes back through the start/completion handlers, and the watchdog
    // above covers an engine that never answers.
    unawaited(_tts.speak(applyReplacements(text, settings.replacements)).catchError((Object e) {
      if (gen == _gen && _playing) {
        error.value = 'Could not start speech: $e';
        pause();
      }
    }));
  }

  String _textAt(int i) => applyReplacements(_chunks[i].text, settings.replacements);

  Future<File> _fetch(int i) => _fetchPiece(_textAt(i), _chunks[i].voice, _chunks[i].style);

  Future<File> _fetchPiece(String text, String? voice, String style) {
    if (voice == _fileVoice && _exportFile != null) return Future.value(_exportFile!);
    final source = _activeSource;
    final key = '$source|${voice ?? ''}|$style|$text';
    return _fetches.putIfAbsent(key, () {
      final f = cloudAudioFile(settings, source, text, voice: voice, style: style);
      f.catchError((Object _) {
        _fetches.remove(key);
        return File('');
      });
      return f;
    });
  }

  /// Starts fetching the next few pieces so playback does not wait between them.
  /// Fetches up to six pieces ahead, one at a time (cloud voices limit requests per minute), and
  /// the start of the next chapter near the end, so short network drops don't interrupt playback.
  void _prefetch() {
    if (_prefetching) return;
    _prefetching = true;
    final gen = _gen;
    () async {
      try {
        if (_fetches.length > 40) _fetches.clear();
        for (var i = _ci + 1; i < _chunks.length && i <= _ci + 6; i++) {
          if (gen != _gen || !_cloud) return;
          if (_speakable.hasMatch(_chunks[i].text)) await _fetch(i);
        }
        if (gen == _gen && _cloud && _ci >= _chunks.length - 4) await _prefetchNextChapter();
      } catch (_) {
        // Errors surface when the piece is actually needed.
      } finally {
        _prefetching = false;
      }
    }();
  }

  Future<void> _prefetchNextChapter() async {
    final next = _chapterIdx + 1;
    if (!settings.autoNextChapter || next >= _metas.length || _nextChapterPrefetched == next) return;
    _nextChapterPrefetched = next;
    final ch = await Db.chapterAt(_book!.id!, next);
    if (ch == null) return;
    final paras = splitParas(_translated && ch.translated.isNotEmpty ? ch.translated : ch.content);
    final pieces = await _characterPlan(ch, paras) ?? cloudChunks(paras);
    final titleFirst = paras.isNotEmpty && paraText(paras.first).trim() == ch.title.trim();
    final first = [
      if (settings.readTitles && !titleFirst && ch.title.isNotEmpty) SpeechChunk(-1, 0, 0, ch.title),
      ...pieces.where((c) => _speakable.hasMatch(c.text)).take(2),
    ];
    for (final c in first) {
      await _fetchPiece(applyReplacements(c.text, settings.replacements), c.voice, c.style);
    }
  }

  static bool _isNetworkError(Object e) {
    final m = '$e';
    return e is SocketException || e is TimeoutException || m.contains('SocketException') || m.contains('ClientException') ||
        m.contains('TimeoutException') || m.contains('Connection') || m.contains('Failed host lookup');
  }

  /// Keeps Wi-Fi and the CPU awake while a cloud voice is playing, so the next pieces can still be
  /// downloaded with the screen off.
  void _keepAwake(bool on) {
    if (on == _awake || kIsWeb || !Platform.isAndroid) return;
    _awake = on;
    unawaited(_audioChannel.invokeMethod('keepAwake', on).catchError((Object _) => null));
  }

  /// When a cloud voice can't be reached, carry on with the phone voice from the current paragraph
  /// instead of stopping. The next chapter tries the chosen voice again.
  Future<void> _fallBackToPhone(String reason) async {
    final para = _ci < _chunks.length ? _chunks[_ci].para : 0;
    _fetches.clear();
    _activeSource = voiceDevice;
    _chunkLoaded = false;
    try {
      await _player?.stop();
    } catch (_) {}
    _chunks = speechChunks(_paras);
    final i = _chunks.indexWhere((c) => c.para >= (para < 0 ? 0 : para));
    _ci = i < 0 ? _chunks.length : i;
    error.value = '$reason Continuing with the phone voice for this chapter.';
    _publish();
    await _speak();
  }

  Future<void> _speakCloud(int gen) async {
    _loading = true;
    _publish();
    Object? lastError;
    // Network hiccups (Wi-Fi waking up, a tunnel in the car) usually clear within seconds.
    for (final wait in const [0, 3, 8]) {
      if (wait > 0) {
        await Future<void>.delayed(Duration(seconds: wait));
        if (gen != _gen || !_playing) return;
      }
      try {
        final f = await _fetch(_ci);
        if (gen != _gen || !_playing) return;
        final p = await _ensurePlayer();
        await p.setFilePath(f.path);
        await p.setSpeed(settings.ttsRate);
        if (gen != _gen || !_playing) return;
        _chunkLoaded = true;
        _loading = false;
        _publish();
        unawaited(p.play());
        _prefetch();
        return;
      } catch (e) {
        if (gen != _gen) return;
        lastError = e;
        if (!_isNetworkError(e)) break;
        if (await _playExported(gen)) return;
      }
    }
    _loading = false;
    final label = voiceSourceLabel(_activeSource);
    final reason = _isNetworkError(lastError!)
        ? 'The $label voice couldn\'t be reached (no internet).'
        : friendlyCloudError(lastError, _activeSource);
    await _fallBackToPhone(reason);
  }

  /// No internet and this piece wasn't saved: play the chapter's file from "Make audio files" if there is
  /// one, from about the same place, instead of switching to the phone voice.
  Future<bool> _playExported(int gen) async {
    if (_book == null || _chapter == null || _ci >= _chunks.length) return false;
    if (_chunks[_ci].voice == _fileVoice) return false;
    File? f;
    try {
      f = await exportedChapterFile(_book!, _chapter!.title);
    } catch (_) {}
    if (f == null || gen != _gen || !_playing) return false;
    final total = _chunks.fold<int>(0, (n, c) => n + c.text.length);
    final before = _chunks.take(_ci).fold<int>(0, (n, c) => n + c.text.length);
    final cur = _chunks[_ci];
    _exportFile = f;
    // The rest of the chapter becomes one piece: the file.
    _chunks = [
      ..._chunks.take(_ci),
      SpeechChunk(cur.para < 0 ? 0 : cur.para, 0, 0, 'chapter audio file',
          lastPara: _paras.isEmpty ? 0 : _paras.length - 1, voice: _fileVoice),
    ];
    try {
      final p = await _ensurePlayer();
      final d = await p.setFilePath(f.path);
      if (d != null && total > 0 && before > 0) await p.seek(d * (before / total));
      await p.setSpeed(settings.ttsRate);
      if (gen != _gen || !_playing) return true;
      _chunkLoaded = true;
      _loading = false;
      _publish();
      unawaited(p.play());
      return true;
    } catch (e) {
      debugPrint('Could not play the chapter file: $e');
      return false;
    }
  }

  void _onChunkDone() {
    if (!_playing || !_started) return;
    _started = false;
    _errors = 0;
    _ci++;
    if (_stopAfterChunk) {
      cancelSleep();
      pause();
      return;
    }
    _speak();
  }

  Future<void> _chapterDone() async {
    final next = _chapterIdx + 1;
    final hasNext = next < _metas.length;
    if (sleep.value.mode == SleepMode.chapterEnd || !settings.autoNextChapter || !hasNext) {
      cancelSleep();
      await _halt();
      if (hasNext) {
        await _loadChapter(next, 0);
        await Db.savePosition(_book!.id!, next, 0);
      } else {
        await Db.savePosition(_book!.id!, _chapterIdx, _paras.isEmpty ? 0 : _paras.length - 1, within: 1);
      }
      _publish();
      return;
    }
    if (await _loadChapter(next, 0)) await _speak();
  }

  void _publish() {
    _keepAwake(_playing && _cloud);
    _trackListening(_playing);
    final c = _ci < _chunks.length ? _chunks[_ci] : null;
    state.value = NarrationState(
      bookId: _book?.id,
      chapterId: _chapter?.id,
      chapterIdx: _chapterIdx,
      para: c?.para ?? (_paras.isEmpty ? 0 : _paras.length - 1),
      lastPara: c?.lastPara ?? (_paras.isEmpty ? 0 : _paras.length - 1),
      loading: _loading,
      start: c?.start ?? 0,
      end: c?.end ?? 0,
      playing: _playing,
      bookTitle: _book?.title ?? '',
      chapterTitle: _chapter?.title ?? '',
    );
    if (_book == null) return;
    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        _playing ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      androidCompactActionIndices: const [0, 1, 2],
      processingState: AudioProcessingState.ready,
      playing: _playing,
    ));
  }

  // ---- sleep timer ----

  void sleepIn(Duration d) {
    _sleepTimer?.cancel();
    _stopAfterChunk = false;
    sleep.value = SleepState(SleepMode.timer, DateTime.now().add(d));
    // When time is up, finish the current paragraph and then stop.
    _sleepTimer = Timer(d, () {
      if (_playing) {
        _stopAfterChunk = true;
      } else {
        cancelSleep();
      }
    });
  }

  void sleepAtChapterEnd() {
    _sleepTimer?.cancel();
    _stopAfterChunk = false;
    sleep.value = const SleepState(SleepMode.chapterEnd);
  }

  void cancelSleep() {
    _sleepTimer?.cancel();
    _stopAfterChunk = false;
    sleep.value = const SleepState(SleepMode.off);
  }

  // ---- audio export ----

  /// Renders [text] to a WAV file with the current voice and returns its bytes.
  Future<Uint8List?> renderWav(String text, String tmpPath) async {
    await init();
    await _tts.awaitSynthCompletion(true);
    final f = File(tmpPath);
    if (f.existsSync()) f.deleteSync();
    try {
      await _tts
          .synthesizeToFile(applyReplacements(text, settings.replacements), tmpPath, true)
          .timeout(Duration(seconds: 45 + text.length ~/ 15));
    } on TimeoutException {
      // Clears the plugin's "busy" flag so the next attempt isn't ignored.
      await _tts.stop().catchError((Object _) => null);
      throw Exception('The phone\'s speech engine (${engineLabel(settings.ttsEngine)}) did not finish making the audio. '
          'Try another engine or a downloaded voice under Voice → Phone, or use a Google voice.');
    }
    // Some engines report completion a moment before the file is fully written.
    for (var i = 0; i < 20 && (!f.existsSync() || f.lengthSync() < 44); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (!f.existsSync()) return null;
    final bytes = await f.readAsBytes();
    f.deleteSync();
    return bytes;
  }
}
