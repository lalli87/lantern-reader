import 'package:flutter/services.dart';

import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'app.dart';
import 'text_utils.dart';
import 'updates.dart';
import 'cloud_tts.dart';
import 'drive_sync.dart';
import 'exports.dart';
import 'models.dart';
import 'narration_ui.dart';
import 'reader_widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final s = settings;
        return Scaffold(
          appBar: AppBar(leading: Navigator.canPop(context) ? null : const MenuButton(), title: const Text('Settings')),
          body: ListView(
            children: [
              const _Header('Google Drive sync'),
              const _SyncSection(),
              const _Header('Appearance'),
              _choice(context, Icons.palette_outlined, 'App theme', s.appTheme, const {
                'system': 'Follow phone',
                'light': 'Light',
                'dark': 'Dark',
              }, (v) => s.set('appTheme', v)),
              _switch(
                Icons.play_circle_outline,
                'Open the last book at start',
                'Go straight back to what you were reading',
                s.openLastBook,
                (v) => s.set('openLastBook', v),
              ),
              const _Header('Reading'),
              _switch(
                Icons.auto_stories_outlined,
                'Turn pages instead of scrolling',
                'Tap the left or right edge, or swipe',
                s.paged,
                (v) => s.set('paged', v),
              ),
              _switch(Icons.pin_outlined, 'Show page and chapter numbers', 'In page-turn mode', s.showProgress, (v) => s.set('showProgress', v)),
              _switch(
                Icons.fullscreen,
                'Full screen while reading',
                'Hide the status and navigation bars',
                s.fullScreen,
                (v) => s.set('fullScreen', v),
              ),
              _switch(Icons.lightbulb_outline, 'Keep the screen on', null, s.keepScreenOn, (v) => s.set('keepScreenOn', v)),
              _switch(
                Icons.brightness_6_outlined,
                'Brightness by swipe',
                'Slide up or down along the left edge',
                s.brightnessSwipe,
                (v) => s.set('brightnessSwipe', v),
              ),
              _switch(
                Icons.dark_mode_outlined,
                'Day / night by tap',
                'Tap the top-left corner of the page',
                s.cornerTheme,
                (v) => s.set('cornerTheme', v),
              ),
              _switch(
                Icons.bookmark_add_outlined,
                'Bookmark by tap',
                'Tap the top-right corner of the page',
                s.cornerBookmark,
                (v) => s.set('cornerBookmark', v),
              ),
              _switch(
                Icons.volume_up_outlined,
                'Volume keys turn pages',
                'Off while narration is playing',
                s.volumeKeys,
                (v) => s.set('volumeKeys', v),
              ),
              _switch(
                Icons.spellcheck,
                'Mark glossary words in the text',
                'Tap a marked word to see your note',
                s.markGlossary,
                (v) => s.set('markGlossary', v),
              ),
              ListTile(
                leading: const Icon(Icons.font_download_outlined),
                title: const Text('My fonts'),
                subtitle: Text(s.userFonts.isEmpty ? 'Add your own .ttf or .otf fonts' : s.userFonts.map((f) => f['name']).join(', ')),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _FontsScreen())),
              ),
              const _Header('Narration'),
              ListTile(
                leading: const Icon(Icons.record_voice_over_outlined),
                title: const Text('Voice'),
                subtitle: Text(
                  '${switch (s.voiceSource) {
                    voiceGoogle => 'Google Cloud · ${s.googleVoice}',
                    voiceGemini => 'Gemini · ${s.cloudTtsVoice}',
                    _ => '${engineLabel(s.ttsEngine)} · ${s.ttsVoice.isEmpty ? 'default voice' : s.ttsVoice}',
                  }} · ${s.ttsRate.toStringAsFixed(2)}×',
                ),
                onTap: () => showVoicePicker(context),
              ),
              ListTile(
                leading: const Icon(Icons.tune),
                title: const Text('Pitch'),
                subtitle: Slider(
                  value: s.ttsPitch.clamp(0.5, 2.0),
                  min: 0.5,
                  max: 2.0,
                  divisions: 15,
                  label: s.ttsPitch.toStringAsFixed(1),
                  onChanged: (v) => narrator.setPitch(v),
                ),
              ),
              if (Platform.isAndroid) const _BatteryTile(),
              _switch(Icons.playlist_play, 'Continue into the next chapter', null, s.autoNextChapter, (v) => s.set('autoNextChapter', v)),
              _switch(Icons.title, 'Read chapter titles aloud', null, s.readTitles, (v) => s.set('readTitles', v)),
              _switch(
                Icons.directions_car_outlined,
                'Next / previous buttons skip a whole chapter',
                'On headsets, Bluetooth and in the car. Off = skip one paragraph',
                s.skipByChapter,
                (v) => s.set('skipByChapter', v),
              ),
              ListTile(
                leading: const Icon(Icons.abc),
                title: const Text('Pronunciation fixes'),
                subtitle: Text(
                  s.replacements.isEmpty
                      ? 'Teach the voice how to say names and terms'
                      : '${s.replacements.length} rule${s.replacements.length == 1 ? '' : 's'}',
                ),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _ReplacementsScreen())),
              ),
              ListTile(
                leading: const Icon(Icons.cleaning_services_outlined),
                title: const Text('Clear saved voice audio'),
                subtitle: const Text('Natural-voice audio is kept so replays are free and work offline'),
                onTap: () async {
                  final size = await voiceCacheSize();
                  if (!context.mounted) return;
                  if (await confirm(
                    context,
                    'Clear saved voice audio?',
                    '${fmtSize(size).isEmpty ? 'Nothing' : fmtSize(size)} will be freed.',
                    ok: 'Clear',
                  )) {
                    await clearVoiceCache();
                  }
                },
              ),
              const _Header('AI: translation and Gemini voices'),
              _choice(context, Icons.auto_awesome_outlined, 'Translate with', s.aiProvider, const {
                'gemini': 'Google Gemini',
                'claude': 'Anthropic Claude',
              }, (v) => s.set('aiProvider', v)),
              _text(context, Icons.language, 'Translate into', s.targetLang, (v) => s.set('targetLang', v), hint: 'English'),
              _text(
                context,
                Icons.key,
                'Gemini API key',
                s.geminiKey.isEmpty ? 'Not set' : '•••• ${_tail(s.geminiKey)}',
                (v) => s.setSecret('geminiKey', v.trim()),
                initial: s.geminiKey,
                secret: true,
                help: 'Create a free key at aistudio.google.com. It is stored only on this phone and is never included in backups.',
              ),
              _text(context, Icons.memory, 'Gemini model', s.geminiModel, (v) => s.set('geminiModel', v.trim())),
              _text(
                context,
                Icons.key,
                'Claude API key',
                s.claudeKey.isEmpty ? 'Not set' : '•••• ${_tail(s.claudeKey)}',
                (v) => s.setSecret('claudeKey', v.trim()),
                initial: s.claudeKey,
                secret: true,
                help: 'Create a key at console.anthropic.com. It is stored only on this phone and is never included in backups.',
              ),
              _text(context, Icons.memory, 'Claude model', s.claudeModel, (v) => s.set('claudeModel', v.trim())),
              _text(context, Icons.graphic_eq, 'Gemini voice model', s.cloudTtsModel, (v) => s.set('cloudTtsModel', v.trim())),
              _text(
                context,
                Icons.person_outline,
                'Gemini voice name',
                s.cloudTtsVoice,
                (v) => s.set('cloudTtsVoice', v.trim()),
                help: 'For example Charon, Kore, Puck, Aoede, Fenrir or Leda.',
              ),
              _text(
                context,
                Icons.theater_comedy_outlined,
                'Gemini reading style',
                s.cloudTtsStyle,
                (v) => s.set('cloudTtsStyle', v.trim()),
                help: 'A short direction placed before the text, such as how calm or lively the reading should be.',
              ),
              const _Header('Web'),
              _text(context, Icons.home_outlined, 'Start page', s.homeUrl, (v) => s.set('homeUrl', v.trim())),
              _switch(Icons.hide_image_outlined, 'Text only', 'Hide images and video in the Web tab', s.blockMedia, (v) => s.set('blockMedia', v)),
              _text(
                context,
                Icons.search,
                'Web search address',
                s.searchUrl,
                (v) => s.set('searchUrl', v.trim()),
                help: 'Use %s where the search words go.',
              ),
              _text(
                context,
                Icons.menu_book_outlined,
                'Dictionary address',
                s.dictUrl,
                (v) => s.set('dictUrl', v.trim()),
                help: 'Use %s where the word goes.',
              ),
              const _Header('Backup'),
              ListTile(
                leading: const Icon(Icons.backup_outlined),
                title: const Text('Back up library'),
                subtitle: const Text('Books, progress, bookmarks, highlights, glossary, fonts and settings in one file'),
                onTap: () async {
                  try {
                    final bytes = await createBackup();
                    final d = DateTime.now();
                    final name = 'LanternReader-${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}.zip';
                    if (context.mounted) await offerFile(context, name, bytes);
                  } catch (e) {
                    if (context.mounted) toast(context, 'Backup failed: $e');
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings_backup_restore),
                title: const Text('Restore from a backup'),
                subtitle: const Text('Replaces everything currently in the app'),
                onTap: () async {
                  final x = await openFile();
                  if (x == null || !context.mounted) return;
                  if (!await confirm(
                    context,
                    'Restore this backup?',
                    'Your current library, notes and settings will be replaced by the contents of ${x.name}.',
                    ok: 'Restore',
                    danger: true,
                  )) {
                    return;
                  }
                  try {
                    await narrator.stop();
                    await restoreBackup(await x.readAsBytes());
                    if (context.mounted) toast(context, 'Library restored.');
                  } catch (e) {
                    if (context.mounted) toast(context, e is FormatException ? e.message : 'Restore failed: $e');
                  }
                },
              ),
              const _Header('About'),
              FutureBuilder<AppVersion>(
                future: AppVersion.get(),
                builder: (context, snap) {
                  final v = snap.data;
                  return ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: Text('Lantern Reader ${v?.label ?? ''}'.trim()),
                    subtitle: const Text('Open-source licences'),
                    onTap: () => showLicensePage(
                      context: context,
                      applicationName: 'Lantern Reader',
                      applicationVersion: v?.label ?? '',
                      applicationLegalese:
                          'Bundled fonts (Literata, Atkinson Hyperlegible, JetBrains Mono) are used under the SIL Open Font '
                          'License 1.1. Page text detection uses Mozilla Readability under the Apache License 2.0.',
                    ),
                  );
                },
              ),
              _UpdateTile(),
              _switch(
                Icons.update,
                'Check automatically',
                'Look for a new version once a day when the app opens',
                s.autoUpdateCheck,
                (v) => s.set('autoUpdateCheck', v),
              ),
              ListTile(
                leading: const Icon(Icons.new_releases_outlined),
                title: const Text('All versions and release notes'),
                subtitle: const Text('github.com/$githubRepo/releases'),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () => openReleasesPage(context),
              ),
              if (s.skippedVersion.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.undo),
                  title: Text('Stop skipping version ${s.skippedVersion}'),
                  subtitle: const Text('Show the update prompt for it again'),
                  onTap: () => s.set('skippedVersion', ''),
                ),
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }

  static String _tail(String k) => k.length <= 4 ? k : k.substring(k.length - 4);

  Widget _switch(IconData icon, String title, String? sub, bool value, ValueChanged<bool> onChanged) =>
      SwitchListTile(secondary: Icon(icon), title: Text(title), subtitle: sub == null ? null : Text(sub), value: value, onChanged: onChanged);

  Widget _choice(BuildContext context, IconData icon, String title, String value, Map<String, String> options, ValueChanged<String> onChanged) =>
      ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(options[value] ?? value),
        onTap: () async {
          final v = await showDialog<String>(
            context: context,
            builder: (c) => SimpleDialog(
              title: Text(title),
              children: [
                for (final e in options.entries)
                  ListTile(
                    leading: Icon(e.key == value ? Icons.radio_button_checked : Icons.radio_button_off),
                    title: Text(e.value),
                    onTap: () => Navigator.pop(c, e.key),
                  ),
              ],
            ),
          );
          if (v != null) onChanged(v);
        },
      );

  Widget _text(
    BuildContext context,
    IconData icon,
    String title,
    String shown,
    ValueChanged<String> onChanged, {
    String? initial,
    String? hint,
    String? help,
    bool secret = false,
  }) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(shown, maxLines: 2, overflow: TextOverflow.ellipsis),
    onTap: () async {
      final v = await promptText(context, title, initial: initial ?? shown, hint: hint, help: help, secret: secret);
      if (v != null) onChanged(v);
    },
  );
}

/// Sign-in and status for Google Drive sync (see drive_sync.dart).
class _SyncSection extends StatelessWidget {
  const _SyncSection();

  String _ago(int t) {
    if (t == 0) return 'not yet';
    final m = (nowMs() - t) ~/ 60000;
    return m < 1
        ? 'just now'
        : m < 60
        ? '$m min ago'
        : m < 1440
        ? '${m ~/ 60} h ago'
        : '${m ~/ 1440} d ago';
  }

  Future<void> _do(BuildContext context, Future<SyncStats?> Function() f) async {
    try {
      final r = await f();
      if (r != null && context.mounted) toast(context, 'Synced: $r.');
    } catch (e) {
      if (!context.mounted) return;
      // Long, copyable message: sign-in problems include the signing key to compare in Google Cloud.
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Google Drive sync'),
          content: SingleChildScrollView(child: SelectableText('$e'.replaceFirst('Exception: ', ''))),
          actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: driveSync,
    builder: (context, _) {
      final d = driveSync;
      final tiles = <Widget>[];
      if (!d.signedIn) {
        tiles.add(
          ListTile(
            leading: const Icon(Icons.cloud_outlined),
            title: const Text('Sign in with Google'),
            subtitle: const Text(
              'Keep books and reading positions in sync with the web version and other devices, '
              'through a "Lantern Reader" folder in your Google Drive',
            ),
            onTap: () => _do(context, d.signIn),
          ),
        );
      } else {
        tiles.add(
          ListTile(
            leading: d.busy
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4))
                : Icon(d.paused || d.error.isNotEmpty ? Icons.cloud_off_outlined : Icons.cloud_done_outlined),
            title: Text(d.email),
            subtitle: Text(
              d.busy
                  ? 'Syncing…'
                  : d.paused
                  ? 'Paused: tap to sign in again'
                  : d.error.isNotEmpty
                  ? d.error
                  : 'Last synced ${_ago(d.lastSync)}. Tap to sync now',
            ),
            onTap: d.busy ? null : () => _do(context, () => d.paused ? d.signIn() : d.run(interactive: true)),
          ),
        );
        tiles.add(
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            subtitle: const Text('Books stay on this phone'),
            onTap: () => d.signOut(),
          ),
        );
      }
      if (buildGoogleClientId.isEmpty || settings.googleClientId.isNotEmpty) {
        tiles.add(
          ListTile(
            leading: const Icon(Icons.vpn_key_outlined),
            title: const Text('OAuth client ID'),
            subtitle: Text(settings.googleClientId.isEmpty ? 'Not set: needed for Google sign-in' : settings.googleClientId),
            onTap: () async {
              final v = await promptText(context, 'OAuth client ID', hint: '…apps.googleusercontent.com', initial: settings.googleClientId);
              if (v != null) settings.set('googleClientId', v.trim());
            },
          ),
        );
      }
      return Column(children: tiles);
    },
  );
}

class _Header extends StatelessWidget {
  final String text;
  const _Header(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 22, 16, 6),
    child: Text(
      text,
      style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700, fontSize: 13.5),
    ),
  );
}

class _FontsScreen extends StatelessWidget {
  const _FontsScreen();
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: settings,
    builder: (context, _) {
      final fonts = settings.userFonts;
      return Scaffold(
        appBar: AppBar(title: const Text('My fonts')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => addUserFont(context),
          icon: const Icon(Icons.add),
          label: const Text('Add font file'),
        ),
        body: fonts.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('Add a .ttf or .otf file to read in your own font.', textAlign: TextAlign.center),
                ),
              )
            : ListView(
                children: [
                  for (final f in fonts)
                    ListTile(
                      title: Text(f['name'] ?? '', style: TextStyle(fontFamily: f['name'], fontSize: 18)),
                      subtitle: Text('The quick brown fox jumps over the lazy dog', style: TextStyle(fontFamily: f['name'])),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () {
                          try {
                            File(p.join(fontsDir, f['file'] ?? '')).deleteSync();
                          } catch (_) {}
                          settings.set('userFonts', fonts.where((x) => x['name'] != f['name']).toList());
                          if (settings.fontFamily == f['name']) settings.set('fontFamily', 'Literata');
                        },
                      ),
                    ),
                ],
              ),
      );
    },
  );
}

class _ReplacementsScreen extends StatelessWidget {
  const _ReplacementsScreen();

  Future<void> _edit(BuildContext context, [int? index]) async {
    final rules = settings.replacements;
    final from = TextEditingController(text: index == null ? '' : rules[index][0]);
    final to = TextEditingController(text: index == null ? '' : rules[index][1]);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(index == null ? 'New rule' : 'Edit rule'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: from,
              decoration: const InputDecoration(labelText: 'When the text says', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: to,
              decoration: const InputDecoration(labelText: 'Say this instead', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true || from.text.trim().isEmpty) return;
    final rule = [from.text.trim(), to.text.trim()];
    index == null ? rules.add(rule) : rules[index] = rule;
    settings.set('replacements', rules);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: settings,
    builder: (context, _) {
      final rules = settings.replacements;
      return Scaffold(
        appBar: AppBar(title: const Text('Pronunciation fixes')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _edit(context),
          icon: const Icon(Icons.add),
          label: const Text('Add rule'),
        ),
        body: rules.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'If the voice mispronounces a name or term, add a rule here. For example: when the text says “Xiao Yan”, say “Shao Yen”. '
                    'The text on screen is not changed.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView(
                children: [
                  for (var i = 0; i < rules.length; i++)
                    ListTile(
                      title: Text('${rules[i][0]}  →  ${rules[i][1]}'),
                      onTap: () => _edit(context, i),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => settings.set('replacements', [...rules]..removeAt(i)),
                      ),
                    ),
                ],
              ),
      );
    },
  );
}

/// "Check for updates" row: shows when the last check ran and whether a newer version was found.
class _UpdateTile extends StatefulWidget {
  @override
  State<_UpdateTile> createState() => _UpdateTileState();
}

class _UpdateTileState extends State<_UpdateTile> {
  bool _checking = false;
  String _current = '';

  @override
  void initState() {
    super.initState();
    AppVersion.get().then((v) {
      if (mounted) setState(() => _current = v.version);
    });
  }

  String _subtitle() {
    final last = settings.lastUpdateCheck;
    if (last == 0) return 'Never checked';
    final known = settings.latestKnownVersion;
    if (known.isNotEmpty && _current.isNotEmpty && compareVersions(known, _current) > 0) return 'Version $known is available';
    final d = DateTime.fromMillisecondsSinceEpoch(last);
    final ago = DateTime.now().difference(d);
    final when = ago.inMinutes < 1
        ? 'just now'
        : ago.inHours < 1
        ? '${ago.inMinutes} min ago'
        : ago.inDays < 1
        ? '${ago.inHours} h ago'
        : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return 'Up to date · checked $when';
  }

  @override
  Widget build(BuildContext context) => ListTile(
    leading: _checking
        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
        : const Icon(Icons.system_update_outlined),
    title: const Text('Check for updates'),
    subtitle: Text(_subtitle()),
    onTap: _checking
        ? null
        : () async {
            setState(() => _checking = true);
            await checkForUpdates(context, manual: true);
            if (mounted) setState(() => _checking = false);
          },
  );
}

/// Samsung and other phones restrict apps in the background unless battery use is "Unrestricted".
class _BatteryTile extends StatefulWidget {
  const _BatteryTile();
  @override
  State<_BatteryTile> createState() => _BatteryTileState();
}

class _BatteryTileState extends State<_BatteryTile> with WidgetsBindingObserver {
  static const _ch = MethodChannel('lantern/audio');
  bool? _ok;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    try {
      final v = await _ch.invokeMethod<bool>('batteryUnrestricted');
      if (mounted) setState(() => _ok = v);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(Icons.battery_charging_full, color: _ok == false ? cs.error : null),
      title: const Text('Keep listening with the screen off'),
      subtitle: Text(_ok == true ? 'Battery use is Unrestricted.' : 'Tap, then Battery → Unrestricted. Recommended for Google and Gemini voices.'),
      onTap: () => _ch.invokeMethod('openBatterySettings').catchError((Object _) => null),
    );
  }
}
