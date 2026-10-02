import 'dart:math' as math;
import 'hint_completion_solver.dart';

/// Pure Dart: hints consume a frozen JSON board, never screen/model objects.
/// Verified moves come from constraints; observations deliberately make no
/// claim that a local candidate is a globally optimal solution.
class BoardHint {
  final String focus, strategy, working;
  final String? target;
  final Object? value;
  final bool verified;
  const BoardHint(this.focus, this.strategy, this.working,
      {this.target, this.value, this.verified = false});
  Map<String, dynamic> toJson() => {
        'focus': focus,
        'strategy': strategy,
        'working': working,
        'target': target,
        'value': value,
        'verified': verified
      };
}

Map<String, dynamic> _map(Object? v) =>
    v is Map ? v.map((k, v) => MapEntry(k.toString(), v)) : <String, dynamic>{};
List<dynamic> _list(Object? v) => v is List ? v : <dynamic>[];
Map<String, dynamic> _pairs(Object? v) => v is Map
    ? _map(v)
    : {
        for (final e in _list(v))
          if (e is List && e.length == 2) e[0].toString(): e[1]
      };
String _cell(String id, bool de) {
  final match = RegExp(r'^(?:r|C_)(\d+)(?:c|_)(\d+)$').firstMatch(id);
  if (match == null) return id;
  return '${de ? 'Zeile' : 'row'} ${int.parse(match[1]!) + 1}, '
      '${de ? 'Spalte' : 'column'} ${int.parse(match[2]!) + 1}';
}

String _faceLabel(String face, bool de) => de
    ? switch (face) {
        'top' => 'oben',
        'bottom' => 'unten',
        'front' => 'vorne',
        'back' => 'hinten',
        'left' => 'links',
        'right' => 'rechts',
        _ => 'die gesuchte Seite',
      }
    : switch (face) {
        'top' => 'top',
        'bottom' => 'bottom',
        'front' => 'front',
        'back' => 'back',
        'left' => 'left',
        'right' => 'right',
        _ => 'the requested face',
      };

BoardHint? findBoardHint(String game, Map<String, dynamic> state,
    {bool german = false}) {
  String t(String en, String de) => german ? de : en;
  final p = _map(state['puzzle'] ?? state['_puzzle'] ?? state['currentPuzzle']);
  BoardHint observe(String en, String de, String workEn, String workDe,
          {String? target, Object? value, bool verified = false}) =>
      BoardHint(
          t(en, de),
          t('Use the visible rules and your current placements.',
              'Nutze die sichtbaren Regeln und deine aktuellen Platzierungen.'),
          t(workEn, workDe),
          target: target,
          value: value,
          verified: verified);
  BoardHint? solve(Map<String, dynamic> data, List<String> empty, String ruleEn,
      String ruleDe) {
    final values = _map(data['values']);
    final missing = empty.where((c) => !values.containsKey(c)).toList();
    if (missing.isEmpty) {
      return observe(
          'Your board is filled.',
          'Dein Feld ist gefüllt.',
          'Check every constraint before submitting.',
          'Prüfe vor dem Bestätigen alle Regeln.');
    }
    final completion =
        findHintCompletion({...data, 'maxVisits': 12000, 'timeoutMs': 40});
    final target = missing.first;
    if (completion == null) {
      return observe(
          'Check ${_cell(target, false)}.',
          'Prüfe ${_cell(target, true)}.',
          '$ruleEn A compatible completion was not found within the search limit; review the filled clues.',
          '$ruleDe Innerhalb der Suchgrenze wurde keine passende Ergänzung gefunden; prüfe die ausgefüllten Hinweise.',
          target: target);
    }
    final value = completion[target]!;
    return BoardHint(
        t('Focus on ${_cell(target, false)}.',
            'Betrachte ${_cell(target, true)}.'),
        t(ruleEn, ruleDe),
        t('One completion respecting your placements puts $value here.',
            'Eine Ergänzung, die deine Platzierungen berücksichtigt, setzt hier $value ein.'),
        target: target,
        value: value,
        verified: true);
  }

  switch (game) {
    case 'star_forge':
      final empty = _list(p['emptyNodes']).map((v) => '$v').toList();
      final clues = _map(p['clues']);
      return solve({
        'values': {...clues, ..._map(state['answers'])},
        'domains': {for (final c in empty) c: p['numberPool']},
        'groups': [List.generate(p['nodeCount'] as int, (i) => '$i')],
        'pool': p['numberPool'],
        'equations': [
          for (final line in _list(p['lines']))
            {
              'cells': _list(line).map((v) => '$v').toList(),
              'op': 'sum',
              'target': p['magicConstant']
            }
        ]
      },
          empty,
          'Each arm must total ${p['magicConstant']}; nodes cannot repeat.',
          'Jeder Arm muss ${p['magicConstant']} ergeben; Knoten dürfen sich nicht wiederholen.');
    case 'number_walls':
    case 'solarpanel_game':
      final empty = _list(p['hiddenCells']).map((v) => '$v').toList()
        ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));
      final answers = _list(state['answers'] ?? state['userAnswers']);
      final values = {
        ..._pairs(p['visibleValues']),
        for (int i = 0; i < empty.length; i++)
          if (i < answers.length && answers[i] != null) empty[i]: answers[i]
      };
      final equations = <Map<String, dynamic>>[];
      if (game == 'number_walls') {
        for (int r = 0; r < (p['wallHeight'] as int) - 1; r++) {
          for (int c = 0; c <= r; c++) {
            final parent = r * (r + 1) ~/ 2 + c,
                left = (r + 1) * (r + 2) ~/ 2 + c;
            equations.add({
              'cells': ['$parent', '$left', '${left + 1}'],
              'op': p['operation']
            });
          }
        }
      } else {
        for (final cells in [
          ['1', '3', '4'],
          ['2', '4', '5'],
          ['0', '1', '2']
        ]) {
          equations.add({
            'cells': cells,
            'op': cells.first == '0' ? 'addition' : 'multiplication',
          });
        }
      }
      return solve({
        'values': values,
        'domains': {for (final c in empty) c: p['numberPool']},
        'pool': p['numberPool'],
        'equations': equations
      }, empty, 'Use the displayed operation on connected cells.',
          'Nutze die angezeigte Rechenart auf verbundenen Feldern.');
    case 'orbital_towers':
    case 'nebula_matrix':
    case 'kenken':
      final n = p['size'] as int;
      final empty = _list(p['emptyCells']).cast<String>();
      final groups = [
        for (int r = 0; r < n; r++) List.generate(n, (c) => 'r${r}c$c'),
        for (int c = 0; c < n; c++) List.generate(n, (r) => 'r${r}c$c')
      ];
      if (game == 'nebula_matrix') {
        groups.addAll(_list(p['zones']).map((z) => _list(z).cast<String>()));
      }
      final sightlines = <Map<String, dynamic>>[];
      for (final e in _map(p['edgeClues']).entries) {
        final parts = e.key.split('_'), index = int.parse(parts[1]);
        sightlines.add({
          'cells': List.generate(
              n,
              (i) => switch (parts[0]) {
                    'top' => 'r${i}c$index',
                    'bottom' => 'r${n - 1 - i}c$index',
                    'left' => 'r${index}c$i',
                    _ => 'r${index}c${n - 1 - i}'
                  }),
          'target': e.value
        });
      }
      return solve(
          {
            'values': {..._map(p['clues']), ..._map(state['answers'])},
            'domains': {
              for (final c in empty) c: List.generate(n, (i) => i + 1)
            },
            'groups': groups,
            'sightlines': sightlines,
            'cages': game == 'kenken' ? p['cages'] : []
          },
          empty,
          game == 'kenken'
              ? 'Check row, column and cage arithmetic.'
              : 'Check row, column and visible clues.',
          game == 'kenken'
              ? 'Prüfe Zeile, Spalte und Käfigrechnung.'
              : 'Prüfe Zeile, Spalte und sichtbare Hinweise.');
    case 'dark_matter_grid':
      final taps = solveLights(
          _list(state['grid']).map((r) => _list(r).cast<bool>()).toList());
      if (taps == null || taps.isEmpty) {
        return observe(
            'Check the lights.',
            'Prüfe die Lichter.',
            'The board is clear or no solution was found.',
            'Das Feld ist leer oder es wurde keine Lösung gefunden.');
      }
      final n = _list(state['grid']).length,
          i = taps.first,
          r = i ~/ n,
          c = i % n;
      return observe(
          'Focus on row ${r + 1}, column ${c + 1}.',
          'Betrachte Zeile ${r + 1}, Spalte ${c + 1}.',
          'Tapping here is part of a solution for the current lights.',
          'Dieses Antippen gehört zu einer Lösung der aktuellen Lichter.',
          target: 'r${r}c$c',
          value: true,
          verified: true);
    case 'launch_sequence':
      final seq = _list(state['sequence']), target = _list(p['target']);
      for (int i = 0; i < seq.length - 1; i++) {
        if (target.indexOf(seq[i]) > target.indexOf(seq[i + 1])) {
          return observe(
              'Compare slots ${i + 1} and ${i + 2}.',
              'Vergleiche Plätze ${i + 1} und ${i + 2}.',
              '${seq[i]} precedes ${seq[i + 1]}, but the target order is reversed. Swap these neighbours.',
              '${seq[i]} steht vor ${seq[i + 1]}, aber das Ziel verlangt die umgekehrte Reihenfolge. Tausche diese Nachbarn.',
              target: '$i',
              value: i + 1,
              verified: true);
        }
      }
      return observe('The sequence is ordered.', 'Die Folge ist geordnet.',
          'Compare it with the target.', 'Vergleiche sie mit dem Ziel.');
    case 'sector_painter':
      return _colorHint(p, state, german);
    case 'ion_chain':
      return _ionHint(p, state, german);
    case 'asteroid_math':
    case 'bubble_math':
    case 'planet_hopping':
    case 'hyperdrive_gates':
    case 'pathfinder':
      var problem = _map(state['currentProblem']);
      final sequence = _list(state['targetOrder'] ?? state['targetSequence']);
      final index =
          (state['currentTargetIndex'] ?? state['nextTargetIndex'] ?? 0) as int;
      final next = index < sequence.length ? sequence[index] : null;
      if (problem.isEmpty) {
        final problems = [
          ..._list(state['levelProblems'] ?? state['_levelProblems']),
          ..._list(state['planets']).map((v) => _map(v)['problem']),
        ].map(_map);
        for (final candidate in problems) {
          if (candidate['answer'] == next) {
            problem = candidate;
            break;
          }
        }
      }
      final answer = problem['answer'] ?? next;
      return observe(
          'Focus on the current target.',
          'Betrachte das aktuelle Ziel.',
          problem.isEmpty
              ? 'Your next target is $answer. Choose the object with this value.'
              : '${problem['expression']} = $answer. Choose the matching target or route.',
          problem.isEmpty
              ? 'Dein nächstes Ziel ist $answer. Wähle das Objekt mit diesem Wert.'
              : '${problem['expression']} = $answer. Wähle das passende Ziel oder die passende Route.',
          target: 'currentTarget',
          value: answer,
          verified: answer != null);
    case 'chrono_repair':
      final displayed =
          '${state['_displayedHour']}:${(state['_displayedMinute'] as int).toString().padLeft(2, '0')}';
      return observe(
          'Check the clock showing $displayed.',
          'Prüfe die Uhr mit $displayed.',
          'The malfunction is ${state['_malfunctionHint']}. Correct the minutes before carrying into hours.',
          'Die Fehlfunktion lautet ${state['_malfunctionHint']}. Korrigiere zuerst die Minuten und dann den Stundenübertrag.');
    case 'galactic_market':
      final visible =
          _list(state['_knownCoins']).fold<num>(0, (s, v) => s + (v as num));
      final remaining = (state['_changeTotal'] as num) - visible,
          count = state['_unknownCount'] as int;
      return observe(
          'Separate the $count hidden coins.',
          'Betrachte die $count verdeckten Münzen.',
          '${state['_changeTotal']} − $visible = $remaining; $remaining ÷ $count = ${remaining / count}.',
          '${state['_changeTotal']} − $visible = $remaining; $remaining ÷ $count = ${remaining / count}.',
          target: 'denomination',
          value: remaining / count,
          verified: count > 0);
    case 'xenobiology_lab':
      return observe(
          'Compare eyes and legs.',
          'Vergleiche Augen und Beine.',
          '${state['_nameA']}: ${state['_eyesA']} eyes/${state['_legsA']} legs; '
              '${state['_nameB']}: ${state['_eyesB']} eyes/${state['_legsB']} legs. '
              'The totals are ${state['_totalEyes']} eyes and ${state['_totalLegs']} legs. Test your current counts in both equations.',
          '${state['_nameA']}: ${state['_eyesA']} Augen/${state['_legsA']} Beine; '
              '${state['_nameB']}: ${state['_eyesB']} Augen/${state['_legsB']} Beine. '
              'Die Summen sind ${state['_totalEyes']} Augen und ${state['_totalLegs']} Beine. Prüfe deine Anzahlen in beiden Gleichungen.');
    case 'asteroid_duel':
      final remaining = state['_remaining'] as int,
          max = state['_maxPerTurn'] as int;
      int? take;
      for (int i = 1; i <= math.min(max, remaining - 1); i++) {
        if ((remaining - i - 1) % (max + 1) == 0) {
          take = i;
          break;
        }
      }
      return observe(
          'There are $remaining asteroids; the limit is $max.',
          'Es gibt $remaining Asteroiden; das Limit ist $max.',
          take == null
              ? 'Taking the last asteroid loses. No forcing move is available; keep watching the opponent.'
              : 'Take $take and leave ${remaining - take}. This leaves 1 modulo ${max + 1}; taking the last asteroid loses.',
          take == null
              ? 'Wer den letzten Asteroiden nimmt, verliert. Es gibt keinen erzwingenden Zug; beobachte den Gegner.'
              : 'Nimm $take und lasse ${remaining - take} übrig. Das ist 1 modulo ${max + 1}; wer den letzten nimmt, verliert.',
          target: take == null ? null : 'take',
          value: take,
          verified: take != null);
    case 'comm_relay':
      final cipher = p['cipherText'] as String;
      final shift = state['_currentShift'];
      return observe(
          'Decode the start of "$cipher".',
          'Entschlüssle den Anfang von "$cipher".',
          'Your shift is $shift. Use the revealed letters ${_pairs(p['hintLetters'])} to check that shift before decoding the whole message.',
          'Deine Verschiebung ist $shift. Prüfe sie an den enthüllten Buchstaben ${_pairs(p['hintLetters'])}, bevor du die ganze Nachricht entschlüsselst.');
    case 'vault_cracker':
      final clues = _list(p['clues']);
      final clue = clues.isEmpty ? '' : _map(clues.first)[german ? 'de' : 'en'];
      return observe(
          'Use a visible clue with your current code.',
          'Nutze einen sichtbaren Hinweis für deinen aktuellen Code.',
          'Clue: $clue. Your current code is ${state['answer']}; check this condition first.',
          'Hinweis: $clue. Dein aktueller Code ist ${state['answer']}; prüfe zuerst diese Bedingung.');
    case 'signal_triangulation':
      final history = _list(state['history']);
      if (history.isEmpty) {
        return observe(
            'Try a structured first guess.',
            'Probiere einen geordneten ersten Versuch.',
            'Use the available glyphs ${state['glyphs']} to compare positions in a ${state['length']}-glyph code.',
            'Nutze die verfügbaren Glyphen ${state['glyphs']}, um Plätze in einem Code mit ${state['length']} Glyphen zu vergleichen.');
      }
      final last = _map(history.last);
      return observe(
          'Compare the last guess with its feedback.',
          'Vergleiche den letzten Versuch mit seiner Rückmeldung.',
          '${last['guess']}: ${last['correct']} exact positions, ${last['present']} correct glyphs in other positions. Preserve the known information in your next guess.',
          '${last['guess']}: ${last['correct']} exakte Plätze, ${last['present']} richtige Glyphen auf anderen Plätzen. Erhalte diese Information im nächsten Versuch.');
    case 'codebreaker':
      final equations = _list(p['equations']),
          known = _map(p['knownSymbolValues']);
      final eq =
          equations.isEmpty ? <String, dynamic>{} : _map(equations.first);
      return observe(
          'Use a current equation.',
          'Nutze eine aktuelle Gleichung.',
          '${eq['term1']} ${eq['op']} ${eq['term2']} = ${eq['result']}. Known symbols: $known. Substitute these before solving an unknown.',
          '${eq['term1']} ${eq['op']} ${eq['term2']} = ${eq['result']}. Bekannte Symbole: $known. Setze sie ein, bevor du eine Unbekannte berechnest.');
    case 'arithmatic_square':
    case 'arithmancer_crosswords':
      final values = {
        ..._pairs(p['playerHints'] ?? p['clues']),
        ..._pairs(state['userSolution'])
      };
      final missing = _list(p['emptyCells'])
          .map((v) => '$v')
          .where((c) => !values.containsKey(c))
          .toList();
      final target = missing.isEmpty ? null : missing.first;
      String known(bool de) => values.entries
          .take(4)
          .map((e) => '${_cell(e.key, de)}: ${e.value}')
          .join('; ');
      return observe(
          'Focus on ${target == null ? 'the filled board' : _cell(target, false)}.',
          'Betrachte ${target == null ? 'das ausgefüllte Feld' : _cell(target, true)}.',
          'Known entries: ${known(false)}. Read the operators in the crossing row and column; use both to narrow the remaining pool ${state['numberPool']}.',
          'Bekannte Einträge: ${known(true)}. Lies die Rechenzeichen in der kreuzenden Zeile und Spalte; nutze beide für den restlichen Vorrat ${state['numberPool']}.',
          target: target);
    case 'magic_triangles':
      final visible = _pairs(p['visibleValues']);
      final numbers = _list(p['allNumbers']);
      final side = p['circlesPerSide'] as int;
      final sum = numbers.fold<num>(0, (s, v) => s + (v as num));
      // The target is generated as warpFrequency; do not substitute total sum.
      return observe(
          'Each side must match ${p['warpFrequency']}.',
          'Jede Seite muss ${p['warpFrequency']} ergeben.',
          'The visible nodes are $visible, with $side nodes per side. Subtract the known nodes on one side; the $sum total includes corners only once.',
          'Die sichtbaren Knoten sind $visible, mit $side Knoten pro Seite. Ziehe die bekannten Knoten einer Seite ab; die Gesamtsumme $sum zählt Ecken nur einmal.');
    case 'cryptex_lock_breaker':
      final eq = _map(_list(p['equations']).first);
      final dials = _list(state['dialValues']);
      final left = _list(eq['leftOperandIndices'])
          .map((i) => 'D${(i as int) + 1}')
          .join(' ${eq['operator']} ');
      final right = eq['resultDialIndex'] == null
          ? '${eq['rightSide']}'
          : 'D${(eq['resultDialIndex'] as int) + 1}';
      return observe(
          'Check $left = $right.',
          'Prüfe $left = $right.',
          'Your dial values are ${dials.join(', ')}. Substitute them in this equation and change only the dial you can deduce.',
          'Deine Scheibenwerte sind ${dials.join(', ')}. Setze sie in diese Gleichung ein und ändere nur die Scheibe, die du daraus ableiten kannst.');
    case 'gravity_well':
      final scales = _list(p['scales']);
      final scale = scales.isEmpty ? <String, dynamic>{} : _map(scales.first);
      String side(Object? raw) => _list(raw).map((v) {
            final o = _map(v);
            return o['isKnown'] == true ? '${o['weight']}' : '${o['label']}';
          }).join(' + ');
      final equation =
          '${side(scale['leftSide'])} = ${side(scale['rightSide'])}';
      return observe(
          'Use this visible scale: $equation.',
          'Nutze diese sichtbare Waage: $equation.',
          'Cancel matching objects on both sides, then divide any repeated unknowns. Your current entries are ${_pairs(state['_userAnswers'])}.',
          'Streiche gleiche Objekte auf beiden Seiten und teile dann wiederholte Unbekannte. Deine Einträge sind ${_pairs(state['_userAnswers'])}.');
    case 'cube_scanner':
      final question = _map(p['question']);
      String faces(bool de) =>
          _list(p['visibleFaces']).asMap().entries.map((die) {
            final shown = _map(die.value)
                .entries
                .where((e) => e.value != null)
                .map((e) => '${_faceLabel(e.key, de)}: ${e.value}')
                .join(', ');
            return '${de ? 'Würfel' : 'Cube'} ${die.key + 1}: $shown';
          }).join('; ');
      final face = question['face'] as String?;
      return observe(
          face == null
              ? 'Work out the hidden total.'
              : 'Find the ${_faceLabel(face, false)} face.',
          face == null
              ? 'Ermittle die verdeckte Summe.'
              : 'Suche die Seite ${_faceLabel(face, true)}.',
          '${faces(false)}. Follow the displayed rolls one at a time; opposite faces of a die sum to 7.',
          '${faces(true)}. Verfolge die angezeigten Drehungen einzeln; gegenüberliegende Würfelflächen ergeben zusammen 7.');
    case 'block_counter':
      final blocks =
          _list(_map(p['blockStructure'])['blocks']).map(_map).toList();
      final bottom = blocks.map((b) => b['y'] as int).reduce(math.min);
      final layer = blocks.where((b) => b['y'] == bottom).length;
      return observe(
          'Count the lowest layer first.',
          'Zähle zuerst die unterste Schicht.',
          'The lowest layer contains $layer blocks. Count each higher layer separately and add their totals; include hidden blocks supported by the structure.',
          'Die unterste Schicht enthält $layer Blöcke. Zähle jede höhere Schicht einzeln und addiere ihre Summen; berücksichtige die durch die Struktur erkennbaren verdeckten Blöcke.');
    case 'perspective_puzzle':
      final views = _list(state['_perspectivesToSolve']),
          turn = state['_currentTurnIndex'] as int;
      final view = turn < views.length ? views[turn] : '?';
      return observe(
          'Look from $view.',
          'Blicke von $view.',
          'There are ${_list(p['structure']).length} cubes. Project them onto this view and keep only the nearest cube at each position; hidden cubes do not add visible squares.',
          'Es gibt ${_list(p['structure']).length} Würfel. Projiziere sie auf diese Ansicht und behalte pro Platz nur den nächsten Würfel; verdeckte Würfel ergeben keine zusätzlichen sichtbaren Quadrate.');
    case 'warp_fold':
      final folds = _list(p['folds']).map(_map).toList();
      String directions(bool de) => folds.reversed
          .map((fold) => _faceLabel(fold['direction'] as String, de))
          .join(', ');
      final cuts = _list(p['cuts']).length;
      return observe(
          'Undo the current folds in reverse order.',
          'Öffne die aktuellen Faltungen in umgekehrter Reihenfolge.',
          'There are $cuts cuts. Unfold in this order: ${directions(false)}. Mirror each visible cut across the fold line before continuing.',
          'Es gibt $cuts Schnitte. Öffne die Faltungen in dieser Reihenfolge: ${directions(true)}. Spiegle jeden sichtbaren Schnitt an der Faltlinie, bevor du fortfährst.');
    case 'circuit_repair':
      final digits = _list(state['_currentDigits']);
      return observe(
          'Check the digits ${digits.join()}.',
          'Prüfe die Ziffern ${digits.join()}.',
          'A clock needs hours 00–23 and minutes 00–59. Find the positions that make the current display invalid, then try a single swap.',
          'Eine Uhr braucht Stunden von 00–23 und Minuten von 00–59. Suche die Stellen, die die aktuelle Anzeige ungültig machen, und probiere einen einzigen Tausch.');
    case 'crew_manifest':
      final clues = _list(p['structuredClues']);
      final positive =
          clues.map(_map).where((c) => c['type'] == 'positive').toList();
      final clue = positive.isEmpty
          ? (clues.isEmpty ? <String, dynamic>{} : _map(clues.first))
          : positive.first;
      return observe(
          'Use the clue for ${clue['crewName']}.',
          'Nutze den Hinweis für ${clue['crewName']}.',
          '${clue['crewName']} ${clue['type'] == 'positive' ? 'has' : 'does not have'} ${clue['itemName']}. Compare this with your current marks ${_pairs(state['_gridState'])}; each crew member has exactly one item.',
          '${clue['crewName']} ${clue['type'] == 'positive' ? 'hat' : 'hat nicht'} ${clue['itemName']}. Vergleiche dies mit deinen Markierungen ${_pairs(state['_gridState'])}; jedes Crewmitglied hat genau einen Gegenstand.');
    case 'alien_tribunal':
      final people = _list(p['people']);
      final counts =
          people.map(_map).where((p) => p['kind'] == 'count').toList();
      final person = counts.isEmpty ? _map(people.first) : counts.first;
      return observe(
          'Test the claim from ${person['name']}.',
          'Prüfe die Behauptung von ${person['name']}.',
          person['kind'] == 'count'
              ? 'It claims exactly ${person['countValue']} ${person['countsTruthTellers'] == true ? 'truth-tellers' : 'liars'}. Compare that total with your assignments ${_pairs(state['_userAssignment'])}; the speaker’s role must match the statement’s truth.'
              : 'The claim concerns delegate ${person['targetIndex']}. Test both possible roles and check whether the speaker’s role matches the statement’s truth.',
          person['kind'] == 'count'
              ? 'Sie behauptet genau ${person['countValue']} ${person['countsTruthTellers'] == true ? 'Wahrheitsredner' : 'Lügner'}. Vergleiche die Anzahl mit deiner Zuordnung ${_pairs(state['_userAssignment'])}; die Rolle des Sprechers muss zum Wahrheitswert passen.'
              : 'Die Behauptung betrifft Delegierten ${person['targetIndex']}. Prüfe beide Rollen; die Rolle des Sprechers muss zum Wahrheitswert passen.');
    case 'star_chart_scan':
      final found = _list(state['_foundEquations']);
      final equations = _list(p['placedEquations'])
          .map(_map)
          .where((e) => !found.contains(e['equation']))
          .toList();
      final eq = equations.isEmpty ? <String, dynamic>{} : equations.first;
      return observe(
          'Find the start of ${eq['equation']}.',
          'Suche den Anfang von ${eq['equation']}.',
          'Start at row ${(eq['startRow'] as int? ?? 0) + 1}, column ${(eq['startCol'] as int? ?? 0) + 1}; scan in direction ${_map(eq['direction'])['name']}.',
          'Beginne in Zeile ${(eq['startRow'] as int? ?? 0) + 1}, Spalte ${(eq['startCol'] as int? ?? 0) + 1}; suche in Richtung ${_map(eq['direction'])['name']}.');
    case 'asteroid_field_navigator':
      return _mineHint(state, german);
    case 'hive_station':
      final revealed = _list(p['revealedHints']).map((v) {
        final c = _map(v);
        return '${c['q']},${c['r']}';
      }).toSet();
      final hints = _list(p['numberHints']).where((v) {
        final c = _map(_list(v).first);
        return revealed.contains('${c['q']},${c['r']}');
      }).toList();
      final hint = hints.isEmpty ? <dynamic>[] : _list(hints.first);
      return observe(
          'Use a revealed hexagonal clue.',
          'Nutze einen enthüllten Sechseckhinweis.',
          'Clue ${hint.isEmpty ? '' : hint.first}: ${hint.length < 2 ? '' : hint[1]}. Count the six neighbouring cells and compare with your marks ${state['userMarked']}.',
          'Hinweis ${hint.isEmpty ? '' : hint.first}: ${hint.length < 2 ? '' : hint[1]}. Zähle die sechs Nachbarfelder und vergleiche mit deinen Markierungen ${state['userMarked']}.');
    case 'relic_assembly':
      final placement = _list(state['placement']),
          index = placement.indexOf(-1);
      final cols = p['cols'] as int;
      return observe(
          'Focus on slot ${index + 1}.',
          'Betrachte Platz ${index + 1}.',
          'The board has ${p['rows']} × $cols slots. Match the top/left edges of this empty slot to its placed neighbours; rotate an unused tile before placing it.',
          'Das Feld hat ${p['rows']} × $cols Plätze. Gleiche die obere/linke Kante dieses leeren Platzes mit seinen platzierten Nachbarn ab; drehe einen unbenutzten Stein vor dem Einsetzen.',
          target: '$index');
    case 'hull_plating':
      final used = _list(state['_usedPieceIds']);
      final pieces = _list(p['pieces'])
          .map(_map)
          .where((piece) => !used.contains(piece['id']))
          .toList();
      final piece = pieces.isEmpty ? <String, dynamic>{} : pieces.first;
      return observe(
          'Consider unused piece ${piece['id']}.',
          'Betrachte das unbenutzte Teil ${piece['id']}.',
          'Its shape covers ${_list(piece['cells']).length} cells. Compare it with the remaining board holes; every cell must fit without overlap.',
          'Seine Form bedeckt ${_list(piece['cells']).length} Felder. Vergleiche sie mit den übrigen Lücken; jedes Feld muss ohne Überlappung passen.');
    case 'grid_filler_game':
      final pieces = _list(state['availablePieces']).map(_map);
      final remaining =
          pieces.where((p) => (p['remainingCount'] as int? ?? 1) > 0).toList();
      return observe(
          'Inspect the uncovered grid cells.',
          'Betrachte die unbedeckten Rasterfelder.',
          '${_list(state['placedPieces']).length} pieces are placed; ${remaining.length} piece types remain. Start with a corner and check every square of the chosen shape.',
          '${_list(state['placedPieces']).length} Teile sind platziert; ${remaining.length} Teiletypen bleiben. Beginne mit einer Ecke und prüfe jedes Quadrat der gewählten Form.');
    case 'puzzle_math':
      final placed =
          _list(state['placedPieces']).map((v) => _list(v).first).toSet();
      final pieces = _list(state['pieces'])
          .map(_map)
          .where((v) => !placed.contains(v['id']))
          .toList();
      final piece = pieces.isEmpty ? <String, dynamic>{} : pieces.first;
      final problem = _map(piece['problem'] ?? piece['mathProblem']);
      return observe(
          'Solve a remaining piece.',
          'Berechne ein übriges Teil.',
          '${problem['expression']} = ${problem['answer']}. Compare that result and the edge shape with the empty slot.',
          '${problem['expression']} = ${problem['answer']}. Vergleiche das Ergebnis und die Kantenform mit dem leeren Platz.',
          target: '${piece['id']}',
          value: problem['answer']);
    case 'robot_path_game':
      final level = _map(state['currentLevel']);
      return observe(
          'Plan from (${level['startRow']}, ${level['startCol']}).',
          'Plane von (${level['startRow']}, ${level['startCol']}).',
          'The goal is (${level['goalRow']}, ${level['goalCol']}); start direction ${level['startDirection']}. Trace your ${_list(state['commandSequence']).length} commands on the current grid before running them.',
          'Das Ziel ist (${level['goalRow']}, ${level['goalCol']}); Startrichtung ${level['startDirection']}. Verfolge deine ${_list(state['commandSequence']).length} Befehle im aktuellen Raster, bevor du sie ausführst.');
    case 'star_loader_game':
      return observe(
          'Plan the next push from ${state['_playerPos']}.',
          'Plane den nächsten Schub von ${state['_playerPos']}.',
          'Boxes: ${state['_boxPositions']}; targets: ${state['_targetPositions']}. Reach the opposite side of a box before pushing; avoid corners without a target.',
          'Kisten: ${state['_boxPositions']}; Ziele: ${state['_targetPositions']}. Erreiche vor dem Schieben die gegenüberliegende Seite einer Kiste; meide Ecken ohne Ziel.');
    case 'space_station_gridlock':
      final ships = _list(state['ships']),
          player = state['playerShipIndex'] as int;
      final ship =
          player < ships.length ? _map(ships[player]) : <String, dynamic>{};
      return observe(
          'Clear the exit in row ${(state['exitRow'] as int) + 1}.',
          'Mache den Ausgang in Zeile ${(state['exitRow'] as int) + 1} frei.',
          'Your ship is at ${ship['x'] ?? ship['col']}, ${ship['y'] ?? ship['row']}. Move blockers perpendicular to its route; ships cannot rotate.',
          'Dein Schiff steht bei ${ship['x'] ?? ship['col']}, ${ship['y'] ?? ship['row']}. Bewege Hindernisse quer zu seiner Route; Schiffe können sich nicht drehen.');
    case 'void_crossing':
      final current = _map(state['_gameState']);
      final labels = {
        for (final entity in _list(p['entities']).map(_map))
          entity['id']: entity['emoji']
      };
      String entities(Object? raw, bool de) {
        final items = _list(raw)
            .map((id) => '${labels[id] ?? (de ? 'Gegenstand' : 'entity')}')
            .toList();
        return items.isEmpty ? (de ? 'leer' : 'empty') : items.join(' ');
      }
      String conflicts(bool de) => _list(p['conflicts']).map(_map).map((rule) {
            final pair = entities([rule['entityA'], rule['entityB']], de);
            final guardian = rule['guardian'];
            if (guardian == null) return pair;
            return '$pair ${de ? 'brauchen' : 'need'} ${entities([
                  guardian
                ], de)}';
          }).join('; ');
      return observe(
          'Check the bank the shuttle is leaving.',
          'Prüfe die Station, die das Shuttle verlässt.',
          'Left: ${entities(current['leftStation'], false)}; right: ${entities(current['rightStation'], false)}; aboard: ${entities(current['onShuttle'], false)}. Capacity: ${p['boatCapacity']}. Check these pairs before crossing: ${conflicts(false)}.',
          'Links: ${entities(current['leftStation'], true)}; rechts: ${entities(current['rightStation'], true)}; an Bord: ${entities(current['onShuttle'], true)}. Kapazität: ${p['boatCapacity']}. Prüfe vor der Überfahrt diese Paare: ${conflicts(true)}.');
    case 'cargo_bay_arranger':
      final grid = _list(state['grid']);
      final row = grid.isEmpty ? <dynamic>[] : _list(grid.last);
      final total = row.where((v) => v != null).map(_map).fold<num>(
          0, (s, v) => s + (v['value'] as num? ?? v['number'] as num? ?? 0));
      final needed = (state['targetSum'] as num) - total;
      final pieceValues = _list(_map(state['currentPiece'])['cubes'])
          .expand(_list)
          .where((v) => v != null)
          .map((v) => _map(v)['value'])
          .join(', ');
      return observe(
          'Check the bottom row total.',
          'Prüfe die Summe der untersten Zeile.',
          'Filled cells total $total; the target is ${state['targetSum']}, so the row still needs $needed. Compare this with the current piece $pieceValues.',
          'Belegte Felder ergeben $total; das Ziel ist ${state['targetSum']}, also fehlen $needed. Vergleiche dies mit dem aktuellen Teil $pieceValues.');
    case 'quantum_molecule_builder':
      final pattern = _map(state['targetPattern']);
      return observe(
          'Compare atoms with the current target.',
          'Vergleiche die Atome mit dem aktuellen Ziel.',
          'Target: ${pattern['name'] ?? state['levelName']}; atoms: ${_list(state['atoms']).map(_map).map((a) => a['type']).join(', ')}. Keep the molecule’s relative arrangement; atoms slide until blocked.',
          'Ziel: ${pattern['name'] ?? state['levelName']}; Atome: ${_list(state['atoms']).map(_map).map((a) => a['type']).join(', ')}. Erhalte die relative Anordnung des Moleküls; Atome gleiten bis zu einem Hindernis.');
    case 'arithmancer_duel':
      final engine = _map(state['engine'] ??
          _map(_map(state['pvp'])['player1State'])['engine']);
      final cards = _list(state['hand']).map(_map).toList();
      return observe(
          'Build from your current hand.',
          'Baue mit deiner aktuellen Hand.',
          'Energy: ${engine['playerEnergy']}; cards: ${cards.map((c) => '${c['name']} (${c['cost']})').join(', ')}. Choose affordable number–operator–number cards before matching the enemy’s shields ${_map(engine['currentEnemy'])['mathematicalShields']}.',
          'Energie: ${engine['playerEnergy']}; Karten: ${cards.map((c) => '${c['name']} (${c['cost']})').join(', ')}. Wähle bezahlbare Zahl–Rechenzeichen–Zahl-Karten und prüfe die Schilde des Gegners ${_map(engine['currentEnemy'])['mathematicalShields']}.');
    case 'creature_forge':
      return observe(
          'Group creatures by head.',
          'Gruppiere Wesen nach ihrem Kopf.',
          '${state['_headCount']} heads × ${state['_bodyCount']} bodies × ${state['_tailCount']} tails, with ${state['_forbiddenCombos']} forbidden combinations. Subtract forbidden combinations once.',
          '${state['_headCount']} Köpfe × ${state['_bodyCount']} Körper × ${state['_tailCount']} Schwänze, mit ${state['_forbiddenCombos']} verbotenen Kombinationen. Ziehe verbotene Kombinationen genau einmal ab.');
    default:
      return null;
  }
}

/// Gaussian elimination over GF(2), for the current cross-toggle board.
/// Returns a valid tap set, not a claim of minimum moves.
List<int>? solveLights(List<List<bool>> grid, {bool targetLit = true}) {
  final n = grid.length, count = n * n;
  if (n == 0 || n > 8 || grid.any((r) => r.length != n)) return null;
  final rows = List.generate(
      count,
      (i) => List.generate(count + 1, (j) {
            if (j == count) return grid[i ~/ n][i % n] == targetLit ? 0 : 1;
            return (i ~/ n - j ~/ n).abs() + (i % n - j % n).abs() <= 1 ? 1 : 0;
          }));
  var rank = 0;
  final pivots = <int>[];
  for (int c = 0; c < count; c++) {
    int pivot = rank;
    while (pivot < count && rows[pivot][c] == 0) {
      pivot++;
    }
    if (pivot == count) continue;
    final temp = rows[rank];
    rows[rank] = rows[pivot];
    rows[pivot] = temp;
    for (int r = 0; r < count; r++) {
      if (r != rank && rows[r][c] == 1) {
        for (int j = c; j <= count; j++) {
          rows[r][j] ^= rows[rank][j];
        }
      }
    }
    pivots.add(c);
    rank++;
  }
  for (int r = rank; r < count; r++) {
    if (rows[r][count] == 1) return null;
  }
  return [
    for (int r = 0; r < rank; r++)
      if (rows[r][count] == 1) pivots[r]
  ];
}

String _colourLabel(Object? colour, bool de) {
  final name = colour is int
      ? ['red', 'green', 'purple', 'yellow', 'pink'][colour % 5]
      : colour;
  return switch (name) {
    'red' => de ? 'rot' : 'red',
    'green' => de ? 'grün' : 'green',
    'blue' => de ? 'blau' : 'blue',
    'yellow' => de ? 'gelb' : 'yellow',
    'purple' => de ? 'lila' : 'purple',
    'pink' => de ? 'rosa' : 'pink',
    _ => de ? 'noch leer' : 'empty',
  };
}

BoardHint _colorHint(Map<String, dynamic> p, Map<String, dynamic> s, bool de) {
  final adjacency = _pairs(p['adjacency']);
  final colors = _pairs(s['_coloring']);
  final regions = _list(p['regions']).map((v) => '$v').toList();
  for (final r in regions) {
    for (final neighbour in _list(adjacency[r])) {
      if (colors[r] != null && colors[r] == colors['$neighbour']) {
        return BoardHint(
            de
                ? 'Prüfe benachbarte Regionen $r und $neighbour.'
                : 'Check neighbouring regions $r and $neighbour.',
            de
                ? 'Nachbarn brauchen unterschiedliche Farben.'
                : 'Neighbours need different colours.',
            de
                ? 'Beide haben Farbe ${_colourLabel(colors[r], true)}; ändere eine davon.'
                : 'Both have colour ${_colourLabel(colors[r], false)}; change one.');
      }
    }
  }
  final target = regions.where((r) => !colors.containsKey(r)).firstOrNull;
  if (target == null) {
    return BoardHint(
        de ? 'Alle Regionen sind bemalt.' : 'All regions are painted.',
        de ? 'Prüfe die Farbanzahl.' : 'Check the colour count.',
        de
            ? 'Ziel: ${p['chromaticNumber']} Farben.'
            : 'Target: ${p['chromaticNumber']} colours.');
  }
  final used = _list(adjacency[target])
      .map((r) => colors['$r'])
      .where((v) => v != null)
      .toSet();
  final choices = [
    for (int i = 0; i < (p['availableColors'] as int); i++)
      if (!used.contains(i)) i
  ];
  return BoardHint(
      de ? 'Betrachte Region $target.' : 'Focus on region $target.',
      de
          ? 'Schließe die Farben ihrer Nachbarn aus.'
          : 'Exclude the colours of its neighbours.',
      de
          ? 'Nachbarfarben: ${used.isEmpty ? 'keine' : used.map((v) => _colourLabel(v, true)).join(', ')}; lokal mögliche Farben: ${choices.map((v) => _colourLabel(v, true)).join(', ')}. Prüfe danach die übrigen Regionen.'
          : 'Neighbour colours: ${used.isEmpty ? 'none' : used.map((v) => _colourLabel(v, false)).join(', ')}; locally possible colours: ${choices.map((v) => _colourLabel(v, false)).join(', ')}. Then check the remaining regions.',
      target: target);
}

BoardHint _ionHint(Map<String, dynamic> p, Map<String, dynamic> s, bool de) {
  final chain = _list(s['_playerChain']),
      rules = _list(p['rules']).map(_map).toList();
  final index = chain.indexOf(null);
  if (index < 0) {
    return BoardHint(
        de ? 'Die Kette ist gefüllt.' : 'The chain is filled.',
        de ? 'Prüfe alle Regeln.' : 'Check every rule.',
        de
            ? 'Vergleiche jedes Nachbarpaar.'
            : 'Compare every neighbouring pair.');
  }
  bool allowed(Object? a, Object? b) {
    if (a == null || b == null) return true;
    for (final r in rules) {
      if (r['kind'] == 'noRepeatAtAll' && a == b) return false;
      if (r['kind'] == 'noSelfPair' && a == r['a'] && b == r['a']) return false;
      if (r['kind'] == 'noMixedPair' &&
          ((a == r['a'] && b == r['b']) || (b == r['a'] && a == r['b']))) {
        return false;
      }
    }
    return true;
  }

  final left = index == 0 ? null : chain[index - 1],
      right = index + 1 == chain.length ? null : chain[index + 1];
  final choices = _list(p['ionTypes'])
      .where((v) => allowed(left, v) && allowed(v, right))
      .toList();
  return BoardHint(
      de ? 'Betrachte Perle ${index + 1}.' : 'Focus on bead ${index + 1}.',
      de ? 'Prüfe beide Nachbarn.' : 'Check both neighbours.',
      de
          ? 'Links: ${_colourLabel(left, true)}; rechts: ${_colourLabel(right, true)}. Lokal mögliche Farben: ${choices.map((v) => _colourLabel(v, true)).join(', ')}. Prüfe danach die ganze Kette.'
          : 'Left: ${_colourLabel(left, false)}; right: ${_colourLabel(right, false)}. Locally possible colours: ${choices.map((v) => _colourLabel(v, false)).join(', ')}. Then check the whole chain.',
      target: '$index');
}

BoardHint _mineHint(Map<String, dynamic> s, bool de) {
  final grid = _list(s['grid']).map(_list).toList(), rows = grid.length;
  for (int r = 0; r < rows; r++) {
    for (int c = 0; c < grid[r].length; c++) {
      final cell = _map(grid[r][c]);
      if (cell['isRevealed'] != true || cell['isMine'] == true) continue;
      final hidden = <String>[];
      var flags = 0;
      for (int dr = -1; dr <= 1; dr++) {
        for (int dc = -1; dc <= 1; dc++) {
          if (dr == 0 && dc == 0) continue;
          final y = r + dr, x = c + dc;
          if (y < 0 || y >= rows || x < 0 || x >= grid[y].length) continue;
          final n = _map(grid[y][x]);
          if (n['isFlagged'] == true) {
            flags++;
          } else if (n['isRevealed'] != true) {
            hidden.add('r${y}c$x');
          }
        }
      }
      if (hidden.isEmpty) continue;
      final clue = cell['adjacentMines'] as int;
      final safe = flags == clue, mines = clue - flags == hidden.length;
      return BoardHint(
          de
              ? 'Betrachte Zeile ${r + 1}, Spalte ${c + 1}.'
              : 'Focus on row ${r + 1}, column ${c + 1}.',
          de
              ? 'Vergleiche Zahl, Flaggen und verdeckte Nachbarn.'
              : 'Compare the clue, flags and hidden neighbours.',
          de
              ? 'Hinweis $clue, Flaggen $flags, verdeckt ${hidden.length}. ${safe ? 'Bei korrekten Flaggen sind die übrigen Nachbarn sicher.' : mines ? 'Bei korrekten Flaggen enthalten alle übrigen Nachbarn Minen.' : 'Hier fehlt noch eine weitere Information.'}'
              : 'Clue $clue, flags $flags, hidden ${hidden.length}. ${safe ? 'If your flags are correct, the other neighbours are safe.' : mines ? 'If your flags are correct, all other neighbours contain mines.' : 'You need another clue here.'}',
          target: hidden.first);
    }
  }
  return BoardHint(
      de ? 'Öffne ein Startfeld.' : 'Reveal a starting cell.',
      de
          ? 'Ein enthüllter Hinweis begrenzt seine Nachbarn.'
          : 'A revealed clue constrains its neighbours.',
      de
          ? 'Vor dem ersten Hinweis lässt sich kein sicherer Nachbar ableiten.'
          : 'Before the first clue, a safe neighbour cannot be deduced.');
}
