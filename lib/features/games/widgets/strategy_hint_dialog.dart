import 'package:flutter/material.dart';
import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';

/// A hint starts with a clue and reveals a worked move only on request.
class StrategyHintDialog extends StatefulWidget {
  final String focus;
  final String strategy;
  final String working;
  final VoidCallback? demonstrate;
  const StrategyHintDialog(
      {super.key,
      required this.focus,
      required this.strategy,
      required this.working,
      this.demonstrate});

  static Future<void> show(BuildContext context,
          {required String focus,
          required String strategy,
          required String working,
          VoidCallback? demonstrate}) =>
      showDialog<void>(
          context: context,
          builder: (_) => StrategyHintDialog(
              focus: focus,
              strategy: strategy,
              working: working,
              demonstrate: demonstrate));

  @override
  State<StrategyHintDialog> createState() => _StrategyHintDialogState();
}

class _StrategyHintDialogState extends State<StrategyHintDialog> {
  int _step = 0;
  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    return AlertDialog(
      backgroundColor: SpaceTheme.deepSpace,
      title: Text([s.hintFocus, s.hintStrategy, s.hintWorkedMove][_step]),
      content: SingleChildScrollView(
          child: Text([widget.focus, widget.strategy, widget.working][_step],
              style: SpaceTheme.bodyStyle)),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(s.hintTryMyself)),
        if (_step < 2)
          ElevatedButton(
              onPressed: () => setState(() => _step++),
              child: Text(s.onboardingNext))
        else if (widget.demonstrate != null)
          ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.demonstrate!();
              },
              child: Text(s.hintPlaceMove)),
      ],
    );
  }
}
