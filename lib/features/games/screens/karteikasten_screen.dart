// lib/features/games/screens/karteikasten_screen.dart
//
// Karteikasten-style flashcard view of the SRI database. Five boxes
// (New → Mastered) projected from the SM-2 state. Players see which
// math problems are in each box and can manually move them between
// boxes via a per-item ⋮ menu or by long-pressing and dragging an item
// card onto a target box card.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/services/sri_service.dart';
import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../providers/game_provider.dart';

class KarteikastenScreen extends StatefulWidget {
  const KarteikastenScreen({super.key});

  @override
  State<KarteikastenScreen> createState() => _KarteikastenScreenState();
}

class _KarteikastenScreenState extends State<KarteikastenScreen> {
  int _selectedBox = 1;

  static const List<Color> _boxColors = [
    Color(0xFFE57373),
    Color(0xFFFFB74D),
    Color(0xFFFFD54F),
    Color(0xFF81C784),
    Color(0xFF64B5F6),
  ];

  List<String> _boxLabels(BuildContext context) {
    final s = S.of(context)!;
    return [s.flashcardBoxNew, s.flashcardBoxFirstReview, s.flashcardBoxPractice, s.flashcardBoxConfident, s.flashcardBoxMastered];
  }

  @override
  Widget build(BuildContext context) {
    final sri = context.watch<SriService>();
    final counts = sri.getBoxCounts();
    final itemsInSelected = sri.getItemsInBox(_selectedBox)
      ..sort((a, b) => b.failureCount.compareTo(a.failureCount));

    return Scaffold(
      backgroundColor: SpaceTheme.deepSpace,
      appBar: AppBar(
        title: Text(S.of(context)!.flashcardBoxTitle),
        backgroundColor: SpaceTheme.deepSpace,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            _buildBoxRow(counts),
            const Divider(color: Colors.white24, height: 24),
            Expanded(
              child: itemsInSelected.isEmpty
                  ? _buildEmptyState()
                  : _buildItemList(sri, itemsInSelected),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoxRow(Map<int, int> counts) {
    return SizedBox(
      height: 130,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: 5,
        itemBuilder: (context, i) {
          final boxNum = i + 1;
          final boxColor = _boxColors[i];
          final boxLabel = _boxLabels(context)[i];
          final count = counts[boxNum] ?? 0;
          final selected = boxNum == _selectedBox;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: DragTarget<String>(
              onWillAcceptWithDetails: (_) => true,
              onAcceptWithDetails: (d) async {
                HapticFeedback.mediumImpact();
                await context
                    .read<SriService>()
                    .moveItemToBox(d.data, boxNum);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    duration: const Duration(seconds: 2),
                    content: Text(S.of(context)!.flashcardBoxMovedToBox(boxNum)),
                    backgroundColor: boxColor.withValues(alpha: 0.85),
                  ),
                );
              },
              builder: (context, candidate, _) {
                final hover = candidate.isNotEmpty;
                return GestureDetector(
                  onTap: () => setState(() => _selectedBox = boxNum),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 90,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          boxColor.withValues(alpha: hover ? 1.0 : 0.85),
                          boxColor.withValues(alpha: hover ? 0.85 : 0.55),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected ? Colors.white : Colors.white24,
                        width: selected ? 3 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: boxColor.withValues(alpha: 0.4),
                          blurRadius: hover ? 18 : 6,
                          offset: const Offset(2, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Box $boxNum',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          boxLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          _selectedBox == 5
              ? 'No mastered problems in this box yet.'
              : 'This box is empty.',
          textAlign: TextAlign.center,
          style: SpaceTheme.bodyStyle.copyWith(color: Colors.white60),
        ),
      ),
    );
  }

  Widget _buildItemList(SriService sri, List<SriProblemData> items) {
    final gp = context.read<GameProvider>();
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, i) {
        final item = items[i];
        return _DraggableItemCard(
          itemId: item.problemId,
          label: _formatProblem(item.problemId, gp),
          subtitle:
              'EF ${item.easinessFactor.toStringAsFixed(2)} · '
              '${item.successCount}✓ ${item.failureCount}✗',
          currentBox: _selectedBox,
          onMove: (target) => sri.moveItemToBox(item.problemId, target),
        );
      },
    );
  }

  String _formatProblem(String problemId, GameProvider gp) {
    // problemId format: TYPE_a_b (e.g. ADD_3_4, MUL_5_6).
    final parts = problemId.split('_');
    if (parts.length != 3) return problemId;
    final op = switch (parts[0]) {
      'ADD' => '+',
      'SUB' => '-',
      'MUL' => gp.multiplicationSymbol,
      'DIV' => gp.divisionSymbol,
      _ => '?',
    };
    return '${parts[1]} $op ${parts[2]}';
  }
}

class _DraggableItemCard extends StatelessWidget {
  final String itemId;
  final String label;
  final String subtitle;
  final int currentBox;
  final Future<void> Function(int targetBox) onMove;

  const _DraggableItemCard({
    required this.itemId,
    required this.label,
    required this.subtitle,
    required this.currentBox,
    required this.onMove,
  });

  @override
  Widget build(BuildContext context) {
    final card = _buildCardBody(context);
    return LongPressDraggable<String>(
      data: itemId,
      feedback: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: Opacity(opacity: 0.92, child: card),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: card),
      child: card,
    );
  }

  Widget _buildCardBody(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(1, 2)),
        ],
      ),
      child: ListTile(
        title: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF3E2723),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Color(0xFF5D4037), fontSize: 12),
        ),
        trailing: PopupMenuButton<int>(
          icon: const Icon(Icons.more_vert, color: Color(0xFF5D4037)),
          tooltip: S.of(context)!.flashcardBoxMove,
          onSelected: onMove,
          itemBuilder: (context) => [
            for (var b = 1; b <= 5; b++)
              PopupMenuItem<int>(
                value: b,
                enabled: b != currentBox,
                child: Row(
                  children: [
                    Text(
                      'Box $b',
                      style: TextStyle(
                        fontWeight: b == currentBox
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    if (b == currentBox)
                      const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Text('(current)',
                            style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
