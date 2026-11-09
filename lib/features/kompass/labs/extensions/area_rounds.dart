import 'dart:math' as math;

import '../kompass_lab_round.dart';

class AreaShapeMetrics {
  final bool valid, connected, holeFree;
  final int cells, boundaryEdges;

  const AreaShapeMetrics({
    required this.valid,
    required this.connected,
    required this.holeFree,
    required this.cells,
    required this.boundaryEdges,
  });
}

const _neighbours = [(1, 0), (-1, 0), (0, 1), (0, -1)];

/// Measures edges, not bounding boxes; separate flood fills detect gaps/holes.
AreaShapeMetrics measureAreaShape(
  Iterable<String> cells, {
  required int rows,
  required int cols,
}) {
  final ids = cells.toList();
  final selected = <(int, int)>{};
  for (final id in ids) {
    final cell = parseCell(id);
    if (cell == null ||
        cell.$1 < 0 ||
        cell.$1 >= rows ||
        cell.$2 < 0 ||
        cell.$2 >= cols ||
        !selected.add(cell)) {
      return const AreaShapeMetrics(
        valid: false,
        connected: false,
        holeFree: false,
        cells: 0,
        boundaryEdges: 0,
      );
    }
  }
  if (selected.isEmpty) {
    return const AreaShapeMetrics(
      valid: true,
      connected: false,
      holeFree: true,
      cells: 0,
      boundaryEdges: 0,
    );
  }
  var boundary = 0;
  for (final cell in selected) {
    for (final direction in _neighbours) {
      if (!selected.contains(
        (cell.$1 + direction.$1, cell.$2 + direction.$2),
      )) {
        boundary++;
      }
    }
  }
  final reached = {selected.first};
  final queue = [selected.first];
  for (var index = 0; index < queue.length; index++) {
    final cell = queue[index];
    for (final direction in _neighbours) {
      final neighbour = (cell.$1 + direction.$1, cell.$2 + direction.$2);
      if (selected.contains(neighbour) && reached.add(neighbour)) {
        queue.add(neighbour);
      }
    }
  }

  // One cell of exterior padding keeps every boundary opening reachable.
  final outside = {(-1, -1)};
  final emptyQueue = [(-1, -1)];
  for (var index = 0; index < emptyQueue.length; index++) {
    final cell = emptyQueue[index];
    for (final direction in _neighbours) {
      final next = (cell.$1 + direction.$1, cell.$2 + direction.$2);
      if (next.$1 >= -1 &&
          next.$1 <= rows &&
          next.$2 >= -1 &&
          next.$2 <= cols &&
          !selected.contains(next) &&
          outside.add(next)) {
        emptyQueue.add(next);
      }
    }
  }
  var holeFree = true;
  for (var row = 0; row < rows; row++) {
    for (var col = 0; col < cols; col++) {
      if (!selected.contains((row, col)) && !outside.contains((row, col))) {
        holeFree = false;
      }
    }
  }
  return AreaShapeMetrics(
    valid: true,
    connected: reached.length == selected.length,
    holeFree: holeFree,
    cells: selected.length,
    boundaryEdges: boundary,
  );
}

const _measurementShapes = [
  ['0,0', '1,0', '1,1'],
  ['0,0', '0,1', '0,2', '1,1'],
  ['0,0', '1,0', '1,1', '2,1', '2,2'],
  ['0,0', '1,0', '2,0', '2,1', '2,2', '2,3'],
  ['0,0', '0,1', '0,2', '1,0', '1,1', '1,2'],
];

const _constructionShapes = [
  ['0,0', '0,1', '0,2', '1,0'],
  ['0,0', '0,1', '0,2', '1,0', '2,0'],
  ['0,0', '0,1', '0,2', '1,0', '1,1', '2,0'],
  ['0,0', '0,1', '0,2', '0,3', '1,0', '1,1', '1,2'],
  ['0,0', '0,1', '0,2', '0,3', '1,0', '1,1', '1,2', '2,0'],
];

List<String> _moveShape(List<String> input, math.Random random) {
  var cells = input.map((value) => parseCell(value)!).toList();
  for (var turn = random.nextInt(4); turn > 0; turn--) {
    final height = cells.map((cell) => cell.$1).reduce(math.max) + 1;
    cells = cells.map((cell) => (cell.$2, height - 1 - cell.$1)).toList();
  }
  final height = cells.map((cell) => cell.$1).reduce(math.max) + 1;
  final width = cells.map((cell) => cell.$2).reduce(math.max) + 1;
  final top = random.nextInt(7 - height);
  final left = random.nextInt(7 - width);
  return cells.map((cell) => '${cell.$1 + top},${cell.$2 + left}').toList();
}

KompassLabRound generateAreaRound(int index, int seed) {
  final random = math.Random(seed + index * 7919 + 811);
  final construct = index.isOdd;
  final choices = construct ? _constructionShapes : _measurementShapes;
  final cells = _moveShape(choices[random.nextInt(choices.length)], random);
  final metrics = measureAreaShape(cells, rows: 6, cols: 6);
  final side = construct ? 1 : 1 + random.nextInt(2);
  final area = metrics.cells * side * side;
  final perimeter = metrics.boundaryEdges * side;
  final exampleDe = cells.map((id) {
    final cell = parseCell(id)!;
    return '${cell.$1 + 1}/${cell.$2 + 1}';
  }).join(', ');
  return KompassLabRound(
    type: construct ? 'area_construct' : 'area_measure',
    skillIds: construct
        ? const ['M-R02', 'M-R03', 'M-R08']
        : const ['M-R03', 'M-R08'],
    config: {
      'rows': 6,
      'cols': 6,
      'sideCm': side,
      'areaCm2': area,
      'perimeterCm': perimeter,
      if (construct) 'exampleCells': cells else 'cells': cells,
    },
    titleDe: construct
        ? 'Fläche und Rand selbst bauen'
        : 'Innenfläche und Außenrand',
    titleEn: construct
        ? 'Build an area and its boundary'
        : 'Inside area and outside boundary',
    promptDe: construct
        ? 'Baue aus genau $area Kästchen eine zusammenhängende Figur ohne Löcher. '
            'Jede Kästchenseite ist 1 cm lang. Der Außenrand soll genau '
            '$perimeter cm lang sein. Kästchen müssen über ganze Kanten '
            'zusammenhängen; eine Ecke allein verbindet sie nicht. '
            'Jede passende Figur zählt.'
        : 'Alle markierten Kästchen haben eine Seitenlänge von $side cm. '
            'Bestimme den Flächeninhalt und die Länge des gesamten Außenrandes. '
            'Rechne mit der angegebenen Seitenlänge; miss nicht den Bildschirm.',
    promptEn: construct
        ? 'Build one connected shape without holes using exactly $area cells. '
            'Each cell side is 1 cm long. The outside boundary must measure '
            'exactly $perimeter cm. Cells must connect along whole edges; '
            'touching at a corner is not enough. Every suitable shape counts.'
        : 'Every marked cell has side length $side cm. Find the area and '
            'the length of the whole outside boundary. Use the stated side '
            'length; do not measure the screen.',
    solutionDe: construct
        ? 'Die Figur ist zusammenhängend, hat kein Loch, bedeckt $area cm² '
            'und hat $perimeter cm Außenrand. Andere Formen können dieselben '
            'beiden Werte haben.'
        : '${metrics.cells} Kästchen mit je ${side * side} cm² ergeben '
            '$area cm². ${metrics.boundaryEdges} freie Kanten mit je $side cm '
            'ergeben $perimeter cm Rand. Gemeinsame Innenkanten zählen nicht.',
    solutionEn: construct
        ? 'The shape is connected, has no hole, covers $area cm² and has '
            '$perimeter cm of outside boundary. Other shapes can have the '
            'same two measurements.'
        : '${metrics.cells} cells of ${side * side} cm² give $area cm². '
            '${metrics.boundaryEdges} exposed edges of $side cm give '
            '$perimeter cm of boundary. Shared inside edges do not count.',
    hintsDe: construct
        ? [
            'Eine gemeinsame Kante verschwindet im Inneren. Sie gehört dann '
                'zu keinem Teil des Außenrandes.',
            'Lege zuerst die richtige Anzahl Kästchen. Verschiebe einzelne '
                'Randkästchen, um bei gleicher Fläche die Randlänge zu ändern.',
            'Ein mögliches Beispiel, jeweils Zeile/Spalte: $exampleDe.',
          ]
        : [
            'Fläche und Rand brauchen verschiedene Einheiten: cm² und cm.',
            'Ein Kästchen bedeckt $side · $side = ${side * side} cm². '
                'Zähle für den Rand nur Kanten, die außen frei liegen.',
            '${metrics.cells} Kästchen und ${metrics.boundaryEdges} freie '
                'Kanten: $area cm² und $perimeter cm.',
          ],
    hintsEn: construct
        ? [
            'A shared edge lies inside the shape. It contributes nothing to '
                'the outside boundary.',
            'Start with the right cell count. Move boundary cells to change '
                'the perimeter while keeping the same area.',
            'One example, written as row/column: $exampleDe.',
          ]
        : [
            'Area and boundary need different units: cm² and cm.',
            'One cell covers $side × $side = ${side * side} cm². For the '
                'boundary, count only exposed outer edges.',
            '${metrics.cells} cells and ${metrics.boundaryEdges} exposed '
                'edges: $area cm² and $perimeter cm.',
          ],
  );
}

Map<String, dynamic> createAreaResponse(KompassLabRound round) =>
    round.type == 'area_construct'
        ? {'cells': <String>[]}
        : {'area': '', 'perimeter': ''};

Map<String, dynamic> normalizeAreaResponse(
  KompassLabRound round,
  Map<String, dynamic> saved,
) {
  if (round.type == 'area_construct') {
    final raw = saved['cells'];
    final cells = <String>{};
    if (raw is List) {
      for (final value in raw.take(100)) {
        final cell = value is String ? parseCell(value) : null;
        if (cell != null &&
            cell.$1 >= 0 &&
            cell.$1 < round.config['rows'] &&
            cell.$2 >= 0 &&
            cell.$2 < round.config['cols']) {
          cells.add('${cell.$1},${cell.$2}');
        }
      }
    }
    return {'cells': cells.toList()};
  }
  return {
    for (final key in ['area', 'perimeter'])
      key: saved[key] is String && (saved[key] as String).length <= 40
          ? saved[key]
          : '',
  };
}

KompassLabCheck checkAreaRound(
  KompassLabRound round,
  Map<String, dynamic> response,
) {
  final config = round.config;
  var points = 0;
  final maximum = round.type == 'area_construct' ? 3 : 2;
  String de, en;
  if (round.type == 'area_construct') {
    final raw = response['cells'];
    final metrics = raw is List && raw.every((cell) => cell is String)
        ? measureAreaShape(
            raw.cast<String>(),
            rows: config['rows'] as int,
            cols: config['cols'] as int,
          )
        : const AreaShapeMetrics(
            valid: false,
            connected: false,
            holeFree: false,
            cells: 0,
            boundaryEdges: 0,
          );
    final areaCorrect = metrics.valid && metrics.cells == config['areaCm2'];
    final perimeterCorrect =
        metrics.valid && metrics.boundaryEdges == config['perimeterCm'];
    final shapeCorrect = metrics.valid && metrics.connected && metrics.holeFree;
    points = (areaCorrect ? 1 : 0) +
        (perimeterCorrect ? 1 : 0) +
        (shapeCorrect ? 1 : 0);
    if (!metrics.valid || metrics.cells == 0) {
      de =
          'Markiere Kästchen innerhalb des Gitters. Jedes Kästchen zählt einmal.';
      en = 'Select cells inside the grid. Each cell counts once.';
    } else if (!metrics.connected) {
      de = 'Die Teile müssen über ganze Kanten zusammenhängen. '
          'Eine Berührung an einer Ecke reicht nicht.';
      en = 'The pieces must connect along whole edges. '
          'Touching only at a corner is not enough.';
    } else if (!metrics.holeFree) {
      de = 'In deiner Figur liegt ein eingeschlossenes leeres Kästchen. '
          'Baue eine Figur ohne Löcher.';
      en = 'Your shape encloses an empty cell. Build a shape without holes.';
    } else if (!areaCorrect) {
      de = 'Die Fläche hat ${metrics.cells} Kästchen. '
          'Gesucht sind genau ${config['areaCm2']}.';
      en = 'The shape has ${metrics.cells} cells. '
          'You need exactly ${config['areaCm2']}.';
    } else {
      de = 'Die Fläche stimmt. Dein Rand ist ${metrics.boundaryEdges} cm lang. '
          'Verschiebe Kästchen, ohne die Anzahl zu ändern.';
      en = 'The area is correct. Your boundary is ${metrics.boundaryEdges} cm. '
          'Move cells without changing their count.';
    }
  } else {
    final areaCorrect =
        parseLabNumber(response['area'], unit: 'cm²') == config['areaCm2'];
    final perimeterCorrect =
        parseLabNumber(response['perimeter'], unit: 'cm') ==
            config['perimeterCm'];
    points = (areaCorrect ? 1 : 0) + (perimeterCorrect ? 1 : 0);
    de = areaCorrect
        ? 'Die Fläche stimmt. Zähle beim Rand nur freie Kanten; '
            'gemeinsame Kanten zwischen zwei Kästchen liegen innen.'
        : 'Für die Fläche zählt jedes Kästchen mit Seitenlänge mal Seitenlänge. '
            'Die Randlänge hat dagegen die Einheit cm.';
    en = areaCorrect
        ? 'The area is correct. Count only exposed boundary edges; '
            'edges shared by two cells lie inside.'
        : 'Each cell contributes side length × side length to the area. '
            'The boundary length uses cm instead.';
  }
  return KompassLabCheck(
    points: points,
    maxPoints: maximum,
    feedbackDe: points == maximum ? round.solutionDe : de,
    feedbackEn: points == maximum ? round.solutionEn : en,
  );
}
