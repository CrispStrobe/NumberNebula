import '../models/practice_lesson_catalog.dart';

Map<String, dynamic> _m(Object? v) =>
    v is Map ? v.map((k, v) => MapEntry('$k', v)) : {};
List<dynamic> _l(Object? v) => v is List ? v : [];
Map<String, dynamic> _pairs(Object? v) => v is Map
    ? _m(v)
    : {
        for (final e in _l(v))
          if (e is List && e.length == 2) '${e[0]}': e[1],
      };

/// Current-board teaching, derived from visible clues and the player's moves.
/// No hidden secret, solution assignment or undisclosed mine is consulted.
Map<String, String>? actionHintGuidance(
  String game,
  Map<String, dynamic> s, {
  bool german = false,
}) {
  final lesson = practiceLessons[game];
  if (lesson == null) {
    return null;
  }
  String t(String en, String de) => german ? de : en;
  final p = _m(s['puzzle'] ?? s['_puzzle'] ?? s['currentPuzzle']);
  Map<String, String> help(String focus, String working) => {
        'focus': focus,
        'strategy': german ? lesson.strategyDe : lesson.strategyEn,
        'working': working,
        'replaceMove': 'true',
      };
  switch (game) {
    case 'asteroid_math':
      final order = _l(s['targetOrder']),
          i = s['currentTargetIndex'] as int? ?? 0;
      if (i >= order.length) {
        return help(
          t(
            'All ordered targets are accounted for.',
            'Alle geordneten Ziele sind berücksichtigt.',
          ),
          t(
            'There is no next asteroid to shoot in this round.',
            'In dieser Runde gibt es keinen nächsten Asteroiden mehr.',
          ),
        );
      }
      final next = order[i];
      final facts = _l(
        s['levelProblems'],
      ).map(_m).where((f) => f['answer'] == next).toList();
      final calculation =
          facts.isEmpty ? '' : "${facts.first['expression']} = $next. ";
      return help(
        t(
          'Compare the remaining calculation results, not their positions.',
          'Vergleiche die übrigen Rechenergebnisse, nicht ihre Positionen.',
        ),
        t(
          '${calculation}The remaining result order is ${order.skip(i).join(' → ')}. Choose $next first; a larger correct result must wait.',
          '${calculation}Die übrige Ergebnisreihenfolge ist ${order.skip(i).join(' → ')}. Wähle zuerst $next; ein größeres richtiges Ergebnis muss warten.',
        ),
      );
    case 'hyperdrive_gates':
    case 'pathfinder':
      final f = _m(s['currentProblem']);
      if (f.isEmpty) {
        return null;
      }
      return help(
        t(
          'Read the operator in the current calculation.',
          'Lies das Rechenzeichen der aktuellen Rechnung.',
        ),
        t(
          "${f['expression']} = ${f['answer']}. ${game == 'pathfinder' ? 'Tap the path' : 'Choose the gate'} labelled ${f['answer']}; position and proximity are not the rule.",
          "${f['expression']} = ${f['answer']}. ${game == 'pathfinder' ? 'Tippe auf den Weg' : 'Wähle das Tor'} mit ${f['answer']}; Position und Nähe sind nicht die Regel.",
        ),
      );
    case 'planet_hopping':
      final order = _l(s['targetSequence']),
          i = s['nextTargetIndex'] as int? ?? 0;
      if (i >= order.length) {
        return help(
          t(
            'The target order is complete.',
            'Die Zielreihenfolge ist vollständig.',
          ),
          t(
            'No new landing is needed.',
            'Eine weitere Landung ist nicht nötig.',
          ),
        );
      }
      final next = order[i];
      final matches = _l(s['planets'])
          .map(_m)
          .map((v) => _m(v['problem']))
          .where((f) => f['answer'] == next)
          .toList();
      final eq =
          matches.isEmpty ? '' : "${matches.first['expression']} = $next. ";
      return help(
        t(
          'Read the next target after the planets already visited.',
          'Lies das nächste Ziel nach den schon besuchten Planeten.',
        ),
        t(
          '${eq}Next is $next; the remaining order is ${order.skip(i).join(' → ')}. Match that value, even in a descending round.',
          '${eq}Als Nächstes kommt $next; die übrige Reihenfolge ist ${order.skip(i).join(' → ')}. Wähle diesen Wert, auch in einer absteigenden Runde.',
        ),
      );
    case 'puzzle_math':
      final placed = _pairs(s['placedPieces']);
      final used = placed.values.toSet();
      final pieces = _l(s['pieces']).map(_m).toList();
      for (final piece in pieces.where((v) => !used.contains(v['id']))) {
        final f = _m(piece['problem'] ?? piece['mathProblem']);
        final slots = pieces
            .where(
              (slot) =>
                  !placed.containsKey('${slot['id']}') &&
                  _m(slot['problem'] ?? slot['mathProblem'])['answer'] ==
                      f['answer'],
            )
            .toList();
        if (slots.isEmpty) {
          continue;
        }
        final slot = slots.first,
            row = (slot['row'] as int) + 1,
            col = (slot['col'] as int) + 1;
        final upright = (piece['rotation'] as int? ?? 0) == 0;
        return help(
          t(
            'Choose one piece that has not been placed.',
            'Wähle ein noch nicht gelegtes Teil.',
          ),
          t(
            "${f['expression']} = ${f['answer']}. An empty matching slot is row $row, column $col. ${upright ? 'The piece is upright; drag it there.' : 'Tap the piece until it is upright before dropping it there.'} A matching shape alone does not replace the result check.",
            "${f['expression']} = ${f['answer']}. Ein leerer passender Platz liegt in Zeile $row, Spalte $col. ${upright ? 'Das Teil steht aufrecht; ziehe es dorthin.' : 'Tippe das Teil zuerst aufrecht und lege es dann dort ab.'} Eine passende Form allein ersetzt die Ergebnisprüfung nicht.",
          ),
        );
      }
      return help(
        t('Inspect the placed pieces.', 'Prüfe die gelegten Teile.'),
        t(
          'Every piece is placed or no remaining piece has a matching empty result. Check results and upright orientation before submitting or removing a placement.',
          'Alle Teile sind gelegt oder kein übriges Teil hat einen leeren passenden Ergebnisplatz. Prüfe Ergebnisse und aufrechte Ausrichtung, bevor du bestätigst oder ein Teil entfernst.',
        ),
      );
    case 'signal_triangulation':
      final history = _l(s['history']);
      if (history.isEmpty) {
        return help(
          t(
            'Choose a deliberate first code guess.',
            'Wähle einen gezielten ersten Codeversuch.',
          ),
          t(
            'The code has ${s['length']} positions. Enter one glyph per position and submit. With no feedback yet, no position is known to be correct; do not assume the first chosen glyph belongs there.',
            'Der Code hat ${s['length']} Plätze. Setze auf jeden Platz ein Zeichen und bestätige. Ohne Rückmeldung ist noch keine Position sicher; nimm nicht an, dass dein erstes Zeichen dort hingehört.',
          ),
        );
      }
      final last = _m(history.last),
          exact = last['correct'] as int,
          misplaced = last['present'] as int,
          n = _l(last['guess']).length;
      return help(
        t(
          'Read both totals from your most recent guess.',
          'Lies beide Zahlen deines letzten Versuchs.',
        ),
        t(
          'The last $n-position guess has $exact exact positions and $misplaced correct glyphs elsewhere: ${exact + misplaced} glyph occurrences match in total. These totals do not identify which positions are exact. Test a new order consistent with every previous feedback.',
          'Der letzte Versuch mit $n Plätzen hat $exact genaue Positionen und $misplaced richtige Zeichen an anderen Stellen: insgesamt ${exact + misplaced} passende Zeichenvorkommen. Die Zahlen verraten nicht, welche Positionen genau stimmen. Teste eine neue Reihenfolge, die zu jeder bisherigen Rückmeldung passt.',
        ),
      );
    case 'comm_relay':
      final type = p['cipherType'], cipher = p['cipherText'] as String? ?? '';
      final hints = _pairs(p['hintLetters']);
      final mapping =
          hints.entries.take(3).map((e) => '${e.key} → ${e.value}').join(', ');
      if (type == 'caesar') {
        final shift = s['_currentShift'] as int? ?? 0;
        final shown = String.fromCharCodes(
          cipher.runes
              .take(4)
              .map((c) => c >= 65 && c <= 90 ? 65 + (c - 65 - shift) % 26 : c),
        );
        return help(
          t(
            'Test your Caesar wheel on the first letters.',
            'Teste dein Caesar-Rad an den ersten Buchstaben.',
          ),
          t(
            'Your selected backward shift is $shift. It turns “${cipher.substring(0, cipher.length < 4 ? cipher.length : 4)}” into “$shown”. ${mapping.isEmpty ? 'Check whether this begins a plausible word; the current shift is a trial, not a confirmed solution.' : 'Compare with the revealed mappings $mapping.'} Use the same shift for every letter.',
            'Deine gewählte Rückwärtsverschiebung ist $shift. Sie macht aus „${cipher.substring(0, cipher.length < 4 ? cipher.length : 4)}“ „$shown“. ${mapping.isEmpty ? 'Prüfe, ob so ein sinnvolles Wort beginnt; die aktuelle Verschiebung ist ein Versuch, keine bestätigte Lösung.' : 'Vergleiche mit den enthüllten Zuordnungen $mapping.'} Nutze dieselbe Verschiebung für jeden Buchstaben.',
          ),
        );
      }
      return help(
        t(
          'Use the rule of the named cipher.',
          'Nutze die Regel der benannten Chiffre.',
        ),
        type == 'atbash'
            ? t(
                'This is Atbash: A ↔ Z, B ↔ Y, C ↔ X. Decode the first letter using opposite ends of the alphabet; a Caesar shift is not the right operation.',
                'Das ist Atbash: A ↔ Z, B ↔ Y, C ↔ X. Entschlüssle den ersten Buchstaben über entgegengesetzte Alphabetenden; eine Caesar-Verschiebung ist hier falsch.',
              )
            : t(
                'This is a keyword substitution. ${mapping.isEmpty ? 'Read the displayed substitution alphabet.' : 'Start with the revealed mappings $mapping.'} Replace each cipher letter using that mapping, not a constant Caesar shift.',
                'Das ist eine Schlüsselwort-Ersetzung. ${mapping.isEmpty ? 'Lies das angezeigte Ersetzungsalphabet.' : 'Beginne mit den enthüllten Zuordnungen $mapping.'} Ersetze jeden Geheimtextbuchstaben nach dieser Zuordnung, nicht durch eine feste Caesar-Verschiebung.',
              ),
      );
    case 'crew_manifest':
      final clues = _l(p['structuredClues']).map(_m).toList(),
          marks = _pairs(s['_gridState']);
      final people = _l(p['crewNames']), items = _l(p['itemNames']);
      for (final c in clues) {
        final r = people.indexOf(c['crewName']),
            col = items.indexOf(c['itemName']);
        final current = marks['${r}_$col'] ?? 'empty';
        if ((c['type'] == 'positive' && current == 'check') ||
            (c['type'] == 'negative' && current == 'cross')) {
          continue;
        }
        final positive = c['type'] == 'positive';
        return help(
          t(
            'Use the visible clue about ${c['crewName']}.',
            'Nutze den sichtbaren Hinweis zu ${c['crewName']}.',
          ),
          t(
            "${c['crewName']} ${positive ? 'has' : 'does not have'} ${c['itemName']}. Set that cell to ${positive ? 'a check mark' : 'a cross'}. ${positive ? 'Then exclude the other cells in that row and column: neither person nor item can be paired twice.' : 'A negative clue excludes only this pairing; it does not establish another pairing by itself.'}",
            "${c['crewName']} ${positive ? 'hat' : 'hat nicht'} ${c['itemName']}. Setze dieses Feld auf ${positive ? 'einen Haken' : 'ein Kreuz'}. ${positive ? 'Schließe dann die anderen Felder dieser Zeile und Spalte aus: Person und Gegenstand dürfen nicht doppelt zugeordnet werden.' : 'Ein Nein-Hinweis schließt nur diese Zuordnung aus; er beweist allein keine andere Zuordnung.'}",
          ),
        );
      }
      return help(
        t(
          'Check rows and columns with only one possibility.',
          'Prüfe Zeilen und Spalten mit nur einer Möglichkeit.',
        ),
        t(
          'All direct clues are marked. Each row and column must contain exactly one check. Exclude items already assigned elsewhere, then confirm the last possible pairing.',
          'Alle direkten Hinweise sind markiert. Jede Zeile und Spalte braucht genau einen Haken. Schließe schon anderweitig vergebene Dinge aus und bestätige dann die letzte mögliche Zuordnung.',
        ),
      );
    case 'alien_tribunal':
      final people = _l(p['people']).map(_m).toList(),
          roles = _pairs(s['_userAssignment']);
      for (var i = 0; i < people.length; i++) {
        final person = people[i];
        final role = roles['$i'];
        if (role is! bool) {
          continue;
        }
        bool? truth;
        if (person['kind'] == 'count' && roles.length == people.length) {
          truth = roles.values
                  .where((v) => v == person['countsTruthTellers'])
                  .length ==
              person['countValue'];
        }
        if (person['kind'] == 'single' &&
            roles['${person['targetIndex']}'] is bool) {
          truth =
              roles['${person['targetIndex']}'] == person['claimsTruthTeller'];
        }
        if (person['kind'] == 'pair' &&
            roles['${person['targetIndex']}'] is bool &&
            roles['${person['secondTargetIndex']}'] is bool) {
          final a = roles['${person['targetIndex']}'] ==
                  person['claimsTruthTeller'],
              b = roles['${person['secondTargetIndex']}'] ==
                  person['claimsTruthTeller'];
          truth = person['pairRequiresBoth'] == true ? a && b : a || b;
        }
        if (truth != null && truth != role) {
          return help(
            t(
              'Test ${person['name']} against your current roles.',
              'Prüfe ${person['name']} mit deinen aktuellen Rollen.',
            ),
            t(
              "With your current assignments, this speaker’s whole statement is ${truth ? 'true' : 'false'}, but you marked the speaker as ${role ? 'truthful' : 'lying'}. These conflict. Change at least one involved role and check every statement again; blindly flipping just this speaker may break another claim.",
              "Mit deinen aktuellen Zuordnungen ist die gesamte Aussage ${truth ? 'wahr' : 'falsch'}, aber du hast den Sprecher als ${role ? 'wahr' : 'lügend'} markiert. Das widerspricht sich. Ändere mindestens eine beteiligte Rolle und prüfe jede Aussage erneut; nur diesen Sprecher blind umzuschalten kann eine andere Aussage verletzen.",
            ),
          );
        }
      }
      return help(
        t(
          'Check one complete statement, not a single phrase.',
          'Prüfe eine vollständige Aussage, nicht nur einen Satzteil.',
        ),
        t(
          'Compare each statement’s truth under your current roles with its speaker’s role. “Both” needs both claims true; “at least one” needs only one. A liar must make the whole statement false.',
          'Vergleiche den Wahrheitswert jeder Aussage unter deinen aktuellen Rollen mit der Sprecherrolle. „Beide“ verlangt zwei wahre Teile; „mindestens einer“ nur einen. Bei einem Lügner muss die gesamte Aussage falsch sein.',
        ),
      );
    case 'hive_station':
      final revealed = _l(
        p['revealedHints'],
      ).map(_m).map((v) => '${v['q']},${v['r']}').toSet();
      final marked = _l(
        s['userMarked'],
      ).map(_m).map((v) => '${v['q']},${v['r']}').toSet();
      final cells = _l(
        p['allCells'],
      ).map(_m).map((v) => '${v['q']},${v['r']}').toSet();
      Map<String, String>? fallback;
      for (final raw in _l(p['numberHints'])) {
        final pair = _l(raw);
        if (pair.length != 2) {
          continue;
        }
        final c = _m(pair.first), q = c['q'] as int, r = c['r'] as int;
        if (!revealed.contains('$q,$r')) {
          continue;
        }
        final neighbours = [
          (q + 1, r),
          (q - 1, r),
          (q, r + 1),
          (q, r - 1),
          (q + 1, r - 1),
          (q - 1, r + 1),
        ].map((v) => '${v.$1},${v.$2}').where(cells.contains).toList();
        final flags = neighbours.where(marked.contains).length;
        final unknown = neighbours
            .where((v) => !marked.contains(v) && !revealed.contains(v))
            .length;
        if (unknown == 0) {
          continue;
        }
        final clue = pair[1] as int, need = clue - flags;
        final conclusion = need < 0
            ? t(
                'There are more marks than this clue permits; review these marks first.',
                'Es sind mehr Markierungen vorhanden, als dieser Hinweis erlaubt; prüfe diese zuerst.',
              )
            : need == 0
                ? t(
                    'If those marks are correct, the other neighbours must stay unmarked.',
                    'Wenn diese Markierungen stimmen, müssen die übrigen Nachbarn unmarkiert bleiben.',
                  )
                : need == unknown
                    ? t(
                        'If those marks are correct, every undecided neighbour must be marked as energy.',
                        'Wenn diese Markierungen stimmen, muss jeder ungeklärte Nachbar als Energie markiert werden.',
                      )
                    : t(
                        'This clue alone cannot choose which neighbours contain the remaining energy; combine it with an overlapping clue.',
                        'Dieser Hinweis allein bestimmt nicht, welche Nachbarn die übrige Energie enthalten; kombiniere ihn mit einem überlappenden Hinweis.',
                      );
        final candidate = help(
          t(
            'Use the revealed $clue clue at hex ($q, $r).',
            'Nutze den sichtbaren Hinweis $clue am Sechseck ($q, $r).',
          ),
          t(
            'Among its six possible neighbours: $flags marked, $unknown undecided. $clue − $flags = $need energy cells still needed. $conclusion',
            'Unter seinen sechs möglichen Nachbarn: $flags markiert, $unknown ungeklärt. $clue − $flags = $need noch benötigte Energiezellen. $conclusion',
          ),
        );
        if (need == 0 || need == unknown || need < 0) {
          return candidate;
        }
        fallback ??= candidate;
      }
      return fallback ??
          help(
            t(
              'Compare overlapping revealed hexagonal clues.',
              'Vergleiche überlappende sichtbare Sechseckhinweise.',
            ),
            t(
              'Count only the six neighbours of each clue, not the clue itself. Use common neighbours to compare what each clue still needs.',
              'Zähle nur die sechs Nachbarn jedes Hinweises, nicht das Hinweisfeld selbst. Vergleiche anhand gemeinsamer Nachbarn, was jeder Hinweis noch benötigt.',
            ),
          );
    case 'xenobiology_lab':
      final types = ['A', 'B', if (s['_hasThirdType'] == true) 'C'];
      var eyes = 0, legs = 0;
      final eyeTerms = <String>[], legTerms = <String>[];
      for (final k in types) {
        final n = s['_slider$k'] as int? ?? 0,
            e = s['_eyes$k'] as int,
            l = s['_legs$k'] as int;
        eyes += n * e;
        legs += n * l;
        eyeTerms.add('$n × $e');
        legTerms.add('$n × $l');
      }
      return help(
        t(
          'Check both totals using your current species counts.',
          'Prüfe beide Summen mit deinen aktuellen Artenzahlen.',
        ),
        t(
          'Your current counts give ${eyeTerms.join(' + ')} = $eyes eyes (target ${s['_totalEyes']}) and ${legTerms.join(' + ')} = $legs legs (target ${s['_totalLegs']}). ${eyes == s['_totalEyes'] && legs == s['_totalLegs'] ? 'Both totals match; submit these counts.' : 'Keep adjusting until the same counts satisfy BOTH totals, not just one.'}',
          'Deine aktuellen Anzahlen ergeben ${eyeTerms.join(' + ')} = $eyes Augen (Ziel ${s['_totalEyes']}) und ${legTerms.join(' + ')} = $legs Beine (Ziel ${s['_totalLegs']}). ${eyes == s['_totalEyes'] && legs == s['_totalLegs'] ? 'Beide Summen passen; bestätige diese Anzahlen.' : 'Ändere weiter, bis dieselben Anzahlen BEIDE Summen erfüllen, nicht nur eine.'}',
        ),
      );
    case 'arithmancer_duel':
      final player = _m(_m(s['pvp'])['player1State']);
      final engine = _m(s['engine'] ?? player['engine']);
      final energy = player['energy'] ?? engine['playerEnergy'];
      final selected = _l(s['battlefield']).map(_m).toList();
      final cards = _l(s['hand']).map(_m).toList();
      if (energy is! int) {
        return null;
      }
      final cost = selected.fold<int>(
        0,
        (sum, c) => sum + (c['cost'] as int? ?? 0),
      );
      final affordable =
          cards.where((c) => (c['cost'] as int? ?? 0) + cost <= energy).length;
      return help(
        t(
          'Check the energy cost before calculating damage.',
          'Prüfe die Energiekosten vor dem Schaden.',
        ),
        t(
          'Your selected cards cost $cost in total; you have $energy energy. ${cost > energy ? 'This selection cannot be played: remove cards until its total cost fits.' : 'You can afford the current cost, but the cards must still form a valid calculation.'} $affordable hand cards fit the remaining budget individually; several together may exceed it. Energy cost and the calculation’s result are different numbers.',
          'Deine gewählten Karten kosten zusammen $cost; du hast $energy Energie. ${cost > energy ? 'Diese Auswahl ist zu teuer: Entferne Karten, bis die Gesamtkosten passen.' : 'Die aktuellen Kosten sind bezahlbar, aber die Karten müssen noch eine gültige Rechnung bilden.'} $affordable Handkarten passen einzeln ins übrige Budget; mehrere zusammen können es überschreiten. Energiekosten und Rechenergebnis sind verschiedene Zahlen.',
        ),
      );
    case 'asteroid_duel':
      final remaining = s['_remaining'] as int, max = s['_maxPerTurn'] as int;
      int? take;
      for (var n = 1; n <= max && n < remaining; n++) {
        if ((remaining - n - 1) % (max + 1) == 0) {
          take = n;
          break;
        }
      }
      return help(
        t(
          'Compare the legal takes with what they leave the opponent.',
          'Vergleiche erlaubte Entnahmen damit, was dem Gegner bleibt.',
        ),
        take == null
            ? t(
                'No take can force a win from this count against perfect play. Never take the last deliberately: if more than one remains, leave at least one and watch for the opponent to give you a better count.',
                'Gegen perfektes Spiel kann hier keine Entnahme den Sieg erzwingen. Nimm den letzten nicht absichtlich: Solange mehr als einer liegt, lasse mindestens einen und warte auf eine günstigere Stellung durch den Gegner.',
              )
            : t(
                'Take $take and leave ${remaining - take}. After the opponent’s next take, try to make their take plus yours total ${max + 1}. That keeps reducing the pile toward one asteroid left for the opponent, who loses by taking it.',
                'Nimm $take und lasse ${remaining - take} übrig. Ergänze danach die Entnahme des Gegners mit deiner auf insgesamt ${max + 1}. So verringerst du den Stapel in Richtung eines letzten Asteroiden für den Gegner; wer ihn nimmt, verliert.',
              ),
      );
    case 'cargo_bay_arranger':
      final grid = _l(s['grid']).map(_l).toList();
      var chosen = -1, holes = 100000, total = 0;
      for (var i = grid.length - 1; i >= 0; i--) {
        final gaps = grid[i].where((v) => v == null).length;
        if (gaps > 0 && gaps < holes) {
          chosen = i;
          holes = gaps;
          total = grid[i].where((v) => v != null).map(_m).fold<int>(
                0,
                (sum, c) =>
                    sum + (c['value'] as int? ?? c['number'] as int? ?? 0),
              );
        }
      }
      if (chosen < 0) {
        return help(
          t(
            'Inspect the landing outline for a full-row opportunity.',
            'Prüfe die Landevorschau auf eine vollständig füllbare Reihe.',
          ),
          t(
            'Any full horizontal row clears, regardless of its sum. Keep the landing surface reachable and avoid covering a hole.',
            'Jede volle waagerechte Reihe verschwindet, unabhängig von ihrer Summe. Halte die Landefläche erreichbar und überdecke keine Lücke.',
          ),
        );
      }
      return help(
        t(
          'Look at row ${chosen + 1}, which has $holes empty cells.',
          'Betrachte Zeile ${chosen + 1} mit $holes leeren Feldern.',
        ),
        t(
          'Its occupied values total $total. Filling all $holes holes clears the row even if the sum is not ${s['targetSum']}. The target sum is a bonus opportunity, not a clearing requirement. Check the current piece’s entire shape and landing outline before dropping.',
          'Ihre belegten Zahlen ergeben $total. Werden alle $holes Lücken gefüllt, verschwindet die Reihe auch ohne Summe ${s['targetSum']}. Die Zielsumme ist eine Bonuschance, keine Löschbedingung. Prüfe vor dem Fallenlassen die ganze Form und die Landevorschau.',
        ),
      );
    case 'star_chart_scan':
      final found = _l(s['_foundEquations']).toSet();
      final equations = _l(
        p['placedEquations'],
      ).map(_m).where((e) => !found.contains(e['equation'])).toList();
      if (equations.isEmpty) {
        return help(
          t(
            'All listed equations have been found.',
            'Alle aufgelisteten Gleichungen sind gefunden.',
          ),
          t(
            'No further sweep is needed for this round.',
            'Für diese Runde ist keine weitere Auswahl nötig.',
          ),
        );
      }
      final e = equations.first, d = _m(e['direction']);
      final dr = d['dr'] as int? ?? 0, dc = d['dc'] as int? ?? 1;
      final direction = dr == 0
          ? t(dc > 0 ? 'right' : 'left', dc > 0 ? 'rechts' : 'links')
          : dc == 0
              ? t(dr > 0 ? 'down' : 'up', dr > 0 ? 'unten' : 'oben')
              : t(
                  '${dr > 0 ? 'down' : 'up'} and ${dc > 0 ? 'right' : 'left'}',
                  '${dr > 0 ? 'unten' : 'oben'} und ${dc > 0 ? 'rechts' : 'links'}',
                );
      return help(
        t(
          'Pick a target equation that is still in the list.',
          'Wähle eine noch gesuchte Gleichung aus der Liste.',
        ),
        t(
          'For ${e['equation']}, start at row ${(e['startRow'] as int) + 1}, column ${(e['startCol'] as int) + 1}, and sweep $direction through EVERY character to the other end. Keep the line straight; a reversed straight sweep also works.',
          'Beginne für ${e['equation']} in Zeile ${(e['startRow'] as int) + 1}, Spalte ${(e['startCol'] as int) + 1}, und ziehe nach $direction über JEDES Zeichen bis zum anderen Ende. Bleibe auf einer Geraden; die umgekehrte gerade Richtung zählt auch.',
        ),
      );
    case 'asteroid_field_navigator':
      // Existing local arithmetic is conditional on justified player flags;
      // it reads only revealed clues, not secret mine locations.
      return null;
    default:
      return null;
  }
}
