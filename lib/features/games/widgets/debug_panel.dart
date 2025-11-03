import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:space_math_academy/core/models/skill_category.dart'; // <-- IMPORTED
import 'package:space_math_academy/core/services/debug_provider.dart';
import 'package:space_math_academy/core/theme/space_theme.dart';
import 'package:space_math_academy/features/games/providers/game_provider.dart';
import 'package:space_math_academy/generated/l10n.dart';

class DebugPanel extends StatefulWidget {
  const DebugPanel({super.key});

  @override
  State<DebugPanel> createState() => _DebugPanelState();
}

class _DebugPanelState extends State<DebugPanel> {
  late int _grade;
  late int _level;
  
  // --- NEW STATE VARIABLES ---
  Set<String> _selectedGameKeys = {};
  bool _selectAll = false;
  // --- END NEW STATE ---

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final gameProvider = context.read<GameProvider>();
    _grade = gameProvider.grade;
    _level = gameProvider.level;
  }

  @override
  Widget build(BuildContext context) {
    final debugProvider = context.watch<DebugProvider>();
    final s = S.of(context)!;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: SpaceTheme.deepSpace.withOpacity(0.95),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: SpaceTheme.nebulaPurple, width: 2),
        ),
        child: SingleChildScrollView( // ensures dialog can scroll if content is tall
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(s.debugPanelTitle, style: SpaceTheme.headlineStyle),
              const SizedBox(height: 24),
              _buildSwitch(s.debugForceUnlock, debugProvider.isPaidUnlockedForced, (value) {
                context.read<DebugProvider>().setPaidUnlock(value);
              }),
              const Divider(color: SpaceTheme.nebulaPurple, height: 32),
              _buildSlider('Skill Level', _grade.toDouble(), 1, 4, (value) {
                setState(() => _grade = value.toInt());
              }),
              _buildSlider('Game Level', _level.toDouble(), 1, 20, (value) {
                setState(() => _level = value.toInt());
              }),

              // --- NEW GAME SELECTOR UI ---
              const Divider(color: SpaceTheme.nebulaPurple, height: 32),
              Text(
                "Force Level for Selected Games:", 
                style: SpaceTheme.bodyStyle.copyWith(color: SpaceTheme.starYellow)
              ),
              _buildSelectAllToggle(),
              _buildGameCheckboxList(),
              // --- END NEW UI ---

              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.check),
                onPressed: () {
                  final gameProvider = context.read<GameProvider>();
                  
                  // Set the global grade and level (still useful)
                  gameProvider.setDifficulty(_grade, _level);
                  
                  // --- UPDATED LOGIC ---
                  // Force-set progress only for the selected games
                  gameProvider.debugSetGameLevels(_level, _selectedGameKeys.toList());

                  Navigator.of(context).pop();
                },
                style: SpaceTheme.primaryButtonStyle,
                label: Text(s.debugApplyAndClose),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- NEW HELPER WIDGET ---
  Widget _buildSelectAllToggle() {
    return CheckboxListTile(
      title: Text("Select All Games", style: SpaceTheme.bodyStyle.copyWith(fontStyle: FontStyle.italic)),
      value: _selectAll,
      onChanged: (bool? value) {
        setState(() {
          _selectAll = value ?? false;
          if (_selectAll) {
            // Add all keys from the map to the set
            _selectedGameKeys = gameSkillMap.keys.toSet();
          } else {
            // Clear the set
            _selectedGameKeys.clear();
          }
        });
      },
      controlAffinity: ListTileControlAffinity.leading,
      activeColor: SpaceTheme.alienGreen,
      checkColor: SpaceTheme.deepSpace,
      dense: true,
    );
  }

  // --- NEW HELPER WIDGET ---
  Widget _buildGameCheckboxList() {
    // Get all game keys and sort them for a clean list
    final allGameKeys = gameSkillMap.keys.toList()..sort();

    return Container(
      height: 200, // Fixed height for the scrollable area
      width: double.maxFinite,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SpaceTheme.nebulaPurple.withOpacity(0.5)),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: allGameKeys.length,
        itemBuilder: (context, index) {
          final gameKey = allGameKeys[index];
          return CheckboxListTile(
            title: Text(gameKey, style: SpaceTheme.bodyStyle.copyWith(fontSize: 12)),
            value: _selectedGameKeys.contains(gameKey),
            onChanged: (bool? value) {
              setState(() {
                if (value == true) {
                  _selectedGameKeys.add(gameKey);
                } else {
                  _selectedGameKeys.remove(gameKey);
                }
                // Uncheck "Select All" if we manually uncheck one
                if (_selectedGameKeys.length < allGameKeys.length) {
                  _selectAll = false;
                }
                // Check "Select All" if we just checked the last one
                if (_selectedGameKeys.length == allGameKeys.length) {
                  _selectAll = true;
                }
              });
            },
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: SpaceTheme.alienGreen,
            checkColor: SpaceTheme.deepSpace,
          );
        },
      ),
    );
  }

  Widget _buildSwitch(String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: SpaceTheme.bodyStyle.copyWith(color: SpaceTheme.starYellow)),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: SpaceTheme.alienGreen,
        ),
      ],
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