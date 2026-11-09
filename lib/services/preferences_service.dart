import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const String _keyAdBlocker = 'pref_ad_blocker';
  static const String _keyBackgroundPlay = 'pref_background_play';
  static const String _keyAudioOnly = 'pref_audio_only';
  static const String _keyPlaybackSpeed = 'pref_playback_speed';
  static const String _keyQuality = 'pref_quality';
  static const String _keyAlwaysOnTop = 'pref_always_on_top';
  static const String _keyLastUrl = 'pref_last_url';
  static const String _keyWidth = 'pref_window_width';
  static const String _keyHeight = 'pref_window_height';

  static Future<Map<String, dynamic>> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'adBlocker': prefs.getBool(_keyAdBlocker) ?? true,
      'backgroundPlay': prefs.getBool(_keyBackgroundPlay) ?? true,
      'audioOnly': prefs.getBool(_keyAudioOnly) ?? false,
      'playbackSpeed': prefs.getDouble(_keyPlaybackSpeed) ?? 1.0,
      'quality': prefs.getString(_keyQuality) ?? 'hd1080',
      'alwaysOnTop': prefs.getBool(_keyAlwaysOnTop) ?? false,
      'lastUrl': prefs.getString(_keyLastUrl) ?? 'https://www.youtube.com',
      'width': prefs.getInt(_keyWidth) ?? 1280,
      'height': prefs.getInt(_keyHeight) ?? 720,
    };
  }

  static Future<void> saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  static Future<void> saveAdBlocker(bool value) => saveBool(_keyAdBlocker, value);
  static Future<void> saveBackgroundPlay(bool value) => saveBool(_keyBackgroundPlay, value);
  static Future<void> saveAudioOnly(bool value) => saveBool(_keyAudioOnly, value);
  
  static Future<void> savePlaybackSpeed(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyPlaybackSpeed, value);
  }

  static Future<void> saveQuality(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyQuality, value);
  }

  static Future<void> saveAlwaysOnTop(bool value) => saveBool(_keyAlwaysOnTop, value);

  static Future<void> saveDimensions(int width, int height) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyWidth, width);
    await prefs.setInt(_keyHeight, height);
  }

  static Future<void> saveLastUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastUrl, url);
  }
}
