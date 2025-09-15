// lib/core/services/debug_provider.dart
import 'package:flutter/foundation.dart';

class DebugProvider with ChangeNotifier {
  bool _isDebugMenuEnabled = false;
  bool _isPaidUnlockedForced = false;

  bool get isDebugMenuEnabled => _isDebugMenuEnabled;
  bool get isPaidUnlockedForced => _isPaidUnlockedForced;

  void enableDebugMenu() {
    _isDebugMenuEnabled = true;
    notifyListeners();
  }

  void setPaidUnlock(bool isUnlocked) {
    _isPaidUnlockedForced = isUnlocked;
    notifyListeners();
  }
}