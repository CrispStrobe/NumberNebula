import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A native, offline rendering of the original course's JSON figures.
///
/// Coordinates use zero-based rows/columns. Number-line marks expose their
/// authored label only: the coordinate used to position a question mark must
/// never become a visible answer. An equivalent authored description is always
/// available to assistive technology and through the description control.
class KompassFigureView extends StatelessWidget {
  final Map<String, dynamic> figure;
  final bool german;
  final bool plain;

  const KompassFigureView({
    super.key,
    required this.figure,
    required this.german,
    this.plain = false,
  });

  @override
  Widget build(BuildContext context) {
    final kind = figure['kind'] as String? ?? '';
    final data = _map(figure['data']);
    final alt = figureText(figure['alt'], german);
    final ink = plain ? const Color(0xFF152235) : const Color(0xFFEBF5FF);
    final accent = plain ? const Color(0xFF245C7A) : const Color(0xFF8BDFEA);
    final background = plain ? Colors.white : const Color(0xFF14243B);
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final style = TextStyle(color: ink, fontSize: 16, height: 1.4);
    Widget body;
    switch (kind) {
      case 'wall':
        body = _wall(data, ink, accent, style);
      case 'placeValue':
        final columns = _list(data['columns']).map(_map).toList();
        body = _table(
          columns.map((c) => figureText(c['label'], german)).toList(),
          [columns.map((c) => figureText(c['value'], german)).toList()],
          ink,
          style,
        );
      case 'table':
        body = _table(
          _list(data['headers']).map((v) => figureText(v, german)).toList(),
          _list(data['rows'])
              .map(
                (row) => _list(row).map((v) => figureText(v, german)).toList(),
              )
              .toList(),
          ink,
          style,
        );
      case 'tokenBag':
        body = Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final token in _list(data['tokens']).map(_map))
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: accent),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${figureText(token['label'], german)}: ${_integer(token['count'])}',
                  style: style,
                ),
              ),
          ],
        );
      case 'shapeComparison':
        final shapes = _list(data['shapes']).map(_map).toList();
        final allCells = shapes.expand((shape) => _cells(shape['cells']));
        // Every shape uses the same grid extent and therefore the same unit
        // square. Auto-fitting each shape separately would distort its area.
        final rows =
            allCells.fold<int>(1, (n, cell) => math.max(n, cell.$1 + 1));
        final cols =
            allCells.fold<int>(1, (n, cell) => math.max(n, cell.$2 + 1));
        body = Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (final shape in shapes)
              SizedBox(
                width: 170 * math.min(scale, 2),
                child: Column(
                  children: [
                    Text(figureText(shape['id'], german), style: style),
                    _drawing(
                      context,
                      'cubeNet',
                      {'cells': shape['cells'], 'rows': rows, 'cols': cols},
                      ink,
                      accent,
                      scale,
                      compact: true,
                    ),
                  ],
                ),
              ),
          ],
        );
      case 'numberLine':
      case 'grid':
      case 'barChart':
      case 'cubePlan':
      case 'cubeNet':
      case 'clock':
      case 'spinner':
      case 'measureLine':
      case 'polygon':
      case 'mirror':
        body = _drawing(context, kind, data, ink, accent, scale);
      default:
        body = ExcludeSemantics(
          // The surrounding image semantics already supplies this description.
          // Avoid announcing it twice when an unknown figure uses a text fallback.
          excluding: alt.isNotEmpty,
          child: Text(
            alt.isNotEmpty
                ? alt
                : (german
                    ? 'Abbildung nicht verfügbar.'
                    : 'Figure unavailable.'),
            style: style,
          ),
        );
    }
    return Container(
      key: ValueKey('kompass_figure_$kind'),
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: ink.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: DefaultTextStyle(
        style: style,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(image: true, label: alt, child: body),
            if (alt.isNotEmpty)
              Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: Material(
                  color: Colors.transparent,
                  child: ExpansionTile(
                    key: const ValueKey('figure_description'),
                    tilePadding: EdgeInsets.zero,
                    iconColor: ink,
                    collapsedIconColor: ink,
                    title: Text(
                      german ? 'Abbildung beschreiben' : 'Describe this figure',
                      style: style.copyWith(fontSize: 14),
                    ),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(alt, style: style),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _wall(
    Map<String, dynamic> data,
    Color ink,
    Color accent,
    TextStyle style,
  ) {
    final rows = _list(data['rows']).map(_list).toList().reversed;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        children: [
          for (final row in rows)
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final value in row)
                  Container(
                    constraints: const BoxConstraints(
                      minWidth: 64,
                      minHeight: 50,
                    ),
                    margin: const EdgeInsets.all(3),
                    padding: const EdgeInsets.all(10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(color: accent, width: 1.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      value == null ? '?' : figureText(value, german),
                      style: style.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _table(
    List<String> headers,
    List<List<String>> rows,
    Color ink,
    TextStyle style,
  ) {
    final columns = [
      headers.length,
      ...rows.map((r) => r.length),
    ].fold<int>(0, math.max);
    if (columns == 0) return const SizedBox.shrink();
    Widget cell(String text, {bool heading = false}) => Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            text,
            style: style.copyWith(
              fontWeight: heading ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        border: TableBorder.all(color: ink.withValues(alpha: 0.5)),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          if (headers.isNotEmpty)
            TableRow(
              children: [
                for (var i = 0; i < columns; i++)
                  cell(i < headers.length ? headers[i] : '', heading: true),
              ],
            ),
          for (final row in rows)
            TableRow(
              children: [
                for (var i = 0; i < columns; i++)
                  cell(i < row.length ? row[i] : ''),
              ],
            ),
        ],
      ),
    );
  }

  Widget _drawing(
    BuildContext context,
    String kind,
    Map<String, dynamic> data,
    Color ink,
    Color accent,
    double scale, {
    bool compact = false,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 360.0;
        final minWidth = (compact ? 140.0 : 300.0) * math.min(scale, 2.5);
        final width = math.max(available, minWidth);
        final baseHeight = switch (kind) {
          'numberLine' || 'measureLine' => 128.0,
          'barChart' => 290.0,
          'clock' || 'spinner' => 250.0,
          _ => compact ? 150.0 : 250.0,
        };
        final height = baseHeight * math.min(scale, 2.5);
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width,
            height: height,
            child: CustomPaint(
              painter: _FigurePainter(
                kind: kind,
                data: data,
                german: german,
                ink: ink,
                accent: accent,
                scale: scale,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Localized authored data may be a string, number or `{de, en}` pair.
String figureText(Object? value, bool german) {
  if (value == null) return '';
  if (value is Map) {
    return (value[german ? 'de' : 'en'] ?? value['de'] ?? value['en'] ?? '')
        .toString();
  }
  return value.toString();
}

Map<String, dynamic> _map(Object? value) => value is Map
    ? value.map((key, value) => MapEntry(key.toString(), value))
    : <String, dynamic>{};
List<dynamic> _list(Object? value) => value is List ? value : <dynamic>[];
double _number(Object? value, [double fallback = 0]) =>
    value is num && value.isFinite ? value.toDouble() : fallback;
int _integer(Object? value, [int fallback = 0]) =>
    value is num && value.isFinite ? value.toInt() : fallback;

List<(int, int)> _cells(Object? value) {
  final cells = <(int, int)>[];
  for (final item in _list(value)) {
    final parts = item is String ? item.split(',') : _list(item);
    if (parts.length != 2) continue;
    final row = int.tryParse(parts[0].toString());
    final col = int.tryParse(parts[1].toString());
    if (row != null && col != null && row >= 0 && col >= 0) {
      cells.add((row, col));
    }
  }
  return cells;
}

class _FigurePainter extends CustomPainter {
  final String kind;
  final Map<String, dynamic> data;
  final bool german;
  final Color ink, accent;
  final double scale;

  _FigurePainter({
    required this.kind,
    required this.data,
    required this.german,
    required this.ink,
    required this.accent,
    required this.scale,
  });

  double get font => 14 * math.min(scale, 2.5);
  Paint get pen => Paint()
    ..color = ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6;

  void _text(
    Canvas canvas,
    String text,
    Offset center, {
    Color? color,
    double? size,
    double maxWidth = double.infinity,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color ?? ink,
          fontSize: size ?? font,
          fontWeight: FontWeight.w600,
          fontFamily: 'SpaceGrotesk',
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: maxWidth);
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    switch (kind) {
      case 'numberLine':
      case 'measureLine':
        _numberLine(canvas, size);
      case 'grid':
      case 'cubeNet':
      case 'mirror':
        _grid(canvas, size);
      case 'barChart':
        _barChart(canvas, size);
      case 'cubePlan':
        _cubePlan(canvas, size);
      case 'clock':
        _clock(canvas, size);
      case 'spinner':
        _spinner(canvas, size);
      case 'polygon':
        _polygon(canvas, size);
    }
  }

  void _numberLine(Canvas canvas, Size size) {
    final measuring = kind == 'measureLine';
    final min = measuring ? 0.0 : _number(data['min']);
    final start = _number(data['start']);
    final end = _number(data['end'], 10);
    final max = measuring
        ? math.max(start, end) + math.max(1, _number(data['step'], 1))
        : _number(data['max'], 10);
    if (max <= min) return;
    final margin = font * 2;
    final left = margin, right = size.width - margin;
    final y = size.height * (measuring ? 0.62 : 0.55);
    double x(double value) =>
        left + (value - min) / (max - min) * (right - left);
    canvas.drawLine(Offset(left, y), Offset(right, y), pen);
    var step = _number(data['step'], (max - min) / 10);
    if (step <= 0) step = (max - min) / 10;
    final count = ((max - min) / step).floor().clamp(0, 100);
    for (var i = 0; i <= count; i++) {
      final value = min + i * step;
      canvas.drawLine(Offset(x(value), y - 7), Offset(x(value), y + 7), pen);
      if (measuring || i == 0 || i == count) {
        _text(canvas, _format(value), Offset(x(value), y + font * 1.6));
      }
    }
    if (!measuring && (min + count * step - max).abs() > 0.00001) {
      canvas.drawLine(Offset(right, y - 7), Offset(right, y + 7), pen);
      _text(canvas, _format(max), Offset(right, y + font * 1.6));
    }
    if (measuring) {
      final objectY = y - font * 2;
      canvas.drawLine(
        Offset(x(start), objectY),
        Offset(x(end), objectY),
        Paint()
          ..color = accent
          ..strokeWidth = 8,
      );
      for (final value in [start, end]) {
        canvas.drawLine(
          Offset(x(value), objectY - 10),
          Offset(x(value), y),
          pen,
        );
      }
      _text(
        canvas,
        figureText(data['unit'], german),
        Offset(size.width / 2, size.height - font * 0.6),
      );
    } else {
      for (final mark in _list(data['marks']).map(_map)) {
        final value = _number(mark['value']);
        if (value < min || value > max) continue;
        canvas.drawCircle(Offset(x(value), y), 4, Paint()..color = accent);
        canvas.drawLine(
          Offset(x(value), y - 5),
          Offset(x(value), y - font * 1.5),
          pen,
        );
        // The coordinate is intentionally not printed. It can be the answer.
        _text(
          canvas,
          figureText(mark['label'], german),
          Offset(x(value), y - font * 2.4),
        );
      }
    }
  }

  void _grid(Canvas canvas, Size size) {
    final cells = _cells(data[kind == 'grid' ? 'filled' : 'cells']);
    final rowExtent = cells.fold<int>(1, (a, c) => math.max(a, c.$1 + 1));
    final colExtent = cells.fold<int>(1, (a, c) => math.max(a, c.$2 + 1));
    final rows = _integer(data['rows'], rowExtent).clamp(1, 30);
    final cols = _integer(data['cols'], colExtent).clamp(1, 30);
    final cell = math.min((size.width - 36) / cols, (size.height - 36) / rows);
    final origin = Offset(
      (size.width - cols * cell) / 2,
      (size.height - rows * cell) / 2,
    );
    final labels = _map(data['labels']);
    final selected = cells.toSet();
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final rect = Rect.fromLTWH(
          origin.dx + c * cell,
          origin.dy + r * cell,
          cell,
          cell,
        );
        final filled = selected.contains((r, c));
        if (kind == 'cubeNet' && !filled) continue;
        if (filled) {
          canvas.drawRect(rect, Paint()..color = accent.withValues(alpha: 0.4));
          // A small cross makes the mark readable without relying on colour.
          if (kind != 'cubeNet') {
            final inset = cell * 0.28;
            canvas.drawLine(
              rect.topLeft + Offset(inset, inset),
              rect.bottomRight - Offset(inset, inset),
              pen,
            );
            canvas.drawLine(
              rect.topRight + Offset(-inset, inset),
              rect.bottomLeft + Offset(inset, -inset),
              pen,
            );
          }
        }
        canvas.drawRect(rect, pen);
        final label = labels['$r,$c'];
        if (label != null) {
          _text(
            canvas,
            figureText(label, german),
            rect.center,
            size: math.min(font, cell * 0.45),
          );
        }
      }
    }
    if (kind == 'mirror') {
      final axis = _map(data['axis']);
      final vertical = axis['direction'] != 'horizontal';
      final at = _number(axis['at'], (vertical ? cols : rows) / 2);
      final from = vertical
          ? Offset(origin.dx + at * cell, origin.dy - 10)
          : Offset(origin.dx - 10, origin.dy + at * cell);
      final to = vertical
          ? Offset(from.dx, origin.dy + rows * cell + 10)
          : Offset(origin.dx + cols * cell + 10, from.dy);
      _dashed(canvas, from, to, pen..strokeWidth = 3);
    }
  }

  void _barChart(Canvas canvas, Size size) {
    final labels = _list(data['labels']);
    final values = _list(data['values']).map(_number).toList();
    final count = math.min(labels.length, values.length);
    if (count == 0) return;
    final maxValue = _number(data['max'], values.fold<double>(1, math.max));
    if (maxValue <= 0) return;
    var step = _number(data['step'], math.max(1, maxValue / 5));
    if (step <= 0) step = maxValue / 5;
    final chart = Rect.fromLTRB(
      font * 3.5,
      font * 2.5,
      size.width - font,
      size.height - font * 4.5,
    );
    if (chart.width <= 0 || chart.height <= 0) return;
    final ticks = (maxValue / step).floor().clamp(0, 30);
    for (var i = 0; i <= ticks; i++) {
      final value = step * i;
      final y = chart.bottom - chart.height * value / maxValue;
      canvas.drawLine(
        Offset(chart.left, y),
        Offset(chart.right, y),
        pen..color = ink.withValues(alpha: 0.2),
      );
      _text(canvas, _format(value), Offset(chart.left - font * 1.4, y));
    }
    canvas.drawLine(chart.topLeft, chart.bottomLeft, pen);
    canvas.drawLine(chart.bottomLeft, chart.bottomRight, pen);
    final slot = chart.width / count;
    for (var i = 0; i < count; i++) {
      final height = chart.height * values[i].clamp(0, maxValue) / maxValue;
      final rect = Rect.fromLTWH(
        chart.left + slot * (i + 0.15),
        chart.bottom - height,
        slot * 0.7,
        height,
      );
      canvas.drawRect(rect, Paint()..color = accent.withValues(alpha: 0.65));
      canvas.drawRect(rect, pen);
      _text(
        canvas,
        figureText(labels[i], german),
        Offset(chart.left + slot * (i + 0.5), chart.bottom + font * 2),
        maxWidth: slot - 4,
      );
    }
    if (data['yLabel'] != null) {
      _text(
        canvas,
        figureText(data['yLabel'], german),
        Offset(size.width / 2, font),
        maxWidth: size.width,
      );
    }
  }

  void _cubePlan(Canvas canvas, Size size) {
    final heights = _list(data['heights'])
        .map((row) => _list(row).map((h) => _integer(h).clamp(0, 8)).toList())
        .toList();
    if (heights.isEmpty) return;
    final rows = heights.length;
    final cols = heights.map((r) => r.length).fold<int>(0, math.max);
    if (cols == 0) return;
    final maximum = heights.expand((r) => r).fold<int>(1, math.max);
    final unit = math.min(
      (size.width - 40) / (rows + cols + 2),
      (size.height - font * 3 - 30) / ((rows + cols) / 2 + maximum + 1),
    );
    final origin = Offset(
      size.width / 2 + (rows - cols) * unit / 2,
      maximum * unit + 12,
    );
    Offset p(double x, double y, double z) =>
        origin + Offset((x - y) * unit, (x + y) * unit * 0.5 - z * unit);
    void face(List<Offset> points, double alpha) {
      final path = Path()..addPolygon(points, true);
      canvas.drawPath(path, Paint()..color = accent.withValues(alpha: alpha));
      canvas.drawPath(path, pen..strokeWidth = 1);
    }

    for (var d = 0; d < rows + cols; d++) {
      for (var r = 0; r < rows; r++) {
        final c = d - r;
        if (c < 0 || c >= heights[r].length) continue;
        final x = c.toDouble(), y = r.toDouble();
        for (var z = 0; z < heights[r][c]; z++) {
          final bottom = z.toDouble(), top = bottom + 1;
          face([
            p(x, y + 1, bottom),
            p(x + 1, y + 1, bottom),
            p(x + 1, y + 1, top),
            p(x, y + 1, top),
          ], 0.35);
          face([
            p(x + 1, y, bottom),
            p(x + 1, y + 1, bottom),
            p(x + 1, y + 1, top),
            p(x + 1, y, top),
          ], 0.55);
          face([
            p(x, y, top),
            p(x + 1, y, top),
            p(x + 1, y + 1, top),
            p(x, y + 1, top),
          ], 0.85);
        }
      }
    }
    final right = data['view'] == 'right';
    final from =
        right ? p(cols + 1.0, rows / 2, 0) : p(cols / 2, rows + 1.0, 0);
    final to = right ? p(cols + 0.1, rows / 2, 0) : p(cols / 2, rows + 0.1, 0);
    _arrow(canvas, from, to);
    _text(
      canvas,
      right
          ? (german ? 'Blick von rechts' : 'View from the right')
          : (german ? 'Blick von vorne' : 'View from the front'),
      Offset(size.width / 2, size.height - font),
    );
  }

  void _clock(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - font;
    if (radius <= 0) return;
    canvas.drawCircle(center, radius, pen..strokeWidth = 2);
    for (var n = 1; n <= 12; n++) {
      final angle = n * math.pi / 6 - math.pi / 2;
      _text(
        canvas,
        '$n',
        center + Offset(math.cos(angle), math.sin(angle)) * radius * 0.81,
      );
    }
    for (var tick = 0; tick < 60; tick++) {
      final angle = tick * math.pi / 30 - math.pi / 2;
      final vector = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        center + vector * radius * 0.93,
        center + vector * radius,
        pen,
      );
    }
    final hour = _number(data['hour']) % 12;
    final minute = _number(data['minute']) % 60;
    final hourAngle = (hour + minute / 60) * math.pi / 6 - math.pi / 2;
    final minuteAngle = minute * math.pi / 30 - math.pi / 2;
    canvas.drawLine(
      center,
      center + Offset(math.cos(hourAngle), math.sin(hourAngle)) * radius * 0.5,
      pen..strokeWidth = 6,
    );
    canvas.drawLine(
      center,
      center +
          Offset(math.cos(minuteAngle), math.sin(minuteAngle)) * radius * 0.7,
      pen
        ..color = accent
        ..strokeWidth = 3,
    );
    canvas.drawCircle(center, 5, Paint()..color = ink);
  }

  void _spinner(Canvas canvas, Size size) {
    final sectors = _list(data['sectors']).map(_map).toList();
    final total = sectors.fold<double>(
      0,
      (sum, s) => sum + math.max(0, _number(s['weight'], 1)),
    );
    if (total <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 20;
    var angle = -math.pi / 2;
    for (var i = 0; i < sectors.length; i++) {
      final sector = sectors[i];
      final sweep =
          math.max(0, _number(sector['weight'], 1)) / total * 2 * math.pi;
      if (sweep <= 0) continue;
      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawArc(
        rect,
        angle,
        sweep,
        true,
        Paint()..color = accent.withValues(alpha: 0.2 + (i % 3) * 0.2),
      );
      canvas.drawArc(rect, angle, sweep, true, pen);
      final middle = angle + sweep / 2;
      _text(
        canvas,
        figureText(sector['label'], german),
        center + Offset(math.cos(middle), math.sin(middle)) * radius * 0.62,
        maxWidth: radius * 0.8,
      );
      angle += sweep;
    }
    _arrow(canvas, center, center + Offset(radius * 0.5, -radius * 0.22));
  }

  void _polygon(Canvas canvas, Size size) {
    final points = _list(data['points'])
        .where((p) => _list(p).length == 2)
        .map((p) => Offset(_number(_list(p)[0]), _number(_list(p)[1])))
        .toList();
    if (points.length < 2) return;
    final minX = points.map((p) => p.dx).reduce(math.min);
    final maxX = points.map((p) => p.dx).reduce(math.max);
    final minY = points.map((p) => p.dy).reduce(math.min);
    final maxY = points.map((p) => p.dy).reduce(math.max);
    final margin = font * 2;
    final unit = math.min(
      (size.width - margin * 2) / math.max(1, maxX - minX),
      (size.height - margin * 2) / math.max(1, maxY - minY),
    );
    final origin = Offset(
      (size.width - (maxX - minX) * unit) / 2,
      (size.height - (maxY - minY) * unit) / 2,
    );
    final plotted = points
        .map((p) => origin + Offset((p.dx - minX) * unit, (p.dy - minY) * unit))
        .toList();
    final path = Path()..addPolygon(plotted, true);
    canvas.drawPath(path, Paint()..color = accent.withValues(alpha: 0.2));
    canvas.drawPath(path, pen..strokeWidth = 2);
    final bounds = Rect.fromLTWH(
      origin.dx,
      origin.dy,
      (maxX - minX) * unit,
      (maxY - minY) * unit,
    );
    for (final axis in _list(data['axes'])) {
      final endpoints = switch (axis) {
        'vertical' => (bounds.topCenter, bounds.bottomCenter),
        'horizontal' => (bounds.centerLeft, bounds.centerRight),
        'diagonalDown' => (bounds.topLeft, bounds.bottomRight),
        'diagonalUp' => (bounds.bottomLeft, bounds.topRight),
        _ => null,
      };
      if (endpoints != null) {
        _dashed(
            canvas,
            endpoints.$1,
            endpoints.$2,
            pen
              ..color = ink
              ..strokeWidth = 2.5);
      }
    }
    final labels = _list(data['labels']);
    for (var i = 0; i < math.min(labels.length, plotted.length); i++) {
      _text(
        canvas,
        figureText(labels[i], german),
        plotted[i] + Offset(0, -font),
      );
    }
  }

  void _arrow(Canvas canvas, Offset from, Offset to) {
    canvas.drawLine(from, to, pen..strokeWidth = 2.5);
    final angle = math.atan2(to.dy - from.dy, to.dx - from.dx);
    for (final offset in [-0.5, 0.5]) {
      canvas.drawLine(
        to,
        to - Offset(math.cos(angle + offset), math.sin(angle + offset)) * 10,
        pen..strokeWidth = 2.5,
      );
    }
  }

  void _dashed(Canvas canvas, Offset from, Offset to, Paint paint) {
    final length = (to - from).distance;
    if (length == 0) return;
    final direction = (to - from) / length;
    for (var at = 0.0; at < length; at += 12) {
      canvas.drawLine(
        from + direction * at,
        from + direction * math.min(at + 7, length),
        paint,
      );
    }
  }

  String _format(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1).replaceAll('.', german ? ',' : '.');

  @override
  bool shouldRepaint(covariant _FigurePainter oldDelegate) =>
      kind != oldDelegate.kind ||
      data != oldDelegate.data ||
      german != oldDelegate.german ||
      ink != oldDelegate.ink ||
      accent != oldDelegate.accent ||
      scale != oldDelegate.scale;
}
