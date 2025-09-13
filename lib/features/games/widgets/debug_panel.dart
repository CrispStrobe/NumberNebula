import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:space_math_academy/core/theme/space_theme.dart';
import 'package:space_math_academy/features/games/providers/game_provider.dart';

class DebugPanel extends StatefulWidget {
  final Function() onSettingsApplied;

  const DebugPanel({super.key, required this.onSettingsApplied});

  @override
  State<DebugPanel> createState() => _DebugPanelState();
}

class _DebugPanelState extends State<DebugPanel> {
  late int _grade;
  late int _level;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize with current values from the provider
    final gameProvider = context.read<GameProvider>();
    _grade = gameProvider.grade;
    _level = gameProvider.level;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: SpaceTheme.deepSpace.withOpacity(0.95),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: SpaceTheme.nebulaPurple, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Debug Difficulty', style: SpaceTheme.headlineStyle),
            const SizedBox(height: 24),
            
            // Grade Slider
            _buildSlider('Grade', _grade.toDouble(), 3, 6, (value) {
              setState(() => _grade = value.toInt());
            }),
            
            // Level Slider
            _buildSlider('Level', _level.toDouble(), 1, 10, (value) {
              setState(() => _level = value.toInt());
            }),
            
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.check),
              onPressed: () {
                context.read<GameProvider>().setDifficulty(_grade, _level);
                widget.onSettingsApplied();
                Navigator.of(context).pop();
              },
              style: SpaceTheme.primaryButtonStyle,
              label: const Text('Apply & Close'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlider(String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${value.toInt()}', style: SpaceTheme.bodyStyle.copyWith(color: SpaceTheme.starYellow)),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: (max - min).toInt(),
          label: value.toInt().toString(),
          onChanged: onChanged,
          activeColor: SpaceTheme.alienGreen,
          inactiveColor: SpaceTheme.nebulaPurple,
        ),
      ],
    );
  }
}
