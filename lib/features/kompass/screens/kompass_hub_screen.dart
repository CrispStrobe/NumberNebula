import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/crash_logger.dart';
import '../../../core/services/profile_preferences.dart';
import '../../../generated/l10n.dart';
import '../../games/game_registry.dart';
import '../../games/providers/game_provider.dart';
import '../../missions/data/game_pool.dart';
import '../labs/kompass_lab_screen.dart';
import '../labs/kompass_lab_round.dart';
import '../models/kompass_attempt.dart';
import '../models/kompass_content.dart';
import '../services/kompass_planner.dart';
import '../services/kompass_repository.dart';
import '../services/kompass_store.dart';
import 'kompass_course_screen.dart';
import 'kompass_review_screen.dart';
import 'kompass_paper_screen.dart';
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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Open before any other await: the store captures this local player.
      final storeFuture = widget.store == null
          ? KompassStore.open()
          : Future.value(widget.store!);
      final pack = widget.pack ?? await KompassRepository.load();
      final store = await storeFuture;
      if (!mounted) return;
      setState(() {
        _pack = pack;
        _store = store;
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _loading = false;
        });
      }
    }
  }

  Future<bool> _replaceSession() async {
    if (_store!.session == null) return true;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
                kc(_german, 'Neue Runde beginnen?', 'Start a new session?')),
            content: Text(kc(
                _german,
                'Eine Runde ist noch offen. Deine abgeschlossenen Lernaufzeichnungen bleiben erhalten.',
                'There is an unfinished session. Your completed learning records will be kept.')),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(kc(_german, 'Zurück', 'Back'))),
              FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(kc(_german, 'Neu beginnen', 'Start new'))),
            ],
          ),
        ) ??
        false;
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
            count: mode == KompassMode.rehearsal
                ? 20
                : mode == KompassMode.check
                    ? 8
                    : 4,
            domain: mode == KompassMode.rehearsal ? null : _domain,
            exposedFamilies: _store!.exposedFamilies);
      }
      var repeatedRehearsalTasks = 0;
      if (mode == KompassMode.rehearsal) {
        const expected = {
          'numbers': 8,
          'geometry': 5,
          'measurement': 4,
          'data': 3
        };
        if (tasks.length < 20 ||
            expected.entries.any((entry) =>
                tasks.where((task) => task.domain == entry.key).length !=
                entry.value)) {
          // A repeat remains useful timed practice. Exposure history still
          // prevents these tasks from becoming new independent evidence.
          tasks = KompassPlanner.selectSession(_pack!, const [],
              mode: KompassMode.rehearsal, count: 20);
          final seen = {
            ..._store!.exposedFamilies,
            ..._store!.attempts.map((attempt) => attempt.familyId)
          };
          repeatedRehearsalTasks =
              tasks.where((task) => seen.contains(task.familyId)).length;
        }
      }
      if (tasks.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(kc(
                _german,
                'Für diese Auswahl sind keine neuen Prüfaufgaben übrig. Du kannst weiter üben und deine bisherigen Lösungen ansehen.',
                'No unseen check tasks remain for this selection. You can keep practising and review earlier answers.')),
          ));
        }
        return;
      }
      if (mode == KompassMode.rehearsal) {
        final begin = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(kc(_german, '45 Minuten Arbeitszeit',
                '45 minutes of working time')),
            content: SingleChildScrollView(
                child: Text(kc(
                        _german,
                        'Lege Papier und Stift bereit. Du kannst Aufgaben überspringen, zurückkehren und Antworten ändern. Hinweise und Lösungen gibt es erst am Ende. Die Uhr beginnt mit „Start“ und läuft auch beim Verlassen der App weiter. Dies ist eine eigene Übung; Punkte sind keine amtliche Bewertung.',
                        'Have paper and a pencil ready. You can skip tasks, return and edit answers. Hints and solutions appear at the end. The clock starts with “Start” and keeps running if you leave the app. This is original practice; points are not an official assessment.') +
                    (repeatedRehearsalTasks == 0
                        ? ''
                        : kc(
                            _german,
                            '\n\nDies ist ein Wiederholungs-Probelauf: $repeatedRehearsalTasks Aufgaben hast du bereits gesehen. Sie zählen als Wiederholung, nicht als neue selbstständige Beobachtungen.',
                            '\n\nThis is a repeat rehearsal: you have already seen $repeatedRehearsalTasks tasks. They count as review, not as new independent observations.')))),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(kc(_german, 'Zurück', 'Back'))),
              FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(S.of(context)!.kompassRehearsalStart)),
            ],
          ),
        );
        if (begin != true || !mounted) return;
      }
      await _store!.clearSession();
      if (!mounted) return;
      CrashLogger.instance.beginActivity('KOMPASS ${mode.name} session');
      await Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => KompassCourseScreen(
              pack: _pack!, store: _store!, tasks: tasks, mode: mode)));
      if (mounted) setState(() {});
    } catch (error, stack) {
      CrashLogger.instance.record(
          summary: 'KOMPASS ${mode.name} could not open: $error',
          stackTrace: stack.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(kc(
                _german,
                'Die Runde konnte nicht geöffnet werden. Bitte versuche es erneut.',
                'The session could not be opened. Please try again.'))));
      }
    } finally {
      CrashLogger.instance.endActivity();
      _opening = false;
    }
  }

  /// Opens one complete original paper, either timed as a test or as
  /// practice with hints and immediate feedback. The task order is the print
  /// order; nothing is drawn from the practice/check/rehearsal partitions.
  Future<void> _startPaper(KompassPaper paper, {required bool timed}) async {
    if (_opening || _pack == null || _store == null) return;
    final tasks =
        paper.taskIds.map(_pack!.taskById).whereType<KompassTask>().toList();
    if (tasks.length != paper.taskIds.length) return;
    _opening = true;
    try {
      if (!await _replaceSession() || !mounted) return;
      if (timed) {
        final begin = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('${paper.title} · ${paper.totalSeconds ~/ 60} min'),
            content: SingleChildScrollView(
                child: Text([
              ...paper.instructions,
              kc(
                  _german,
                  'Lege Papier, Stift und Lineal bereit. Zeichnungen und Begründungen prüfst du am Ende mit den Kriterien. Die Uhr läuft auch beim Verlassen der App weiter. Punkte sind keine amtliche Bewertung.',
                  'Have paper, a pencil and a ruler ready. Drawings and explanations are reviewed against the criteria at the end. The clock keeps running if you leave the app. Points are not an official assessment.'),
            ].join('\n\n'))),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(kc(_german, 'Zurück', 'Back'))),
              FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(S.of(context)!.kompassRehearsalStart)),
            ],
          ),
        );
        if (begin != true || !mounted) return;
      }
      await _store!.clearSession();
      if (!mounted) return;
      CrashLogger.instance.beginActivity(
          'KOMPASS paper ${paper.id} (${timed ? 'test' : 'practice'})');
      await Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => KompassCourseScreen(
              pack: _pack!,
              store: _store!,
              tasks: tasks,
              mode: timed ? KompassMode.rehearsal : KompassMode.practice,
              rehearsalDuration: Duration(seconds: paper.totalSeconds))));
      if (mounted) setState(() {});
    } catch (error, stack) {
      CrashLogger.instance.record(
          summary: 'KOMPASS paper ${paper.id} could not open: $error',
          stackTrace: stack.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(kc(
                _german,
                'Die Runde konnte nicht geöffnet werden. Bitte versuche es erneut.',
                'The session could not be opened. Please try again.'))));
      }
    } finally {
      CrashLogger.instance.endActivity();
      _opening = false;
    }
  }

  Future<void> _resume() async {
    if (_store?.session == null || _opening) return;
    _opening = true;
    try {
      CrashLogger.instance.beginActivity('KOMPASS resume session');
      await Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => KompassCourseScreen.resume(
              pack: _pack!, store: _store!, session: _store!.session!)));
      if (mounted) setState(() {});
    } catch (error, stack) {
      CrashLogger.instance.record(
          summary: 'KOMPASS resume could not open: $error',
          stackTrace: stack.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(kc(
                _german,
                'Die Runde konnte nicht geöffnet werden. Bitte versuche es erneut.',
                'The session could not be opened. Please try again.'))));
      }
    } finally {
      CrashLogger.instance.endActivity();
      _opening = false;
    }
  }

  Future<void> _openLab(String labId) async {
    if (_opening) return;
    _opening = true;
    try {
      for (final family
          in kompassLabExposedFamilies[labId] ?? const <String>[]) {
        await _store!.markExposed(family, sessionId: 'lab_practice:$labId');
      }
      if (!mounted) return;
      CrashLogger.instance.beginActivity('KOMPASS lab $labId');
      await Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => KompassLabScreen(
              labId: labId,
              german: _german,
              onCompleted: (result) async {
                final attempt = KompassAttempt.forLab(
                    id: 'lab:${result['roundId']}',
                    result: result,
                    packVersion: _pack!.version);
                await _store!.record(attempt);
              })));
      if (mounted) setState(() {});
    } catch (error, stack) {
      CrashLogger.instance.record(
          summary: 'KOMPASS lab $labId failed: $error',
          stackTrace: stack.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              kc(
                _german,
                'Die Übung konnte nicht sicher gespeichert werden. Bitte versuche es erneut.',
                'The practice record could not be saved. Please try again.',
              ),
            ),
          ),
        );
      }
    } finally {
      CrashLogger.instance.endActivity();
      _opening = false;
    }
  }

  Future<void> _openGame(String key) async {
    final game = gameBuilderFor(key);
    if (game == null) return;
    final provider = context.read<GameProvider>();
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) =>
            game(provider.effectiveGrade, provider.gameProgress[key] ?? 1)));
  }

  Future<void> _exportProgress() async {
    await Clipboard.setData(ClipboardData(
        text: const JsonEncoder.withIndent('  ').convert({
      'schemaVersion': 1,
      'pack': _pack!.id,
      'packVersion': _pack!.version,
      'attempts': _store!.attempts.map((a) => a.toJson()).toList(),
    })));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(kc(
              _german,
              'Lernaufzeichnungen in die Zwischenablage kopiert.',
              'Learning records copied to the clipboard.'))));
    }
  }

  @override
  Widget build(BuildContext context) => KompassPage(
        title: kc(_german, 'KOMPASS 4 · Mathematik', 'KOMPASS 4 · Mathematics'),
        actions: [
          IconButton(
            tooltip: kc(_german, 'Mathematische Wörter', 'Mathematical words'),
            onPressed: () => showKompassGlossary(context, _german),
            icon: const Icon(Icons.menu_book_outlined),
          )
        ],
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(kc(
                        _german,
                        'Der Lernpfad konnte nicht geladen werden.',
                        'The learning path could not be loaded.')),
                    TextButton(
                        onPressed: _load,
                        child:
                            Text(kc(_german, 'Erneut versuchen', 'Try again'))),
                  ]))
                : _store!.profileId != ProfilePreferences.activeId
                    ? Center(
                        child: TextButton(
                            onPressed: _load,
                            child: Text(kc(_german, 'Aktuellen Spieler laden',
                                'Load current player'))))
                    : _store!.corruptionError != null
                        ? _corruptionNotice()
                        : Builder(builder: _content),
      );

  Widget _corruptionNotice() => Center(
      child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(kc(
                _german,
                'Diese Lernaufzeichnungen lassen sich nicht lesen. Sie wurden nicht überschrieben.',
                'These learning records could not be read. They have not been overwritten.')),
            const SizedBox(height: 16),
            OutlinedButton(
                onPressed: () async {
                  final reset = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                            title: Text(kc(_german, 'Lernpfad zurücksetzen?',
                                'Reset this learning path?')),
                            content: Text(kc(
                                _german,
                                'Nur die beschädigten KOMPASS-Aufzeichnungen dieses Spielers werden ersetzt. Andere Spielfortschritte bleiben erhalten.',
                                'Only this player’s damaged KOMPASS records will be replaced. Other game progress is kept.')),
                            actions: [
                              TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child:
                                      Text(kc(_german, 'Abbrechen', 'Cancel'))),
                              FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: Text(
                                      kc(_german, 'Zurücksetzen', 'Reset')))
                            ],
                          ));
                  if (reset == true) {
                    await _store!.resetAfterCorruption();
                    if (mounted) setState(() {});
                  }
                },
                child: Text(kc(
                    _german, 'Aufzeichnungen zurücksetzen', 'Reset records'))),
          ])));

  Widget _content(BuildContext context) {
    final pack = _pack!;
    final progress = KompassPlanner.progress(pack, _store!.attempts);
    final recent = _store!.attempts
        .where((a) => a.mode != KompassMode.lab)
        .toList()
        .reversed
        .take(12)
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        KompassPanel(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              kc(_german, 'Verstehen. Anwenden. Selbstständig lösen.',
                  'Understand. Apply. Solve independently.'),
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 10),
          Text(kc(
              _german,
              'Vier Bereiche, kurze Übungen und verständliche Rückmeldungen. Alles bleibt bei deinem lokalen Spielerprofil.',
              'Four areas, short activities and clear feedback. Everything stays with your local player profile.')),
          const SizedBox(height: 16),
          Wrap(spacing: 10, runSpacing: 10, children: [
            FilledButton.icon(
                key: const ValueKey('kompass-next-practice'),
                onPressed: () => _start(KompassMode.practice),
                icon: const Icon(Icons.play_arrow),
                label: Text(
                    kc(_german, 'Meine nächste Übung', 'My next practice'))),
            OutlinedButton.icon(
                onPressed: () => _start(KompassMode.check),
                icon: const Icon(Icons.fact_check_outlined),
                label: Text(
                    kc(_german, 'Selbstständig lösen', 'Independent check'))),
            OutlinedButton.icon(
                onPressed: () => _start(KompassMode.rehearsal),
                icon: const Icon(Icons.timer_outlined),
                label: Text(kc(
                    _german, '45-Minuten-Probelauf', '45-minute rehearsal'))),
            OutlinedButton.icon(
                onPressed: () async {
                  await Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) =>
                          KompassPaperScreen(pack: pack, store: _store!)));
                  if (mounted) setState(() {});
                },
                icon: const Icon(Icons.print_outlined),
                label:
                    Text(kc(_german, 'Auf Papier üben', 'Practise on paper'))),
          ]),
          if (_store!.session != null) ...[
            const SizedBox(height: 12),
            TextButton.icon(
                key: const ValueKey('kompass-resume'),
                onPressed: _resume,
                icon: const Icon(Icons.history),
                label: Text(kc(_german, 'Offene Runde fortsetzen',
                    'Continue unfinished session'))),
          ],
        ])),
        const SizedBox(height: 20),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ChoiceChip(
              label: Text(kc(_german, 'Alle Bereiche', 'All areas')),
              selected: _domain == null,
              onSelected: (_) => setState(() => _domain = null)),
          for (final domain in kompassDomains)
            ChoiceChip(
                avatar: Icon(kompassDomainIcon(domain), size: 18),
                label: Text(kompassDomainLabel(domain, _german)),
                selected: _domain == domain,
                onSelected: (_) => setState(() => _domain = domain)),
        ]),
        const SizedBox(height: 24),
        Text(kc(_german, 'Mathe-Labore', 'Math labs'),
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(kc(
            _german,
            'Ausprobieren, verändern und Zusammenhänge entdecken. Diese Aktivitäten zählen als Übung.',
            'Try things, make changes and discover relationships. These activities count as practice.')),
        const SizedBox(height: 12),
        for (final lab in _labs)
          if (_domain == null || _domain == lab[1])
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                  child: ListTile(
                key: ValueKey('kompass-lab-${lab[0]}'),
                leading: Icon(kompassDomainIcon(lab[1])),
                title: Text(lab[_german ? 2 : 3]),
                subtitle: Text(lab[_german ? 4 : 5]),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openLab(lab[0]),
              )),
            ),
        if (pack.papers.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(kc(_german, 'Original-Übungstests', 'Original practice papers'),
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(kc(
              _german,
              'Sechs vollständige Mathematiktests aus dem Projekt kompass4, je 45 Minuten. Die Aufgaben sind deutsch. Löse sie als Test oder übe sie mit Hinweisen. Das Heft und die Lösungen gibt es auch zum Drucken.',
              'Six complete mathematics papers from the kompass4 project, 45 minutes each. The tasks are in German. Take one as a test or practise it with hints. The booklet and its solutions are also available to print.')),
          const SizedBox(height: 12),
          for (final paper in pack.papers)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                  child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(paper.title,
                          style: Theme.of(context).textTheme.titleMedium),
                      Text(kc(
                          _german,
                          '${paper.taskIds.length} Aufgaben · ${paper.totalPoints} Punkte · ${paper.totalSeconds ~/ 60} Minuten',
                          '${paper.taskIds.length} tasks · ${paper.totalPoints} points · ${paper.totalSeconds ~/ 60} minutes')),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        FilledButton.tonalIcon(
                            key: ValueKey('kompass-paper-${paper.id}-test'),
                            onPressed: () => _startPaper(paper, timed: true),
                            icon: const Icon(Icons.timer_outlined),
                            label: Text(kc(_german, 'Als Test', 'As a test'))),
                        OutlinedButton.icon(
                            key: ValueKey('kompass-paper-${paper.id}-practice'),
                            onPressed: () => _startPaper(paper, timed: false),
                            icon: const Icon(Icons.school_outlined),
                            label: Text(kc(_german, 'Üben', 'Practise'))),
                        TextButton.icon(
                            onPressed: () => launchUrl(
                                Uri.parse(paper.printUrl),
                                mode: LaunchMode.externalApplication),
                            icon: const Icon(Icons.picture_as_pdf_outlined),
                            label: Text(kc(_german, 'Heft', 'Booklet'))),
                        TextButton.icon(
                            onPressed: () => launchUrl(
                                Uri.parse(paper.solutionsUrl),
                                mode: LaunchMode.externalApplication),
                            icon: const Icon(Icons.fact_check_outlined),
                            label: Text(kc(_german, 'Lösungen', 'Solutions'))),
                      ]),
                    ]),
              )),
            ),
        ],
        const SizedBox(height: 20),
        Text(kc(_german, 'Deine Lernziele', 'Your learning goals'),
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(kc(
            _german,
            'Die Anzeige beruht auf deinen Antworten und der verwendeten Hilfe. Wenige Aufgaben reichen noch nicht für ein sicheres Urteil. Übungspunkte sind keine amtliche KOMPASS-Bewertung.',
            'These observations use your answers and support used. A few tasks are not enough for a confident judgement. Practice points are not an official KOMPASS assessment.')),
        const SizedBox(height: 12),
        for (final competency in pack.competencies)
          if (_domain == null || _domain == competency.domain)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                  child: ExpansionTile(
                key: PageStorageKey('competency-${competency.id}'),
                leading: Icon(kompassDomainIcon(competency.domain)),
                title: Text(kompassText(competency.title, _german)),
                subtitle: Text(kompassProgressLabel(
                    progress[competency.id]?.state.name ?? 'unassessed',
                    _german)),
                childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(kompassText(competency.goal, _german)),
                  const SizedBox(height: 8),
                  Text(kc(
                      _german,
                      'Selbstständige richtige Beobachtungen: ${progress[competency.id]?.independentCorrect ?? 0} / ${progress[competency.id]?.independentAttempts ?? 0}.',
                      'Correct independent observations: ${progress[competency.id]?.independentCorrect ?? 0} / ${progress[competency.id]?.independentAttempts ?? 0}.')),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                      onPressed: () => _start(KompassMode.practice,
                          competencyId: competency.id),
                      child: Text(kc(_german, 'Dieses Lernziel üben',
                          'Practise this goal'))),
                  if (competency.gameKeys.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(kc(_german, 'Passende Spiele zur Vertiefung',
                        'Related games for more practice')),
                    Wrap(spacing: 8, runSpacing: 6, children: [
                      for (final game in competency.gameKeys)
                        OutlinedButton(
                            onPressed: () => _openGame(game),
                            child: Text(gameTitleFor(S.of(context)!, game))),
                    ]),
                  ],
                ],
              )),
            ),
        if (recent.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(kc(_german, 'Letzte Aufgaben ansehen', 'Review recent tasks'),
              style: Theme.of(context).textTheme.headlineSmall),
          for (final attempt in recent)
            if (pack.taskById(attempt.taskId) case final task?)
              ListTile(
                title: Text(kompassText(task.title, _german)),
                subtitle: Text(attempt.score.pendingReview
                    ? kc(_german, 'Begründung noch prüfen',
                        'Explanation awaiting review')
                    : '${attempt.score.awardedPoints} / ${attempt.score.maxPoints}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => KompassReviewScreen(
                          pack: pack,
                          store: _store!,
                          attemptIds: [attempt.id])));
                  if (mounted) setState(() {});
                },
              ),
        ],
        const SizedBox(height: 20),
        Wrap(spacing: 10, runSpacing: 8, children: [
          OutlinedButton.icon(
              onPressed: _exportProgress,
              icon: const Icon(Icons.copy_outlined),
              label: Text(kc(_german, 'Lernaufzeichnungen kopieren',
                  'Copy learning records'))),
          TextButton(
              onPressed: () => launchUrl(
                  Uri.parse(
                      'https://ibbw-bw.de/,Lde/Startseite/Pruefungen+_+Lernstandserhebungen/Kompass+4-+Konzeption'),
                  mode: LaunchMode.externalApplication),
              child: Text(kc(
                  _german,
                  'Amtliche Informationen und Originalhefte',
                  'Official information and original papers'))),
        ]),
      ],
    );
  }
}

const _labs = [
  [
    'reasoning_workshop',
    'numbers',
    'Denkwerkstatt',
    'Reasoning workshop',
    'Rechenwege begründen, Regeln prüfen und alle Möglichkeiten bauen',
    'Explain methods, check rules and construct every possibility',
  ],
  [
    'journey_planner',
    'measurement',
    'Reiseplanung',
    'Journey planner',
    'Rückwärts planen und passende Verbindungen finden',
    'Plan backwards and find feasible connections',
  ],
  [
    'area_studio',
    'geometry',
    'Flächenstudio',
    'Area studio',
    'Fläche und Umfang vergleichen und eigene Formen bauen',
    'Compare area and perimeter and construct your own shapes',
  ],
  [
    'chance_detective',
    'data',
    'Zufallsdetektive',
    'Chance detectives',
    'Behauptungen mit erlaubten Gegenbeispielen prüfen',
    'Test claims with possible counterexamples',
  ],
  [
    'number_dock',
    'numbers',
    'Zahlendock',
    'Number dock',
    'Stellenwerte bündeln und Zahlen verorten',
    'Regroup place values and locate numbers'
  ],
  [
    'supply_station',
    'measurement',
    'Versorgungsstation',
    'Supply station',
    'Mit Geld, Zeit und Einheiten handeln',
    'Work with money, time and units'
  ],
  [
    'data_observatory',
    'data',
    'Datenobservatorium',
    'Data observatory',
    'Daten untersuchen und faire Chancen herstellen',
    'Explore data and construct fair chances'
  ],
  [
    'geometry_workshop',
    'geometry',
    'Geometriewerkstatt',
    'Geometry workshop',
    'Spiegelungen, Netze und Ansichten entdecken',
    'Explore reflections, nets and views'
  ],
];
