import 'dart:convert';

import 'package:flutter/material.dart';

import 'db.dart';

/// A reading colour scheme.
class ReaderTheme {
  final String id, label;
  final Color bg, fg, accent;
  final bool dark;
  const ReaderTheme(this.id, this.label, this.bg, this.fg, this.accent, this.dark);
}

const readerThemes = <ReaderTheme>[
  ReaderTheme('day', 'Day', Color(0xFFFCFBF8), Color(0xFF1F1D1A), Color(0xFFB5541C), false),
  ReaderTheme('sepia', 'Sepia', Color(0xFFF3E7D0), Color(0xFF45341F), Color(0xFF9A5A1E), false),
  ReaderTheme('dusk', 'Dusk', Color(0xFF2B2A33), Color(0xFFD9D6E0), Color(0xFFE5A15A), true),
  ReaderTheme('night', 'Night', Color(0xFF000000), Color(0xFFB8B4AC), Color(0xFFE08A4A), true),
  ReaderTheme('console', 'Console', Color(0xFF07120A), Color(0xFF6FE38A), Color(0xFFB7F5C3), true),
];

/// Highlight colours offered for quotes.
const quoteColors = <Color>[
  Color(0xFFFFD54F),
  Color(0xFFFF8A65),
  Color(0xFF81C784),
  Color(0xFF64B5F6),
  Color(0xFFBA68C8),
  Color(0xFFF06292),
];

const bundledFonts = ['Literata', 'Atkinson Hyperlegible', 'JetBrains Mono'];
const systemFonts = {'system': 'System default', 'serif': 'System serif', 'monospace': 'System mono'};

/// All user preferences, persisted as one JSON blob. API keys live in a separate blob that is
/// left out of backups.
class Settings extends ChangeNotifier {
  Map<String, dynamic> _m = {};
  Map<String, dynamic> _secrets = {};

  Future<void> load() async {
    _m = await Db.kvJson('settings');
    _secrets = await Db.kvJson('secrets');
    notifyListeners();
  }

  void set(String k, Object? v) {
    _m[k] = v;
    notifyListeners();
    Db.kvSet('settings', jsonEncode(_m));
  }

  void setSecret(String k, String v) {
    _secrets[k] = v;
    notifyListeners();
    Db.kvSet('secrets', jsonEncode(_secrets));
  }

  String _s(String k, String d) => _m[k] is String ? _m[k] as String : d;
  bool _b(String k, bool d) => _m[k] is bool ? _m[k] as bool : d;
  double _d(String k, double d) => _m[k] is num ? (_m[k] as num).toDouble() : d;
  int _i(String k, int d) => _m[k] is num ? (_m[k] as num).toInt() : d;

  // ---- app ----
  String get appTheme => _s('appTheme', 'system'); // system | light | dark
  String get libraryView => _s('libraryView', 'list'); // list | compact | grid
  String get sortBy => _s('sortBy', 'recent'); // recent | title | author | added | size | format
  bool get sortAsc => _b('sortAsc', false);
  bool get openLastBook => _b('openLastBook', false);
  bool get colZoomHintShown => _b('colZoomHintShown', false); // the column-view tip was shown once
  bool get pdfPageView => _b('pdfPageView', true); // PDFs open on the original pages when the file was kept
  bool get autoUpdateCheck => _b('autoUpdateCheck', true);
  int get lastUpdateCheck => _i('lastUpdateCheck', 0);
  String get latestKnownVersion => _s('latestKnownVersion', '');
  String get skippedVersion => _s('skippedVersion', '');

  // ---- reader ----
  String get themeId => _s('themeId', 'day');
  String get lastLightTheme => _s('lastLightTheme', 'day');
  String get lastDarkTheme => _s('lastDarkTheme', 'night');
  ReaderTheme get readerTheme => readerThemes.firstWhere((t) => t.id == themeId, orElse: () => readerThemes.first);
  String get fontFamily => _s('fontFamily', 'Literata');
  double get fontSize => _d('fontSize', 19);
  bool get bold => _b('bold', false);
  double get lineHeight => _d('lineHeight', 1.55);
  double get margin => _d('margin', 22);
  double get paraSpacing => _d('paraSpacing', 0.7);
  bool get justify => _b('justify', false);
  bool get paged => _b('paged', false);
  int get orientation => _i('orientation', 0); // 0 auto, 1 portrait, 2 landscape
  bool get keepScreenOn => _b('keepScreenOn', true);
  bool get fullScreen => _b('fullScreen', true);
  bool get brightnessSwipe => _b('brightnessSwipe', true);
  bool get cornerTheme => _b('cornerTheme', true);
  bool get cornerBookmark => _b('cornerBookmark', true);
  bool get volumeKeys => _b('volumeKeys', false);
  bool get showProgress => _b('showProgress', true);
  bool get markGlossary => _b('markGlossary', true);
  int get quoteColor => _i('quoteColor', 0);

  void setReaderTheme(String id) {
    final t = readerThemes.firstWhere((t) => t.id == id, orElse: () => readerThemes.first);
    _m[t.dark ? 'lastDarkTheme' : 'lastLightTheme'] = t.id;
    set('themeId', t.id);
  }

  /// Flips between the last light and last dark reading theme.
  void toggleDayNight() => setReaderTheme(readerTheme.dark ? lastLightTheme : lastDarkTheme);

  List<Map<String, String>> get userFonts =>
      ((_m['userFonts'] as List?) ?? []).map((e) => Map<String, String>.from(e as Map)).toList();

  // ---- narration ----
  String get ttsEngine => _s('ttsEngine', '');
  String get ttsVoice => _s('ttsVoice', '');
  String get ttsLocale => _s('ttsLocale', '');
  double get ttsRate => _d('ttsRate', 1.0);
  double get ttsPitch => _d('ttsPitch', 1.0);
  bool get autoNextChapter => _b('autoNextChapter', true);
  bool get readTitles => _b('readTitles', true);
  bool get skipByChapter => _b('skipByChapter', false);
  bool get followNarration => _b('followNarration', true);

  /// Speed remembered per voice, so switching voices restores the speed you liked for each.
  Map<String, dynamic> get voiceRates => Map<String, dynamic>.from((_m['voiceRates'] as Map?) ?? {});

  /// Pronunciation fixes applied before text is spoken: [[from, to], ...].
  List<List<String>> get replacements =>
      ((_m['replacements'] as List?) ?? []).map((e) => List<String>.from(e as List)).toList();

  // ---- natural (cloud) voices ----
  String get voiceSource => _s('voiceSource', 'device'); // device | google | gemini
  String get googleVoice => _s('googleVoice', 'en-US-Chirp3-HD-Charon');
  String get googleTtsKey => (_secrets['googleTtsKey'] as String?) ?? '';

  // ---- AI ----
  String get aiProvider => _s('aiProvider', 'gemini'); // gemini | claude
  String get geminiModel => _s('geminiModel', 'gemini-3.8-flash');
  String get claudeModel => _s('claudeModel', 'claude-haiku-5-5');
  String get targetLang => _s('targetLang', 'English');
  String get cloudTtsModel => _s('cloudTtsModel', 'gemini-3.1-flash-tts-preview');
  String get cloudTtsVoice => _s('cloudTtsVoice', 'Charon');
  String get cloudTtsStyle => _s('cloudTtsStyle', 'Read this like a calm, warm audiobook narrator:');
  String get geminiKey => (_secrets['geminiKey'] as String?) ?? '';
  String get claudeKey => (_secrets['claudeKey'] as String?) ?? '';

  // ---- browser ----
  String get homeUrl => _s('homeUrl', 'https://www.wuxiaworld.com');
  String get syncEmail => _s('syncEmail', ''); // Google account used for Drive sync ('' = not signed in)
  String get googleClientId => _s('googleClientId', ''); // overrides the build's OAuth web client ID
  bool get blockMedia => _b('blockMedia', true);
  String get searchUrl => _s('searchUrl', 'https://www.google.com/search?q=%s');
  String get dictUrl => _s('dictUrl', 'https://www.google.com/search?q=define+%s');

  /// Optional CSS selector per site for where the story text lives: {host: selector}.
  Map<String, dynamic> get siteSelectors => Map<String, dynamic>.from((_m['siteSelectors'] as Map?) ?? {});

  /// Which book chapters from each site were last saved into: {host: bookId}.
  Map<String, dynamic> get browserTargets => Map<String, dynamic>.from((_m['browserTargets'] as Map?) ?? {});

  /// Settings JSON for backups (never includes API keys).
  String exportJson() => jsonEncode(_m);
}

/// Text style for reading, from the current settings.
TextStyle readerTextStyle(Settings s, {double scale = 1, bool heading = false}) {
  final t = s.readerTheme;
  final fam = s.fontFamily;
  final sys = fam == 'system';
  return TextStyle(
    fontFamily: sys ? null : fam,
    fontSize: s.fontSize * scale,
    height: heading ? 1.25 : s.lineHeight,
    color: t.fg,
    fontWeight: (heading || s.bold) ? FontWeight.w700 : FontWeight.w400,
    letterSpacing: 0,
  );
}
