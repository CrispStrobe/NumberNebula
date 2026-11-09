import 'package:flutter/material.dart';

import '../../widgets/kompass_figure_view.dart';
import '../kompass_lab_round.dart';
import 'journey_rounds.dart';

class JourneyLabView extends StatelessWidget {
  final KompassLabRound round;
  final Map<String, dynamic> response;
  final bool german, enabled;
  final void Function(String, Object) onChanged;

  const JourneyLabView({
    super.key,
    required this.round,
    required this.response,
    required this.german,
    required this.enabled,
    required this.onChanged,
  });

  String _t(String de, String en) => german ? de : en;

  @override
  Widget build(BuildContext context) {
    final config = round.config;
    final backward = round.type == 'journey_backward';
    final rows = backward
        ? <List<Object>>[
            [
              _t('Kursbeginn', 'Workshop start'),
              journeyTime(config['deadline'] as int),
            ],
            [_t('Fahrt', 'Ride'), '${config['rideMinutes']} min'],
            [
              _t('Fußweg danach', 'Walk afterwards'),
              '${config['walkMinutes']} min',
            ],
            [
              _t('Reserve vor Beginn', 'Reserve before start'),
              '${config['reserveMinutes']} min',
            ],
          ]
        : <List<Object>>[
            [
              _t('Start Zubringer', 'Feeder departure'),
              journeyTime(config['startTime'] as int),
            ],
            [_t('Fahrt', 'Ride'), '${config['rideMinutes']} min'],
            [
              _t('Weg zum Bahnsteig', 'Walk to platform'),
              '${config['walkMinutes']} min',
            ],
            [
              _t('Mindestreserve', 'Minimum reserve'),
              '${config['reserveMinutes']} min',
            ],
          ];
    return KeyedSubtree(
      // A new round must not inherit another round's editable text controller.
      key: ObjectKey(round),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _table(
            [_t('Schritt', 'Step'), _t('Zeit', 'Time')],
            rows,
            rows.map((row) => '${row[0]}: ${row[1]}').join('. '),
          ),
          const SizedBox(height: 16),
          if (backward) ...[
            _timeField(
              'stopTime',
              _t(
                'Wann musst du spätestens am Zielhalt ankommen?',
                'What is the latest time to reach the destination stop?',
              ),
              _t('Zielhalt', 'Destination stop'),
            ),
            const SizedBox(height: 20),
            _timeField(
              'leaveTime',
              _t(
                'Wann musst du spätestens losfahren?',
                'What is the latest time to set off?',
              ),
              _t('Abfahrt', 'Departure'),
            ),
          ] else ...[
            _timeField(
              'platformTime',
              _t(
                'Wann erreichst du den Bahnsteig?',
                'When do you reach the platform?',
              ),
              _t('Bahnsteig', 'Platform arrival'),
            ),
            const SizedBox(height: 20),
            _table(
              [_t('Anschluss', 'Connection'), _t('Abfahrt', 'Departure')],
              [
                for (final raw in config['services'] as List)
                  [
                    (raw as Map)['id'] as String,
                    journeyTime(raw['departure'] as int),
                  ],
              ],
              (config['services'] as List).map((raw) {
                final service = raw as Map;
                return '${service['id']}: '
                    '${journeyTime(service['departure'] as int)}';
              }).join('. '),
            ),
            const SizedBox(height: 16),
            Text(
              _t(
                'Wähle den frühesten Anschluss, der auch die Reserve einhält.',
                'Choose the earliest connection that allows the reserve.',
              ),
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final raw in config['services'] as List)
                  _serviceChoice(raw as Map),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _timeField(String field, String question, String label) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(question, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 10),
          TextFormField(
            key: ValueKey('journey_$field'),
            initialValue:
                response[field] is String ? response[field] as String : '',
            enabled: enabled,
            keyboardType: TextInputType.datetime,
            textInputAction: TextInputAction.next,
            style: const TextStyle(fontSize: 20),
            decoration: InputDecoration(
              labelText: label,
              hintText: '09:15',
              helperText:
                  _t('24-Stunden-Uhrzeit: HH:MM', '24-hour time: HH:MM'),
              helperMaxLines: 2,
              border: const OutlineInputBorder(),
            ),
            onChanged: enabled ? (value) => onChanged(field, value) : null,
          ),
        ],
      );

  Widget _serviceChoice(Map service) {
    final id = service['id'] as String;
    return ChoiceChip(
      key: ValueKey('journey_service_$id'),
      selected: response['service'] == id,
      label: Text('$id · ${journeyTime(service['departure'] as int)}'),
      onSelected: enabled ? (_) => onChanged('service', id) : null,
      showCheckmark: true,
    );
  }

  Widget _table(List<String> headers, List<List<Object>> rows, String alt) =>
      KompassFigureView(
        figure: {
          'kind': 'table',
          'data': {'headers': headers, 'rows': rows},
          'alt': alt,
        },
        german: german,
      );
}
