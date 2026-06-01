# Visual & Interaction Template for Game Screens

> MANDATORY patterns for all game screens. Extracted from the best existing games
> (kenken_game, arithmatic_square_game, blocks_counter_game, perspective_puzzle_game).
> Every new/fixed game MUST follow these patterns.

---

## A. DRAG-AND-DROP (mandatory for placement games)

### Draggable Item (in number tray / piece tray)
```dart
Draggable<int>(
  data: number,
  feedback: Material(
    color: Colors.transparent,
    child: Container(
      width: 60, height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: SpaceTheme.starGradient,
        boxShadow: [BoxShadow(
          color: SpaceTheme.starYellow.withValues(alpha: 0.8),
          blurRadius: 20, spreadRadius: 5,
        )],
      ),
      child: Center(child: Text(number.toString(),
        style: SpaceTheme.headlineStyle.copyWith(fontSize: 22))),
    ),
  ),
  childWhenDragging: Opacity(opacity: 0.3, child: _buildTile(number)),
  child: _buildTile(number),
)
```

### Drop Target (grid cell)
```dart
DragTarget<int>(
  builder: (context, candidateData, rejectedData) {
    final isHovering = candidateData.isNotEmpty;
    return Container(
      width: cellSize, height: cellSize,
      decoration: BoxDecoration(
        gradient: isHovering
            ? const LinearGradient(colors: [SpaceTheme.starYellow, SpaceTheme.planetOrange])
            : const LinearGradient(colors: [SpaceTheme.deepSpace, SpaceTheme.nebulaPurple]),
        border: Border.all(
          color: isHovering ? SpaceTheme.starYellow : SpaceTheme.nebulaPurple,
          width: isHovering ? 3 : 2,
        ),
        boxShadow: isHovering ? [BoxShadow(
          color: SpaceTheme.starYellow.withValues(alpha: 0.6),
          blurRadius: 8, spreadRadius: 2,
        )] : null,
      ),
      child: isHovering ? null : _pulsingPlusIcon(cellSize),
    );
  },
  onWillAcceptWithDetails: (details) => true,
  onAcceptWithDetails: (details) => _placeItem(details.data, cellId),
)
```

### Undo (tap placed item to remove)
```dart
GestureDetector(
  onTap: () => _removeItem(cellId),
  child: Container(/* show placed value with remove hint */),
)
```

---

## B. RESPONSIVE GRID SIZING (mandatory for ALL grid games)

### Formula
```
cellSize = min(maxCellSize, min(availableWidth / cols, availableHeight / rows))
```

### LayoutBuilder Pattern
```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    body: SpaceBackground(
      child: SafeArea(
        child: Column(
          children: [
            GameUI(title: s.gameTitle, level: widget.level,
                   onBack: () => Navigator.of(context).pop()),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 700;
                  final isCompact = constraints.maxHeight < 500;
                  return isWide
                      ? _buildWideLayout(constraints)
                      : _buildCompactLayout(constraints);
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
```

### Wide Layout (landscape/tablet)
```dart
Widget _buildWideLayout(BoxConstraints constraints) {
  return Row(
    children: [
      Expanded(flex: 3, child: Center(child: _buildGrid(constraints))),
      const SizedBox(width: 24),
      Expanded(flex: 2, child: _buildItemTray()),
    ],
  );
}
```

### Compact Layout (portrait/phone)
```dart
Widget _buildCompactLayout(BoxConstraints constraints) {
  return Column(
    children: [
      Expanded(flex: 3, child: Center(child: _buildGrid(constraints))),
      const SizedBox(height: 8),
      Expanded(flex: 2, child: _buildItemTray()),
    ],
  );
}
```

### Grid Sizing Inside LayoutBuilder
```dart
Widget _buildGrid(BoxConstraints outerConstraints) {
  return LayoutBuilder(builder: (context, constraints) {
    final maxCellW = (constraints.maxWidth - 32) / cols;
    final maxCellH = (constraints.maxHeight - 32) / rows;
    final cellSize = min(maxCellW, maxCellH).clamp(30.0, 80.0);
    // ... build grid with cellSize
  });
}
```

---

## C. ANIMATIONS (mandatory minimum set)

### Required Controllers
```dart
// 1. Glow (continuous, for borders/accents)
_glowController = AnimationController(duration: Duration(milliseconds: 2000), vsync: this)
  ..repeat(reverse: true);
_glowAnimation = Tween<double>(begin: 0.5, end: 1.0)
    .animate(CurvedAnimation(parent: _glowController, curve: Curves.easeInOut));

// 2. Drop success (one-shot, on placement)
_dropController = AnimationController(duration: Duration(milliseconds: 500), vsync: this);
_dropAnimation = CurvedAnimation(parent: _dropController, curve: Curves.elasticOut);

// 3. Pulse (continuous, for empty cells)
_pulseController = AnimationController(duration: Duration(milliseconds: 1000), vsync: this)
  ..repeat(reverse: true);
_pulseAnimation = Tween<double>(begin: 0.8, end: 1.0)
    .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

// 4. Success dialog (one-shot)
_successController = AnimationController(duration: Duration(milliseconds: 600), vsync: this);
_successAnimation = CurvedAnimation(parent: _successController, curve: Curves.elasticOut);
```

### Apply Drop Animation
```dart
void _placeItem(int value, String cellId) {
  setState(() {
    _lastDroppedCell = cellId;
    _dropController.forward(from: 0.0);
  });
}

// In cell builder:
if (cellId == _lastDroppedCell) {
  cellWidget = ScaleTransition(scale: _dropAnimation, child: cellWidget);
}
```

### Apply Pulse on Empty Cells
```dart
AnimatedBuilder(
  animation: _pulseAnimation,
  builder: (context, child) => Transform.scale(
    scale: _pulseAnimation.value,
    child: Icon(Icons.add, color: SpaceTheme.nebulaPurple, size: cellSize * 0.3),
  ),
)
```

---

## D. ITEM TRAY (number pool / piece pool)

### Horizontal Scrollable Tray
```dart
SizedBox(
  height: 80,
  child: ListView.builder(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 8),
    itemCount: pool.length,
    itemBuilder: (context, index) {
      final item = pool[index];
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Draggable<int>(
          data: item,
          feedback: _buildFeedback(item),
          childWhenDragging: Opacity(opacity: 0.3, child: _buildTile(item)),
          child: _buildTile(item),
        ),
      );
    },
  ),
)
```

### Grid Tray (for more items)
```dart
GridView.builder(
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: isCompact ? 5 : 4,
    crossAxisSpacing: 8,
    mainAxisSpacing: 8,
  ),
  itemCount: pool.length,
  itemBuilder: (context, index) => Draggable<int>(...),
)
```

---

## E. SLIDER CONTROLS (for games with numeric input)

### Range Slider
```dart
Container(
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: SpaceTheme.deepSpace.withValues(alpha: 0.6),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: SpaceTheme.nebulaPurple.withValues(alpha: 0.5)),
  ),
  child: Column(
    children: [
      Text('VALUE: $currentValue', style: SpaceTheme.headlineStyle.copyWith(fontSize: 20)),
      Slider(
        value: currentValue.toDouble(),
        min: minVal, max: maxVal,
        divisions: (maxVal - minVal).toInt(),
        activeColor: SpaceTheme.starYellow,
        inactiveColor: SpaceTheme.nebulaPurple.withValues(alpha: 0.5),
        label: currentValue.toString(),
        onChanged: (v) => setState(() => currentValue = v.round()),
      ),
    ],
  ),
)
```

---

## F. COMMON MISTAKES TO AVOID

1. **Never hardcode pixel sizes for main game content.** Use LayoutBuilder + formula.
2. **Never use TextField for number input when a slider or drag-drop would work.**
3. **Never let content overflow.** Use Expanded, Flexible, LayoutBuilder.
4. **Never omit hover feedback on DragTarget.** The glow-on-hover is critical UX.
5. **Never skip undo.** Every placement must be reversible by tapping.
6. **Never use a plain Container when AnimatedContainer or AnimatedBuilder is available.**
7. **Always dispose ALL animation controllers.**
8. **Always use SpaceTheme colors, never raw Colors.blue etc.**
