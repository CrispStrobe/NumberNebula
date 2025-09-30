# 🚀 Space Math Academy

A space-themed math learning app for primary school students onwards. Features engaging mini-games including Magic Triangles, arithmetic puzzles, and visual spatial games.

## ✨ Features

### 🎮 Mini Games

  - **Magic Triangles**: Solve mathematical triangle puzzles where each side adds up to the same sum
  - **Space Puzzle Math**: Complete space station puzzles by solving math problems and fitting rotatable pieces
  - **Hyperdrive Gates**: Pilot a spaceship through gates with the correct answer to a math problem while avoiding obstacles
  - **Path Finder**: Select the correct mathematical path for your spaceship to follow, avoiding hazards and collecting points
  - **Planet Hopping**: Navigate your space hopper to planets in the correct numerical sequence, solving math problems along the way
  - **Number Walls**: Fill in the missing numbers in a pyramid-like structure where each number is the result of a mathematical operation on the two numbers below it
  - **Codebreaker**: Decipher a code by assigning numbers to symbols to solve a series of interconnected equations
  - **Perspective Puzzle**: Recreate a 3D block structure from a 2D perspective view, testing spatial reasoning and visualization skills
  - **Spatial Blocks**: Construct a 3D block structure by stacking colored pieces on a grid to match a rotating target model
  - **Signal Triangulation**: A logic puzzle where players must deduce a secret sequence of colored and shaped glyphs using feedback from their guesses.
  - **Cryptex Lock Breaker**: Solve a system of mathematical equations to determine the correct combination for a series of rotating dials.
  - **Arithmancer Duel**: A turn-based card game where players craft mathematical expressions to defeat an AI opponent.
   - **Arithmetic Square**: Fill a grid of empty cells with numbers from a pool to satisfy all horizontal and vertical equations (row/column constraints).
  - **Arithmancer Crosswords**: Solve a math-based crossword puzzle by placing numbers in a grid to complete intersecting arithmetic equations.
  - **Kenken**: Fill a grid such that no digit repeats in any row or column, while also satisfying the mathematical constraints within "cages."

### 🌟 Key Features
- **Multi-language support**: English & German (i18n)
- **Grade-specific content**: Tailored for grades 3-6
- **Progressive difficulty**: Adaptive challenge levels
- **Space theme**: Immersive cosmic design with animations
- **iPad optimized**: Landscape orientation, large touch targets
- **Achievement system**: Unlock space explorer achievements
- **Progress tracking**: Save and monitor learning progress

## 🛠️ Setup Instructions

### Prerequisites
- Flutter SDK (3.10.0 or higher)
- Dart SDK (3.0.0 or higher)
- iOS development setup for iPad deployment
- Xcode (for iOS builds)

### Installation

1. **Clone or create the project**
   ```bash
   flutter create space_math_academy
   cd space_math_academy
   ```

2. **Replace pubspec.yaml with the provided configuration**
   
3. **Install dependencies**
   ```bash
   flutter pub get
   ```

4. **Create the required directory structure**
   ```
   lib/
   ├── core/
   │   ├── constants/
   │   │   └── app_constants.dart
   │   ├── theme/
   │   │   └── space_theme.dart
   │   └── services/
   ├── features/
   │   ├── home/
   │   │   ├── screens/
   │   │   │   └── home_screen.dart
   │   │   └── widgets/
   │   │       ├── animated_logo.dart
   │   │       ├── grade_selector.dart
   │   │       └── stats_card.dart
   │   └── games/
   │       ├── models/
   │       │   └── math_problem.dart
   │       ├── providers/
   │       │   └── game_provider.dart
   │       ├── screens/
   │   │       │   ├── arithmancer_duel_game.dart
   │   │       │   ├── asteroid_math_game.dart
   │   │       │   ├── blocks_counter_game.dart
   │   │       │   ├── codebreaker_game.dart
   │   │       │   ├── cryptex_lock_breaker_game.dart
   │   │       │   ├── game_menu_screen.dart
   │   │       │   ├── hyperdrive_gates_game.dart
   │   │       │   ├── magic_triangles_game.dart
   │   │       │   ├── number_walls_game.dart
   │   │       │   ├── path_finder_game.dart
   │   │       │   ├── perspective_puzzle_game.dart
   │   │       │   ├── planet_hopping_game.dart
   │   │       │   ├── puzzle_math_game.dart
   │   │       │   ├── signal_triangulation_game.dart
   │   │       │   ├── arithmatic_square_game.dart
   │   │       │   ├── arithmancer_crosswords_game.dart
   │   │       │   ├── kenken_game.dart   
   │   │       │   └── spatial_blocks_game.dart
   │       └── widgets/
   │           ├── space_background.dart
   │           └── game_ui.dart
   ├── l10n/
   │   ├── app_en.arb
   │   └── app_de.arb
   ├── generated/
   │   └── l10n.dart
   └── main.dart
   ```

5. **Set up localization**
   ```bash
   flutter gen-l10n
   ```

6. **Create asset directories**
   ```bash
   mkdir -p assets/{images,sounds,animations,fonts}
   ```

7. **Add font files** (optional - the app will work with system fonts)
   - Download Space Grotesk font family
   - Place in `assets/fonts/`

## 📱 Running the App

### Development
```bash
# Run in debug mode
flutter run

# Run on specific device
flutter run -d "iPad Simulator"

# Hot reload during development
# Press 'r' in terminal while app is running
```

### Building for iOS (iPad)
```bash
# Build for iOS simulator
flutter build ios --simulator

# Build for device (requires code signing)
flutter build ios --release
```

### Building for other platforms
```bash
# Android (phone/tablet)
flutter build apk

# Web
flutter build web

# macOS
flutter build macos
```

## 🎨 Assets Setup

### Required Assets
Create placeholder files or add real assets:

```
assets/
├── images/
│   ├── app_icon.png (1024x1024)
│   ├── planets/ (various planet images)
│   ├── rockets/ (rocket sprites)
│   └── backgrounds/ (space backgrounds)
├── sounds/
│   ├── correct.mp3
│   ├── incorrect.mp3
│   ├── level_complete.mp3
│   ├── button_click.mp3
│   └── space_ambient.mp3
├── animations/
│   └── (Lottie/Rive animations)
└── fonts/
    ├── SpaceGrotesk-Regular.ttf
    └── SpaceGrotesk-Bold.ttf
```

## 🔧 Configuration

### iOS Configuration
Add to `ios/Runner/Info.plist`:
```xml
<key>UIInterfaceOrientationSupported</key>
<array>
    <string>UIInterfaceOrientationLandscapeLeft</string>
    <string>UIInterfaceOrientationLandscapeRight</string>
</array>
<key>UISupportedInterfaceOrientations~ipad</key>
<array>
    <string>UIInterfaceOrientationLandscapeLeft</string>
    <string>UIInterfaceOrientationLandscapeRight</string>
</array>
```

### App Icon
Generate app icons for iOS:
```bash
# Install flutter_launcher_icons if not already added
flutter pub run flutter_launcher_icons:main
```

## 🎯 Game Types & Grade Levels

### Grade 3 (Ages 8-9)
- **Operations**: Addition, Subtraction, Simple Multiplication
- **Number Range**: 1-20
- **Examples**: 5 + 8, 15 - 7, 3 × 4

### Grade 4 (Ages 9-10)
- **Operations**: Addition, Subtraction, Multiplication, Division
- **Number Range**: 1-50
- **Examples**: 25 + 37, 48 - 19, 6 × 7, 24 ÷ 6

### Grade 5 (Ages 10-11)
- **Operations**: All four operations
- **Number Range**: 1-100
- **Examples**: 67 + 89, 85 - 38, 9 × 12, 72 ÷ 8

### Grade 6 (Ages 11-12)
- **Operations**: Advanced problems
- **Number Range**: 1-200
- **Examples**: 156 + 287, 201 - 89, 15 × 18, 144 ÷ 12

## 🏆 Achievement System

### Score-based Achievements
- **First Century**: Score 100 points
- **Score Master**: Score 500 points
- **Thousand Club**: Score 1000 points

### Progress Achievements
- **Level Explorer**: Reach level 5
- **Space Commander**: Reach level 10
- **Grade Graduate**: Complete grade levels

### Game-specific Achievements
- **Triangle Wizard**: Complete Magic Triangle levels
- **Bubble Popper**: Master Bubble Math
- **Puzzle Solver**: Excel at Space Puzzles

## 🌍 Internationalization (i18n)

The app supports:
- **English (en)**: Default language
- **German (de)**: Deutsch

### Adding New Languages
1. Create new `.arb` file in `lib/l10n/`
2. Add translations for all keys
3. Run `flutter gen-l10n`
4. Update supported locales in `main.dart`

## 🎵 Audio Features

### Sound Effects
- Correct answer chime
- Incorrect answer buzz
- Level completion fanfare
- Button click sounds

### Background Music
- Ambient space music
- Adaptive to game state
- Volume controls in settings

## 📊 Progress Tracking

### Local Storage
- Game progress per grade/level
- Achievement unlocks
- User preferences
- High scores

### Data Persistence
Uses `shared_preferences` for:
- Settings (sound, music, language)
- Game progress
- Achievement status
- User statistics

## 🔍 Troubleshooting

### Common Issues

**Localization not working:**
```bash
flutter clean
flutter pub get
flutter gen-l10n
```

**iOS build fails:**
- Check Xcode version compatibility
- Verify code signing settings
- Clean build folder: `flutter clean`

**Assets not loading:**
- Verify file paths in `pubspec.yaml`
- Check asset file existence
- Run `flutter pub get` after asset changes

**Performance issues:**
- Test on physical device (simulator may be slower)
- Check for memory leaks in animations
- Optimize image assets

## 🚀 Deployment

### iOS App Store
1. Configure app metadata in Xcode
2. Set up provisioning profiles
3. Build release version: `flutter build ios --release`
4. Archive and upload via Xcode

### TestFlight Distribution
1. Build and archive in Xcode
2. Upload to App Store Connect
3. Add external testers
4. Distribute for testing

## 🤝 Contributing

### Code Style
- Follow Dart/Flutter style guidelines
- Use meaningful variable names
- Comment complex game logic
- Maintain consistent theming

### Adding New Games
1. Create new game screen in `features/games/screens/`
2. Add game card to `game_menu_screen.dart`
3. Update localization files
4. Add achievement support
5. Update progress tracking

## 📝 License

This project is created for educational purposes. Please ensure compliance with any third-party assets or fonts used.

## 🎯 Possible Future Enhancements

- **Multiplayer mode**: Local multiplayer on shared iPad
- **Adaptive difficulty**: AI-driven difficulty adjustment
- **Parent dashboard**: Progress reports for parents/teachers
- **Offline mode**: Full functionality without internet
- **Voice recognition**: Speak answers aloud
- **Accessibility**: Screen reader support, high contrast mode

**Happy coding and may the mathematical force be with you! 🚀✨**
