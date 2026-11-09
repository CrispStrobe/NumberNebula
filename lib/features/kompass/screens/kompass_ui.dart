import 'package:flutter/material.dart';

String kc(bool german, String de, String en) => german ? de : en;

String kompassDomainLabel(String domain, bool german) => switch (domain) {
      'numbers' =>
        kc(german, 'Zahlen und Operationen', 'Numbers and operations'),
      'geometry' => kc(german, 'Raum und Form', 'Space and shape'),
      'measurement' =>
        kc(german, 'Größen und Messen', 'Quantities and measurement'),
      'data' => kc(german, 'Daten und Zufall', 'Data and chance'),
      _ => domain,
    };

IconData kompassDomainIcon(String domain) => switch (domain) {
      'numbers' => Icons.calculate_outlined,
      'geometry' => Icons.view_in_ar_outlined,
      'measurement' => Icons.straighten,
      'data' => Icons.bar_chart,
      _ => Icons.explore_outlined,
    };

String kompassProgressLabel(String state, bool german) => switch (state) {
      'practising' => kc(german, 'Noch einmal üben', 'Keep practising'),
      'supported' =>
        kc(german, 'Mit Unterstützung gelöst', 'Solved with support'),
      'independent' => kc(german, 'Ohne Hilfe gelöst', 'Solved independently'),
      'reviewDue' => kc(german, 'Zeit zum Wiederholen', 'Ready for a review'),
      _ => kc(german, 'Noch nicht ausreichend geprüft', 'More evidence needed'),
    };

/// A quiet, high-contrast surface shared by learning and paper-like checks.
/// Text remains responsive to the device's accessibility settings.
class KompassPage extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;
  final Widget? bottomNavigationBar;
  const KompassPage({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.bottomNavigationBar,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF126B67),
      brightness: Brightness.light,
    );
    return Theme(
      data: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        fontFamily: 'SpaceGrotesk',
        scaffoldBackgroundColor: const Color(0xFFF7F9F8),
        appBarTheme: AppBarTheme(
          backgroundColor: scheme.surface,
          foregroundColor: scheme.onSurface,
          surfaceTintColor: Colors.transparent,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: Colors.white,
        ),
      ),
      child: Scaffold(
        appBar: AppBar(title: Text(title), actions: actions),
        body: SafeArea(child: child),
        bottomNavigationBar: bottomNavigationBar == null
            ? null
            : SafeArea(top: false, child: bottomNavigationBar!),
      ),
    );
  }
}

class KompassPanel extends StatelessWidget {
  final Widget child;
  const KompassPanel({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(padding: const EdgeInsets.all(20), child: child),
      );
}

Future<void> showKompassGlossary(BuildContext context, bool german) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .8,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(kc(german, 'Mathematische Wörter', 'Mathematical words'),
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              for (final row in _glossary)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(row[0]),
                  subtitle: Text(row[german ? 1 : 2]),
                ),
            ],
          ),
        ),
      ),
    );

const _glossary = [
  [
    'genau / mindestens / höchstens',
    'Genau 5: nur 5. Mindestens 5: 5 oder mehr. Höchstens 5: 5 oder weniger.',
    'Exactly 5: only 5. At least 5: 5 or more. At most 5: 5 or fewer.',
  ],
  [
    'frühestens / spätestens',
    'Frühestens: die erste erlaubte Zeit. Spätestens: die letzte Zeit, die noch reicht.',
    'Earliest: the first permitted time. Latest: the last time that still works.',
  ],
  [
    'alle Möglichkeiten',
    'Sammle jede erlaubte Möglichkeit genau einmal. Eine feste Reihenfolge hilft, nichts zu übersehen.',
    'All possibilities: collect each allowed possibility once. A fixed order helps you avoid missing any.',
  ],
  [
    'Gegenbeispiel',
    'Ein erlaubtes Beispiel, bei dem eine Behauptung falsch ist. Eine Ausnahme widerlegt eine Aussage mit „immer“.',
    'Counterexample: an allowed example that makes a claim false. One exception disproves an “always” claim.',
  ],
  [
    'zusammenhängend / ohne Löcher',
    'Die Kästchen bilden über gemeinsame Seiten eine einzige Form. Ohne Löcher bleibt keine leere Stelle vollständig eingeschlossen.',
    'Connected: shared edges join the cells into one shape. With no holes, no empty space is completely enclosed.',
  ],
  [
    'ergänze',
    'Trage ein, was noch fehlt.',
    'Complete: fill in what is missing.'
  ],
  [
    'begründe',
    'Erkläre, warum deine Antwort stimmt. Eine passende Rechnung kann helfen.',
    'Justify: explain why your answer works. A relevant calculation can help.'
  ],
  [
    'vergleiche',
    'Untersuche, was gleich ist und was sich unterscheidet.',
    'Compare: look for what is the same and what is different.'
  ],
  [
    'genau in der Mitte',
    'Die Abstände zu beiden Seiten sind gleich.',
    'Exactly halfway: the distances to both ends are equal.'
  ],
  [
    'Nachbarzehner',
    'Die Zehnerzahl direkt unter und direkt über einer Zahl.',
    'Neighbouring tens: the multiples of ten immediately below and above a number.'
  ],
  [
    'Stellenwert',
    'Eine Ziffer hat je nach Stelle einen anderen Wert: 4 Zehner sind 40.',
    'Place value: a digit has a different value in each position; 4 tens are 40.'
  ],
  [
    'Überschlag',
    'Rechne mit passenden gerundeten Zahlen, um ein Ergebnis einzuschätzen.',
    'Estimate: calculate with suitably rounded numbers to judge a result.'
  ],
  [
    'Umfang / Flächeninhalt',
    'Umfang: Länge des Randes. Flächeninhalt: Größe der bedeckten Fläche.',
    'Perimeter: length around the boundary. Area: size of the covered surface.'
  ],
  [
    'Zeitpunkt / Zeitspanne',
    'Zeitpunkt: wann etwas geschieht. Zeitspanne: wie lange es dauert.',
    'Time: when something happens. Duration: how long it takes.'
  ],
  [
    'zusätzlich',
    'Gesucht ist, wie viel dazukommt, nicht die neue Gesamtzahl.',
    'Additional: how much is added, rather than the new total.'
  ],
  [
    'sicher / möglich / unmöglich',
    'Sicher: immer. Möglich: kann vorkommen. Unmöglich: kann nicht vorkommen.',
    'Certain: always. Possible: can happen. Impossible: cannot happen.'
  ],
  [
    'gleich wahrscheinlich',
    'Beide Ereignisse haben dieselbe Chance. Beachte alle gleich möglichen Ergebnisse.',
    'Equally likely: both events have the same chance. Consider all equally possible outcomes.'
  ],
];
