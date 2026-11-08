import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/profile_preferences.dart';
import '../../../generated/l10n.dart';
import '../../games/game_registry.dart';
import '../../games/providers/game_provider.dart';
import '../../missions/data/game_pool.dart';
import '../labs/kompass_lab_screen.dart';
import '../models/kompass_attempt.dart';
import '../models/kompass_content.dart';
import '../services/kompass_planner.dart';
import '../services/kompass_repository.dart';
import '../services/kompass_store.dart';
import 'kompass_course_screen.dart';
import 'kompass_review_screen.dart';
import 'kompass_ui.dart';

/// Optional curriculum pathway; existing free-play games and saved keys stay intact.
class KompassHubScreen extends StatefulWidget {
  final KompassPack? pack;
  final KompassStore? store;
  const KompassHubScreen({super.key, this.pack, this.store});

  @override
  State<KompassHubScreen> createState() => _KompassHubScreenState();
}

class _KompassHubScreenState extends State<KompassHubScreen> {
  KompassPack? _pack;
  KompassStore? _store;
  Object? _error;
  bool _loading = true;
  bool _opening = false;
  String? _domain;

  bool get _german => Localizations.localeOf(context).languageCode == 'de';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      // Open before any other await: the store captures this local player.
      final storeFuture = widget.store == null
          ? KompassStore.open()
          : Future.value(widget.store!);
      final pack = widget.pack ?? await KompassRepository.load();
      final store = await storeFuture;
      if (!mounted) return;
      setState(() { _pack = pack; _store = store; _loading = false; });
    } catch (error) {
      if (mounted) setState(() { _error = error; _loading = false; });
    }
  }

  Future<bool> _replaceSession() async {
    if (_store!.session == null) return true;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(kc(_german, 'Neue Runde beginnen?', 'Start a new session?')),
            content: Text(kc(_german,
                'Eine Runde ist noch offen. Deine abgeschlossenen Lernaufzeichnungen bleiben erhalten.',
                'There is an unfinished session. Your completed learning records will be kept.')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false),
                  child: Text(kc(_german, 'Zurück', 'Back'))),
              FilledButton(onPressed: () => Navigator.pop(context, true),
                  child: Text(kc(_german, 'Neu beginnen', 'Start new'))),
            ],
          ),
        ) ?? false;
  }

  Future<void> _start(KompassMode mode, {String? competencyId}) async {
    if (_opening || _pack == null || _store == null) return;
    _opening = true;
    try {
      if (!await _replaceSession() || !mounted) return;
      List<KompassTask> tasks;
      if (competencyId != null) {
        final first = KompassPlanner.nextPractice(_pack!, _store!.attempts,
            competencyId: competencyId);
        tasks = first == null ? [] : [first];
      } else {
        tasks = KompassPlanner.selectSession(_pack!, _store!.attempts,
            mode: mode,
            count: mode == KompassMode.rehearsal ? 20 : mode == KompassMode.check ? 8 : 4,
            domain: mode == KompassMode.rehearsal ? null : _domain,
            exposedFamilies: _store!.exposedFamilies);
      }
      if (tasks.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(kc(_german,
              'Für diese Auswahl sind keine neuen Prüfaufgaben übrig. Du kannst weiter üben und deine bisherigen Lösungen ansehen.',
              'No unseen check tasks remain for this selection. You can keep practising and review earlier answers.')),
        ));
        return;
      }
      if (mode == KompassMode.rehearsal) {
        final begin = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(kc(_german, '45 Minuten Arbeitszeit', '45 minutes of working time')),
            content: SingleChildScrollView(child: Text(kc(_german,
                'Lege Papier und Stift bereit. Du kannst Aufgaben überspringen, zurückkehren und Antworten ändern. Hinweise und Lösungen gibt es erst am Ende. Die Uhr beginnt mit „Start“ und läuft auch beim Verlassen der App weiter. Dies ist eine eigene Übung; Punkte sind keine amtliche Bewertung.',
                'Have paper and a pencil ready. You can skip tasks, return and edit answers. Hints and solutions appear at the end. The clock starts with “Start” and keeps running if you leave the app. This is original practice; points are not an official assessment.'))),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false),
                  child: Text(kc(_german, 'Zurück', 'Back'))),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Start')),
            ],
          ),
        );
        if (begin != true || !mounted) return;
      }
      await _store!.clearSession();
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) =>
          KompassCourseScreen(pack: _pack!, store: _store!, tasks: tasks, mode: mode)));
      if (mounted) setState(() {});
    } finally {
      _opening = false;
    }
  }

  Future<void> _resume() async {
    if (_store?.session == null || _opening) return;
    _opening = true;
    try {
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) =>
          KompassCourseScreen.resume(pack: _pack!, store: _store!, session: _store!.session!)));
      if (mounted) setState(() {});
    } finally { _opening = false; }
  }

  Future<void> _openLab(String labId) async {
    if (_opening) return;
    _opening = true;
    try {
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) =>
          KompassLabScreen(labId: labId, german: _german, onCompleted: (result) {
            final attempt = KompassAttempt.forLab(
              id: 'lab:${result['roundId']}', result: result, packVersion: _pack!.version);
            _store!.record(attempt).catchError((Object error) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(kc(_german, 'Lernaufzeichnung konnte nicht gespeichert werden.',
                      'The learning record could not be saved.'))));
              return false;
            });
          })));
      if (mounted) setState(() {});
    } finally { _opening = false; }
  }

  Future<void> _openGame(String key) async {
    final game = gameBuilderFor(key);
    if (game == null) return;
    final provider = context.read<GameProvider>();
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) =>
        game(provider.effectiveGrade, provider.gameProgress[key] ?? 1)));
  }

  Future<void> _exportProgress() async {
    await Clipboard.setData(ClipboardData(text: const JsonEncoder.withIndent('  ').convert({
      'schemaVersion': 1,
      'pack': _pack!.id,
      'packVersion': _pack!.version,
      'attempts': _store!.attempts.map((a) => a.toJson()).toList(),
    })));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
        kc(_german, 'Lernaufzeichnungen in die Zwischenablage kopiert.', 'Learning records copied to the clipboard.'))));
  }

  @override
  Widget build(BuildContext context) => KompassPage(
        title: kc(_german, 'KOMPASS 4 · Mathematik', 'KOMPASS 4 · Mathematics'),
        actions: [IconButton(
          tooltip: kc(_german, 'Mathematische Wörter', 'Mathematical words'),
          onPressed: () => showKompassGlossary(context, _german),
          icon: const Icon(Icons.menu_book_outlined),
        )],
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(kc(_german, 'Der Lernpfad konnte nicht geladen werden.', 'The learning path could not be loaded.')),
                    TextButton(onPressed: _load, child: Text(kc(_german, 'Erneut versuchen', 'Try again'))),
                  ]))
                : _store!.profileId != ProfilePreferences.activeId
                    ? Center(child: TextButton(onPressed: _load,
                        child: Text(kc(_german, 'Aktuellen Spieler laden', 'Load current player'))))
                    : _store!.corruptionError != null
                        ? _corruptionNotice()
                        : Builder(builder: _content),
      );

  Widget _corruptionNotice() => Center(child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(kc(_german,
            'Diese Lernaufzeichnungen lassen sich nicht lesen. Sie wurden nicht überschrieben.',
            'These learning records could not be read. They have not been overwritten.')),
        const SizedBox(height: 16),
        OutlinedButton(onPressed: () async {
          final reset = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
            title: Text(kc(_german, 'Lernpfad zurücksetzen?', 'Reset this learning path?')),
            content: Text(kc(_german, 'Nur die beschädigten KOMPASS-Aufzeichnungen dieses Spielers werden ersetzt. Andere Spielfortschritte bleiben erhalten.',
                'Only this player’s damaged KOMPASS records will be replaced. Other game progress is kept.')),
            actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: Text(kc(_german, 'Abbrechen', 'Cancel'))),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(kc(_german, 'Zurücksetzen', 'Reset')))],
          ));
          if (reset == true) { await _store!.resetAfterCorruption(); if (mounted) setState(() {}); }
        }, child: Text(kc(_german, 'Aufzeichnungen zurücksetzen', 'Reset records'))),
      ])));

  Widget _content(BuildContext context) {
    final pack = _pack!;
    final progress = KompassPlanner.progress(pack, _store!.attempts);
    final recent = _store!.attempts.where((a) => a.mode != KompassMode.lab).toList().reversed.take(12).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        KompassPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(kc(_german, 'Verstehen. Anwenden. Selbstständig lösen.', 'Understand. Apply. Solve independently.'),
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 10),
          Text(kc(_german, 'Vier Bereiche, kurze Übungen und verständliche Rückmeldungen. Alles bleibt bei deinem lokalen Spielerprofil.',
              'Four areas, short activities and clear feedback. Everything stays with your local player profile.')),
          const SizedBox(height: 16),
          Wrap(spacing: 10, runSpacing: 10, children: [
            FilledButton.icon(key: const ValueKey('kompass-next-practice'),
                onPressed: () => _start(KompassMode.practice), icon: const Icon(Icons.play_arrow),
                label: Text(kc(_german, 'Meine nächste Übung', 'My next practice'))),
            OutlinedButton.icon(onPressed: () => _start(KompassMode.check),
                icon: const Icon(Icons.fact_check_outlined),
                label: Text(kc(_german, 'Selbstständig lösen', 'Independent check'))),
            OutlinedButton.icon(onPressed: () => _start(KompassMode.rehearsal),
                icon: const Icon(Icons.timer_outlined),
                label: Text(kc(_german, '45-Minuten-Probelauf', '45-minute rehearsal'))),
          ]),
          if (_store!.session != null) ...[
            const SizedBox(height: 12),
            TextButton.icon(key: const ValueKey('kompass-resume'), onPressed: _resume,
                icon: const Icon(Icons.history), label: Text(kc(_german, 'Offene Runde fortsetzen', 'Continue unfinished session'))),
          ],
        ])),
        const SizedBox(height: 20),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ChoiceChip(label: Text(kc(_german, 'Alle Bereiche', 'All areas')), selected: _domain == null,
              onSelected: (_) => setState(() => _domain = null)),
          for (final domain in kompassDomains)
            ChoiceChip(avatar: Icon(kompassDomainIcon(domain), size: 18),
                label: Text(kompassDomainLabel(domain, _german)), selected: _domain == domain,
                onSelected: (_) => setState(() => _domain = domain)),
        ]),
        const SizedBox(height: 24),
        Text(kc(_german, 'Mathe-Labore', 'Math labs'), style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(kc(_german, 'Ausprobieren, verändern und Zusammenhänge entdecken. Diese Aktivitäten zählen als Übung.',
            'Try things, make changes and discover relationships. These activities count as practice.')),
        const SizedBox(height: 12),
        for (final lab in _labs)
          if (_domain == null || _domain == lab[1]) Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(child: ListTile(
              key: ValueKey('kompass-lab-${lab[0]}'),
              leading: Icon(kompassDomainIcon(lab[1])),
              title: Text(lab[_german ? 2 : 3]),
              subtitle: Text(lab[_german ? 4 : 5]),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openLab(lab[0]),
            )),
          ),
        const SizedBox(height: 20),
        Text(kc(_german, 'Deine Lernziele', 'Your learning goals'), style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(kc(_german,
            'Die Anzeige beruht auf deinen Antworten und der verwendeten Hilfe. Wenige Aufgaben reichen noch nicht für ein sicheres Urteil. Übungspunkte sind keine amtliche KOMPASS-Bewertung.',
            'These observations use your answers and support used. A few tasks are not enough for a confident judgement. Practice points are not an official KOMPASS assessment.')),
        const SizedBox(height: 12),
        for (final competency in pack.competencies)
          if (_domain == null || _domain == competency.domain) Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(child: ExpansionTile(
              key: PageStorageKey('competency-${competency.id}'),
              leading: Icon(kompassDomainIcon(competency.domain)),
              title: Text(kompassText(competency.title, _german)),
              subtitle: Text(kompassProgressLabel(progress[competency.id]?.state.name ?? 'unassessed', _german)),
              childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(kompassText(competency.goal, _german)),
                const SizedBox(height: 8),
                Text(kc(_german,
                    'Selbstständige richtige Beobachtungen: ${progress[competency.id]?.independentCorrect ?? 0} / ${progress[competency.id]?.independentAttempts ?? 0}.',
                    'Correct independent observations: ${progress[competency.id]?.independentCorrect ?? 0} / ${progress[competency.id]?.independentAttempts ?? 0}.')),
                const SizedBox(height: 8),
                FilledButton.tonal(onPressed: () => _start(KompassMode.practice, competencyId: competency.id),
                    child: Text(kc(_german, 'Dieses Lernziel üben', 'Practise this goal'))),
                if (competency.gameKeys.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(kc(_german, 'Passende Spiele zur Vertiefung', 'Related games for more practice')),
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    for (final game in competency.gameKeys)
                      OutlinedButton(onPressed: () => _openGame(game),
                          child: Text(gameTitleFor(S.of(context)!, game))),
                  ]),
                ],
              ],
            )),
          ),
        if (recent.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(kc(_german, 'Letzte Aufgaben ansehen', 'Review recent tasks'), style: Theme.of(context).textTheme.headlineSmall),
          for (final attempt in recent)
            if (pack.taskById(attempt.taskId) case final task?)
              ListTile(
                title: Text(kompassText(task.title, _german)),
                subtitle: Text(attempt.score.pendingReview
                    ? kc(_german, 'Begründung noch prüfen', 'Explanation awaiting review')
                    : '${attempt.score.awardedPoints} / ${attempt.score.maxPoints}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) =>
                      KompassReviewScreen(pack: pack, store: _store!, attemptIds: [attempt.id])));
                  if (mounted) setState(() {});
                },
              ),
        ],
        const SizedBox(height: 20),
        Wrap(spacing: 10, runSpacing: 8, children: [
          OutlinedButton.icon(onPressed: _exportProgress, icon: const Icon(Icons.copy_outlined),
              label: Text(kc(_german, 'Lernaufzeichnungen kopieren', 'Copy learning records'))),
          TextButton(onPressed: () => launchUrl(Uri.parse(
              'https://ibbw-bw.de/,Lde/Startseite/Pruefungen+_+Lernstandserhebungen/Kompass+4-+Konzeption'),
              mode: LaunchMode.externalApplication),
              child: Text(kc(_german, 'Amtliche Informationen und Originalhefte', 'Official information and original papers'))),
        ]),
      ],
    );
  }
}

const _labs = [
  ['number_dock', 'numbers', 'Zahlendock', 'Number dock',
    'Stellenwerte bündeln und Zahlen verorten', 'Regroup place values and locate numbers'],
  ['supply_station', 'measurement', 'Versorgungsstation', 'Supply station',
    'Mit Geld, Zeit und Einheiten handeln', 'Work with money, time and units'],
  ['data_observatory', 'data', 'Datenobservatorium', 'Data observatory',
    'Daten untersuchen und faire Chancen herstellen', 'Explore data and construct fair chances'],
  ['geometry_workshop', 'geometry', 'Geometriewerkstatt', 'Geometry workshop',
    'Spiegelungen, Netze und Ansichten entdecken', 'Explore reflections, nets and views'],
];
