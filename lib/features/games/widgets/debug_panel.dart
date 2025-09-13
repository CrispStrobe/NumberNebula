class DebugPanel extends StatefulWidget {
  final Function(Map<String, dynamic>) onSettingsChanged;
  
  const DebugPanel({super.key, required this.onSettingsChanged});

  @override
  State<DebugPanel> createState() => _DebugPanelState();
}

class _DebugPanelState extends State<DebugPanel> {
  Map<String, dynamic> settings = {
    'objectCount': 6,
    'numberRange': 50,
    'timeLimit': 60,
    'mathComplexity': 1,
    'gameSpeed': 100.0,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SpaceTheme.deepSpace.withOpacity(0.9),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Debug Settings', style: SpaceTheme.titleStyle),
          const SizedBox(height: 16),
          
          _buildSlider('Object Count', 'objectCount', 3, 15),
          _buildSlider('Number Range', 'numberRange', 10, 200),
          _buildSlider('Time Limit', 'timeLimit', 30, 180),
          _buildSlider('Math Complexity', 'mathComplexity', 1, 5),
          _buildSlider('Game Speed', 'gameSpeed', 50, 300),
          
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              widget.onSettingsChanged(settings);
              Navigator.of(context).pop();
            },
            child: const Text('Apply Settings'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSlider(String label, String key, double min, double max) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${settings[key].toString()}'),
        Slider(
          value: settings[key].toDouble(),
          min: min,
          max: max,
          divisions: (max - min).toInt(),
          onChanged: (value) {
            setState(() {
              settings[key] = key == 'gameSpeed' ? value : value.toInt();
            });
          },
        ),
      ],
    );
  }
}