import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _fontSizeKey = 'font_size';
  static const String _themeModeKey = 'theme_mode';
  static const String _mapPreferenceKey = 'map_preference';
  
  // Default values
  static const double defaultFontSize = 14.0;
  static const String defaultThemeMode = 'light';
  static const String defaultMapPreference = 'google'; // 'google', 'osm', 'waze'

  // Get font size
  static Future<double> getFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_fontSizeKey) ?? defaultFontSize;
  }

  // Set font size
  static Future<void> setFontSize(double fontSize) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontSizeKey, fontSize);
  }

  // Get theme mode ('light', 'dark', or 'system')
  static Future<String> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themeModeKey) ?? defaultThemeMode;
  }

  // Set theme mode
  static Future<void> setThemeMode(String themeMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, themeMode);
  }

  // Get map preference
  static Future<String> getMapPreference() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_mapPreferenceKey) ?? defaultMapPreference;
  }

  // Set map preference
  static Future<void> setMapPreference(String mapPreference) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_mapPreferenceKey, mapPreference);
  }

  // Reset all settings to defaults
  static Future<void> resetSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_fontSizeKey);
    await prefs.remove(_themeModeKey);
    await prefs.remove(_mapPreferenceKey);
  }
}

