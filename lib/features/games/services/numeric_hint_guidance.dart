/// Visible-board guidance only: no solution keys or hidden answers are read.
/// A null result leaves the existing bounded constraint-completion hint intact.
Map<String, String>? numericHintGuidance(
  String game,
  Map<String, dynamic> state, {
  bool german = false,
}) {
  String t(String en, String de) => german ? de : en;
  Map<String, String> hint(String focus, String strategy, String working) => {
        'focus': focus,
        'strategy': strategy,
        'working': working,
      };
  final p = _numericMap(
    state['puzzle'] ?? state['_puzzle'] ?? state['currentPuzzle'],
  );
  final proposedTarget = state['_hintTarget'];
  final proposedValue = state['_hintValue'];
  if (state['_hintVerified'] == true &&
      proposedTarget is String &&
      proposedValue is int) {
    final target = proposedTarget, value = proposedValue;
    final values = {
      ..._numericPairs(p['clues']),
      ..._numericPairs(state['answers']),
    };
    if (game == 'star_forge') {
      final lines = _numericList(p['lines'])
          .map(_numericList)
          .where((line) => line.any((node) => '$node' == target))
          .toList();
      if (lines.isEmpty) {
        return null;
      }
      final shown = lines
          .map(
            (line) =>
                '${line.map((node) => '$node' == target ? '[$value]' : values['$node'] is int ? '${values['$node']}' : '□').join(' + ')} = ${p['magicConstant']}',
          )
          .join('\n');
      return hint(
        t(
          'Place $value at star node ${int.parse(target) + 1}.',
          'Setze $value auf Sternknoten ${int.parse(target) + 1}.',
        ),
        t(
          'Each full drawn straight line has the target sum. This node belongs to every line shown below; its one value counts in each.',
          'Jede vollständige gezeichnete Gerade hat die Zielsumme. Dieser Knoten gehört zu jeder unten gezeigten Geraden; sein Wert zählt in jeder davon.',
        ),
        '$shown\n${t('[$value] is the suggested placement; □ are other empty nodes. A completion respecting all lines, unique numbers and your placements supports it.', '[$value] ist der Vorschlag; □ sind andere leere Knoten. Eine Ergänzung mit allen Geraden, verschiedenen Zahlen und deinen Platzierungen unterstützt ihn.')}',
      );
    }
    if (game == 'number_walls' || game == 'solarpanel_game') {
      final hidden = _numericList(p['hiddenCells']).map((v) => '$v').toList()
        ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));
      final answers = _numericList(state['answers'] ?? state['userAnswers']);
      values.addAll(_numericPairs(p['visibleValues']));
      for (var i = 0; i < hidden.length && i < answers.length; i++) {
        if (answers[i] is int) {
          values[hidden[i]] = answers[i];
        }
      }
      final equations = <({List<String> cells, String op})>[];
      if (game == 'solarpanel_game') {
        equations.addAll([
          (cells: ['1', '3', '4'], op: '×'),
          (cells: ['2', '4', '5'], op: '×'),
          (cells: ['0', '1', '2'], op: '+'),
        ]);
      } else {
        final height = p['wallHeight'];
        if (height is! int) {
          return null;
        }
        final operation = '${p['operation']}';
        final op = switch (operation) {
          'addition' => '+',
          'subtraction' => 'difference',
          'multiplication' => '×',
          'division' => 'quotient',
          _ => '?',
        };
        for (var r = 0; r < height - 1; r++) {
          for (var c = 0; c <= r; c++) {
            final parent = r * (r + 1) ~/ 2 + c,
                left = (r + 1) * (r + 2) ~/ 2 + c;
            equations.add((cells: ['$parent', '$left', '${left + 1}'], op: op));
          }
        }
      }
      String show(String cell) => cell == target
          ? '[$value]'
          : values[cell] is int
              ? '${values[cell]}'
              : '□';
      final affected = equations
          .where((e) => e.cells.contains(target))
          .map(
            (e) => e.op == 'difference'
                ? '${show(e.cells[0])} = |${show(e.cells[1])} − ${show(e.cells[2])}|'
                : e.op == 'quotient'
                    ? t(
                        '${show(e.cells[0])} = larger(${show(e.cells[1])},${show(e.cells[2])}) ÷ smaller (no remainder)',
                        '${show(e.cells[0])} = größer(${show(e.cells[1])},${show(e.cells[2])}) ÷ kleiner (ohne Rest)',
                      )
                    : '${show(e.cells[0])} = ${show(e.cells[1])} ${e.op} ${show(e.cells[2])}',
          )
          .join('\n');
      return hint(
        t('Try $value in this gap.', 'Setze $value in diese Lücke.'),
        game == 'solarpanel_game'
            ? t(
                'The middle panels multiply adjacent bottom numbers; the top ADDS the middle panels.',
                'Die mittleren Felder multiplizieren benachbarte untere Zahlen; die Spitze ADDIERT die mittleren Felder.',
              )
            : t(
                'Every upper brick uses its two immediate lower neighbours. Check all triangles touching the gap.',
                'Jeder obere Stein nutzt seine zwei direkten unteren Nachbarn. Prüfe alle Dreiecke an dieser Lücke.',
              ),
        '$affected\n${t('[$value] marks the suggested placement. It belongs to a completion respecting the current placements and all connected rules.', '[$value] markiert den Vorschlag. Er gehört zu einer Ergänzung, die deine Platzierungen und alle verbundenen Regeln berücksichtigt.')}',
      );
    }
    if (game == 'orbital_towers' ||
        game == 'nebula_matrix' ||
        game == 'kenken') {
      final size = p['size'];
      final match = RegExp(r'^r(\d+)c(\d+)$').firstMatch(target);
      if (size is! int || match == null) {
        return null;
      }
      final row = int.parse(match[1]!), col = int.parse(match[2]!);
      String show(String cell) => cell == target
          ? '[$value]'
          : values[cell] is int
              ? '${values[cell]}'
              : '□';
      final rowText = [
        for (var c = 0; c < size; c++) show('r${row}c$c'),
      ].join(' · ');
      final colText = [
        for (var r = 0; r < size; r++) show('r${r}c$col'),
      ].join(' · ');
      var work = t(
        'Row ${row + 1}: $rowText\nColumn ${col + 1}, top to bottom: $colText',
        'Zeile ${row + 1}: $rowText\nSpalte ${col + 1}, von oben: $colText',
      );
      if (game == 'kenken') {
        for (final raw in _numericList(p['cages'])) {
          final cage = _numericMap(raw);
          final cells = _numericList(cage['cells']).map((c) => '$c').toList();
          if (cells.contains(target)) {
            work +=
                '\n${t('Cage', 'Käfig')} ${cage['clue']}: ${cells.map(show).join(' · ')}';
            break;
          }
        }
      } else if (game == 'nebula_matrix') {
        for (final raw in _numericList(p['zones'])) {
          final cells = _numericList(raw).map((c) => '$c').toList();
          if (cells.contains(target)) {
            work +=
                '\n${t('Region', 'Bereich')}: ${cells.map(show).join(' · ')}';
            break;
          }
        }
      } else {
        final clues = _numericMap(p['edgeClues']);
        for (final edge in [
          ('left_$row', t('from left', 'von links')),
          ('right_$row', t('from right', 'von rechts')),
          ('top_$col', t('from top', 'von oben')),
          ('bottom_$col', t('from bottom', 'von unten')),
        ]) {
          if (clues[edge.$1] != null) {
            work +=
                '\n${t('View', 'Blick')} ${edge.$2}: ${t('exactly', 'genau')} ${clues[edge.$1]} ${t('visible towers', 'sichtbare Türme')}';
          }
        }
      }
      work +=
          '\n${t('[$value] is a placement supported by a completion respecting your board; □ are still empty. It is not a claim that the number follows from this row alone.', '[$value] ist ein Vorschlag aus einer passenden Ergänzung deines Feldes; □ sind noch leer. Die Zahl muss nicht allein aus dieser Zeile folgen.')}';
      return hint(
        t(
          'Place $value at ${_numericLocation(target, false)}.',
          'Setze $value in ${_numericLocation(target, true)}.',
        ),
        game == 'orbital_towers'
            ? t(
                'Use each height once in every row and column. From a clue’s edge count only towers taller than every tower before them.',
                'Nutze jede Höhe einmal pro Zeile und Spalte. Zähle vom Randhinweis aus nur Türme, die höher als alle davor sind.',
              )
            : game == 'kenken'
                ? t(
                    'The row and column need 1 to $size once each; the outlined cage must ALSO meet its arithmetic clue.',
                    'Zeile und Spalte brauchen 1 bis $size je einmal; der umrandete Käfig muss ZUSÄTZLICH seine Rechenvorgabe erfüllen.',
                  )
                : t(
                    'The row, column and any drawn region need 1 to $size once each.',
                    'Zeile, Spalte und ein eventuell eingezeichneter Bereich brauchen 1 bis $size je einmal.',
                  ),
        work,
      );
    }
  }
  if (game == 'chrono_repair') {
    final hour = state['_displayedHour'], minute = state['_displayedMinute'];
    if (hour is! int || minute is! int) {
      return null;
    }
    final shown = '$hour:${minute.toString().padLeft(2, '0')}';
    final mirror = state['_malfunction'] == 'mirror';
    if (mirror) {
      final total = (720 - ((hour % 12) * 60 + minute)) % 720;
      final corrected = _numericClock(total);
      return hint(
        t('Reflect the clock showing $shown.', 'Spiegle die Uhr mit $shown.'),
        t(
          'Reflect BOTH hands across the vertical axis. Reflecting the minute separately loses the hour hand’s progress.',
          'Spiegle BEIDE Zeiger an der senkrechten Achse. Wenn du nur die Minuten spiegelst, geht die fortgeschrittene Stundenposition verloren.',
        ),
        t(
          'The reflected time is $corrected. Select that hour and minute, then check.',
          'Die gespiegelte Zeit ist $corrected. Wähle diese Stunde und Minute und prüfe.',
        ),
      );
    }
    final hours = state['_offsetHours'], minutes = state['_offsetMinutes'];
    if (hours is! int || minutes is! int) {
      return null;
    }
    final offset = hours * 60 + minutes;
    final corrected = _numericClock(hour % 12 * 60 + minute - offset);
    return hint(
      t(
        'Undo the advance from $shown.',
        'Mache den Vorsprung bei $shown rückgängig.',
      ),
      t(
        'The clock is ahead, so subtract its advance. Borrow an hour when subtracting more minutes than the clock shows.',
        'Die Uhr geht vor, also ziehe ihren Vorsprung ab. Gehe eine Stunde zurück, wenn du mehr Minuten abziehst, als angezeigt werden.',
      ),
      t(
        '$shown − $hours h $minutes min = $corrected. Select BOTH corrected fields and check.',
        '$shown − $hours h $minutes min = $corrected. Wähle BEIDE korrigierten Felder und prüfe.',
      ),
    );
  }
  if (game == 'galactic_market') {
    final total = state['_changeTotal'], count = state['_unknownCount'];
    final coins = _numericList(state['_knownCoins']);
    if (total is! int ||
        count is! int ||
        count <= 0 ||
        coins.any((v) => v is! int)) {
      return null;
    }
    final visible = coins.cast<int>().fold(0, (a, b) => a + b);
    final remainder = total - visible;
    if (remainder < 0 || remainder % count != 0) {
      return null;
    }
    final denomination = remainder ~/ count;
    return hint(
      t(
        'Find the value of ONE of the $count hidden coins.',
        'Finde den Wert EINER der $count verdeckten Münzen.',
      ),
      t(
        'Subtract the visible money before dividing. The remaining total belongs to all hidden coins together.',
        'Ziehe vor dem Teilen das sichtbare Geld ab. Der verbleibende Wert gehört allen verdeckten Münzen gemeinsam.',
      ),
      t(
        '$total − $visible = $remainder; $remainder ÷ $count = $denomination each. Select $denomination and submit. Check: $visible + $count × $denomination = $total.',
        '$total − $visible = $remainder; $remainder ÷ $count = $denomination pro Münze. Wähle $denomination und bestätige. Probe: $visible + $count × $denomination = $total.',
      ),
    );
  }
  if (game == 'arithmatic_square' || game == 'arithmancer_crosswords') {
    final values = {
      ..._numericPairs(p['clues']),
      ..._numericPairs(p['playerHints']),
      ..._numericPairs(state['userSolution']),
    };
    final equations = <({List<String> cells, List<String> ops})>[];
    if (game == 'arithmatic_square') {
      final size = p['gridSize'];
      final rowOps = _numericList(p['rowOperators']);
      final colOps = _numericList(p['columnOperators']);
      if (size is! int ||
          size < 2 ||
          rowOps.length != size ||
          colOps.length != size) {
        return null;
      }
      for (var i = 0; i < size; i++) {
        equations.add((
          cells: [for (var c = 0; c < size; c++) 'r${i}c$c'],
          ops: _numericList(rowOps[i]).cast<String>(),
        ));
        equations.add((
          cells: [for (var r = 0; r < size; r++) 'r${r}c$i'],
          ops: _numericList(colOps[i]).cast<String>(),
        ));
      }
    } else {
      for (final raw in _numericList(p['equations'])) {
        final eq = _numericMap(raw);
        final cells = <String>[];
        for (final point in _numericList(eq['numberCells'])) {
          final coordinates = _numericList(point);
          if (coordinates.length == 2) {
            cells.add('C_${coordinates[1]}_${coordinates[0]}');
          }
        }
        if (cells.length == 3 && eq['operator'] is String) {
          equations.add((cells: cells, ops: [eq['operator'] as String]));
        }
      }
    }
    equations.sort(
      (a, b) => a.cells
          .where((c) => values[c] is! int)
          .length
          .compareTo(b.cells.where((c) => values[c] is! int).length),
    );
    for (final eq in equations) {
      final missing = eq.cells.where((c) => values[c] is! int).toList();
      final computed = missing.isEmpty
          ? _numericEvaluate(
              eq.cells
                  .sublist(0, eq.cells.length - 1)
                  .map((c) => values[c] as int)
                  .toList(),
              eq.ops,
            )
          : null;
      // Skip a fully satisfied equation; show the first useful incomplete or wrong one.
      if (missing.isEmpty && computed == values[eq.cells.last]) {
        continue;
      }
      String show(String cell) => values[cell] is int ? '${values[cell]}' : '□';
      var expression = show(eq.cells.first);
      for (var i = 0; i < eq.ops.length && i + 1 < eq.cells.length - 1; i++) {
        final op = _numericOperator(eq.ops[i]);
        expression = game == 'arithmatic_square'
            ? '($expression $op ${show(eq.cells[i + 1])})'
            : '$expression $op ${show(eq.cells[i + 1])}';
      }
      expression += ' = ${show(eq.cells.last)}';
      final sequential = game == 'arithmatic_square';
      final location = _numericLocation(
        missing.isEmpty ? eq.cells.first : missing.first,
        german,
      );
      return hint(
        t(
          'Check the equation through $location.',
          'Prüfe die Gleichung durch $location.',
        ),
        sequential
            ? t(
                'This game evaluates from left to right or top to bottom. The parentheses below show that order. The shared cell must also fit its crossing equation.',
                'Dieses Spiel rechnet von links nach rechts beziehungsweise oben nach unten. Die Klammern unten zeigen diese Reihenfolge. Das gemeinsame Feld muss auch zur kreuzenden Gleichung passen.',
              )
            : t(
                'Use the displayed operation to find the missing number, then substitute it in the crossing equation. Division must have no remainder.',
                'Nutze das angezeigte Rechenzeichen für die fehlende Zahl und setze sie danach in die kreuzende Gleichung ein. Division muss ohne Rest aufgehen.',
              ),
        missing.isEmpty
            ? t(
                '$expression does not work with your current entries. Recheck the numbers you placed in this equation.',
                '$expression stimmt mit deinen aktuellen Einträgen nicht. Prüfe deine Zahlen in dieser Gleichung erneut.',
              )
            : '$expression\n${t('Each □ is its own empty cell; do not assume different gaps have the same value.', 'Jedes □ steht für ein eigenes leeres Feld; verschiedene Lücken müssen nicht denselben Wert haben.')}',
      );
    }
    return hint(
      t('Check every crossing.', 'Prüfe jede Kreuzung.'),
      t(
        'Every row and column must agree on their shared cells.',
        'Jede Zeile und Spalte muss mit den gemeinsamen Feldern übereinstimmen.',
      ),
      t(
        'All readable equations match your current entries. Complete any remaining empty cells.',
        'Alle lesbaren Gleichungen stimmen mit deinen Einträgen überein. Fülle eventuell verbleibende leere Felder.',
      ),
    );
  }
  if (game == 'codebreaker') {
    final equations = _numericList(p['equations']).map(_numericMap).toList();
    final known = _numericMap(p['knownSymbolValues']);
    final answers = _numericMap(state['answers']);
    final assigned = <String, dynamic>{...known};
    for (final entry in answers.entries) {
      final match = RegExp(
        r'^eq(\d+)_(term1|term2|result)$',
      ).firstMatch(entry.key);
      if (match == null) {
        continue;
      }
      final index = int.parse(match[1]!);
      if (index >= equations.length) {
        continue;
      }
      final symbol = equations[index][match[2]!];
      if (symbol is String) {
        assigned[symbol] = entry.value;
      }
    }
    equations.sort((a, b) {
      int unknownCount(Map<String, dynamic> equation) => [
            equation['term1'],
            equation['term2'],
            equation['result'],
          ].where((term) => term is String && assigned[term] is! int).length;
      return unknownCount(a).compareTo(unknownCount(b));
    });
    for (final eq in equations) {
      String show(Object? term) => term is String && assigned[term] is int
          ? '$term(${assigned[term]})'
          : '$term';
      final terms = [eq['term1'], eq['term2'], eq['result']];
      if (terms.any((v) => v == null)) {
        continue;
      }
      if (!terms.any((v) => v is String && assigned[v] is! int)) {
        continue;
      }
      final expression =
          '${show(terms[0])} ${_numericOperator('${eq['op']}')} ${show(terms[1])} = ${show(terms[2])}';
      return hint(
        t('Use one symbol consistently.', 'Nutze ein Symbol überall gleich.'),
        t(
          'Start with a symbol whose equation has the fewest unknowns. Values in parentheses are your current assignments, not guarantees that they are correct.',
          'Beginne mit einem Symbol, dessen Gleichung möglichst wenige Unbekannte hat. Werte in Klammern sind deine aktuellen Zuweisungen; sie müssen nicht richtig sein.',
        ),
        '$expression\n${t('Solve this equation, then check the same symbol in the other equations. Dropping one tile assigns all hidden copies of that symbol together.', 'Löse diese Gleichung und prüfe dasselbe Symbol in den anderen Gleichungen. Eine abgelegte Zahl weist allen verdeckten Kopien dieses Symbols gemeinsam den Wert zu.')}',
      );
    }
    return hint(
      t('Recheck assigned symbols.', 'Prüfe die zugewiesenen Symbole.'),
      t(
        'A symbol has one shared value across all equations.',
        'Ein Symbol hat in allen Gleichungen denselben Wert.',
      ),
      t(
        'Read every equation using your placed values. Tap a wrong assignment to remove that symbol’s value, then place its replacement.',
        'Lies jede Gleichung mit deinen eingesetzten Werten. Tippe auf eine falsche Zuweisung, um den Wert dieses Symbols zu entfernen, und setze ihn neu ein.',
      ),
    );
  }
  if (game == 'cryptex_lock_breaker') {
    final dials = _numericList(state['dialValues']);
    for (final raw in _numericList(p['equations'])) {
      final eq = _numericMap(raw);
      final indices = _numericList(eq['leftOperandIndices']);
      if (indices.length < 2 ||
          indices.any((i) => i is! int || i < 0 || i >= dials.length)) {
        continue;
      }
      final a = dials[indices[0] as int], b = dials[indices[1] as int];
      if (a is! int || b is! int) {
        continue;
      }
      final resultIndex = eq['resultDialIndex'];
      final right =
          resultIndex is int && resultIndex >= 0 && resultIndex < dials.length
              ? dials[resultIndex]
              : eq['rightSide'];
      final op = eq['operator'];
      final actual = switch (op) {
        '+' => a + b,
        '-' => (a - b).abs(),
        '*' => a * b,
        '/' => b == 0 ? 0 : a ~/ b,
        _ => null,
      };
      if (actual == right) {
        continue;
      }
      String label(int index) => String.fromCharCode(65 + index);
      final lhs =
          '${label(indices[0] as int)}($a) ${_numericOperator('$op')} ${label(indices[1] as int)}($b)';
      final rhs =
          resultIndex is int ? '${label(resultIndex)}($right)' : '$right';
      final note = op == '-'
          ? t(
              'For this lock, subtraction means the positive difference.',
              'Bei diesem Schloss bedeutet Minus den positiven Unterschied.',
            )
          : op == '/'
              ? t(
                  'This lock currently uses the whole-number quotient. Recheck the other equations too.',
                  'Dieses Schloss verwendet derzeit den ganzzahligen Quotienten. Prüfe auch die anderen Gleichungen.',
                )
              : '';
      return hint(
        t(
          'Repair an equation that is still false.',
          'Repariere eine Gleichung, die noch falsch ist.',
        ),
        t(
          'Keep correct equations intact when possible. A shared dial changes every equation containing that letter.',
          'Erhalte richtige Gleichungen möglichst. Ein gemeinsames Rad ändert jede Gleichung mit diesem Buchstaben.',
        ),
        '$lhs = $rhs\n${t('The left side currently gives $actual, so this equation is not satisfied.', 'Links ergibt sich aktuell $actual; diese Gleichung stimmt also noch nicht.')} $note',
      );
    }
    return hint(
      t('Check all equations together.', 'Prüfe alle Gleichungen gemeinsam.'),
      t(
        'The lock opens when every equation is true after a committed adjustment.',
        'Das Schloss öffnet sich, wenn nach einer abgeschlossenen Einstellung alle Gleichungen stimmen.',
      ),
      t(
        'Finish the current dial gesture and compare all displayed equations.',
        'Beende die aktuelle Radbewegung und vergleiche alle angezeigten Gleichungen.',
      ),
    );
  }
  if (game == 'gravity_well') {
    final answers = _numericPairs(state['_userAnswers']);
    for (final raw in _numericList(p['scales'])) {
      final scale = _numericMap(raw);
      final left = _numericList(scale['leftSide']).map(_numericMap).toList();
      final right = _numericList(scale['rightSide']).map(_numericMap).toList();
      if (left.isEmpty || right.isEmpty) {
        continue;
      }
      final unknowns = [
        ...left,
        ...right,
      ].where((i) => i['isKnown'] != true).map((i) => '${i['label']}').toSet();
      if (unknowns.isEmpty) {
        continue;
      }
      String side(List<Map<String, dynamic>> items) => items
          .map(
            (i) => i['isKnown'] == true ? '${i['weight']} kg' : '${i['label']}',
          )
          .join(' + ');
      final entries = unknowns
          .where((label) => answers[label] is int)
          .map((label) => '$label = ${answers[label]} kg')
          .join('; ');
      return hint(
        t('Use this balanced scale.', 'Nutze diese ausgeglichene Waage.'),
        t(
          'Both sides have equal weight. Cancel equal objects or known weights on both sides; divide if several identical unknowns remain.',
          'Beide Seiten wiegen gleich viel. Streiche gleiche Objekte oder bekannte Gewichte auf beiden Seiten; teile, wenn mehrere gleiche Unbekannte bleiben.',
        ),
        '${side(left)} = ${side(right)}\n${entries.isEmpty ? '' : t('Your entries (still to check): $entries. ', 'Deine Einträge (noch zu prüfen): $entries. ')}${t('Use a deduced weight on every scale containing the same letter, then check all answer fields.', 'Nutze ein ermitteltes Gewicht auf jeder Waage mit demselben Buchstaben und prüfe dann alle Antwortfelder.')}',
      );
    }
    return null;
  }
  if (game == 'vault_cracker') {
    final clues = _numericList(p['clues'])
        .map(_numericMap)
        .map((c) => c[german ? 'de' : 'en'])
        .whereType<String>()
        .toList();
    if (clues.isEmpty) {
      return null;
    }
    final code = _numericList(state['answer']);
    final display = code.map((v) => v is int ? '$v' : '□').join(' · ');
    return hint(
      t(
        'Combine the written code clues.',
        'Verknüpfe die geschriebenen Codehinweise.',
      ),
      t(
        'Use fixed-position clues first, then check sums, comparisons and parity together. A candidate must satisfy every clue before you submit.',
        'Nutze feste Positionshinweise zuerst und prüfe dann Summen, Vergleiche und Gerade-Ungerade-Bedingungen gemeinsam. Ein Kandidat muss vor dem Bestätigen jeden Hinweis erfüllen.',
      ),
      '${clues.take(3).join('\n')}\n${t('Current entry: $display. Keep green digits in place; move yellow digits to other positions. Each colored match uses one copy of a digit.', 'Aktueller Eintrag: $display. Lass grüne Ziffern an ihrer Stelle; verschiebe gelbe an andere Stellen. Jede farbige Zuordnung verbraucht ein Vorkommen einer Ziffer.')}',
    );
  }
  return null;
}

Map<String, dynamic> _numericMap(Object? value) =>
    value is Map ? value.map((key, value) => MapEntry('$key', value)) : {};
List<dynamic> _numericList(Object? value) => value is List ? value : [];
Map<String, dynamic> _numericPairs(Object? value) => value is Map
    ? _numericMap(value)
    : {
        for (final pair in _numericList(value))
          if (pair is List && pair.length == 2) '${pair[0]}': pair[1],
      };
String _numericClock(int minutes) {
  final total = minutes % 720;
  final hour = total ~/ 60;
  return '${hour == 0 ? 12 : hour}:${(total % 60).toString().padLeft(2, '0')}';
}

String _numericOperator(String op) => switch (op) {
      '*' => '×',
      '/' => '÷',
      '-' => '−',
      _ => op,
    };
String _numericLocation(String id, bool german) {
  final match = RegExp(r'^(?:r|C_)(\d+)(?:c|_)(\d+)$').firstMatch(id);
  if (match == null) {
    return id;
  }
  return '${german ? 'Zeile' : 'row'} ${int.parse(match[1]!) + 1}, ${german ? 'Spalte' : 'column'} ${int.parse(match[2]!) + 1}';
}

int? _numericEvaluate(List<int> values, List<String> operators) {
  if (values.isEmpty || operators.length != values.length - 1) {
    return null;
  }
  var total = values.first;
  for (var i = 0; i < operators.length; i++) {
    final next = values[i + 1];
    switch (operators[i]) {
      case '+':
        total += next;
      case '-':
      case '−':
        total -= next;
      case '*':
      case '×':
        total *= next;
      case '/':
      case '÷':
        if (next == 0 || total % next != 0) {
          return null;
        }
        total ~/= next;
      default:
        return null;
    }
  }
  return total;
}
