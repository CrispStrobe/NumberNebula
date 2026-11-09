import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/services/profile_preferences.dart';
import '../widgets/kompass_cell_input.dart';
import '../widgets/kompass_figure_view.dart';
import 'kompass_lab_round.dart';

/// Four untimed, locally resumable workshops. Completions report practice only.
/// The first submitted response and its points never change after a retry.
class KompassLabScreen extends StatefulWidget {
  final String labId;
  final bool german;
  final FutureOr<void> Function(Map<String, dynamic> result)? onCompleted;

  const KompassLabScreen({
    super.key,
    required this.labId,
    required this.german,
    this.onCompleted,
  });

  @override
  State<KompassLabScreen> createState() => KompassLabScreenState();
}

class KompassLabScreenState extends State<KompassLabScreen>
    with WidgetsBindingObserver {
  // Reads and writes share a queue across routes. Reopening a lab must observe
  // the previous route's final snapshot before it can edit the same player data.
  static final Map<(String, String), Future<void>> _storageOperations = {};
  static final Map<(String, String), Object> _storageOwners = {};
  final Object _storageOwner = Object();
  ProfilePreferences? _preferences;
  final Stopwatch _clock = Stopwatch();
  int _storedMillis = 0, _seed = 0, _index = 0, _hintsUsed = 0, _attempts = 0;
  int? _firstPoints;
  bool? _firstCorrect;
  bool _loaded = false, _completed = false, _reported = false;
  bool _foreground = true, _visible = true, _saveFailed = false;
  bool _recording = false, _reportFailed = false;
  String _sessionId = '';
  Map<String, dynamic> _response = {}, _firstResponse = {};
  KompassLabRound? _round;
  KompassLabCheck? _feedback;
  String get _storageKey => 'kompass_lab_v1_${widget.labId}';
  String get _roundId => '$_sessionId:$_index';
  int get _activeMillis => _storedMillis + _clock.elapsedMilliseconds;
  bool get _ownsStorage {
    final prefs = _preferences;
    return prefs != null &&
        identical(_storageOwners[(prefs.profileId, _storageKey)], _storageOwner);
  }

  bool get _editable =>
      mounted &&
      _loaded &&
      !_completed &&
      _ownsStorage &&
      _preferences?.profileId == ProfilePreferences.activeId;
  bool get _german => widget.german;
  String _t(String de, String en) => _german ? de : en;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground = WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    unawaited(_load());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible = TickerMode.valuesOf(context).enabled;
    _syncClock();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncClock();
    if (!_foreground) unawaited(_save());
  }

  void _syncClock() {
    if (_loaded &&
        !_completed &&
        _foreground &&
        _visible &&
        _ownsStorage &&
        _preferences?.profileId == ProfilePreferences.activeId) {
      _clock.start();
    } else {
      _clock.stop();
    }
  }

  Future<void> _load() async {
    if (!kompassLabIds.contains(widget.labId)) {
      if (mounted) setState(() => _loaded = true);
      return;
    }
    // getInstance captures the active profile before its first await.
    final captured = ProfilePreferences.getInstance();
    final prefs = await captured;
    await _enqueueStorage<void>((prefs.profileId, _storageKey), () {
      if (!mounted) return;
      _preferences = prefs;
      _storageOwners[(prefs.profileId, _storageKey)] = _storageOwner;
      _restore(prefs);
    });
    if (!mounted || !_ownsStorage) return;
    setState(() => _loaded = true);
    _syncClock();
    await _save();
  }

  void _restore(ProfilePreferences prefs) {
    final now = DateTime.now().microsecondsSinceEpoch;
    _seed = now % 2147483647;
    _sessionId = '${widget.labId}:$now';
    try {
      final raw = prefs.getString(_storageKey);
      final saved = raw == null ? null : jsonDecode(raw);
      if (saved is Map &&
          saved['schemaVersion'] == 1 &&
          saved['labId'] == widget.labId) {
        _seed = (saved['seed'] as num).toInt();
        _sessionId = saved['sessionId'] as String;
        _index = (saved['index'] as num).toInt().clamp(0, 1000000);
        _storedMillis =
            (saved['activeMillis'] as num? ?? 0).toInt().clamp(0, 86400000);
        _hintsUsed = (saved['hintsUsed'] as num? ?? 0).toInt().clamp(0, 3);
        _attempts = (saved['attempts'] as num? ?? 0).toInt().clamp(0, 100000);
        _firstCorrect = saved['firstCorrect'] as bool?;
        _firstPoints = (saved['firstPoints'] as num?)?.toInt();
        _completed = saved['completed'] == true;
        _reported = saved['reported'] == true;
        _response = Map<String, dynamic>.from(saved['response'] as Map);
        _firstResponse =
            Map<String, dynamic>.from(saved['firstResponse'] as Map? ?? {});
      }
    } catch (_) {
      // A damaged lab save cannot erase any game/profile or course evidence.
      _index = 0;
      _storedMillis = 0;
      _hintsUsed = 0;
      _attempts = 0;
      _firstCorrect = null;
      _firstPoints = null;
      _completed = false;
      _reported = false;
      _response = {};
      _firstResponse = {};
    }
    _round = generateKompassLabRound(widget.labId, _index, _seed);
    _response = _round!.normalizeResponse(_response);
    if (_attempts > 0) _feedback = _round!.check(_response);
  }

  static Future<T> _enqueueStorage<T>(
    (String, String) scope,
    FutureOr<T> Function() action,
  ) {
    final previous = _storageOperations[scope] ?? Future<void>.value();
    final operation = previous.then((_) => action());
    _storageOperations[scope] = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return operation;
  }

  /// JSON-compatible snapshot for support, export and deterministic replay.
  /// The saved profile instance owns writes even if the global profile changes.
  Map<String, dynamic> exportState() => _copy({
        'schemaVersion': 1,
        'labId': widget.labId,
        'sessionId': _sessionId,
        'seed': _seed,
        'index': _index,
        'roundId': _roundId,
        'response': _response,
        'firstResponse': _firstResponse,
        'firstCorrect': _firstCorrect,
        'firstPoints': _firstPoints,
        'hintsUsed': _hintsUsed,
        'attempts': _attempts,
        'activeMillis': _activeMillis,
        'completed': _completed,
        'reported': _reported,
      });

  Future<void> _save() {
    final prefs = _preferences;
    if (!_loaded || prefs == null || _round == null || !_ownsStorage) {
      return Future<void>.value();
    }
    final payload = jsonEncode(exportState());
    final key = _storageKey;
    final scope = (prefs.profileId, key);
    return _enqueueStorage<void>(scope, () async {
      // A completion callback may return after a new route resumed this lab.
      // It still may finish its idempotent course record, but cannot replace
      // the new route's draft, round index or immutable first response.
      if (!identical(_storageOwners[scope], _storageOwner)) return;
      final saved = await prefs.setString(key, payload);
      if (mounted && _ownsStorage && _saveFailed == saved) {
        setState(() => _saveFailed = !saved);
      }
    }).catchError((Object _, StackTrace __) {
      if (mounted && _ownsStorage) setState(() => _saveFailed = true);
    });
  }

  void _edit(String field, Object value) {
    if (!_editable) return;
    setState(() {
      _response[field] = value;
      _feedback = null;
    });
    unawaited(_save());
  }

  void _hint() {
    if (!_editable || _hintsUsed >= 3) return;
    setState(() => _hintsUsed++);
    unawaited(_save());
  }

  void _check() {
    if (!_editable) return;
    final round = _round!;
    final check = round.check(_response);
    setState(() {
      _firstCorrect ??= check.correct;
      _firstPoints ??= check.points;
      if (_attempts == 0) _firstResponse = _copy(_response);
      _attempts++;
      _feedback = check;
      _completed = check.correct;
    });
    _syncClock();
    if (_completed && !_reported) {
      unawaited(_deliverCompletion());
    } else {
      unawaited(_save());
    }
  }

  Future<void> _deliverCompletion() async {
    if (!mounted ||
        !_ownsStorage ||
        !_completed ||
        _reported ||
        _recording ||
        _preferences?.profileId != ProfilePreferences.activeId) {
      return;
    }
    setState(() {
      _recording = true;
      _reportFailed = false;
    });
    // Persist a completed, pending round before awaiting the course store.
    // A failed store write remains retryable after leaving and reopening.
    await _save();
    if (!mounted ||
        !_ownsStorage ||
        _preferences?.profileId != ProfilePreferences.activeId) {
      _recording = false;
      return;
    }
    final round = _round!;
    final result = <String, dynamic>{
      'labId': widget.labId,
      'roundId': _roundId,
      'skillIds': List<String>.of(round.skillIds),
      'mode': 'practice',
      'practiceOnly': true,
      'firstCorrect': _firstCorrect,
      'hintsUsed': _hintsUsed,
      'activeSeconds': (_activeMillis / 1000).round(),
      'response': _copy(_firstResponse),
      'finalResponse': _copy(_response),
      'attempts': _attempts,
      'maxPoints': round.check(_response).maxPoints,
      'awardedPoints': _firstPoints,
      'completedCorrect': true,
    };
    try {
      await widget.onCompleted?.call(Map<String, dynamic>.unmodifiable(result));
      if (!_ownsStorage) return;
      _reported = true;
      await _save();
    } catch (_) {
      _reportFailed = true;
      // Keep the same round ID and immutable first response for an idempotent
      // retry. Never award progress merely because a callback was invoked.
    } finally {
      _recording = false;
      if (mounted) setState(() {});
    }
  }

  void _next() {
    if (!mounted ||
        !_ownsStorage ||
        !_loaded ||
        !_completed ||
        !_reported ||
        _recording ||
        _preferences?.profileId != ProfilePreferences.activeId) {
      return;
    }
    setState(() {
      _index++;
      _round = generateKompassLabRound(widget.labId, _index, _seed);
      _response = _round!.createResponse();
      _firstResponse = {};
      _firstCorrect = null;
      _firstPoints = null;
      _hintsUsed = 0;
      _attempts = 0;
      _completed = false;
      _reported = false;
      _reportFailed = false;
      _feedback = null;
      _storedMillis = 0;
      _clock.reset();
    });
    _syncClock();
    unawaited(_save());
  }

  @override
  void dispose() {
    _clock.stop();
    unawaited(_save());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData.dark(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: const Color(0xFF0B1426),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6BCDD9),
        brightness: Brightness.dark,
      ),
    );
    return Theme(
      data: theme,
      child: Builder(builder: (context) {
        final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
        final round = _round;
        return Scaffold(
          appBar: AppBar(
            toolbarHeight: math.max(64, 46 * scale),
            title: Text(kompassLabTitle(widget.labId, _german),
                maxLines: 2, style: const TextStyle(fontSize: 20)),
          ),
          body: SafeArea(
            child: !_loaded
                ? const Center(child: CircularProgressIndicator())
                : round == null
                    ? Center(
                        child: Text(_t('Dieses Lernlabor ist nicht verfügbar.',
                            'This learning lab is unavailable.')))
                    : Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 960),
                          child: SingleChildScrollView(
                            key: const ValueKey('kompass_lab_scroll'),
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Wrap(spacing: 12, runSpacing: 8, children: [
                                  Chip(
                                      label: Text(_t(
                                          'Ohne Zeitlimit', 'No time limit'))),
                                  Chip(
                                      label: Text(_t('Runde ${_index + 1}',
                                          'Round ${_index + 1}'))),
                                ]),
                                const SizedBox(height: 12),
                                Text(round.title(_german),
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall),
                                const SizedBox(height: 12),
                                Text(round.prompt(_german),
                                    style: const TextStyle(
                                        fontSize: 18, height: 1.5)),
                                const SizedBox(height: 16),
                                ..._activity(context, round),
                                const SizedBox(height: 20),
                                if (_hintsUsed > 0)
                                  _panel(
                                      context,
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(_t('Hilfen', 'Hints'),
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold)),
                                          for (final hint in round
                                              .hints(_german)
                                              .take(_hintsUsed))
                                            Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 10),
                                                child: Text(hint)),
                                        ],
                                      )),
                                if (_feedback != null)
                                  Semantics(
                                    liveRegion: true,
                                    child: _panel(
                                        context,
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                                _completed
                                                    ? _t('Geschafft!',
                                                        'Completed!')
                                                    : _t('Noch ein Versuch',
                                                        'Try again'),
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 20)),
                                            const SizedBox(height: 8),
                                            Text(_feedback!.feedback(_german)),
                                            if (_completed &&
                                                _firstCorrect == false) ...[
                                              const SizedBox(height: 10),
                                              Text(_t(
                                                  'Du hast deine Lösung verbessert. Der erste Versuch bleibt im Übungsprotokoll erhalten.',
                                                  'You improved your solution. Your first attempt stays in the practice record.')),
                                            ],
                                          ],
                                        )),
                                  ),
                                const SizedBox(height: 12),
                                Wrap(spacing: 12, runSpacing: 12, children: [
                                  if (!_completed)
                                    FilledButton.icon(
                                      key: const ValueKey('lab_check'),
                                      onPressed: _editable ? _check : null,
                                      icon: const Icon(Icons.check),
                                      label: Text(_t('Prüfen', 'Check')),
                                    ),
                                  if (!_completed)
                                    OutlinedButton.icon(
                                      key: const ValueKey('lab_hint'),
                                      onPressed: _editable && _hintsUsed < 3
                                          ? _hint
                                          : null,
                                      icon: const Icon(Icons.lightbulb_outline),
                                      label: Text(_t(
                                          'Hilfe ${math.min(_hintsUsed + 1, 3)}/3',
                                          'Hint ${math.min(_hintsUsed + 1, 3)}/3')),
                                    ),
                                  if (_completed)
                                    FilledButton.icon(
                                      key: const ValueKey('lab_next'),
                                      onPressed: _reported && !_recording
                                          ? _next
                                          : null,
                                      icon: const Icon(Icons.arrow_forward),
                                      label: Text(
                                          _t('Nächste Runde', 'Next round')),
                                    ),
                                ]),
                                if (_completed && !_reported) ...[
                                  const SizedBox(height: 12),
                                  Text(_recording
                                      ? _t('Übungsrunde wird gespeichert …',
                                          'Saving practice round …')
                                      : _reportFailed
                                          ? _t(
                                              'Die Runde ist gelöst. Das Übungsprotokoll konnte noch nicht gespeichert werden.',
                                              'The round is solved. Its practice record could not be saved yet.')
                                          : _t(
                                              'Die gelöste Runde wartet noch auf ihren Eintrag im Übungsprotokoll.',
                                              'This solved round is waiting to be added to the practice record.')),
                                  if (!_recording)
                                    Align(
                                        alignment: Alignment.centerLeft,
                                        child: OutlinedButton(
                                          key: const ValueKey(
                                              'lab_retry_record'),
                                          onPressed: () =>
                                              unawaited(_deliverCompletion()),
                                          child: Text(_t(
                                              'Übungsrunde speichern',
                                              'Save practice round')),
                                        )),
                                ],
                                const SizedBox(height: 20),
                                Text(
                                    _t('Diese Lernlabor-Runden sind Übung. Eigenständige Lernstandschecks findest du im Kurs.',
                                        'These lab rounds are practice. Independent checks are available in the course.'),
                                    style: const TextStyle(
                                        fontSize: 14, color: Colors.white70)),
                                if (_saveFailed) ...[
                                  const SizedBox(height: 12),
                                  Text(_t(
                                      'Der lokale Zwischenstand konnte gerade nicht gespeichert werden.',
                                      'The local session could not be saved just now.')),
                                  TextButton(
                                      onPressed: () => unawaited(_save()),
                                      child: Text(_t(
                                          'Speichern erneut versuchen',
                                          'Retry saving'))),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
          ),
        );
      }),
    );
  }

  List<Widget> _activity(BuildContext context, KompassLabRound round) {
    final config = round.config;
    switch (round.type) {
      case 'buildNumber':
      case 'regroup':
        final counts = intList(_response['counts']);
        final labels = _german
            ? ['Tausender', 'Hunderter', 'Zehner', 'Einer']
            : ['Thousands', 'Hundreds', 'Tens', 'Ones'];
        return [
          _figure(
              'placeValue',
              {
                'columns': [
                  for (var i = 0; i < 4; i++)
                    {'label': labels[i], 'value': counts[i]},
                ]
              },
              _t('Stellenwerte von links nach rechts: ${counts.join(', ')}.',
                  'Place values from left to right: ${counts.join(', ')}.')),
          Text(
              _t('Aktueller Wert: ${placeValueTotal(counts)}',
                  'Current value: ${placeValueTotal(counts)}'),
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(spacing: 12, runSpacing: 12, children: [
            for (var i = 0; i < 4; i++)
              _counter(context, 'place_$i', labels[i], counts[i], (value) {
                final next = List<int>.of(counts)..[i] = value;
                _edit('counts', next);
              }, max: 29),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (var i = 3; i > 0; i--)
              OutlinedButton(
                key: ValueKey('lab_trade_$i'),
                onPressed: !_editable || counts[i] < 10
                    ? null
                    : () {
                        final next = List<int>.of(counts);
                        next[i] -= 10;
                        next[i - 1]++;
                        _edit('counts', next);
                      },
                child: Text(_t('10 ${labels[i]} → 1 ${labels[i - 1]}',
                    '10 ${labels[i]} → 1 ${labels[i - 1]}')),
              ),
          ]),
        ];
      case 'numberLine':
        final min = config['min'] as int, max = config['max'] as int;
        final step = config['step'] as int;
        final value = numberAt(_response, 'value').clamp(min, max);
        return [
          _figure(
              'numberLine',
              {
                'min': min,
                'max': max,
                'step': step,
                'marks': [
                  {'value': value, 'label': '$value'}
                ]
              },
              _t('Zahlenstrahl von $min bis $max. Deine Markierung: $value.',
                  'Number line from $min to $max. Your marker: $value.')),
          Semantics(
              label:
                  _t('Markierung auf dem Zahlenstrahl', 'Number-line marker'),
              child: Slider(
                  key: const ValueKey('lab_number_slider'),
                  min: min.toDouble(),
                  max: max.toDouble(),
                  value: value.toDouble(),
                  divisions: (max - min) ~/ step,
                  label: '$value',
                  onChanged: _editable
                      ? (v) => _edit('value', (v / step).round() * step)
                      : null)),
          _counter(context, 'marker', _t('Markierung', 'Marker'), value,
              (v) => _edit('value', v),
              min: min, max: max, step: step),
          Text(_t(
              'Abstände: ${value - min} nach links, ${max - value} nach rechts.',
              'Distances: ${value - min} to the left, ${max - value} to the right.')),
        ];
      case 'shopping':
        final prices = intList(config['prices']),
            quantities = intList(config['quantities']);
        final coins = intList(_response['coins']);
        return [
          _figure(
              'table',
              {
                'headers': [
                  _t('Ware', 'Item'),
                  _t('Einzelpreis', 'Unit price'),
                  _t('Anzahl', 'Quantity')
                ],
                'rows': [
                  [
                    _t('Saft', 'Juice'),
                    labMoney(prices[0], _german),
                    quantities[0]
                  ],
                  [
                    _t('Brötchen', 'Bread rolls'),
                    labMoney(prices[1], _german),
                    quantities[1]
                  ],
                ]
              },
              _t('Kassenbon mit Einzelpreisen und Anzahlen.',
                  'Receipt with unit prices and quantities.')),
          _numberField(
              'total', _t('Gesamtpreis in Euro', 'Total price in euros'),
              unit: '€'),
          const SizedBox(height: 16),
          Text(
              _t('Dein Wechselgeld: ${labMoney(coinTotal(coins), true)}',
                  'Your change: ${labMoney(coinTotal(coins), false)}'),
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(spacing: 12, runSpacing: 12, children: [
            for (var i = 0; i < labCoinValues.length; i++)
              _counter(context, 'coin_$i', labMoney(labCoinValues[i], _german),
                  coins[i], (value) {
                final next = List<int>.of(coins)..[i] = value;
                _edit('coins', next);
              }, max: 30),
          ]),
        ];
      case 'elapsed':
        final hour = numberAt(_response, 'hour'),
            minute = numberAt(_response, 'minute');
        return [
          _figure(
              'clock',
              {'hour': hour, 'minute': minute},
              _t('Deine Uhr zeigt ${labTime(hour, minute)}.',
                  'Your clock shows ${labTime(hour, minute)}.')),
          Text(labTime(hour, minute),
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(spacing: 12, runSpacing: 12, children: [
            _counter(context, 'hour', _t('Stunden', 'Hours'), hour,
                (v) => _edit('hour', v),
                max: 23),
            _counter(context, 'minute', _t('Minuten', 'Minutes'), minute,
                (v) => _edit('minute', v),
                max: 55, step: 5),
          ]),
        ];
      case 'capacity':
        final bottles = numberAt(_response, 'bottles'),
            cups = numberAt(_response, 'cups');
        return [
          _figure(
              'table',
              {
                'headers': [_t('Gefäß', 'Container'), _t('Inhalt', 'Capacity')],
                'rows': [
                  [_t('Flasche', 'Bottle'), '1000 ml'],
                  [_t('Becher', 'Cup'), '250 ml']
                ]
              },
              _t('Eine Flasche: 1000 ml. Ein Becher: 250 ml.',
                  'A bottle: 1000 ml. A cup: 250 ml.')),
          Wrap(spacing: 12, runSpacing: 12, children: [
            _counter(context, 'bottles', _t('1-l-Flaschen', '1-litre bottles'),
                bottles, (v) => _edit('bottles', v),
                max: 10),
            _counter(context, 'cups', _t('250-ml-Becher', '250-ml cups'), cups,
                (v) => _edit('cups', v),
                max: 24),
          ]),
          const SizedBox(height: 12),
          Text(
              _t('Abgefüllt: ${bottles * 1000 + cups * 250} ml',
                  'Measured: ${bottles * 1000 + cups * 250} ml'),
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ];
      case 'length':
        return [
          _figure(
              'measureLine',
              {
                'start': config['start'],
                'end': config['end'],
                'step': 1,
                'unit': 'cm'
              },
              _t('Das Band liegt auf dem Lineal von ${config['start']} cm bis ${config['end']} cm.',
                  'The strip lies from ${config['start']} cm to ${config['end']} cm on the ruler.')),
          _numberField('millimetres',
              _t('Länge in Millimetern', 'Length in millimetres'),
              unit: 'mm'),
        ];
      case 'buildChart':
        final labels = _german
            ? ['Äpfel', 'Birnen', 'Pflaumen']
            : ['Apples', 'Pears', 'Plums'];
        final expected = intList(config['values']),
            values = intList(_response['values']);
        return [
          _figure(
              'table',
              {
                'headers': [_t('Obst', 'Fruit'), _t('Anzahl', 'Count')],
                'rows': [
                  for (var i = 0; i < 3; i++) [labels[i], expected[i]]
                ]
              },
              _t('Die Tabelle gibt die Anzahlen für drei Obstsorten vor.',
                  'The table gives counts for three types of fruit.')),
          _figure(
              'barChart',
              {
                'labels': labels,
                'values': values,
                'max': 12,
                'step': 2,
                'yLabel': _t('Anzahl', 'Count')
              },
              _t('Deine Säulenhöhen: ${values.join(', ')}.',
                  'Your bar heights: ${values.join(', ')}.')),
          Wrap(spacing: 12, runSpacing: 12, children: [
            for (var i = 0; i < 3; i++)
              _counter(context, 'bar_$i', labels[i], values[i], (v) {
                final next = List<int>.of(values)..[i] = v;
                _edit('values', next);
              }, max: 12),
          ]),
        ];
      case 'chance':
      case 'event':
        final red = config['red'] as int;
        final blue = round.type == 'chance'
            ? numberAt(_response, 'blue')
            : config['blue'] as int;
        final draws = stringList(_response['draws']);
        return [
          _figure(
              'tokenBag',
              {
                'tokens': [
                  {'label': _t('★ Stern', '★ Star'), 'count': red},
                  {'label': _t('● Kreis', '● Circle'), 'count': blue},
                ]
              },
              _t('$red Sterne und $blue Kreise. Alle Steine sind gleich groß.',
                  '$red stars and $blue circles. All tokens have the same size.')),
          if (round.type == 'chance')
            _counter(context, 'blue', _t('Kreissteine', 'Circle tokens'), blue,
                (v) {
              _edit('blue', v);
              _edit('draws', <String>[]);
            }, max: 12),
          if (round.type == 'event')
            Wrap(spacing: 10, runSpacing: 10, children: [
              for (final item in [
                ('certain', _t('Sicher', 'Certain')),
                (
                  'possible',
                  _t('Möglich, aber nicht sicher', 'Possible, but not certain')
                ),
                ('impossible', _t('Unmöglich', 'Impossible')),
              ])
                ChoiceChip(
                    key: ValueKey('lab_event_${item.$1}'),
                    label: Text(item.$2),
                    selected: _response['answer'] == item.$1,
                    onSelected:
                        _editable ? (_) => _edit('answer', item.$1) : null),
            ]),
          const SizedBox(height: 12),
          Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                key: const ValueKey('lab_draw'),
                onPressed: !_editable || draws.length >= 50
                    ? null
                    : () {
                        final random = math.Random(
                            _seed + _index * 7919 + draws.length * 421);
                        final next = List<String>.of(draws)
                          ..add(random.nextInt(red + blue) < red
                              ? 'star'
                              : 'circle');
                        _edit('draws', next);
                      },
                icon: const Icon(Icons.shuffle),
                label: Text(_t('Probe ziehen und zurücklegen',
                    'Draw a trial token and replace it')),
              )),
          Text(_t(
              'Jeder gezogene Stein kommt zurück. Die Zusammensetzung bleibt gleich. Eine kurze Serie beweist keine Wahrscheinlichkeit.',
              'Every drawn token goes back. The composition stays the same. A short series does not prove a probability.')),
          if (draws.isNotEmpty) ...[
            const SizedBox(height: 8),
            Semantics(
                liveRegion: true,
                child: Text(_t(
                    'Probeziehungen: ${draws.length}; Sterne: ${draws.where((d) => d == 'star').length}; Kreise: ${draws.where((d) => d == 'circle').length}.',
                    'Trial draws: ${draws.length}; stars: ${draws.where((d) => d == 'star').length}; circles: ${draws.where((d) => d == 'circle').length}.'))),
          ],
        ];
      case 'axes':
        final axes = stringList(_response['axes']);
        return [
          _figure(
              'polygon',
              {'points': config['points'], 'axes': axes},
              _t('Figur mit Eckpunkten ${config['points']}. Markierte Linien: ${axes.join(', ')}.',
                  'Shape with vertices ${config['points']}. Selected lines: ${axes.join(', ')}.')),
          for (final axis in [
            ('vertical', _t('Senkrecht', 'Vertical')),
            ('horizontal', _t('Waagerecht', 'Horizontal')),
            (
              'diagonalDown',
              _t('Diagonal: links oben nach rechts unten',
                  'Diagonal: top left to bottom right')
            ),
            (
              'diagonalUp',
              _t('Diagonal: links unten nach rechts oben',
                  'Diagonal: bottom left to top right')
            ),
          ])
            CheckboxListTile(
              key: ValueKey('lab_axis_${axis.$1}'),
              contentPadding: EdgeInsets.zero,
              title: Text(axis.$2),
              value: axes.contains(axis.$1),
              onChanged: _editable
                  ? (checked) {
                      final next = axes.toSet();
                      checked == true
                          ? next.add(axis.$1)
                          : next.remove(axis.$1);
                      _edit('axes', next.toList());
                    }
                  : null,
            ),
        ];
      case 'cubeNet':
        return [
          KompassCellInput(
            figure: {
              'kind': 'cubeNet',
              'data': {'rows': 5, 'cols': 4, 'cells': config['cells']}
            },
            selected: stringList(_response['cells']).toSet(),
            german: _german,
            enabled: _editable,
            onChanged: (values) {
              final previous = stringList(_response['cells']).toSet();
              final newlyAdded = values.difference(previous);
              _edit(
                  'cells',
                  (newlyAdded.isNotEmpty ? newlyAdded : values)
                      .take(1)
                      .toList());
            },
          ),
        ];
      case 'sideView':
        final heights = intList(_response['heights']);
        return [
          _figure(
              'cubePlan',
              {'heights': config['heights'], 'view': config['view']},
              _t('Würfelbauwerk. Stapelhöhen zeilenweise von hinten nach vorne: ${config['heights']}. Blick von ${config['view'] == 'right' ? 'rechts' : 'vorne'}.',
                  'Cube building. Stack heights by row from back to front: ${config['heights']}. View from the ${config['view']}.')),
          Text(_t('Deine Ansicht', 'Your view'),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          _figure(
              'grid',
              {
                'rows': 3,
                'cols': 3,
                'filled': [
                  for (var c = 0; c < 3; c++)
                    for (var h = 0; h < heights[c]; h++) '${2 - h},$c',
                ]
              },
              _t('Deine Ansicht hat von links nach rechts die Höhen ${heights.join(', ')}.',
                  'Your view has heights ${heights.join(', ')} from left to right.')),
          Wrap(spacing: 12, runSpacing: 12, children: [
            for (var i = 0; i < 3; i++)
              _counter(context, 'height_$i',
                  _t('Spalte ${i + 1}', 'Column ${i + 1}'), heights[i], (v) {
                final next = List<int>.of(heights)..[i] = v;
                _edit('heights', next);
              }, max: 3),
          ]),
        ];
    }
    return const [];
  }

  Widget _figure(String kind, Map<String, dynamic> data, String alt) =>
      KompassFigureView(
          figure: {'kind': kind, 'data': data, 'alt': alt}, german: _german);

  Widget _panel(BuildContext context, Widget child) => Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16)),
        child: child,
      );

  Widget _counter(BuildContext context, String id, String label, int value,
      ValueChanged<int> onChanged,
      {int min = 0, int max = 20, int step = 1}) {
    final width =
        math.min(250.0, math.max(160.0, MediaQuery.sizeOf(context).width - 80));
    return SizedBox(
        width: width,
        child: _panel(
            context,
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(children: [
                  IconButton.filledTonal(
                    key: ValueKey('lab_${id}_minus'),
                    constraints:
                        const BoxConstraints(minWidth: 48, minHeight: 48),
                    tooltip: '$label −$step',
                    onPressed: _editable && value > min
                        ? () => onChanged((value - step).clamp(min, max))
                        : null,
                    icon: const Icon(Icons.remove),
                  ),
                  Expanded(
                      child: Semantics(
                          liveRegion: true,
                          child: Text('$value',
                              key: ValueKey('lab_${id}_value'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 24)))),
                  IconButton.filledTonal(
                    key: ValueKey('lab_${id}_plus'),
                    constraints:
                        const BoxConstraints(minWidth: 48, minHeight: 48),
                    tooltip: '$label +$step',
                    onPressed: _editable && value < max
                        ? () => onChanged((value + step).clamp(min, max))
                        : null,
                    icon: const Icon(Icons.add),
                  ),
                ]),
              ],
            )));
  }

  Widget _numberField(String field, String label, {String? unit}) =>
      TextFormField(
        key: ValueKey('lab_field_$field'),
        initialValue: _response[field]?.toString() ?? '',
        enabled: _editable,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(fontSize: 20),
        decoration: InputDecoration(
            labelText: label,
            suffixText: unit,
            border: const OutlineInputBorder()),
        onChanged: (value) => _edit(field, value),
      );

  Map<String, dynamic> _copy(Map<String, dynamic> value) =>
      Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);
}
