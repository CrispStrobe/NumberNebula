import 'package:flutter/material.dart';

import '../kompass_lab_round.dart';

class ChanceDetectiveView extends StatelessWidget {
  final KompassLabRound round;
  final Map<String, dynamic> response;
  final bool german, enabled;
  final void Function(String, Object) onChanged;
  const ChanceDetectiveView({
    super.key,
    required this.round,
    required this.response,
    required this.german,
    required this.enabled,
    required this.onChanged,
  });

  String _t(String de, String en) => german ? de : en;

  Widget _draw(String field, String label) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              for (final symbol in const ['star', 'circle'])
                ChoiceChip(
                  key: ValueKey('chance_${field}_$symbol'),
                  label: Text(
                    symbol == 'star'
                        ? _t('Stern', 'Star')
                        : _t('Kreis', 'Circle'),
                  ),
                  selected: response[field] == symbol,
                  onSelected: enabled ? (_) => onChanged(field, symbol) : null,
                ),
            ],
          ),
        ],
      );

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _t(
              'Beutel: ${round.config['stars']} Sterne, ${round.config['circles']} Kreise',
              'Bag: ${round.config['stars']} stars, ${round.config['circles']} circles',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            round.config['replacement'] == true
                ? _t(
                    'Mit Zurücklegen: Der erste Stein kommt wieder in den Beutel.',
                    'With replacement: put the first token back in the bag.',
                  )
                : _t(
                    'Ohne Zurücklegen: Der erste Stein bleibt außerhalb des Beutels.',
                    'Without replacement: keep the first token out of the bag.',
                  ),
          ),
          const SizedBox(height: 16),
          _draw('first', _t('Erste Ziehung', 'First draw')),
          const SizedBox(height: 12),
          _draw('second', _t('Zweite Ziehung', 'Second draw')),
          const SizedBox(height: 20),
          Text(
            _t(
              'Warum widerlegt dein Beispiel die Behauptung?',
              'Why does your example disprove the claim?',
            ),
          ),
          const SizedBox(height: 8),
          for (final option in [
            [
              'exception',
              _t(
                'Eine erlaubte Ausnahme zeigt: Es passiert nicht immer.',
                'One allowed exception shows that it does not always happen.',
              ),
            ],
            [
              'frequent',
              _t(
                'Dieses Ergebnis muss am häufigsten vorkommen.',
                'This result must happen most often.',
              ),
            ],
            [
              'oneTrial',
              _t(
                'Eine einzige echte Ziehung beweist jede Regel.',
                'One real draw proves every rule.',
              ),
            ],
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Semantics(
                selected: response['reason'] == option[0],
                child: OutlinedButton(
                  key: ValueKey('chance_reason_${option[0]}'),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: response['reason'] == option[0]
                        ? Theme.of(context).colorScheme.secondaryContainer
                        : null,
                    padding: const EdgeInsets.all(14),
                  ),
                  onPressed:
                      enabled ? () => onChanged('reason', option[0]) : null,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(option[1]),
                  ),
                ),
              ),
            ),
        ],
      );
}
