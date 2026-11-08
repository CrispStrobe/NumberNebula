import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/kompass_content.dart';
import '../services/kompass_store.dart';
import '../widgets/kompass_figure_view.dart';
import 'kompass_ui.dart';
import 'printing/kompass_html_export.dart';

/// Paper transfer uses exactly the versioned task IDs in the printable manifest.
/// Viewing a paper or its solutions consumes exposure, never mastery evidence.
class KompassPaperScreen extends StatefulWidget {
  final KompassPack pack;
  final KompassStore store;
  const KompassPaperScreen(
      {super.key, required this.pack, required this.store});

  @override
  State<KompassPaperScreen> createState() => _KompassPaperScreenState();
}

class _KompassPaperScreenState extends State<KompassPaperScreen> {
  List<Map<String, dynamic>>? _worksheets;
  Map<String, dynamic>? _sheet;
  List<KompassTask> _tasks = [];
  final _html = <String, String>{};
  bool _solutions = false;
  bool _busy = false;
  String? _error;
  bool get _german => Localizations.localeOf(context).languageCode == 'de';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final manifest = jsonDecode(
              await rootBundle.loadString('assets/kompass/print/manifest.json'))
          as Map;
      if (manifest['schemaVersion'] != 1) {
        throw const FormatException('Unsupported paper manifest');
      }
      final sheets = (manifest['worksheets'] as List)
          .map((s) => Map<String, dynamic>.from(s as Map))
          .toList();
      // Preload trusted bundled HTML before a browser download gesture.
      for (final sheet in sheets) {
        for (final group in ['files', 'solutions']) {
          for (final filename in (sheet[group] as Map).values.cast<String>()) {
            if (!RegExp(r'^[a-z_]+\.html$').hasMatch(filename)) {
              throw const FormatException('Invalid paper filename');
            }
            _html[filename] =
                await rootBundle.loadString('assets/kompass/print/$filename');
          }
        }
      }
      if (mounted) {
        setState(() {
          _worksheets = sheets;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = kc(
            _german,
            'Die Druckvorlagen konnten nicht geladen werden.',
            'The printable worksheets could not be loaded.'));
      }
    }
  }

  Future<void> _open(Map<String, dynamic> sheet) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final ids = (sheet['taskIds'] as List).cast<String>();
      final tasks =
          ids.map(widget.pack.taskById).whereType<KompassTask>().toList();
      if (tasks.length != ids.length) {
        throw const FormatException('Unknown worksheet task');
      }
      final session =
          'paper_${sheet['id']}_${DateTime.now().microsecondsSinceEpoch}';
      for (final family in tasks.map((t) => t.familyId).toSet()) {
        await widget.store.markExposed(family, sessionId: session);
      }
      if (mounted) {
        setState(() {
          _sheet = sheet;
          _tasks = tasks;
          _solutions = false;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = kc(
            _german,
            'Die Vorlage konnte nicht geöffnet werden. Bitte versuche es erneut.',
            'The worksheet could not be opened. Please try again.'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy() async {
    final text = StringBuffer(kc(_german, 'KOMPASS 4 – eigene Papierübungen\n',
        'KOMPASS 4 – original paper practice\n'));
    for (var i = 0; i < _tasks.length; i++) {
      final task = _tasks[i];
      text.writeln('${i + 1}. ${kompassText(task.title, _german)}');
      text.writeln(kompassText(task.prompt, _german));
      if (task.figure != null) {
        text.writeln(kompassText(task.figure!['alt'], _german));
      }
      for (final part in task.parts) {
        text.writeln(kompassText(part.prompt, _german));
        for (final option in part.options) {
          text.writeln('□ ${kompassText(option['label'], _german)}');
        }
        text.writeln('________________________________');
      }
      if (_solutions) text.writeln(kompassText(task.solution, _german));
      text.writeln();
    }
    await Clipboard.setData(ClipboardData(text: text.toString()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(kc(
              _german,
              'Aufgabentext kopiert. Die Abbildungen bleiben in der Papieransicht sichtbar.',
              'Worksheet text copied. The figures remain visible in the paper view.'))));
    }
  }

  void _download(bool solutions) {
    final name = (_sheet![solutions ? 'solutions' : 'files']
        as Map)[_german ? 'de' : 'en'] as String;
    downloadKompassHtml(_html[name]!, name);
  }

  @override
  Widget build(BuildContext context) => KompassPage(
        title: kc(_german, 'Auf Papier üben', 'Practise on paper'),
        child: Builder(
            builder: (context) =>
                ListView(padding: const EdgeInsets.all(20), children: [
                  KompassPanel(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(
                            kc(_german, 'Den Lösungsweg selbst aufschreiben',
                                'Write out your own method'),
                            style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 12),
                        Text(kc(
                            _german,
                            'Lege Papier, Stift und Lineal bereit. Wähle einzelne Aufgaben aus dem Übungsheft oder bearbeite den Probelauf mit 45 Minuten Arbeitszeit nach dem Lesen der Anleitung. Lösungen stehen in einem eigenen Heft. Gesehene Papieraufgaben zählen später nicht mehr als neue selbstständige Beobachtungen.',
                            'Have paper, a pencil and a ruler ready. Choose individual activities from the practice booklet, or use the rehearsal for 45 minutes after reading the instructions. Solutions are in a separate booklet. Paper tasks you have seen will no longer count as unseen independent observations.')),
                        if (kIsWeb)
                          Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(kc(
                                  _german,
                                  'Lade das HTML-Heft herunter, öffne es im Browser und wähle Drucken oder Als PDF speichern. Es funktioniert ohne Internet.',
                                  'Download the HTML booklet, open it in a browser, then choose Print or Save as PDF. It works without an internet connection.'))),
                      ])),
                  const SizedBox(height: 16),
                  if (_error != null)
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  if (_worksheets == null && _error == null)
                    const Center(child: CircularProgressIndicator()),
                  if (_worksheets == null && _error != null)
                    TextButton(
                        onPressed: _load,
                        child:
                            Text(kc(_german, 'Erneut versuchen', 'Try again'))),
                  if (_worksheets != null)
                    Wrap(spacing: 12, runSpacing: 12, children: [
                      for (final sheet in _worksheets!)
                        FilledButton.tonal(
                            onPressed: _busy ? null : () => _open(sheet),
                            child: Text(sheet['mode'] == 'rehearsal'
                                ? kc(_german, 'Probelauf öffnen',
                                    'Open paper rehearsal')
                                : kc(_german, 'Übungsheft öffnen',
                                    'Open practice booklet'))),
                    ]),
                  if (_busy) const LinearProgressIndicator(),
                  if (_sheet != null) ...[
                    const SizedBox(height: 16),
                    Wrap(spacing: 12, runSpacing: 12, children: [
                      if (kIsWeb)
                        OutlinedButton.icon(
                            onPressed: () => _download(false),
                            icon: const Icon(Icons.download),
                            label: Text(kc(_german, 'Aufgaben herunterladen',
                                'Download tasks'))),
                      if (kIsWeb)
                        OutlinedButton.icon(
                            onPressed: () => _download(true),
                            icon: const Icon(Icons.download),
                            label: Text(kc(_german, 'Lösungsheft herunterladen',
                                'Download solutions'))),
                      TextButton.icon(
                          onPressed: _copy,
                          icon: const Icon(Icons.copy),
                          label: Text(kc(_german, 'Aufgabentext kopieren',
                              'Copy worksheet text'))),
                    ]),
                    SwitchListTile(
                        value: _solutions,
                        onChanged: (value) =>
                            setState(() => _solutions = value),
                        title: Text(kc(
                            _german,
                            'Lösungen in der Ansicht zeigen',
                            'Show solutions in this view'))),
                    for (var i = 0; i < _tasks.length; i++)
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: KompassPanel(
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                Text(
                                    '${i + 1}. ${kompassText(_tasks[i].title, _german)}',
                                    style:
                                        Theme.of(context).textTheme.titleLarge),
                                const SizedBox(height: 12),
                                SelectableText(
                                    kompassText(_tasks[i].prompt, _german)),
                                if (_tasks[i].figure != null)
                                  KompassFigureView(
                                      figure: _tasks[i].figure!,
                                      german: _german,
                                      plain: true),
                                for (final part in _tasks[i].parts)
                                  Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            SelectableText(kompassText(
                                                part.prompt, _german)),
                                            if (part.figure != null)
                                              KompassFigureView(
                                                  figure: part.figure!,
                                                  german: _german,
                                                  plain: true),
                                            for (final option in part.options)
                                              Text(
                                                  '□ ${kompassText(option['label'], _german)}'),
                                            const Padding(
                                                padding: EdgeInsets.symmetric(
                                                    vertical: 20),
                                                child: Divider()),
                                          ])),
                                if (_solutions)
                                  SelectableText(
                                      kompassText(_tasks[i].solution, _german)),
                              ]))),
                  ],
                ])),
      );
}
