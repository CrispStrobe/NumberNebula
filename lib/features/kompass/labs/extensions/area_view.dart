import 'package:flutter/material.dart';

import '../../widgets/kompass_cell_input.dart';
import '../../widgets/kompass_figure_view.dart';
import '../kompass_lab_round.dart';
import 'area_rounds.dart';

class AreaLabView extends StatelessWidget {
  final KompassLabRound round;
  final Map<String, dynamic> response;
  final bool german, enabled;
  final void Function(String, Object) onChanged;

  const AreaLabView({
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
    return KeyedSubtree(
      key: ObjectKey(round),
      child: round.type == 'area_construct'
          ? _construction(config)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                KompassFigureView(
                  figure: {
                    'kind': 'grid',
                    'data': {
                      'rows': config['rows'],
                      'cols': config['cols'],
                      'filled': config['cells'],
                    },
                    'alt': _t(
                      'Markierte Kästchen, jeweils Zeile und Spalte ab 1: '
                          '${_coordinates(config['cells'] as List)}. '
                          'Jede Kästchenseite ist ${config['sideCm']} cm lang.',
                      'Marked cells, each given as row and column starting at 1: '
                          '${_coordinates(config['cells'] as List)}. '
                          'Each cell side measures ${config['sideCm']} cm.',
                    ),
                  },
                  german: german,
                ),
                const SizedBox(height: 16),
                _numberField('area', _t('Flächeninhalt', 'Area'), 'cm²'),
                const SizedBox(height: 20),
                _numberField(
                  'perimeter',
                  _t('Außenrand', 'Outside boundary'),
                  'cm',
                ),
              ],
            ),
    );
  }

  Widget _construction(Map<String, dynamic> config) {
    final selected = stringList(response['cells']).toSet();
    final metrics = measureAreaShape(
      selected,
      rows: config['rows'] as int,
      cols: config['cols'] as int,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t(
            'Ziel: ${config['areaCm2']} cm² Fläche und '
                '${config['perimeterCm']} cm Außenrand.',
            'Target: ${config['areaCm2']} cm² of area and '
                '${config['perimeterCm']} cm of outside boundary.',
          ),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        KompassCellInput(
          key: const ValueKey('area_construction_grid'),
          figure: {
            'kind': 'grid',
            'data': {
              'rows': config['rows'],
              'cols': config['cols'],
              'filled': const <String>[],
            },
          },
          selected: selected,
          german: german,
          enabled: enabled,
          onChanged: (cells) => onChanged('cells', cells.toList()),
        ),
        const SizedBox(height: 16),
        Semantics(
          liveRegion: true,
          child: Text(
            _t(
              'Deine Fläche: ${metrics.cells} cm². '
                  'Freie Kanten insgesamt: ${metrics.boundaryEdges} cm.',
              'Your area: ${metrics.cells} cm². '
                  'All exposed edges: ${metrics.boundaryEdges} cm.',
            ),
            style: const TextStyle(fontSize: 18),
          ),
        ),
        if (selected.isNotEmpty && !metrics.connected)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _t(
                'Die Teile sind noch nicht über Kanten miteinander verbunden.',
                'The pieces are not yet connected along edges.',
              ),
            ),
          ),
        if (!metrics.holeFree)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _t(
                'Die Figur hat ein Loch. Die freien Kanten um das Loch werden '
                    'oben mitgezählt; gesucht ist eine Figur ohne Löcher.',
                'The shape has a hole. Its exposed edges are included above; '
                    'the task requires a shape without holes.',
              ),
            ),
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: const ValueKey('area_clear'),
          onPressed: enabled && selected.isNotEmpty
              ? () => onChanged('cells', <String>[])
              : null,
          icon: const Icon(Icons.clear),
          label: Text(_t('Kästchen leeren', 'Clear cells')),
        ),
      ],
    );
  }

  Widget _numberField(String field, String label, String unit) => TextFormField(
        key: ValueKey('area_$field'),
        initialValue:
            response[field] is String ? response[field] as String : '',
        enabled: enabled,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textInputAction: TextInputAction.next,
        style: const TextStyle(fontSize: 20),
        decoration: InputDecoration(
          labelText: label,
          suffixText: unit,
          border: const OutlineInputBorder(),
        ),
        onChanged: enabled ? (value) => onChanged(field, value) : null,
      );

  String _coordinates(List cells) => cells.map((value) {
        final cell = parseCell(value as String)!;
        return '${cell.$1 + 1}/${cell.$2 + 1}';
      }).join(', ');
}
