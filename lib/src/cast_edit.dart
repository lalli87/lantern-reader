import 'package:flutter/material.dart';

import 'app.dart';
import 'characters.dart';

/// Edit one character: name, gender, age and voice (with a preview), merge into another character, or remove.
/// Returns true when something changed.
class CastEditScreen extends StatefulWidget {
  final CastMember member;
  final List<CastMember> cast;
  const CastEditScreen({super.key, required this.member, required this.cast});
  @override
  State<CastEditScreen> createState() => _CastEditScreenState();
}

class _CastEditScreenState extends State<CastEditScreen> {
  late final TextEditingController _name = TextEditingController(text: widget.member.name);
  late String _gender = widget.member.gender, _age = widget.member.age;
  late String? _voice = widget.member.voice;
  bool _all = false;
  String? _previewing;

  CastMember get m => widget.member;
  List<CastMember> get others => widget.cast.where((c) => c.id != m.id).toList();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _setGender(String g) {
    setState(() {
      _gender = g;
      // A voice of the other gender no longer fits: pick one that does (unknown keeps the choice).
      if (g != 'unknown' && _voice != null && voiceGender(_voice!) != g) {
        _voice = pickVoice(g, _age, others, narratorName(settings) ?? settings.cloudTtsVoice);
      }
    });
  }

  Future<void> _preview(String? voice) async {
    setState(() => _previewing = voice ?? '');
    final who = CastMember(bookId: m.bookId, name: _name.text, gender: _gender, age: _age);
    await narrator.preview('“My name is ${_name.text.trim().isEmpty ? m.name : _name.text.trim()}. Remember it well.”',
        voice: voice, style: voice == null ? '' : dialogueStyle(who));
    if (mounted) setState(() => _previewing = null);
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return toast(context, 'Give the character a name.');
    if (name != m.name && !m.aliases.contains(m.name)) m.aliases = [...m.aliases, m.name];
    m
      ..name = name
      ..aliases = m.aliases.where((a) => a.toLowerCase() != name.toLowerCase()).toList()
      ..gender = _gender
      ..age = _age
      ..style = styleForAge(_age)
      ..voice = _voice
      ..userSet = true;
    await Cast.save(m);
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _merge() async {
    final into = await showDialog<CastMember>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('${m.name} is the same person as…'),
        children: [
          for (final c in others)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, c),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(c.aliases.isEmpty ? c.name : '${c.name}  (also ${c.aliases.take(2).join(', ')})'),
              ),
            ),
        ],
      ),
    );
    if (into == null || !mounted) return;
    if (!await confirm(context, 'Merge ${m.name} into ${into.name}?',
        '"${m.name}" becomes another name for ${into.name}, and all of ${m.name}\'s lines are read in ${into.name}\'s voice.',
        ok: 'Merge')) {
      return;
    }
    await Cast.merge(m, into);
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _remove() async {
    if (!await confirm(context, 'Remove ${m.name}?', 'Their lines will be read by the narrator.', ok: 'Remove')) return;
    await Cast.delete(m.id!);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme, cs = Theme.of(context).colorScheme;
    final narratorVoice = narratorName(settings) ?? settings.cloudTtsVoice;
    final cantPreview = characterVoicesUnavailable(settings);
    final pool = _all || _gender == 'unknown'
        ? [...femaleVoices, ...maleVoices]
        : (_gender == 'female' ? femaleVoices : maleVoices);
    final usedBy = <String, List<String>>{};
    for (final c in others) {
      if (c.voice != null) (usedBy[c.voice!] ??= []).add(c.name);
    }

    Widget voiceRow(String? v) {
      final isNarrator = v == narratorVoice;
      final users = v == null ? const <String>[] : (usedBy[v] ?? const <String>[]);
      final hint = v == null
          ? 'Read like the rest of the story'
          : [
              voiceGender(v),
              if (isNarrator) 'the narrator',
              if (users.isNotEmpty) 'also ${users.take(2).join(', ')}${users.length > 2 ? '…' : ''}',
            ].join(' · ');
      return RadioListTile<String?>(
        contentPadding: EdgeInsets.zero,
        value: v,
        enabled: !isNarrator,
        title: Text(v ?? 'Narrator\'s voice'),
        subtitle: Text(hint),
        secondary: IconButton(
          tooltip: 'Listen',
          icon: _previewing == (v ?? '')
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.play_circle_outline),
          onPressed: cantPreview != null || _previewing != null ? null : () => _preview(v),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(m.name, overflow: TextOverflow.ellipsis),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder())),
        if (m.aliases.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Also called ${m.aliases.join(', ')}', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          ),
        const SizedBox(height: 16),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'male', label: Text('Male'), icon: Icon(Icons.face)),
            ButtonSegment(value: 'female', label: Text('Female'), icon: Icon(Icons.face_3)),
            ButtonSegment(value: 'unknown', label: Text('Unknown')),
          ],
          selected: {_gender},
          onSelectionChanged: (v) => _setGender(v.first),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _age,
          decoration: const InputDecoration(labelText: 'Age', border: OutlineInputBorder()),
          items: [for (final a in castAges) DropdownMenuItem(value: a, child: Text(a))],
          onChanged: (v) => setState(() => _age = v ?? 'unknown'),
        ),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: Text('Voice', style: tt.titleMedium)),
          if (_gender != 'unknown')
            FilterChip(label: const Text('All voices'), selected: _all, onSelected: (v) => setState(() => _all = v)),
        ]),
        if (cantPreview != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('To listen to the voices: ${cantPreview.toLowerCase()}.', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          ),
        RadioGroup<String?>(
          groupValue: _voice,
          onChanged: (x) => setState(() => _voice = x),
          child: Column(children: [
            voiceRow(null),
            for (final v in pool) voiceRow(v),
            if (_voice != null && !pool.contains(_voice)) voiceRow(_voice),
          ]),
        ),
        const Divider(height: 32),
        if (others.isNotEmpty)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.merge_type),
            title: const Text('Same person as another character…'),
            subtitle: const Text('Merge them into one, keeping all their lines'),
            onTap: _merge,
          ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.person_remove_outlined, color: cs.error),
          title: Text('Remove from the cast', style: TextStyle(color: cs.error)),
          onTap: _remove,
        ),
      ]),
    );
  }
}
