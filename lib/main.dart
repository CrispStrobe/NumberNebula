// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- CORE SERVICES ---
import 'core/services/audio_service.dart';
import 'core/services/debug_provider.dart';
import 'core/services/progress_service.dart';
import 'core/services/purchase_service.dart';
import 'core/services/puzzle_image_service.dart';
import 'core/services/sri_service.dart';
import 'core/theme/space_theme.dart';

// --- PROVIDERS & MODELS ---
import 'features/games/providers/game_provider.dart';

// --- SCREENS ---
import 'features/home/screens/home_screen.dart';
import 'features/games/screens/game_menu_screen.dart';
import 'features/settings/screens/settings_screen.dart';
import 'features/achievements/screens/achievements_screen.dart';
import 'features/games/screens/magic_triangles_game.dart';
import 'features/games/screens/asteroid_math_game.dart';
import 'features/games/screens/puzzle_math_game.dart';
import 'features/games/screens/hyperdrive_gates_game.dart';
import 'features/games/screens/planet_hopping_game.dart';
import 'features/games/screens/number_walls_game.dart';
import 'features/games/screens/codebreaker_game.dart';
import 'features/games/screens/perspective_puzzle_game.dart'; 
import 'features/games/screens/blocks_counter_game.dart'; 

// --- UTILS & GENERATED ---
import 'shared/utils/app_utilities.dart';
import 'generated/l10n.dart';

// --- GLOBAL INSTANCES & NAVIGATOR KEY ---
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GameProvider gameProvider = GameProvider();
final SriService sriService = SriService();
final PurchaseService purchaseService = PurchaseService();
final DebugProvider debugProvider = DebugProvider();
final ProgressService progressService = ProgressService();
final AudioService audioService = AudioService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  await PuzzleImageService.instance.init();
  purchaseService.init(gameProvider);
  await debugProvider.init();
  GlobalErrorHandler.init();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: gameProvider),
        ChangeNotifierProvider.value(value: sriService),
        ChangeNotifierProvider.value(value: purchaseService),
        ChangeNotifierProvider.value(value: debugProvider),
        Provider.value(value: progressService),
        Provider.value(value: audioService),
      ],
      child: const SpaceMathApp(),
    ),
  );
}

class SpaceMathApp extends StatefulWidget {
  const SpaceMathApp({super.key});

  @override
  State<SpaceMathApp> createState() => _SpaceMathAppState();
}

class _SpaceMathAppState extends State<SpaceMathApp> with WidgetsBindingObserver {
  Locale? _locale;
  bool _isInitialized = false;
  String? _initializationError;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    purchaseService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _saveAppState();
    }
  }
  
  Future<void> _initializeApp() async {
    try {
      await _loadLanguagePreference();
      await progressService.loadProgress(gameProvider);
      await sriService.loadSriData();
      setState(() => _isInitialized = true);
    } catch (e, s) {
      debugPrint('Initialization Error: $e\n$s');
      setState(() {
        _initializationError = e.toString();
        _isInitialized = true;
      });
    }
  }
  
  Future<void> _loadLanguagePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final languageCode = prefs.getString('language');
      
      if (languageCode != null && S.supportedLocales.any((locale) => locale.languageCode == languageCode)) {
        setState(() => _locale = Locale(languageCode));
      } else {
        final systemLocale = WidgetsBinding.instance.platformDispatcher.locale;
        if (S.supportedLocales.any((l) => l.languageCode == systemLocale.languageCode)) {
           setState(() => _locale = systemLocale);
        } else {
           setState(() => _locale = const Locale('en'));
        }
      }
    } catch (e) {
      setState(() => _locale = const Locale('en'));
    }
  }
  
  Future<void> _saveAppState() async {
    await progressService.saveProgress(gameProvider);
    await sriService.saveSriData();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_locale != null) {
        await prefs.setString('language', _locale!.languageCode);
      }
    } catch (e) {
      debugPrint('Error saving language state: $e');
    }
  }
  
  Future<void> _restoreAppState() async {
    // Restore logic if needed
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return MaterialApp(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: const SpaceLoadingScreen(message: 'Initializing...'),
        theme: SpaceTheme.lightTheme,
      );
    }
    
    if (_initializationError != null) {
      return MaterialApp(
        home: SpaceErrorScreen(
          title: 'Initialization Error',
          message: 'Failed to start the app: $_initializationError',
          onRetry: () {
            setState(() {
              _isInitialized = false;
              _initializationError = null;
            });
            _initializeApp();
          },
        ),
        theme: SpaceTheme.lightTheme,
      );
    }

    return MaterialApp(
      title: 'Space Math Academy',
      navigatorKey: navigatorKey, 
      debugShowCheckedModeBanner: false,
      locale: _locale,
      localizationsDelegates: S.localizationsDelegates,
      supportedLocales: S.supportedLocales,
      theme: SpaceTheme.lightTheme,
      darkTheme: SpaceTheme.darkTheme,
      themeMode: ThemeMode.light,
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRoutes.generateRoute,
      builder: (context, child) {
        ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
          return SpaceErrorScreen(
            title: 'Oops! Something went wrong',
            message: 'Our space engineers are working on it!',
            onRetry: () {
              final currentContext = navigatorKey.currentContext;
              if (currentContext != null) {
                Navigator.of(currentContext).pushReplacementNamed(
                  ModalRoute.of(currentContext)?.settings.name ?? AppRoutes.home,
                );
              }
            },
          );
        };
        return child ?? const SizedBox.shrink();
      },
    );
  }
}

class AppRoutes {
  // Route names
  static const String splash = '/';
  static const String home = '/home';
  static const String gameMenu = '/games';
  static const String magicTriangles = '/games/magic-triangles';
  static const String asteroidGame = '/games/asteroid-math';
  static const String puzzleGame = '/games/puzzle-math';
  static const String hyperdriveGates = '/games/hyperdrive-gates';
  static const String planetHopping = '/games/planet-hopping';
  static const String numberWalls = '/games/number-walls';
  static const String codebreaker = '/games/codebreaker';
  static const String perspectivePuzzle = '/games/perspective-puzzle';
  static const String blockCounter = '/games/block-counter'; // NEW
  static const String settings = '/settings';
  static const String achievements = '/achievements';
  static const String loading = '/loading';
  static const String error = '/error';
  
  static Route<dynamic> generateRoute(RouteSettings settings) {
    final args = settings.arguments as Map<String, dynamic>?;
    
    switch (settings.name) {
        case splash:
          return _createRoute(const SplashScreen());
          
        case home:
          return _createRoute(const HomeScreen());
          
        case gameMenu:
          return _createRoute(const GameMenuScreen());
          
        case magicTriangles:
          final grade = args?['grade'] as int? ?? 3;
          final level = args?['level'] as int? ?? 1;
          return _createRoute(MagicTrianglesGame(grade: grade, level: level));
          
        case asteroidGame:
          final grade = args?['grade'] as int? ?? 3;
          final level = args?['level'] as int? ?? 1;
          return _createRoute(AsteroidMathGame(grade: grade, level: level));
          
        case puzzleGame:
          final grade = args?['grade'] as int? ?? 3;
          final level = args?['level'] as int? ?? 1;
          return _createRoute(PuzzleMathGame(grade: grade, level: level));
          
        case hyperdriveGates:
          final grade = args?['grade'] as int? ?? 3;
          final level = args?['level'] as int? ?? 1;
          return _createRoute(HyperdriveGatesGame(grade: grade, level: level));
          
        case planetHopping:
          final grade = args?['grade'] as int? ?? 3;
          final level = args?['level'] as int? ?? 1;
          return _createRoute(PlanetHoppingGame(grade: grade, level: level));

        case numberWalls:
          final grade = args?['grade'] as int? ?? 3;
          final level = args?['level'] as int? ?? 1;
          return _createRoute(NumberWallsGame(grade: grade, level: level));

        case codebreaker:
          final grade = args?['grade'] as int? ?? 3;
          final level = args?['level'] as int? ?? 1;
          return _createRoute(CodebreakerGame(grade: grade, level: level));
      
        case perspectivePuzzle:
            final grade = args?['grade'] as int? ?? 3;
            final level = args?['level'] as int? ?? 1;
            return _createRoute(PerspectivePuzzleGame(grade: grade, level: level));

        case blockCounter: 
          final grade = args?['grade'] as int? ?? 3;
          final level = args?['level'] as int? ?? 1;
          return _createRoute(BlockCounterGame(grade: grade, level: level));
      
        case AppRoutes.settings:
          return _createRoute(const SettingsScreen());
      
        case AppRoutes.achievements:
        return _createRoute(const AchievementsScreen());
      
        case loading:
          final message = args?['message'] as String?;
          return _createRoute(SpaceLoadingScreen(message: message));
          
        case error:
          final title = args?['title'] as String? ?? 'Error';
          final message = args?['message'] as String? ?? 'Something went wrong';
          return _createRoute(SpaceErrorScreen(title: title, message: message));
          
        default:
          return _createRoute(
              SpaceErrorScreen(
              title: 'Route Not Found',
              message: 'The requested page could not be found.',
              onBack: () {},
              ),
          );
    }
    }
  
  static PageRoute _createRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.1, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            )),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 400),
    );
  }
}

// Enhanced Splash Screen with Better Initialization
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _progressController;

  late Animation<double> _logoScale;
  late Animation<double> _textOpacity;
  late Animation<double> _progressAnimation;

  String _loadingMessage = 'Initializing...'; // Start with a non-localized default
  double _progress = 0.0;
  
  @override
  void initState() {
    super.initState();
    
    _logoController = AnimationController(duration: const Duration(milliseconds: 2000), vsync: this);
    _textController = AnimationController(duration: const Duration(milliseconds: 1000), vsync: this);
    _progressController = AnimationController(duration: const Duration(milliseconds: 3000), vsync: this);

    _logoScale = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _logoController, curve: Curves.elasticOut));
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _textController, curve: Curves.easeIn));
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _progressController, curve: Curves.easeInOut));
  }

  // FIX: Access context-dependent resources here, not in initState.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // It's safe to call S.of(context) here for the first time.
    // We pass the S instance to the initialization logic.
    _initializeApp(S.of(context)!);
  }
  
  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _progressController.dispose();
    super.dispose();
  }
  
  // FIX: This method now accepts the 'S' instance so it doesn't need context.
  Future<void> _initializeApp(S s) async {
    _logoController.forward();

    await _updateProgress(0.2, s.loadingAssets);
    await Future.delayed(const Duration(milliseconds: 500));

    await _updateProgress(0.4, s.loadingProgress);
    try {
      if (mounted) {
        final progressService = context.read<ProgressService>();
        final gameProvider = context.read<GameProvider>();
        await progressService.loadProgress(gameProvider);
      }
    } catch (e) {
      debugPrint('Error loading progress: $e');
    }
    
    _textController.forward();
    await _updateProgress(0.6, s.preparingSpaceStation);
    await Future.delayed(const Duration(milliseconds: 500));
    
    await _updateProgress(0.8, s.calibratingNav);
    await Future.delayed(const Duration(milliseconds: 500));
    
    await _updateProgress(1.0, s.readyForLaunch);
    await Future.delayed(const Duration(milliseconds: 800));

    if (mounted) {
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    }
  }

  Future<void> _updateProgress(double progress, String message) async {
    if (mounted) {
      setState(() {
        _progress = progress;
        _loadingMessage = message;
      });
      _progressController.animateTo(progress);
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: SpaceTheme.spaceGradient),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _logoScale,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _logoScale.value,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        gradient: SpaceTheme.starGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: SpaceTheme.starYellow.withOpacity(0.5),
                            blurRadius: 30,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.rocket_launch, color: Colors.white, size: 80),
                    ),
                  );
                },
              ),
              const SizedBox(height: 40),
              AnimatedBuilder(
                animation: _textOpacity,
                builder: (context, child) {
                  return Opacity(
                    opacity: _textOpacity.value,
                    child: Column(
                      children: [
                        Text(
                          S.of(context)!.appTitle, // This is safe to call here
                          style: SpaceTheme.headlineStyle.copyWith(fontSize: 36),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          S.of(context)!.splashScreenSubtitle, // And here
                          style: SpaceTheme.bodyStyle.copyWith(
                            fontSize: 18,
                            color: SpaceTheme.starYellow,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 60),
              AnimatedBuilder(
                animation: _textOpacity,
                builder: (context, child) {
                  return Opacity(
                    opacity: _textOpacity.value,
                    child: Column(
                      children: [
                        SizedBox(
                          width: 250,
                          child: AnimatedBuilder(
                            animation: _progressAnimation,
                            builder: (context, child) {
                              return LinearProgressIndicator(
                                value: _progressAnimation.value,
                                backgroundColor: SpaceTheme.deepSpace,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  SpaceTheme.starYellow,
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _loadingMessage, // Display the current loading message
                          style: SpaceTheme.bodyStyle.copyWith(fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${(_progress * 100).toInt()}%',
                          style: SpaceTheme.bodyStyle.copyWith(
                            fontSize: 12,
                            color: SpaceTheme.starYellow,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Global Error Handler
class GlobalErrorHandler {
  static void handleError(dynamic error, StackTrace stackTrace) {
    // Log error
    debugPrint('Global Error: $error');
    debugPrint('Stack Trace: $stackTrace');
    
    // Report to crash analytics service if implemented
    // FirebaseCrashlytics.instance.recordError(error, stackTrace);
  }
  
  static void init() {
    FlutterError.onError = (FlutterErrorDetails details) {
      handleError(details.exception, details.stack ?? StackTrace.empty);
    };
  }
}