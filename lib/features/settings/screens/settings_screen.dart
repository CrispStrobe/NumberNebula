import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;

import '../widgets/sri_statistics_dialog.dart'; // statistics dialog widget

import '../../../core/theme/space_theme.dart';
import '../../../core/services/debug_provider.dart';
import '../../../core/services/progress_service.dart';

import '../../../generated/l10n.dart';

import '../../games/constants/app_constants.dart';
import '../../games/providers/game_provider.dart';
import '../../games/widgets/space_background.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with TickerProviderStateMixin {
  
  late AnimationController _slideController;
  late List<Animation<Offset>> _settingAnimations;
  String currentLocale = 'en'; // Safe default - NO CONTEXT ACCESS
  bool _isLoading = false;
  bool _hasLoadedLocale = false; // Track if we've loaded the locale yet
  
  @override
  void initState() {
    super.initState();
    debugPrint("[SETTINGS] 🔧 initState() starting...");
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _settingAnimations = List.generate(7, (index) { // how many settings do we have => how large the card...
      return Tween<Offset>(
        begin: const Offset(-1.0, 0.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _slideController,
        curve: Interval(
          (index * 0.1).clamp(0.0, 0.5),
          (0.4 + (index * 0.1)).clamp(0.1, 1.0),
          curve: Curves.easeOutCubic,
        ),
      ));
    });
    
    // CRITICAL: Do NOT access context here - wait for didChangeDependencies
    debugPrint("[SETTINGS] 🔧 initState() completed - animations ready");
    _slideController.forward();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    debugPrint("[SETTINGS] 🌍 didChangeDependencies() called");
    
    // NOW we can safely access Localizations and load settings
    if (!_hasLoadedLocale) {
      _loadCurrentLocaleAndSettings();
      _hasLoadedLocale = true;
    }
  }
  
  @override
  void dispose() {
    debugPrint("[SETTINGS] 🗑️ Disposing settings screen");
    _slideController.dispose();
    super.dispose();
  }

  void _loadCurrentLocaleAndSettings() async {
    debugPrint("[SETTINGS] 📱 Loading current locale and settings...");
    
    try {
      // Get current locale from context (now safe)
      final contextLocale = Localizations.localeOf(context).languageCode;
      debugPrint("[SETTINGS] 🌍 Context locale: $contextLocale");
      
      // Load saved locale from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final savedLocale = prefs.getString('language');
      debugPrint("[SETTINGS] 💾 Saved locale from SharedPreferences: $savedLocale");
      
      setState(() {
        // Use saved locale if available, otherwise use context locale
        currentLocale = savedLocale ?? contextLocale;
      });
      
      debugPrint("[SETTINGS] ✅ Final locale set to: $currentLocale");
      
      // Load other settings
      await _loadAllSettings();
      
    } catch (e, stackTrace) {
      debugPrint("[SETTINGS] ❌ Error loading locale/settings: $e");
      debugPrint("[SETTINGS] 📚 Stack trace: $stackTrace");
      // Fallback to English if there's any issue
      setState(() {
        currentLocale = 'en';
      });
    }
  }
  
  Future<void> _loadAllSettings() async {
    debugPrint("[SETTINGS] 📚 Loading all application settings...");
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Log all current preference keys
      final keys = prefs.getKeys();
      debugPrint("[SETTINGS] 🔑 Found ${keys.length} preference keys: $keys");
      
      // Load each setting with logging
      final soundEnabled = prefs.getBool('sound_enabled') ?? true;
      final musicEnabled = prefs.getBool('music_enabled') ?? true;
      final hintsEnabled = prefs.getBool('hints_enabled') ?? true;
      final hapticEnabled = prefs.getBool('haptic_enabled') ?? true;
      final puzzleTimerEnabled = prefs.getBool('puzzle_timer_enabled') ?? true;

      final useCustomSettings = prefs.getBool('use_custom_settings') ?? false;
      final customOps = prefs.getStringList('custom_math_ops')?.toSet() ?? {'addition', 'subtraction'};
      final customMin = prefs.getInt('custom_range_min') ?? 1;
      final customMax = prefs.getInt('custom_range_max') ?? 20;
      
      debugPrint("[SETTINGS] 🔊 Sound enabled: $soundEnabled");
      debugPrint("[SETTINGS] 🎵 Music enabled: $musicEnabled");
      debugPrint("[SETTINGS] 💡 Hints enabled: $hintsEnabled");
      debugPrint("[SETTINGS] 📳 Haptic enabled: $hapticEnabled");
      debugPrint("[SETTINGS] ⏱️ Puzzle timer enabled: $puzzleTimerEnabled");
      debugPrint("[SETTINGS] 🔧 Use Custom Settings: $useCustomSettings");
      debugPrint("[SETTINGS] 🔧 Custom Operations: $customOps");
      debugPrint("[SETTINGS] 🔧 Custom Range: $customMin - $customMax");
      
      // Apply settings to GameProvider if needed
      if (mounted) {
        final gameProvider = context.read<GameProvider>();
        gameProvider.setSoundEnabled(soundEnabled);
        gameProvider.setMusicEnabled(musicEnabled);
        gameProvider.setPuzzleTimer(puzzleTimerEnabled);

        gameProvider.setUseCustomSettings(useCustomSettings);
        gameProvider.setCustomOperations(customOps);
        gameProvider.setCustomRange(min: customMin, max: customMax);
        
        debugPrint("[SETTINGS] ✅ Applied settings to GameProvider");
      }
      
    } catch (e, stackTrace) {
      debugPrint("[SETTINGS] ❌ Error loading settings: $e");
      debugPrint("[SETTINGS] 📚 Stack trace: $stackTrace");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildAudioSettings(),
                      const SizedBox(height: 20),
                      _buildGameplaySettings(),
                      const SizedBox(height: 20),
                      _buildProblemCustomizationSettings(),
                      const SizedBox(height: 20),
                      _buildLanguageSettings(),
                      const SizedBox(height: 20),
                      _buildDifficultySettings(),
                      const SizedBox(height: 20),
                      _buildProgressSettings(),
                      const SizedBox(height: 20),
                      _buildAboutSection(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1E2235),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              debugPrint("[SETTINGS] 🔙 Back button pressed");
              Navigator.of(context).pop();
            },
            icon: const Icon(
              Icons.arrow_back_ios,
              color: Colors.white,
              size: 28,
            ),
            style: IconButton.styleFrom(
              backgroundColor: SpaceTheme.deepSpace.withOpacity(0.8),
              padding: const EdgeInsets.all(12),
            ),
          ),
          
          const SizedBox(width: 20),
          
          Expanded(
            child: Text(
              S.of(context)!.settings,
              style: SpaceTheme.headlineStyle.copyWith(fontSize: 32),
            ),
          ),
          
          const Icon(
            Icons.settings,
            color: SpaceTheme.starYellow,
            size: 32,
          ),
        ],
      ),
    );
  }
  
  Widget _buildAudioSettings() {
    return SlideTransition(
      position: _settingAnimations[0],
      child: _buildSettingsCard(
        title: S.of(context)!.audioSettings,
        icon: Icons.volume_up,
        children: [
          Consumer<GameProvider>(
            builder: (context, gameProvider, child) {
              return Column(
                children: [
                  _buildSwitchTile(
                    title: S.of(context)!.sound,
                    subtitle: S.of(context)!.soundEffects,
                    value: gameProvider.soundEnabled,
                    onChanged: (value) {
                      debugPrint("[SETTINGS] 🔊 Sound setting changed to: $value");
                      gameProvider.setSoundEnabled(value);
                      _saveSetting('sound_enabled', value);
                    },
                    icon: Icons.music_note,
                  ),
                  
                  _buildSwitchTile(
                    title: S.of(context)!.music,
                    subtitle: S.of(context)!.backgroundMusicDesc,
                    value: gameProvider.musicEnabled,
                    onChanged: (value) {
                      debugPrint("[SETTINGS] 🎵 Music setting changed to: $value");
                      gameProvider.setMusicEnabled(value);
                      _saveSetting('music_enabled', value);
                    },
                    icon: Icons.library_music,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildGameplaySettings() {
    return SlideTransition(
      position: _settingAnimations[1],
      child: _buildSettingsCard(
        title: S.of(context)!.gameplay,
        icon: Icons.games,
        children: [
          Consumer2<GameProvider, DebugProvider>(
            builder: (context, gameProvider, debugProvider, child) {
              final isUnlocked = gameProvider.isFullVersionUnlocked || debugProvider.isPaidUnlockedForced;
            
              return Column(
                children: [
                  // NEW: Add Adaptive Difficulty Toggle
                  _buildSwitchTile(
                    title: S.of(context)!.adaptiveDifficulty, 
                    subtitle: S.of(context)!.adjustProblems,
                    value: gameProvider.useAdaptiveDifficulty,
                    onChanged: (value) {
                      debugPrint("[SETTINGS] 🧠 Adaptive difficulty changed to: $value");
                      gameProvider.setUseAdaptiveDifficulty(value);
                      _saveSetting('use_adaptive_difficulty', value);
                    },
                    icon: Icons.auto_awesome,
                  ),
                  _buildSwitchTile(
                    title: S.of(context)!.puzzleTimer,
                    subtitle: S.of(context)!.puzzleTimerDesc,
                    value: gameProvider.puzzleTimerEnabled,
                    onChanged: (value) {
                      debugPrint("[SETTINGS] ⏱️ Puzzle timer setting changed to: $value");
                      gameProvider.setPuzzleTimer(value);
                      _saveSetting('puzzle_timer_enabled', value);
                    },
                    icon: Icons.timer,
                  ),
                  
                  _buildSwitchTile(
                    title: S.of(context)!.showHints,
                    subtitle: S.of(context)!.showHintsDesc,
                    value: true, // TODO: Add to GameProvider
                    onChanged: (value) {
                      debugPrint("[SETTINGS] 💡 Hints setting changed to: $value");
                      _saveSetting('hints_enabled', value);
                    },
                    icon: Icons.lightbulb,
                  ),
                  
                  _buildSwitchTile(
                    title: S.of(context)!.hapticFeedback,
                    subtitle: S.of(context)!.hapticFeedbackDesc,
                    value: true, // TODO: Add to GameProvider
                    onChanged: (value) {
                      debugPrint("[SETTINGS] 📳 Haptic feedback setting changed to: $value");
                      _saveSetting('haptic_enabled', value);
                    },
                    icon: Icons.vibration,
                  ),

                  const Divider(color: SpaceTheme.nebulaPurple, height: 24),
                    _buildFeatureRow(
                    title: S.of(context)!.sriStatisticsTitle,
                    subtitle: S.of(context)!.sriStatisticsDesc,
                    icon: Icons.bar_chart,
                    isLocked: !isUnlocked,
                    onTap: () {
                        if (isUnlocked) {
                        showDialog(
                            context: context,
                            builder: (context) => const SriStatisticsDialog(),
                        );
                        } else {
                        // Inform the user that this is a premium feature
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                            content: Text(S.of(context)!.premiumFeature),
                            backgroundColor: SpaceTheme.planetOrange,
                            ),
                        );
                        }
                    },
                    ),

                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // --- Method to build the problem customization card ---
  Widget _buildProblemCustomizationSettings() {
    return SlideTransition(
        position: _settingAnimations[2], // Adjust animation index if needed
        child: Consumer2<GameProvider, DebugProvider>( // CHANGED: Use Consumer2 to watch both providers
        builder: (context, gameProvider, debugProvider, child) {
            // FIX: Check both full version unlock AND debug forced unlock
            final isUnlocked = gameProvider.isFullVersionUnlocked || debugProvider.isPaidUnlockedForced;
            final bool isCustomEnabled = isUnlocked && gameProvider.useCustomProblemSettings;

            return _buildSettingsCard(
            title: S.of(context)!.problemCustomization,
            icon: Icons.calculate,
            children: [
                Text(
                S.of(context)!.problemCustomizationDesc,
                style: SpaceTheme.bodyStyle.copyWith(fontSize: 14, color: Colors.white70),
                ),
                const SizedBox(height: 16),
                _buildSwitchTile(
                title: S.of(context)!.enableCustomSettings,
                subtitle: isUnlocked ? '' : S.of(context)!.problemCustomizationUnlock,
                value: gameProvider.useCustomProblemSettings,
                onChanged: isUnlocked
                    ? (value) {
                        gameProvider.setUseCustomSettings(value);
                        _saveSetting('use_custom_settings', value);
                        }
                    : (value) {}, // Empty function to disable
                icon: Icons.toggle_on,
                isLocked: !isUnlocked,
                ),
                const Divider(color: SpaceTheme.nebulaPurple, height: 24),

                // Allowed Operations Section
                Text(
                S.of(context)!.allowedOperations,
                style: SpaceTheme.titleStyle.copyWith(fontSize: 16, color: isCustomEnabled ? Colors.white : Colors.grey),
                ),
                const SizedBox(height: 8),
                _buildOperationCheckboxes(isCustomEnabled),
                const SizedBox(height: 16),
                // Number Range Section
                Text(
                S.of(context)!.numberRange,
                style: SpaceTheme.titleStyle.copyWith(fontSize: 16, color: isCustomEnabled ? Colors.white : Colors.grey),
                ),
                const SizedBox(height: 8),
                _buildRangeSliders(isCustomEnabled),
            ],
            );
        },
        ),
    );
    }

  Widget _buildFeatureRow({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isLocked,
    required VoidCallback onTap,
    }) {
    return InkWell(
        onTap: isLocked ? null : onTap, // Disable tap if locked
        borderRadius: BorderRadius.circular(12),
        child: Opacity(
        opacity: isLocked ? 0.6 : 1.0,
        child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
            children: [
                Icon(
                icon,
                color: isLocked ? Colors.grey : SpaceTheme.alienGreen,
                size: 24,
                ),
                const SizedBox(width: 16),
                Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    Text(
                        title,
                        style: SpaceTheme.bodyStyle.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        ),
                    ),
                    Text(
                        subtitle,
                        style: SpaceTheme.bodyStyle.copyWith(
                        fontSize: 12,
                        color: Colors.white60,
                        ),
                    ),
                    ],
                ),
                ),
                if (isLocked)
                const Icon(Icons.lock, color: SpaceTheme.starYellow, size: 20)
                else
                const Icon(Icons.chevron_right, color: Colors.white70),
            ],
            ),
        ),
        ),
    );
    }

  // --- Helper for operation checkboxes ---
  Widget _buildOperationCheckboxes(bool isEnabled) {
    // --- Get the localization S instance ---
    final s = S.of(context)!;

    return Consumer<GameProvider>(
      builder: (context, gameProvider, child) {
        return Wrap(
          spacing: 8.0,
          runSpacing: 4.0,
          children: [
            // --- Pass the localized strings from 's' ---
            _buildOperationChip(
              s.mathOperationsAddition, 'addition', gameProvider, isEnabled),
            _buildOperationChip(
              s.mathOperationsSubtraction, 'subtraction', gameProvider, isEnabled),
            _buildOperationChip(
              s.mathOperationsMultiplication, 'multiplication', gameProvider, isEnabled),
            _buildOperationChip(
              s.mathOperationsDivision, 'division', gameProvider, isEnabled),
          ],
        );
      },
    );
  }

  // --- Helper for a single operation chip ---
  Widget _buildOperationChip(String label, String opKey, GameProvider provider, bool isEnabled) {
    final bool isSelected = provider.customOperations.contains(opKey);
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: isEnabled
          ? (selected) {
              final currentOps = Set<String>.from(provider.customOperations);
              if (selected) {
                currentOps.add(opKey);
              } else if (currentOps.length > 1) { // Prevent unselecting the last one
                currentOps.remove(opKey);
              }
              provider.setCustomOperations(currentOps);
              _saveSetting('custom_math_ops', currentOps.toList());
            }
          : null,
      backgroundColor: SpaceTheme.deepSpace,
      selectedColor: SpaceTheme.alienGreen,
      labelStyle: TextStyle(color: isEnabled ? Colors.white : Colors.grey),
      shape: StadiumBorder(side: BorderSide(color: isEnabled ? SpaceTheme.alienGreen : Colors.grey)),
    );
  }

  // --- Helper for range sliders ---
  Widget _buildRangeSliders(bool isEnabled) {
    return Consumer<GameProvider>(
      builder: (context, gameProvider, child) { 
        return Column(
          children: [
            Row(
              children: [
                Expanded(child: Text(S.of(context)!.minValue, style: SpaceTheme.bodyStyle.copyWith(color: isEnabled ? Colors.white70 : Colors.grey))),
                Text(gameProvider.customRangeMin.toString(), style: SpaceTheme.titleStyle.copyWith(color: isEnabled ? SpaceTheme.starYellow : Colors.grey)),
              ],
            ),
            Slider(
              value: gameProvider.customRangeMin.toDouble(),
              min: 1,
              max: 99,
              divisions: 98,
              onChanged: isEnabled ? (value) {
                gameProvider.setCustomRange(min: value.toInt(), max: math.max(value.toInt(), gameProvider.customRangeMax));
              } : null,
              onChangeEnd: (value) {
                _saveSetting('custom_range_min', value.toInt());
                _saveSetting('custom_range_max', math.max(value.toInt(), gameProvider.customRangeMax));
              },
            ),
            Row(
              children: [
                Expanded(child: Text(S.of(context)!.maxValue, style: SpaceTheme.bodyStyle.copyWith(color: isEnabled ? Colors.white70 : Colors.grey))),
                Text(gameProvider.customRangeMax.toString(), style: SpaceTheme.titleStyle.copyWith(color: isEnabled ? SpaceTheme.starYellow : Colors.grey)),
              ],
            ),
            Slider(
              value: gameProvider.customRangeMax.toDouble(),
              min: gameProvider.customRangeMin.toDouble(),
              max: 200,
              divisions: (200 - gameProvider.customRangeMin).toInt(),
              onChanged: isEnabled ? (value) {
                gameProvider.setCustomRange(min: gameProvider.customRangeMin, max: value.toInt());
              } : null,
              onChangeEnd: (value) {
                 _saveSetting('custom_range_max', value.toInt());
              },
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildLanguageSettings() {
    return SlideTransition(
      position: _settingAnimations[3], // Adjust animation index
      child: _buildSettingsCard(
        title: S.of(context)!.language,
        icon: Icons.language,
        children: [
          _buildLanguageSelector(),
        ],
      ),
    );
  }

  Widget _buildLanguageSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: SpaceTheme.deepSpace.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: SpaceTheme.alienGreen.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.translate,
                color: SpaceTheme.alienGreen,
                size: 24,
              ),
              
              const SizedBox(width: 16),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      S.of(context)!.appLanguage,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      S.of(context)!.appLanguageDesc,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          _buildLanguageOption(S.of(context)!.languageEnglish, 'en'),
          const SizedBox(height: 12),
          _buildLanguageOption(S.of(context)!.languageGerman, 'de'),
        ],
      ),
    );
  }
  
  Widget _buildLanguageOption(String displayName, String localeCode) {
    final isSelected = currentLocale == localeCode;
    
    return GestureDetector(
      onTap: _isLoading ? null : () => _changeLanguage(localeCode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected 
              ? SpaceTheme.alienGreen.withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected 
                ? SpaceTheme.alienGreen 
                : Colors.white.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? SpaceTheme.alienGreen : Colors.white70,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                displayName,
                style: TextStyle(
                  color: isSelected ? SpaceTheme.alienGreen : Colors.white,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 16,
                ),
              ),
            ),
            if (isSelected) 
              Icon(
                Icons.check,
                color: SpaceTheme.alienGreen,
                size: 20,
              ),
            if (_isLoading && isSelected)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(SpaceTheme.alienGreen),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultySettings() {
    return SlideTransition(
      position: _settingAnimations[3],
      child: _buildSettingsCard(
        title: S.of(context)!.difficulty,
        icon: Icons.tune,
        children: [
          Consumer<GameProvider>(
            builder: (context, gameProvider, child) {
              return Column(
                children: [
                  _buildStatRow(
                    label: S.of(context)!.currentGrade,
                    value: gameProvider.grade.toString(),
                    icon: Icons.school,
                    onTap: () => _showGradeSelector(gameProvider),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  _buildStatRow(
                    label: S.of(context)!.currentLevelDesc,
                    value: gameProvider.level.toString(),
                    icon: Icons.trending_up,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Text(
                    _getDifficultyDescription(gameProvider.grade),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildProgressSettings() {
    return SlideTransition(
      position: _settingAnimations[4],
      child: _buildSettingsCard(
        title: S.of(context)!.progress,
        icon: Icons.analytics,
        children: [
          Consumer<GameProvider>(
            builder: (context, gameProvider, child) {
              return Column(
                children: [
                  _buildStatRow(
                    label: S.of(context)!.totalScore,
                    value: gameProvider.score.toString(),
                    icon: Icons.star,
                  ),
                  
                  _buildStatRow(
                    label: S.of(context)!.gamesPlayed,
                    value: gameProvider.totalGamesPlayed.toString(),
                    icon: Icons.games,
                  ),
                  
                  _buildStatRow(
                    label: 'Achievements',
                    value: gameProvider.totalAchievements.toString(),
                    icon: Icons.emoji_events,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _showResetDialog,
                      icon: const Icon(Icons.refresh),
                      label: Text(S.of(context)!.resetProgress),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SpaceTheme.rocketRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildAboutSection() {
    return SlideTransition(
      position: _settingAnimations[5],
      child: _buildSettingsCard(
        title: S.of(context)!.about,
        icon: Icons.info,
        children: [
          _buildInfoRow(S.of(context)!.appVersion, '1.0.0'),
          _buildInfoRow(S.of(context)!.developer, 'Space Math Academy Team'),
          _buildInfoRow(S.of(context)!.targetAge, '8-12 years (Grades 3-6)'),
          
          const SizedBox(height: 16),
          
          Text(
            S.of(context)!.aboutApp,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildSettingsCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: SpaceTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: SpaceTheme.starYellow.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: SpaceTheme.starYellow,
                  size: 24,
                ),
              ),
              
              const SizedBox(width: 16),
              
              Text(
                title,
                style: SpaceTheme.titleStyle.copyWith(fontSize: 20),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          ...children,
        ],
      ),
    );
  }
  
  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
    bool isLocked = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            color: SpaceTheme.alienGreen,
            size: 24,
          ),
          
          const SizedBox(width: 16),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: SpaceTheme.bodyStyle.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                Text(
                  subtitle,
                  style: SpaceTheme.bodyStyle.copyWith(
                    fontSize: 12,
                    color: Colors.white60,
                  ),
                ),
              ],
            ),
          ),
          
          Switch(
            value: value,
            onChanged: isLocked ? null : onChanged, // Disable if locked
            activeColor: SpaceTheme.alienGreen,
            inactiveThumbColor: SpaceTheme.moonSilver,
            inactiveTrackColor: SpaceTheme.deepSpace,
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatRow({
    required String label,
    required String value,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              icon,
              color: SpaceTheme.cosmicPink,
              size: 20,
            ),
            
            const SizedBox(width: 12),
            
            Expanded(
              child: Text(
                label,
                style: SpaceTheme.bodyStyle.copyWith(fontSize: 14),
              ),
            ),
            
            Text(
              value,
              style: SpaceTheme.titleStyle.copyWith(
                fontSize: 16,
                color: SpaceTheme.starYellow,
              ),
            ),
            
            if (onTap != null)
              const SizedBox(
                width: 4,
                child: Icon(
                  Icons.chevron_right,
                  color: Colors.white54,
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: SpaceTheme.bodyStyle.copyWith(fontSize: 14),
          ),
          Text(
            value,
            style: SpaceTheme.bodyStyle.copyWith(
              fontSize: 14,
              color: SpaceTheme.starYellow,
            ),
          ),
        ],
      ),
    );
  }

  // SAVE INDIVIDUAL SETTING WITH LOGGING
  Future<void> _saveSetting(String key, dynamic value) async {
    debugPrint("[SETTINGS] 💾 Saving setting: $key = $value");
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is String) {
        await prefs.setString(key, value);
      } else if (value is int) {
        await prefs.setInt(key, value);
      } else if (value is double) {
        await prefs.setDouble(key, value);
      } else if (value is List<String>) {
        await prefs.setStringList(key, value);
      }
      
      debugPrint("[SETTINGS] ✅ Successfully saved $key");
      
      // Verify it was saved
      final savedValue = _getSettingValue(prefs, key, value.runtimeType);
      debugPrint("[SETTINGS] 🔍 Verification - $key now reads: $savedValue");
      
    } catch (e, stackTrace) {
      debugPrint("[SETTINGS] ❌ Failed to save $key: $e");
      debugPrint("[SETTINGS] 📚 Stack trace: $stackTrace");
    }
  }
  
  dynamic _getSettingValue(SharedPreferences prefs, String key, Type type) {
    switch (type) {
      case bool:
        return prefs.getBool(key);
      case String:
        return prefs.getString(key);
      case int:
        return prefs.getInt(key);
      case double:
        return prefs.getDouble(key);
      case const (List<String>):
        return prefs.getStringList(key);
      default:
        return prefs.get(key);
    }
  }

  void _changeLanguage(String localeCode) async {
    if (localeCode == currentLocale) {
      debugPrint("[SETTINGS] 🌍 Language unchanged: $localeCode");
      return;
    }
    
    debugPrint("[SETTINGS] 🌍 Changing language from $currentLocale to $localeCode");
    
    setState(() {
      _isLoading = true;
      currentLocale = localeCode;
    });
    
    try {
      // Save to preferences with extensive logging
      await _saveLanguagePreference(localeCode);
      
      // Show restart dialog
      if (mounted) {
        _showLanguageChangeDialog(localeCode);
      }
    } catch (e, stackTrace) {
      debugPrint("[SETTINGS] ❌ Failed to change language: $e");
      debugPrint("[SETTINGS] 📚 Stack trace: $stackTrace");
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to change language: $e'),
            backgroundColor: SpaceTheme.rocketRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _saveLanguagePreference(String localeCode) async {
    debugPrint("[SETTINGS] 🌍 Saving language preference: $localeCode");
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('language', localeCode);
      
      // Verify it was saved
      final savedLocale = prefs.getString('language');
      debugPrint("[SETTINGS] ✅ Language saved successfully");
      debugPrint("[SETTINGS] 🔍 Verification - language now reads: $savedLocale");
      
      // Show all current preferences for debugging
      final allKeys = prefs.getKeys();
      debugPrint("[SETTINGS] 🗂️ All current preferences:");
      for (final key in allKeys) {
        final value = prefs.get(key);
        debugPrint("[SETTINGS]   $key: $value");
      }
      
    } catch (e, stackTrace) {
      debugPrint("[SETTINGS] ❌ Failed to save language preference: $e");
      debugPrint("[SETTINGS] 📚 Stack trace: $stackTrace");
      rethrow;
    }
  }
  
  void _showLanguageChangeDialog(String localeCode) {
    debugPrint("[SETTINGS] 🔄 Showing language change dialog for: $localeCode");
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: SpaceTheme.deepSpace,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          S.of(context)!.languageChanged,
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'The app language will change when you restart. Would you like to restart now?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              debugPrint("[SETTINGS] 🔄 User chose to restart later");
              Navigator.of(context).pop();
            },
            child: Text(
              S.of(context)!.later,
              style: TextStyle(color: SpaceTheme.moonSilver),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              debugPrint("[SETTINGS] 🔄 User chose to restart now");
              Navigator.of(context).pop();
              _triggerAppRestart();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: SpaceTheme.alienGreen,
            ),
            child: Text(S.of(context)!.restartNow),
          ),
        ],
      ),
    );
  }

  void _showGradeSelector(GameProvider gameProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SpaceTheme.deepSpace,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          S.of(context)!.selectGrade,
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [1, 2, 3, 4].map((grade) { 
            final isSelected = gameProvider.grade == grade;
            return GestureDetector(
              onTap: () {
                debugPrint("[SETTINGS] 🎓 Grade changed to: $grade");
                gameProvider.setGrade(grade);
                // SAVE PROGRESS IMMEDIATELY
                context.read<ProgressService>().saveProgress(gameProvider);

                Navigator.of(context).pop();
              },
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? SpaceTheme.starYellow.withOpacity(0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected 
                        ? SpaceTheme.starYellow 
                        : Colors.white.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.school,
                      color: isSelected ? SpaceTheme.starYellow : Colors.white70,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      S.of(context)!.gradeN(grade),
                      style: TextStyle(
                        color: isSelected ? SpaceTheme.starYellow : Colors.white,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _getDifficultyDescription(grade),
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              S.of(context)!.cancel,
              style: TextStyle(color: SpaceTheme.moonSilver),
            ),
          ),
        ],
      ),
    );
  }
  
  String _getDifficultyDescription(int grade) {
    switch (grade) {
      case 1:
        return S.of(context)!.difficultyDescGrade3;
      case 2:
        return S.of(context)!.difficultyDescGrade4;
      case 3:
        return S.of(context)!.difficultyDescGrade5;
      case 4:
        return S.of(context)!.difficultyDescGrade6;
      default:
        return '';
    }
  }

  void _triggerAppRestart() {
    debugPrint("[SETTINGS] 🔄 Triggering app restart notification");
    
    // This would need to be implemented with a state management solution
    // For now, we'll just show a snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(S.of(context)!.restartToApplyChanges),
        backgroundColor: SpaceTheme.alienGreen,
        duration: Duration(seconds: 4),
      ),
    );
  }
  
  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SpaceTheme.deepSpace,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          S.of(context)!.resetProgress,
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to reset all progress? This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              S.of(context)!.cancel,
              style: TextStyle(color: SpaceTheme.moonSilver),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              debugPrint("[SETTINGS] 🗑️ Resetting all game progress");
              context.read<GameProvider>().resetGame();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(S.of(context)!.progressResetSuccess),
                  backgroundColor: SpaceTheme.alienGreen,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: SpaceTheme.rocketRed,
            ),
            child: Text(S.of(context)!.reset),
          ),
        ],
      ),
    );
  }
}