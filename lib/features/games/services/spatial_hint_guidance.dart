/// Board-specific teaching observations. These do not claim a proved completion
/// or an optimal move, and never inspect stored solutions or answer indices.
Map<String, String>? spatialHintGuidance(
  String game,
  Map<String, dynamic> state, {
  bool german = false,
}) {
  state = _normalizeSpatialSnapshot(game, state);
  final de = german;
  String t(String en, String translated) => de ? translated : en;
  Map<String, String> hint(String focus, String strategy, String working) => {
        'focus': focus,
        'strategy': strategy,
        'working': working,
      };
  String cell(int row, int col) => t(
        'row ${row + 1}, column ${col + 1}',
        'Zeile ${row + 1}, Spalte ${col + 1}',
      );
  final p = _object(
    state['puzzle'] ?? state['_puzzle'] ?? state['currentPuzzle'],
  );

  switch (game) {
    case 'dark_matter_grid':
      // Keep the existing solveLights verified move and its target intact.
      return null;
    case 'block_counter':
      final blocks = _array(
        _object(p['blockStructure'])['blocks'],
      ).map(_object).where((b) => b['y'] is num).toList();
      if (blocks.isEmpty) {
        return null;
      }
      final lowest =
          blocks.map((b) => _number(b['y'])).reduce((a, b) => a < b ? a : b);
      final count = blocks.where((b) => _number(b['y']) == lowest).length;
      final heights = blocks.map((b) => _number(b['y'])).toSet().length;
      return hint(
        t('Start with the bottom layer.', 'Beginne mit der untersten Schicht.'),
        t(
          'Count solid cubes layer by layer, including cubes hidden behind others. Visible faces are not separate cubes.',
          'Zähle ganze Würfel Schicht für Schicht, auch verdeckte. Sichtbare Flächen sind keine eigenen Würfel.',
        ),
        t(
          'The bottom layer has $count cubes; this structure has $heights occupied height layers. Count the remaining layers separately, then add your subtotals.',
          'Unten liegen $count Würfel; das Bauwerk hat $heights belegte Höhenschichten. Zähle die übrigen Schichten getrennt und addiere deine Zwischensummen.',
        ),
      );
    case 'perspective_puzzle':
      final views = _array(state['_perspectivesToSolve']);
      final turn = _number(state['_currentTurnIndex']);
      if (turn < 0 || turn >= views.length) {
        return null;
      }
      final direction = '${views[turn]}';
      final label = switch (direction) {
        'Front' => t('front', 'vorne'),
        'Back' => t('back', 'hinten'),
        'Left' => t('left', 'links'),
        'Right' => t('right', 'rechts'),
        _ => t('the indicated side', 'der angezeigten Seite'),
      };
      return hint(
        t(
          'This turn asks for the view from $label.',
          'Jetzt ist die Ansicht von $label gefragt.',
        ),
        t(
          'Imagine standing at the indicated side. Along each line of sight, the nearest cube hides cubes directly behind it at the same height.',
          'Stelle dich im Kopf auf die angezeigte Seite. Auf jeder Blicklinie verdeckt der nächste Würfel weitere Würfel direkt dahinter auf gleicher Höhe.',
        ),
        t(
          'You are on viewing turn ${turn + 1} of ${views.length}. Compare one occupied square and its nearest color at a time. Keep left and right as they appear from the requested side.',
          'Du bist bei Ansicht ${turn + 1} von ${views.length}. Vergleiche jeweils ein Bildfeld und seine vorderste Farbe. Links und rechts gelten von der gefragten Seite aus.',
        ),
      );
    case 'warp_fold':
      final folds = _array(p['folds']).map(_object).toList();
      if (folds.isEmpty) {
        return null;
      }
      String axis(Map<String, dynamic> fold) =>
          fold['direction'] == 'left' || fold['direction'] == 'right'
              ? t('vertical crease', 'senkrechte Falte')
              : t('horizontal crease', 'waagerechte Falte');
      final order = folds.reversed.map(axis).join(' → ');
      return hint(
        t(
          'Open the last ${axis(folds.last)} first.',
          'Öffne zuerst die letzte ${axis(folds.last)}.',
        ),
        t(
          'Work backward through the folds. Keep each cut and imagine its reflection across the crease before opening the previous fold.',
          'Gehe rückwärts durch die Faltungen. Behalte jeden Schnitt und stelle dir sein Spiegelbild an der Falte vor, bevor du die vorige Faltung öffnest.',
        ),
        t(
          'This sheet has ${folds.length} folds and ${_array(p['cuts']).length} cuts. Unfold in this order: $order. A vertical crease reflects left/right; a horizontal crease reflects up/down.',
          'Dieses Blatt hat ${folds.length} Faltungen und ${_array(p['cuts']).length} Schnitte. Öffne in dieser Reihenfolge: $order. Senkrecht spiegelt links/rechts; waagerecht spiegelt oben/unten.',
        ),
      );
    case 'circuit_repair':
      final digits = _array(state['_currentDigits']);
      if (digits.length != 4 && digits.length != 6) {
        return null;
      }
      final fields = <String>[];
      for (var i = 0; i < digits.length; i += 2) {
        final value = _number(digits[i]) * 10 + _number(digits[i + 1]);
        if (value > (i == 0 ? 23 : 59)) {
          fields.add(
            i == 0
                ? t('hours', 'Stunden')
                : i == 2
                    ? t('minutes', 'Minuten')
                    : t('seconds', 'Sekunden'),
          );
        }
      }
      final time = [
        for (var i = 0; i < digits.length; i += 2)
          '${digits[i]}${digits[i + 1]}',
      ].join(':');
      final selected =
          state['_selectedFirst'] != null && state['_selectedSecond'] != null;
      return hint(
        t(
          'Inspect ${selected ? 'your preview' : 'the display'}: $time.',
          'Prüfe ${selected ? 'deine Vorschau' : 'die Anzeige'}: $time.',
        ),
        t(
          'Swap two whole digit positions, not individual light segments. Check hours 00–23 and every minute/second field 00–59 before confirming.',
          'Tausche zwei ganze Ziffernplätze, keine einzelnen Leuchtstriche. Prüfe vor dem Bestätigen Stunden 00–23 sowie Minuten und Sekunden 00–59.',
        ),
        fields.isEmpty
            ? t(
                'Every time field shown is within range. If you have selected a pair, inspect the preview and confirm when ready; Reset lets you choose another pair.',
                'Alle angezeigten Teile liegen im erlaubten Bereich. Wenn dein Paar gewählt ist, prüfe die Vorschau und bestätige. Mit Zurücksetzen kannst du neu wählen.',
              )
            : t(
                'Out of range: ${fields.join(', ')}. Try moving a digit from one of those positions, then check that the other time fields also stay valid.',
                'Außerhalb des Bereichs: ${fields.join(', ')}. Probiere einen Tausch mit einer dieser Stellen. Prüfe dabei, ob auch die anderen Teile gültig bleiben.',
              ),
      );
    case 'cube_scanner':
      final q = _object(p['question']);
      final visible = _array(p['visibleFaces']).map(_object).toList();
      if (visible.isEmpty) {
        return null;
      }
      String face(Object? raw) => switch (raw) {
            'top' => t('top', 'oben'),
            'bottom' => t('bottom', 'unten'),
            'front' => t('front', 'vorne'),
            'back' => t('back', 'hinten'),
            'left' => t('left', 'links'),
            'right' => t('right', 'rechts'),
            _ => t('the requested face', 'die gesuchte Seite'),
          };
      final shown = visible.first.entries
          .where((e) => e.value is num)
          .map((e) => '${face(e.key)}: ${e.value}')
          .join(', ');
      final kind = q['kind'];
      final rolls = _array(q['rolls']);
      String roll(Object? raw) => switch (raw) {
            'forward' => t('forward', 'vorwärts'),
            'backward' => t('backward', 'rückwärts'),
            'left' => t('left', 'links'),
            'right' => t('right', 'rechts'),
            _ => t('as shown', 'wie angezeigt'),
          };
      if (kind == 'rollToFace') {
        return hint(
          t(
            'Track the ${face(q['face'])} face through ${rolls.length} rolls.',
            'Verfolge die gesuchte Seite (${face(q['face'])}) durch ${rolls.length} Rollbewegungen.',
          ),
          t(
            'Update the positions after each roll; do not answer from the starting picture alone.',
            'Aktualisiere nach jeder Bewegung die Seiten. Antworte nicht nur anhand des Startbilds.',
          ),
          t(
            'Die 1 starts with $shown. Roll order: ${rolls.map(roll).join(' → ')}. Then read the requested face. Opposite faces always add to 7.',
            'Würfel 1 startet mit $shown. Reihenfolge: ${rolls.map(roll).join(' → ')}. Lies danach die gesuchte Seite ab. Gegenüberliegende Seiten ergeben immer 7.',
          ),
        );
      }
      final totalQuestion = kind == 'hiddenPips' || kind == 'hiddenFaceSum';
      return hint(
        totalQuestion
            ? t(
                'Count only the faces the question calls hidden.',
                'Zähle nur die in der Frage verdeckten Flächen.',
              )
            : t(
                'Find the ${face(q['face'])} face.',
                'Suche die Seite ${face(q['face'])}.',
              ),
        totalQuestion
            ? t(
                'A complete die has 21 pips. For a hidden total, subtract only the faces actually visible in the picture; touching and underside faces stay hidden.',
                'Ein ganzer Würfel hat 21 Augen. Ziehe für eine verdeckte Summe nur die wirklich sichtbaren Flächen ab. Berührungsflächen und Unterseiten bleiben verdeckt.',
              )
            : t(
                'Find the opposite face you can see and subtract its pips from 7. A neighboring face is not its opposite.',
                'Suche die sichtbare Gegenseite und ziehe ihre Augen von 7 ab. Eine Nachbarseite ist nicht die Gegenseite.',
              ),
        t(
          'Die 1 shows $shown. There are ${visible.length} dice in this picture. Read whether the question asks for one face or the hidden total across the pictured dice.',
          'Würfel 1 zeigt $shown. Im Bild sind ${visible.length} Würfel. Prüfe, ob die Frage eine einzelne Seite oder die verdeckte Summe über die gezeigten Würfel meint.',
        ),
      );
    case 'relic_assembly':
      final placement = _array(state['placement']);
      final rotations = _array(state['rotations']);
      final tiles = _array(p['playerTiles']).map(_object).toList();
      final cols = _number(p['cols']);
      if (cols < 1 || placement.isEmpty) {
        return null;
      }
      int? edge(int pos, int side) {
        if (pos < 0 || pos >= placement.length) {
          return null;
        }
        final tile = _number(placement[pos], -1);
        if (tile < 0 || tile >= tiles.length || tile >= rotations.length) {
          return null;
        }
        final values = _array(tiles[tile]['edges']);
        return values.length == 4
            ? _number(values[(side - _number(rotations[tile]) + 4) % 4])
            : null;
      }
      // Full boards can still contain mismatches; do not call slot -1 "slot 0".
      for (var i = 0; i < placement.length; i++) {
        for (final next in <(int, int, int)>[
          if (i % cols + 1 < cols) (i + 1, 1, 3),
          if (i + cols < placement.length) (i + cols, 2, 0),
        ]) {
          final a = edge(i, next.$2), b = edge(next.$1, next.$3);
          if (a != null && b != null && a != b) {
            return hint(
              t(
                'Check the shared edge at ${cell(i ~/ cols, i % cols)}.',
                'Prüfe die gemeinsame Kante bei ${cell(i ~/ cols, i % cols)}.',
              ),
              t(
                'Touching numbers must be equal. Rotate or replace one tile and recheck all its neighbors.',
                'Zahlen an berührenden Kanten müssen gleich sein. Drehe oder tausche eine Kachel und prüfe dann alle ihre Nachbarn.',
              ),
              t(
                'The edge toward ${cell(next.$1 ~/ cols, next.$1 % cols)} shows $a against $b. These do not match. Outside edges do not need a frame match.',
                'Zur Kachel bei ${cell(next.$1 ~/ cols, next.$1 % cols)} stehen $a und $b gegenüber. Sie passen nicht. Außenkanten müssen zu keinem Rahmen passen.',
              ),
            );
          }
        }
      }
      var target = -1;
      var most = -1;
      List<String> constraints(int i) {
        final r = i ~/ cols, c = i % cols;
        final result = <String>[];
        for (final neighbor in <(int, int, String)>[
          if (r > 0) (i - cols, 2, t('top', 'oben')),
          if (c + 1 < cols) (i + 1, 3, t('right', 'rechts')),
          if (i + cols < placement.length) (i + cols, 0, t('bottom', 'unten')),
          if (c > 0) (i - 1, 1, t('left', 'links')),
        ]) {
          final value = edge(neighbor.$1, neighbor.$2);
          if (value != null) {
            result.add('${neighbor.$3}: $value');
          }
        }
        return result;
      }
      for (var i = 0; i < placement.length; i++) {
        if (_number(placement[i], -1) < 0 && constraints(i).length > most) {
          target = i;
          most = constraints(i).length;
        }
      }
      if (target < 0) {
        return hint(
          t('Every slot is filled.', 'Alle Plätze sind belegt.'),
          t(
            'Check every shared edge and use each tile once.',
            'Prüfe jede gemeinsame Kante und benutze jede Kachel einmal.',
          ),
          t(
            'No mismatch was found among the adjacent tiles inspected. Outside edges do not need matching frame numbers.',
            'Bei den geprüften Nachbarkanten wurde kein Unterschied gefunden. Außenkanten brauchen keine passenden Rahmenzahlen.',
          ),
        );
      }
      final needed = constraints(target);
      return hint(
        t(
          'Try the empty slot at ${cell(target ~/ cols, target % cols)}.',
          'Untersuche den freien Platz bei ${cell(target ~/ cols, target % cols)}.',
        ),
        t(
          'Compare every already placed neighbor, not only top and left. Rotate an unused tile so all shared edges match.',
          'Vergleiche alle schon gelegten Nachbarn, nicht nur oben und links. Drehe eine übrige Kachel so, dass alle gemeinsamen Kanten passen.',
        ),
        needed.isEmpty
            ? t(
                'This slot has no placed neighbors yet. Place a starting tile, then use its exposed edge numbers to guide neighboring slots.',
                'Dieser Platz hat noch keine gelegten Nachbarn. Lege eine Startkachel und nutze ihre freien Kantenzahlen für die Nachbarplätze.',
              )
            : t(
                'This slot needs ${needed.join('; ')}. These are local edge requirements; other slots must still fit too.',
                'Dieser Platz braucht ${needed.join('; ')}. Das sind Anforderungen dieser Kanten; die übrigen Plätze müssen ebenfalls passen.',
              ),
      );
    case 'hull_plating':
      final board = _array(p['board']).map(_array).toList();
      if (board.isEmpty) {
        return null;
      }
      final covered = <String>{};
      for (final piece in _array(state['_placedPieces']).map(_object)) {
        for (final raw in _array(piece['absoluteCells'])) {
          final xy = _array(raw);
          if (xy.length == 2) {
            covered.add('${_number(xy[0])},${_number(xy[1])}');
          }
        }
      }
      final used = _array(state['_usedPieceIds']).toSet();
      final remaining = _array(
        p['pieces'],
      ).map(_object).where((piece) => !used.contains(piece['id'])).toList();
      for (var r = 0; r < board.length; r++) {
        for (var c = 0; c < board[r].length; c++) {
          if (board[r][c] != true || covered.contains('$r,$c')) {
            continue;
          }
          final neighbors = <String>[];
          for (final d in <(int, int, String)>[
            (0, -1, t('left', 'links')),
            (0, 1, t('right', 'rechts')),
            (-1, 0, t('above', 'oben')),
            (1, 0, t('below', 'unten')),
          ]) {
            final nr = r + d.$1, nc = c + d.$2;
            if (nr < 0 ||
                nr >= board.length ||
                nc < 0 ||
                nc >= board[nr].length ||
                board[nr][nc] != true ||
                covered.contains('$nr,$nc')) {
              neighbors.add(d.$3);
            }
          }
          return hint(
            t(
              'Inspect the uncovered hull at ${cell(r, c)}.',
              'Betrachte den freien Rumpf bei ${cell(r, c)}.',
            ),
            t(
              'Trace the whole rotated piece before placing. Every square must lie on uncovered hull; holes and occupied squares cannot be covered.',
              'Gehe das ganze gedrehte Teil vor dem Legen durch. Jedes Feld muss auf freiem Rumpf liegen; Löcher und belegte Felder sind verboten.',
            ),
            t(
              '${remaining.length} pieces remain. ${neighbors.isEmpty ? 'This square has free hull on all four sides.' : 'No free hull directly ${neighbors.join(', ')} of this square.'} Compare the narrow gap with your remaining shapes, and tap a placed piece to remove it if needed.',
              '${remaining.length} Teile bleiben. ${neighbors.isEmpty ? 'Dieses Feld hat auf allen vier Seiten freien Rumpf.' : 'Direkt ${neighbors.join(', ')} ist kein freier Rumpf.'} Vergleiche die Lücke mit den Restformen. Bei Bedarf kannst du ein gelegtes Teil antippen und entfernen.',
            ),
          );
        }
      }
      return hint(
        t('The hull appears covered.', 'Der Rumpf scheint bedeckt.'),
        t(
          'Every piece must be used once without overlap.',
          'Jedes Teil muss einmal und ohne Überlappung liegen.',
        ),
        t(
          '${remaining.length} pieces remain in the tray. Check for any covered hole or piece extending outside the hull.',
          '${remaining.length} Teile sind noch in der Ablage. Prüfe, ob ein Loch bedeckt ist oder ein Teil über den Rumpf ragt.',
        ),
      );
    case 'grid_filler_game':
      final n = _number(state['gridSize']);
      if (n <= 0) {
        return null;
      }
      final covered = <String>{};
      for (final placed in _array(state['placedPieces']).map(_object)) {
        final pos = _array(placed['position']);
        if (pos.length != 2) {
          continue;
        }
        final x = _number(pos[0]),
            y = _number(pos[1]),
            size = _number(placed['size']);
        for (var r = y; r < y + size; r++) {
          for (var c = x; c < x + size; c++) {
            covered.add('$r,$c');
          }
        }
      }
      final remaining = _array(
        state['availablePieces'],
      ).map(_object).where((p) => _number(p['remainingCount']) > 0).toList();
      final supply = remaining
          .map(
            (p) =>
                '${_number(p['remainingCount'])} × ${_number(p['size'])}×${_number(p['size'])}',
          )
          .join('; ');
      for (var r = 0; r < n; r++) {
        for (var c = 0; c < n; c++) {
          if (covered.contains('$r,$c')) {
            continue;
          }
          return hint(
            t(
              'Inspect the gap at ${cell(r, c)}.',
              'Untersuche die Lücke bei ${cell(r, c)}.',
            ),
            t(
              'Reserve a continuous square for each large piece. Empty squares scattered across the board cannot hold one large square piece.',
              'Halte für jedes große Teil ein zusammenhängendes Quadrat frei. Über das Brett verstreute freie Felder reichen für ein großes Quadrat nicht.',
            ),
            t(
              'Remaining supply: ${supply.isEmpty ? 'none' : supply}. Check the full width and height before placing; you can move or remove earlier pieces to make room.',
              'Restbestand: ${supply.isEmpty ? 'keiner' : supply}. Prüfe vor dem Legen die ganze Breite und Höhe. Du kannst frühere Teile verschieben oder entfernen, um Platz zu schaffen.',
            ),
          );
        }
      }
      return hint(
        t('The board is covered.', 'Das Brett ist bedeckt.'),
        t('Check the remaining supply.', 'Prüfe den Restbestand.'),
        t(
          'Remaining supply: ${supply.isEmpty ? 'none' : supply}. Every available square piece must be placed.',
          'Restbestand: ${supply.isEmpty ? 'keiner' : supply}. Alle vorhandenen Quadratteile müssen gelegt sein.',
        ),
      );
    case 'robot_path_game':
      final level = _object(state['currentLevel']);
      if (level.isEmpty) {
        return null;
      }
      final startRow = _number(level['startRow']),
          startCol = _number(level['startCol']);
      final facing = switch (_number(level['startDirection'])) {
        0 => t('up', 'oben'),
        1 => t('right', 'rechts'),
        2 => t('down', 'unten'),
        _ => t('left', 'links'),
      };
      return hint(
        t(
          'Start at ${cell(startRow, startCol)}, facing $facing.',
          'Starte bei ${cell(startRow, startCol)} mit Blick nach $facing.',
        ),
        t(
          'Trace position and facing separately. Forward moves one square; a turn changes facing in place. Use a special command only on its matching obstacle.',
          'Verfolge Ort und Blickrichtung getrennt. Vorwärts geht ein Feld; Drehen ändert die Richtung am selben Ort. Spezialbefehle brauchen das passende Hindernis.',
        ),
        t(
          'The goal is at ${cell(_number(level['goalRow']), _number(level['goalCol']))}. Your list has ${_array(state['commandSequence']).length} commands, with room for ${_number(state['maxCommands'])}. Trace each command from the start before running it; each run starts from the original board.',
          'Das Ziel liegt bei ${cell(_number(level['goalRow']), _number(level['goalCol']))}. Deine Liste hat ${_array(state['commandSequence']).length} Befehle bei Platz für ${_number(state['maxCommands'])}. Gehe sie vor dem Start einzeln durch; jeder Lauf beginnt auf dem ursprünglichen Brett.',
        ),
      );
    case 'star_loader_game':
      final player = _array(state['_playerPos']);
      final grid = _array(state['_grid']).map(_array).toList();
      if (player.length != 2 || grid.isEmpty) {
        return null;
      }
      final boxes = _array(
        state['_boxPositions'],
      ).map(_array).where((v) => v.length == 2).toList();
      final targets = _array(
        state['_targetPositions'],
      ).map(_array).where((v) => v.length == 2).toList();
      bool hasBox(int r, int c) =>
          boxes.any((b) => _number(b[0]) == c && _number(b[1]) == r);
      final onTargets = targets
          .where((target) => hasBox(_number(target[1]), _number(target[0])))
          .length;
      final row = _number(player[1]), col = _number(player[0]);
      final pushes = <String>[];
      for (final d in <(int, int, String)>[
        (-1, 0, t('up', 'hoch')),
        (1, 0, t('down', 'runter')),
        (0, -1, t('left', 'links')),
        (0, 1, t('right', 'rechts')),
      ]) {
        final nr = row + d.$1, nc = col + d.$2;
        final br = row + 2 * d.$1, bc = col + 2 * d.$2;
        if (hasBox(nr, nc) &&
            br >= 0 &&
            br < grid.length &&
            bc >= 0 &&
            bc < grid[br].length &&
            grid[br][bc] != 'wall' &&
            !hasBox(br, bc)) {
          pushes.add(
            t(
              '${d.$3} would push a box to ${cell(br, bc)}',
              '${d.$3} würde eine Kiste nach ${cell(br, bc)} schieben',
            ),
          );
        }
      }
      return hint(
        t(
          'Plan from the loader at ${cell(row, col)}.',
          'Plane vom Lader bei ${cell(row, col)} aus.',
        ),
        t(
          'You can push one box when the square beyond is clear; you cannot pull. Before pushing, plan where to stand for the following push.',
          'Du kannst eine Kiste schieben, wenn dahinter Platz ist; ziehen geht nicht. Plane vor dem Schieben auch den Standplatz für den nächsten Schub.',
        ),
        t(
          '$onTargets of ${targets.length} targets have a box. ${pushes.isEmpty ? 'There is no immediate push from this position; walk around a box to reach the side you need.' : 'Possible immediate pushes: ${pushes.join('; ')}. A legal push is not necessarily a good plan; avoid non-target corners.'}',
          '$onTargets von ${targets.length} Zielen sind mit Kisten belegt. ${pushes.isEmpty ? 'Von hier ist kein direkter Schub möglich. Gehe um eine Kiste herum auf die benötigte Seite.' : 'Direkt mögliche Schübe: ${pushes.join('; ')}. Erlaubt heißt nicht unbedingt sinnvoll; meide Ecken ohne Ziel.'}',
        ),
      );
    case 'space_station_gridlock':
      final ships = _array(state['ships']).map(_object).toList();
      final index = _number(state['playerShipIndex'], -1);
      if (index < 0 || index >= ships.length) {
        return null;
      }
      final player = ships[index], row = _number(ships[index]['row']);
      final front = _number(player['col']) + _number(player['length']);
      Map<String, dynamic>? blocker;
      for (var c = front; c < 6 && blocker == null; c++) {
        for (var i = 0; i < ships.length; i++) {
          if (i == index) {
            continue;
          }
          final ship = ships[i];
          final sr = _number(ship['row']),
              sc = _number(ship['col']),
              length = _number(ship['length']);
          final horizontal = ship['isHorizontal'] == true;
          if ((horizontal && row == sr && c >= sc && c < sc + length) ||
              (!horizontal && c == sc && row >= sr && row < sr + length)) {
            blocker = ship;
            break;
          }
        }
      }
      final detail = blocker == null
          ? t(
              'No ship currently occupies the exit lane ahead of your ship. Slide the player right to the edge; each cell counts as a move.',
              'Vor deinem Schiff steht gerade kein Schiff in der Ausgangszeile. Schiebe das Spielerschiff rechts bis zum Rand; jedes Feld zählt als Zug.',
            )
          : blocker['isBlocking'] == true
              ? t(
                  'The first blocker starts at ${cell(_number(blocker['row']), _number(blocker['col']))} and is fixed. It cannot be dragged; inspect the available lanes around the other ships.',
                  'Das erste Hindernis beginnt bei ${cell(_number(blocker['row']), _number(blocker['col']))} und ist fest. Es lässt sich nicht ziehen. Prüfe die Wege der anderen Schiffe.',
                )
              : t(
                  'The first blocking ship starts at ${cell(_number(blocker['row']), _number(blocker['col']))}. It can move only ${blocker['isHorizontal'] == true ? 'left/right' : 'up/down'}. Find enough free space to move its whole length out of the player’s route.',
                  'Das erste blockierende Schiff beginnt bei ${cell(_number(blocker['row']), _number(blocker['col']))}. Es fährt nur ${blocker['isHorizontal'] == true ? 'links/rechts' : 'hoch/runter'}. Suche genug Platz, um es ganz aus dem Weg des Spielerschiffs zu bewegen.',
                );
      return hint(
        t(
          'Clear row ${row + 1} toward the right-hand exit.',
          'Mache Zeile ${row + 1} zum Ausgang rechts frei.',
        ),
        t(
          'Ships keep their orientation. Horizontal ships move left/right, vertical ships up/down; neither can rotate or pass through another ship.',
          'Schiffe behalten ihre Ausrichtung. Waagerechte fahren links/rechts, senkrechte hoch/runter. Kein Schiff kann sich drehen oder durch andere fahren.',
        ),
        detail,
      );
    case 'quantum_molecule_builder':
      final grid = _array(state['grid']).map(_array).toList();
      final atoms = _array(state['atoms']).map(_object).toList();
      if (grid.isEmpty || atoms.isEmpty) {
        return null;
      }
      bool clear(int r, int c) =>
          r >= 0 &&
          r < grid.length &&
          c >= 0 &&
          c < grid[r].length &&
          grid[r][c] != 'wall' &&
          !atoms.any((a) => _number(a['row']) == r && _number(a['col']) == c);
      String observation = t(
        'Inspect the target picture, including the empty spaces between its atoms.',
        'Prüfe das Zielbild, auch die leeren Felder zwischen seinen Atomen.',
      );
      outer:
      for (final atom in atoms) {
        final r = _number(atom['row']), c = _number(atom['col']);
        for (final d in <(int, int, String)>[
          (0, 1, t('right', 'rechts')),
          (0, -1, t('left', 'links')),
          (-1, 0, t('up', 'oben')),
          (1, 0, t('down', 'unten')),
        ]) {
          var nr = r, nc = c;
          while (clear(nr + d.$1, nc + d.$2)) {
            nr += d.$1;
            nc += d.$2;
          }
          if (nr == r && nc == c) {
            continue;
          }
          final symbol = _object(atom['type'])['symbol'];
          observation = t(
            'For the ${symbol is String ? symbol : 'shown'} atom at ${cell(r, c)}, a slide ${d.$3} stops at ${cell(nr, nc)}. This is a legal endpoint, not a proved solution. Compare it with the target before moving.',
            'Das ${symbol is String ? symbol : 'gezeigte'}-Atom bei ${cell(r, c)} hält beim Gleiten nach ${d.$3} bei ${cell(nr, nc)}. Das ist ein erlaubter Endpunkt, keine bewiesene Lösung. Vergleiche ihn vor dem Zug mit dem Ziel.',
          );
          break outer;
        }
      }
      final moves = _number(state['movesMade']),
          limit = _number(state['moveLimit']);
      return hint(
        t('Plan where an atom will STOP.', 'Plane, wo ein Atom ANHÄLT.'),
        t(
          'An atom slides until a wall, another atom or the edge stops it. You cannot stop halfway; use other atoms as stoppers. Match the target’s relative pattern anywhere it fits.',
          'Ein Atom gleitet bis zur Wand, zum anderen Atom oder zum Rand. Du kannst es nicht unterwegs anhalten. Nutze andere Atome als Stopper. Das relative Zielmuster darf überall passen.',
        ),
        t(
          '$moves of $limit moves used. $observation',
          '$moves von $limit Zügen verbraucht. $observation',
        ),
      );
    case 'void_crossing':
      final current = _object(state['_gameState']);
      if (current.isEmpty) {
        return null;
      }
      final entities = _array(p['entities']).map(_object).toList();
      final labels = {for (final e in entities) e['id']: e['emoji']};
      String label(Object? id) => labels[id] is String
          ? labels[id] as String
          : t('a creature', 'ein Wesen');
      final onLeft = current['shuttleOnLeft'] == true;
      final leftBehind = _array(
        current[onLeft ? 'leftStation' : 'rightStation'],
      ).toSet();
      final aboard = _array(current['onShuttle']);
      // Snapshot banks already exclude boarded creatures, as the screen does.
      leftBehind.removeAll(aboard);
      final conflicts = _array(p['conflicts'])
          .map(_object)
          .where(
            (r) =>
                leftBehind.contains(r['entityA']) &&
                leftBehind.contains(r['entityB']) &&
                (r['guardian'] == null || !leftBehind.contains(r['guardian'])),
          )
          .toList();
      final warning = conflicts.isEmpty
          ? t(
              'No displayed forbidden pair is left unattended by this loading choice. Also plan who returns on the next trip.',
              'Bei dieser Beladung bleibt kein angezeigtes verbotenes Paar unbeaufsichtigt. Plane auch, wer bei der nächsten Fahrt zurückkommt.',
            )
          : t(
              'Left behind together: ${conflicts.map((r) => '${label(r['entityA'])} + ${label(r['entityB'])}').join('; ')}. Change who is aboard before launching; a shown guardian must remain with its pair.',
              'Zusammen zurückbleiben würden: ${conflicts.map((r) => '${label(r['entityA'])} + ${label(r['entityB'])}').join('; ')}. Ändere die Beladung vor dem Start. Ein angezeigter Wächter muss bei seinem Paar bleiben.',
            );
      return hint(
        t(
          'Check the ${onLeft ? 'left' : 'right'} station you will leave.',
          'Prüfe die ${onLeft ? 'linke' : 'rechte'} Station, die du verlässt.',
        ),
        t(
          'The shuttle supervises its current station. Load within the seat limit, then inspect the creatures staying behind, including guardian rules. You may return empty if that leaves the other station safe.',
          'Das Shuttle beaufsichtigt seine aktuelle Station. Lade innerhalb des Sitzlimits und prüfe die Zurückbleibenden samt Wächterregeln. Leer zurückzufahren ist erlaubt, wenn die andere Station sicher bleibt.',
        ),
        t(
          '${aboard.length} of ${_number(p['boatCapacity'])} seats filled; ${_number(current['movesTaken'])} of ${_number(p['maxMoves'])} crossings used. $warning',
          '${aboard.length} von ${_number(p['boatCapacity'])} Sitzen belegt; ${_number(current['movesTaken'])} von ${_number(p['maxMoves'])} Fahrten verbraucht. $warning',
        ),
      );
    case 'sector_painter':
      return _sectorGuidance(p, state, de);
    case 'ion_chain':
      return _ionGuidance(p, state, de);
    default:
      return null;
  }
}

Map<String, dynamic> _object(Object? raw) =>
    raw is Map ? raw.map((k, v) => MapEntry('$k', v)) : <String, dynamic>{};
List<dynamic> _array(Object? raw) => raw is List ? raw : <dynamic>[];
int _number(Object? raw, [int fallback = 0]) =>
    raw is num ? raw.toInt() : fallback;
Map<String, dynamic> _entries(Object? raw) => raw is Map
    ? _object(raw)
    : {
        for (final pair in _array(raw).map(_array))
          if (pair.length == 2) '${pair[0]}': pair[1],
      };

Map<String, String>? _sectorGuidance(
  Map<String, dynamic> p,
  Map<String, dynamic> state,
  bool de,
) {
  String t(String en, String translated) => de ? translated : en;
  String color(Object? raw) => switch (_number(raw, -1)) {
        0 => t('red', 'Rot'),
        1 => t('green', 'Grün'),
        2 => t('purple', 'Violett'),
        3 => t('yellow', 'Gelb'),
        4 => t('pink', 'Rosa'),
        _ => t('uncolored', 'ungefärbt'),
      };
  final regions = _array(p['regions']);
  if (regions.isEmpty) {
    return null;
  }
  final adjacency = _entries(p['adjacency']),
      coloring = _entries(state['_coloring']);
  for (final r in regions) {
    for (final next in _array(adjacency['$r'])) {
      if (coloring['$r'] != null && coloring['$r'] == coloring['$next']) {
        return {
          'focus': t(
            'Check connected sectors ${_number(r) + 1} and ${_number(next) + 1}.',
            'Prüfe die verbundenen Sektoren ${_number(r) + 1} und ${_number(next) + 1}.',
          ),
          'strategy': t(
            'Only sectors joined by a line must differ. Select another palette color and repaint one end of the conflicting connection.',
            'Nur durch eine Linie verbundene Sektoren müssen verschieden sein. Wähle eine andere Palettenfarbe und färbe ein Ende dieser Verbindung um.',
          ),
          'working': t(
            'Both currently use ${color(coloring['$r'])}. Check every other connected neighbor before choosing the replacement color.',
            'Beide sind gerade ${color(coloring['$r'])}. Prüfe vor der neuen Farbe auch alle anderen verbundenen Nachbarn.',
          ),
        };
      }
    }
  }
  Object? target;
  for (final r in regions) {
    if (!coloring.containsKey('$r')) {
      target = r;
      break;
    }
  }
  if (target == null) {
    return {
      'focus': t('Every sector is colored.', 'Alle Sektoren sind gefärbt.'),
      'strategy': t(
        'Check connections, not whether every sector has a unique color.',
        'Prüfe Verbindungen; nicht jeder Sektor braucht eine eigene Farbe.',
      ),
      'working': t(
        'No same-color connection was found. The goal is a filled board with different colors at the ends of every connection; you do not have to use exactly a stated number of colors.',
        'Es wurde keine gleichfarbige Verbindung gefunden. Das Ziel ist ein volles Brett mit verschiedenen Farben an jeder Verbindung; du musst keine bestimmte Farbanzahl genau treffen.',
      ),
    };
  }
  final used = _array(
    adjacency['$target'],
  ).map((r) => coloring['$r']).where((v) => v != null).toSet();
  final choices = [
    for (var i = 0; i < _number(p['availableColors']); i++)
      if (!used.contains(i)) color(i),
  ];
  return {
    'focus': t(
      'Inspect uncolored sector ${_number(target) + 1}.',
      'Betrachte den ungefärbten Sektor ${_number(target) + 1}.',
    ),
    'strategy': t(
      'Follow its lines and exclude the colors of its painted neighbors. Nearby sectors without a connecting line do not restrict it.',
      'Folge seinen Linien und schließe die Farben der gefärbten Nachbarn aus. Bloß nahe Sektoren ohne Linie schränken es nicht ein.',
    ),
    'working': t(
      'Neighbor colors: ${used.isEmpty ? 'none yet' : used.map(color).join(', ')}. Locally possible palette colors: ${choices.isEmpty ? 'none; recolor a neighbor first' : choices.join(', ')}. A local choice is not a proof that the rest of the board can be completed.',
      'Nachbarfarben: ${used.isEmpty ? 'noch keine' : used.map(color).join(', ')}. Lokal mögliche Palettenfarben: ${choices.isEmpty ? 'keine; färbe zuerst einen Nachbarn um' : choices.join(', ')}. Eine lokale Wahl beweist noch keine Lösung des ganzen Bretts.',
    ),
  };
}

Map<String, String>? _ionGuidance(
  Map<String, dynamic> p,
  Map<String, dynamic> state,
  bool de,
) {
  String t(String en, String translated) => de ? translated : en;
  String bead(Object? raw) => switch (raw) {
        'red' => t('red star', 'roter Stern'),
        'blue' => t('blue circle', 'blauer Kreis'),
        'green' => t('green hexagon', 'grünes Sechseck'),
        'yellow' => t('yellow diamond', 'gelbe Raute'),
        'purple' => t('purple triangle', 'violettes Dreieck'),
        _ => t('empty', 'leer'),
      };
  final chain = _array(state['_playerChain']);
  if (chain.isEmpty) {
    return null;
  }
  final rules = _array(p['rules']).map(_object).toList();
  bool allowed(Object? a, Object? b) {
    if (a == null || b == null) {
      return true;
    }
    for (final rule in rules) {
      if (rule['kind'] == 'noRepeatAtAll' && a == b) {
        return false;
      }
      if (rule['kind'] == 'noSelfPair' && a == rule['a'] && b == rule['a']) {
        return false;
      }
      if (rule['kind'] == 'noMixedPair' &&
          ((a == rule['a'] && b == rule['b']) ||
              (b == rule['a'] && a == rule['b']))) {
        return false;
      }
    }
    return true;
  }

  final slot = chain.indexOf(null);
  if (slot < 0) {
    for (var i = 0; i < chain.length; i++) {
      final next = (i + 1) % chain.length;
      if (!allowed(chain[i], chain[next])) {
        return {
          'focus': t(
            'Check neighboring ring slots ${i + 1} and ${next + 1}.',
            'Prüfe die benachbarten Ringplätze ${i + 1} und ${next + 1}.',
          ),
          'strategy': t(
            'The last and first slots are neighbors too. Remove one of your own placements that breaks a displayed pair rule.',
            'Auch letzter und erster Platz sind Nachbarn. Entferne eine eigene Perle, die ein angezeigtes Paarverbot verletzt.',
          ),
          'working': t(
            '${bead(chain[i])} beside ${bead(chain[next])} breaks a current rule. Fixed beads cannot be removed.',
            '${bead(chain[i])} neben ${bead(chain[next])} verletzt eine aktuelle Regel. Vorgegebene Perlen lassen sich nicht entfernen.',
          ),
        };
      }
    }
    return {
      'focus': t('The ring is filled.', 'Der Ring ist gefüllt.'),
      'strategy': t(
        'Check every neighboring pair, including the join.',
        'Prüfe jedes Nachbarpaar, auch am Ringschluss.',
      ),
      'working': t(
        'No displayed pair rule was broken in this ring check.',
        'Bei dieser Ringprüfung wurde kein angezeigtes Paarverbot verletzt.',
      ),
    };
  }
  final tray = List<dynamic>.from(_array(p['availableIons']));
  final fixed = _array(p['chain']);
  for (var i = 0; i < chain.length; i++) {
    if (i < fixed.length && fixed[i] == null && chain[i] != null) {
      tray.remove(chain[i]);
    }
  }
  final left = chain[(slot - 1 + chain.length) % chain.length],
      right = chain[(slot + 1) % chain.length];
  final candidates =
      tray.toSet().where((v) => allowed(left, v) && allowed(v, right)).toList();
  return {
    'focus': t(
      'Inspect empty ring slot ${slot + 1}.',
      'Betrachte den freien Ringplatz ${slot + 1}.',
    ),
    'strategy': t(
      'Check both neighbors around the ring and the beads actually left in the tray. The last slot also touches the first.',
      'Prüfe beide Nachbarn im Ring und die wirklich übrigen Perlen. Der letzte Platz berührt auch den ersten.',
    ),
    'working': t(
      'Neighbors: ${bead(left)} and ${bead(right)}. From the remaining tray, these pass the immediate pair rules: ${candidates.isEmpty ? 'none' : candidates.map(bead).join(', ')}. The other empty slots must still be fillable; this local check does not prove a completion.',
      'Nachbarn: ${bead(left)} und ${bead(right)}. Aus der übrigen Ablage bestehen diese die direkten Paarregeln: ${candidates.isEmpty ? 'keine' : candidates.map(bead).join(', ')}. Auch alle anderen Lücken müssen füllbar bleiben; diese lokale Prüfung beweist keine vollständige Lösung.',
    ),
  };
}

/// The shared generator emits initial boards rather than full screen saves.
/// Normalize only absent screen fields; a restored/current screen board always
/// takes precedence over its original level asset. Never inspect solutions.
Map<String, dynamic> _normalizeSpatialSnapshot(
  String game,
  Map<String, dynamic> state,
) {
  if (game == 'relic_assembly' && !state.containsKey('placement')) {
    final puzzle = _object(state['puzzle'] ?? state['_puzzle']);
    final rows = _number(puzzle['rows']), cols = _number(puzzle['cols']);
    final count = rows * cols;
    if (rows > 0 && cols > 0 && _array(puzzle['playerTiles']).length == count) {
      return {
        ...state,
        'placement': List<int>.filled(count, -1),
        'rotations': List<int>.filled(count, 0),
      };
    }
  }
  if (game == 'quantum_molecule_builder' && !state.containsKey('grid')) {
    final playfield =
        _array(_object(state['levelData'])['playfield']).map(_array).toList();
    if (playfield.isNotEmpty) {
      final grid = <List<String>>[];
      final atoms = <Map<String, dynamic>>[];
      for (var r = 0; r < playfield.length; r++) {
        final row = <String>[];
        for (var c = 0; c < playfield[r].length; c++) {
          final tile = _object(playfield[r][c]);
          row.add(tile['type'] == 'wall' ? 'wall' : 'empty');
          if (tile['type'] == 'atom') {
            atoms.add({'row': r, 'col': c, 'type': <String, dynamic>{}});
          }
        }
        grid.add(row);
      }
      return {...state, 'grid': grid, 'atoms': atoms, 'movesMade': 0};
    }
  }
  if (game == 'star_loader_game' && !state.containsKey('_grid')) {
    final level = _object(state['_currentLevelData']);
    final structure = _array(level['roomStructure']).map(_array).toList();
    final room = _array(level['roomState']).map(_array).toList();
    if (structure.isNotEmpty) {
      final grid = <List<String>>[];
      final players = <List<int>>[],
          boxes = <List<int>>[],
          targets = <List<int>>[];
      for (var r = 0; r < structure.length; r++) {
        final row = <String>[];
        for (var c = 0; c < structure[r].length; c++) {
          final tile = _number(structure[r][c]);
          row.add(tile == 0
              ? 'wall'
              : tile == 2
                  ? 'target'
                  : 'floor');
          if (tile == 2) {
            targets.add([c, r]);
          }
          if (r < room.length && c < room[r].length) {
            final occupant = _number(room[r][c]);
            if (occupant == 5 || occupant == 6) {
              players.add([c, r]);
            }
            if (occupant == 3 || occupant == 4) {
              boxes.add([c, r]);
            }
          }
        }
        grid.add(row);
      }
      return {
        ...state,
        '_grid': grid,
        if (!state.containsKey('_playerPos') && players.length == 1)
          '_playerPos': players.single,
        if (!state.containsKey('_boxPositions')) '_boxPositions': boxes,
        if (!state.containsKey('_targetPositions')) '_targetPositions': targets,
      };
    }
    // The optional fresh Sokoban generator emits standard ASCII; bundled
    // screen LevelData instead stores W/P/Y/B/T/X rows. Both describe only
    // visible current cells, not solution commands or reference paths.
    final ascii = state['ascii'];
    final layout = _array(level['layout']);
    if (ascii is String || layout.isNotEmpty) {
      final standard = ascii is String;
      final lines =
          standard ? ascii.split('\n') : layout.map((v) => '$v').toList();
      final grid = <List<String>>[];
      final players = <List<int>>[],
          boxes = <List<int>>[],
          targets = <List<int>>[];
      for (var r = 0; r < lines.length; r++) {
        final line = lines[r].replaceAll('\r', '');
        final row = <String>[];
        for (var c = 0; c < line.length; c++) {
          final tile = line[c];
          final wall = standard ? tile == '#' : tile == 'W';
          final target = standard ? '.+*'.contains(tile) : 'TYX'.contains(tile);
          row.add(wall
              ? 'wall'
              : target
                  ? 'target'
                  : 'floor');
          if (target) {
            targets.add([c, r]);
          }
          if (standard ? '@+'.contains(tile) : 'PY'.contains(tile)) {
            players.add([c, r]);
          }
          if (standard ? r'$*'.contains(tile) : 'BX'.contains(tile)) {
            boxes.add([c, r]);
          }
        }
        grid.add(row);
      }
      if (players.length == 1) {
        return {
          ...state,
          '_grid': grid,
          if (!state.containsKey('_playerPos')) '_playerPos': players.single,
          if (!state.containsKey('_boxPositions')) '_boxPositions': boxes,
          if (!state.containsKey('_targetPositions'))
            '_targetPositions': targets,
        };
      }
    }
  }
  return state;
}
