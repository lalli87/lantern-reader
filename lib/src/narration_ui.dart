import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'narrator.dart';
import 'cloud_tts.dart';
import 'text_utils.dart';

/// Slim "now playing" bar shown above the navigation bar while a book is loaded in the narrator.
class MiniPlayer extends StatelessWidget {
  final void Function(NarrationState s) onOpen;
  const MiniPlayer({super.key, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<NarrationState>(
      valueListenable: narrator.state,
      builder: (context, s, _) {
        if (!s.active) return const SizedBox.shrink();
        final cs = Theme.of(context).colorScheme;
        return Material(
          color: cs.secondaryContainer,
          child: InkWell(
            onTap: () => onOpen(s),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
              child: Row(children: [
                Icon(Icons.graphic_eq, color: cs.onSecondaryContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(s.chapterTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(s.bookTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                  ]),
                ),
                IconButton(tooltip: 'Back a paragraph', icon: const Icon(Icons.replay), onPressed: narrator.prevPara),
                IconButton(
                  tooltip: s.playing ? 'Pause' : 'Play',
                  icon: Icon(s.playing ? Icons.pause_circle_filled : Icons.play_circle_fill, size: 34),
                  onPressed: narrator.toggle,
                ),
                IconButton(tooltip: 'Stop', icon: const Icon(Icons.close), onPressed: narrator.stop),
              ]),
            ),
          ),
        );
      },
    );
  }
}

Future<void> showNarrationPanel(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const NarrationPanel(),
    );

/// Full narration controls: transport, speed, sleep timer and voice.
class NarrationPanel extends StatefulWidget {
  const NarrationPanel({super.key});
  @override
  State<NarrationPanel> createState() => _NarrationPanelState();
}

class _NarrationPanelState extends State<NarrationPanel> {
  Timer? _tick;
  double? _dragRate;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: Listenable.merge([narrator.state, narrator.sleep, narrator.error, settings]),
      builder: (context, _) {
        final s = narrator.state.value;
        final sl = narrator.sleep.value;
        final rate = _dragRate ?? settings.ttsRate;
        final left = sl.at?.difference(DateTime.now());
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(s.chapterTitle.isEmpty ? 'Nothing playing' : s.chapterTitle,
                  textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
              if (s.bookTitle.isNotEmpty)
                Text(s.bookTitle, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
              if (narrator.error.value != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(narrator.error.value!, textAlign: TextAlign.center, style: TextStyle(color: cs.error)),
                ),
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                IconButton(tooltip: 'Previous chapter', iconSize: 30, icon: const Icon(Icons.skip_previous), onPressed: narrator.prevChapter),
                IconButton(tooltip: 'Back a paragraph', iconSize: 30, icon: const Icon(Icons.fast_rewind), onPressed: narrator.prevPara),
                IconButton.filled(
                  tooltip: s.playing ? 'Pause' : 'Play',
                  iconSize: 44,
                  icon: s.loading && s.playing
                      ? const SizedBox(width: 44, height: 44, child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 3)))
                      : Icon(s.playing ? Icons.pause : Icons.play_arrow),
                  onPressed: s.active ? narrator.toggle : null,
                ),
                IconButton(tooltip: 'Skip a paragraph', iconSize: 30, icon: const Icon(Icons.fast_forward), onPressed: narrator.nextPara),
                IconButton(tooltip: 'Next chapter', iconSize: 30, icon: const Icon(Icons.skip_next), onPressed: narrator.nextChapter),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.speed, size: 20),
                const SizedBox(width: 8),
                const Text('Speed'),
                Expanded(
                  child: Slider(
                    value: rate.clamp(0.1, 4.0),
                    min: 0.1,
                    max: 4.0,
                    divisions: 78,
                    onChanged: (v) => setState(() => _dragRate = v),
                    onChangeEnd: (v) {
                      _dragRate = null;
                      narrator.setRate((v * 20).round() / 20);
                    },
                  ),
                ),
                SizedBox(width: 48, child: Text('${rate.toStringAsFixed(2)}×', textAlign: TextAlign.end)),
              ]),
              Wrap(alignment: WrapAlignment.center, spacing: 6, children: [
                for (final r in const [0.8, 1.0, 1.2, 1.5, 2.0])
                  ActionChip(label: Text('$r×'), onPressed: () => narrator.setRate(r), visualDensity: VisualDensity.compact),
              ]),
              const Divider(height: 28),
              Row(children: [
                const Icon(Icons.bedtime_outlined, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(switch (sl.mode) {
                    SleepMode.off => 'Sleep timer',
                    SleepMode.chapterEnd => 'Stops at the end of this chapter',
                    SleepMode.timer => left == null || left.isNegative
                        ? 'Stopping after this paragraph'
                        : 'Stops in about ${left.inMinutes + 1} min',
                  }),
                ),
                if (sl.mode != SleepMode.off) TextButton(onPressed: narrator.cancelSleep, child: const Text('Cancel')),
              ]),
              const SizedBox(height: 4),
              Wrap(spacing: 6, runSpacing: 2, children: [
                for (final m in const [10, 15, 30, 45, 60, 90])
                  ActionChip(label: Text('$m min'), onPressed: () => narrator.sleepIn(Duration(minutes: m)), visualDensity: VisualDensity.compact),
                ActionChip(
                  label: const Text('End of chapter'),
                  onPressed: narrator.sleepAtChapterEnd,
                  visualDensity: VisualDensity.compact,
                ),
              ]),
              const Divider(height: 28),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.record_voice_over_outlined),
                title: const Text('Voice'),
                subtitle: Text(switch (settings.voiceSource) {
                  voiceGoogle => 'Google Cloud · ${settings.googleVoice}',
                  voiceGemini => 'Gemini · ${settings.cloudTtsVoice}',
                  _ => settings.ttsVoice.isEmpty
                      ? '${engineLabel(settings.ttsEngine)} · default voice'
                      : '${engineLabel(settings.ttsEngine)} · ${settings.ttsVoice}',
                }),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showVoicePicker(context),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.my_location),
                title: const Text('Follow along on screen'),
                value: settings.followNarration,
                onChanged: (v) => settings.set('followNarration', v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.playlist_play),
                title: const Text('Continue into the next chapter'),
                value: settings.autoNextChapter,
                onChanged: (v) => settings.set('autoNextChapter', v),
              ),
            ]),
          ),
        );
      },
    );
  }
}

Future<void> showVoicePicker(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const VoicePicker(),
    );

const geminiVoices = [
  'Charon', 'Kore', 'Puck', 'Aoede', 'Fenrir', 'Leda', 'Orus', 'Zephyr', 'Callirrhoe', 'Autonoe', 'Enceladus',
  'Iapetus', 'Umbriel', 'Algieba', 'Despina', 'Erinome', 'Algenib', 'Rasalgethi', 'Laomedeia', 'Achernar',
  'Alnilam', 'Schedar', 'Gacrux', 'Pulcherrima', 'Achird', 'Zubenelgenubi', 'Vindemiatrix', 'Sadachbia',
  'Sadaltager', 'Sulafat',
];

const _sample = 'The mountain path wound upward through the pines, and somewhere below a bell rang three times.';

/// Chooses where the narration voice comes from (phone, Google Cloud, Gemini) and which voice.
class VoicePicker extends StatefulWidget {
  const VoicePicker({super.key});
  @override
  State<VoicePicker> createState() => _VoicePickerState();
}

class _VoicePickerState extends State<VoicePicker> {
  late String _source = settings.voiceSource;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, scroll) => ListView(controller: scroll, padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
        Text('Voice', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: voiceDevice, label: Text('Phone'), icon: Icon(Icons.phone_android)),
            ButtonSegment(value: voiceGoogle, label: Text('Google'), icon: Icon(Icons.cloud_outlined)),
            ButtonSegment(value: voiceGemini, label: Text('Gemini'), icon: Icon(Icons.auto_awesome_outlined)),
          ],
          selected: {_source},
          showSelectedIcon: false,
          onSelectionChanged: (v) async {
            setState(() => _source = v.first);
            await narrator.setVoiceSource(v.first);
          },
        ),
        const SizedBox(height: 10),
        Text(
          switch (_source) {
            voiceGoogle => 'Google Cloud voices (Chirp 3 HD, Neural2, Studio, WaveNet). Very natural, needs internet and a Google Cloud API key with '
                'the Text-to-Speech API turned on. Usage is billed to your Google Cloud account; audio is cached so replays are free.',
            voiceGemini => 'Gemini voices read with expression and can follow a reading style. Needs internet and your Gemini API key; '
                'usage counts against your key\'s quota.',
            _ => 'Voices installed on this phone. Free and offline. For better quality, download high-quality voices in your phone\'s '
                'Settings → Text-to-speech, or pick a voice marked "needs internet".',
          },
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 14),
        switch (_source) {
          voiceGoogle => const _GoogleVoices(),
          voiceGemini => const _GeminiVoices(),
          _ => const _PhoneVoices(),
        },
      ]),
    );
  }
}

class _PhoneVoices extends StatefulWidget {
  const _PhoneVoices();
  @override
  State<_PhoneVoices> createState() => _PhoneVoicesState();
}

class _PhoneVoicesState extends State<_PhoneVoices> {
  List<String> _engines = [];
  List<Map<String, String>> _voices = [];
  String _lang = 'en';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await narrator.init();
    final e = await narrator.engines();
    final v = await narrator.voices();
    if (!mounted) return;
    setState(() {
      _engines = e;
      _voices = v;
      _loading = false;
      if (settings.ttsLocale.isNotEmpty) _lang = settings.ttsLocale.split(RegExp('[-_]')).first.toLowerCase();
      final langs = _langs();
      if (!langs.contains(_lang) && langs.isNotEmpty) _lang = langs.contains('en') ? 'en' : langs.first;
    });
  }

  List<String> _langs() =>
      (_voices.map((v) => (v['locale'] ?? '').split(RegExp('[-_]')).first.toLowerCase()).where((l) => l.isNotEmpty).toSet().toList()..sort());

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()));
    final cs = Theme.of(context).colorScheme;
    final shown = _voices.where((v) => (v['locale'] ?? '').toLowerCase().startsWith(_lang)).toList()
      ..sort((a, b) {
        // Higher quality and online voices first.
        int score(Map<String, String> v) => (int.tryParse(v['quality'] ?? '') ?? 0) + (v['network_required'] == '1' ? 1000 : 0);
        return score(b).compareTo(score(a));
      });
    final langs = _langs();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (_engines.isNotEmpty)
        DropdownButtonFormField<String>(
          key: ValueKey('eng-${settings.ttsEngine}'),
          initialValue: _engines.contains(settings.ttsEngine) ? settings.ttsEngine : '',
          decoration: const InputDecoration(labelText: 'Engine', border: OutlineInputBorder(), isDense: true),
          items: [
            const DropdownMenuItem(value: '', child: Text('System default')),
            for (final e in _engines) DropdownMenuItem(value: e, child: Text('${engineLabel(e)}  ($e)', overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) async {
            setState(() => _loading = true);
            await narrator.chooseEngine(v ?? '');
            await _load();
          },
        ),
      const SizedBox(height: 12),
      if (langs.isNotEmpty)
        DropdownButtonFormField<String>(
          key: ValueKey('lang-$_lang-${langs.length}'),
          initialValue: _lang,
          decoration: const InputDecoration(labelText: 'Language', border: OutlineInputBorder(), isDense: true),
          items: [for (final l in langs) DropdownMenuItem(value: l, child: Text(l))],
          onChanged: (v) => setState(() => _lang = v ?? _lang),
        ),
      const SizedBox(height: 8),
      if (shown.isEmpty)
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text('No voices were reported by this engine.', textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
        ),
      for (final v in shown)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(settings.ttsVoice == v['name'] ? Icons.radio_button_checked : Icons.radio_button_off,
              color: settings.ttsVoice == v['name'] ? cs.primary : null),
          title: Text(v['name'] ?? ''),
          subtitle: Text([
            v['locale'] ?? '',
            if ((v['quality'] ?? '').isNotEmpty) 'quality ${v['quality']}',
            if (v['network_required'] == '1') 'needs internet',
            if ((v['features'] ?? '').contains('notInstalled')) 'not downloaded',
          ].join(' · ')),
          onTap: () async {
            await narrator.chooseVoice(v['name'] ?? '', v['locale'] ?? '');
            if (!narrator.isPlaying) await narrator.preview(_sample);
            if (mounted) setState(() {});
          },
        ),
    ]);
  }
}

Future<void> _editKey(BuildContext context, String title, String current, void Function(String) save, String help) async {
  final v = await promptText(context, title, initial: current, secret: true, help: help);
  if (v != null) save(v.trim());
}

class _GoogleVoices extends StatefulWidget {
  const _GoogleVoices();
  @override
  State<_GoogleVoices> createState() => _GoogleVoicesState();
}

class _GoogleVoicesState extends State<_GoogleVoices> {
  List<GoogleVoice> _voices = [];
  String _lang = 'en-US', _kind = 'Chirp3-HD';
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _lang = settings.googleVoice.split('-').take(2).join('-');
    _kind = googleVoiceKind(settings.googleVoice);
    _load();
  }

  Future<void> _load() async {
    if (settings.googleTtsKey.isEmpty && settings.geminiKey.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final v = await googleVoices(settings);
      if (mounted) setState(() => _voices = v);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasKey = settings.googleTtsKey.isNotEmpty || settings.geminiKey.isNotEmpty;
    final langs = (_voices.expand((v) => v.languages).toSet().toList()..sort());
    final kinds = googleVoiceKinds.where((k) => _voices.any((v) => v.kind == k && v.languages.contains(_lang))).toList();
    final shown = _voices.where((v) => v.languages.contains(_lang) && (kinds.isEmpty || v.kind == _kind)).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.key),
        title: const Text('Google Cloud API key'),
        subtitle: Text(settings.googleTtsKey.isNotEmpty
            ? 'Set'
            : (settings.geminiKey.isNotEmpty ? 'Using your Gemini key (works if Text-to-Speech is enabled in the same project)' : 'Not set')),
        onTap: () => _editKey(context, 'Google Cloud API key', settings.googleTtsKey, (v) {
          settings.setSecret('googleTtsKey', v);
          _load();
        }, 'In console.cloud.google.com: enable "Cloud Text-to-Speech API", then APIs & Services → Credentials → Create API key. '
            'Stored only on this phone.'),
      ),
      if (!hasKey)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text('Add a key to see the voices.', style: TextStyle(color: cs.onSurfaceVariant)),
        ),
      if (_loading) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
      if (_error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(_error!, style: TextStyle(color: cs.error))),
      if (_voices.isNotEmpty) ...[
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          key: ValueKey('glang-$_lang'),
          initialValue: langs.contains(_lang) ? _lang : null,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Language', border: OutlineInputBorder(), isDense: true),
          items: [for (final l in langs) DropdownMenuItem(value: l, child: Text(l))],
          onChanged: (v) => setState(() {
            _lang = v ?? _lang;
            final k = googleVoiceKinds.where((k) => _voices.any((x) => x.kind == k && x.languages.contains(_lang)));
            if (k.isNotEmpty && !k.contains(_kind)) _kind = k.first;
          }),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 4, children: [
          for (final k in kinds) ChoiceChip(label: Text(k), selected: _kind == k, onSelected: (_) => setState(() => _kind = k)),
        ]),
        const SizedBox(height: 6),
        for (final v in shown)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(settings.googleVoice == v.name ? Icons.radio_button_checked : Icons.radio_button_off,
                color: settings.googleVoice == v.name ? cs.primary : null),
            title: Text(v.name.split('-').skip(2).join(' ')),
            subtitle: Text('${v.name} · ${v.gender.toLowerCase()}'),
            onTap: () async {
              settings.set('googleVoice', v.name);
              setState(() {});
              await narrator.cloudVoiceChanged();
              if (!narrator.isPlaying) await narrator.preview(_sample);
            },
          ),
      ],
    ]);
  }
}

class _GeminiVoices extends StatefulWidget {
  const _GeminiVoices();
  @override
  State<_GeminiVoices> createState() => _GeminiVoicesState();
}

class _GeminiVoicesState extends State<_GeminiVoices> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.key),
        title: const Text('Gemini API key'),
        subtitle: Text(settings.geminiKey.isEmpty ? 'Not set' : 'Set'),
        onTap: () => _editKey(context, 'Gemini API key', settings.geminiKey, (v) {
          settings.setSecret('geminiKey', v);
          setState(() {});
        }, 'Create a free key at aistudio.google.com. Stored only on this phone.'),
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.theater_comedy_outlined),
        title: const Text('Reading style'),
        subtitle: Text(settings.cloudTtsStyle.isEmpty ? 'None' : settings.cloudTtsStyle),
        onTap: () async {
          final v = await promptText(context, 'Reading style', initial: settings.cloudTtsStyle, multiline: true,
              help: 'A short direction for the voice, for example "Read like a calm, warm audiobook narrator, slightly slow."');
          if (v == null) return;
          settings.set('cloudTtsStyle', v.trim());
          setState(() {});
          await narrator.cloudVoiceChanged();
        },
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.memory),
        title: const Text('Model'),
        subtitle: Text(settings.cloudTtsModel),
        onTap: () async {
          final v = await promptText(context, 'Gemini voice model', initial: settings.cloudTtsModel);
          if (v == null || v.trim().isEmpty) return;
          settings.set('cloudTtsModel', v.trim());
          setState(() {});
          await narrator.cloudVoiceChanged();
        },
      ),
      const SizedBox(height: 6),
      Text('Voices', style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 6),
      Wrap(spacing: 6, runSpacing: 4, children: [
        for (final v in geminiVoices)
          ChoiceChip(
            label: Text(v),
            selected: settings.cloudTtsVoice == v,
            onSelected: (_) async {
              settings.set('cloudTtsVoice', v);
              setState(() {});
              await narrator.cloudVoiceChanged();
              if (!narrator.isPlaying) await narrator.preview(_sample);
            },
          ),
      ]),
      const SizedBox(height: 8),
      Text('Tap a voice to hear it.', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5)),
    ]);
  }
}

/// One-line description of a book's length for lists.
String listenLabel(int chars) => chars <= 0 ? '' : '≈ ${fmtListenTime(chars, rate: settings.ttsRate)} to listen';
