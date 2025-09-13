import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
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
    
    _settingAnimations = List.generate(6, (index) {
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
      
      debugPrint("[SETTINGS] 🔊 Sound enabled: $soundEnabled");
      debugPrint("[SETTINGS] 🎵 Music enabled: $musicEnabled");
      debugPrint("[SETTINGS] 💡 Hints enabled: $hintsEnabled");
      debugPrint("[SETTINGS] 📳 Haptic enabled: $hapticEnabled");
      debugPrint("[SETTINGS] ⏱️ Puzzle timer enabled: $puzzleTimerEnabled");
      
      // Apply settings to GameProvider if needed
      if (mounted) {
        final gameProvider = context.read<GameProvider>();
        gameProvider.setSoundEnabled(soundEnabled);
        gameProvider.setMusicEnabled(musicEnabled);
        gameProvider.setPuzzleTimer(puzzleTimerEnabled);
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
        title: 'Audio Settings',
        icon: Icons.volume_up,
        children: [
          Consumer<GameProvider>(
            builder: (context, gameProvider, child) {
              return Column(
                children: [
                  _buildSwitchTile(
                    title: S.of(context)!.sound,
                    subtitle: 'Sound effects',
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
                    subtitle: 'Background music',
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
        title: 'Gameplay',
        icon: Icons.games,
        children: [
          Consumer<GameProvider>(
            builder: (context, gameProvider, child) {
              return Column(
                children: [
                  _buildSwitchTile(
                    title: 'Puzzle Timer',
                    subtitle: 'Enable timer in puzzle games',
                    value: gameProvider.puzzleTimerEnabled,
                    onChanged: (value) {
                      debugPrint("[SETTINGS] ⏱️ Puzzle timer setting changed to: $value");
                      gameProvider.setPuzzleTimer(value);
                      _saveSetting('puzzle_timer_enabled', value);
                    },
                    icon: Icons.timer,
                  ),
                  
                  _buildSwitchTile(
                    title: 'Show Hints',
                    subtitle: 'Display helpful hints during games',
                    value: true, // TODO: Add to GameProvider
                    onChanged: (value) {
                      debugPrint("[SETTINGS] 💡 Hints setting changed to: $value");
                      _saveSetting('hints_enabled', value);
                    },
                    icon: Icons.lightbulb,
                  ),
                  
                  _buildSwitchTile(
                    title: 'Haptic Feedback',
                    subtitle: 'Vibration on touch (if supported)',
                    value: true, // TODO: Add to GameProvider
                    onChanged: (value) {
                      debugPrint("[SETTINGS] 📳 Haptic feedback setting changed to: $value");
                      _saveSetting('haptic_enabled', value);
                    },
                    icon: Icons.vibration,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildLanguageSettings() {
    return SlideTransition(
      position: _settingAnimations[2],
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
                    const Text(
                      'App Language',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Choose your preferred language',
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
          
          _buildLanguageOption('English', 'en'),
          const SizedBox(height: 12),
          _buildLanguageOption('Deutsch', 'de'),
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
        title: 'Difficulty',
        icon: Icons.tune,
        children: [
          Consumer<GameProvider>(
            builder: (context, gameProvider, child) {
              return Column(
                children: [
                  _buildStatRow(
                    label: 'Current Grade',
                    value: gameProvider.grade.toString(),
                    icon: Icons.school,
                    onTap: () => _showGradeSelector(gameProvider),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  _buildStatRow(
                    label: 'Current Level',
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
                    label: 'Total Score',
                    value: gameProvider.score.toString(),
                    icon: Icons.star,
                  ),
                  
                  _buildStatRow(
                    label: 'Games Played',
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
                      label: const Text('Reset Progress'),
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
        title: 'About',
        icon: Icons.info,
        children: [
          _buildInfoRow('App Version', '1.0.0'),
          _buildInfoRow('Developer', 'Space Math Academy Team'),
          _buildInfoRow('Target Age', '8-12 years (Grades 3-6)'),
          
          const SizedBox(height: 16),
          
          const Text(
            'Space Math Academy helps primary school students learn mathematics through engaging space-themed games. Perfect for iPads and designed with young learners in mind.',
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
            onChanged: onChanged,
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
        title: const Text(
          'Language Changed',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'The app language will change when you restart. Would you like to restart now?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              debugPrint("[SETTINGS] 🔄 User chose to restart later");
              Navigator.of(context).pop();
            },
            child: const Text(
              'Later',
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
            child: const Text('Restart Now'),
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
        title: const Text(
          'Select Grade',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [3, 4, 5, 6].map((grade) {
            final isSelected = gameProvider.grade == grade;
            return GestureDetector(
              onTap: () {
                debugPrint("[SETTINGS] 🎓 Grade changed to: $grade");
                gameProvider.setGrade(grade);
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
                      'Grade $grade',
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
            child: const Text(
              'Cancel',
              style: TextStyle(color: SpaceTheme.moonSilver),
            ),
          ),
        ],
      ),
    );
  }
  
  String _getDifficultyDescription(int grade) {
    switch (grade) {
      case 3:
        return 'Basic operations';
      case 4:
        return 'Multi-digit math';
      case 5:
        return 'Complex problems';
      case 6:
        return 'Advanced challenges';
      default:
        return '';
    }
  }

  void _triggerAppRestart() {
    debugPrint("[SETTINGS] 🔄 Triggering app restart notification");
    
    // This would need to be implemented with a state management solution
    // For now, we'll just show a snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please restart the app to apply language changes'),
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
        title: const Text(
          'Reset Progress',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to reset all progress? This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: SpaceTheme.moonSilver),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              debugPrint("[SETTINGS] 🗑️ Resetting all game progress");
              context.read<GameProvider>().resetGame();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Progress reset successfully!'),
                  backgroundColor: SpaceTheme.alienGreen,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: SpaceTheme.rocketRed,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}