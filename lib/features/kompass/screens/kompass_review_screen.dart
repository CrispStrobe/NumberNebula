import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/kompass_attempt.dart';
import '../models/kompass_content.dart';
import '../services/kompass_store.dart';
import '../services/kompass_planner.dart';
import '../widgets/kompass_figure_view.dart';
import 'kompass_ui.dart';
import 'kompass_course_screen.dart';

class KompassReviewScreen extends StatefulWidget {
  final KompassPack pack;
  final KompassStore store;
  final List<String> attemptIds;
  final bool expired;
  const KompassReviewScreen({
    super.key,
    required this.pack,
    required this.store,
    required this.attemptIds,
    this.expired = false,
  });

  @override
  State<KompassReviewScreen> createState() => _KompassReviewScreenState();
}

class _KompassReviewScreenState extends State<KompassReviewScreen> {
  bool _busy = false;
  bool get _german => Localizations.localeOf(context).languageCode == 'de';
  List<KompassAttempt> get _attempts => [
        for (final id in widget.attemptIds)
          for (final attempt in widget.store.attempts)
            if (attempt.id == id) attempt,
      ];

  String _response(KompassPart part, dynamic value) {
    if (value == null || value == '') {
      return kc(_german, 'Nicht bearbeitet', 'Not attempted');
    }
    if (value is List && value.isEmpty) {
      return kc(_german, 'Keine Elemente ausgewählt', 'No elements selected');
    }
    String label(dynamic item) {
      if (part.kind == 'cells') {
        final coordinates = item.toString().split(',');
        if (coordinates.length == 2) {
          final row = int.tryParse(coordinates[0]);
          final column = int.tryParse(coordinates[1]);
          if (row != null && column != null) {
            return kc(
              _german,
              'Reihe ${row + 1}, Spalte ${column + 1}',
              'row ${row + 1}, column ${column + 1}',
            );
          }
        }
      }
      for (final option in part.options) {
        if (option['id'] == item) return kompassText(option['label'], _german);
      }
      return item.toString();
    }

    final text = value is List
        ? value.map(label).join(part.kind == 'order' ? ' → ' : '; ')
        : label(value);
    return part.unit.isEmpty || RegExp(r'[a-zA-Z€²]').hasMatch(text)
        ? text
        : '$text ${part.unit}';
  }

  Future<void> _review(
    KompassAttempt attempt,
    KompassTask task,
    KompassPart part,
    double points,
  ) async {
    if (_busy) return;
    KompassAttempt? latest;
    for (final candidate in widget.store.attempts) {
      if (candidate.id == attempt.id) {
        latest = candidate;
        break;
      }
    }
    if (latest == null ||
        latest.packVersion != widget.pack.version ||
        latest.taskId != task.id) {
      return;
    }
    setState(() => _busy = true);
    try {
      final manual = <String, double>{
        for (final score in latest.score.parts)
          if (score.manual && score.reviewed) score.partId: score.awardedPoints,
        part.id: points,
      };
      await widget.store.revise(
        latest.reviseTask(
          task: task,
          responses: latest.responses,
          manualPoints: manual,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              kc(
                _german,
                'Die Bewertung konnte nicht gespeichert werden.',
                'The review could not be saved.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copyReport() async {
    final report = StringBuffer(
      kc(
        _german,
        'KOMPASS 4 – Übungsbericht\n',
        'KOMPASS 4 – practice report\n',
      ),
    );
    report.writeln(
      kc(
        _german,
        'Eigene Übungen; keine amtliche Bewertung.\n',
        'Original practice; not an official assessment.\n',
      ),
    );
    for (final attempt in _attempts) {
      final task = widget.pack.taskById(attempt.taskId);
      if (task == null || attempt.packVersion != widget.pack.version) {
        report.writeln(kc(_german, 'Frühere Aufzeichnung', 'Earlier record'));
        report.writeln(
          '${attempt.score.awardedPoints} / ${attempt.score.maxPoints}',
        );
        for (final response in attempt.responses.values) {
          report.writeln(response);
        }
        report.writeln();
        continue;
      }
      report.writeln(kompassText(task.title, _german));
      report.writeln(
        '${attempt.score.awardedPoints} / ${attempt.score.maxPoints}',
      );
      report.writeln(
        kc(
          _german,
          'Verwendete Hinweise: ${attempt.hintsUsed}',
          'Hints used: ${attempt.hintsUsed}',
        ),
      );
      if (attempt.solutionSeen) {
        report.writeln(
          kc(
            _german,
            'Lösungsweg beim Üben angesehen.',
            'Worked solution viewed during practice.',
          ),
        );
      }
      for (final part in task.parts) {
        report.writeln(kompassText(part.prompt, _german));
        report.writeln(_response(part, attempt.responses[part.id]));
        if (part.isManual) {
          report.writeln(kompassText(part.answer['criteria'], _german));
        }
      }
      report.writeln(kompassText(task.solution, _german));
      report.writeln();
    }
    await Clipboard.setData(ClipboardData(text: report.toString()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            kc(
              _german,
              'Bericht kopiert. Du kannst ihn in ein Dokument einfügen und ausdrucken.',
              'Report copied. You can paste it into a document and print it.',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _nextPractice() async {
    if (_busy) return;
    final task = KompassPlanner.nextPractice(
      widget.pack,
      widget.store.attempts,
    );
    if (task == null) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => KompassCourseScreen(
          pack: widget.pack,
          store: widget.store,
          tasks: [task],
          mode: KompassMode.practice,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => KompassPage(
        title: kc(
          _german,
          'Lösungen & nächste Schritte',
          'Solutions and next steps',
        ),
        actions: [
          IconButton(
            onPressed: _copyReport,
            icon: const Icon(Icons.copy_outlined),
            tooltip:
                kc(_german, 'Übungsbericht kopieren', 'Copy practice report'),
          ),
        ],
        child: Builder(builder: _content),
      );

  Widget _content(BuildContext context) {
    final attempts = _attempts;
    final awarded = attempts.fold<double>(
      0,
      (sum, a) => sum + a.score.awardedPoints,
    );
    final maximum = attempts.fold<double>(
      0,
      (sum, a) => sum + a.score.maxPoints,
    );
    final pending = attempts.fold<double>(
      0,
      (sum, a) => sum + a.score.pendingPoints,
    );
    final skipped = attempts.where((a) => !a.completed).length;
    final reviewSkills = {
      for (final attempt in attempts)
        for (final part in attempt.firstScore.parts)
          if (!part.correct || part.pendingReview || attempt.assisted)
            ...part.competencyIds,
    };
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        KompassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.expired
                    ? kc(
                        _german,
                        'Die Arbeitszeit ist zu Ende.',
                        'Working time has ended.',
                      )
                    : kc(
                        _german,
                        'Deine Runde ist gespeichert.',
                        'Your session has been saved.',
                      ),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                kc(
                  _german,
                  'Übungspunkte: $awarded / $maximum',
                  'Practice points: $awarded / $maximum',
                ),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (pending > 0)
                Text(
                  kc(
                    _german,
                    '$pending Punkte sind noch anhand der Kriterien zu prüfen.',
                    '$pending points still need a rubric review.',
                  ),
                ),
              if (skipped > 0)
                Text(
                  kc(
                    _german,
                    '$skipped Aufgaben blieben unbearbeitet.',
                    '$skipped tasks were not attempted.',
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                kc(
                  _german,
                  'Schau auf deine Lösungswege und die Hilfe, die du gebraucht hast. Diese Aufgaben sind eigene Übungen. Daraus entsteht keine amtliche KOMPASS-Stufe oder Schulartempfehlung.',
                  'Look at your methods and the support you needed. These are original practice tasks. They do not produce an official KOMPASS level or school recommendation.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        KompassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                kc(_german, 'Dein nächster Schritt', 'Your next step'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                pending > 0
                    ? kc(
                        _german,
                        'Prüfe zuerst die offenen Begründungen mit den Kriterien. Wähle dann eine kurze Übung und erkläre dir deinen Lösungsweg.',
                        'First review the pending explanations against the criteria. Then try a short practice task and explain your method.',
                      )
                    : kc(
                        _german,
                        'Wähle eine kurze Übung zu einem offenen Lernziel. Eine spätere Aufgabe ohne Hilfe zeigt dir, was du behalten hast.',
                        'Try a short practice task for a learning goal you are working on. A later task without help can show what you retained.',
                      ),
              ),
              for (final id in reviewSkills.take(4))
                if (widget.pack.competencyById(id) case final skill?)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('• ${kompassText(skill.title, _german)}'),
                  ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: widget.store.session == null
                    ? _nextPractice
                    : () => Navigator.of(context).pop(),
                child: Text(
                  widget.store.session == null
                      ? kc(
                          _german,
                          'Nächste passende Übung',
                          'Next suggested practice',
                        )
                      : kc(
                          _german,
                          'Offene Runde in der Übersicht fortsetzen',
                          'Return to your unfinished session in the overview',
                        ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (final attempt in attempts)
          if (attempt.packVersion != widget.pack.version ||
              widget.pack.taskById(attempt.taskId) == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: KompassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kc(_german, 'Frühere Aufzeichnung', 'Earlier record'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${attempt.score.awardedPoints} / ${attempt.score.maxPoints}',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      kc(
                        _german,
                        'Diese Aufgabe stammt aus einer anderen Inhaltsfassung. Deine Antworten und die damalige Bewertung bleiben erhalten; neue Lösungen oder Kriterien werden nicht darauf angewendet.',
                        'This task comes from a different content version. Your responses and original score are preserved; current solutions or rubrics are not applied to it.',
                      ),
                    ),
                    for (final response in attempt.responses.values)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: SelectableText(response.toString()),
                      ),
                  ],
                ),
              ),
            )
          else if (widget.pack.taskById(attempt.taskId) case final task?)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: ExpansionTile(
                  key: ValueKey('review-${attempt.id}'),
                  initiallyExpanded:
                      attempts.length == 1 || attempt.score.pendingReview,
                  title: Text(kompassText(task.title, _german)),
                  subtitle: Text(
                    '${attempt.score.awardedPoints} / ${attempt.score.maxPoints} · ${kc(_german, 'Hinweise', 'Hints')}: ${attempt.hintsUsed}',
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (attempt.solutionSeen)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          kc(
                            _german,
                            'Lösungsweg beim Üben angesehen.',
                            'Worked solution viewed during practice.',
                          ),
                        ),
                      ),
                    SelectableText(kompassText(task.prompt, _german)),
                    if (task.figure != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: KompassFigureView(
                          figure: task.figure!,
                          german: _german,
                          plain: true,
                        ),
                      ),
                    for (final part in task.parts)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              kompassText(part.prompt, _german),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (part.figure != null)
                              KompassFigureView(
                                figure: part.figure!,
                                german: _german,
                                plain: true,
                              ),
                            const SizedBox(height: 6),
                            Text(
                              '${kc(_german, 'Deine Antwort', 'Your response')}: ${_response(part, attempt.responses[part.id])}',
                            ),
                            if (attempt.firstResponses[part.id].toString() !=
                                attempt.responses[part.id].toString())
                              Text(
                                '${kc(_german, 'Erste Abgabe', 'First submission')}: ${_response(part, attempt.firstResponses[part.id])}',
                              ),
                            if (attempt.score.partById(part.id)?.feedback
                                case final feedback?)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(kompassText(feedback, _german)),
                              ),
                            if (attempt.score.partById(part.id)?.carriedError ==
                                true)
                              Text(
                                kc(
                                  _german,
                                  'Teilpunkt für den passenden Folgeschritt trotz vorherigem Rechenfehler.',
                                  'Credit for a valid follow-up step despite an earlier arithmetic slip.',
                                ),
                              ),
                            if (part.isManual) ...[
                              const SizedBox(height: 10),
                              Text(
                                kc(
                                  _german,
                                  'Begründung anhand dieser Kriterien prüfen:',
                                  'Review the explanation using these criteria:',
                                ),
                              ),
                              Text(
                                kompassText(part.answer['criteria'], _german),
                              ),
                              for (final criterion in part.rubric)
                                Text('• ${kompassText(criterion, _german)}'),
                              const SizedBox(height: 8),
                              Text(
                                kc(
                                  _german,
                                  'Prüfe selbst oder gemeinsam mit einer unterstützenden Person. Diese Bewertung wird als manuell geprüft gespeichert.',
                                  'Review it yourself or with someone supporting you. This result is saved as a manual review.',
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (double points = 0;
                                      points <= part.maxPoints;
                                      points += .5)
                                    ChoiceChip(
                                      label: Text(
                                        '$points / ${part.maxPoints}',
                                      ),
                                      selected: attempt.score
                                                  .partById(part.id)
                                                  ?.reviewed ==
                                              true &&
                                          attempt.score
                                                  .partById(part.id)
                                                  ?.awardedPoints ==
                                              points,
                                      onSelected: _busy ||
                                              attempt.packVersion !=
                                                  widget.pack.version
                                          ? null
                                          : (_) => _review(
                                                attempt,
                                                task,
                                                part,
                                                points,
                                              ),
                                    ),
                                ],
                              ),
                              if (attempt.packVersion != widget.pack.version)
                                Text(
                                  kc(
                                    _german,
                                    'Diese Aufzeichnung gehört zu einer früheren Inhaltsfassung. Die gespeicherte Bewertung bleibt erhalten.',
                                    'This record uses an earlier content version. Its saved score is preserved.',
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                    const Divider(),
                    Text(
                      kc(
                        _german,
                        'Ein möglicher Lösungsweg',
                        'One valid solution',
                      ),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    SelectableText(kompassText(task.solution, _german)),
                  ],
                ),
              ),
            ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            kc(_german, 'Zur Lernübersicht', 'Back to learning overview'),
          ),
        ),
      ],
    );
  }
}
