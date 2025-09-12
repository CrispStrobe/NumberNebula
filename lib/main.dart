import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/theme/space_theme.dart';
import 'features/games/constants/app_constants.dart';
import 'core/services/audio_service.dart';
import 'core/services/progress_service.dart';
import 'features/home/screens/home_screen.dart';
import 'features/games/providers/game_provider.dart';
import 'features/games/screens/game_menu_screen.dart';
import 'features/games/screens/magic_triangles_game.dart';
import 'features/games/screens/bubble_math_game.dart';
import 'features/games/screens/puzzle_math_game.dart';
import 'features/settings/screens/settings_screen.dart';
import 'features/achievements/screens/achievements_screen.dart';
import 'shared/utils/app_utilities.dart';
import 'generated/l10n.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Force landscape orientation for iPad
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  
  // Initialize services
  final audioService = AudioService();
  final progressService = ProgressService();
  await progressService.init();
  
  runApp(SpaceMathApp(
    audioService: audioService,
    progressService: progressService,
  ));
}

class SpaceMathApp extends StatelessWidget {
  final AudioService audioService;
  final ProgressService progressService;
  
  const SpaceMathApp({
    super.key,
    required this.audioService,
    required this.progressService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AudioService>.value(value: audioService),
        Provider<ProgressService>.value(value: progressService),
        ChangeNotifierProvider(create: (_) => GameProvider()),
      ],
      child: MaterialApp(
        title: 'Space Math Academy',
        debugShowCheckedModeBanner: false,
        
        // Internationalization
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        
        // Theme
        theme: SpaceTheme.lightTheme,
        darkTheme: SpaceTheme.darkTheme,
        themeMode: ThemeMode.light,
        
        // Routes
        initialRoute: AppRoutes.splash,
        onGenerateRoute: AppRoutes.generateRoute,
        
        // Error handling
        builder: (context, child) {
          ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
            return SpaceErrorScreen(
              title: 'Oops! Something went wrong',
              message: 'Our space engineers are working on it!',
              onRetry: () {
                // Restart app logic
              },
            );
          };
          
          return child ?? const SizedBox.shrink();
        },
      ),
    );
  }
}

class AppRoutes {
  // Route names
  static const String splash = '/';
  static const String home = '/home';
  static const String gameMenu = '/games';
  static const String magicTriangles = '/games/magic-triangles';
  static const String bubbleGame = '/games/bubble-math';
  static const String puzzleGame = '/games/puzzle-math';
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
        
      case bubbleGame:
        final grade = args?['grade'] as int? ?? 3;
        final level = args?['level'] as int? ?? 1;
        return _createRoute(BubbleMathGame(grade: grade, level: level));
        
      case puzzleGame:
        final grade = args?['grade'] as int? ?? 3;
        final level = args?['level'] as int? ?? 1;
        return _createRoute(PuzzleMathGame(grade: grade, level: level));
        
      case AppRoutes.settings:
        return _createRoute(const SettingsScreen());
        
      case achievements:
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
            onBack: () {
              // Navigate back to home
            },
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
  
  // Navigation helpers
  static Future<void> navigateToGame(
    BuildContext context,
    String gameRoute, {
    required int grade,
    required int level,
  }) {
    return Navigator.pushNamed(
      context,
      gameRoute,
      arguments: {'grade': grade, 'level': level},
    );
  }
  
  static Future<void> navigateToHome(BuildContext context) {
    return Navigator.pushNamedAndRemoveUntil(
      context,
      home,
      (route) => false,
    );
  }
  
  static Future<void> showLoadingScreen(
    BuildContext context, {
    String? message,
  }) {
    return Navigator.pushNamed(
      context,
      loading,
      arguments: {'message': message},
    );
  }
}

// Splash Screen with App Initialization
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  
  late AnimationController _logoController;
  late AnimationController _textController;
  late Animation<double> _logoScale;
  late Animation<double> _textOpacity;
  
  @override
  void initState() {
    super.initState();
    
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _textController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _logoScale = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    ));
    
    _textOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeIn,
    ));
    
    _initializeApp();
  }
  
  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    super.dispose();
  }
  
  Future<void> _initializeApp() async {
    // Start logo animation
    _logoController.forward();
    
    // Simulate app initialization
    await Future.delayed(const Duration(milliseconds: 1000));
    
    // Start text animation
    _textController.forward();
    
    // Load game data
    try {
      final progressService = context.read<ProgressService>();
      final gameProvider = context.read<GameProvider>();
      await progressService.loadProgress(gameProvider);
    } catch (e) {
      // Handle initialization error
      print('Error loading progress: $e');
    }
    
    // Wait for animations to complete
    await Future.delayed(const Duration(milliseconds: 2000));
    
    // Navigate to home
    if (mounted) {
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: SpaceTheme.spaceGradient,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated Logo
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
                      child: const Icon(
                        Icons.rocket_launch,
                        color: Colors.white,
                        size: 80,
                      ),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 40),
              
              // App Title
              AnimatedBuilder(
                animation: _textOpacity,
                builder: (context, child) {
                  return Opacity(
                    opacity: _textOpacity.value,
                    child: Column(
                      children: [
                        Text(
                          'Space Math Academy',
                          style: SpaceTheme.headlineStyle.copyWith(fontSize: 36),
                          textAlign: TextAlign.center,
                        ),
                        
                        const SizedBox(height: 16),
                        
                        Text(
                          'Explore • Learn • Discover',
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
              
              // Loading Indicator
              AnimatedBuilder(
                animation: _textOpacity,
                builder: (context, child) {
                  return Opacity(
                    opacity: _textOpacity.value,
                    child: Column(
                      children: [
                        SizedBox(
                          width: 200,
                          child: LinearProgressIndicator(
                            backgroundColor: SpaceTheme.deepSpace,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              SpaceTheme.starYellow,
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        Text(
                          'Launching into space...',
                          style: SpaceTheme.bodyStyle.copyWith(fontSize: 14),
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
    print('Global Error: $error');
    print('Stack Trace: $stackTrace');
    
    // Report to crash analytics service if implemented
    // FirebaseCrashlytics.instance.recordError(error, stackTrace);
  }
  
  static void init() {
    FlutterError.onError = (FlutterErrorDetails details) {
      handleError(details.exception, details.stack ?? StackTrace.empty);
    };
  }
}