import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../generated/l10n.dart';

/// A tap/keyboard grid for missing mirror cells, rotated shapes and cube nets.
/// Given cells are fixed. [selected] and [onChanged] contain additions only.
/// Cell IDs are zero-based `row,column`; spoken coordinates start at one.
class KompassCellInput extends StatelessWidget {
  final Map<String, dynamic> figure;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final bool german;
  final bool enabled;

  const KompassCellInput({
    super.key,
    required this.figure,
    required this.selected,
    required this.onChanged,
    required this.german,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final strings = lookupS(Locale(german ? 'de' : 'en'));
    final raw = figure['data'];
    final data = raw is Map ? raw : const <String, dynamic>{};
    final givenRaw = data['cells'] ?? data['filled'];
    final given = givenRaw is List
        ? givenRaw.map((c) => c.toString()).toSet()
        : <String>{};
    final occupied = <(int, int)>[];
    for (final id in {...given, ...selected}) {
      final parts = id.split(',');
      if (parts.length != 2) continue;
      final row = int.tryParse(parts[0]), col = int.tryParse(parts[1]);
      if (row != null && col != null && row >= 0 && col >= 0) {
        occupied.add((row, col));
      }
    }
    final rows = data['rows'] is num
        ? (data['rows'] as num).toInt().clamp(1, 20)
        : occupied.fold<int>(3, (n, c) => math.max(n, c.$1 + 2)).clamp(1, 20);
    final cols = data['cols'] is num
        ? (data['cols'] as num).toInt().clamp(1, 20)
        : occupied.fold<int>(3, (n, c) => math.max(n, c.$2 + 2)).clamp(1, 20);
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final cell = math.max(52.0, 32 * scale);
    final axis = data['axis'] is Map ? data['axis'] as Map : null;
    final hasAxis = figure['kind'] == 'mirror' && axis != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(strings.kompassGridInstructions),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: CustomPaint(
            foregroundPainter: hasAxis
                ? _CellAxisPainter(
                    vertical: axis['direction'] != 'horizontal',
                    at: (axis['at'] as num? ?? 0).toDouble(),
                    cell: cell,
                    color: Theme.of(context).colorScheme.onSurface,
                  )
                : null,
            child: SizedBox(
              width: cols * cell,
              child: Column(
                children: [
                  for (var row = 0; row < rows; row++)
                    Row(
                      children: [
                        for (var col = 0; col < cols; col++)
                          _cell(context, row, col, cell, given),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _cell(
    BuildContext context,
    int row,
    int col,
    double side,
    Set<String> given,
  ) {
    final id = '$row,$col';
    final fixed = given.contains(id);
    final marked = selected.contains(id);
    final state = fixed
        ? (german ? 'vorgegeben' : 'given')
        : marked
            ? (german ? 'markiert' : 'selected')
            : (german ? 'leer' : 'empty');
    final label = german
        ? 'Zeile ${row + 1}, Spalte ${col + 1}, $state'
        : 'Row ${row + 1}, column ${col + 1}, $state';
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: side,
      height: side,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Semantics(
          label: label,
          selected: marked,
          child: OutlinedButton(
            key: ValueKey('kompass_cell_$id'),
            onPressed: !enabled || fixed
                ? null
                : () {
                    final next = Set<String>.of(selected)..removeAll(given);
                    if (!next.add(id)) next.remove(id);
                    onChanged(next);
                  },
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(48, 48),
              foregroundColor: colors.onSurface,
              disabledForegroundColor: colors.onSurface,
              backgroundColor: fixed || marked
                  ? colors.primary.withValues(alpha: fixed ? 0.3 : 0.15)
                  : Colors.transparent,
              side: BorderSide(color: colors.onSurface.withValues(alpha: 0.6)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            child: fixed
                ? const Icon(Icons.square, size: 22)
                : marked
                    ? const Icon(Icons.check, size: 26)
                    : Text(
                        '${row + 1},${col + 1}',
                        style: const TextStyle(fontSize: 11),
                      ),
          ),
        ),
      ),
    );
  }
}

class _CellAxisPainter extends CustomPainter {
  final bool vertical;
  final double at, cell;
  final Color color;
  const _CellAxisPainter({
    required this.vertical,
    required this.at,
    required this.cell,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final length = vertical ? size.height : size.width;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3;
    for (var offset = 0.0; offset < length; offset += 12) {
      canvas.drawLine(
        vertical ? Offset(at * cell, offset) : Offset(offset, at * cell),
        vertical
            ? Offset(at * cell, math.min(offset + 7, length))
            : Offset(math.min(offset + 7, length), at * cell),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CellAxisPainter oldDelegate) =>
      vertical != oldDelegate.vertical ||
      at != oldDelegate.at ||
      cell != oldDelegate.cell ||
      color != oldDelegate.color;
}
