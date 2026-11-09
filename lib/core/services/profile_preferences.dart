import 'package:shared_preferences/shared_preferences.dart';

/// The original player keeps the legacy keys, preserving existing installs.
/// Capture the player before awaiting so an in-flight write cannot cross profiles.
class ProfilePreferences {
  static Future<void> _pendingWrites = Future.value();

  /// Capture both the player and payload before awaiting preferences, and
  /// preserve request order even on the first platform-storage initialization.
  static Future<bool> writeString(String key, String value) {
    final preferences = getInstance();
    final result = _pendingWrites.then((_) async {
      final prefs = await preferences;
      return prefs.setString(key, value);
    });
    _pendingWrites = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }
  static Future<void> flushWrites() => _pendingWrites;

  static String activeId = 'default';
  final SharedPreferences _prefs;
  final String profileId;
  ProfilePreferences._(this._prefs, this.profileId);
  static Future<ProfilePreferences> getInstance() async {
    final id = activeId;
    return ProfilePreferences._(await SharedPreferences.getInstance(), id);
  }

  String _key(String key) => key == 'language' || profileId == 'default'
      ? key
      : 'player_${profileId}_$key';
  String? getString(String key) => _prefs.getString(_key(key));
  bool? getBool(String key) => _prefs.getBool(_key(key));
  int? getInt(String key) => _prefs.getInt(_key(key));
  double? getDouble(String key) => _prefs.getDouble(_key(key));
  List<String>? getStringList(String key) => _prefs.getStringList(_key(key));
  Object? get(String key) => _prefs.get(_key(key));
  Set<String> getKeys() => _prefs
      .getKeys()
      .where((key) => profileId == 'default'
          ? !key.startsWith('player_')
          : key.startsWith('player_${profileId}_'))
      .map((key) => profileId == 'default'
          ? key
          : key.substring('player_${profileId}_'.length))
      .toSet();
  Future<bool> setString(String key, String value) =>
      _prefs.setString(_key(key), value);
  Future<bool> setBool(String key, bool value) =>
      _prefs.setBool(_key(key), value);
  Future<bool> setInt(String key, int value) => _prefs.setInt(_key(key), value);
  Future<bool> setDouble(String key, double value) =>
      _prefs.setDouble(_key(key), value);
  Future<bool> setStringList(String key, List<String> value) =>
      _prefs.setStringList(_key(key), value);
  Future<bool> remove(String key) => _prefs.remove(_key(key));
}
