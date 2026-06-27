// lib/features/games/screens/parent_dashboard_screen.dart
//
// A grown-up summary of the player's progress. Aggregates GameProvider
// progress, CognitiveProfileService stats, and SriService mastery into
// one screen. PIN-gated (4 digits) — the gate is a friction point to
// keep the kid out of the parent view, not a security boundary.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models/skill_category.dart';
import '../../../core/services/cognitive_profile_service.dart';
import '../../../core/services/sri_service.dart';
import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../providers/game_provider.dart';

const _kParentPinKey = 'parent_pin';
const _kDefaultParentPin = '1234'; // Documented default; parents can change.

class ParentDashboardScreen extends StatefulWidget {
  const ParentDashboardScreen({super.key});

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
  bool _unlocked = false;
  String? _storedPin;
  final TextEditingController _pinController = TextEditingController();
  String? _pinError;

  @override
  void initState() {
    super.initState();
    _loadPin();
  }

  Future<void> _loadPin() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _storedPin = prefs.getString(_kParentPinKey) ?? _kDefaultParentPin;
    });
  }

  void _submitPin() {
    if (_pinController.text == _storedPin) {
      setState(() {
        _unlocked = true;
        _pinError = null;
      });
    } else {
      setState(() {
        _pinError = 'Falscher Code';
      });
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpaceTheme.deepSpace,
      appBar: AppBar(
        title: Text(S.of(context)!.parentDashboardTitle),
        backgroundColor: SpaceTheme.deepSpace,
      ),
      body: _unlocked ? _buildDashboard(context) : _buildLockScreen(),
    );
  }

  Widget _buildLockScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock, size: 64, color: SpaceTheme.starYellow),
            const SizedBox(height: 16),
            Text(S.of(context)!.parentDashboardPinTitle, style: SpaceTheme.headlineStyle),
            const SizedBox(height: 8),
            Text(
              S.of(context)!.parentDashboardPinDesc(_kDefaultParentPin.toString()),
              textAlign: TextAlign.center,
              style: SpaceTheme.bodyStyle
                  .copyWith(fontSize: 13, color: Colors.white60),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 160,
              child: TextField(
                controller: _pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: Colors.white, letterSpacing: 8),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: InputDecoration(
                  counterText: '',
                  errorText: _pinError,
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: SpaceTheme.starYellow),
                  ),
                ),
                onSubmitted: (_) => _submitPin(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _submitPin,
              child: Text(S.of(context)!.parentDashboardUnlock),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard(BuildContext context) {
    final gp = context.watch<GameProvider>();
    final cp = context.watch<CognitiveProfileService>();
    final sri = context.watch<SriService>();

    final progress = gp.gameProgress;
    final activeGames = progress.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final snapshot = cp.snapshot;
    // Find strongest / weakest skill by overall success ratio (min 5 attempts).
    SkillCategory? strongest;
    SkillCategory? weakest;
    double bestRatio = -1;
    double worstRatio = 2;
    snapshot.forEach((skill, diffMap) {
      final attempts =
          diffMap.values.fold<int>(0, (s, v) => s + v.attempts);
      if (attempts < 5) return;
      final successes =
          diffMap.values.fold<int>(0, (s, v) => s + v.successes);
      final ratio = successes / attempts;
      if (ratio > bestRatio) {
        bestRatio = ratio;
        strongest = skill;
      }
      if (ratio < worstRatio) {
        worstRatio = ratio;
        weakest = skill;
      }
    });

    final sriTotal = sri.totalTrackedProblems;
    final sriMastered = sri.masteredProblemCount;
    final sriDue = sri.getAvailableReviewCount();
    final masteryPct =
        sriTotal > 0 ? (sriMastered / sriTotal * 100).round() : 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Section(
          title: S.of(context)!.parentDashboardMathMastery,
          children: [
            _StatLine(
                label: S.of(context)!.parentDashboardProblemsTracked,
                value: sriTotal.toString()),
            _StatLine(
                label: S.of(context)!.parentDashboardMastered,
                value: '$sriMastered ($masteryPct%)'),
            _StatLine(
                label: S.of(context)!.parentDashboardDueForReview,
                value: sriDue.toString()),
          ],
        ),
        const SizedBox(height: 16),
        _Section(
          title: S.of(context)!.parentDashboardCognitiveStrengths,
          children: [
            if (cp.totalAttempts == 0)
              _StatLine(
                  label: S.of(context)!.parentDashboardDataBasis, value: S.of(context)!.parentDashboardNoData),
            if (strongest != null)
              _StatLine(
                label: S.of(context)!.parentDashboardStrongest,
                value: '${_skillLabel(strongest!)} '
                    '(${(bestRatio * 100).round()}%)',
              ),
            if (weakest != null && weakest != strongest)
              _StatLine(
                label: S.of(context)!.parentDashboardWeakest,
                value: '${_skillLabel(weakest!)} '
                    '(${(worstRatio * 100).round()}%)',
              ),
            _StatLine(
                label: S.of(context)!.parentDashboardTotalAttempts,
                value: cp.totalAttempts.toString()),
          ],
        ),
        const SizedBox(height: 16),
        _Section(
          title: S.of(context)!.parentDashboardGameProgress,
          children: activeGames.isEmpty
              ? [
                  _StatLine(
                      label: S.of(context)!.parentDashboardGamesPlayed, value: S.of(context)!.parentDashboardNone)
                ]
              : [
                  for (final entry in activeGames)
                    _StatLine(
                      label: _gameLabel(entry.key),
                      value: S.of(context)!.parentDashboardLevelN(entry.value),
                    ),
                ],
        ),
        const SizedBox(height: 24),
        TextButton.icon(
          onPressed: _changePin,
          icon: const Icon(Icons.lock_reset, color: Colors.white70),
          label: Text(S.of(context)!.parentDashboardChangePin,
              style: const TextStyle(color: Colors.white70)),
        ),
      ],
    );
  }

  Future<void> _changePin() async {
    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        String? err;
        return StatefulBuilder(
          builder: (context, setSt) => AlertDialog(
            backgroundColor: SpaceTheme.deepSpace,
            title: Text(S.of(context)!.parentDashboardChangePinTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: pinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(labelText: S.of(context)!.parentDashboardNewPin),
                ),
                TextField(
                  controller: confirmController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration:
                      InputDecoration(labelText: S.of(context)!.parentDashboardConfirm, errorText: err),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(S.of(context)!.parentDashboardCancel),
              ),
              TextButton(
                autofocus: true,
                onPressed: () {
                  if (pinController.text.length != 4) {
                    setSt(() => err = S.of(context)!.parentDashboardPin4Digits);
                    return;
                  }
                  if (pinController.text != confirmController.text) {
                    setSt(() => err = S.of(context)!.parentDashboardPinMismatch);
                    return;
                  }
                  Navigator.pop(context, pinController.text);
                },
                child: Text(S.of(context)!.parentDashboardSave),
              ),
            ],
          ),
        );
      },
    );
    if (result != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kParentPinKey, result);
      if (mounted) {
        setState(() => _storedPin = result);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context)!.parentDashboardPinUpdated)),
        );
      }
    }
  }

  String _skillLabel(SkillCategory s) {
    switch (s) {
      case SkillCategory.arithmetic:
        return 'Arithmetik';
      case SkillCategory.spatial2d:
        return 'Räumlich (2D)';
      case SkillCategory.spatial3d:
        return 'Räumlich (3D)';
      case SkillCategory.logicDeduction:
        return 'Logik';
      case SkillCategory.patternRecognition:
        return 'Mustererkennung';
    }
  }

  String _gameLabel(String key) {
    // Best-effort humanization. If you want full localized names,
    // pull them from S.of(context).
    return key
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) =>
            w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: SpaceTheme.nebulaPurple.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: SpaceTheme.titleStyle.copyWith(fontSize: 16)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _StatLine extends StatelessWidget {
  final String label;
  final String value;
  const _StatLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: SpaceTheme.bodyStyle
                  .copyWith(fontSize: 13, color: Colors.white70),
            ),
          ),
          Text(value,
              style: SpaceTheme.titleStyle
                  .copyWith(fontSize: 14, color: Colors.white)),
        ],
      ),
    );
  }
}
