import 'package:flutter/material.dart';

import '../../widgets/kompass_figure_view.dart';
import '../kompass_lab_round.dart';

/// Tap and keyboard controls for the reasoning workshop's saved response.
class ReasoningLabView extends StatelessWidget {
  final KompassLabRound round;
  final Map<String, dynamic> response;
  final bool german;
  final bool enabled;
  final void Function(String, Object) onChanged;

  const ReasoningLabView({
    super.key,
    required this.round,
    required this.response,
    required this.german,
    required this.enabled,
    required this.onChanged,
  });

  String _t(String de, String en) => german ? de : en;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: switch (round.type) {
          'reasoning_inverse_wall' => _inverseWall(),
          'reasoning_max_wall' => _maxWall(),
          'reasoning_machine' => _machine(),
          'reasoning_codes' => _codes(),
          _ => [
              Text(_t('Diese Übung ist nicht verfügbar.',
                  'This activity is unavailable.'))
            ],
        },
      );

  List<Widget> _inverseWall() {
    final config = round.config;
    return [
      _wall(
        [
          [config['leftBase'], config['middleBase'], _number('base')],
          [config['leftMiddle'], _number('middle')],
          [config['top']],
        ],
        _t(
          'Additionsmauer: unten ${config['leftBase']}, ${config['middleBase']} und deine untere Antwort; darüber ${config['leftMiddle']} und deine mittlere Antwort; oben ${config['top']}. Fragezeichen markieren leere Antworten.',
          'Addition wall: base ${config['leftBase']}, ${config['middleBase']} and your base response; above, ${config['leftMiddle']} and your middle response; top ${config['top']}. Question marks show empty responses.',
        ),
      ),
      const SizedBox(height: 12),
      _field(
          'middle',
          _t('Rechter Stein in der mittleren Reihe',
              'Right brick in the middle row')),
      const SizedBox(height: 16),
      _field(
          'base',
          _t('Rechter Stein in der unteren Reihe',
              'Right brick in the base row')),
      const SizedBox(height: 20),
      _choices(
        'inverse',
        _t('Welche Rechenart macht das Addieren rückgängig?',
            'Which operation reverses addition?'),
        [
          ('add', 'Addieren', 'Addition'),
          ('subtract', 'Subtrahieren', 'Subtraction'),
          ('multiply', 'Multiplizieren', 'Multiplication'),
        ],
      ),
    ];
  }

  List<Widget> _maxWall() {
    final cards = (round.config['cards'] as List).cast<int>();
    final order = _list('order');
    final positions =
        german ? ['Links', 'Mitte', 'Rechts'] : ['Left', 'Middle', 'Right'];
    int? value(String id) => switch (id) {
          'c0' => cards[0],
          'c1' => cards[1],
          'c2' => cards[2],
          _ => null,
        };
    return [
      _wall(
        [
          [
            for (var i = 0; i < 3; i++)
              i < order.length ? value(order[i]) : null
          ],
          [null, null],
          [null],
        ],
        _t(
          'Additionsmauer mit drei unteren Plätzen. Wähle deine Karten in der Reihenfolge links, Mitte, rechts. Die oberen Zahlen berechnest du selbst.',
          'Addition wall with three base positions. Choose cards in left, middle, right order. Calculate the upper values yourself.',
        ),
      ),
      Text(_t(
        'Wähle die Karten nacheinander für links, Mitte und rechts. Zum Umordnen kannst du gewählte Karten entfernen.',
        'Choose cards for left, middle and right in order. Remove selected cards to rearrange them.',
      )),
      const SizedBox(height: 12),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (var i = 0; i < order.length; i++)
            InputChip(
              key: ValueKey('reasoning_order_$i'),
              label: Text(
                  '${i < positions.length ? positions[i] : i + 1}: ${value(order[i]) ?? '?'}'),
              onDeleted: enabled
                  ? () =>
                      onChanged('order', List<String>.of(order)..removeAt(i))
                  : null,
              deleteButtonTooltipMessage: _t('Karte entfernen', 'Remove card'),
            ),
        ],
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (var i = 0; i < cards.length; i++)
            OutlinedButton(
              key: ValueKey('reasoning_card_c$i'),
              onPressed: enabled && order.length < 3 && !order.contains('c$i')
                  ? () => onChanged('order', [...order, 'c$i'])
                  : null,
              child: Text('${cards[i]}', style: const TextStyle(fontSize: 22)),
            ),
        ],
      ),
      const SizedBox(height: 20),
      _field(
          'top',
          _t('Größtmögliche Zahl an der Spitze',
              'Largest possible number at the top')),
      const SizedBox(height: 20),
      _choices(
        'reason',
        _t('Warum ist die mittlere untere Zahl besonders wichtig?',
            'Why does the middle base number matter most?'),
        [
          (
            'once',
            'Alle drei unteren Zahlen zählen oben gleich oft.',
            'All three base numbers count equally often at the top.'
          ),
          (
            'twice',
            'Die mittlere Zahl zählt oben zweimal, die äußeren je einmal.',
            'The middle number counts twice at the top; each outer number counts once.'
          ),
          (
            'right',
            'Die rechte Zahl zählt oben dreimal.',
            'The right number counts three times at the top.'
          ),
        ],
      ),
    ];
  }

  List<Widget> _machine() {
    final add = round.config['add'];
    final factor = round.config['factor'];
    final shown = (round.config['shown'] as List).join(' → ');
    return [
      Semantics(
        label: _t('Bisherige Zahlenfolge: $shown', 'Sequence so far: $shown'),
        child: ExcludeSemantics(
          child: SelectableText(
            '$shown → ? → ?',
            style: const TextStyle(fontSize: 22, height: 1.5),
          ),
        ),
      ),
      const SizedBox(height: 20),
      _field('next', _t('Die nächste Zahl', 'The next number')),
      const SizedBox(height: 16),
      _field('after', _t('Die Zahl danach', 'The number after that')),
      const SizedBox(height: 20),
      _choices(
        'rule',
        _t('Die nächsten beiden Rechenschritte', 'The next two operations'),
        [
          ('multiply_then_add', '×$factor, dann +$add', '×$factor, then +$add'),
          ('add_then_multiply', '+$add, dann ×$factor', '+$add, then ×$factor'),
          ('add_twice', 'Zweimal +$add', '+$add twice'),
        ],
      ),
    ];
  }

  List<Widget> _codes() {
    final symbols = (round.config['symbols'] as List).cast<String>();
    final first = response['draftFirst']?.toString() ?? '';
    final second = response['draftSecond']?.toString() ?? '';
    final codes = _list('codes');
    final ready = symbols.contains(first) && symbols.contains(second);
    final draft = '$first$second';
    final duplicate = ready && codes.contains(draft);
    return [
      _choices(
        'draftFirst',
        _t('Erste Stelle', 'First position'),
        [for (final symbol in symbols) (symbol, symbol, symbol)],
      ),
      const SizedBox(height: 16),
      _choices(
        'draftSecond',
        _t('Zweite Stelle', 'Second position'),
        [for (final symbol in symbols) (symbol, symbol, symbol)],
      ),
      const SizedBox(height: 12),
      Semantics(
        liveRegion: true,
        child: Text(
          _t('Dein neuer Code: ${ready ? draft : '…'}',
              'Your new code: ${ready ? draft : '…'}'),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
      ),
      const SizedBox(height: 10),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.tonalIcon(
          key: const ValueKey('reasoning_add_code'),
          onPressed: enabled && ready && !duplicate && codes.length < 12
              ? () => onChanged('codes', [...codes, draft])
              : null,
          icon: const Icon(Icons.add),
          label: Text(_t('Code zur Liste hinzufügen', 'Add code to the list')),
        ),
      ),
      if (duplicate)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(_t('Dieser Code steht schon in deiner Liste.',
              'This code is already in your list.')),
        ),
      const SizedBox(height: 20),
      Text(_t('Deine Liste', 'Your list'),
          style: const TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 10),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (var i = 0; i < codes.length; i++)
            InputChip(
              key: ValueKey('reasoning_code_$i'),
              label: Text(codes[i].isEmpty ? '?' : codes[i]),
              deleteButtonTooltipMessage: _t('Code entfernen', 'Remove code'),
              onDeleted: enabled
                  ? () =>
                      onChanged('codes', List<String>.of(codes)..removeAt(i))
                  : null,
            ),
        ],
      ),
      const SizedBox(height: 20),
      _field('count',
          _t('Anzahl aller erlaubten Codes', 'Number of all allowed codes')),
      const SizedBox(height: 20),
      _choices(
        'reason',
        _t('Warum fehlt kein erlaubter Code?',
            'Why is no allowed code missing?'),
        [
          (
            'symbols',
            'Jedes angebotene Zeichen kommt irgendwo in meiner Liste vor.',
            'Every offered symbol appears somewhere in my list.'
          ),
          (
            'systematic',
            'Für jedes erste Zeichen habe ich alle erlaubten zweiten Zeichen gesammelt.',
            'For each first symbol, I collected every allowed second symbol.'
          ),
          (
            'reversed',
            'Zwei vertauschte Zeichen ergeben denselben Code.',
            'Swapping two symbols gives the same code.'
          ),
        ],
      ),
    ];
  }

  Widget _wall(List<List<Object?>> rows, String alt) => KompassFigureView(
        figure: {
          'kind': 'wall',
          'data': {'rows': rows},
          'alt': alt
        },
        german: german,
      );

  Widget _field(String key, String label) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Semantics(
            label: label,
            child: TextFormField(
              key: ValueKey('reasoning_field_$key'),
              initialValue: response[key]?.toString() ?? '',
              enabled: enabled,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, signed: true),
              decoration: InputDecoration(
                hintText: _t('Zahl eingeben', 'Enter a number'),
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) => onChanged(key, value),
            ),
          ),
        ],
      );

  Widget _choices(
          String field, String title, List<(String, String, String)> choices) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          for (final choice in choices)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ChoiceChip(
                key: ValueKey('reasoning_${field}_${choice.$1}'),
                label: Text(_t(choice.$2, choice.$3)),
                selected: response[field] == choice.$1,
                onSelected: enabled ? (_) => onChanged(field, choice.$1) : null,
              ),
            ),
        ],
      );

  List<String> _list(String key) => response[key] is List
      ? (response[key] as List)
          .map((value) => value is String ? value : '')
          .toList()
      : <String>[];

  int? _number(String key) {
    final parsed = parseLabNumber(response[key]);
    return parsed != null && parsed == parsed.truncateToDouble()
        ? parsed.toInt()
        : null;
  }
}
