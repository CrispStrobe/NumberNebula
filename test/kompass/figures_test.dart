import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/kompass/widgets/kompass_cell_input.dart';
import 'package:space_math_academy/features/kompass/widgets/kompass_figure_view.dart';

const _figures = <String, Map<String, dynamic>>{
  'wall': {
    'rows': [
      [12, null, 8],
      [null, 14],
      [null]
    ]
  },
  'numberLine': {
    'min': 200,
    'max': 400,
    'step': 20,
    'marks': [
      {'value': 300, 'label': 'A'}
    ]
  },
  'placeValue': {
    'columns': [
      {
        'label': {'de': 'Hunderter', 'en': 'Hundreds'},
        'value': 13
      },
      {'label': 'Z', 'value': 2}
    ]
  },
  'grid': {
    'rows': 3,
    'cols': 4,
    'filled': ['0,0', '1,2']
  },
  'barChart': {
    'labels': [
      {'de': 'Äpfel', 'en': 'Apples'},
      'B',
      'C'
    ],
    'values': [4, 8, 2],
    'max': 10,
    'step': 2,
    'yLabel': {'de': 'Anzahl', 'en': 'Count'}
  },
  'table': {
    'headers': [
      {'de': 'Ware', 'en': 'Item'},
      {'de': 'Preis', 'en': 'Price'}
    ],
    'rows': [
      [
        {'de': 'Saft', 'en': 'Juice'},
        '1,50 €'
      ],
      ['B', '2,30 €']
    ]
  },
  'cubePlan': {
    'heights': [
      [1, 2, 0],
      [3, 1, 2]
    ],
    'view': 'right'
  },
  'cubeNet': {
    'rows': 4,
    'cols': 3,
    'cells': ['0,1', '1,0', '1,1', '1,2', '2,1', '3,1'],
    'labels': {'1,1': 'A'}
  },
  'clock': {'hour': 13, 'minute': 40},
  'tokenBag': {
    'tokens': [
      {
        'label': {'de': 'Stern', 'en': 'Star'},
        'count': 4
      },
      {
        'label': {'de': 'Kreis', 'en': 'Circle'},
        'count': 2
      }
    ]
  },
  'spinner': {
    'sectors': [
      {'label': 'A', 'weight': 2},
      {'label': 'B', 'weight': 1},
      {'label': 'C', 'weight': 1}
    ]
  },
  'shapeComparison': {
    'shapes': [
      {
        'id': 'A',
        'cells': ['0,0', '0,1', '1,0']
      },
      {
        'id': 'B',
        'cells': ['0,0', '1,0', '2,0']
      }
    ]
  },
  'measureLine': {'start': 3, 'end': 9, 'unit': 'cm', 'step': 1},
  'polygon': {
    'points': [
      [0, 0],
      [6, 0],
      [6, 3],
      [0, 3]
    ],
    'labels': ['A', 'B', 'C', 'D'],
    'axes': ['vertical']
  },
  'mirror': {
    'rows': 4,
    'cols': 6,
    'cells': ['1,0', '2,1'],
    'axis': {'direction': 'vertical', 'at': 3}
  },
};

Widget _app(Widget child, {double scale = 1}) => MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: MediaQuery(
        data: MediaQueryData(
            size: const Size(390, 844), textScaler: TextScaler.linear(scale)),
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

void main() {
  for (final entry in _figures.entries) {
    for (final german in [true, false]) {
      testWidgets('${entry.key} renders ${german ? 'DE' : 'EN'} at large text',
          (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(_app(
          KompassFigureView(
            figure: {
              'kind': entry.key,
              'data': entry.value,
              'alt': const {
                'de': 'Beschreibung der gegebenen Abbildung.',
                'en': 'Description of the given figure.'
              }
            },
            german: german,
            plain: !german,
          ),
          scale: 2,
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(ValueKey('kompass_figure_${entry.key}')),
            findsOneWidget);
        final description =
            find.byKey(const ValueKey('figure_description')).first;
        await tester.ensureVisible(description);
        await tester.tap(description);
        await tester.pumpAndSettle();
        expect(
            find.text(german
                ? 'Beschreibung der gegebenen Abbildung.'
                : 'Description of the given figure.'),
            findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
      'cell input preserves givens and reports additions through real taps',
      (tester) async {
    var selected = <String>{};
    final changes = <Set<String>>[];
    await tester.pumpWidget(_app(StatefulBuilder(
      builder: (context, setState) => KompassCellInput(
        figure: const {
          'kind': 'mirror',
          'data': {
            'rows': 3,
            'cols': 4,
            'cells': ['1,0'],
            'axis': {'direction': 'vertical', 'at': 2}
          }
        },
        selected: selected,
        onChanged: (value) {
          changes.add(value);
          setState(() => selected = value);
        },
        german: true,
      ),
    )));
    await tester.tap(find.byKey(const ValueKey('kompass_cell_1,0')));
    await tester.pump();
    expect(changes, isEmpty);
    await tester.tap(find.byKey(const ValueKey('kompass_cell_1,3')));
    await tester.pump();
    expect(changes.single, {'1,3'});
    await tester.tap(find.byKey(const ValueKey('kompass_cell_1,3')));
    await tester.pump();
    expect(changes.last, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('grid cells accept Tab and Enter without drag input',
      (tester) async {
    var selected = <String>{};
    await tester.pumpWidget(_app(StatefulBuilder(
      builder: (context, setState) => KompassCellInput(
        figure: const {
          'kind': 'grid',
          'data': {'rows': 2, 'cols': 2}
        },
        selected: selected,
        onChanged: (value) => setState(() => selected = value),
        german: false,
      ),
    )));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(selected, {'0,0'});
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(selected, isEmpty);
  });

  testWidgets(
      'equal unit areas retain equal painted area across different bounds',
      (tester) async {
    await tester.pumpWidget(_app(const KompassFigureView(
      figure: {
        'kind': 'shapeComparison',
        'data': {
          'shapes': [
            {
              'id': 'A',
              'cells': ['0,0', '1,0', '2,0', '2,1', '2,2', '1,2']
            },
            {
              'id': 'B',
              'cells': ['0,0', '0,1', '0,2', '1,0', '1,1', '1,2']
            }
          ]
        },
        'alt': 'Two shapes made from equal unit squares.'
      },
      german: false,
    )));
    final drawings = tester
        .widgetList<CustomPaint>(find.descendant(
          of: find.byKey(const ValueKey('kompass_figure_shapeComparison')),
          matching: find.byType(CustomPaint),
        ))
        .where((widget) => widget.painter != null)
        .toList();
    expect(drawings, hasLength(2));
    final cellAreas = <List<double>>[];
    for (final drawing in drawings) {
      final canvas = TestRecordingCanvas();
      drawing.painter!.paint(canvas, tester.getSize(find.byWidget(drawing)));
      cellAreas.add(canvas.invocations
          .map((record) => record.invocation)
          .where((call) =>
              call.memberName == #drawRect &&
              (call.positionalArguments[1] as Paint).style ==
                  PaintingStyle.fill)
          .map((call) => call.positionalArguments[0] as Rect)
          .map((rect) => rect.width * rect.height)
          .toList());
    }
    expect(cellAreas[0], hasLength(6));
    expect(cellAreas[1], hasLength(6));
    expect(cellAreas[0], everyElement(closeTo(cellAreas[1].first, 0.001)));
    expect(cellAreas[1], everyElement(closeTo(cellAreas[0].first, 0.001)));
    expect(tester.takeException(), isNull);
  });

  testWidgets('unknown figures retain the authored accessible description',
      (tester) async {
    final handle = tester.ensureSemantics();
    addTearDown(handle.dispose);
    await tester.pumpWidget(_app(const KompassFigureView(
      figure: {
        'kind': 'futureFigure',
        'alt': {'de': 'Drei gleich große Felder.', 'en': 'Three equal cells.'}
      },
      german: true,
    )));
    expect(find.text('Drei gleich große Felder.'), findsOneWidget);
    expect(find.bySemanticsLabel('Drei gleich große Felder.'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  test('localized table data uses requested language and handles numbers', () {
    expect(figureText({'de': 'Anzahl', 'en': 'Count'}, false), 'Count');
    expect(figureText({'de': 'Anzahl', 'en': 'Count'}, true), 'Anzahl');
    expect(figureText(13, true), '13');
  });
}
