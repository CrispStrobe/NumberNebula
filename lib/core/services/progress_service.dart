import '../../../features/games/providers/game_provider.dart';

class ProgressService {
  Future<void> init() async {
    // TODO: Initialize shared preferences for data persistence
    print('Progress service initialized');
  }
  
  Future<void> saveProgress(GameProvider gameProvider) async {
    // TODO: Save game progress to shared preferences
    final data = gameProvider.toJson();
    print('Saving progress: $data');
    // Implementation with shared_preferences will be added later
  }
  
  Future<void> loadProgress(GameProvider gameProvider) async {
    // TODO: Load game progress from shared preferences
    print('Loading progress');
    // Implementation with shared_preferences will be added later
  }
}