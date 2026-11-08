import 'dart:async';
import 'dart:convert';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../models/kompass_attempt.dart';
import '../models/kompass_content.dart';
import '../services/kompass_scorer.dart';
import '../services/kompass_store.dart';
import '../widgets/kompass_cell_input.dart';
import '../widgets/kompass_figure_view.dart';
import 'kompass_review_screen.dart';
import 'kompass_ui.dart';

class KompassCourseScreen extends StatefulWidget {
  final KompassPack pack;
  final KompassStore store;
  final List<KompassTask> tasks;
  final KompassMode mode;
  final Map<String, dynamic>? initialSession;
  final Duration rehearsalDuration;
  final DateTime Function() now;

  const KompassCourseScreen({
    super.key,
    required this.pack,
    required this.store,
    required this.tasks,
    required this.mode,
    this.initialSession,
    this.rehearsalDuration = const Duration(minutes: 45),
    this.now = DateTime.now,
  });

  factory KompassCourseScreen.resume({
    Key? key,
    required KompassPack pack,
    required KompassStore store,
    required Map<String, dynamic> session,
  }) {
    final ids = (session['taskIds'] as List? ?? []).whereType<String>();
    final tasks = ids.map(pack.taskById).whereType<KompassTask>().toList();
    final mode = KompassMode.values.firstWhere(
      (mode) => mode.name == session['mode'], orElse: () => KompassMode.practice);
    return KompassCourseScreen(key: key, pack: pack, store: store, tasks: tasks,
        mode: mode, initialSession: session);
  }

  @override
  State<KompassCourseScreen> createState() => _KompassCourseScreenState();
}

class _KompassCourseScreenState extends State<KompassCourseScreen>
    with WidgetsBindingObserver {
  final _responses = <String, Map<String, dynamic>>{};
  final _hints = <String, int>{};
  final _activeMillis = <String, int>{};
  final _feedback = <String>{};
  final _clock = Stopwatch();
  final _scroll = ScrollController();
  Timer? _ticker;
  Timer? _draftTimer;
  late final String _sessionId;
  DateTime? _deadline;
  int _index = 0;
  bool _foreground = true;
  bool _busy = false;
  bool _finished = false;
  bool _invalidSession = false;
  bool _confirming = false;
  BuildContext? _confirmationContext;
  int _revision = 0;
  int _heartbeat = 0;
  String? _saveError;

  bool get _german => Localizations.localeOf(context).languageCode == 'de';
  bool get _practice => widget.mode == KompassMode.practice;
  KompassTask get _task => widget.tasks[_index];
  Map<String, dynamic> get _answers => _responses.putIfAbsent(_task.id, () => {});
  int get _remaining => _deadline == null ? 0 :
      _deadline!.difference(widget.now()).inSeconds.clamp(0, 2700);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final saved = widget.initialSession;
    _sessionId = saved?['id'] as String? ??
        'kompass_${widget.now().microsecondsSinceEpoch}';
    if (saved != null) {
      try {
        _revision = (saved['revision'] as num?)?.toInt() ?? 0;
        if (saved['schemaVersion'] != 1 || saved['packVersion'] != widget.pack.version ||
            (saved['taskIds'] as List).length != widget.tasks.length ||
            !['practice', 'check', 'rehearsal'].contains(saved['mode'])) {
          _invalidSession = true;
        }
        final answers = Map<String, dynamic>.from(saved['responses'] as Map? ?? {});
        for (final entry in answers.entries) {
          _responses[entry.key] = Map<String, dynamic>.from(
              jsonDecode(jsonEncode(entry.value)) as Map);
        }
        for (final entry in (saved['hints'] as Map? ?? {}).entries) {
          _hints[entry.key as String] = (entry.value as num).toInt();
        }
        for (final entry in (saved['activeMillis'] as Map? ?? {}).entries) {
          _activeMillis[entry.key as String] = (entry.value as num).toInt();
        }
        if (widget.tasks.isNotEmpty) {
          _index = ((saved['index'] as num?)?.toInt() ?? 0).clamp(0, widget.tasks.length - 1);
        }
        if (saved['deadline'] != null) _deadline = DateTime.parse(saved['deadline'] as String);
        _feedback.addAll((saved['feedback'] as List? ?? []).whereType<String>());
        if (widget.mode == KompassMode.rehearsal && _deadline == null) _invalidSession = true;
      } catch (_) { _invalidSession = true; }
    } else if (widget.mode == KompassMode.rehearsal) {
      _deadline = widget.now().add(widget.rehearsalDuration);
    }
    if (widget.tasks.isEmpty) _invalidSession = true;
    if (!_invalidSession) {
      _clock.start();
      _openTask();
      _startTicker();
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || _finished) return;
        if (_deadline != null) {
          if (_remaining == 0) { _finish(expired: true); return; }
          if (_foreground) setState(() {});
        }
        if (_foreground && ++_heartbeat % 10 == 0) _persist();
      });
  }

  void _accountTime() {
    if (!_invalidSession && widget.tasks.isNotEmpty) {
      _activeMillis[_task.id] = (_activeMillis[_task.id] ?? 0) + _clock.elapsedMilliseconds;
    }
    _clock.reset();
  }

  Map<String, dynamic> _snapshot() {
    final times = Map<String, int>.from(_activeMillis);
    if (!_invalidSession) times[_task.id] = (times[_task.id] ?? 0) + _clock.elapsedMilliseconds;
    return {
      'schemaVersion': 1, 'id': _sessionId, 'revision': ++_revision,
      'packVersion': widget.pack.version,
      'mode': widget.mode.name, 'taskIds': widget.tasks.map((t) => t.id).toList(),
      'index': _index, 'responses': jsonDecode(jsonEncode(_responses)),
      'hints': Map<String, int>.from(_hints), 'activeMillis': times,
      'feedback': _feedback.toList(),
      if (_deadline != null) 'deadline': _deadline!.toIso8601String(),
    };
  }

  Future<void> _openTask() async {
    try {
      await widget.store.markExposed(_task.familyId, sessionId: _sessionId);
      await _persist();
    } catch (_) { _showSaveError(); }
  }

  Future<bool> _persist() async {
    if (_finished || _invalidSession) return true;
    final snapshot = _snapshot();
    try {
      await widget.store.saveSession(snapshot);
      if (mounted && _saveError != null) setState(() => _saveError = null);
      return true;
    } catch (_) { _showSaveError(); return false; }
  }

  void _showSaveError() {
    if (mounted) setState(() => _saveError = kc(_german,
        'Speichern ist gerade nicht möglich. Bitte versuche es erneut, bevor du die Runde verlässt.',
        'Saving is currently unavailable. Please retry before leaving this session.'));
  }

  void _change(String part, dynamic value) {
    if (_busy || _finished || (_deadline != null && _remaining == 0)) return;
    setState(() { _answers[part] = value; _feedback.remove(_task.id); });
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 250), _persist);
  }

  Future<void> _go(int index) async {
    if (_busy || _finished || index == _index) return;
    _draftTimer?.cancel();
    _accountTime();
    setState(() => _index = index.clamp(0, widget.tasks.length - 1));
    if (_scroll.hasClients) _scroll.jumpTo(0);
    await _openTask();
  }

  KompassAttempt? _existing(KompassTask task) {
    for (final attempt in widget.store.attempts) {
      if (attempt.id == '$_sessionId:${task.id}') return attempt;
    }
    return null;
  }

  Future<void> _recordTask(KompassTask task) async {
    final responses = Map<String, dynamic>.from(
        jsonDecode(jsonEncode(_responses[task.id] ?? {})) as Map);
    final hints = _hints[task.id] ?? 0;
    final milliseconds = (_activeMillis[task.id] ?? 0) +
        (task.id == _task.id ? _clock.elapsedMilliseconds : 0);
    final previous = _existing(task);
    final attempted = KompassScorer.score(task, responses).attempted;
    if (previous == null) {
      await widget.store.record(KompassAttempt.forTask(
        id: '$_sessionId:${task.id}', sessionId: _sessionId, task: task,
        packVersion: widget.pack.version, mode: widget.mode,
        firstResponses: responses, hintsUsed: hints,
        activeSeconds: milliseconds ~/ 1000, completed: attempted,
      ));
    } else {
      // Keep manually reviewed points when revisiting the same saved response.
      final manualPoints = <String, double>{
        for (final part in previous.score.parts)
          if (part.manual && part.reviewed &&
              jsonEncode(previous.responses[part.partId]) == jsonEncode(responses[part.partId]))
            part.partId: part.awardedPoints,
      };
      await widget.store.revise(previous.reviseTask(task: task, responses: responses,
          hintsUsed: hints, activeSeconds: milliseconds ~/ 1000,
          completed: attempted, manualPoints: manualPoints));
    }
  }

  Future<void> _submitPractice() async {
    if (_busy || !_practice || _finished) return;
    setState(() => _busy = true);
    try {
      await _recordTask(_task);
      _feedback.add(_task.id);
      await _persist();
    } catch (_) { _showSaveError(); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _hint() async {
    if (!_practice || _busy || _finished) return;
    setState(() => _hints[_task.id] = (_hints[_task.id] ?? 0) + 1);
    await _persist();
  }

  Future<void> _finish({bool expired = false}) async {
    if (_busy || _finished || _invalidSession) return;
    if (_confirming) {
      if (expired && _confirmationContext?.mounted == true) {
        Navigator.of(_confirmationContext!).pop(true);
        _confirmationContext = null;
      }
      return;
    }
    if (!expired) {
      _confirming = true;
      final answered = widget.tasks.where((t) =>
          KompassScorer.score(t, _responses[t.id] ?? {}).attempted).length;
      final confirm = await showDialog<bool>(context: context, builder: (context) {
        _confirmationContext = context;
        return AlertDialog(
        title: Text(kc(_german, 'Runde abschließen?', 'Finish this session?')),
        content: Text(kc(_german,
            '$answered von ${widget.tasks.length} Aufgaben sind bearbeitet. Danach kannst du Lösungen und Begründungen ansehen.',
            '$answered of ${widget.tasks.length} tasks have responses. You can then review solutions and explanations.')),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: Text(kc(_german, 'Weiterarbeiten', 'Keep working'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(kc(_german, 'Abschließen', 'Finish')))],
      );
      });
      _confirmationContext = null;
      _confirming = false;
      if (confirm != true || !mounted || _finished || _busy) return;
      expired = _deadline != null && _remaining == 0;
    }
    setState(() => _busy = true);
    _draftTimer?.cancel();
    _accountTime();
    _clock.stop();
    try {
      for (final task in widget.tasks) { await _recordTask(task); }
      // No timer/debounce/dispose save is allowed to resurrect a completed round.
      _finished = true;
      _ticker?.cancel();
      await widget.store.clearSession(sessionId: _sessionId);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) =>
          KompassReviewScreen(pack: widget.pack, store: widget.store,
              attemptIds: widget.tasks.map((t) => '$_sessionId:${t.id}').toList(),
              expired: expired)));
    } catch (_) {
      _finished = false;
      if (_foreground) _clock.start();
      _startTicker();
      _showSaveError();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_invalidSession || _finished) return;
    if (_foreground) {
      _clock.start();
      if (_deadline != null && _remaining == 0) _finish(expired: true);
    } else {
      _accountTime(); _clock.stop(); _persist();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel(); _draftTimer?.cancel();
    _accountTime(); _clock.stop();
    _persist();
    _scroll.dispose();
    super.dispose();
  }

  String get _modeTitle => switch (widget.mode) {
    KompassMode.practice => kc(_german, 'Lernen & Üben', 'Learn and practise'),
    KompassMode.check => kc(_german, 'Selbstständig lösen', 'Independent check'),
    KompassMode.rehearsal => kc(_german, 'Probelauf', 'Rehearsal'),
    KompassMode.lab => kc(_german, 'Mathe-Labor', 'Math lab'),
  };

  @override
  Widget build(BuildContext context) => KompassPage(
    title: _modeTitle,
    actions: [
      if (_practice) IconButton(tooltip: kc(_german, 'Mathematische Wörter', 'Mathematical words'),
          onPressed: () => showKompassGlossary(context, _german), icon: const Icon(Icons.menu_book_outlined)),
      if (_deadline != null && !_invalidSession) Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Center(child: Semantics(label: kc(_german, 'Verbleibende Zeit', 'Time remaining'),
          child: Text('${_remaining ~/ 60}:${(_remaining % 60).toString().padLeft(2, '0')}',
            key: const ValueKey('kompass-time'), style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()])))),
      ),
    ],
    child: _invalidSession ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(
        kc(_german, 'Diese gespeicherte Runde gehört zu einer anderen Inhaltsfassung. Bitte beginne eine neue Runde. Deine abgeschlossenen Aufzeichnungen bleiben erhalten.',
            'This saved session uses a different content version. Please start a new session. Your completed records are kept.')))) : Builder(builder: _body),
  );

  Widget _body(BuildContext context) {
    final task = _task;
    final attempt = _existing(task);
    final showingFeedback = _practice && _feedback.contains(task.id) && attempt != null;
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        if (_saveError != null) MaterialBanner(content: Text(_saveError!), actions: [
          TextButton(onPressed: _persist, child: Text(kc(_german, 'Erneut speichern', 'Retry save')))]),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (var i = 0; i < widget.tasks.length; i++)
            ChoiceChip(key: ValueKey('kompass-task-nav-$i'),
              label: Text('${i + 1}${(_responses[widget.tasks[i].id]?.isNotEmpty ?? false) ? ' •' : ''}'),
              selected: i == _index, onSelected: _busy ? null : (_) => _go(i)),
        ]),
        const SizedBox(height: 16),
        Text('${_index + 1} / ${widget.tasks.length} · ${kompassDomainLabel(task.domain, _german)}',
            style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Text(kompassText(task.title, _german), style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        SelectableText(kompassText(task.prompt, _german), style: const TextStyle(fontSize: 18, height: 1.5)),
        if (task.figure != null) Padding(padding: const EdgeInsets.symmetric(vertical: 16),
            child: KompassFigureView(figure: task.figure!, german: _german, plain: !_practice)),
        const SizedBox(height: 12),
        for (final part in task.parts) Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: KompassPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(kompassText(part.prompt, _german), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            if (part.figure != null && part.kind != 'cells')
              Padding(padding: const EdgeInsets.only(bottom: 12),
                  child: KompassFigureView(figure: part.figure!, german: _german, plain: !_practice)),
            _input(part),
            if (showingFeedback)
            if (attempt.score.partById(part.id) case final result?) ...[
              const SizedBox(height: 12),
              Semantics(liveRegion: true, child: Text(
                result.pendingReview ? kc(_german, 'Deine Begründung wird mit den Kriterien am Ende geprüft.', 'Review your explanation against the criteria at the end.') :
                result.correct ? kc(_german, 'Das stimmt.', 'That is correct.') :
                result.carriedError ? kc(_german, 'Dieser Schritt passt zu deinem Zwischenergebnis.', 'This step follows correctly from your intermediate result.') :
                result.feedback != null ? kompassText(result.feedback, _german) :
                kc(_german, 'Prüfe deinen Lösungsweg. Ein Hinweis kann helfen.', 'Check your approach. A hint may help.'),
                style: TextStyle(color: result.correct ? const Color(0xFF176746) : const Color(0xFF844015)),
              )),
            ],
          ])),
        ),
        if (_practice) ...[
          Wrap(spacing: 10, runSpacing: 10, children: [
            FilledButton.icon(key: const ValueKey('kompass-check-answer'),
              onPressed: _busy ? null : _submitPractice, icon: const Icon(Icons.check),
              label: Text(kc(_german, 'Antwort prüfen', 'Check answer'))),
            if (task.hints.isNotEmpty) OutlinedButton.icon(key: const ValueKey('kompass-hint'),
              onPressed: _busy || (_hints[task.id] ?? 0) >= task.hints.length ? null : _hint,
              icon: const Icon(Icons.lightbulb_outline), label: Text(kc(_german, 'Hinweis', 'Hint'))),
          ]),
          for (var i = 0; i < (_hints[task.id] ?? 0).clamp(0, task.hints.length); i++)
            Padding(padding: const EdgeInsets.only(top: 12), child: Text(
              '${i + 1}. ${kompassText(task.hints[i], _german)}')),
          if (showingFeedback) ExpansionTile(
            key: ValueKey('solution-${task.id}'),
            title: Text(kc(_german, 'Lösungsweg ansehen', 'View the worked solution')),
            children: [Padding(padding: const EdgeInsets.all(16),
              child: SelectableText(kompassText(task.solution, _german)))],
          ),
        ] else Text(kc(_german,
            'Du kannst Antworten ändern und später zu dieser Aufgabe zurückkehren. Rückmeldung gibt es nach dem Abschließen.',
            'You can edit answers and return to this task. Feedback appears after finishing.')),
        const SizedBox(height: 24),
        Wrap(spacing: 10, runSpacing: 10, children: [
          if (_index > 0) OutlinedButton(onPressed: _busy ? null : () => _go(_index - 1),
              child: Text(kc(_german, 'Vorherige Aufgabe', 'Previous task'))),
          if (_index < widget.tasks.length - 1) FilledButton.tonal(
              key: const ValueKey('kompass-next-task'), onPressed: _busy ? null : () => _go(_index + 1),
              child: Text(kc(_german, 'Weiter / überspringen', 'Next / skip'))),
          OutlinedButton(key: const ValueKey('kompass-finish'), onPressed: _busy ? null : _finish,
              child: Text(kc(_german, 'Runde abschließen', 'Finish session'))),
        ]),
        if (_busy) const Padding(padding: EdgeInsets.only(top: 16), child: LinearProgressIndicator()),
      ],
    );
  }

  Widget _input(KompassPart part) {
    final value = _answers[part.id];
    switch (part.kind) {
      case 'choice':
        return Wrap(spacing: 8, runSpacing: 8, children: [
          for (final option in part.options) ChoiceChip(
            key: ValueKey('answer-${_task.id}-${part.id}-${option['id']}'),
            label: Text(kompassText(option['label'], _german)), selected: value == option['id'],
            onSelected: _busy ? null : (_) => _change(part.id, option['id'])),
        ]);
      case 'multiChoice':
        final selected = (value as List? ?? []).whereType<String>().toSet();
        return Wrap(spacing: 8, runSpacing: 8, children: [
          for (final option in part.options) FilterChip(
            label: Text(kompassText(option['label'], _german)), selected: selected.contains(option['id']),
            onSelected: _busy ? null : (on) {
              final next = Set<String>.from(selected);
              if (on) { next.add(option['id'] as String); } else { next.remove(option['id']); }
              _change(part.id, next.toList());
            }),
        ]);
      case 'cells':
        return KompassCellInput(figure: part.figure ?? _task.figure ?? const {
          'kind': 'grid', 'data': {'rows': 5, 'cols': 5}, 'alt': {'de': 'Raster', 'en': 'Grid'}},
          selected: (value as List? ?? []).whereType<String>().toSet(),
          german: _german, enabled: !_busy,
          onChanged: (selection) => _change(part.id, selection.toList()));
      case 'order':
        final sequence = (value as List? ?? []).whereType<String>().toList();
        String label(String id) => kompassText(part.options.firstWhere(
            (o) => o['id'] == id, orElse: () => {'label': id})['label'], _german);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(kc(_german, 'Wähle die Einträge nacheinander. Du kannst einen gewählten Eintrag wieder entfernen.',
              'Choose entries in order. You can remove a selected entry.')),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (var i = 0; i < sequence.length; i++) InputChip(
              label: Text('${i + 1}. ${label(sequence[i])}'),
              onDeleted: _busy ? null : () { final next = List<String>.from(sequence)..removeAt(i); _change(part.id, next); }),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final option in part.options) OutlinedButton(
              onPressed: _busy || sequence.contains(option['id']) ? null :
                  () => _change(part.id, [...sequence, option['id'] as String]),
              child: Text(kompassText(option['label'], _german))),
          ]),
        ]);
      default:
        return TextFormField(
          key: ValueKey('answer-${_task.id}-${part.id}'),
          initialValue: value?.toString() ?? '',
          enabled: !_busy,
          keyboardType: part.kind == 'number'
              ? const TextInputType.numberWithOptions(decimal: true, signed: true)
              : TextInputType.multiline,
          minLines: part.kind == 'text' ? 2 : 1,
          maxLines: part.kind == 'text' ? 5 : 1,
          decoration: InputDecoration(
            labelText: kc(_german, 'Deine Antwort', 'Your answer'),
            suffixText: part.unit.isEmpty ? null : part.unit,
            helperText: part.kind == 'text' ? kc(_german,
                'Du kannst deine Erklärung auch auf Papier notieren und hier „auf Papier“ eintragen.',
                'You may write your explanation on paper and enter “on paper” here.') : null,
            helperMaxLines: 4,
          ),
          onChanged: (text) => _change(part.id, text),
        );
    }
  }
}
